# AGENTS.md

## Layout

- Il progetto Godot vive in `Godot/robloxwebengine/` (non nella root): tutti i path
  `res://` e `project.godot` sono relativi a quella cartella.
- `WEBhtml/` è il sito servito dal server Python: `index.html` (catalogo), `place.html`,
  `play.html`, `login.html`, `profile.html`, `studio.html`, `assets/` e `dev/` (export
  Web del client, rigenerato e gitignored), `downloads/` (zip di Studio, generati e
  gitignored).
- `server/` è un unico processo Python (solo standard library): HTTP + API + relay
  WebSocket + SQLite. Vedi `server/README.md`.
- `build/` contiene gli export desktop di Studio (`build/studio/linux/`,
  `build/studio/windows/`), generati da `build_studio.sh` e gitignored.
- `PLAN.md` è il piano completo della piattaforma (M0–M5).

## Stato attuale: M2 — Studio desktop

Flusso funzionante in locale:

1. `python3 server/run.py` avvia HTTP su `127.0.0.1:9080` e WebSocket su `9081`.
2. Home del sito → login/registrazione oppure **Continua come ospite**.
3. Catalogo → pagina esperienza → **Play** → `play.html` con iframe
   `/dev/index.html?place=<id>`.
4. Il client Godot chiama `POST /api/places/<id>/play`, costruisce il livello e si
   connette al relay con un ticket HMAC.
5. Due tab sulla stessa place si vedono; place diverse sono stanze separate.
6. Gli ospiti non possono chattare né pubblicare (blocco server-side).
7. **M1:** dall'editor si preme **Pubblica**: login Bearer, titolo/descrizione/visibilità,
   creazione della place o nuova versione, thumbnail 512×288.
8. **M2:** `./build_studio.sh` produce **RobloxWeb Studio** per Linux e Windows
   (`build/studio/…` + zip in `WEBhtml/downloads/`). Studio parte dalla schermata
   iniziale: accedi/continua offline, nuova esperienza, apri file, **Le mie place**.
   L'editor ha la barra **Pubblica / Place… / Account / Script / Output** (Script e
   Output sono placeholder per M3), anteprima thumbnail e **Esci** che torna alla
   schermata iniziale.
9. Il profilo (`profile.html`) mostra le proprie esperienze con badge di visibilità e
   dialog **Modifica**; `profile.html?user=<id>` è il profilo autore pubblico.
10. Home, pagina esperienza e profilo aggiornano visite e giocatori live con polling
    leggero (10–15 s, sospeso quando la scheda è in background).

Seed idempotente al primo avvio: utente `demo` / `demo1234` (cambiare la password!),
autore `RobloxWeb`, place **Welcome Obby** da `levels/default.rwl.json`.

## Server

```bash
python3 server/run.py                 # tutto: sito, API, WS
python3 server/manage.py seed         # seed idempotente
python3 server/manage.py reset        # azzera DB (chiede conferma)
python3 server/manage.py backup       # backup SQLite consistente
python3 -m unittest discover -s server/tests -v
```

- Porte: HTTP `9080`, WebSocket `9081` (configurabili con `--http-port`, `--ws-port`).
- Dati locali in `server/data/` (gitignored): `app.db`, `secret.key`, `thumbs/`.
- Cookie di sessione `rw_session` HttpOnly/SameSite=Lax; l'HTTPRequest del client
  dentro l'iframe invia il cookie same-origin (verificato con il browser).
- Autenticazione Bearer per client nativi: `POST /api/token` restituisce un token di
  sessione senza cookie; le richieste usano `Authorization: Bearer <token>`.
- API M0: `/api/guest`, `/api/register`, `/api/login`, `/api/logout`, `/api/me`,
  `/api/places`, `/api/places/<id>`, `/api/me/places`, `/api/places/<id>/play`.
- API M1: `POST /api/places`, `PUT|DELETE /api/places/<id>`,
  `GET /api/places/<id>/data`, `POST|GET /api/places/<id>/versions`,
  `GET /api/places/<id>/versions/<v>`, `POST /api/places/<id>/thumbnail`,
  `GET /api/users/<id>`, `POST /api/token`, `GET /thumbs/<id>.png?v=<versione>`.
  Ownership: 403 per i non-owner; ospiti rifiutati su pubblicazione/modifica.
