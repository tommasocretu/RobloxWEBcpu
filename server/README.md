# Server RobloxWeb (M0)

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

## API M0

| Metodo | Path | Auth | Note |
|---|---|---|---|
| POST | `/api/guest` | no | crea ospite + sessione |
| POST | `/api/register` | no | username/password, login automatico |
| POST | `/api/login` | no | sessione |
| POST | `/api/logout` | sì | cancella la sessione |
| GET | `/api/me` | sì | utente corrente (401 se anonimo) |
| GET | `/api/places?sort=popular\|recent&q=` | no | catalogo pubblico |
| GET | `/api/places/<id>` | no | dettaglio (private solo all'owner) |
| GET | `/api/me/places` | sì | proprie place |
| POST | `/api/places/<id>/play` | sì/ospite | livello + ticket + `ws_url`, incrementa le visite |
| GET | `/dev/...` | no | export Web del client |

La sessione usa il cookie `rw_session` (`HttpOnly`, `SameSite=Lax`, `Path=/`;
`Secure` solo dietro HTTPS). Il client Godot dentro l'iframe invia il cookie
same-origin all'HTTPRequest: verificato nel browser.

Il ticket WebSocket è HMAC-SHA256 (`user_id`, `place_id`, scadenza, `is_guest`, nome)
e viene validato dal relay. Non è un JWT e non contiene la password.

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
```

## Deploy

Resta locale in M0. L'architettura è pronta per Caddy/nginx davanti:
`wss://dominio/ws` → `9081`, TLS e file statici, e `ROBLOXWEB_WS_URL` per
l'URL pubblico. Vedi M5 di `PLAN.md`.
