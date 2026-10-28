# Checklist di accettazione — re-skin 2014

> Allegato a [`implementation-plan.md`](implementation-plan.md).
> Ogni riga ha un ID stabile: le PR citano gli ID coperti, il gate finale li verifica tutti.
> `Esito`: `☐` da verificare, `✔` verificato, `—` non applicabile con motivo.
> `Evidenza`: percorso dello screenshot, nome del test, output del checker o link alla PR.

## 1. Sito — chrome e trasversali

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-CHROME-01 | L'header è blu `#114081`, alto 36 px, con inner 970 px (1180 sulla home) e divisori `#7394C1`. | | ☐ |
| SITE-CHROME-02 | La nav mostra Home · Giochi · Studio · Profilo · Moderazione (solo admin); la voce attiva è bianca in grassetto; hover `rgba(255,255,255,.14)`. | | ☐ |
| SITE-CHROME-03 | Lo stato ospite mostra `Registrati`, “oppure”, `Accedi`, `Ospite`; lo stato account mostra username, tag Ospite se pertinente, `Esci`. | | ☐ |
| SITE-CHROME-04 | Non esiste una ricerca globale nell'header; la ricerca è solo in `games.html`. | | ☐ |
| SITE-CHROME-05 | Il footer è blu `#123F83`, con soli link reali e anno 2026; è assente in `play.html`. | | ☐ |
| SITE-CHROME-06 | Sotto 1000 px la nav si compatta; sotto 700 restano brand, account e `Giochi`; il footer va in colonna sotto 480. | | ☐ |
| SITE-CHROME-07 | Focus ring 2 px `#00A1DA` con offset 1 su link, bottoni, input, tab e card; target minimo 24×24. | | ☐ |
| SITE-CHROME-08 | Non ci sono ombre, radius (tranne tooltip), gradienti o animazioni di lift; hover CTA con darkening 8%. | | ☐ |
| SITE-CHROME-09 | Nessun link morto (Chi siamo, Termini, Privacy, Forum) e nessun “© 2014”. | | ☐ |
| SITE-CHROME-10 | Ogni pagina ha `lang="it"`, title coerente e nessun errore console/404 di asset. | | ☐ |

## 2. Sito — pagine e stati

### 2.1 Home (`index.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-HOME-01 | Hero 1180 px in stile box 2014: h1 32 “Benvenuto su RobloxWeb”, CTA verde `Gioca ora` + CTA blu `Crea`. | | ☐ |
| SITE-HOME-02 | L'art dell'hero è 430×230 `cover`, con badge “In evidenza · <titolo>” e link unico; senza giochi l'art è nascosta e resta il testo. | | ☐ |
| SITE-HOME-03 | La sezione “Giochi popolari” ha h2 30/400, tab `Popolari / Più apprezzati / Recenti`, griglia 4 colonne e 8 card. | | ☐ |
| SITE-HOME-04 | “Vedi tutti” porta a `games.html`; il sort cambia i risultati e lo stato attivo. | | ☐ |
| SITE-HOME-05 | Stati caricamento (“Caricamento…”), errore (alert 2014) ed empty (“Nessun gioco trovato.” + link) sono corretti. | | ☐ |
| SITE-HOME-06 | Il live si aggiorna ogni 10 s, si sospende con la scheda in background e non ridisegna la griglia. | | ☐ |
| SITE-HOME-07 | L'hero non duplica il saluto all'utente; il guest button resta nell'header e in login. | | ☐ |

### 2.2 Giochi (`games.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-GAMES-01 | Pagina 970 px, h1 32, riga filtri con `Ordina per` e ricerca locale; nessun filtro Tempo/Genere finto. | | ☐ |
| SITE-GAMES-02 | Layout main 610 (griglia 3×202, card 192×108) + sidebar 300. | | ☐ |
| SITE-GAMES-03 | La sidebar mostra “In evidenza” 300×160, “Più giocati” con thumb 64×36 e “Crea il tuo gioco”; sparisce se non ha dati. | | ☐ |
| SITE-GAMES-04 | Ricerca e sort usano GET e `?q=&sort=`; il form è inviabile da tastiera. | | ☐ |
| SITE-GAMES-05 | Empty “Nessun gioco trovato.” + “Azzera ricerca”; nessuna paginazione. | | ☐ |
| SITE-GAMES-06 | Sotto 1000: 2 colonne; sotto 700: 1 colonna e sidebar in stack. | | ☐ |

