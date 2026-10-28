# RobloxWeb — Piano completo della piattaforma

> Documento di handoff per l'implementazione.
> Data: 28 ottobre 2026.
> Prossima fase: **decisione sul deploy** (il piano M0–M5 è completo).
>
> **Stato (28 ottobre 2026): M0, M1, M2, M3, M4 e M5 completati e verificati.**
> M0: server HTTP+WS+SQLite, sito, client web, relay per place. M1: ownership, versioni,
> pubblicazione (API + pulsante Pubblica nell'editor), thumbnail, profilo autore, contatori
> live aggiornati. M2: RobloxWeb Studio desktop (start screen, login/offline, place browser,
> publish, thumbnail), preset Linux/Windows con feature `studio`, binari e zip in
> `build/studio/`, download sul sito, editor rimosso dal web. M3: VM Lua sandboxata
> (lexer/parser/compiler/bytecode/VM), stdlib, API Roblox-like (`workspace`, `Instance.new`,
> `Touched`, Humanoid, `task.*`), scheduler con budget, formato livello v2 con `scripts[]`,
> pannelli Script/Output e simulazione in Studio, place demo **Demo script** seedata.
> M4: ricerca per titolo/autore, ordinamento per like e recenti, like con elenco personale,
> profili autore con avatar colorato e statistiche, storico versioni con rollback
> append-only, visibilità public/unlisted/private e segnalazione contenuti; restrizioni
> ospite complete (like, segnalazioni, chat, publish). M5: configurazione via ambiente e
> secret stabile, log con rotazione, rate limit per scope, header di sicurezza, backup e
> ripristino di DB+thumbnail, backup pre-migrazione, moderazione con amministratori e
> place nascoste, esempio Caddy TLS + systemd. Test Python/Godot e prova nel browser verdi.
>
> Il deploy pubblico resta una decisione separata: l'esempio pronto è in `deploy/`.
>
> Questo piano sostituisce la direzione precedente ("level select + editor dentro la build web").
> L'obiettivo è il flusso classico Roblox: **sito → login/ospite → catalogo esperienze → Play →
> client web che carica quella specifica esperienza**, con esperienze create da altri utenti tramite
> **Studio desktop** e **logica sandboxata in Lua**.

---

## 1. Obiettivo del prodotto

Replicare, in piccolo ma in modo completo, il flusso di Roblox:

1. Un utente apre il sito.
2. Accede con username/password **oppure** continua come ospite.
3. Vede una home con una lista scrollabile di esperienze (thumbnail, titolo, autore, giocatori live).
4. Clicca una card e apre la pagina dell'esperienza (descrizione, autore, bottone **Play**).
5. Clicca **Play**: si apre una pagina con il client web a schermo intero che carica *quella*
   esperienza dal server.
6. L'esperienza è stata creata da un altro utente con **RobloxWeb Studio**, un editor desktop
   (Windows `.exe` e Linux) con strumenti semplici, pubblicazione sul server e scripting sandboxato.

Non è un clone di Roblox: è una piattaforma originale con lo stesso modello di prodotto. Per un
eventuale uso pubblico evitare marchio/logo Roblox.

---

## 2. Stato attuale del repository

Percorsi reali:

- Progetto Godot: `Godot/robloxwebengine/` (non la root).
- Scena principale: `scenes/main.tscn` → `scripts/main.gd`.
- Editor: `scenes/editor/editor.tscn` → `scripts/editor/editor.gd`.
- Formato livello: `scripts/world/level_data.gd`, `level_builder.gd`, `level_io.gd`.
- Livello demo: `levels/default.rwl.json`.
- Export Web: preset `Web` in `export_presets.cfg`, output `WEBhtml/dev/index.html`
  (rigenerato con l'export; `WEBhtml/dev/` è gitignored).
- Sito attuale: `WEBhtml/index.html`, `place.html`, `play.html`, `login.html`,
  `profile.html`, `studio.html`, `assets/`.
- Server attuale (M0): `server/run.py` avvia HTTP+API (`app.py`), relay (`relay.py`),
  SQLite (`db.py`), auth (`auth.py`), place (`places.py`); `server/wsproto.py` invariato.
- Template di export installati (Flatpak): Web, Windows e Linux in
  `~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/`.
- `AGENTS.md` è aggiornato all'architettura M0 (path di export corretti).

### Gap rispetto all'obiettivo

| Area | Oggi | Serve |
|---|---|---|
| Sito | iframe wrapper | home, catalogo, pagina esperienza, Play, login, profilo, download Studio |
| Client | LevelSelect + Menu + editor dentro il gioco | avvio diretto su una place remota, niente menu/editor |
| Studio | editor dentro la build web | binario desktop Windows/Linux con login, place browser, publish |
| Backend | relay WS globale | HTTP API + SQLite + account + places + versioni |
| Scripting | campo `scripts` nel JSON, nessun runtime | VM Lua sandboxata con API Roblox-like |

### Cosa si riusa

- `LevelData`, `LevelBuilder`, `LevelIO`, `PartFactory`.
- Editor attuale (UI, camera, proprietà, undo/redo, autosave, test play).
- `character.tscn`, `remote_character.tscn`, `hud.tscn`, SFX procedurali.
- `wsproto.py` e il relay (da rifattorizzare per stanze).
- Formato `.rwl.json` (con estensione v2 per gli script).

### Cosa esce dal client web

- Schermata `LevelSelect`.
- `Menu` con nome + Play.
- Accesso all'editor.
- Caricamento di file locali.

Restano nella build nativa di sviluppo e in Studio.

---

## 3. Decisioni approvate

| Decisione | Scelta |
|---|---|
| Linguaggio di scripting | **Lua 5.1 subset** in GDScript, non Luau completo nella v1 |
| Ordine | **Piattaforma prima**, poi pubblicazione, Studio, scripting, scoperta |
| Deploy | **Solo locale** per ora; architettura pronta per `wss`/TLS futuro |
| Identità | **Ospiti + account reali** |
| Studio | **Windows `.exe` + Linux** |
| Backend | **Un solo processo Python** (HTTP + WebSocket), stdlib, SQLite |
| Sito | HTML/CSS/JS vanilla, stesso origin del gioco, niente build step |
| Editor | Si tiene quello attuale e si estende, non si riscrive |
| Formato livello | v2 retrocompatibile con v1, scripts con `parent_id` |
| Scripting | Client-side in v1; authority server in una fase futura |

---

## 4. Architettura target

```
Browser ──HTTP──▶ ┌──────────────────────────────────────────┐
  sito + API      │  Server Python (un processo)             │
                  │  ├─ pagine statiche da WEBhtml/          │
Browser ──WS────▶ │  ├─ API JSON + sessioni + SQLite         │
  client Godot    │  ├─ relay WebSocket per place            │
  (solo gioco)    │  └─ registry condiviso (giocatori live)  │
                  └──────────────────────────────────────────┘
Studio .exe/.run ──HTTP──▶ login, place browser, publish, thumbnail
```

- **Un solo origin** in locale: `http://127.0.0.1:9080`.
- **HTTP** su `9080`, **WebSocket** su `9081`, stesso processo e stesso registry.
- In futuro: Caddy/nginx davanti, `wss://dominio/ws` → `9081`, TLS e file statici.
- Nessuna dipendenza Python esterna: `http.server`, `sqlite3`, `hashlib`, `hmac`, `secrets`,
  `json`, `threading`, `socket`.

### Struttura cartelle proposta

```
server/
  run.py          # avvia HTTP + WS nello stesso processo
  app.py          # routing HTTP, file statici, API
  auth.py         # password, sessioni, guest, ticket HMAC
  db.py           # SQLite, schema, migrazioni
  places.py       # query places/versioni, seed
  relay.py        # stanze WebSocket per place (ex server.py)
  wsproto.py      # invariato
  manage.py       # seed/reset/backup
  config.py       # porte, data dir, secret
  data/           # app.db, thumbs/, secret.key (gitignored)
  tests/          # unittest
WEBhtml/
  index.html      # home
  place.html      # dettaglio esperienza
  play.html       # pagina con client fullscreen
  login.html      # login/register/ospite
  profile.html    # profilo e proprie esperienze
  studio.html     # download Studio
  assets/         # site.css, site.js
  dev/            # export Web del client (rigenerato)
Godot/robloxwebengine/
  scenes/editor/  # Studio (desktop)
  scripts/lua/    # VM sandbox (M3)
  scripts/net/    # place bootstrap + NetClient
build/
  studio/windows/ # RobloxWebStudio.exe + pck
  studio/linux/   # RobloxWebStudio.x86_64 + pck
```

---

## 5. Flussi utente

### 5.1 Ospite

1. `login.html` → **Continua come ospite** → `POST /api/guest`.
2. Il server crea un utente `is_guest=1`, display name `Ospite1234`, e una sessione.
3. L'ospite naviga e gioca.
4. Non può pubblicare, mettere like o scrivere in chat. Il server rifiuta, non solo la UI.
5. Gli ospiti inattivi vengono eliminati periodicamente.

### 5.2 Utente registrato

1. `POST /api/register` / `POST /api/login`.
2. Sessione con cookie `rw_session`.
3. Home, ricerca, pagina esperienza, Play.
4. Profilo con le proprie esperienze.
5. In Studio può pubblicare.

### 5.3 Autore (Studio)

1. Apre Studio (Windows o Linux).
2. **Accedi** (stesso account del sito) oppure **Continua offline** per lavorare in locale.
3. **Le mie place** → apre l'ultima versione dal server, oppure **Nuova** / **Apri file**.
4. Modifica con palette, proprietà, script.
5. **Pubblica** → titolo, descrizione, visibilità, thumbnail → nuova versione sul server.
6. **Testa** → gioca la versione corrente in locale.
7. Un altro utente (o ospite) vede l'esperienza sul sito e la gioca nel browser.

### 5.4 Play

1. `place.html?id=<id>` → **Play** → `play.html?id=<id>`.
2. `play.html` verifica la sessione; se manca, redirect a `login.html?next=...`.
3. Mostra una top bar sottile (titolo, autore, **Torna al sito**) e un iframe
   `/dev/index.html?place=<id>`.
4. Il client chiama `POST /api/places/<id>/play` con i cookie.
5. Riceve livello, nome giocatore, `ws_url`, ticket; costruisce il mondo e si connette.
6. Esc → menu "Lascia l'esperienza" → torna alla pagina dell'esperienza.

---

## 6. Milestone

| # | Milestone | Cosa costruiamo | Done quando | Peso |
|---|---|---|---|---|
| **M0** | Piattaforma minima | server HTTP+WS+SQLite, guest/account, seed demo, sito home/place/play/login, client boot da `?place=`, relay per place | da browser: login o ospite → home → Play → livello demo; due tab si vedono | L |
| **M1** | Autori e pubblicazione | ownership, versioni, API publish, thumbnail, profilo, visite/live, pulsante Pubblica nell'editor attuale | A pubblica, B vede l'esperienza con autore e gioca | L |
| **M2** | Studio desktop | preset Win/Linux `studio`, start screen, login/offline, place browser, publish dialog, thumbnail, rimozione editor dal web | Studio Linux apre, edita, pubblica; zip Windows pronto | M |
| **M3** | Lua sandbox | lexer/parser/compiler/VM, stdlib, API Roblox-like, scheduler, limiti, pannello Script + Output, livello v2 | uno script su una parte funziona in Studio e nel browser per tutti | XL |
| **M4** | Scoperta | ricerca/ordinamento, like, visite, profilo, versioni/rollback, visibilità | sito completo e navigabile | M |
| **M5** | Robustezza | config/secret/backup/rate limit/log, esempio Caddy per TLS | pronto per un eventuale online | S |

### 6.1 M0 — Piattaforma minima (prima fase)

**Obiettivo:** vedere il flusso "sito → Play → client" con account/ospiti e relay per place, usando
il livello demo esistente come prima esperienza pubblicata dal seed. Nessuna pubblicazione da UI
in questa fase: il seed crea l'esperienza.

**Server**

- [x] `config.py`: host, porta HTTP 9080, porta WS 9081, data dir, secret.
- [x] `db.py`: connessione SQLite (WAL), schema, migrazioni, `PRAGMA user_version`.
- [x] `auth.py`:
  - hash password con `hashlib.scrypt` + salt per utente;
  - sessioni con token casuale, hash SHA-256 in DB, scadenza (30 giorni);
  - cookie `rw_session` HttpOnly, SameSite=Lax, Path=/; `Secure` solo dietro HTTPS;
  - guest (`is_guest=1`, nome `OspiteNNNN`);
  - ticket HMAC-SHA256 per il WebSocket (user_id, place_id, exp, is_guest).
- [x] `places.py`: lista, dettaglio, play (incrementa visite), seed.
- [x] `app.py`:
  - serve `WEBhtml/` come root statica, con MIME corretto per `.wasm`, `.pck`, `.js`, `.css`,
    `.json`, `.png`;
  - route API sotto `/api/`;
  - body JSON con limite di dimensione;
  - protezione path traversal;
  - controllo `Origin` per POST/PUT/DELETE;
  - rate limit semplice in memoria su login/register/guest;
  - `Cache-Control: no-store` in dev.
- [x] `relay.py`:
  - rifattorizzare `server.py` in stanze per `place_id`;
  - handshake `{"type":"hello","ticket":"..."}` invece del nome libero;
  - validazione ticket, cap per stanza (es. 16), heartbeat e timeout esistenti;
  - chat rifiutata per gli ospiti;
  - registry condiviso con l'HTTP per i contatori live.
- [x] `run.py`: avvia `ThreadingHTTPServer` e relay WS, gestisce Ctrl+C.
- [x] `manage.py`: `seed`, `reset`, `backup`.
- [x] Seed idempotente:
  - utente demo (`demo` / password demo, con warning di cambiarla);
  - utente "RobloxWeb" come autore del livello demo;
  - place "Welcome Obby" con `levels/default.rwl.json` come versione 1.
- [x] Test Python in `server/tests/`.

**Sito**

- [x] `WEBhtml/assets/site.css` e `site.js`.
- [x] `index.html`: header (logo, login/ospite, cerca), griglia card scrollabile.
- [x] `place.html?id=`: thumbnail, titolo, autore, descrizione, contatori, **Play**.
- [x] `play.html?id=`: top bar + iframe `/dev/index.html?place=<id>` + overlay caricamento/errore.
- [x] `login.html`: login, registrazione, **Continua come ospite**, parametro `next`.
- [x] `profile.html`: profilo minimo, proprie esperienze (per ora vuoto/placeholder per gli ospiti).
- [x] `studio.html`: pagina placeholder con download "disponibile in M2".
- [x] Gestione 401 → redirect al login; 404/403 → messaggio nella pagina.
- [x] Polling leggero dei giocatori live (implementato in M1 su home, esperienza e profilo).

**Client Godot**

- [x] `main.gd` diventa un launcher:
  1. `LevelData.play_request` → test play (ha priorità, serve a Studio);
  2. `OS.has_feature("studio")` → editor;
  3. `OS.has_feature("web")` → bootstrap da place;
  4. build nativa dev senza feature → LevelSelect attuale.
- [x] Nuovo `scripts/net/place_client.gd` (HTTPRequest):
  - legge `place` da `window.location.search` via `JavaScriptBridge`;
  - chiama `POST /api/places/<id>/play`;
  - gestisce loading, errori, timeout.
- [x] `NetClient.start_with_ticket(ws_url, ticket, player_name)`; `hello` con ticket.
- [x] Il client web non mostra LevelSelect, Menu o editor.
- [x] HUD: titolo/autore (o top bar HTML), messaggi di errore, Esc → "Lascia l'esperienza".
- [x] Chat nascosta per gli ospiti ("Accedi per chattare").
- [x] Fallback se il WebSocket non è raggiungibile: single player (comportamento attuale).
- [x] Rimuovere l'uso di `net/server_url` per il web; l'URL WS arriva dall'API.
- [x] `main.tscn`: aggiungere il nodo `PlaceClient` (o istanziarlo da codice).

**Export e docs**

- [x] Rigenerare `WEBhtml/dev/` con il preset Web.
- [x] Aggiornare `AGENTS.md`: nuova architettura, comandi, porte, path corretti
      (incluso il path stale `/home/tommaso/...`), stato M0.
- [x] Aggiornare `server/README.md` e `server/test_peer.py` al nuovo handshake.

**Test M0**

- [x] Python: registrazione, login, sessione, guest, 401/403, lista place, play, visita,
      isolamento stanze WS, blocco chat ospiti, MIME `.wasm`.
- [x] Godot headless: test esistenti (`test_gameplay`, `test_level_io`, `test_editor`) ancora verdi.
- [x] Browser: home → login/ospite → place → play; due tab stessa place → i due avatar si vedono;
      due place diverse → non si vedono.
- [x] Verifica esplicita che i cookie di sessione arrivino all'HTTPRequest dentro l'iframe.
      Se non arrivano: fallback con ticket monouso passato dalla pagina Play al client.

**Criteri di accettazione M0**

1. `python3 server/run.py` avvia tutto.
2. `http://127.0.0.1:9080/` mostra la home con la card "Welcome Obby".
3. Si può continuare come ospite o accedere come `demo`.
4. **Play** apre `play.html`, il client carica il livello dal server e si gioca.
5. Due tab sulla stessa place si vedono; place diverse no.
6. Il client web non mostra più LevelSelect, Menu o editor.
7. Gli ospiti non possono chattare (server-side).

### 6.2 M1 — Autori e pubblicazione

**Obiettivo:** un autore pubblica dall'editor e un altro utente vede e gioca l'esperienza;
ownership e visibilità sono applicate dal server, non solo dalla UI.

**Server e API**

- [x] Registrazione/login completi; profilo con le proprie esperienze.
- [x] `POST /api/places` (crea place + versione 1), `PUT /api/places/<id>` (metadati),
      `DELETE /api/places/<id>` (owner), `POST /api/places/<id>/versions`,
      `GET /api/places/<id>/versions[/<v>]`, `GET /api/places/<id>/data`,
      `POST /api/places/<id>/thumbnail`, `GET /api/users/<id>`.
- [x] Ownership e visibilità (`public`, `unlisted`, `private`): 403 per i non-owner,
      private escluse dal catalogo e dal play degli altri, unlisted raggiungibili per link.
- [x] Thumbnail PNG: validazione firma/IHDR e limite 1 MB, file `data/thumbs/<id>.png`,
      servita da `/thumbs/<id>.png?v=<versione>`, ereditata dalle nuove versioni.
- [x] Autenticazione Bearer per API non-browser (`POST /api/token`) oltre al cookie;
      niente cookie per i client nativi (Studio).
- [x] Limiti: livello 2 MB (body pubblicazione 2 MB + 64 KB), titolo 60, descrizione 500,
      rate limit su pubblicazione.
- [x] Ospiti: pubblicazione/modifica rifiutata lato server.

**Sito**

- [x] Autore cliccabile su card e pagina esperienza, pagina profilo pubblica
      (`profile.html?user=<id>`) con le esperienze pubbliche.
- [x] Profilo proprietario con badge visibilità, versione e dialog **Modifica**
      (titolo, descrizione, visibilità) via `PUT`; gli ospiti non vedono i controlli.
- [x] Contatori visite e giocatori live aggiornati con polling leggero
      (home, pagina esperienza, profilo) senza ridisegnare le card.
- [x] Thumbnail nella card e nella pagina esperienza, fallback gradiente.
- [x] `studio.html` aggiornata: pubblicazione dall'editor attuale e link
      `/dev/index.html?editor=1` temporaneo.

**Editor / Godot**

- [x] `scripts/net/publish_client.gd`: login Bearer, elenco proprie place, download livello,
      creazione place, nuova versione, upload thumbnail (una richiesta alla volta, segnali).
- [x] Seconda riga nella barra dell'editor: **Pubblica** e **Dal server…**, stato account.
- [x] Finestra con account (server, username, password), tab **Pubblica** (titolo,
      descrizione, visibilità, thumbnail) e tab **Le mie place** (apri/aggiorna).
- [x] `meta.place_id` e `meta.published_version` salvati nel livello e nell'autosave:
      le pubblicazioni successive aggiornano la stessa place.
- [x] Thumbnail 512×288 catturata con `SubViewport` dalla vista della camera (best-effort;
      se il renderer non è pronto la pubblicazione procede senza immagine).
- [x] Editor raggiungibile nel web solo con `?editor=1` (temporaneo, rimosso in M2).

**Test**

- [x] Python: bearer token, creazione, versioni, ownership (B non può modificare A),
      visibilità, thumbnail (upload/serving/ereditarietà), validazione, cancellazione,
      profilo pubblico.
- [x] Godot headless: `tools/test_publish.gd` (login, crea, v2, download, dettaglio, delete).
- [x] Browser: login demo → profilo → dialog Modifica → pagina esperienza con autore/versione →
      ospite → Play → livello e avatar renderizzati; thumbnail visibile nel catalogo.
- [x] Test esistenti (`test_gameplay`, `test_level_io`, `test_editor`) ancora verdi.

**Criteri di accettazione M1**

1. A (account) pubblica dall'editor una nuova esperienza con titolo, descrizione e visibilità.
2. B vede l'esperienza con autore e thumbnail e la gioca dal browser.
3. B non può modificare, ripubblicare, cancellare o caricare thumbnail sulla place di A (403).
4. Una nuova versione è visibile subito nella pagina esperienza e nel play.
5. Unlisted non compare nel catalogo ma si apre per link; private è solo per l'autore.
6. Gli ospiti non possono pubblicare (server-side).

**Fuori da M1:** Studio `.exe`/`.run` autonomo, start screen, place browser completo,
script Lua, like, rollback, deploy online.

### 6.3 M2 — Studio desktop

**Obiettivo:** un'app desktop autonoma (Windows `.exe` e Linux) con schermata iniziale,
login/offline, place browser, editor, test play e pubblicazione; il client web non
contiene più l'editor.

**Build e preset**

- [x] Preset `Linux Studio` e `Windows Studio` con `custom_features="studio"` e PCK
      incorporato; output in `build/studio/linux/` e `build/studio/windows/`.
- [x] `build_studio.sh`: import, export Linux/Windows, zip in `WEBhtml/downloads/`,
      `SHA256SUMS`; download collegati da `studio.html`.
- [x] Preset Web: esclusi `scenes/editor/*`, `scripts/editor/*`, `scenes/studio/*`,
      `scripts/studio/*` e `publish_client.gd`; nessun `?editor=1`.
- [x] Smoke test del binario Linux headless (`STUDIO_READY`, exit 0); zip Windows
      prodotto (da provare manualmente su Windows).

**Start screen**

- [x] `scenes/studio/studio_start.tscn` → `scripts/studio/studio_start.gd`.
- [x] Accedi / Esci, URL server, username/password, stato connessione.
- [x] Sessione Bearer persistente in `user://studio_session.json` (token + utente +
      URL), cancellata dal logout e dai 401.
- [x] **Continua offline (autosave)**, **Nuova esperienza**, **Apri file…**.
- [x] **Le mie place**: elenco via `/api/me/places`, versione/visibilità, download
      dell'ultima versione, apertura nell'editor.
- [x] Passaggio all'editor tramite `StudioSession` (livello + messaggio di stato);
      l'editor non ripristina l'autosave quando c'è un livello in attesa.

**Editor / Studio**

- [x] Barra **Pubblica / Place… / Account / Script / Output** (Script e Output sono
      placeholder disabilitati per M3) e **Esci** verso la start screen in Studio.
- [x] Place browser e publish dialog riusano `PublishClient` (creazione, nuove versioni,
      ownership, visibilità, thumbnail).
- [x] Anteprima thumbnail 512×288 nel dialog, con aggiornamento manuale; la cattura usa
      un `SubViewport` che condivide il `World3D` e una camera dedicata.
- [x] Metadati `place_id`, `published_version`, `visibility`, titolo e descrizione
      conservati nel livello e nell'autosave.
- [x] Test play via `LevelData.play_request`; Esc torna all'editor.
- [x] Launcher: feature `studio` → start screen; in sviluppo `-- --studio` per provarla.

**Test**

- [x] Python: suite M0/M1 invariata e verde (nessuna modifica al server).
- [x] Godot: `test_gameplay`, `test_level_io`, `test_editor`, `test_publish` verdi.
- [x] Nuovo `tools/test_studio.gd`: preset, `StudioSession`, login/lista/download dalla
      start screen, consumo del livello da parte dell'editor.
- [x] Browser: home e catalogo ancora funzionanti; `dev/index.html?editor=1` non apre
      più l'editor (mostra "Apri questa esperienza dal sito").
- [x] Export Web rigenerato e ispezionato: nessun file editor/studio nel PCK.

**Criteri di accettazione M2**

1. `./build_studio.sh` produce il binario Linux, l'`.exe` Windows e i due zip.
2. Il binario Linux si avvia, mostra la start screen e permette di accedere o continuare
   offline.
3. Da **Le mie place** si scarica l'ultima versione, si modifica e si ripubblica.
4. **Nuova esperienza** e **Apri file…** portano all'editor; **Esci** torna alla start
   screen.
5. La thumbnail si vede nel dialog di pubblicazione ed è servita dal sito.
6. Il client web non contiene l'editor e `?editor=1` non lo apre.
7. I test Python e Godot esistenti restano verdi.

**Fuori da M2:** Lua sandbox, pannello Script/Output attivo, ricerca/like, rollback,
deploy online.

### 6.4 M3 — Lua sandbox

- [x] Moduli: `lua_lexer.gd`, `lua_parser.gd`, `lua_compiler.gd`, `lua_vm.gd`, `lua_table.gd`,
  `lua_values.gd`, `lua_stdlib.gd`, `lua_roblox_api.gd`, `lua_scheduler.gd`, `lua_errors.gd`.
- [x] Pipeline: sorgente → lexer → parser → bytecode → VM.
- [x] Valori: nil, bool, number (float), string, table, function, userdata.
- [x] Closure/upvalue, chiamate, `if/while/repeat/for`, `break/return`, operatori Lua.
- [x] Niente `goto`, niente metatable, niente coroutine generali nella v1.
- [x] Standard library: `math`, `string`, `table`, `tostring`, `tonumber`, `type`, `pairs`, `ipairs`,
  `pcall`, `error`, `assert`.
- [x] API Roblox-like:
  - `print`, `warn`, `task.wait/spawn/delay` (+ alias `wait/spawn/delay`);
  - `workspace`, `game:GetService("Workspace")`;
  - `Instance.new("Part")`;
  - proprietà parte: `Position`, `Size`, `Color`, `Anchored`, `CanCollide`, `Transparency`,
    `Name`, `Parent`;
  - `Destroy`, `Touched`, `TouchEnded`;
  - `script.Parent`, `script.Name`;
  - wrapper player/character per `Touched` (`Name`, `Health`, `TakeDamage`,
    `FindFirstChild("Humanoid")`).
- [x] Limiti: 64 KB/script, 200 script, 2–4 ms/frame totali, call depth e istanze capped.
- [x] Sandbox: nessun accesso a `OS`, `FileAccess`, `Engine`, `ClassDB`, rete, filesystem.
- [x] Errori con nome script/riga; output in Studio; console nel client.
- [x] Formato livello v2 con `scripts[]` (`id`, `name`, `parent_id`, `enabled`, `source`).
- [x] Editor Studio: pannello Script (lista, crea/attacca, CodeEdit), pannello Output, run/test.
- [x] Script demo: porta con `Touched`, piattaforma rotante, kill brick, teleporter.
- [x] Test: unit VM, escape test, integrazione, script pubblicato e giocato nel browser.
- [x] `lua_values.gd`/`lua_function.gd`/`lua_builtin.gd`/`lua_prototype.gd` aggiunti per
  valori, closure, builtin e prototipi; `levels/scripts_demo.rwl.json` seedato come
  **Demo script**.
- [x] Editor: **Simula** avvia/ferma il runtime; **Testa** esegue gli script in `main.tscn`.
- [x] Server: validazione dei campi `scripts[]` e rifiuto di script in v1.

### 6.5 M4 — Scoperta

- [x] Ricerca per titolo/autore (`q`) e ordinamento `popular`, `likes`, `recent`, `visits`;
  il catalogo espone `likes` e lo stato `liked` dell'utente corrente.
- [x] Like: toggle per account (`POST /api/places/<id>/like`), tabella `place_likes`,
  contatore denormalizzato su `places.likes`, elenco personale `GET /api/me/likes`.
  Gli ospiti ricevono 403; un secondo click toglie il like.
- [x] Visite e giocatori live restano sui contatori esistenti; i like pesano
  nell'ordinamento "Popolari".
- [x] Profilo autore con avatar colorato stabile (`avatar_color`), username, data di
  iscrizione e statistiche pubbliche (esperienze, visite, like).
- [x] Storico versioni visibile al proprietario nel profilo con data/dimensione e
  **Ripristina**: il rollback crea una nuova versione corrente con il contenuto scelto
  (`POST /api/places/<id>/versions/<v>/rollback`), senza cancellare lo storico.
- [x] Visibilità public/unlisted/private applicata a catalogo, dettaglio, play e like.
- [x] Restrizioni ospite complete: like, segnalazioni, chat e publish rifiutati dal server.
- [x] Segnalazione contenuti (`POST /api/places/<id>/report`) con motivo, dettagli,
  una segnalazione per utente/place e rate limit; UI nel dettaglio esperienza.
- [x] Test Python per ricerca/ordinamento, like, rollback, segnalazioni, migrazione DB
  e profilo pubblico; test browser per like, rollback, segnalazione e blocchi ospite.

### 6.6 M5 — Robustezza (pre-deploy)

- [x] Configurazione via ambiente (`ROBLOXWEB_*`), secret stabile in
  `data/secret.key` oppure `ROBLOXWEB_SECRET`, data/log/backup dir separabili.
- [x] Log applicativo con rotazione (`data/logs/server.log`, 2 MB × 3) al posto
  dei `print`; access log HTTP, join/leave relay, eventi di sicurezza e azioni admin.
- [x] Rate limit a finestre scorrevoli per IP e scope (`login`, `register`, `guest`,
  `publish`, `like`, `report`, `rollback`, `play`, `admin`) con `Retry-After`;
  `X-Forwarded-For` solo con `ROBLOXWEB_TRUST_PROXY=1`; limiti chat/stato e cap
  connessioni nel relay.
- [x] Backup completo di DB+thumbnail in `data/backups/app-<stamp>/` con manifest,
  ritenzione configurabile, `restore` con `integrity_check` e backup automatico
  pre-migrazione.
- [x] Header di sicurezza (`X-Content-Type-Options`, `X-Frame-Options`,
  `Referrer-Policy`, `Permissions-Policy`, CSP sulle pagine del sito), rifiuto di
  `Transfer-Encoding` non supportato, rotazione della sessione al login, CSRF
  same-origin per le richieste con cookie, difesa timing sul login.
- [x] Moderazione: ruolo `is_admin` (CLI/env), elenco segnalazioni, chiusura o
  "nascondi", place nascoste fuori da catalogo/profili/like/play, pagina
  `/admin.html` e badge **Nascosta** nel profilo dell'autore.
- [x] Esempio Caddy per TLS e `wss://dominio/ws` + unit systemd in `deploy/`.
- [x] Test Python dedicati (`server/tests/test_hardening.py`): header, CSRF,
  rotazione sessione, rate limit, proxy fidato, moderazione, backup/ripristino,
  migrazione con backup, log e secret da ambiente.
- Resta locale finché non si decide il deploy; il piano M0–M5 è completo.

---

## 7. Dettagli tecnici

### 7.1 API

| Metodo | Path | Auth | Note |
|---|---|---|---|
| POST | `/api/guest` | no | crea ospite + sessione |
| POST | `/api/register` | no | username/password |
| POST | `/api/login` | no | sessione |
| POST | `/api/logout` | sì | cancella sessione |
| GET | `/api/me` | sì | utente corrente |
| GET | `/api/places?sort=popular\|likes\|recent\|visits&q=` | no | card pubbliche, liked se autenticato |
| GET | `/api/places/<id>` | no | dettaglio pubblico (private solo owner) |
| GET | `/api/me/places` | sì | proprie place (Studio) |
| GET | `/api/me/likes` | sì | esperienze che piacciono all'utente |
| POST | `/api/places` | sì | crea place (M1) |
| PUT | `/api/places/<id>` | owner | metadati (M1) |
| POST | `/api/places/<id>/like` | account | toggle like, 403 agli ospiti (M4) |
| POST | `/api/places/<id>/report` | account | segnalazione contenuti (M4) |
| POST | `/api/places/<id>/versions` | owner | pubblica versione (M1) |
| POST | `/api/places/<id>/versions/<v>/rollback` | owner | ripristina v come nuova versione (M4) |
| GET | `/api/places/<id>/versions` | owner | storico (M1/M4) |
| POST | `/api/places/<id>/thumbnail` | owner | PNG (M1) |
| POST | `/api/places/<id>/play` | sì/ospite | livello + ticket + ws_url |
| GET | `/api/admin/reports?status=open\|resolved\|all` | admin | segnalazioni (M5) |
| POST | `/api/admin/reports/<id>/resolve` | admin | dismiss oppure hide (M5) |
| GET | `/api/admin/places` | admin | place nascoste (M5) |
| POST | `/api/admin/places/<id>/moderate` | admin | hidden true/false (M5) |
| GET | `/dev/...` | no | export Web |

Risposta `play` (esempio):

```json
{
  "place": {"id": 1001, "title": "Welcome Obby", "author": "RobloxWeb"},
  "player": {"name": "Ospite1234", "is_guest": true},
  "level": { "format": "robloxweb-level", "version": 1, "parts": [], "scripts": [] },
  "ws_url": "ws://127.0.0.1:9081",
  "ticket": "..."
}
```

- Il livello può essere restituito come oggetto o come stringa JSON; in ogni caso il client
  passa da `LevelIO.from_json` e `LevelData.validate`.
- Il server salva la versione come **testo JSON originale** e non la riserializza.
- `visits` incrementato su play.
- `Cache-Control: no-store` sulle API.

### 7.2 Database

```sql
users(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL DEFAULT '',
  is_guest INTEGER NOT NULL DEFAULT 0,
  is_admin INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

sessions(
  token_hash TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

places(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  owner_id INTEGER NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  visibility TEXT NOT NULL DEFAULT 'public',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  current_version INTEGER NOT NULL DEFAULT 0,
  visits INTEGER NOT NULL DEFAULT 0,
  likes INTEGER NOT NULL DEFAULT 0,
  hidden INTEGER NOT NULL DEFAULT 0,
  hidden_reason TEXT NOT NULL DEFAULT ''
);

place_versions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  data_json TEXT NOT NULL,
  thumbnail_path TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(place_id, version)
);

place_likes(
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, place_id)
);

reports(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  place_id INTEGER NOT NULL REFERENCES places(id) ON DELETE CASCADE,
  reporter_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  details TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  resolved_at TEXT,
  resolved_by INTEGER REFERENCES users(id),
  created_at TEXT NOT NULL,
  UNIQUE(place_id, reporter_id)
);
```

- `PRAGMA journal_mode=WAL`.
- Connessione per thread (`threading.local`) o lock; attenzione a `check_same_thread`.
- Migrazioni con `PRAGMA user_version`: v3 aggiunge `users.is_admin`, `places.hidden`,
  `places.hidden_reason` e lo stato delle segnalazioni; prima di migrare viene creato un
  backup in `data/backups/`.
- `data/thumbs/<place_id>.png` (o `<place_id>_<version>.png` per lo storico).
- `data/secret.key` generato al primo avvio; HMAC dei ticket. In deploy si può usare
  `ROBLOXWEB_SECRET`.
- `data/logs/server.log` con rotazione; `data/backups/app-<stamp>/` con DB, thumbnail e
  manifest.
- `data/` in `.gitignore`.

### 7.3 Autenticazione e sicurezza

- Password: `hashlib.scrypt(password, salt=os.urandom(16), n=2**14, r=8, p=1)`.
- Verifica con `hmac.compare_digest`; login inesistente esegue comunque uno scrypt
  (difesa timing).
- Sessione: token `secrets.token_urlsafe(32)`, in DB solo SHA-256; login/registrazione/
  ospite ruotano la sessione cookie precedente (session fixation).
- Cookie: `HttpOnly; SameSite=Lax; Path=/`; `Secure` se HTTPS.
- CSRF: controllo `Origin`/`Referer` su metodi non-GET; le richieste con cookie devono
  dichiarare un'origine same-origin; Studio usa Bearer e non ha cookie.
- Rate limit in memoria per IP e scope con `Retry-After`; `X-Forwarded-For` solo dietro
  proxy fidato. Il relay limita chat/stato e connessioni per IP.
- Header: `X-Content-Type-Options`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy`,
  `Permissions-Policy`, CSP sulle pagine del sito (escluso l'export in `/dev/`).
- Limiti body: JSON API 64 KB; livello 2 MB; script 64 KB; parti 2000; script 200;
  `Transfer-Encoding` non supportato rifiutato; connessioni keep-alive drenate.
- Validazione server: `format`, `version`, limiti; validazione completa lato client.
- Path traversal: normalizzare e verificare che il file sia dentro `WEBhtml/`.
- Thumbnail: verificare magic PNG e dimensione.
- Messaggi di errore generici su login fallito; eventi di sicurezza nel log.

### 7.4 Ospiti

- `POST /api/guest` crea `users` con `is_guest=1`, username `guest_<random>`,
  display name `OspiteNNNN`, password vuota.
- Sessione normale.
- Vietato: publish, like, chat. Il relay rifiuta i messaggi chat degli ospiti.
- Pulizia: eliminare ospiti senza sessioni attive da N giorni (job in `manage.py` o all'avvio).
- In Studio: "Continua offline" permette di editare/testare; publish richiede login.

### 7.5 Client web

Launcher `main.gd`:

```gdscript
if not LevelData.play_request.is_empty():
    # test play da Studio
elif OS.has_feature("studio"):
    # editor
elif OS.has_feature("web"):
    # PlaceClient: leggi ?place=, fetch API, avvia
else:
    # dev nativo: LevelSelect attuale
```

`place_client.gd`:

- `JavaScriptBridge.eval("new URLSearchParams(location.search).get('place')")`.
- `HTTPRequest` con `request_completed`.
- `POST /api/places/<id>/play`.
- Timeout e messaggi:
  - nessun `place` → "Apri questa esperienza dal sito";
  - 401 → "Accedi per giocare";
  - 404/403 → "Esperienza non trovata o privata";
  - rete → "Server non raggiungibile".
- Dopo il fetch: `LevelData.validate`, `LevelBuilder.build_into`, spawn, `NetClient.start_with_ticket`.
- Passa titolo/autore alla top bar/HUD.

`NetClient`:

- `start_with_ticket(ws_url, ticket, player_name)`.
- Invia `{"type":"hello","ticket":"..."}`.
- Il server risponde con `welcome` + `id` + `peers`.
- Riconnessione con lo stesso ticket finché valido; altrimenti il client può richiedere un nuovo
  ticket alla play API.

**Rischio cookie nell'iframe:** verificare presto che l'HTTPRequest web invii i cookie di sessione
same-origin. Se non li invia, la pagina `play.html` fa il fetch (ha i cookie), riceve il JSON del
livello e il ticket, e li passa al client via `sessionStorage`/`postMessage` prima di caricare
l'iframe. Il ticket resta la credenziale per il WebSocket.

### 7.6 Studio desktop

Implementato in M2:

- Stesso progetto Godot, preset `Linux Studio`/`Windows Studio` con `custom_features="studio"`.
- Launcher: `OS.has_feature("studio")` (o `-- --studio`) → `scenes/studio/studio_start.tscn`.
- Start screen (`StudioStart`): Accedi/Esci, URL server, Continua offline (autosave), Nuova
  esperienza, Apri file, Le mie place. Sessione Bearer salvata in
  `user://studio_session.json` e impostazioni in `user://publish_settings.json`.
- Passaggio start screen → editor tramite `StudioSession` (statiche: livello e messaggio);
  l'editor usa il livello in attesa e ignora l'autosave finché lo slot è pieno.
- Editor: UI attuale + Pubblica, Place…, Account, Script, Output (gli ultimi due
  disabilitati in M2, arrivano con M3), Esci verso la start screen.
- Place browser: `GET /api/me/places`, download `GET /api/places/<id>/data`.
- Publish:
  - nuova place → `POST /api/places`;
  - versione → `POST /api/places/<id>/versions`;
  - thumbnail → `POST /api/places/<id>/thumbnail`;
  - `place_id`, `published_version`, `visibility`, titolo e descrizione salvati in `meta`.
- Thumbnail: SubViewport che condivide il `World3D`, camera dedicata, render 512×288,
  anteprima nel dialog, PNG best-effort in headless.
- Test play: `LevelData.play_request` + cambio scena a `main.tscn`; Esc torna all'editor.
- Salvataggio locale: dialog nativi; autosave esistente.
- Preset Web: esclusi `scenes/editor/*`, `scripts/editor/*`, `scenes/studio/*`,
  `scripts/studio/*`, `publish_client.gd`; il launcher non li carica.
- Build: `./build_studio.sh` (import + export + zip in `WEBhtml/downloads/` + checksum).
- Test Linux headless; Windows prodotto ma non eseguibile qui senza Wine.

### 7.7 Lua sandbox (M3)

Pipeline:

```
source → lexer → parser → compiler → bytecode → VM
                                      ↑
                              scheduler (wait, eventi, budget)
                                      ↑
                              bindings whitelist (API Roblox)
```

- Un contesto VM per script; frame, stack, upvalue, closure.
- Sospensione su `task.wait`, ripresa al frame successivo.
- Eventi (`Touched`) accodati e dispatchati con budget.
- `Vector3`/`Color3` come userdata con operatori; niente metatable esposte.
- `Instance.new("Part")` crea un nodo reale; `Parent` lo aggancia.
- `Touched` implementato con un `Area3D` sensore sulla parte quando serve; argomento player/parte.
- Errori: `script name:line: message`; stop dello script su errore fatale, senza crash del gioco.
- Limiti: istruzioni/frame, call depth, istanze, stringhe, tabelle.
- Test di escape: `os`, `io`, `debug`, `package`, `loadstring`, `require`, `getfenv`,
  `setfenv` devono essere `nil` o assenti.
- Il codice VM è condiviso tra client web e Studio; in futuro può girare in un host Godot
  headless per l'autorità server.

### 7.8 Formato livello v2

```json
{
  "format": "robloxweb-level",
  "version": 2,
  "meta": { "title": "Porte e lava", "author": "mario", "description": "" },
  "parts": [
    {
      "id": "p1", "name": "Porta", "kind": "part",
      "position": [0, 5, 0], "rotation": [0, 0, 0], "size": [4, 8, 1],
      "color": "#888888", "anchored": true, "collide": true,
      "transparency": 0.0, "props": {}
    }
  ],
  "scripts": [
    {
      "id": "s1",
      "name": "PortaScript",
      "parent_id": "p1",
      "enabled": true,
      "source": "local porta = script.Parent\nporta.Touched:Connect(function(hit)\n  print(hit.Name)\nend)\n"
    }
  ]
}
```

- `LevelData.VERSION = 2`; accettare v1 con `scripts: []`.
- Validazione: id script unici, `parent_id` esistente (o vuoto = workspace), `enabled` bool,
  sorgente entro 64 KB, max 200 script.
- `LevelBuilder` costruisce le parti e ritorna la mappa `id → nodo`; `LuaRuntime`
  (creato da `main.gd` e dall'editor) avvia gli script abilitati.
- `LevelIO.serialize_world` e l'editor devono preservare `scripts`.
- L'editor crea/rimuove script e li associa alla parte selezionata.

### 7.9 Relay multiplayer

Protocollo aggiornato:

```
client → server:
  {"type":"hello","ticket":"<hmac>"}
  {"type":"state","p":[x,y,z],"y":yaw,"s":speed}
  {"type":"chat","text":"..."}

server → client:
  {"type":"welcome","id":N,"peers":[...]}
  {"type":"join","id":N,"name":"..."}
  {"type":"leave","id":N}
  {"type":"state","id":N,"p":[...],"y":yaw,"s":speed}
  {"type":"chat","id":N,"name":"...","text":"..."}
```

- Stanze per `place_id`; un client appartiene a una sola stanza.
- Ticket: HMAC-SHA256 su `user_id|place_id|exp|is_guest`, base64url.
- Cap stanza (es. 16) e cap globale.
- Chat: rifiutata se `is_guest`.
- Heartbeat/timeout come oggi.
- Registry condiviso con l'HTTP per `live_players(place_id)`.
- `test_peer.py` aggiornato per ottenere un ticket dall'API e connettersi.

### 7.10 Sito: dettagli UI

- Header: logo/nome, Home, Cerca, accedi/avatar, link Studio.
- Home: hero + sezione "Popolari" con griglia di card scrollabile; ordinamento
  Popolari/Più apprezzati/Recenti e ricerca per titolo o autore.
- Card: thumbnail (o gradiente), titolo, autore, giocatori live, visite e like, hover.
- Place: layout a due colonne (media + dettagli), Play verde grande, autore cliccabile,
  descrizione, visite/like, aggiornato il; like e **Segnala** per gli account.
- Play: top bar sottile + iframe fullscreen; overlay di caricamento; errore con "Torna al sito".
- Login: due tab (Accedi/Registrati) + "Continua come ospite".
- Profilo: avatar colorato, nome/username, statistiche, "Le mie esperienze",
  storico versioni con rollback, elenco dei like, link a Studio; badge **Nascosta**
  per le place fermate dalla moderazione.
- Admin: `/admin.html` con segnalazioni aperte, **Ignora**, **Nascondi**,
  elenco delle place nascoste con **Ripristina**; voce **Moderazione** nel menu
  solo per `is_admin`.
- Place nascosta: banner con il motivo per l'autore, Play disabilitato (l'admin
  può ancora aprirla); fuori da catalogo, profili pubblici, like e play.
- Studio: download Windows/Linux + istruzioni.
- Mobile: non prioritario in M0; layout responsive di base.

### 7.11 Thumbnail

- M1/M2: SubViewport 512×288 che condivide il `world_3d` dell'editor, camera dedicata.
- Upload PNG con la versione; server valida e salva `data/thumbs/<place_id>.png`.
- Card: `<img src="/thumbs/<id>.png?v=<current_version>">`; fallback gradiente CSS.
- In futuro: anteprima automatica dal punto di spawn.

---

## 8. Testing

### Python

- `server/tests/` con `unittest`.
- Server avviato su porte effimere e DB temporaneo.
- Casi: register/login/logout, sessione scaduta, guest, 401/403, ownership, lista place,
  play/visite, pubblicazione (M1), visibilità, MIME `.wasm`, path traversal, body troppo grande,
  WS isolamento stanze, chat ospite bloccata, ticket scaduto/falsificato; ricerca e
  ordinamento, like (toggle, ospiti, elenco personale), rollback append-only, segnalazioni,
  migrazione DB v2 e statistiche del profilo autore (M4); hardening (M5): header di
  sicurezza, CSRF con cookie, rotazione sessione, rate limit e `Retry-After`,
  proxy fidato, moderazione/hide/unhide, backup/ripristino, backup pre-migrazione,
  log e secret da ambiente (`server/tests/test_hardening.py`).

### Godot headless

- `tools/test_gameplay.gd` aggiornato.
- `tools/test_editor.gd` e `tools/test_level_io.gd` ancora verdi.
- `tools/test_lua.gd` (M3): lexer/parser/VM, numeri, stringhe, tabelle, closure, errori,
  limiti, escape test.
- Test bootstrap place: con un server di test locale, il client carica il livello e spawna.

### Studio

- Build Linux e smoke test headless.
- Login, place browser, publish e thumbnail testati contro il server locale.
- Zip Windows prodotto; test manuale su Windows quando disponibile.

### Browser

- E2E manuale con i tool browser:
  - home → login → place → play;
  - ospite → place → play;
  - due tab stessa place;
  - due place diverse;
  - chat da account, chat bloccata da ospite;
  - errori (place privata, server giù);
  - admin: segnalazione → Nascondi → fuori dal catalogo → Ripristina.

---

## 9. Comandi

### Server

```bash
python3 server/run.py
# poi aprire http://127.0.0.1:9080/
```

### Manutenzione e deploy

```bash
python3 server/manage.py check                   # integrità + statistiche
python3 server/manage.py backup                  # DB + thumbnail + manifest
python3 server/manage.py restore <cartella>      # ripristino (chiede conferma)
python3 server/manage.py admin demo              # ruolo amministratore
python3 server/manage.py cleanup-guests
# deploy TLS di esempio:
#   deploy/Caddyfile, deploy/robloxweb.service, deploy/README.md
```

### Export Web

```bash
flatpak run org.godotengine.Godot --headless \
  --path Godot/robloxwebengine \
  --export-release "Web" \
  "$PWD/WEBhtml/dev/index.html"
```

### Editor / dev nativo

```bash
flatpak run org.godotengine.Godot --path Godot/robloxwebengine
```

### Test Godot headless

```bash
flatpak run org.godotengine.Godot --headless \
  --path Godot/robloxwebengine --script res://tools/test_gameplay.gd
# con il server attivo:
#   res://tools/test_publish.gd, res://tools/test_studio.gd
# nessun server richiesto:
#   res://tools/test_lua.gd (M3)
```

### Test Python

```bash
python3 -m unittest discover -s server/tests -v
```

### Export Studio (M2)

```bash
./build_studio.sh   # import + Linux + Windows + zip in WEBhtml/downloads/
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

Smoke test del binario Linux: `./build/studio/linux/RobloxWebStudio.x86_64 --headless --quit-after 5`
(attesi `ROBLOXWEBENGINE_READY` e `STUDIO_READY`).

> Nota: dopo aver aggiunto/rimosso script con `class_name`, eseguire una volta
> `flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine --import`
> prima dei tool `--script`.

---

## 10. Rischi e mitigazioni

| Rischio | Impatto | Mitigazione |
|---|---|---|
| La VM Lua è lunga | M3 slitta | Fase separata, subset v1, test incrementali, API minima |
| Script client-side divergono in multiplayer | esperienze non coerenti | v1 accettato; in futuro host Godot headless autorevole |
| Cookie non passano nell'iframe | Play non autenticato | test precoce in M0; fallback ticket/sessionStorage |
| Export Windows non testabile qui | bug Windows | build Linux come test; test manuale su Windows |
| Livello grande / JSON lento | play lento | limiti 2 MB, gzip opzionale, thumbnail piccole |
| Contenuti pubblici | moderazione | segnalazioni e place nascoste (M5), visibilità private |
| Path stale in AGENTS | comandi rotti | correggere in M0 |

---

## 11. Default e assunzioni

1. Ospite = solo gioco (niente chat, like, publish).
2. Studio offline consentito; publish solo con account.
3. Login username/password; niente email/reset in v1.
4. UI in italiano; nome piattaforma provvisorio "RobloxWeb".
5. Desktop browser prima; mobile dopo.
6. Porte locali 9080 (HTTP) e 9081 (WS), avvio da `python3 server/run.py`.
7. Un solo processo Python; SQLite in `server/data/`.
8. Il livello demo iniziale è `levels/default.rwl.json`, seedato come "Welcome Obby".
9. Il client web è single-threaded (nessun COOP/COEP); nessuna GDExtension.
10. La build nativa dev senza feature `studio` continua a mostrare LevelSelect per comodità.

---

## 12. Checklist storica M0 (completata)

Questa sezione documenta l'ordine con cui è stata costruita la prima milestone;
M0–M5 sono ora completi. Per il deploy vedere `deploy/README.md` e la sezione M5.

1. Leggere `AGENTS.md`, `PLAN.md`, `server/run.py`, `relay.py`, `scripts/main.gd`,
   `level_data.gd`, `level_io.gd`, `export_presets.cfg`.
2. Creare `server/config.py`, `server/db.py`, `server/auth.py`, `server/places.py`.
3. Rifattorizzare il relay in `server/relay.py` con stanze e ticket; aggiornare `test_peer.py`.
4. Scrivere `server/app.py` (static + API) e `server/run.py`.
5. Scrivere `server/manage.py` e seedare demo + Welcome Obby.
6. Scrivere i test Python e farli passare.
7. Sostituire `WEBhtml/index.html` con la home e creare le altre pagine + assets.
8. Implementare `place_client.gd` e il launcher in `main.gd`; aggiornare `NetClient`.
9. Esportare il Web in `WEBhtml/dev/`.
10. Test browser end-to-end (ospite, demo, due tab, place diverse).
11. Aggiornare `AGENTS.md` e la documentazione.
12. Solo quando M0 è verde, passare a M1.

**Non fare in M0:** publish da UI, Studio `.exe`, Lua, like, rollback, deploy online.