- Visibilità: `public` nel catalogo, `unlisted` solo per link, `private` solo owner.
- Thumbnail: PNG max 1 MB (1920×1080), salvata in `data/thumbs/<place_id>.png`,
  validata su firma+IHDR; una nuova versione eredita quella precedente.
- Livello in pubblicazione: max 2 MB (body API 2 MB + 64 KB), titolo 60,
  descrizione 500, parti 2000, script 200. Il server salva il JSON senza riserializzarlo
  quando arriva come stringa.
- Relay: `server/relay.py` (stanze per `place_id`, ticket HMAC, cap 16/stanza,
  heartbeat, chat ospiti rifiutata). Protocollo documentato in `server/README.md`.
- `server/test_peer.py` ottiene un ticket dall'API e simula un giocatore:
  `python3 server/test_peer.py --guest` oppure `--username demo --password demo1234`.

## Sito

- HTML/CSS/JS vanilla, stesso origin del gioco, nessun build step.
- `assets/site.js` espone `window.RW`: fetch API con cookie, header utente, card,
  guest/login/logout, gestione errori, `RW.applyLive`/`RW.pollLive` per i contatori.
  Caricato **senza** `defer` perché gli script inline delle pagine usano `RW` subito.
- `play.html` verifica la sessione, mostra la top bar, carica l'iframe e ascolta
  `postMessage` dal client (`rw-leave` → torna alla pagina esperienza,
  `rw-error` → overlay di errore).
- `profile.html`: proprie esperienze con badge di visibilità/versione e dialog
  **Modifica** (`PUT /api/places/<id>`); `?user=<id>` mostra il profilo autore
  pubblico con le sole esperienze pubbliche.
- `place.html`: autore cliccabile, versione corrente, visite/live aggiornati ogni 10 s.
- `index.html`: badge live aggiornati senza ridisegnare la griglia.
- `studio.html`: download Windows/Linux da `/downloads/` e istruzioni per pubblicare.
  I binari sono prodotti da `./build_studio.sh`; il vecchio editor web `?editor=1` è
  stato rimosso in M2.
- Esc nel client apre il menu "Lascia l'esperienza?" (Godot); il client invia
  `rw-leave` alla pagina parent.

## Client Godot

Launcher `scripts/main.gd`:

