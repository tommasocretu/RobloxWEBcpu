# Piano di implementazione e verifica — re-skin 2014

> Documento canonico della [specifica consolidata](spec.md).
> Approvato il 28 ottobre 2026. Le decisioni sono chiuse; questo documento è l'handoff per chi implementa.
> Riferimenti canonici: [`tokens.md`](tokens.md), [`site-map.md`](site-map.md), [`hud-client.md`](hud-client.md), [`media-rules.md`](media-rules.md), [`godot-theme.md`](godot-theme.md), [`../../GLOSSARY.md`](../../GLOSSARY.md).
> Checklist di accettazione: [`acceptance.md`](acceptance.md).

## 1. Esito in una pagina

Il re-skin si consegna con **10 PR** su un branch di integrazione, senza feature flag:

1. fondamenta del sito: token, font, checker;
2. design system del sito: chrome, componenti, card/media, avatar, dialoghi;
3. home + nuova pagina Giochi;
4. dettaglio gioco;
5. pagine account: Accedi, Profilo, Moderazione, Studio;
6. fondamenta del client Godot: tema, scala, font, content scaling;
7. HUD 2014: chat, player list, salute, banner, hurt, debug, mirino;
8. Game Menu, Leave, Reset e macchina a stati di Esc;
9. barra di `play.html`, caricamento, errore, handshake e export Web;
10. documentazione, accettazione, contatto finale e merge.

Ogni PR ha un gate “fast”; solo l'ultima esegue il gate “full”. La spec è congelata: ogni scostamento visivo/UX passa da un nuovo ticket in `issues/` e da un aggiornamento di `map.md`.

## 2. Stato di partenza verificato

| Area | Oggi | Conseguenza per il piano |
|---|---|---|
| Sito | un solo `site.css` (583 righe) e un solo `site.js` (298 righe), tema scuro, nessun `--rw-*`, nessun font self-hosted, nessun `games.html` | la PR 1 introduce i token senza cambiare la pelle; la PR 2 sostituisce il design system |
| Chrome | header generato da `RW.headerHTML()`, footer duplicato in 6 pagine, avatar/dialoghi locali | la PR 2 centralizza header/footer e i componenti condivisi |
| Card/media | card con lift/ombra e badge live; nessun placeholder a stud, nessun avatar blocky | la PR 2 introduce card 202/192×108, placeholder, avatar e dialoghi 2014 |
| Copy | 51 occorrenze di “esperienz*”, 5 di “catalog*”, 8 “like” visibili, 3 “online” | la PR 2 fa lo sweep globale; il resto si rifinisce nelle PR di pagina |
| Client | `hud.tscn` piatto (103 righe), nessun `Root`, tema, player list, Game Menu, banner o hurt overlay | le PR 6–8 ricostruiscono l'HUD e i menu |
| Loading web | `play.html` mostra uno spinner moderno e nasconde l'overlay sull'evento `load`; il client crea `BootOverlay` in-canvas e non invia `rw-ready` | la PR 9 cambia insieme handshake client e overlay HTML, dopo che le PR 6–8 hanno stabilizzato tema, HUD e menu |
| Scene | `tools/generate_scenes.gd` rigenera `hud.tscn` con la vecchia struttura | le scene UI diventano scritte a mano; il generatore non le riscrive più (PR 7) |
| Font | nessun TTF/woff2 nel repo; Liberation Sans è installato nel sistema, Source Sans 3 no | la PR 1 aggiunge i woff2 + OFL; la PR 6 i TTF + OFL |
| Server | serve già HTML/woff/woff2/ttf con MIME corretti, CSP same-origin e `Cache-Control: no-store`; nessuna route da aggiungere | nessuna modifica a `server/`; `games.html` e i font funzionano senza route nuove |
| Test | `server/tests` non leggono le pagine reali; nessun test del tema/HUD; nessuna CI | i checker e i test headless sono l'unica regressione automatica; le PR allegano evidenze visive |
| Tooling | browser tool disponibile con screenshot ma senza resize; Node/Pillow presenti; niente Playwright/Chromium CLI/Xvfb; display reale disponibile | l'harness del sito usa iframe a larghezza fissa; la gallery HUD usa il renderer reale |

## 3. Invarianti, riuso e migrazione

