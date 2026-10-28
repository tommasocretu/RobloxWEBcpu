# Server RobloxWeb (M0–M5)

Un solo processo Python (solo standard library) che serve:

- il sito e l'API JSON su `http://127.0.0.1:9080`;
- il relay WebSocket multi-giocatore su `ws://127.0.0.1:9081`;
- il database SQLite e i dati locali in `server/data/` (gitignored).

M5 aggiunge logging con rotazione, rate limit per scope, backup/ripristino di DB
e thumbnail, migrazione con backup automatico, header di sicurezza e
moderazione di base (segnalazioni, place nascoste, amministratori). Il database
migra a `PRAGMA user_version = 3` (`users.is_admin`, `places.hidden`,
`reports.status/resolved_at/resolved_by`).

## Avvio

```bash
python3 server/run.py
# poi aprire http://127.0.0.1:9080/
```

Opzioni: `--host`, `--http-port`, `--ws-port`, `--no-seed`.

Al primo avvio vengono creati (seed idempotente):

- utente `demo` / `demo1234` — **cambiare la password** per un uso reale;
- utente autore `RobloxWeb`;
- place **Welcome Obby** con `Godot/robloxwebengine/levels/default.rwl.json`;
- place **Demo script** con `Godot/robloxwebengine/levels/scripts_demo.rwl.json`
  (porta con `Touched`, piattaforma rotante, lava e teletrasporto).