### 2.3 Dettaglio gioco (`place.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-PLACE-01 | Pagina 970 px; h1 32; autore 14 con avatar 48 e link al profilo; due colonne 500 + 240. | | ☐ |
| SITE-PLACE-02 | Media 500×281 `cover` center, bordo `#CCC`, alt “Anteprima di <titolo>”; placeholder 84 px se manca o è rotta. | | ☐ |
| SITE-PLACE-03 | Destra: `Gioca` verde 150, `★ N preferiti` con stella oro/grigia, `Segnala`, box `Visite / Giocano ora / Versione / Aggiornata`. | | ☐ |
| SITE-PLACE-04 | Ospite anonimo: box “Accedi per giocare” con Accedi, Registrati, Gioca come ospite; il play resta e porta al login. | | ☐ |
| SITE-PLACE-05 | Owner: link `Modifica` al profilo; nessun dialog di modifica duplicato qui. | | ☐ |
| SITE-PLACE-06 | Nascosto: alert warning; non-admin ha play disabilitato “Non disponibile” e like/report nascosti; admin può giocare. | | ☐ |
| SITE-PLACE-07 | Dialog “Segnala gioco” 2014 con select motivo, textarea, `Invia segnalazione` verde, `Annulla` grigio, focus corretto. | | ☐ |
| SITE-PLACE-08 | 403/404: box “Gioco non trovato” + link; nessun errore grezzo. | | ☐ |
| SITE-PLACE-09 | Visite/live/preferiti si aggiornano ogni 10 s senza layout shift. | | ☐ |

### 2.4 Gioca (`play.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-PLAY-01 | Barra 36 px con brand, titolo, `di <autore>` linkato, `N che giocano`, `Esci`; nessun nome giocatore. | | ☐ |
| SITE-PLAY-02 | L'iframe è `calc(100vh - 36px)`, bordo 0, sfondo nero; nessun header/footer del sito. | | ☐ |
| SITE-PLAY-03 | Overlay nero con `CARICAMENTO` 12 px maiuscolo e barra 300×18 (`#D2D400` su `#8C8C8C`), indeterminata; con `prefers-reduced-motion` il fill resta fermo al 40%. | | ☐ |
| SITE-PLAY-04 | L'overlay resta finché arriva `rw-ready`; non sparisce sull'evento `load` dell'iframe. | | ☐ |
| SITE-PLAY-05 | `rw-error` mostra il box “Impossibile avviare il gioco” con messaggio, detail e `Torna al gioco`; la barra resta usabile. | | ☐ |
| SITE-PLAY-06 | Il timeout di 30 s mostra “Il client non risponde. Ricarica la pagina.”; se `rw-ready` arriva dopo, l'errore sparisce. | | ☐ |
| SITE-PLAY-07 | Il conteggio parte da `live_players`, si aggiorna ogni 10 s, non scende sotto 1 a gioco pronto e non fa layout shift. | | ☐ |
| SITE-PLAY-08 | Sotto 700 px restano titolo con ellissi + `Esci`; la barra resta alta 36 px. | | ☐ |
| SITE-PLAY-09 | `Esci` e `rw-leave` tornano a `place.html?id=…`; nessun loop o pagina bianca. | | ☐ |

### 2.5 Accedi / Registrati (`login.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-LOGIN-01 | Due colonne 465 + 484, entrambe visibili, nessun tab; sotto 1000 stack con login prima. | | ☐ |
| SITE-LOGIN-02 | Pannello Accedi con label/input 21 px, `Accedi` blu, `Annulla` grigio, `Gioca come ospite` link. | | ☐ |
| SITE-LOGIN-03 | Pannello Registrati con username/password/ripeti, footnote 12 `#666`, `Crea account` verde. | | ☐ |
| SITE-LOGIN-04 | Nota demo `demo/demo1234` in footnote 12 px, solo sviluppo. | | ☐ |
| SITE-LOGIN-05 | Se già loggato: alert info “Sei connesso come X” + profilo/Esci; i form restano per cambiare account. | | ☐ |
| SITE-LOGIN-06 | Errori 2014 `#FAE5E5`/`#CC0000`; nessun errore grezzo del server. | | ☐ |