- **Nessuna modifica a server, API, DB, relay o formato livello.** L'unico adattamento è client-side: `RW.localizeServerMessage()` traduce i messaggi server noti (“esperienze” → “giochi”, “like” → “preferiti”) e ha fallback locale per 401/403/404/429/503.
- **Thumbnail: nessuna migrazione.** Il master resta 512×288, `thumbnail_url` resta l'unica fonte, il crop è solo UI (`object-fit: cover`). Le thumbnail esistenti sono già 16:9.
- **Topbar:** la barra HTML di `play.html` sostituisce quella attuale; dentro il CanvasLayer non compare nessuna topbar. Non si tocca il client desktop né Studio.
- **URL e API invariati:** `index.html`, `place.html`, `profile.html`, `admin.html`, `studio.html`, `play.html`, `login.html`; nuova `games.html`; `/api/places/<id>/like` resta `like` anche se la UI dice “preferiti”.
- **Sito senza build step:** CSS e JS restano file statici, font self-hosted, nessun CDN, nessuna richiesta di terze parti.
- **CSP invariata:** font e iframe sono same-origin; `games.html` riceve la CSP come le altre pagine; `/dev/` resta senza CSP.
- **Cache:** il server serve tutto con `Cache-Control: no-store`; non serve cache busting per CSS/font.
- **Fuori scope:** Studio desktop/editor/start screen, build nativa dev (`LevelSelect`, `Menu`), UI mobile 2014, feature finte (Tix, Builders Club, catalogo merci, forum, party, leaderboard), asset o logo Roblox.

### 3.1 Riuso, migrazione e sostituzione

| Elemento | Trattamento | Note |
|---|---|---|
| API, sessioni, cookie, relay, livello `.rwl.json` | **riuso invariato** | nessuna modifica server; nessun cambio di contratto |
| Thumbnail esistenti | **riuso, nessuna migrazione** | master 512×288 già 16:9; `?v=<versione>` invariato |
| Card/avatar/placeholder | **sostituzione client-side** | `site.js` + CSS; nessun endpoint o resize server |
| Header/footer | **sostituzione** | header generato da `RW.headerHTML`; footer centralizzato in `RW.footerHTML` |
| Topbar di gioco | **sostituzione** | barra HTML 36 px fuori dall'iframe; nessuna topbar in-canvas |
| HUD esistente | **sostituzione** | nuova scena con `Root`, tema e widget 2014; i vecchi nodi `Coins/Players/Message/FPS` spariscono |
| Game Menu/Leave | **sostituzione** | il vecchio `_show_leave_menu` e il `BootOverlay` dinamici vengono rimossi |
| `games.html` | **nuovo** | pagina statica servita senza route server |
| Font | **nuovo** | woff2 per il sito, TTF per Godot, OFL committate |
| Test esistenti | **riuso, un aggiornamento** | `test_network.gd` passa a `chat_has_line`; gli altri restano invariati |
| `tools/generate_scenes.gd` | **ridotto** | non rigenera più `hud.tscn`; resta per `main.tscn`/`level_select.tscn` |

## 4. Modello di consegna

- Branch di integrazione `aesthetic-2014` creato da `main`.
- Ogni PR è reale su GitHub, ha base `aesthetic-2014`, un solo sottosistema e un titolo che cita la superficie (es. `site: home e pagina Giochi 2014`).
- Il branch può contenere stati intermedi, ma nessuna PR introduce codice transitorio o fallback che resterebbe in produzione.
- `main` non cambia fino alla PR 10. La PR di integrazione `aesthetic-2014` → `main` usa un merge commit (non squash): il rollback è `git revert -m 1 <merge>`.
- Nessun feature flag, nessun parametro `?theme=legacy`, nessuna doppia pelle.
- Se una PR scopre un conflitto con la spec: nuovo ticket, aggiornamento di `map.md`, decisione prima del codice. Le scelte tecniche interne (nomi di helper, ordine dei nodi, struttura dei test) sono libere.
- I documenti canonici vivono in `docs/roblox-2014/`; `GLOSSARY.md` sta alla root. Il tracker dei ticket resta in `.scratch/roblox-2014-aesthetic/`.

## 5. Sequenza PR

| # | PR | Dipende da | Superfici | Dimensione indicativa | Gate fast | Evidenza |
|---|---|---|---|---:|---|---|
| 1 | Fondamenta sito | — | token CSS, font woff2, `rw_tokens.gd`, checker | ~350 righe + font | Python tests + entrambi i checker | output checker, specimen tipografico |
| 2 | Design system sito | 1 | `site.css`, `site.js`, tutte le pagine (chrome, copy, footer) | ~900–1100 righe | Python tests + checker + browser | chrome, card, placeholder, avatar, dialoghi a 1440/700 |
| 3 | Home e Giochi | 2 | `index.html`, nuova `games.html` | ~500 righe | Python tests + checker + browser | 1440/1180/1000/700/480 + empty/search |
| 4 | Dettaglio gioco | 2 | `place.html` | ~450 righe | Python tests + checker + browser | owner/guest/hidden/404 + dialog |
| 5 | Pagine account | 2 | `login.html`, `profile.html`, `admin.html`, `studio.html` | ~700 righe | Python tests + checker + browser | login 2 colonne, profilo tab, admin tabelle, studio |
| 6 | Fondamenta client | 1 | font TTF, `RwTheme`, `RwLayout`, content scaling, `test_theme` | ~600 righe | `test_theme`, `test_gameplay`, `test_editor`, export | tipo/scala a 1680×964 e 640×364 |
| 7 | HUD 2014 | 6 | `hud.tscn`, `hud.gd`, banner, hurt, debug, `main.gd`, `remote_character.gd` | ~900 righe | `test_theme`, `test_hud`, `test_gameplay`, `test_lua`, export | gallery HUD, stati chat/lista/salute/banner/hurt |
| 8 | Game Menu | 7 | `game_menu.tscn/gd`, trigger, Esc, Leave/Reset, `main.gd` | ~600 righe | `test_hud`, `test_gameplay`, export | menu/leave/reset/focus/default a 1680 e 640 |
| 9 | Play e handshake | 2, 6, 7, 8 | `play.html`, `site.js`, `main.gd`, `place_client.gd`, export | ~400 righe | `test_network`, `test_theme`, export + browser | loading/error/ready + barra 1440/650 |
| 10 | Documentazione e chiusura | tutte | docs, AGENTS, GLOSSARY, acceptance, merge | docs | full gate | contact sheet + acceptance compilata |