1. `LevelData.play_request` → test play da Studio (priorità);
2. `OS.has_feature("studio")` (o `-- --studio` in sviluppo) → `StudioStart`;
3. `OS.has_feature("web")` → `PlaceClient` (legge `?place=` e chiama l'API);
4. build nativa dev → `LevelSelect` attuale, single player.

- `scripts/studio/studio_start.gd` (`StudioStart`): schermata iniziale di Studio con
  login Bearer, URL server, nuova esperienza, apertura file, autosave e **Le mie place**
  (download dell'ultima versione). Passa il livello all'editor tramite `StudioSession`.
- `scripts/studio/studio_session.gd` (`StudioSession`): variabili statiche
  (`pending_level`, `pending_message`) che sopravvivono al cambio scena; l'editor le
  consuma in `_ready()` e non ripristina l'autosave quando c'è un livello in attesa.
- `scripts/net/place_client.gd` (`PlaceClient`): `HTTPRequest` POST play, timeout,
  validazione `LevelData`, errori 401/403/404/rete; `leave()` via `JavaScriptBridge`.
- `scripts/net/publish_client.gd` (`PublishClient`): login Bearer (`/api/token`),
  elenco proprie place, download livello, creazione place, nuove versioni e upload
  thumbnail. Una richiesta alla volta, esiti via segnali. Salva la sessione di Studio
  in `user://studio_session.json` (`save_session`/`restore_session`/`clear_session`).
- `scripts/net/net_client.gd`: `start_with_ticket(ws_url, ticket, name)` invia
  `hello` con il ticket; gestisce `welcome`, `join`, `leave`, `state`, `chat`,
  `error`. I retry usano lo stesso ticket.
- Sul web non compaiono LevelSelect, Menu né editor; HUD e top bar HTML mostrano
  titolo/autore/giocatori. Chat disabilitata per gli ospiti.
- Editor (`scripts/editor/editor.gd`): barra **Pubblica / Place… / Account / Script /
  Output**, finestra account + tab Pubblica/Le mie place, anteprima thumbnail 512×288
  da `SubViewport` che condivide il `World3D`, `meta.place_id`/`published_version`/
  `visibility` nel livello e nell'autosave. In Studio **Esci** torna alla start screen;
  nella build dev nativa torna a `main.tscn`.
- Il vecchio multiplayer nativo (nome in chiaro) non è più supportato dal relay:
  usare il sito web o `tools/test_network.gd` (che ottiene un ticket dall'API).

## Godot: comandi e test

Godot è installato solo come Flatpak (4.7.2, `org.godotengine.Godot`): non c'è un
binario `godot` nel PATH.

```bash
flatpak run org.godotengine.Godot --path Godot/robloxwebengine          # editor/dev
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine --import
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_gameplay.gd
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_level_io.gd
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_editor.gd
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_publish.gd
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_studio.gd
```

Dopo aver aggiunto/rimosso script con `class_name` eseguire una volta `--import`,
altrimenti la cache delle classi globali è stale e i tool falliscono con
"Identifier ... not declared".

`tools/test_network.gd` richiede il server attivo e usa l'API per ottenere un
ticket (login `demo`) e simulare un secondo giocatore. `tools/test_publish.gd`
richiede il server attivo e verifica login Bearer, creazione, v2, download e delete.
`tools/test_studio.gd` richiede il server attivo e verifica preset, `StudioSession`,
login e download dalla start screen, consumo del livello da parte dell'editor.

## Export Web

Preset `Web` in `export_presets.cfg`: **single-threaded**
(`variant/thread_support=false` → template `web_nothreads_*`), nessuna GDExtension,
output `WEBhtml/dev/index.html`, `include_filter="levels/*"`,
`exclude_filter="tools/*,scenes/editor/*,scripts/editor/*,scenes/studio/*,scripts/studio/*,scripts/net/publish_client.gd"`.
Non servono header COOP/COEP. L'editor e la start screen di Studio non sono inclusi
nel client web.

```bash
flatpak run org.godotengine.Godot --headless \
  --path Godot/robloxwebengine \
  --export-release "Web" \
  "$PWD/WEBhtml/dev/index.html"
```

Poi aprire `http://127.0.0.1:9080/` con `python3 server/run.py` attivo. Non serve
più il vecchio server statico esterno per il MIME `.wasm`: `app.py` lo serve
correttamente e con `Cache-Control: no-store`.

Template di export installati (Flatpak):
`~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/`
(Web, Windows, Linux).

## Export Studio (desktop)

Preset `Linux Studio` e `Windows Studio` con `custom_features="studio"`, PCK
incorporato (`binary_format/embed_pck=true`), output in `build/studio/`. Lo script
prepara anche gli zip serviti da `studio.html` in `WEBhtml/downloads/` (gitignored).

```bash
./build_studio.sh
```

Equivale a:

```bash
flatpak run org.godotengine.Godot --headless \
  --path Godot/robloxwebengine \
  --export-release "Linux Studio" \
  "$PWD/build/studio/linux/RobloxWebStudio.x86_64"

flatpak run org.godotengine.Godot --headless \
  --path Godot/robloxwebengine \
  --export-release "Windows Studio" \
  "$PWD/build/studio/windows/RobloxWebStudio.exe"
```

Smoke test Linux senza display:

```bash
./build/studio/linux/RobloxWebStudio.x86_64 --headless --quit-after 5
# attesi: ROBLOXWEBENGINE_READY e STUDIO_READY
```

La build Windows (`.exe`) si produce da Linux ma va provata manualmente su Windows;
qui è verificata solo come file/zip. In sviluppo la start screen si apre anche con
`flatpak run org.godotengine.Godot --path Godot/robloxwebengine -- --studio`.

## Struttura del progetto Godot

- `scenes/main.tscn` → `scripts/main.gd`: bootstrap launcher, world, UI, `GlobalSound`,
  `NetClient`, `PlaceClient`.
- `scenes/studio/studio_start.tscn` → `scripts/studio/studio_start.gd`: schermata
  iniziale di Studio (account, URL server, autosave, nuova/open file, Le mie place).
- `scenes/editor/editor.tscn` → `scripts/editor/editor.gd`, `editor_camera.gd`:
  editor desktop (camera libera, palette, proprietà, snap, duplica/elimina, undo/redo,
  simula/testa, salva/apri, autosave `user://editor_autosave.rwl.json`, Pubblica).
  Non è caricato dal client web.
- `scenes/ui/level_select.tscn`, `menu.tscn`, `hud.tscn`: UI della build nativa dev;
  HUD condiviso dal client web (chat, monete, salute, giocatori, FPS).
- `scenes/player/character.tscn`, `remote_character.tscn`: avatar R6 e avatar remoto
  interpolato.
- `scripts/world/level_data.gd` (`LevelData`), `level_builder.gd` (`LevelBuilder`),
  `level_io.gd` (`LevelIO`): formato `.rwl.json` v1 con campo `scripts` (v2 in M3),
  validazione, dati → scena, JSON/file. Entità: `part`, `spawn`, `checkpoint`, `coin`,
  `goal`, `kill`, `moving_platform`, `spinner`, `label`.
- `scripts/world/part_factory.gd` e script delle parti speciali.
- `levels/default.rwl.json` è il livello demo seedato come Welcome Obby.
- `scripts/io/level_file_io.gd`: dialog nativi su desktop, `<input type=file>` e
  download su web (usato dall'editor, non dal client web).
- `scripts/audio/sfx_factory.gd`: SFX procedurali, nessun asset esterno.
- `tools/`: `generate_scenes.gd` (rigenera le scene), `export_default_level.gd`,
  `setup_project_settings.gd`, test headless. Esclusi dall'export.

Input map (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`,
`toggle_shift_lock`) in `project.godot`, eventi con `device=-1`.
`physics/3d/default_gravity=196.2`, walk speed 16, jump velocity 50 (unità "studs").
Renderer GL Compatibility (Windows D3D12), fisica Jolt Physics.

## Gotchas

- `project.godot` avverte che va modificato dall'editor, non a mano.
- `.godot/` è cache generata: mai versionarla o fidarsene.
- `JSON.parse_string` restituisce i numeri come float: mantenerli float o
  normalizzare con `from_json(to_json(...))` nei confronti.
- Sul web `user://` mappa IndexedDB; i dialog nativi non esistono (LevelFileIO usa
  input file e download).
- `server/data/` contiene DB, secret e dati locali: non committare.
- La password demo `demo1234` è solo per lo sviluppo; il seed lo segnala a ogni
  creazione.
- Place private: solo l'owner può vederle/giocarle; la home mostra solo le pubbliche,
  le non elencate (`unlisted`) solo per link.
- Il livello non viene sincronizzato in rete: tutti i client caricano la stessa
  versione corrente dal server. La pubblicazione avviene dall'editor (M1), non dal
  client web di gioco.
- Gli ospiti sono bloccati lato server su publish, like e chat.
- `LevelIO.load_from_path` è riusato per `user://publish_settings.json` (URL server e
  username) e `user://studio_session.json` (token Bearer per non riaccedere a ogni
  avvio): non sono livelli, non validarli con `LevelData`. Il token è locale
  all'utente del sistema operativo; `clear_session()` cancella il file.
- La thumbnail viene ereditata dalle nuove versioni finché non se ne carica una nuova;
  la cattura dall'editor è best-effort (in headless non c'è renderer) e usa un
  `SubViewport` che condivide il `World3D` dell'editor.
- Il client web esclude `scenes/editor/*`, `scenes/studio/*` e i loro script: non
  aggiungere riferimenti a queste classi in `main.gd`, `PlaceClient` o altri script
  inclusi nel Web, altrimenti l'export li trascina dentro o fallisce.
- `build/` e `WEBhtml/downloads/` sono output di build: non committarli; si rigenerano
  con `./build_studio.sh`.