### 2.6 Profilo (`profile.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-PROFILE-01 | Due colonne: sinistra 484 con h2 30, `@username · dal …`, avatar 352 blocky, stats `Giochi / Visite / Preferiti`, azioni per ruolo. | | ☐ |
| SITE-PROFILE-02 | Destra con tab verticali 35 px `Giochi`; `Preferiti` solo nel proprio profilo; pannello con bordo `#CCC` e griglia 2 colonne. | | ☐ |
| SITE-PROFILE-03 | Card owner con badge visibilità testuale, versione, visite, preferiti e azioni `Modifica`, `Versioni`, `Gioca`. | | ☐ |
| SITE-PROFILE-04 | Profilo pubblico: solo giochi pubblici, nessun badge e nessuna azione owner; avatar blocky con `aria-label`. | | ☐ |
| SITE-PROFILE-05 | Empty: “Non hai ancora pubblicato giochi…”, “Questo autore non ha giochi pubblici.”, “Nessun gioco preferito.”. | | ☐ |
| SITE-PROFILE-06 | Dialog Modifica: titolo 27, campi titolo/descrizione/visibilità, Salva verde, Annulla grigio, alert 2014. | | ☐ |
| SITE-PROFILE-07 | Dialog Versioni: tabella 2014 (Versione, Data, Dimensione, Azioni), badge corrente, Ripristina blu, conferma 2014, Chiudi grigio. | | ☐ |
| SITE-PROFILE-08 | Rollback append-only: crea una nuova versione, non cancella le successive; titolo/descrizione/visibilità restano invariati. | | ☐ |
| SITE-PROFILE-09 | Il live delle card si aggiorna ogni 12 s senza layout shift. | | ☐ |
| SITE-PROFILE-10 | Sotto 480 l'avatar scende a 200 px; la griglia va a 1 colonna sotto 700. | | ☐ |

### 2.7 Moderazione (`admin.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-ADMIN-01 | Due sezioni impilate con tabelle 2014: “Segnalazioni aperte (N)” e “Giochi nascosti (N)” con le colonne approvate. | | ☐ |
| SITE-ADMIN-02 | Riga segnalazione: titolo link + badge Visibile/Nascosta, autore 12, motivo, dettagli, `Ignora` e `Nascondi` (testo/bordo rosso). | | ☐ |
| SITE-ADMIN-03 | Riga nascosta: Gioco, Autore, Motivo, Data, `Ripristina` verde. | | ☐ |
| SITE-ADMIN-04 | Hide/restore richiedono conferma con modale 2014, default sicuro `Annulla`. | | ☐ |
| SITE-ADMIN-05 | Empty “Nessuna segnalazione aperta.” / “Nessun gioco nascosto.”. | | ☐ |
| SITE-ADMIN-06 | Non-admin: box “Questa pagina è riservata agli amministratori.” + link home. | | ☐ |
| SITE-ADMIN-07 | Sotto 700 le tabelle scrollano in orizzontale senza rompere la pagina. | | ☐ |

### 2.8 Studio (`studio.html`)

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| SITE-STUDIO-01 | Due colonne 600 + 300, h1 32, intro 14/1.5, box download con due `btn-large` verdi Windows/Linux e meta zip/x86_64. | | ☐ |
| SITE-STUDIO-02 | Nota 404 in piccolo che rimanda a `./build_studio.sh`; requisiti e comandi in `<code>`. | | ☐ |
| SITE-STUDIO-03 | Destra: box “Come pubblicare” con lista numerata, box “Server locale” con comando/URL, `Torna ai giochi` blu. | | ☐ |
| SITE-STUDIO-04 | Nessun hero moderno con gradienti/radius; nessun asset esterno. | | ☐ |

## 3. Card, media e avatar

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| MEDIA-01 | Card 202 px, thumb 192×108, bordo `#D2D2D2`, titolo 14/600 una riga con ellissi, meta 12 su due righe fisse. | | ☐ |
| MEDIA-02 | Meta riga 1 `di <autore>` + ` · N che giocano` verde solo se live >0; riga 2 `<N> visite · ★ <N>` con stella oro e `aria-label="<N> preferiti"`. | | ☐ |
| MEDIA-03 | Card interamente link; autore non linkato; nessun avatar nella card; nessun link annidato. | | ☐ |
| MEDIA-04 | Hover/focus: barra `Gioca` 22 px dal basso, titolo sottolineato, focus ring; nessun lift/ombra/transform. | | ☐ |
| MEDIA-05 | Placeholder a strati cielo/prato/stud/iniziale, palette deterministica dall'hash, iniziale 46/84/76/40/18 px secondo il contesto. | | ☐ |
| MEDIA-06 | Immagine rotta: l'`<img>` viene rimossa, il placeholder resta, nessun layout shift. | | ☐ |
| MEDIA-07 | Avatar blocky SVG da `avatar_color`, testa/braccia `#F5CD30`, gambe scurite 25%, fallback `#9E9E9E`, 48 e 352 (200 sotto 480). | | ☐ |
| MEDIA-08 | Hero 430×230, sidebar 300×160 e 64×36, dettaglio 500×281: tutti `object-fit: cover` center, bordo corretto, `alt` corretto. | | ☐ |
| MEDIA-09 | Stella oro, live verde testuale, Nascosta warning testuale; nessun altro accento. | | ☐ |
| MEDIA-10 | Nessuna migrazione thumbnail, nessun endpoint nuovo, `thumbnail_url` invariato con `?v=`. | | ☐ |