> La PR 2 è la più ampia: va spezzata in commit interni (base/chrome, form, card/media, dialoghi) ma resta una sola PR perché la pelle scura non deve convivere con componenti 2014 in `main`. Se in review supera ~1200 righe, si può dividere in 2a “chrome” e 2b “media” senza cambiare l'ordine delle PR successive.

### 5.1 PR 1 — Fondamenta del sito

**Contenuto**
- Blocco `:root` con tutti i token `--rw-*` di [`tokens.md`](tokens.md) §2 in `WEBhtml/assets/site.css`; i token scuri esistenti restano temporaneamente per non rompere le pagine.
- `@font-face` Source Sans 3 300/400/600/700, `font-display: swap`, preload di 400/600; file in `WEBhtml/assets/fonts/source-sans-3/` + `OFL.txt`.
- `Godot/robloxwebengine/scripts/ui/rw_tokens.gd`: costanti `COLOR_*`, `FONT_SIZE_*`, `SIZE_*`, `OUTLINE_*`, incluse quelle solo client.
- `tools/check_design_tokens.py`: confronta CSS e GDScript per il sottoinsieme condiviso, calcola il contrasto dei token di testo e fallisce con un diff leggibile.
- `tools/check_site_content.py`: prima versione con inventario pagine, presenza dei token, font richiesti, divieto di URL esterni e regole di copy attivabili per superficie.
- Aggiornamento di `AGENTS.md` con i nuovi comandi? No: l'aggiornamento operativo è nella PR 10, per non anticipare una struttura che cambia.

**Gate**
- `python3 -m unittest discover -s server/tests -v`.
- `python3 tools/check_design_tokens.py`.
- `python3 tools/check_site_content.py`.
- Nessuno screenshot obbligatorio: la PR non deve cambiare la pelle. Se cambia il rendering del testo per il solo font, allegare uno specimen 1440.

**Done when**
- I token CSS e GDScript coincidono; il checker passa.
- I quattro woff2 esistono, sono same-origin e non producono 404.
- Le pagine attuali restano leggibili e senza errori console.

### 5.2 PR 2 — Design system del sito

**Contenuto**
- `site.css`: base 2014 (canvas bianco, testo 14/1.428, link, focus ring, niente radius/ombre), header 36 px, footer, bottoni `.btn-small/medium/large/control`, input, alert, tab, tabelle, badge, empty/loading, dialoghi `<dialog>`.
- Media: card 202/192×108, placeholder cielo/prato/stud/iniziale, hover `Gioca` 22 px, avatar blocky, hero 430×230, sidebar 300×160 e 64×36, dettaglio 500×281.
- `site.js`: `RW.headerHTML` con nav Home/Giochi/Studio/Profilo/Moderazione e stati ospite/account/admin; `RW.footerHTML`; pagina attiva; rimozione della ricerca globale; `RW.card`, `RW.thumbHTML(place, context)`, `RW.avatarHTML(user, size, decorative)`, `RW.shade`, `RW.palette` con le 8 coppie 2014, `RW.applyLive` testuale; `RW.confirmDialog`; `RW.localizeServerMessage`.
- Sweep globale della copy: “esperienze” → “giochi/gioco”, “like” → “preferiti”, “online” → “che giocano/giocano ora”, “catalogo” → “Giochi” dove è UI; footer con anno 2026 e soli link reali.
- Tutte le pagine con chrome (non `play.html`): footer generato, `data-page` per la nav attiva, rimozione della search dall'header. I corpi delle pagine restano quelli attuali fino alle PR 3–5; `play.html` riceve la barra nella PR 9.