Variabili d'ambiente: `ROBLOXWEB_HOST`, `ROBLOXWEB_HTTP_PORT`, `ROBLOXWEB_WS_PORT`,
`ROBLOXWEB_DATA_DIR`, `ROBLOXWEB_WS_URL` (override esplicito dell'URL WS restituito
dall'API), `ROBLOXWEB_SECRET` (chiave HMAC al posto di `data/secret.key`),
`ROBLOXWEB_LOG_LEVEL`, `ROBLOXWEB_LOG_MAX_BYTES`, `ROBLOXWEB_LOG_BACKUP_COUNT`,
`ROBLOXWEB_TRUST_PROXY` (usa `X-Forwarded-For`),
`ROBLOXWEB_ADMIN_USERS` (elenco autorevole di amministratori separato da virgole),
`ROBLOXWEB_BACKUP_KEEP` (quanti backup conservare, default 14),
`ROBLOXWEB_MAINTENANCE_HOURS` (intervallo di pulizia di ospiti/sessioni scadute,
default 6; `0` disattiva il thread di manutenzione). I limiti delle finestre sono
in `config.RATE_LIMITS`.

Controllo rapido: `GET /api/health` restituisce `ok`, `db`, `version`, `ws_port`,
`uptime` e `live_players`.

## API

| Metodo | Path | Auth | Note |
|---|---|---|---|
| POST | `/api/guest` | no | crea ospite + sessione |
| POST | `/api/register` | no | username/password, login automatico |
| POST | `/api/login` | no | sessione via cookie |
| POST | `/api/token` | no | login per client nativi: token Bearer, nessun cookie |
| POST | `/api/logout` | sì | cancella sessione (cookie o Bearer) |
| GET | `/api/me` | sì | utente corrente (401 se anonimo) |
| GET | `/api/places?sort=popular\|likes\|recent\|visits&q=` | no | catalogo pubblico, ricerca titolo/autore; `liked` se autenticato |
| GET | `/api/places/<id>` | no | dettaglio (private solo all'owner) |
| GET | `/api/users/<id>` | no | profilo autore + statistiche + esperienze pubbliche |
| GET | `/api/me/likes` | sì | esperienze che piacciono all'utente |
| POST | `/api/places/<id>/like` | account | toggle like; 403 agli ospiti (M4) |
| POST | `/api/places/<id>/report` | account | segnalazione contenuti (M4) |
| POST | `/api/places` | sì | crea place + versione 1 (M1) |
| PUT | `/api/places/<id>` | owner | titolo/descrizione/visibilità (M1) |
| DELETE | `/api/places/<id>` | owner | elimina place e thumbnail (M1) |
| GET | `/api/places/<id>/data` | owner | livello della versione corrente (M1) |
| POST | `/api/places/<id>/versions` | owner | pubblica una nuova versione (M1) |
| POST | `/api/places/<id>/versions/<v>/rollback` | owner | ripristina v come nuova versione (M4) |
| GET | `/api/places/<id>/versions` | owner | storico versioni (M1/M4) |
| GET | `/api/places/<id>/versions/<v>` | owner | livello di una versione (M1) |
| POST | `/api/places/<id>/thumbnail` | owner | PNG raw, `Content-Type: image/png` (M1) |
| GET | `/api/me/places` | sì | proprie place, incluse private e nascoste |
| POST | `/api/places/<id>/play` | sì/ospite | livello + ticket + `ws_url`, incrementa le visite |
| GET | `/api/admin/reports?status=open\|resolved\|all` | admin | segnalazioni con place/autore/reporter (M5) |
| POST | `/api/admin/reports/<id>/resolve` | admin | `{"action":"dismiss"\|"hide"}` (M5) |
| GET | `/api/admin/places` | admin | esperienze nascoste (M5) |
| POST | `/api/admin/places/<id>/moderate` | admin | `{"hidden":true\|false,"reason":"..."}` (M5) |
| GET | `/thumbs/<id>.png?v=<versione>` | no | thumbnail della versione corrente |
| GET | `/dev/...` | no | export Web del client |

La sessione usa il cookie `rw_session` (`HttpOnly`, `SameSite=Lax`, `Path=/`;
`Secure` solo dietro HTTPS). Il client Godot dentro l'iframe invia il cookie
same-origin all'HTTPRequest: verificato nel browser. Login, registrazione e
accesso ospite **ruotano** la sessione cookie precedente; le POST/PUT/DELETE con
cookie richiedono `Origin` o `Referer` same-origin (CSRF), mentre i client
nativi con Bearer ne sono esenti.

Per i client nativi (editor/Studio) c'è `POST /api/token`, che restituisce
`{"token": "...", "user": {...}}` senza impostare cookie. Le richieste successive
usano `Authorization: Bearer <token>`; il token è una sessione normale e scade come
tale. La pubblicazione è consentita solo agli account (gli ospiti ricevono 403).

Il ticket WebSocket è HMAC-SHA256 (`user_id`, `place_id`, scadenza, `is_guest`, nome)
e viene validato dal relay. Non è un JWT e non contiene la password.

## Pubblicazione (M1)

`POST /api/places` e `POST /api/places/<id>/versions` accettano:

```json
{
  "title": "La mia esperienza",
  "description": "Testo libero",
  "visibility": "public",
  "level": { "format": "robloxweb-level", "version": 2, "meta": {}, "parts": [], "scripts": [] }
}
```

- `level` può essere un oggetto JSON oppure una stringa con il JSON originale:
  in quest'ultimo caso il server la salva **senza riserializzarla**.
- `visibility`: `public`, `unlisted`, `private`.
- `title` massimo 60 caratteri, `description` 500, livello 2 MB, parti 2000, script 200.
- `scripts[]` (v2): max 200, id unici, `name` 1–40 caratteri, `parent_id` esistente
  (o vuoto = workspace), `enabled` bool, `source` max 64 KB. Script in v1 rifiutati.
- La nuova versione diventa subito corrente e incrementa `current_version`;
  `updated_at` cambia. La thumbnail precedente viene ereditata finché non se ne carica una nuova.
- Errori: 400 (dati non validi), 401 (non autenticato), 403 (ospite o non owner),
  413 (body troppo grande), 429 (rate limit).

Esempio con token Bearer:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:9080/api/token \
  -H 'Content-Type: application/json' \
  -d '{"username":"demo","password":"demo1234"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')

curl -s -X POST http://127.0.0.1:9080/api/places \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"title\":\"Prova\",\"level\":$(cat Godot/robloxwebengine/levels/default.rwl.json)}"

curl -s -X POST http://127.0.0.1:9080/api/places/1/thumbnail \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: image/png' \
  --data-binary @anteprima.png
```

### Thumbnail

- Deve essere un PNG valido (firma + IHDR), massimo 1 MB e 1920×1080.
- Il file viene scritto atomicamente in `server/data/thumbs/<place_id>.png`.
- L'URL pubblico è `/thumbs/<place_id>.png?v=<current_version>`; le card usano il
  gradiente come fallback se la versione corrente non ha una thumbnail.
- `thumbnail_path` è salvato su `place_versions`: lo storico sa quale versione aveva
  un'immagine.

## Scoperta, like e segnalazioni (M4)

- `GET /api/places?sort=popular|likes|recent|visits&q=testo`: ricerca case-insensitive
  su titolo, `display_name` e `username`; `popular` ordina per like, poi visite e
  aggiornamento. Se la richiesta è autenticata, ogni place include `liked`.
- `POST /api/places/<id>/like` (account, non ospiti): toggle. Risposta
  `{"liked": true, "likes": 3}`. `GET /api/me/likes` restituisce le esperienze
  visibili piaciute all'utente.
- `POST /api/places/<id>/report` `{"reason": "spam", "details": "..."}`: motivi
  `inappropriate`, `spam`, `copyright`, `other`; dettagli max 500. Una segnalazione per
  utente/place viene aggiornata se ripetuta. L'owner non può segnalare la propria place.
- `POST /api/places/<id>/versions/<v>/rollback` (owner): crea la versione successiva
  con il `data_json` della versione scelta. Lo storico è append-only e i metadati
  correnti (titolo/descrizione/visibilità/thumbnail) restano invariati.
- Gli ospiti ricevono 403 su like, segnalazioni e publish; il relay continua a
  rifiutare la chat degli ospiti.
- `GET /api/users/<id>` aggiunge `avatar_color` (colore stabile derivato dall'id) e
  `stats` con `places`, `visits`, `likes` delle sole esperienze pubbliche.

## Moderazione (M5)

- Un amministratore è un account con `users.is_admin = 1`. Si assegna con
  `python3 server/manage.py admin <username>` (o con `ROBLOXWEB_ADMIN_USERS`,
  elenco autorevole applicato all'avvio). La pagina `/admin.html` è visibile dal
  menu account solo agli amministratori.
- `GET /api/admin/reports?status=open` elenca le segnalazioni con titolo/autore
  della place, reporter, motivo, dettagli e stato `hidden`.
- `POST /api/admin/reports/<id>/resolve` con `action=dismiss` chiude la
  segnalazione; con `action=hide` chiude e nasconde la place. Una place nascosta
  esce da catalogo, profilo pubblico, like e play; l'autore la vede ancora nel
  profilo con il badge **Nascosta**, l'admin può riaprirla.
- `POST /api/admin/places/<id>/moderate` con `{"hidden": false}` ripristina una
  place; `{"hidden": true, "reason": "..."}` la nasconde senza segnalazione.
- Le azioni admin e i login falliti finiscono nel log `security`.

## Backup, log e rate limit (M5)

- **Log**: `data/logs/server.log` con rotazione (2 MB × 3 di default), formatter
  con timestamp e componente; access log HTTP e join/leave del relay inclusi.
- **Rate limit**: finestre scorrevoli per IP e scope (`login`, `register`,
  `guest`, `publish`, `like`, `report`, `rollback`, `play`, `admin`, default).
  La risposta 429 include `Retry-After`. Con `ROBLOXWEB_TRUST_PROXY=1` l'IP è
  letto da `X-Forwarded-For`.
- **Backup**: `manage.py backup` crea `data/backups/app-<stamp>/` con `app.db`
  (copia consistente via API SQLite), `thumbs/` e `manifest.json`; mantiene gli
  ultimi `ROBLOXWEB_BACKUP_KEEP` (14) backup. `restore` controlla
  `PRAGMA integrity_check` prima di sostituire i dati; fermare il server prima
  di ripristinare.
- **Migrazioni**: prima di aggiornare un DB esistente viene creato
  `data/backups/pre-migration-v<versione>-<stamp>.db`.
- **Sicurezza**: header `X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy`, `Permissions-Policy`; CSP sulle pagine del sito (non
  sull'export Godot in `/dev/`); rifiuto di `Transfer-Encoding: chunked` non
  supportato; path traversal e thumbnail validati; session fixation evitata
  ruotando il cookie al login.

## Relay

Protocollo (un oggetto JSON per frame di testo):

```
client → server:
  {"type":"hello","ticket":"..."}
  {"type":"state","p":[x,y,z],"y":yaw,"s":speed}
  {"type":"chat","text":"..."}

server → client:
  {"type":"welcome","id":N,"place_id":ID,"peers":[...]}
  {"type":"join","id":N,"name":"..."}
  {"type":"leave","id":N}
  {"type":"state","id":N,"p":[...],"y":yaw,"s":speed}
  {"type":"chat","id":N,"name":"...","text":"..."}
  {"type":"error","code":"guest_chat|rejected|full","message":"..."}
```

- Una stanza per `place_id`; i client di place diverse non si vedono.
- Cap per stanza (16), globale (64) e per IP (12 connessioni); frame massimo 16 KB.
- Gli ospiti ricevono `guest_chat` e il messaggio non viene inoltrato.
- Chat limitata a 20 messaggi/minuto per client (`rate_limited`); gli aggiornamenti
  di stato oltre 30/secondo vengono scartati. Posizioni non finite sono ignorate.
- Heartbeat/timeout come nel vecchio relay.
- `live_players(place_id)` è condiviso con l'HTTP per i contatori del sito.

## Manutenzione

```bash
python3 server/manage.py seed                    # seed idempotente
python3 server/manage.py reset                   # azzera DB e thumbnail (chiede conferma)
python3 server/manage.py backup                  # DB + thumbnail + manifest
python3 server/manage.py backup /tmp/rw-backup   # destinazione esplicita
python3 server/manage.py restore <cartella>      # ripristino (chiede conferma)
python3 server/manage.py prune-backups --keep 7  # elimina i backup più vecchi
python3 server/manage.py cleanup-guests          # elimina ospiti inattivi
python3 server/manage.py admin demo              # concede il ruolo admin
python3 server/manage.py check                   # integrità + statistiche
```

Durante l'esecuzione un thread di manutenzione elimina periodicamente ospiti
inattivi e sessioni scadute; l'intervallo è `ROBLOXWEB_MAINTENANCE_HOURS`
(default 6 ore, `0` lo disattiva). Il thread usa una propria connessione SQLite e
viene fermato prima della chiusura del database.

## Test

```bash
python3 -m unittest discover -s server/tests -v
```

I test usano porte effimere e un DB temporaneo: non toccano `server/data/`.
`server/tests/test_hardening.py` copre header/CSRF/sessione, rate limit, proxy
fidato, moderazione, backup/ripristino, migrazione con backup, log e secret.

Client CLI verso il relay (ottiene il ticket dall'API):

```bash
# in un terminale: python3 server/run.py
python3 server/test_peer.py --guest
python3 server/test_peer.py --username demo --password demo1234 \
    --send-chat "ciao" --expect-chat "risposta"
# gli ospiti non possono chattare: deve arrivare guest_chat
python3 server/test_peer.py --guest --send-chat "ciao" \
    --expect-error guest_chat --timeout 5
```

Test Godot headless (server attivo):

```bash
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_network.gd
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_publish.gd   # login, crea, v2, download, delete
```

## Deploy

Resta locale finché non si decide il deploy. Per esporlo con TLS c'è un esempio
pronto in `deploy/` (Caddy + systemd):

- Caddy serve `https://dominio` → `127.0.0.1:9080` e `wss://dominio/ws` →
  `127.0.0.1:9081`;
- `ROBLOXWEB_WS_URL=wss://dominio/ws` e `ROBLOXWEB_TRUST_PROXY=1` nell'env;
- `ROBLOXWEB_SECRET` esplicito e `ROBLOXWEB_DATA_DIR` fuori dal codice;
- backup giornaliero via cron e `manage.py check` periodico.

Vedi `deploy/README.md` per i passi completi.