## 4. Client — HUD e widget

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| HUD-CHROME-01 | Nessuna topbar in-canvas e nessun nome giocatore nell'HUD: brand, titolo, autore, conteggio e `Esci` stanno solo nella barra HTML; il nome è nella player list. | | ☐ |
| HUD-CHAT-01 | Log in alto a sinistra, x=0/y=5, 500×120, font Source Sans 3 12/15, bianco outline 1, rientro 12, nessuno sfondo. | | ☐ |
| HUD-CHAT-02 | 8 righe visibili, storico 20, dissolvenza 45 s/0,5 s, nuove in basso, niente timestamp/tab/scrollbar. | | ☐ |
| HUD-CHAT-03 | Nomi colorati con la palette a 8 e hash dei byte UTF-8; system in oro; niente BBCode dell'utente. | | ☐ |
| HUD-CHAT-04 | Input full-width 20 px in basso, `CHAT_BAR`, focus `CHAT_BAR_FOCUS` + bordo cyan 2 px, placeholder corretto. | | ☐ |
| HUD-CHAT-05 | Si apre con click, `/` e Invio; Invio invia; Esc chiude; vuoto chiude; 120 caratteri; movimento bloccato mentre è aperto. | | ☐ |
| HUD-CHAT-06 | Ospite: riga oro, input disabilitato, `/`/Invio/click non lo aprono; nessun invio lato client. | | ☐ |
| HUD-CHAT-07 | Storico azzerato a nuovo livello, conservato su morte/respawn; disconnessione aggiunge una riga oro. | | ☐ |
| HUD-CHAT-08 | Join/leave di altri giocatori e morte/respawn non producono messaggi in chat; la player list resta l'unica informazione. | | ☐ |
| HUD-PLAYERS-01 | Player list in alto a destra, 202 px (150+52), header 56, righe 20, max 16, nessuno scroll, pannello `UI_PANEL` 0.86 con radius 4. | | ☐ |
| HUD-PLAYERS-02 | Header `Giocatori` 24/700 + `Monete` 11/700; righe alternate; font Liberation Sans; nessun avatar o click. | | ☐ |
| HUD-PLAYERS-03 | Ordinamento alfabetico case-insensitive; locale in grassetto non pinnato; nomi lunghi con ellissi a 138 px. | | ☐ |
| HUD-PLAYERS-04 | Solo la riga locale mostra `collected/total` (o `—` se total 0); le righe remote mostrano `—`. | | ☐ |
| HUD-PLAYERS-05 | Click/Invio/Spazio sull'header collassa a 24 px con `Giocatori` 12 + chevron; stato ricordato per la sessione. | | ☐ |
| HUD-PLAYERS-06 | `peer_joined` aggiunge, `peer_left` rimuove, disconnessione toglie i remoti e lascia il locale; nuovo livello riparte dal locale. | | ☐ |
| HUD-PLAYERS-07 | Le righe non sono interattive: nessun pannello amico/report, nessun cursore a mano, nessuna icona. | | ☐ |
| HUD-HEALTH-01 | Health 170×18, centro-basso bottom 22, bordo nero, gradiente `#25B230`→`#00AB00` 45%→`#004F00`, label `Salute` 14/700. | | ☐ |
| HUD-HEALTH-02 | Riempimento con tween 0,2 s; sotto 25% rosso `#FF1C00`; valore numerico assente; sempre visibile. | | ☐ |
| HUD-HEALTH-03 | Hurt overlay rosso ai bordi, sotto l'HUD, scatta solo per danno ≥5 HP, alpha 0→0,5→0 in 0,6 s. | | ☐ |
| HUD-HEALTH-04 | Morte/respawn immediati, nessuna schermata/countdown; salute 100; chat e player list restano. | | ☐ |
| HUD-MENU-01 | Pulsante Menu a scudo 92×48, left 8/bottom 28, casa 24 + `Menu` 12, hover `rgba(255,255,255,.12)`, focus cyan. | | ☐ |
| HUD-MENU-02 | Visibile solo nel client web in place mode; nascosto in Studio Test e build nativa dev. | | ☐ |
| HUD-MENU-03 | Game Menu: shield `MENU_SHIELD`, pannello 525×430, titolo 36, pulsanti 340×50 nero/bordo `#808080`, `Riprendi` default bordo `#C1272D`. | | ☐ |
| HUD-MENU-04 | Comandi statici tra y=175 e 320: WASD, Spazio, Shift, `/ o Invio`, Esc, 12/18. | | ☐ |
| HUD-MENU-05 | Focus iniziale su Riprendi; Tab/Shift+Tab/frecce, Invio/Spazio, Esc; nessuna pausa del mondo. | | ☐ |
| HUD-MENU-06 | All'apertura chiude chat, rilascia mouse/shift lock, blocca movimento; alla chiusura ripristina e riattiva lo shift lock se era attivo. | | ☐ |
| HUD-MENU-07 | Esc priority: chat → menu → leave → reset → apre menu. | | ☐ |
| HUD-MENU-08 | Il Game Menu non contiene Impostazioni, Aiuto, Screenshot, Report o Registra: non esistono funzioni dietro. | | ☐ |
| HUD-LEAVE-01 | Leave 525×300, titolo `Lasciare questo gioco?`, pulsanti 128×50 `Resta` (default) a x=90 e `Esci` a x=313, bottom 22. | | ☐ |
| HUD-LEAVE-02 | `Resta`/Esc chiudono; `Esci` chiama `leave()` e torna a `place.html`; nessun `Riprendi` nel dialogo. | | ☐ |
| HUD-RESET-01 | Reset 525×370, titolo `Reimpostare il personaggio?`, sottotesto `Tornerai al punto di spawn.` 18 px a y=215. | | ☐ |
| HUD-RESET-02 | `Annulla` default a x=90, `Reimposta` a x=313; `Reimposta` uccide e respawna dal checkpoint. | | ☐ |
| HUD-BANNER-01 | Banner 525×80, centro orizzontale, centro al 40%, `BANNER_BG` con bordo `#C1272D`, testo 36/700 `GIOCO COMPLETATO!`. | | ☐ |
| HUD-BANNER-02 | Fade 120 ms, resta 5 s, un solo banner; aggiunge la riga oro `Traguardo raggiunto!`; niente toast. | | ☐ |
| HUD-BANNER-03 | Il banner sta sotto i menu (CanvasLayer 20) e non compare sopra Game Menu/Leave/Reset; nessuna pila di notifiche. | | ☐ |
| HUD-DEBUG-01 | FPS nascosto; F3 mostra/nasconde `FPS <n>` 11 px in basso a destra; stato non persistito. | | ☐ |
| HUD-DEBUG-02 | Backpack/hotbar, leaderboard, pillola Lock Mouse, toast e schermata di morte non esistono. | | ☐ |
| HUD-CROSS-01 | Mirino 4×4 bianco con bordo nero 1 px solo con shift lock; mouse libero = cursore di sistema. | | ☐ |
| HUD-SCALE-01 | `scale = clamp(min(w/1280, h/720), 0.8, 1.0)`; nessun upscaling oltre 1680×1000; input chat a piena larghezza. | | ☐ |
| HUD-SCALE-02 | A 1680×964, 1280×684, 1024×732, 800×564 e 640×364 l'HUD resta dentro lo schermo e leggibile. | | ☐ |
| HUD-EVENTS-01 | Eventi in chat oro con i testi di `hud-client.md` §10; benvenuto, connessione, checkpoint, monete, script, disconnessione. | | ☐ |
| HUD-EVENTS-02 | `add_system_line`/`show_banner` sostituiscono `show_message`; `print`/`warn` restano in console/Output, non nell'HUD. | | ☐ |
| HUD-THEME-01 | `RwTheme.shared()` costruisce una sola istanza; variation `Rw*` con base type, font, size, colori e outline attesi. | | ☐ |
| HUD-THEME-02 | Stylebox: menu nero/bordo, default rosso `#C1272D`, header player list, chat focus cyan, pannelli, banner, shield. | | ☐ |
| HUD-THEME-03 | `hud.tscn` e `game_menu.tscn` non contengono `theme_override_*`; nessun NinePatch/Texture UI esterna. | | ☐ |
| HUD-THEME-04 | Font Source Sans 3 e Liberation Sans caricati dal PCK; niente fallback inatteso; outline leggibile su mondo chiaro/scuro. | | ☐ |
| HUD-WEB-01 | `rw-ready` viene inviato una sola volta dopo livello costruito e personaggio spawnato, anche senza WebSocket. | | ☐ |
| HUD-WEB-02 | `rw-error` porta `{type, message, detail?}` e non parte due volte; `PlaceClient._fail` non chiama `_post_error`. | | ☐ |
| HUD-WEB-03 | In embedded non esiste il boot in-canvas; l'overlay HTML è l'unico proprietario. | | ☐ |
| HUD-WEB-04 | `rw-leave` resta invariato e torna a `place.html?id=…`. | | ☐ |
| HUD-TEST-01 | `test_theme.gd` e `test_hud.gd` passano; `test_network.gd` usa `chat_has_line`. | | ☐ |
| HUD-TEST-02 | `test_gameplay`, `test_level_io`, `test_editor`, `test_lua`, `test_publish`, `test_studio` restano verdi. | | ☐ |