**Regole del checker attivate in questa PR**
- niente `confirm()` residuo (le pagine che lo usano vengono migrate nella PR 5; fino ad allora la regola è `warning`, poi `error`);
- niente “esperienze” nelle stringhe visibili;
- niente URL esterni in CSS/HTML;
- header senza `header-search`.

**Gate**
- Python tests + entrambi i checker.
- Browser: console pulita, font caricato, nessun 404; screenshot chrome/card/avatar/placeholder a 1440 e 700.

**Done when**
- La home, il profilo e il dettaglio usano già card e avatar nuovi senza rompere il layout.
- La nav è corretta per ospite, account e admin.
- Il footer è unico e non ci sono link morti.

### 5.3 PR 3 — Home e Giochi

**Contenuto**
- `index.html`: hero 1180 con art 430×230 e badge “In evidenza · <titolo>”, h1 32, CTA verde/blu, sezione “Giochi popolari” con tab 2014, griglia 4 colonne, 8 card, “Vedi tutti” → `games.html`; stati caricamento/errore/vuoto; polling 10 s senza layout shift.
- `games.html` nuova: 970 px, h1 “Giochi”, filtri `Ordina per` + ricerca locale GET (`?q=&sort=`), main 610 con griglia 3×202, sidebar 300 con featured 300×160, “Più giocati” 64×36, box “Crea il tuo gioco”; empty con “Azzera ricerca”; nessuna paginazione.
- `site.css`/`site.js` solo per il supporto alla pagina (grid, sidebar, tab, hero, ricerca locale), senza duplicare componenti.
- Copy e title/meta aggiornati.

**Gate**
- Python tests + checker.
- Screenshot 1440, 1180, 1000, 700, 480; stati empty (`?q=zzz`), featured assente, live 0/>0.
- Browser: sort e ricerca cambiano URL e risultati; “Vedi tutti” funziona.

**Done when**
- Home e Giochi usano solo dati reali e nessuna feature finta.
- Le card restano 202/192×108 a 970 e fluide a 1180.
- La ricerca non è più nell'header.

### 5.4 PR 4 — Dettaglio gioco

**Contenuto**
- `place.html`: 970 px, h1 32, autore 14 con avatar 48 linkato, colonna sinistra 500 con media 500×281, descrizione e “aggiornata il…”; colonna destra 240 con `Gioca` verde 150, `★ N preferiti`, `Segnala`, box statistiche `Visite / Giocano ora / Versione / Aggiornata`.
- Stati: ospite anonimo con box “Accedi per giocare”, owner con link `Modifica`, nascosto con alert warning e play disabilitato (admin può giocare), 403/404 con box “Gioco non trovato”.
- Dialog segnalazione 2014 con select motivo, textarea, `Invia segnalazione` verde, `Annulla` grigio; niente `confirm()`.
- Polling 10 s su visite/live/preferiti senza layout shift.

**Gate**
- Python tests + checker.
- Screenshot 1440/1000/700/480 per owner, ospite, nascosto, 404, dialog.
- Browser: like toggle, report, play link, 404.

**Done when**
- Tutti gli stati e le copy sono quelli di `site-map.md` §3.3.
- Il media non si distorce e il placeholder è corretto.

### 5.5 PR 5 — Pagine account

**Contenuto**
- `login.html`: due colonne 465+484, nessun tab; pannelli Accedi/Registrati, input 21 px, `Accedi` blu, `Crea account` verde, `Annulla` grigio, `Gioca come ospite`, nota demo, alert info se già loggato, errori 2014, stack sotto 1000.
- `profile.html`: due colonne; sinistra 484 con h2 30, `@username · dal …`, avatar 352 blocky, stats `Giochi / Visite / Preferiti`, azioni per ruolo; destra con tab verticali 35 px `Giochi`/`Preferiti` solo per il proprio profilo, card 2 colonne, badge visibilità testuali, azioni owner, empty states.
- Dialog Modifica 27/700, campi titolo/descrizione/visibilità, Salva/Annulla; dialog Versioni con tabella 2014 e `Ripristina` blu; conferma con modale 2014, non `confirm()`.
- `admin.html`: due sezioni impilate con tabelle 2014 (segnalazioni aperte, giochi nascosti), azioni `Ignora`/`Nascondi`/`Ripristina`, conferme con modale, empty, non-admin, scroll orizzontale <700.
- `studio.html`: due colonne 600+300, box download con due `btn-large` verdi, meta zip/x86_64, nota 404, requisiti/comandi `<code>`, box “Come pubblicare”, “Server locale”, “Torna ai giochi”.
- Copy e title/meta aggiornati; rimozione definitiva di `confirm()`.

**Gate**
- Python tests + checker (tutte le regole diventano `error`).
- Screenshot 1440/1000/700/480: login ospite/loggato/errore; profilo proprio/pubblico/vuoto/modifica/versioni; admin segnalazioni/nascosti/conferma/non-admin; studio.
- Browser: login/registrazione, logout, modifica place, rollback, hide/restore admin (con fixture).

