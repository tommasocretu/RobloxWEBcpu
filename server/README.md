# Server RobloxWeb (M0–M1)

Un solo processo Python (solo standard library) che serve:

- il sito e l'API JSON su `http://127.0.0.1:9080`;
- il relay WebSocket multi-giocatore su `ws://127.0.0.1:9081`;
- il database SQLite e i dati locali in `server/data/` (gitignored).

## Avvio

```bash
python3 server/run.py
# poi aprire http://127.0.0.1:9080/
```

Opzioni: `--host`, `--http-port`, `--ws-port`, `--no-seed`.

Al primo avvio vengono creati (seed idempotente):

- utente `demo` / `demo1234` — **cambiare la password** per un uso reale;
- utente autore `RobloxWeb`;
- place **Welcome Obby** con `Godot/robloxwebengine/levels/default.rwl.json` come versione 1.

Variabili d'ambiente: `ROBLOXWEB_HOST`, `ROBLOXWEB_HTTP_PORT`, `ROBLOXWEB_WS_PORT`,
`ROBLOXWEB_DATA_DIR`, `ROBLOXWEB_WS_URL` (override esplicito dell'URL WS restituito dall'API).

## API

| Metodo | Path | Auth | Note |
|---|---|---|---|
| POST | `/api/guest` | no | crea ospite + sessione |
| POST | `/api/register` | no | username/password, login automatico |
| POST | `/api/login` | no | sessione via cookie |
| POST | `/api/token` | no | login per client nativi: token Bearer, nessun cookie |
| POST | `/api/logout` | sì | cancella sessione (cookie o Bearer) |
| GET | `/api/me` | sì | utente corrente (401 se anonimo) |
| GET | `/api/places?sort=popular\|recent&q=` | no | catalogo pubblico |
| GET | `/api/places/<id>` | no | dettaglio (private solo all'owner) |
| GET | `/api/users/<id>` | no | profilo autore + esperienze pubbliche |
| POST | `/api/places` | sì | crea place + versione 1 (M1) |
| PUT | `/api/places/<id>` | owner | titolo/descrizione/visibilità (M1) |
| DELETE | `/api/places/<id>` | owner | elimina place e thumbnail (M1) |
| GET | `/api/places/<id>/data` | owner | livello della versione corrente (M1) |
| POST | `/api/places/<id>/versions` | owner | pubblica una nuova versione (M1) |
| GET | `/api/places/<id>/versions` | owner | storico versioni (M1) |
| GET | `/api/places/<id>/versions/<v>` | owner | livello di una versione (M1) |
| POST | `/api/places/<id>/thumbnail` | owner | PNG raw, `Content-Type: image/png` (M1) |
| GET | `/api/me/places` | sì | proprie place, incluse private |
| POST | `/api/places/<id>/play` | sì/ospite | livello + ticket + `ws_url`, incrementa le visite |
| GET | `/thumbs/<id>.png?v=<versione>` | no | thumbnail della versione corrente |
| GET | `/dev/...` | no | export Web del client |

La sessione usa il cookie `rw_session` (`HttpOnly`, `SameSite=Lax`, `Path=/`;
`Secure` solo dietro HTTPS). Il client Godot dentro l'iframe invia il cookie
same-origin all'HTTPRequest: verificato nel browser.

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
  "level": { "format": "robloxweb-level", "version": 1, "meta": {}, "parts": [] }
}
```

- `level` può essere un oggetto JSON oppure una stringa con il JSON originale:
  in quest'ultimo caso il server la salva **senza riserializzarla**.
- `visibility`: `public`, `unlisted`, `private`.
- `title` massimo 60 caratteri, `description` 500, livello 2 MB, parti 2000, script 200.
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
- Cap per stanza (16) e globale (64).
- Gli ospiti ricevono `guest_chat` e il messaggio non viene inoltrato.
- Heartbeat/timeout come nel vecchio relay.
- `live_players(place_id)` è condiviso con l'HTTP per i contatori del sito.

## Manutenzione

```bash
python3 server/manage.py seed              # seed idempotente
python3 server/manage.py reset             # azzera DB e thumbnail (chiede conferma)
python3 server/manage.py backup [file]     # backup SQLite consistente
python3 server/manage.py cleanup-guests    # elimina ospiti inattivi
```

## Test

```bash
python3 -m unittest discover -s server/tests -v
```

I test usano porte effimere e un DB temporaneo: non toccano `server/data/`.

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

Resta locale in M1. L'architettura è pronta per Caddy/nginx davanti:
`wss://dominio/ws` → `9081`, TLS e file statici, e `ROBLOXWEB_WS_URL` per
l'URL pubblico. Vedi M5 di `PLAN.md`.