## 5. Accessibilità, copy, performance e sicurezza

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| X-A11Y-01 | Contrasto: testo attenuato `#767676` 4.54:1 su bianco; footer `#C7CFDD` e legale `#AFC0D8`; focus `#00A1DA`. | | ☐ |
| X-A11Y-02 | Focus visibile 2 px/offset 1 solo da tastiera; link nei paragrafi sottolineati; target minimo 24×24. | | ☐ |
| X-A11Y-03 | Motion 120 ms, disattivato con `prefers-reduced-motion`; nessun bounce/scale. | | ☐ |
| X-A11Y-04 | Il colore non è l'unica informazione: badge testuali, live testuale, salute lunghezza+rosso, locale grassetto+nome. | | ☐ |
| X-A11Y-05 | Lighthouse: gate su `color-contrast`, `label`, `link-name`, `button-name`, `html-has-lang`, `document-title`, `viewport`. | | ☐ |
| X-COPY-01 | Nessun “esperienza/esperienze” nell'interfaccia; “Gioco/Giochi”, “Preferiti”, “N che giocano”, “Catalogo” solo come dominio. | | ☐ |
| X-COPY-02 | Messaggi server-origin tradotti da `RW.localizeServerMessage`; nessun “like/online” visibile; titoli/descrizioni utente intatti. | | ☐ |
| X-COPY-03 | Nessun testo in inglese, nessun “© 2014”, anno 2026, nessun link morto. | | ☐ |
| X-PERF-01 | Nessuna richiesta di terze parti; font self-hosted con `font-display: swap`; nessun CDN. | | ☐ |
| X-PERF-02 | Nessun errore console o 404; polling senza layout shift; dimensioni CSS/JS/font registrate. | | ☐ |
| X-SEC-01 | CSP invariata; nessun nuovo origin in `script-src/style-src/img-src/font-src/connect-src`. | | ☐ |
| X-SEC-02 | Nessuna modifica a `server/`, API, DB, relay o formato livello; `git diff main...aesthetic-2014 -- server/` vuoto. | | ☐ |
| X-DOC-01 | `docs/roblox-2014/` contiene spec e documenti canonici; `GLOSSARY.md` alla root; tracker in `.scratch/`. | | ☐ |
| X-DOC-02 | `AGENTS.md` aggiornato con nuovi path, comandi, font, HUD e generatore scene. | | ☐ |
| X-DOC-03 | `acceptance.md` compilato con evidenze; contact sheet committate in `docs/roblox-2014/evidence/`. | | ☐ |

## 6. Gate finale e sign-off

| ID | Criterio | Evidenza | Esito |
|---|---|---|---|
| X-GATE-01 | Gate fast verde su tutte le PR. | | ☐ |
| X-GATE-02 | Gate full verde: test Godot completi, `test_network`/`test_publish`/`test_studio`, checker, export Web, smoke `play.html`. | | ☐ |
| X-GATE-03 | Matrice visuale completa acquisita e archiviata; nessuna regressione nota. | | ☐ |
| X-GATE-04 | Revisione umana di contact sheet + acceptance completata. | | ☐ |
| X-GATE-05 | Merge commit `aesthetic-2014` → `main`; rollback documentato (`git revert -m 1 <merge>`). | | ☐ |

## 7. Firma

| Ruolo | Nome | Data | Esito |
|---|---|---|---|
| Implementazione | | | |
| Revisione visiva | | | |
| Merge | | | |