**Done when**
- Nessuna pagina usa `confirm()` o componenti scuri.
- Tutti gli empty state e le copy coincidono con `site-map.md` §3.5–3.8.

### 5.6 PR 6 — Fondamenta del client Godot

**Contenuto**
- Font TTF `SourceSans3-Regular/Bold`, `LiberationSans-Regular/Bold` + OFL in `Godot/robloxwebengine/assets/fonts/`; import settings come `godot-theme.md` §6.2.
- `themes/rw_theme.gd` (`RwTheme`), `scripts/ui/rw_layout.gd`, completamento di `rw_tokens.gd`; type variation `Rw*`, stylebox, helper `_flat`.
- Content scaling: `RwLayout.use_client()` in `main.gd` `_enter_tree()`; `use_editor()` in StudioStart/editor; `scale_for/apply`.
- `tools/export_web.sh`.
- `tools/test_theme.gd`: build/cache, base type, font, colori, stylebox, `scale_for`, `apply`, scan `hud.tscn`/`game_menu.tscn` senza `theme_override_` (il secondo scatterà dalla PR 8).
- Nessun handshake ancora: `play.html` continua a funzionare con l'overlay attuale; il client non mostra ancora il nuovo HUD.

**Gate**
- `flatpak run … --headless --import`.
- `test_theme.gd`, `test_gameplay.gd`, `test_editor.gd`.
- `tools/export_web.sh` + apertura `/dev/index.html` (console pulita).
- Screenshot di controllo a 1680×964 e 640×364 per verificare che la scala non abbia rotto la scena esistente.

**Done when**
- Il tema si costruisce headless, le variation hanno il base type giusto e i font sono nel PCK.
- Studio/editor restano su `CONTENT_SCALE_MODE_CANVAS_ITEMS`; il client su `DISABLED`.

### 5.7 PR 7 — HUD 2014

**Contenuto**
- `scenes/ui/hud.tscn`: `CanvasLayer` 10 → `Root` Control in design space; chat log `RichTextLabel` + input `LineEdit`, player list 202 px con header 56 e righe 20, health 170×18, banner 525×80, hurt overlay, debug FPS, crosshair 4×4. Niente `theme_override_*`.
- `scripts/ui/hud.gd`: API di `hud-client.md` §14.2 (`add_system_line`, `add_chat_line`, `chat_has_line`, `show_banner`, `set_local_coins`, `set_player_list`, `set_chat_enabled`, `set_health`, `set_crosshair_visible`, `is_chat_open`); storia 20 righe/8 visibili, fade 45 s, palette nomi deterministica, oro per i system, guest.
- `scenes/ui/banner.tscn`, `scenes/ui/debug.tscn`, `scenes/world/hurt_overlay.tscn`.
- `scripts/main.gd`: sostituisce `show_message` con `add_system_line`/`show_banner`; alimenta la player list da `net.player_name` e `_remote_characters`; `RemoteCharacter.display_name`; gli eventi di `hud-client.md` §10 passano in chat oro.
- `tools/generate_scenes.gd`: smette di rigenerare `hud.tscn` (resta per `main.tscn`/`level_select.tscn`).
- `tools/test_hud.gd`: palette, ordinamento, collapse, storia/timer, formula di scala, API chat; `tools/test_network.gd` passa a `chat_has_line`.
- Nessun Game Menu ancora: il pulsante Menu arriva nella PR 8. Esc resta il comportamento attuale.

**Gate**
- `test_theme.gd`, `test_hud.gd`, `test_gameplay.gd`, `test_lua.gd`.
- `tools/export_web.sh` + gallery HUD.
- Screenshot/gallery: chat vuota/5 righe/input aperto/ospite, player list 1/4/16/collassata, salute 100/24/0, banner, hurt, crosshair, FPS a 1680×964 e 640×364.

**Done when**
- Nessun `theme_override_` in `hud.tscn`.
- Chat, player list e salute rispettano misure, colori e copy di `hud-client.md`.
- `test_network` non legge più `ChatLog.text`.

### 5.8 PR 8 — Game Menu, Leave e Reset

**Contenuto**
- `scenes/ui/game_menu.tscn` + `scripts/ui/game_menu.gd`: shield `MENU_SHIELD`, pannello 525×430, titolo 36, pulsanti 340×50 (`Riprendi` default, `Reimposta personaggio`, `Esci dal gioco`), blocco Comandi, focus iniziale e navigazione da tastiera; Leave 525×300 (`Resta` default, `Esci`), Reset 525×370 (`Annulla` default, `Reimposta`).
- Pulsante Menu a scudo 92×48 in basso a sinistra, solo client web in place mode; `_draw` per lo scudo, hover/focus; `set_menu_enabled`.
- `main.gd`: macchina a stati `CHIUSO/MENU/LEAVE/RESET`, priorità Esc (chat → menu → leave → reset → apre menu), rilascio mouse/shift lock, blocco movimento con `input_enabled`, ripristino shift lock; rimozione del vecchio `_show_leave_menu` e del CanvasLayer 0.
- `test_hud.gd`: stati e default sicuri (`Resta`, `Annulla`); `test_gameplay.gd` invariato sul Menu iniziale.

**Gate**
- `test_theme.gd`, `test_hud.gd`, `test_gameplay.gd`.
- Export Web + gallery menu/leave/reset a 1680×964 e 640×364.
- Smoke manuale: Esc, Menu, Riprendi, Reset, Leave, ritorno a `place.html`.

**Done when**
- Il Game Menu non appare in Studio Test/native dev.
- Esc non mette in pausa il gioco e non lascia il mouse catturato dietro il menu.
- `Resta` e `Annulla` sono i default sicuri.

### 5.9 PR 9 — Play, handshake ed export

> Dipende da PR 6–8: `rw-ready` deve esistere prima che `play.html` smetta di nascondere l'overlay sull'evento `load`.

**Contenuto**
- `play.html`: barra 36 px (brand, titolo, autore linkato, `N che giocano`, `Esci`), iframe `calc(100vh - 36px)`, overlay `CARICAMENTO` + barra 300×18 indeterminata, box errore 2014, timeout 30 s, `rw-ready`/`rw-error`, nessun nome giocatore, responsive <700.
- `site.css`/`site.js`: stili barra/overlay/errore, polling conteggio 10 s con pausa in background, `rw-leave` invariato.
- `main.gd`: `place_client.post_ready()` una volta per caricamento, dopo livello costruito e personaggio spawnato; rimozione di `_show_boot` embedded; `_on_place_failed` compone `message` + `detail`.
- `place_client.gd`: `rw-error` con `detail`; `_fail` non chiama più `_post_error`; solo `post_error`/`post_ready`.
- `tools/export_web.sh` usato per l'export finale della PR.

**Gate**
- `test_network.gd`, `test_theme.gd`, `test_gameplay.gd`, `tools/export_web.sh`.
- Browser: `play.html` loading → ready, errore API, errore export mancante, `Esci`, conteggio, responsive 650; console e network puliti.
- Screenshot 1440 e 650 di loading/errore/pronto.

**Done when**
- L'overlay resta finché arriva `rw-ready`; `rw-error` mostra il box; il timeout funziona.
- Non esistono più due boot screen (HTML + in-canvas) in embedded.
- `rw-leave` torna a `place.html?id=…`.

### 5.10 PR 10 — Documentazione, accettazione e chiusura

**Contenuto**
- I documenti canonici sono già in `docs/roblox-2014/` (ticket 10): `spec.md`, `tokens.md`, `site-map.md`, `hud-client.md`, `media-rules.md`, `godot-theme.md`, `implementation-plan.md`, `acceptance.md`, `research/`, `prototype/`, `evidence/`. La PR 10 aggiunge le contact sheet e completa l'accettazione.
- `GLOSSARY.md` alla root, con i termini già approvati (committato dal ticket 10).
- `AGENTS.md`: nuovi path (`games.html`, `docs/`, `tools/check_*.py`, `tools/verify.sh`, `tools/export_web.sh`, `rw_tokens.gd`, `RwTheme`, `RwLayout`, font), comandi di verifica, struttura HUD e nota sul generatore scene.
- `acceptance.md` compilata con evidenze e contatto finale.
- Contact sheet committate in `docs/roblox-2014/evidence/`; set completo in `.scratch/roblox-2014-aesthetic/evidence/`.
- Nessun aggiornamento a `PLAN.md` (nessun M6) e a `server/README.md` (server invariato).

**Gate**
- Gate full: tutti i test Godot, `test_network`/`test_publish`/`test_studio`, `tools/verify.sh --full`, export Web, matrice visuale completa, browser smoke.
- Revisione umana di contact sheet + acceptance.
- Merge commit in `main` solo dopo il sign-off.

**Done when**
- Ogni riga di `acceptance.md` è spuntata o motivata.
- `git diff main...aesthetic-2014 -- server/` è vuoto.
- `AGENTS.md` descrive lo stato reale e i comandi funzionano da clone pulito.
- La PR di integrazione è mergiata con merge commit.

## 6. Gate fast e gate full

### 6.1 Fast (ogni PR)

```bash
python3 -m unittest discover -s server/tests -v
python3 tools/check_design_tokens.py
python3 tools/check_site_content.py
```

Più i test Godot toccati dalla PR:

```bash
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine --import
flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine \
  --script res://tools/test_theme.gd
# e, secondo la PR: test_hud.gd, test_gameplay.gd, test_lua.gd, test_editor.gd
```

- Se la PR tocca codice Godot incluso nel Web: `tools/export_web.sh` e apertura di `/dev/index.html` con console pulita.
- Se la PR cambia una superficie visibile: screenshot before/after a 1440 e 700, allegati alla PR; per le pagine con breakpoint specifici, anche 1000/480.
- Nessuna PR può mergiare con un checker rosso, un errore console o un 404 di asset.

### 6.2 Full (solo PR 10)

`tools/verify.sh --full` deve:

1. verificare che le porte 9080/9081 siano libere;
2. creare una data dir temporanea con `mktemp -d`;
3. avviare `server/run.py` con `ROBLOXWEB_DATA_DIR` temporanea e seed demo;
4. eseguire `test_network`, `test_publish`, `test_studio` e tutti i test Godot headless;
5. eseguire `tools/check_design_tokens.py` e `tools/check_site_content.py`;
6. eseguire `tools/export_web.sh`;
7. fermare il server e cancellare la data dir anche in caso di errore (trap).

La matrice visuale e la gallery HUD sono passi separati di `tools/verify.sh --full --visual` (richiedono display e browser), documentati nel §8.

## 7. Test esistenti da preservare

| Test | Stato | Note |
|---|---|---|
| `server/tests/test_platform.py` | invariato | non legge `WEBhtml` reale; nessuna modifica necessaria |
| `server/tests/test_hardening.py` | invariato | verifica CSP/M5; nessun cambio di API |
| `tools/test_gameplay.gd` | invariato salvo path HUD | il Menu iniziale non è il Game Menu |
| `tools/test_level_io.gd` | invariato | nessuna modifica al formato livello |
| `tools/test_editor.gd` | invariato | nessun tema nell'editor |
| `tools/test_lua.gd` | invariato | Lua sandbox fuori scope |
| `tools/test_publish.gd` | invariato | server/API invariati |
| `tools/test_studio.gd` | invariato | verifica anche i preset di export |
| `tools/test_network.gd` | **aggiornato** | l'assert chat passa a `hud.chat_has_line(...)` |

Nuovi test: `tools/test_theme.gd`, `tools/test_hud.gd`, `tools/check_design_tokens.py`, `tools/check_site_content.py`.

## 8. Harness di verifica visiva

### 8.1 Dati e fixture

`tools/visual_fixtures.py` (dev-only) usa una `ROBLOXWEB_DATA_DIR` temporanea e il server reale, senza toccare `server/data/`:

- crea `visual_owner`, `visual_viewer`, `visual_admin` (admin via `ROBLOXWEB_ADMIN_USERS` o `manage.py admin`);
- crea un place pubblico con thumbnail 16:9, uno con thumbnail 4:3, uno non elencato, uno privato, uno nascosto via admin;
- crea una segnalazione aperta, un like e un profilo vuoto;
- genera le thumbnail PNG con la sola stdlib (zlib/struct), senza Pillow;
- stampa URL, porte e credenziali; `--clean` cancella la data dir e ferma il server.

Le fixture usano porte dedicate (es. 9082/9083) per non collidere con il server di sviluppo e con il gate full. I dati sono deterministici e non vengono committati.

### 8.2 Matrice del sito

Generata da `tools/visual_matrix.py` in `WEBhtml/dev/visual-matrix.html` (gitignored). La pagina contiene iframe same-origin a larghezza fissa; il browser tool non sa ridimensionare la finestra, quindi i breakpoint si verificano negli iframe e si fotografano con `browser.screenshot`.

| Superficie | Larghezze | Stati |
|---|---|---|
| `index.html` | 1440, 1180, 1000, 700 | popolata, empty, errore, live 0/>0 |
| `games.html` | 1440, 1180, 1000, 700, 480 | popolata, `?q=zzz`, sidebar senza featured |
| `place.html` | 1440, 1000, 700, 480 | owner, ospite, nascosto, 404, dialog segnalazione |
| `play.html` | 1440, 650 | loading, errore, pronto, `rw-leave` |
| `login.html` | 1440, 1000, 700, 480 | ospite, loggato, errore |
| `profile.html` | 1440, 1000, 700, 480 | proprio, pubblico, vuoto, modifica, versioni |
| `admin.html` | 1440, 1000, 700, 480 | segnalazioni, nascosti, conferma, non-admin |
| `studio.html` | 1440, 1000, 700 | download, nota 404, comandi |
| Chrome/card/media | 1440, 700 | header ospite/account/admin, card con/senza thumb, hover/focus, avatar 48/352, placeholder, dialoghi |

Gli stati transitori di caricamento/errore che dipendono dalla rete o dal DB si verificano con l'harness dei componenti e con un'interruzione controllata del server dopo il load; non si aggiungono parametri `?state=` alla produzione. Il wiring reale (fetch, alert, retry) resta coperto dallo smoke browser e dalla review del codice.

### 8.3 Matrice HUD

`tools/hud_gallery.gd` monta HUD, banner, hurt, debug e Game Menu con dati finti e salva PNG via `get_viewport().get_texture().get_image().save_png()`. Richiede display, non headless; è escluso dall'export da `tools/*`.

| Gruppo | Viewport | Stati |
|---|---|---|
| HUD completo | 1680×964, 640×364 | chat vuota/5 righe/input aperto/ospite; player list 1/4/16/collassata; salute 100/24/0; banner; hurt; crosshair; FPS |
| HUD base | 1280×684, 1024×732, 800×564 | chat + player list + salute + Menu |
| Menu/dialoghi | 1680×964, 640×364 | Game Menu (focus Riprendi), Leave (focus Resta), Reset (focus Annulla), hover/focus |
| Barra play | 1440×900, 650×900 | loading, ready, error |

Nomi file: `site-<pagina>-<larghezza>-<stato>.png`, `hud-<gruppo>-<stato>-<WxH>.png`.

### 8.4 Accessibilità

- `check_design_tokens.py` calcola il contrasto dei token di testo e verificherà i valori `#767676`, footer, focus.
- Lighthouse sul sito (tutte le pagine, viewport desktop) con gate sugli audit: `color-contrast`, `label`, `link-name`, `button-name`, `html-has-lang`, `document-title`, `viewport`. Il punteggio sintetico è registrato ma non è un gate.
- Passaggio da tastiera su header, form, dialoghi, card, tab, admin, Game Menu/Leave/Reset: focus visibile, ordine logico, Esc/Invio/Spazio.
- Nessun testo affidato al solo colore: badge visibilità, live, preferiti, salute con barra + rosso.

### 8.5 Performance e pulizia

- Nessuna richiesta di terze parti; font self-hosted; `font-display: swap`.
- Nessun errore console o 404 di asset nelle pagine e in `/dev/`.
- Layout shift assente nei polling (live, visite, preferiti).
- `check_site_content.py` registra le dimensioni di CSS/JS/font e fallisce se compare un URL esterno o un font mancante; nessun budget sintetico Lighthouse.
- Dopo ogni prova: fixture `--clean`, server fermato, `WEBhtml/dev/` rigenerato dall'export e non committato.

### 8.6 Evidenze e sign-off

- Ogni PR allega gli screenshot before/after delle superfici cambiate.
- Il set completo resta in `.scratch/roblox-2014-aesthetic/evidence/` (non versionato).
- A fine lavoro si committono solo le contact sheet in `docs/roblox-2014/evidence/` (circa 10–14 immagini ottimizzate) e l'`acceptance.md` compilato.
- Il merge finale avviene dopo la revisione umana di contact sheet e acceptance.

## 9. Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| La PR 2 è troppo ampia | commit interni separati; split 2a/2b se supera ~1200 righe, senza cambiare l'ordine |
| `play.html` si rompe se aspetta `rw-ready` prima che il client lo invii | la PR 9 arriva dopo le PR 6–8 e include handshake + overlay insieme |
| `generate_scenes.gd` sovrascrive il nuovo HUD | la PR 7 modifica il generatore e aggiunge un test/controllo che non rigeneri `hud.tscn` |
| Font non inclusi nel PCK Web | preload in `RwTheme`; verifica con export e `/dev/index.html` |
| Content scaling rompe Studio/editor | `RwLayout.use_editor()` in StudioStart/editor; `test_studio`/`test_editor` nel gate |
| Il server restituisce copy fuori glossario | `RW.localizeServerMessage()` client-side, testato; nessuna modifica server |
| Fixture che sporcano il DB | data dir temporanea, porte dedicate, `--clean` e trap |
| Screenshot non riproducibili per viewport | harness a iframe + gallery Godot, nomi file deterministici |
| Nessuna CI | `tools/verify.sh` + gate per PR + evidenze allegate; nessuna aspettativa di automazione GitHub |
| Rate limit durante le prove | fixture con pochi account e richieste distanziate; server isolato |

## 10. Definition of done

Il ticket 09 è chiuso quando:

- questo piano e `acceptance.md` sono approvati e linkati da `map.md`;
- ogni decisione residua della mappa è riflessa nel piano;
- il ticket 10 può assemblare `spec.md` senza rileggere i ticket;

L'effort è chiuso quando:

- tutte le righe di `acceptance.md` sono verificate con evidenza;
- il gate full è verde, l'export Web funziona e `play.html` supera lo smoke;
- `git diff main...aesthetic-2014 -- server/` è vuoto;
- la PR 10 aggiorna `AGENTS.md`, `GLOSSARY.md` e i documenti in `docs/roblox-2014/`;
- contact sheet e acceptance sono riviste e firmate;
- il merge commit è su `main`.
