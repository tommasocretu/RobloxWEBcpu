# Specifica consolidata — estetica Roblox 2014

> **Versione 1.0 — 28 ottobre 2026. Congelata.**
> Handoff unico per il re-skin 2014 del sito e del client di RobloxWeb.
> Questa spec raccoglie tutte le decisioni approvate nei ticket 01–10 e le rende
> eseguibili senza rileggere il tracker. I documenti canonici linkati qui sotto fanno
> parte della specifica: contengono le tabelle complete, mentre questa pagina fissa
> perimetro, scelte, superfici, sequenza e verifica.
>
> **Change control:** ogni scostamento visivo o di UX passa da un nuovo ticket in
> `.scratch/roblox-2014-aesthetic/issues/` e da un aggiornamento di
> `.scratch/roblox-2014-aesthetic/map.md` prima del codice. Nessuna decisione di
> design viene presa dentro una PR.

## 1. Esito in una pagina

Il re-skin applica la pelle di **metà 2014** alle funzioni già esistenti (M1–M5) del
sito e del client, senza toccare gameplay, livello, server, API, DB o relay.

- **Sito:** header blu `#114081` alto 36 px, colonna 970 px (home 1180 px), fonte
  Source Sans 3 14 px/1.428, squadrato e senza ombre, nuova pagina `games.html`,
  dialoghi 2014 al posto di `confirm()`, lessico italiano “Giochi / Preferiti /
  che giocano”.
- **Client:** barra HTML 36 px fuori dall'iframe, nessuna topbar in-canvas, HUD 2014
  dentro il CanvasLayer (chat, player list, salute, Menu a scudo, Game Menu nero/rosso,
  banner, debug F3), scala `0.8–1.0`, nessun backpack/toast/schermata di morte.
- **Media:** master thumbnail 512×288 16:9 invariato, card 202/192×108, placeholder
  originale cielo/prato/stud/iniziale, avatar blocky SVG dal colore utente, hero
  430×230, sidebar 300×160 e 64×36, dettaglio 500×281. Nessuna migrazione server.
- **Godot:** `Theme` runtime costruito da `rw_tokens.gd` in `themes/rw_theme.gd`,
  variation `Rw*`, font TTF Source Sans 3 e Liberation Sans, `StyleBoxFlat`, scudo in
  `_draw`, client con `CONTENT_SCALE_MODE_DISABLED` e design space `viewport / s`.
- **Consegna:** 10 PR foundation-first sul branch `aesthetic-2014`, merge finale
  atomico senza feature flag, gate fast per PR e gate full finale, evidenze visuali
  con contact sheet.
- **Invarianti:** zero modifiche a `server/`, API, DB, relay e formato livello; zero
  feature 2014 finte; zero asset o logo Roblox reali.

### 1.1 Documenti canonici

| Documento | Cosa fissa | Uso |
|---|---|---|
| [`tokens.md`](tokens.md) | Tutti i token CSS e GDScript, tipografia, spazi, stati, accessibilità | Fonte unica dei valori; nessun altro documento li ridefinisce |
| [`site-map.md`](site-map.md) | Chrome, componenti, pagina per pagina, stati, copy, responsive | Implementazione delle PR 2–5 |
| [`hud-client.md`](hud-client.md) | Barra `play.html`, caricamento, chat, player list, salute, menu, banner, scala | Implementazione delle PR 6–9 |
| [`media-rules.md`](media-rules.md) | Thumbnail, card, placeholder, avatar blocky, hero, sidebar, dettaglio | Implementazione delle PR 2–5 |
| [`godot-theme.md`](godot-theme.md) | `RwTheme`, `RwLayout`, variation, font, content scaling, test headless | Implementazione delle PR 6–8 |
| [`implementation-plan.md`](implementation-plan.md) | Sequenza PR, invarianti, gate, harness, rischi | Esecuzione e review |
| [`acceptance.md`](acceptance.md) | Checklist con ID stabili e firma finale | Verifica e sign-off |
| [`../GLOSSARY.md`](../../GLOSSARY.md) | Lessico di dominio e divieti di traduzione | Copy e review |
| [`research/sito-2014.md`](research/sito-2014.md) | Fonti primarie del sito: snapshot Wayback e CSS archiviati | Riferimento storico, non decisione |
| [`research/client-2014.md`](research/client-2014.md) | Fonti primarie del client: CoreScripts e screenshot datati | Riferimento storico, non decisione |
| [`prototype/README.md`](prototype/README.md) | Prototipo approvato, varianti home B e client B | Riferimento visivo usa-e-getta |
| [`evidence/README.md`](evidence/README.md) | Convenzioni delle contact sheet finali | Chiusura PR 10 |

## 2. Riferimento, identità e perimetro

### 2.1 Riferimento del sito

Il riferimento è il **sito desktop di metà 2014** (giugno–agosto), non la home di
novembre 2014 e non l'header grigio successivo.

- Header **blu `#114081` alto 36 px**, non l'header grigio `#343434` a 50 px presente
  nel CSS ma non attivo nei snapshot di giugno–agosto.
- Colonna **970 px** per catalogo, dettaglio, login, profilo, moderazione e Studio;
  **1180 px** per la home B.
- Testo 14 px/1.428, link `#0055B3`, CTA verdi `#007001` e blu `#0852B7`.
- Le fonti primarie (snapshot e CSS) sono elencate in
  [`research/sito-2014.md`](research/sito-2014.md) §1 e §8.

### 2.2 Riferimento del client

Il riferimento è il **client desktop di metà 2014** (giugno), prima della topbar
arrivata il 23 aprile 2015 e prima del Game Menu grigio/blu del 27 agosto 2014.

- **Nessuna topbar in-game.** La barra con titolo, autore, conteggio ed `Esci` è chrome
  del sito e vive nell'HTML di `play.html`, fuori dall'iframe.
- Menu a scudo in basso a sinistra, chat 12 px in alto a sinistra, player list in alto a
  destra (150 px di base + colonna `Monete` da 52 px = 202 px, senza avatar), salute
  170×18 in basso al centro, Game Menu nero/rosso su Esc.
- Il backpack 9×54 px è documentato come riferimento storico, ma **non viene
  replicato**: il gioco non ha tool/inventario, quindi non esiste hotbar.
- Le fonti primarie (CoreScripts, screenshot, wiki datate) sono in
  [`research/client-2014.md`](research/client-2014.md) §14.

### 2.3 Prototipo approvato

Il prototipo ha confrontato tre home e tre client. Le scelte valide sono:

- **Home B:** 1180 px, hero, 4 colonne 16:9, senza sidebar.
- **Catalogo a 970 + sidebar:** per Giochi, profilo, dettaglio, admin e Studio.
- **Client B:** barra HTML blu 36 px come chrome del sito, HUD 2014 dentro il canvas.
- **Dettagli:** chat in alto a sinistra, monete come colonna della player list, Game
  Menu nero/rosso con `Resta` come default e flusso a due passi `Esc → Esci → conferma`.

Il prototipo è archiviato in [`prototype/`](prototype/README.md), apre sulla variante B
e non va promosso a produzione. Le varianti A e C restano solo per confronto.

### 2.4 Fedeltà, identità e lingua

- **Fedeltà:** pelle 2014 su layout e funzioni attuali; non è un clone strutturale 1:1
  delle pagine 2014. Le funzioni M1–M5 restano tutte.
- **Identità:** “RobloxWeb” originale in stile 2014. Nessun logo, screenshot, sprite o
  asset Roblox reale. Wordmark RobloxWeb e stud disegnati da noi.
- **Font:** Source Sans 3 al posto di Source Sans Pro (successore OFL); Liberation Sans
  al posto di Arial nel client legacy (OFL, metric-compatibile).
- **Lingua:** il sito resta in italiano. Il lessico 2014 è adattato, non tradotto in
  inglese.
- **Responsive:** densità 2014 sopra i 1000 px; sotto, degrado semplice e dignitoso.
  Non si inventa una UI mobile 2014.
- **Niente dark mode:** il 2014 non ce l'aveva e il re-skin non la introduce.
- **Niente feature finte:** Tix, Builders Club, catalogo merci, forum, party,
  leaderboard, notizie, top creatori, video, splash login, “Play Now” sprite e widget
  social non esistono nel prodotto e non vengono simulati.

### 2.5 Fuori scope

- Implementare funzioni 2014 assenti oggi: solo estetica, nessuna parità funzionale.
- Studio desktop, editor, start screen di Studio e build nativa dev (`LevelSelect`,
  `Menu`).
- UI mobile/touch del 2014.
- Modifiche a gameplay, livello, server, API, DB, relay o formato `.rwl.json`.
- Asset e logo Roblox reali.
- Nuovi formati immagine (WebP/AVIF) o resize/crop lato server.
- Nuovi test runner, CI GitHub o build step per il sito.

## 3. Lessico e copy

Il lessico vincolante è in [`GLOSSARY.md`](../../GLOSSARY.md). Nell'interfaccia:

| Concetto | Termine UI | Divieto |
|---|---|---|
| Unità creata e pubblicata | **Gioco / Giochi** | “Esperienza” nelle etichette |
| Segnalazione positiva | **Preferiti** | “Like”, “mi piace” |
| Giocatori collegati | **N che giocano**, **Giocano ora** | “Online”, “live” come etichetta |
| Insieme dei giochi pubblici | **Giochi** | “Catalogo” come UI (resta termine di dominio) |
| Accesso senza account | **Gioca come ospite** | “Continua come ospite” |
| Ritorno | **Torna ai giochi** dove esiste `games.html` | “Torna alla home” |
| Errore di contenuto | **Gioco non trovato** | “Esperienza non trovata” |
| Pulsante di uscita dal gioco | **Esci** | “Leave” |
| Dialogo di uscita | **Lasciare questo gioco?** | “Lasciare l'esperienza?” |
| Salute | **Salute** | “Health” |
| Valuta locale | **Monete** | “Coins” |
| Lista giocatori | **Giocatori** | “Players” |
| Editor desktop | **Studio** | “Editor web”, “IDE” |

Regole di copy:

1. Nessuna occorrenza visibile di “esperienza/esperienze”; il termine resta solo nel
   dominio e nel marketing.
2. “Place” compare solo in codice, API e database.
3. Nessun testo in inglese nell'interfaccia.
4. Anno corrente **2026**; nessun “© 2014”.
5. Nessun link morto: Chi siamo, Termini, Privacy e Forum non esistono e non vanno
   linkati.
6. I messaggi che arrivano dal server vengono tradotti lato client da
   `RW.localizeServerMessage()`: “esperienze” → “giochi”, “like” → “preferiti”, con
   fallback locale per 401/403/404/429/503. Titoli e descrizioni scritti dagli utenti
   non si toccano.
7. I testi dell'HUD sono quelli di [`hud-client.md`](hud-client.md) §12; i testi delle
   pagine sono quelli di [`site-map.md`](site-map.md) §3.

## 4. Token e accessibilità

### 4.1 Principi

1. Il 2014 è **chiaro, denso e squadrato**: bianco, header blu, testo 14 px, card
   192×108, niente ombre, niente radius sul sito.
2. Il colore non è decorazione: blu = link/azione neutra, verde = azione primaria e
   positivo, rosso = errore/pericolo, oro = sistema/notifica in-game.
3. Il testo si legge: i valori 2014 che non passano il contrasto vengono corretti, non
   copiati.
4. Un solo set di valori: CSS e Godot leggono la stessa tabella; un checker impedisce
   che divergano.

### 4.2 Valori non negoziabili

La tabella completa è [`tokens.md`](tokens.md) §2–3. Questi valori ricorrono in tutta
la spec e non si cambiano senza un nuovo ticket.

| Ambito | Token / valore |
|---|---|
| Header | `--rw-color-header` `#114081`, altezza 36 px, divisori `#7394C1` |
| Footer | `--rw-color-footer` `#123F83`, testo `#C7CFDD`, legale `#AFC0D8` |
| Canvas / testo | `#FFFFFF` / `#343434`; secondario `#666666`; attenuato `#767676` |
| Link | `#0055B3`; hover solo underline |
| CTA primaria | `#007001`; hover `#005A01`; disabilitata `#99C699` |
| CTA neutra | `#0852B7`; hover `#06408F`; disabilitata `#9CBAE2` |
| CTA negativa | `#565656`; hover `#404040`; disabilitata `#BBBCBB` |
| Bordi | standard `#CCCCCC`; input `#A7A7A7`; forte `#777777`; tabelle/tab `#9E9E9E` |
| Superfici | sottile `#F1F1F1`; tab `#D6D6D6`; tab hover `#E9E9E9`; box `#E1E1E1` |
| Errore | sfondo `#FAE5E5`, bordo `#CC0000` |
| Info | sfondo `#E5EFFA`, bordo `#0066CC` |
| Warning | sfondo `#FFF4D6`, bordo `#AA6611` |
| Focus | `#00A1DA`, outline 2 px, offset 1 px, solo `:focus-visible` |
| Tipografia sito | Source Sans 3, body 14 px/1.428, small 12, tiny 11, h1 32/700, h2 30/400, h3 15/700, nav 15/600, modale 27/700 |
| Tipografia client | Source Sans 3 per chat/salute/banner/debug; Liberation Sans per Game Menu/player list |
| Larghezze | contenuto 970 px, home 1180 px, card 202/192×108, sidebar 300 px |
| Spazi | 5, 7, 10, 15, 20, 25, 30 px |
| Radius / ombre | sito 0 (tooltip 3 px); client 4 px solo pannello player list; nessuna ombra |
| Motion | 120 ms ease; disattivata con `prefers-reduced-motion` |
| Z-index sito | header 30, dropdown 40, modale 100, toast 110 |

**Palette nomi chat (8):** `#C4281C`, `#0D69AC`, `#27462D`, `#6B327C`, `#DA8541`,
`#F5CD30`, `#B480FF`, `#D7C59A`.

**Stati client:** `UI_PANEL` `rgba(30,58,120,0.86)`, `UI_PANEL_DARK`
`rgba(23,42,79,0.90)`, `UI_BORDER` `#6E7FA6`, `CHAT_BAR` `rgba(0,0,0,0.75)`,
`CHAT_BAR_FOCUS` `rgba(0,0,0,0.88)`, `MENU_SHIELD` `rgba(51,51,51,0.40)`,
`MENU_DEFAULT` `#C1272D`, `GOLD` `#FFD700`, `FOCUS` `#00A1DA`.

### 4.3 Deviazioni di accessibilità

Sette deviazioni deliberate, tutte dichiarate in [`tokens.md`](tokens.md) §4:

1. Testo attenuato `#767676` (4.54:1 su bianco) al posto di `#999` (2.85:1).
2. Footer `#C7CFDD` / `#AFC0D8` al posto di `#AAA` / `#899FC1`.
3. Focus ring 2 px `#00A1DA` con offset 1 px; il 2014 aveva `outline: none`.
4. Link nei paragrafi sottolineati; nav e card senza underline.
5. Area cliccabile minima 24×24 px anche se il bottone resta 18–25 px.
6. Motion 120 ms, disattivata con `prefers-reduced-motion`.
7. Il colore non è mai l'unica informazione: badge testuali, “che giocano” esplicito,
   salute con lunghezza + rosso, riga locale in grassetto + nome.

### 4.4 Font e sincronizzazione

- **Sito:** Source Sans 3 woff2 300/400/600/700 in
  `WEBhtml/assets/fonts/source-sans-3/` + `OFL.txt`; `font-display: swap`; preload di
  400 e 600. Nessuna richiesta a Google Fonts o CDN.
- **Client:** `SourceSans3-Regular.ttf`, `SourceSans3-Bold.ttf`,
  `LiberationSans-Regular.ttf`, `LiberationSans-Bold.ttf` in
  `Godot/robloxwebengine/assets/fonts/` + licenze OFL; preload in `RwTheme`, così
  entrano nel PCK Web.
- **Sincronizzazione:** il `:root` di `WEBhtml/assets/site.css` è la fonte canonica;
  `scripts/ui/rw_tokens.gd` è il mirror GDScript; `tools/check_design_tokens.py`
  confronta il sottoinsieme condiviso (colori e misure) e calcola il contrasto dei
  token di testo. Gira a mano e nel gate fast.
- **Nessun generatore JSON:** il sito non ha build step e non se ne introduce uno per
  il design. Il checker dà la stessa garanzia senza generare file.

## 5. Chrome e componenti del sito

### 5.1 Header

- 36 px, `#114081`, inner 970 px (1180 sulla home), logo a sinistra, nav orizzontale,
  account a destra, divisori `#7394C1`, padding orizzontale coerente con i token.
- **Guest:** Home · Giochi · Studio · `Registrati` (link bianco) · “oppure” `#9EC3E7` ·
  `Accedi` (`btn-control-large`) · `Ospite` (`btn-control`).
- **Account:** Home · Giochi · Studio · Profilo · `Moderazione` (solo admin) · username
  link al profilo · tag `Ospite` se pertinente · `Esci` (`btn-control`).
- **Pagina attiva:** voce bianca in grassetto; niente underline o pill.
- **Hover:** `rgba(255,255,255,0.14)`.
- **Niente ricerca globale:** la ricerca vive solo in `games.html`.
- **Responsive:** sotto 1000 px la nav si compatta (Home, Giochi, account); sotto 700
  restano brand, account e `Giochi`.
- Implementazione: `RW.headerHTML()` con stato ospite/account/admin, pagina attiva via
  `data-page`, nessun `header-search`.

### 5.2 Footer

- `#123F83`, inner 970/1180, link solo a pagine reali: Home · Giochi · Studio · Profilo
  (se loggato) · Moderazione (se admin).
- Legale: “© 2026 RobloxWeb — piattaforma di giochi creati dagli utenti. Progetto
  locale in sviluppo.”
- Assente in `play.html`, che è a schermo pieno.
- Implementazione: `RW.footerHTML()`, generato una volta e incluso da tutte le pagine
  con chrome.

### 5.3 Componenti condivisi

| Componente | Regola 2014 |
|---|---|
| Pulsanti | `.btn-small` 20 px, `.btn-medium` 28 px, `.btn-large` 39 px; `.btn-control` 18/21/25 px; primario verde, neutro blu, negativo grigio; hover con darkening 8%; niente radius/ombra |
| Tab | Sfondo `#D6D6D6`, bordo `#9E9E9E`, attiva bianca, testo 15/700; usate per il sort in home e nelle sezioni |
| Input | Bordo `#A7A7A7`, altezza 21 px (medium), label 14/600, focus ring 2 px `#00A1DA` |
| Alert | Errore `#FAE5E5`/`#CC0000`, info `#E5EFFA`/`#0066CC`, warning `#FFF4D6`/`#AA6611`; bordo 1 px, raggio 0, padding 10 |
| Dialoghi | `<dialog>` nativo, bianco, titolo 27/700/−1, corpo 14, azioni a destra, overlay `rgba(0,0,0,0.45)`; niente blur, niente radius |
| Tabelle | Header `#F1F1F1`, bordi `#CCC`, padding 5, righe alternate `#EEE`; usate in admin e storico versioni |
| Badge | Quadrato/2 px, 10–11 px bold, bordo 1 px, **testo sempre presente**: Pubblica, Non elencata, Privata, Nascosta, Admin |
| Empty/loading | Box `#F1F1F1` bordo `#CCC`, testo 14 `#666`, “Caricamento…” senza skeleton |
| Avatar | 48×48 autore, 352×352 profilo (200 sotto 480); blocky SVG dal colore utente, bordo 1 px `#CCC` |
| Thumb | 192×108 card, 500×281 dettaglio, 430×230 hero, 300×160 sidebar, 64×36 mini |
| Ricerca | Locale al catalogo: input 20 px, bordo `#BBB`, icona 16×16 |
| Paginazione | Nessun pager: l'API restituisce tutti i giochi, deviazione dichiarata |

- **Niente ombre, radius (tranne tooltip), gradienti o animazioni di lift.**
- **Focus ring** 2 px `#00A1DA` con offset 1 su link, bottoni, input, tab e card;
  target minimo 24×24.
- **Niente componenti scuri** residui nelle pagine con chrome.

## 6. Pagine del sito

Tutte le pagine hanno `lang="it"`, title coerente e nessun errore console o 404 di
asset. La struttura completa e gli stati sono in [`site-map.md`](site-map.md) §3.

### 6.1 Home — `index.html`

- **Hero 1180** in stile box 2014 (bordo, blu, niente radius): h1 32 “Benvenuto su
  RobloxWeb”, paragrafo 15, CTA verde `Gioca ora` (ancora `#giochi`) + CTA blu `Crea`
  (→ `studio.html`); a destra art 430×230 del gioco più popolare con badge
  “In evidenza · <titolo>”.
- L'art e il badge sono un unico link alla pagina del gioco, con
  `aria-label="In evidenza: <titolo>"`; se il gioco non ha thumbnail si usa il
  placeholder con iniziale 76 px; se non ci sono giochi l'art è nascosta e resta il
  testo.
- **Sezione Giochi:** h2 30/400 “Giochi popolari”, tab 2014 `Popolari / Più apprezzati
  / Recenti` a destra, griglia 4 colonne, **8 card**, pulsante blu `btn-medium` “Vedi
  tutti” → `games.html`.
- **Stati:** caricamento “Caricamento…”, errore alert 2014, empty “Nessun gioco
  trovato.” + link “Vedi tutti i giochi”.
- **Dati:** `/api/places?sort=…`; il primo gioco popolare alimenta l'hero. Polling live
  10 s, aggiorna “N che giocano” senza ridisegnare la griglia e senza layout shift.
- **Auth:** l'header gestisce accedi/ospite/profilo; l'hero non duplica “Ciao, nome”.
  Il guest button resta nell'header e in login.
- **Copy:** “Giochi”, “che giocano”, “preferiti”; niente “esperienze”.

### 6.2 Giochi — `games.html` (nuova)

- Pagina 970 px, h1 “Giochi” 32.
- Riga filtri: select `Ordina per` (Popolari / Più apprezzati / Recenti) + campo ricerca
  locale + icona. **Niente filtri Tempo/Genere finti:** l'API non li supporta.
- Layout: main 610 (griglia 3×202, card 192×108, 9+ giochi) + sidebar 300.
- Sidebar con soli dati reali: “In evidenza” (gioco più popolare, thumb 300×160 +
  `Gioca`), “Più giocati” (primi 3, thumb 64×36, titolo, visite), “Crea il tuo gioco”
  (box con link a Studio). Se non ha dati, la sidebar sparisce.
- URL `games.html?q=&sort=`; il form usa GET ed è inviabile da tastiera.
- Empty “Nessun gioco trovato.” + “Azzera ricerca”. Nessuna paginazione.
- Responsive: sotto 1000 px 2 colonne; sotto 700 px 1 colonna e sidebar in stack.

### 6.3 Dettaglio gioco — `place.html`

- 970 px; link `← Torna ai giochi` (o home); h1 32 sopra le due colonne; autore 14 con
  avatar 48 linkato al profilo.
- **Sinistra 500:** media 500×281 bordo `#CCC`, descrizione 14/1.4, eventuale
  “aggiornata il…”.
- **Destra 240:** `Gioca` verde `btn-medium` largo 150; `★ N preferiti` come
  `btn-control` (stella oro se attivo, grigia se no); link `Segnala`; box statistiche
  con righe `Visite / Giocano ora / Versione / Aggiornata`.
- **Ospite anonimo:** box “Accedi per giocare” 250 px con `Accedi`, `Registrati`,
  `Gioca come ospite`; il play button resta e reindirizza al login.
- **Owner:** link `Modifica` → profilo; il dialog di modifica resta nel profilo.
- **Nascosto:** alert warning 2014; non-admin ha play disabilitato “Non disponibile”,
  like/report nascosti; l'admin può giocare.
- **Preferiti:** l'etichetta è “Preferiti” con stella; l'API `/like` resta invariata.
- **Segnala:** dialog 2014 “Segnala gioco”, select motivo, textarea, `Invia
  segnalazione` verde, `Annulla` grigio, focus corretto; niente `confirm()`.
- **403/404:** box errore 2014 “Gioco non trovato” + link; nessun errore grezzo.
- Polling 10 s su visite/live/preferiti, senza layout shift.

### 6.4 Gioca — `play.html`

La specifica completa della barra, del caricamento e dell'handshake è nel §10 e in
[`hud-client.md`](hud-client.md) §4–5.

- Barra blu 36 px: brand · `<titolo> · di <autore>` · `N che giocano` · `Esci`
  (`btn-control`). Niente nav completa, niente nome giocatore.
- Iframe `width: 100%`, `height: calc(100vh - 36px)`, bordo 0, sfondo nero; nessun
  header/footer del sito.
- Overlay nero con `CARICAMENTO` 12 px maiuscolo, barra 300×18 indeterminata finché
  non arriva `rw-ready`.
- Errore: box bianco 2014 “Impossibile avviare il gioco”, messaggio 14, detail 12,
  `Torna al gioco` grigio; la barra resta usabile.
- `Esci` e `rw-leave` tornano a `place.html?id=…`.
- Responsive <700: restano titolo con ellissi + `Esci`; la barra resta alta 36 px.
- La pagina richiede una sessione (account o ospite); senza sessione si va al login.

### 6.5 Accedi / Registrati — `login.html`

- 970 px, **due colonne 465 + 484, entrambe visibili, niente tab**.
- **Sinistra:** pannello “Accedi a RobloxWeb” con titolo h2 30/400, label + input
  medium 21 px, `Accedi` blu `btn-medium`, `Annulla` grigio, `Gioca come ospite` link
  blu.
- **Destra:** pannello “Registrati” con titolo h2 30/400, username/password/ripeti,
  footnote 12 `#666`, `Crea account` verde `btn-medium`.
- Nota demo `demo/demo1234` in footnote 12 px, solo sviluppo.
- Se già loggato: alert info “Sei connesso come X” + link profilo/Esci; i form restano
  per cambiare account.
- Errori 2014 `#FAE5E5`/`#CC0000`; nessun errore grezzo del server.
- Responsive: stack, login prima, registrazione dopo.

### 6.6 Profilo — `profile.html`

- 970 px, **due colonne**.
- **Sinistra 484:** h2 “<Nome>” 30, `@username · dal …` 12, avatar 352×352 bordo `#CCC`,
  box statistiche `#EEE` con righe `Giochi / Visite / Preferiti`, azioni `Apri Studio`
  + `Esci` (`btn-control-large`); ospite: `Registrati` + `Esci`; profilo pubblico:
  `Sfoglia i giochi`.
- **Destra:** tab verticali 35 px (`Giochi`, `Preferiti` solo per il proprio profilo),
  pannello con bordo `#CCC`, griglia 2 colonne di card 202×108.
- **Giochi:** card con badge visibilità **testuale**, versione, visite, preferiti; sotto
  la card `Modifica`, `Versioni`, `Gioca` (solo owner). Pubblico: solo giochi pubblici,
  nessun badge.
- **Preferiti:** “Giochi preferiti”, stesse card ma senza azioni owner.
- **Empty:** “Non hai ancora pubblicato giochi. Apri Studio e premi Pubblica.” /
  “Questo autore non ha giochi pubblici.” / “Nessun gioco preferito.”
- **Dialog Modifica:** titolo 27, campi titolo/descrizione/visibilità, `Salva` verde,
  `Annulla` grigio, alert 2014.
- **Dialog Versioni:** tabella 2014 (Versione, Data, Dimensione, Azioni), badge
  “corrente”, `Ripristina` blu, conferma con modale 2014, `Chiudi` grigio.
- Polling live 12 s sulle card, senza layout shift.
- Sotto 700 px la griglia va a 1 colonna; sotto 480 l'avatar scende a 200 px.

### 6.7 Moderazione — `admin.html`

- 970 px, h1 32, `← Torna alla home`.
- **Due sezioni impilate, non colonne di card**, ciascuna con tabella 2014:
  - “Segnalazioni aperte (N)”: colonne Gioco, Motivo, Segnalato da, Data, Azioni. Riga:
    titolo link + badge Visibile/Nascosta, autore 12; motivo; dettagli 12; `Ignora`
    `btn-control`, `Nascondi` `btn-control` con testo/bordo rosso.
  - “Giochi nascosti (N)”: colonne Gioco, Autore, Motivo, Data, Azioni; `Ripristina`
    `btn-control` verde.
- Conferme con modale 2014 (Nascondere/Ripristinare), default sicuro `Annulla`.
- Empty: “Nessuna segnalazione aperta.” / “Nessun gioco nascosto.”
- Non admin: box “Questa pagina è riservata agli amministratori.” + link home.
- Sotto 700 px le tabelle scrollano in orizzontale senza rompere la pagina.

### 6.8 Studio — `studio.html`

- 970 px, h1 32, due colonne fisse 600 + 300.
- Sinistra: intro 14/1.5; box download con due `btn-large` verdi `Scarica per Windows`
  / `Scarica per Linux` + meta “zip · x86_64”; nota 404 in piccolo che rimanda a
  `./build_studio.sh`; requisiti e comandi in `<code>` 2014.
- Destra: box “Come pubblicare” con lista numerata 14/1.6, box “Server locale” con
  comando e URL, `Torna ai giochi` `btn-neutral`.
- Niente hero moderno con gradienti/radius: box 2014 con bordo. Nessun asset esterno.

## 7. Media, card e avatar

La specifica completa è [`media-rules.md`](media-rules.md). I punti non negoziabili:

### 7.1 Formato e crop

| Elemento | Regola |
|---|---|
| Master | 512×288 PNG, quello che Studio cattura già (`THUMBNAIL_SIZE`) |
| Upload server | max 1 MB, max 1920×1080, PNG; invariato |
| Card | 192×108 esatti (catalogo/profilo); 16:9 fluido (home) |
| Dettaglio | 500×281 (16:9) |
| Hero | 430×230, `cover` center (ritaglio ~12 px verticale da un 16:9) |
| Sidebar featured | 300×160, `cover` center |
| Sidebar “Più giocati” | 64×36, `cover` center |
| Crop | `object-fit: cover; object-position: center`; nessun crop custom |
| Loading | card `loading="lazy" decoding="async"`; hero e dettaglio `loading="eager"` |
| Cache | `thumbnail_url` con `?v=<versione>` già fornito dall'API |

- Nessuna migrazione: le thumbnail esistenti sono già 16:9.
- Nessun resize/crop lato server; un'immagine non 16:9 viene croppata nella UI.
- Nessun nuovo formato WebP/AVIF e nessun `srcset` in questo effort.
- `thumbnail_url` resta l'unica fonte; niente endpoint o placeholder server.

### 7.2 Card

| Proprietà | Valore |
|---|---|
| Colonna catalogo | 202 px (3 colonne in 610) |
| Thumb catalogo/profilo | 192×108, bordo 1 px `#D2D2D2` |
| Home | 4 colonne fluide, thumb 16:9, gap 18×16 |
| Profilo | 2 colonne 202, thumb 192×108 |
| Card | nessun bordo/sfondo/ombra/radius; padding `0 10px 8px 0` |
| Titolo | 14/600, `#343434`, una riga, ellissi |
| Meta | 12 px, due righe fisse da 15 px, `#666` |
| Riga 1 | `di <autore>` e, se live > 0, ` · <N> che giocano` in `#007001` |
| Riga 2 | `<N> visite · ★ <N>`; stella `#FFD700`, numero `#666` |
| Autore / avatar nella card | testo non linkato; nessun avatar |
| Hover/focus | barra bianca `Gioca` alta 22 px in fondo alla thumb, bordo superiore 1 px `#777`, testo 12 px `#767676`, `bottom: -22px → 0`, `opacity: 0 → 1`, 120 ms; titolo sottolineato; focus ring 2 px `#00A1DA` |
| Motion ridotta | nessuna transizione con `prefers-reduced-motion` |

- La card è un **link unico**: immagine, titolo e meta sono un solo `<a>`; niente link
  annidati.
- Il live è testo nella meta, non una pillola o un badge sopra la thumbnail; non fa
  crescere la card.
- Se `live_players` è 0, la parte live sparisce e resta `di <autore>`.
- La stella è decorativa; il numero è leggibile e il blocco ha
  `aria-label="<N> preferiti"`.

### 7.3 Placeholder

1. Cielo: gradiente diagonale a due toni, deterministico dal gioco.
2. Prato: banda `#3F8F3F` dal 58% in basso.
3. Stud: griglia di puntini bianchi `rgba(255,255,255,0.22)`, passo 16 px (18 hero,
   20 dettaglio).
4. Iniziale: primo grafema del titolo, maiuscolo, bianco, `font-weight:700`, ombra
   dura `2px 2px 0 rgba(0,0,0,0.45)`.
5. Immagine reale sopra tutto, tranne la barra `Gioca`.

**Palette cielo (8 coppie):**

| # | Alto | Basso |
|---|---|---|
| 0 | `#7EC8E3` | `#2B6CB0` |
| 1 | `#F0B35A` | `#B5532B` |
| 2 | `#B480FF` | `#6B327C` |
| 3 | `#4FC28A` | `#27462D` |
| 4 | `#F5CD30` | `#AA6611` |
| 5 | `#DA8541` | `#7A3A3F` |
| 6 | `#9EC3E7` | `#114081` |
| 7 | `#D7C59A` | `#6B5523` |

- Il prato resta `#3F8F3F` per tutte le palette. Lo stesso gioco ha sempre lo stesso
  placeholder.
- Iniziale per contesto: card 46 px, dettaglio 84, hero 76, sidebar featured 40, mini
  18. Se il titolo è vuoto, `?`.
- L'iniziale è `aria-hidden="true"` e non è mai l'unica informazione.
- Immagine rotta: `onerror="this.remove()"` sull'`<img>`, il placeholder resta, nessun
  broken-image icon e nessun salto di layout. La thumbnail rotta non viene ritentata
  fino al refresh.

### 7.4 Avatar blocky

- SVG inline originale, derivato dal `avatar_color` stabile dell'utente.
- Testa e braccia `#F5CD30` con bordo `#B38F00`; torso `avatar_color`; gambe
  `avatar_color` scurito del 25%; bordi 2 unità nel viewBox 100×100; fondo `#EEEEEE`
  con bordo 1 px `#CCC`, nessun radius; personaggio centrato a 78%×88%; faccia minima
  con due occhi e una bocca.
- Misure: 48×48 accanto all'autore (decorativo), 352×352 nel profilo
  (`role="img"`, `aria-label="Avatar di <nome>"`), 200×200 sotto 480.
- Colore mancante o non valido: `#9E9E9E`, gambe `#6E6E6E`; non si usa l'iniziale come
  fallback.
- API: `RW.avatarHTML(user, size, decorative)`, `RW.shade(hex, -0.25)`,
  `RW.userColor`.

### 7.5 Hero, sidebar, dettaglio e accenti

- **Hero:** art 430×230, `cover` center, bordo `rgba(255,255,255,0.5)`, badge in basso
  a sinistra `In evidenza · <titolo>` su `rgba(0,0,0,0.65)`, testo 12/600, padding
  3×7, max-width `calc(100% - 20px)`, ellissi. Sotto 1000 px l'hero va in colonna e
  l'art diventa 16:9 a piena larghezza.
- **Sidebar:** featured 300×160, righe “Più giocati” 64×36, bordo `#CCC`, placeholder
  40/18 px; “Crea il tuo gioco” senza immagine. Se la sidebar non ha dati, sparisce.
- **Dettaglio:** media 500×281, `cover` center, bordo `#CCC`, `alt="Anteprima di
  <titolo>"`, placeholder 84 px; una sola immagine, nessuna galleria/video/carosello.
- **Accenti:** stella preferiti `#FFD700`; live `#007001` testuale; Nascosta `#AA6611`
  con badge testuale; tutto il resto `#343434`/`#666`/`#767676`.
- Numeri con `RW.formatNumber` (formato italiano); niente “like”, niente “online”.

## 8. Client: architettura, tema e scala

La specifica completa è [`godot-theme.md`](godot-theme.md). Il client è Godot 4.7.2,
renderer GL Compatibility, export Web **single-threaded**, nessuna GDExtension.

### 8.1 File e responsabilità

```
scripts/ui/rw_tokens.gd        valori canonici (colori, font, misure)
themes/rw_theme.gd             Theme + variation Rw*
scripts/ui/rw_layout.gd        content scale + design-space scale
assets/fonts/*.ttf             font + OFL

scenes/ui/hud.tscn             CanvasLayer 10 + Root Control → theme
scenes/ui/game_menu.tscn       CanvasLayer 30 + Root Control → theme
scenes/ui/banner.tscn          CanvasLayer 20 + Root Control → theme
scenes/ui/debug.tscn           CanvasLayer 15 + Root Control → theme
scenes/world/hurt_overlay.tscn CanvasLayer 5, nessun theme
```

| File | Ruolo |
|---|---|
| `scripts/ui/rw_tokens.gd` | costanti `COLOR_*`, `FONT_*`, `FONT_SIZE_*`, `SIZE_*`, `OUTLINE_*`; nessun nodo |
| `themes/rw_theme.gd` | `class_name RwTheme`, `build()`, `shared()`, cache; costruisce il `Theme` |
| `scripts/ui/rw_layout.gd` | `scale_for()`, `apply()`, `use_client()`, `use_editor()` |
| `assets/fonts/` | Source Sans 3 e Liberation Sans TTF + licenze OFL |
| `scenes/ui/hud.tscn` | chat, player list, salute, Menu, mirino |
| `scenes/ui/game_menu.tscn` | shield, Game Menu, Leave, Reset |
| `scenes/ui/banner.tscn` | banner traguardo |
| `scenes/ui/debug.tscn` | FPS F3 |
| `scenes/world/hurt_overlay.tscn` | vignetta rossa, nessun tema |

### 8.2 Tema runtime

- `RwTheme.shared()` costruisce una sola istanza e la riusa; `build()` è idempotente e
  testabile headless; `reset_cache()` serve ai test.
- Il tema non viene mai mutato a runtime: gli stati sono stylebox separati.
- `RwTheme` preloada i quattro TTF, così l'export Web li include come dipendenze.
- **Nessun `.tres` statico:** duplicherebbe i valori di `rw_tokens.gd`.
- **Nessun autoload:** `RwTheme` è una classe statica con cache.
- **Nessun `theme_override_*`** in `hud.tscn` e `game_menu.tscn`: solo anchors, offset,
  size, `theme_type_variation`, testo e proprietà di gioco. Un test legge i `.tscn` e
  fallisce se trova override.
- **Niente nine-patch, PNG o texture UI:** `StyleBoxFlat`, scudo in `_draw`, gradienti
  di salute/hurt generati a runtime.

### 8.3 Type variation `Rw*`

Convenzione: prefisso `Rw`, PascalCase, base `Label`/`Button`/`LineEdit`/
`RichTextLabel`/`Panel`/`PanelContainer`.

| Variation | Base | Font / size | Colore / outline | Stylebox / note |
|---|---|---|---|---|
| Base `Label` | Label | Source Sans 3 Regular 14 | bianco, outline 0 | fallback |
| Base `Button` | Button | Liberation Sans Regular 24 | bianco | menu nero, bordo `#808080` |
| Base `LineEdit` | LineEdit | Source Sans 3 Regular 12 | bianco | chat, focus cyan |
| Base `RichTextLabel` | RichTextLabel | Source Sans 3 Regular 12 | bianco, outline 3 | chat trasparente |
| `RwLabelHealth` | Label | Source Sans 3 Bold 14 | bianco, outline 2 | `Salute` |
| `RwLabelPlayerHead` | Label | Liberation Sans Bold 24 | bianco, outline 2 | `Giocatori` |
| `RwLabelPlayerCoinsHead` | Label | Liberation Sans Bold 11 | bianco, outline 1 | `Monete` |
| `RwLabelPlayerName` | Label | Liberation Sans Regular 14 | bianco, outline 2 | righe player list |
| `RwLabelPlayerNameLocal` | Label | Liberation Sans Bold 14 | bianco, outline 2 | riga locale |
| `RwLabelPlayerCoins` | Label | Liberation Sans Bold 14 | oro `GOLD`, outline 2 | colonna Monete |
| `RwLabelMenuTitle` | Label | Liberation Sans Bold 36 | bianco, outline 2 | Menu/Leave/Reset |
| `RwLabelMenuSmall` | Label | Liberation Sans Regular 18 | bianco, outline 2 | sottotesto Reset |
| `RwLabelComandiTitle` | Label | Liberation Sans Bold 18 | bianco, outline 2 | titolo Comandi |
| `RwLabelComandi` | Label | Liberation Sans Regular 12 | bianco, outline 2 | righe comandi |
| `RwLabelBanner` | Label | Source Sans 3 Bold 36 | bianco, outline 2 | `GIOCO COMPLETATO!` |
| `RwLabelDebug` | Label | Source Sans 3 Regular 11 | bianco, outline 1 | FPS F3 |
| `RwButtonMenu` | Button | Liberation Sans Regular 24 | bianco | nero/`#808080`, focus cyan |
| `RwButtonMenuDefault` | Button | Liberation Sans Regular 24 | bianco | come sopra, bordo `MENU_DEFAULT` |
| `RwButtonPlayerHeader` | Button | Liberation Sans Bold 24 | bianco | `UI_PANEL_DARK`, bordo basso |
| `RwButtonMenuTrigger` | Button | Source Sans 3 Regular 12 | bianco, outline 2 | stylebox vuoti; scudo in `_draw` |
| `RwLineEditChat` | LineEdit | Source Sans 3 Regular 12 | bianco | `CHAT_BAR`, focus cyan |
| `RwRichChat` | RichTextLabel | Source Sans 3 Regular 12 | bianco, outline 3 | trasparente, `line_separation=1` |
| `RwPanelPlayerList` | PanelContainer | — | — | `UI_PANEL`, bordo 1, radius 4 |
| `RwPanelPlayerRow` | PanelContainer | — | — | trasparente, bordo basso 1 |
| `RwPanelPlayerRowAlt` | PanelContainer | — | — | `PLAYERLIST_ROW_ALT`, bordo basso 1 |
| `RwPanelBanner` | PanelContainer | — | — | `BANNER_BG`, bordo 1 `MENU_DEFAULT` |
| `RwPanelMenuShield` | Panel | — | — | `MENU_SHIELD` |
| `RwPanelCrosshair` | Panel | — | — | bianco, bordo 1 nero |
| `RwPanelHealthTrack` | Panel | — | — | nero, bordo 1 nero |

### 8.4 Stylebox e risorse generate

- Bottoni menu: normal `#000000` + bordo `#808080`; hover `#111111`; pressed `#000000`;
  focus trasparente + bordo 2 px `FOCUS`; disabled `#000000` + testo `TEXT_DISABLED`.
  `RwButtonMenuDefault` usa `MENU_DEFAULT` `#C1272D` in normal/hover/pressed. Radius 0,
  content margin 8/4.
- Header player list: `UI_PANEL_DARK`, bordo basso 1 px `UI_BORDER`, radius 0; hover
  `UI_PANEL`, pressed `UI_PANEL_DARK`, focus cyan. Il Button non ha testo: le due Label
  sono figlie.
- Chat: `RwLineEditChat` normal `CHAT_BAR` 0.75, focus `CHAT_BAR_FOCUS` 0.88 + bordo
  superiore 2 px `FOCUS`, read-only `CHAT_BAR`, content margin 4, radius 0.
  `RwRichChat` usa `StyleBoxEmpty`, font UI 12, outline nero 3, `line_separation=1`;
  i colori dei nomi/system sono BBCode nel testo, non nel tema.
- Pannelli: player list `UI_PANEL` 0.86 + bordo `UI_BORDER` + radius 4,
  `clip_contents=true`; righe con bordo basso `UI_BORDER` al 40%; banner `BANNER_BG`
  0.90 + bordo `MENU_DEFAULT`; shield `MENU_SHIELD` 0.40; crosshair bianco + bordo nero;
  health track nero + bordo nero.
- **Scudo Menu:** Button 92×48 con `RwButtonMenuTrigger`, ma senza StyleBox visibile;
  il poligono `(14,0) (92,0) (92,48) (0,48) (0,14)` è disegnato in `_draw`, fill
  trasparente, bordo 1 px `UI_BORDER`, hover `MENU_TRIGGER_HOVER`, focus 2 px `FOCUS`;
  casa 24×24 e testo `Menu` 12 px sopra.
- **Risorse generate:** health fill `GradientTexture2D` 1×18 verticale
  `HEALTH_TOP` → `HEALTH_MID` 45% → `HEALTH_DARK`, sostituito da `HEALTH_RED` sotto
  25%; hurt overlay `GradientTexture2D` radiale 256×256, centro trasparente → bordo
  rosso; crosshair `Panel` 4×4; righe player list `PanelContainer`.

### 8.5 Font

| File | Famiglia | Uso |
|---|---|---|
| `SourceSans3-Regular.ttf` | Source Sans 3 400 | chat, salute, banner, debug, label base |
| `SourceSans3-Bold.ttf` | Source Sans 3 700 | salute, banner, grassetti |
| `LiberationSans-Regular.ttf` | Liberation Sans 400 | Game Menu, player list, Comandi |
| `LiberationSans-Bold.ttf` | Liberation Sans 700 | titoli menu, header player list, monete |

- Import: `antialiasing = GRAY`, `hinting = LIGHT`, `subpixel_positioning = AUTO`,
  `multichannel_signed_distance_field = false`, `allow_system_fallback = true`,
  `force_autohinter = false`.
- Niente bitmap font, niente MSDF: la scala 0.8–1.0 è gestita dal canvas transform.
- Le dimensioni sono px di design: 11, 12, 14, 18, 24, 36. Non si creano varianti DPI.

### 8.6 Content scaling e design space

- Il **client** (web, build dev, Studio Test) imposta a runtime
  `Window.CONTENT_SCALE_MODE_DISABLED`: i 2D sono pixel CSS/iframe.
- **Studio/editor/start screen** restano su `CONTENT_SCALE_MODE_CANVAS_ITEMS`.
- Lo switch avviene in `_enter_tree()` di `main.gd`, prima dei `_ready` dei figli;
  StudioStart/editor chiamano `RwLayout.use_editor()` quando si entra.
- Formula: `scale = clamp(min(width / 1280, height / 720), 0.8, 1.0)`.
- `RwLayout.apply(layer, root)` imposta `layer.scale = s`, `root.position = 0` e
  `root.size = viewport / s`; gli anchor restano ai bordi fisici e i font scalano con
  il canvas.
- Va chiamato in `_ready` e su `get_viewport().size_changed` per HUD, GameMenu, Banner
  e Debug. L'hurt overlay non usa `RwLayout`: è full-rect nel CanvasLayer 5.
- Il mondo 3D usa i pixel fisici; solo HUD/Menu usano la scala.
- Sotto 640×400 non c'è garanzia.

| Viewport iframe | Scala | Design space | Chat visiva | Menu visivo |
|---|---|---|---|---|
| 1680×964 | 1.00 | 1680×964 | 500×120 | 525×430 |
| 1366×732 | 1.00 | 1366×732 | 500×120 | 525×430 |
| 1280×684 | 0.95 | 1347×720 | 475×114 | 499×409 |
| 1024×732 | 0.80 | 1280×915 | 400×96 | 420×344 |
| 800×564 | 0.80 | 1000×705 | 400×96 | 420×344 |
| 640×364 | 0.80 | 800×455 | 400×96 | 420×344 |

### 8.7 Scenes e applicazione

- `hud.tscn`: root `CanvasLayer` 10 → `Root` Control in design space,
  `mouse_filter = IGNORE`, `theme = RwTheme.shared()` in `_ready`; figli chat, player
  list, salute, input, Menu, mirino. `hud.gd` assegna il tema e chiama
  `RwLayout.apply`; connette `get_viewport().size_changed`.
- `game_menu.tscn`: root `CanvasLayer` 30 → `Root` Control in design space,
  `mouse_filter = STOP`, tema in `_ready`; shield, titolo, pulsanti, Comandi,
  Leave/Reset.
- `banner.tscn`: CanvasLayer 20 → Root in design space, `mouse_filter = IGNORE`;
  `RwPanelBanner` + `RwLabelBanner`.
- `debug.tscn`: CanvasLayer 15 → Root in design space, `mouse_filter = IGNORE`;
  `RwLabelDebug`; invisibile di default.
- `main.tscn` non riceve un tema globale. `LevelSelect`, `Menu` iniziale, Studio start
  ed editor restano con il tema Godot di default e non vengono ridisegnati.
- Il `BootOverlay` dinamico di `main.gd` sparisce nel caso embedded; il fallback
  standalone `/dev` può restare non tematizzato, fuori scope.

## 9. Client: HUD, menu e widget

La specifica completa è [`hud-client.md`](hud-client.md). Il client **non ha una
topbar in-canvas**: brand, titolo, autore, conteggio ed `Esci` stanno solo nella barra
HTML del §10.

### 9.1 Inventario

| Widget | Stato | Dove / note |
|---|---|---|
| Barra HTML `play.html` | esiste | 36 px, fuori dal CanvasLayer |
| Topbar in-canvas | non esiste | arriva nel 2015, non è il riferimento |
| Pulsante `Menu` | esiste | basso sinistra, 92×48, forma a scudo |
| Game Menu | esiste | 525×430, nero/rosso |
| Dialogo `Lasciare questo gioco?` | esiste | 525×300 |
| Dialogo `Reimpostare il personaggio?` | esiste | 525×370 |
| Impostazioni / Aiuto / Screenshot / Report / Registra | non esistono | nessuna funzione reale dietro |
| Chat log + input | esiste | alto sinistra 500×120; input full-width 20 px |
| Chat ospite | esiste disabilitata | placeholder + riga oro |
| Player list | esiste | alto destra 202 px |
| Avatar nella player list | non esiste | nessuna icona |
| Click riga player list | non esiste | righe non interattive |
| Contatore giocatori nell'HUD | non esiste | solo barra HTML e righe |
| Colonna `Monete` | esiste | solo la riga locale ha un valore |
| Health bar | esiste | 170×18, basso centro |
| Hurt overlay | esiste | danno ≥ 5 HP |
| Schermata di morte / countdown | non esiste | respawn immediato |
| Messaggio centrale transitorio | non esiste | chat oro + banner |
| Banner traguardo | esiste | 525×80, 5 s |
| Toast / notifiche social | non esiste | nessun evento sociale |
| Caricamento in-canvas | non esiste | overlay HTML unico proprietario |
| FPS | non esiste | debug nascosto con F3 |
| Backpack / hotbar / inventario | non esiste | nessun tool |
| Mirino | esiste | solo shift lock, punto 4×4 |
| Pillola `Lock Mouse` | non esiste | Shift è nei Comandi |
| Leaderboard | non esiste | monete nella player list |
| Name tag 3D | esiste invariato | non è HUD |
| Stud del brand nella barra | decorativo | unico elemento decorativo |

### 9.2 Layout, ancore e z-order

| Widget | Ancora | Offset / misura |
|---|---|---|
| Chat log | sinistra-alto | `x=0`, `y=5`, 500×120; testo indentato 12 px |
| Player list | destra-alto | `right=0`, `y=5`, larghezza 202; altezza `56 + 20×N` |
| Pulsante Menu | sinistra-basso | `left=8`, `bottom=28`, 92×48 |
| Health | centro-basso | `bottom=22`, 170×18 |
| Chat input | sinistra+destra-basso | `left=0`, `right=0`, `bottom=0`, altezza 20 |
| Banner | centro | centro orizzontale, centro verticale al 40%, 525×80 |
| Mirino | centro | punto 4×4 |
| FPS debug | destra-basso | `right=12`, `bottom=28`, 11 px |
| Hurt overlay | schermo intero | sotto l'HUD, sopra il mondo |

| Livello | Contenuto | Note |
|---|---|---|
| HTML sopra l'iframe | overlay caricamento/errore `z-index: 10`, barra `z-index: 30` | copre tutto finché il client non è pronto |
| CanvasLayer 40 | boot fallback standalone | solo `/dev/index.html` fuori dal wrapper; fuori specifica |
| CanvasLayer 30 | shield + Game Menu / Leave / Reset | modale, sopra ogni cosa in-canvas |
| CanvasLayer 20 | banner traguardo | sopra l'HUD, sotto i menu |
| CanvasLayer 15 | FPS debug | sopra l'HUD, sotto il banner |
| CanvasLayer 10 | HUD: chat, player list, health, input, Menu, mirino | ordine figli: chat, player list, health, input, Menu, mirino |
| CanvasLayer 5 | hurt overlay | sotto l'HUD per non coprire i testi |
| 0 | mondo 3D | — |

### 9.3 Chat

| Proprietà | Valore |
|---|---|
| Posizione | alto sinistra, `x=0`, `y=5` |
| Dimensione | 500×120 (scalata) |
| Sfondo | nessuno |
| Font | Source Sans 3 12 px, line-height 15 px |
| Testo | bianco `#FFFFFF`, outline nero 1 px |
| Rientro | 12 px |
| Righe visibili / storico | 8 / 20 |
| Durata | 45 s per riga, dissolvenza 0,5 s |
| Ordinamento | nuove in basso, le vecchie scorrono in alto |
| Timestamp / tab / scrollbar | assenti |
| Join/leave | nessun messaggio |
| Formato | `Nome: testo`; nome colorato, testo bianco |
| System | oro `GOLD` `#FFD700`, senza nome |
| Nomi | palette 8, indice `somma dei byte UTF-8 del nome % 8` |
| BBCode utente | vietato: si costruisce con `add_text`/`push_color` |
| Storico | azzerato a nuovo livello, conservato su morte/respawn |

Input chat:

| Proprietà | Valore |
|---|---|
| Posizione | basso, `left=0`, `right=0`, `bottom=0` |
| Altezza | 20 px (scalata) |
| Sfondo | `CHAT_BAR` `rgba(0,0,0,0.75)`; focus `CHAT_BAR_FOCUS` `rgba(0,0,0,0.88)` |
| Testo | bianco 12 px, Source Sans 3 |
| Placeholder | `Per chattare clicca qui o premi "/"` |
| Focus | bordo superiore 2 px `FOCUS` `#00A1DA` |
| Apertura | click, `/`, Invio |
| Invio | invia; con testo vuoto chiude |
| Esc | chiude senza inviare |
| Limite | 120 caratteri, `strip_edges`, vuoto ignorato |
| Movimento | disabilitato mentre è aperto; ripristinato alla chiusura |

- `/` non inserisce lo slash: la chat non ha comandi.
- Mentre si scrive, il personaggio non si muove e il Game Menu non si apre con Esc.
- La chat non si apre se Game Menu, Leave o Reset sono aperti.
- **Ospite:** riga oro `Sei un ospite: accedi per chattare.`; input visibile ma
  disabilitato con placeholder `Gli ospiti non possono chattare.`; `/`, Invio e click
  non lo aprono; se insiste, riga oro `Gli ospiti non possono chattare. Accedi per
  usare la chat.` Nessun invio lato client; il blocco server resta invariato.
- Disconnessione: log invariato + riga oro.

### 9.4 Player list

| Proprietà | Valore |
|---|---|
| Posizione | alto destra, `right=0`, `y=5` |
| Larghezza | 202 px: 150 nome + 52 monete |
| Header | 56 px, `UI_PANEL_DARK`, bordo inferiore 1 px `UI_BORDER` |
| Righe | 20 px, max 16 (cap relay), nessuno scroll |
| Pannello | `UI_PANEL` 0.86, bordo 1 px `UI_BORDER`, raggio 4 |
| Righe alternate | `PLAYERLIST_ROW_ALT` `rgba(255,255,255,0.06)` sulle pari |
| Bordo righe | 1 px `UI_BORDER` al 40% |
| Font | Liberation Sans |
| Header | `Giocatori` 24/700 bianco, outline nero; `Monete` 11/700 |
| Nome riga | 14 px bianco, outline nero; locale in grassetto |
| Monete riga | 14/700 `GOLD` |
| Avatar / icone / click | nessuno; cursore normale |
| Ordinamento | alfabetico case-insensitive; il locale non è pinnato |
| Nomi lunghi | ellissi a 138 px |

- La riga locale mostra `collected/total` se `total > 0`, altrimenti `—`.
- Le righe remote mostrano sempre `—`: le monete sono client-side.
- Il conteggio giocatori non si ripete nell'HUD.
- **Collapse:** click sull'header (o Invio/Spazio) chiude la lista; chiusa = barra 24 px
  con `Giocatori` 12 px e chevron; stato ricordato per la sessione, non persistito;
  default espansa.
- **Aggiornamento:** avvio con `net.player_name`; `peer_joined` aggiunge e riordina;
  `peer_left` rimuove; disconnessione rimuove i remoti e lascia il locale; nuovo
  livello riparte dal locale; l'ospite compare come qualsiasi giocatore.

### 9.5 Salute, danno, morte

- Health 170×18, centro-basso `bottom=22`, bordo nero 1 px, nessun raggio.
- Riempimento `health / MAX_HEALTH`, tween 0,2 s; gradiente `#25B230` → `#00AB00` 45%
  → `#004F00`; sotto 25% `#FF1C00`.
- Label `Salute` a destra, Source Sans 3 14/700 bianco, outline nero, 4 px dal bordo;
  nessun valore numerico; sempre visibile.
- **Hurt overlay:** vignetta rossa ai bordi, sotto l'HUD; scatta solo per danno ≥ 5 HP;
  alpha 0 → 0,5 → 0 in 0,6 s; non blocca input o HUD.
- **Morte/respawn:** nessun overlay, countdown o testo; il personaggio viene rimosso e
  respawna immediatamente; salute 100, barra piena, ultimo checkpoint; chat e player
  list restano; lo storico chat non si azzera.

### 9.6 Pulsante Menu, Game Menu, Leave e Reset

**Pulsante Menu** — visibile solo nel client web in place mode; in Studio Test e build
nativa dev non compare. Posizione `left=8`, `bottom=28`, 92×48; forma a scudo
(rettangolo con punta a sinistra), bordo 1 px `UI_BORDER`, fill trasparente; casa
bianca 24×24 + `Menu` 12 px con outline nero; hover `MENU_TRIGGER_HOVER`
`rgba(255,255,255,0.12)`, pressed, focus ring 2 px `FOCUS`; click o Invio/Spazio apre
il Game Menu.

**Priorità di Esc:**

1. Chat input aperto → chiude la chat, non apre il menu.
2. Game Menu aperto → chiude il menu (`Riprendi`).
3. Leave aperto → `Resta` (chiude).
4. Reset aperto → `Annulla` (chiude).
5. Altrimenti → apre il Game Menu.

Esc non mette in pausa il gioco.

**Game Menu** — shield a schermo intero `MENU_SHIELD` `rgba(51,51,51,0.40)`, nessun
bordo; pannello 525×430 centrato, nessun fill; titolo `Menu di gioco` 36/700 Liberation
Sans bianco, outline nero, centrato in alto; pulsanti 340×50, `x=92`:

| Pulsante | `y` | Default |
|---|---:|---|
| `Riprendi` | 54 | sì, bordo `MENU_DEFAULT` `#C1272D` |
| `Reimposta personaggio` | 105 | no |
| `Esci dal gioco` | 358 | no |

- Fill nero `MENU_BUTTON_BG`, bordo 1 px `MENU_BUTTON_BORDER` `#808080`, testo bianco
  24 px; hover fill `MENU_BUTTON_HOVER` `#111111`.
- Blocco statico `Comandi` tra `y=175` e `y=320`: titolo 18/700, righe 12/18:
  `WASD — muoviti`, `Spazio — salta`, `Shift — blocca il mouse`, `/ o Invio — chat`,
  `Esc — menu`.
- Niente Impostazioni/Aiuto/Screenshot/Report/Registra.
- Focus iniziale su `Riprendi`; Tab/Shift+Tab e frecce muovono il focus; Invio/Spazio
  attivano; Esc chiude.
- All'apertura: chiude la chat, rilascia mouse/shift lock, disabilita il movimento del
  personaggio. Il mondo continua a girare; nessuna pausa.
- Alla chiusura: ripristina l'input e, se lo shift lock era attivo prima, lo riattiva.

**Leave** — il Game Menu si nasconde; dialogo 525×300 sullo stesso shield; titolo
`Lasciare questo gioco?` 36/700 bianco, centrato, margine superiore 40; pulsanti 128×50
in fondo (`bottom=22`): `Resta` a `x=90` (default, bordo rosso), `Esci` a `x=313`.
`Resta` o Esc chiude tutto e torna al gioco; `Esci` chiude tutto e chiama
`place_client.leave()`, la pagina torna a `place.html`. Il pulsante `Riprendi` non è
presente.

**Reset** — il Game Menu si nasconde; dialogo 525×370 sullo stesso shield; titolo
`Reimpostare il personaggio?` 36/700 bianco, centrato, margine superiore 40; sottotesto
`Tornerai al punto di spawn.` 18 px, centrato, `y=215`; pulsanti 128×50 in fondo
(`bottom=22`): `Annulla` a `x=90` (**default**, bordo rosso), `Reimposta` a `x=313`.
`Annulla` o Esc chiude tutto e torna al gioco; `Reimposta` chiude, uccide il personaggio
e respawna immediatamente dall'ultimo checkpoint. Deviazione di sicurezza: il default
è `Annulla`, non `Reimposta`.

**Macchina a stati:**

```
CHIUSO ──Esc / Menu──▶ MENU
MENU ──Riprendi / Esc──▶ CHIUSO
MENU ──Reimposta personaggio──▶ RESET
MENU ──Esci dal gioco──▶ LEAVE
RESET ──Annulla / Esc──▶ CHIUSO
RESET ──Reimposta──▶ CHIUSO + respawn
LEAVE ──Resta / Esc──▶ CHIUSO
LEAVE ──Esci──▶ place.html
CHAT_APERTA ──Esc──▶ CHIUSO (chat)
```

Se il gioco non è ancora partito o è in errore, il Menu non si apre. In Studio Test o
build dev il sottosistema è disabilitato.

### 9.7 Banner, debug, mirino e widget assenti

- **Banner traguardo:** 525×80, centrato orizzontalmente, centro verticale al 40%;
  `BANNER_BG` `rgba(0,0,0,0.90)`, bordo 1 px `MENU_DEFAULT` `#C1272D`, nessun raggio;
  `GIOCO COMPLETATO!` 36/700 bianco; fade 120 ms, resta 5 s; un solo banner alla volta;
  non compare sopra i menu; aggiunge la riga oro `Traguardo raggiunto!`.
- **FPS:** nessun FPS nell'HUD; F3 mostra/nasconde `FPS <n>` 11 px in basso a destra;
  stato non persistito, escluso da screenshot e demo.
- **Mirino:** punto bianco 4×4 con outline nero 1 px, solo con shift lock; con mouse
  libero si vede il cursore di sistema.
- **Assenti:** backpack/hotbar, leaderboard, pillola Lock Mouse, toast, schermata di
  morte, name tag 3D invariati.

### 9.8 Eventi e messaggi

Nessun toast: non ci sono amicizie, badge, acquisti o altri eventi sociali reali.

| Evento | Canale | Testo | Durata |
|---|---|---|---|
| Ingresso account | chat oro | `Benvenuto, <nome>!` | 45 s |
| Ingresso ospite | chat oro | `Benvenuto, <nome>!` + `Sei un ospite: accedi per chattare.` | 45 s |
| Connessione multiplayer | chat oro | `Connesso in multiplayer!` | 45 s |
| Connessione persa | chat oro | `Connessione persa: modalità single player.` | 45 s |
| Server non raggiungibile | chat oro | `Server non raggiungibile: modalità single player.` | 45 s |
| Server rifiuta / stanza piena | chat oro | messaggio del server | 45 s |
| Checkpoint | chat oro | `Checkpoint raggiunto!` | 45 s |
| Tutte le monete | chat oro | `Hai raccolto tutte le monete!` | 45 s |
| Traguardo | banner + chat oro | `GIOCO COMPLETATO!` + `Traguardo raggiunto!` | 5 s + 45 s |
| Errore script | chat oro | `Script: <NomeScript>:<riga>: <messaggio>` | 45 s |
| Morte / respawn | nessuno | — | — |
| Join/leave di altri | nessuno | la player list basta | — |

- `GameHUD.show_message` viene sostituito da `add_system_line(text)` e
  `show_banner(text, duration)`.
- `print`/`warn` degli script restano nella console e nel pannello Output di Studio,
  non nell'HUD.

### 9.9 API del HUD

```gdscript
func add_system_line(text: String) -> void
func add_chat_line(sender: String, text: String) -> void
func chat_has_line(sender: String, text: String) -> bool
func show_banner(text: String, duration: float = 5.0) -> void
func set_local_coins(collected: int, total: int) -> void
func set_player_list(local_name: String, remote_names: Array[String]) -> void
func set_chat_enabled(enabled: bool) -> void
func set_menu_enabled(enabled: bool) -> void
func set_crosshair_visible(enabled: bool) -> void
func set_health(value: float) -> void
func is_chat_open() -> bool
func is_menu_open() -> bool
```

- `set_players(int)` e `set_coins(int, int)` vengono ritirati o diventano wrapper
  interni.
- Dati player list: `main.gd` mantiene `_remote_names` (id → nome) o legge
  `remote.display_name`; `RemoteCharacter.setup(name, …)` salva il nome in una
  property; `peer_joined` aggiunge, `peer_left` rimuove; `set_player_list` riordina
  alfabeticamente. Il locale è `net.player_name` (o `menu.player_name()` in dev).

## 10. Play, caricamento e handshake

La specifica completa è [`hud-client.md`](hud-client.md) §4–5.

### 10.1 Barra HTML

```
[stud] RobloxWeb   Welcome Obby · di RobloxWeb        3 che giocano   [Esci]
```

- Altezza 36 px, sfondo `#114081`, testo bianco, bordo inferiore 1 px `#7394C1`,
  padding orizzontale 15 px, gap 15 px; nessuna ombra, nessun radius.
- **Brand:** stud + wordmark `RobloxWeb`, link a `/`, font 14/600.
- **Titolo:** 14/700 bianco, ellissi se lungo; nessun link.
- **Autore:** 13 px `#9EC3E7`, `di <autore>`, link a `/profile.html?user=<owner_id>`
  quando `owner_id` è presente.
- **Conteggio:** 13 px bianco, `font-variant-numeric: tabular-nums`; forme
  `1 che gioca` / `N che giocano` / `Nessuno sta giocando`; a gioco pronto non scende
  sotto 1.
- **Esci:** link `btn-control` a `/place.html?id=<id>`; target minimo 24×24, focus ring
  del sito.
- Nessun nome giocatore, nessun `#play-player`.
- Sotto 700 px: restano titolo con ellissi + `Esci`; brand, autore e conteggio nascosti;
  barra sempre 36 px.
- La pagina richiede una sessione; `document.title = "Gioca a <titolo> — RobloxWeb"`.

### 10.2 Conteggio live

- Valore iniziale da `GET /api/places/<id>` (`live_players`).
- Polling ogni 10 s, sospeso con `document.hidden`; nessun layout shift (larghezza
  minima del blocco); in errore si tiene l'ultimo valore, senza alert.
- La player list in-game è la fonte autorevole delle righe; il numero nella barra è il
  conteggio del relay visto dall'API.

### 10.3 Stati della barra

| Stato | Titolo | Autore | Conteggio | Esci |
|---|---|---|---|---|
| Caricamento | `Caricamento…` | vuoto | `—` | attivo |
| Pronto | titolo del gioco | `di <autore>` linkato | valore API, min 1 | attivo |
| Errore API | `Caricamento…` o titolo se noto | vuoto | `—` | attivo |
| Poll fallito | invariato | invariato | ultimo valore | attivo |
| <700 px | titolo, ellissi | nascosto | nascosto | attivo |

### 10.4 Overlay di caricamento

- Area nera sotto la barra; contenuto centrato: `CARICAMENTO` 12 px maiuscolo,
  `letter-spacing: 2px`, `#E6E6E6`; sotto, barra 300×18.
- Barra: track `#8C8C8C`, fill `#D2D400`, bordo 1 px `#777777`; indeterminata (fill
  ~30% che scorre) finché non arriva `rw-ready`; con `prefers-reduced-motion` il fill
  resta fermo al 40%.
- Nessuno spinner moderno, nessun logo, nessun titolo del gioco.
- Transizione di uscita 120 ms, poi `pointer-events: none`.
- L'evento `load` dell'iframe **non** nasconde l'overlay.

### 10.5 Handshake

| Messaggio | Quando | Effetto |
|---|---|---|
| `rw-ready` | livello costruito e personaggio spawnato, anche se il WebSocket non è connesso | nasconde l'overlay e mostra il gioco |
| `rw-error` | errore fatale di bootstrap | mostra il box di errore; non nasconde la barra |
| `rw-leave` | uscita dal Game Menu | già gestito da `site.js`: torna a `place.html` |

- `rw-error` porta `{type, message, detail?}`. `message` è la frase breve, `detail` il
  suggerimento. Il client compone il detail in `_on_place_failed`; `PlaceClient._fail`
  non chiama `_post_error`, altrimenti partirebbero due messaggi.
- `post_ready()` chiama `window.parent.postMessage({type:'rw-ready'}, origin)` solo se
  `OS.has_feature("web")`; se `window.parent === window` non fa nulla.
- Timeout di sicurezza 30 s: box `Il client non risponde. Ricarica la pagina.` Se
  `rw-ready` arriva dopo, l'errore sparisce e il gioco parte.
- Un fallimento del solo multiplayer **non** produce `rw-error`: è una riga oro in chat.
- In embedded non esiste il boot in-canvas: l'overlay HTML è l'unico proprietario.

### 10.6 Box di errore e testi

- Box bianco 2014, max 460 px, bordo 1 px `#CCC`, padding 20, nessun radius.
- Titolo `Impossibile avviare il gioco` 27/700; messaggio 14/1.428 `#343434`; detail
  12/1.4 `#666`; pulsante `Torna al gioco` (`btn-negative`, grigio) verso
  `/place.html?id=<id>`.
- La barra HTML resta visibile e utilizzabile.

| Codice | Testo |
|---|---|
| id non valido | `Gioco non valido. Apri un gioco dal catalogo.` |
| 401 | `Accedi per giocare.` |
| 403/404 | `Gioco non trovato o privato.` |
| 503 | `L'autore non ha ancora pubblicato una versione giocabile.` |
| rete | `Server non raggiungibile.` |
| export mancante | `Il client Web non è disponibile. Esegui l'export Godot in WEBhtml/dev/ e riprova.` |

## 11. Invarianti tecnici e ciò che non cambia

| Elemento | Trattamento | Note |
|---|---|---|
| API, sessioni, cookie, relay, livello `.rwl.json` | **riuso invariato** | nessuna modifica server; nessun cambio di contratto |
| Thumbnail esistenti | **riuso, nessuna migrazione** | master 512×288 già 16:9; `?v=<versione>` invariato |
| Card/avatar/placeholder | **sostituzione client-side** | `site.js` + CSS; nessun endpoint o resize server |
| Header/footer | **sostituzione** | header `RW.headerHTML`, footer `RW.footerHTML` |
| Topbar di gioco | **sostituzione** | barra HTML 36 px fuori dall'iframe; nessuna topbar in-canvas |
| HUD esistente | **sostituzione** | nuova scena con `Root`, tema e widget 2014; i vecchi nodi `Coins/Players/Message/FPS` spariscono |
| Game Menu/Leave | **sostituzione** | il vecchio `_show_leave_menu` e il `BootOverlay` dinamici vengono rimossi |
| `games.html` | **nuovo** | pagina statica servita senza route server |
| Font | **nuovo** | woff2 per il sito, TTF per Godot, OFL committate |
| Test esistenti | **riuso, un aggiornamento** | `test_network.gd` passa a `chat_has_line`; gli altri restano invariati |
| `tools/generate_scenes.gd` | **ridotto** | non rigenera più `hud.tscn`; resta per `main.tscn`/`level_select.tscn` |

- **Nessuna modifica a server, API, DB, relay o formato livello.** L'unico adattamento è
  client-side: `RW.localizeServerMessage()` traduce i messaggi server noti e ha fallback
  locale per 401/403/404/429/503.
- **URL e API invariati:** `index.html`, `place.html`, `profile.html`, `admin.html`,
  `studio.html`, `play.html`, `login.html`; nuova `games.html`;
  `/api/places/<id>/like` resta `like` anche se la UI dice “preferiti”.
- **Sito senza build step:** CSS e JS restano file statici, font self-hosted, nessun
  CDN, nessuna richiesta di terze parti.
- **CSP invariata:** font e iframe sono same-origin; `games.html` riceve la CSP come le
  altre pagine; `/dev/` resta senza CSP. Non si aggiungono origin a
  `script-src/style-src/img-src/font-src/connect-src`.
- **Cache:** il server serve tutto con `Cache-Control: no-store`; non serve cache
  busting per CSS/font.
- **Le richieste POST/PUT/DELETE con cookie** mantengono `Origin`/`Referer` same-origin;
  i client Bearer ne sono esenti. Non si rimuove il controllo senza un token CSRF.
- **Topbar:** la barra HTML di `play.html` sostituisce quella attuale; dentro il
  CanvasLayer non compare nessuna topbar. Non si tocca il client desktop né Studio.
- **Thumbnail:** `thumbnail_url` resta l'unica fonte; il crop è solo UI
  (`object-fit: cover`).
- **Fuori scope:** Studio desktop/editor/start screen, build nativa dev (`LevelSelect`,
  `Menu`), UI mobile 2014, feature finte, asset o logo Roblox.

## 12. Piano di implementazione

La specifica completa è [`implementation-plan.md`](implementation-plan.md). Il lavoro
si consegna con **10 PR** su un branch di integrazione, senza feature flag.

### 12.1 Modello di consegna

- Branch `aesthetic-2014` creato da `main`.
- Ogni PR è reale su GitHub, ha base `aesthetic-2014`, un solo sottosistema e un titolo
  che cita la superficie (es. `site: home e pagina Giochi 2014`).
- Il branch può contenere stati intermedi, ma nessuna PR introduce codice transitorio o
  fallback che resterebbe in produzione.
- `main` non cambia fino alla PR 10. La PR di integrazione `aesthetic-2014` → `main` usa
  un merge commit (non squash): il rollback è `git revert -m 1 <merge>`.
- Nessun feature flag, nessun parametro `?theme=legacy`, nessuna doppia pelle.
- Se una PR scopre un conflitto con la spec: nuovo ticket, aggiornamento di `map.md`,
  decisione prima del codice. Le scelte tecniche interne (nomi di helper, ordine dei
  nodi, struttura dei test) sono libere.
- I documenti canonici vivono in `docs/roblox-2014/`; `GLOSSARY.md` sta alla root. Il
  tracker dei ticket resta in `.scratch/roblox-2014-aesthetic/`.

### 12.2 Sequenza PR

| # | PR | Dipende da | Superfici | Dimensione indicativa | Gate fast | Evidenza |
|---|---|---|---:|---|---:|---|
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

> La PR 2 è la più ampia: va spezzata in commit interni (base/chrome, form, card/media,
> dialoghi) ma resta una sola PR perché la pelle scura non deve convivere con componenti
> 2014 in `main`. Se in review supera ~1200 righe, si divide in 2a “chrome” e 2b “media”
> senza cambiare l'ordine delle PR successive.

### 12.3 Contenuto per PR

**PR 1 — Fondamenta del sito**
- Blocco `:root` con tutti i token `--rw-*` di [`tokens.md`](tokens.md) §2 in
  `WEBhtml/assets/site.css`; i token scuri esistenti restano temporaneamente.
- `@font-face` Source Sans 3 300/400/600/700, `font-display: swap`, preload di 400/600;
  file in `WEBhtml/assets/fonts/source-sans-3/` + `OFL.txt`.
- `Godot/robloxwebengine/scripts/ui/rw_tokens.gd`: costanti `COLOR_*`, `FONT_SIZE_*`,
  `SIZE_*`, `OUTLINE_*`, incluse quelle solo client.
- `tools/check_design_tokens.py`: confronta CSS e GDScript per il sottoinsieme condiviso,
  calcola il contrasto dei token di testo e fallisce con un diff leggibile.
- `tools/check_site_content.py`: inventario pagine, presenza token, font richiesti,
  divieto di URL esterni e regole di copy attivabili per superficie.
- Nessun aggiornamento ad `AGENTS.md`: l'aggiornamento operativo è nella PR 10.

**PR 2 — Design system del sito**
- `site.css`: base 2014 (canvas bianco, testo 14/1.428, link, focus ring, niente
  radius/ombre), header 36 px, footer, bottoni `.btn-small/medium/large/control`, input,
  alert, tab, tabelle, badge, empty/loading, dialoghi `<dialog>`.
- Media: card 202/192×108, placeholder cielo/prato/stud/iniziale, hover `Gioca` 22 px,
  avatar blocky, hero 430×230, sidebar 300×160 e 64×36, dettaglio 500×281.
- `site.js`: `RW.headerHTML` con nav Home/Giochi/Studio/Profilo/Moderazione e stati
  ospite/account/admin; `RW.footerHTML`; pagina attiva; rimozione della ricerca globale;
  `RW.card`, `RW.thumbHTML(place, context)`, `RW.avatarHTML(user, size, decorative)`,
  `RW.shade`, `RW.palette` con le 8 coppie 2014, `RW.applyLive` testuale;
  `RW.confirmDialog`; `RW.localizeServerMessage`.
- Sweep globale della copy: “esperienze” → “giochi/gioco”, “like” → “preferiti”,
  “online” → “che giocano/giocano ora”, “catalogo” → “Giochi” dove è UI; footer con
  anno 2026 e soli link reali.
- Tutte le pagine con chrome (non `play.html`): footer generato, `data-page`, rimozione
  della search dall'header. I corpi restano quelli attuali fino alle PR 3–5; `play.html`
  riceve la barra nella PR 9.

**PR 3 — Home e Giochi**
- `index.html`: hero 1180 con art 430×230 e badge “In evidenza · <titolo>”, h1 32, CTA
  verde/blu, sezione “Giochi popolari” con tab 2014, griglia 4 colonne, 8 card, “Vedi
  tutti” → `games.html`; stati caricamento/errore/vuoto; polling 10 s senza layout shift.
- `games.html` nuova: 970 px, h1 “Giochi”, filtri `Ordina per` + ricerca locale GET
  (`?q=&sort=`), main 610 con griglia 3×202, sidebar 300 con featured 300×160, “Più
  giocati” 64×36, box “Crea il tuo gioco”; empty con “Azzera ricerca”; nessuna
  paginazione.
- `site.css`/`site.js` solo per il supporto alla pagina, senza duplicare componenti.
- Copy e title/meta aggiornati.

**PR 4 — Dettaglio gioco**
- `place.html`: 970 px, h1 32, autore 14 con avatar 48 linkato, colonna sinistra 500 con
  media 500×281, descrizione e “aggiornata il…”; colonna destra 240 con `Gioca` verde
  150, `★ N preferiti`, `Segnala`, box statistiche `Visite / Giocano ora / Versione /
  Aggiornata`.
- Stati: ospite anonimo con box “Accedi per giocare”, owner con link `Modifica`, nascosto
  con alert warning e play disabilitato (admin può giocare), 403/404 con box “Gioco non
  trovato”.
- Dialog segnalazione 2014 con select motivo, textarea, `Invia segnalazione` verde,
  `Annulla` grigio; niente `confirm()`.
- Polling 10 s su visite/live/preferiti senza layout shift.

**PR 5 — Pagine account**
- `login.html`: due colonne 465+484, nessun tab; pannelli Accedi/Registrati, input 21 px,
  `Accedi` blu, `Crea account` verde, `Annulla` grigio, `Gioca come ospite`, nota demo,
  alert info se già loggato, errori 2014, stack sotto 1000.
- `profile.html`: due colonne; sinistra 484 con h2 30, `@username · dal …`, avatar 352
  blocky, stats `Giochi / Visite / Preferiti`, azioni per ruolo; destra con tab verticali
  35 px `Giochi`/`Preferiti` solo per il proprio profilo, card 2 colonne, badge visibilità
  testuali, azioni owner, empty states.
- Dialog Modifica 27/700, campi titolo/descrizione/visibilità, Salva/Annulla; dialog
  Versioni con tabella 2014 e `Ripristina` blu; conferma con modale 2014, non `confirm()`.
- `admin.html`: due sezioni impilate con tabelle 2014 (segnalazioni aperte, giochi
  nascosti), azioni `Ignora`/`Nascondi`/`Ripristina`, conferme con modale, empty,
  non-admin, scroll orizzontale <700.
- `studio.html`: due colonne 600+300, box download con due `btn-large` verdi, meta
  zip/x86_64, nota 404, requisiti/comandi `<code>`, box “Come pubblicare”, “Server
  locale”, “Torna ai giochi”.
- Copy e title/meta aggiornati; rimozione definitiva di `confirm()`.

**PR 6 — Fondamenta del client Godot**
- Font TTF `SourceSans3-Regular/Bold`, `LiberationSans-Regular/Bold` + OFL in
  `Godot/robloxwebengine/assets/fonts/`; import settings come [`godot-theme.md`](godot-theme.md)
  §6.2.
- `themes/rw_theme.gd` (`RwTheme`), `scripts/ui/rw_layout.gd`, completamento di
  `rw_tokens.gd`; type variation `Rw*`, stylebox, helper `_flat`.
- Content scaling: `RwLayout.use_client()` in `main.gd` `_enter_tree()`; `use_editor()`
  in StudioStart/editor; `scale_for`/`apply`.
- `tools/export_web.sh`.
- `tools/test_theme.gd`: build/cache, base type, font, colori, stylebox, `scale_for`,
  `apply`, scan `hud.tscn`/`game_menu.tscn` senza `theme_override_` (il secondo scatterà
  dalla PR 8).
- Nessun handshake ancora: `play.html` continua con l'overlay attuale; il client non
  mostra ancora il nuovo HUD.

**PR 7 — HUD 2014**
- `scenes/ui/hud.tscn`: `CanvasLayer` 10 → `Root` Control in design space; chat log
  `RichTextLabel` + input `LineEdit`, player list 202 px con header 56 e righe 20,
  health 170×18, banner 525×80, hurt overlay, debug FPS, crosshair 4×4. Niente
  `theme_override_*`.
- `scripts/ui/hud.gd`: API del §9.9; storia 20 righe/8 visibili, fade 45 s, palette nomi
  deterministica, oro per i system, guest.
- `scenes/ui/banner.tscn`, `scenes/ui/debug.tscn`, `scenes/world/hurt_overlay.tscn`.
- `scripts/main.gd`: sostituisce `show_message` con `add_system_line`/`show_banner`;
  alimenta la player list da `net.player_name` e `_remote_characters`;
  `RemoteCharacter.display_name`; gli eventi del §9.8 passano in chat oro.
- `tools/generate_scenes.gd`: smette di rigenerare `hud.tscn` (resta per
  `main.tscn`/`level_select.tscn`).
- `tools/test_hud.gd`: palette, ordinamento, collapse, storia/timer, formula di scala,
  API chat; `tools/test_network.gd` passa a `chat_has_line`.
- Nessun Game Menu ancora: il pulsante Menu arriva nella PR 8. Esc resta il comportamento
  attuale.

**PR 8 — Game Menu, Leave e Reset**
- `scenes/ui/game_menu.tscn` + `scripts/ui/game_menu.gd`: shield `MENU_SHIELD`, pannello
  525×430, titolo 36, pulsanti 340×50 (`Riprendi` default, `Reimposta personaggio`, `Esci
  dal gioco`), blocco Comandi, focus iniziale e navigazione da tastiera; Leave 525×300
  (`Resta` default, `Esci`), Reset 525×370 (`Annulla` default, `Reimposta`).
- Pulsante Menu a scudo 92×48 in basso a sinistra, solo client web in place mode; `_draw`
  per lo scudo, hover/focus; `set_menu_enabled`.
- `main.gd`: macchina a stati `CHIUSO/MENU/LEAVE/RESET`, priorità Esc, rilascio
  mouse/shift lock, blocco movimento con `input_enabled`, ripristino shift lock;
  rimozione del vecchio `_show_leave_menu` e del CanvasLayer 0.
- `test_hud.gd`: stati e default sicuri (`Resta`, `Annulla`); `test_gameplay.gd`
  invariato sul Menu iniziale.

**PR 9 — Play, handshake ed export**
- `play.html`: barra 36 px (brand, titolo, autore linkato, `N che giocano`, `Esci`),
  iframe `calc(100vh - 36px)`, overlay `CARICAMENTO` + barra 300×18 indeterminata, box
  errore 2014, timeout 30 s, `rw-ready`/`rw-error`, nessun nome giocatore, responsive
  <700.
- `site.css`/`site.js`: stili barra/overlay/errore, polling conteggio 10 s con pausa in
  background, `rw-leave` invariato.
- `main.gd`: `place_client.post_ready()` una volta per caricamento, dopo livello
  costruito e personaggio spawnato; rimozione di `_show_boot` embedded; `_on_place_failed`
  compone `message` + `detail`.
- `place_client.gd`: `rw-error` con `detail`; `_fail` non chiama più `_post_error`; solo
  `post_error`/`post_ready`.
- `tools/export_web.sh` usato per l'export finale della PR.

**PR 10 — Documentazione, accettazione e chiusura**
- I documenti canonici sono già in `docs/roblox-2014/` (ticket 10): `spec.md`,
  `tokens.md`, `site-map.md`, `hud-client.md`, `media-rules.md`, `godot-theme.md`,
  `implementation-plan.md`, `acceptance.md`, `research/`, `prototype/`, `evidence/`. La
  PR 10 aggiunge le contact sheet e completa l'accettazione.
- `GLOSSARY.md` alla root, con i termini già approvati (committato dal ticket 10).
- `AGENTS.md`: nuovi path (`games.html`, `docs/`, `tools/check_*.py`, `tools/verify.sh`,
  `tools/export_web.sh`, `rw_tokens.gd`, `RwTheme`, `RwLayout`, font), comandi di
  verifica, struttura HUD e nota sul generatore scene.
- `acceptance.md` compilata con evidenze e contatto finale.
- Contact sheet committate in `docs/roblox-2014/evidence/`; set completo in
  `.scratch/roblox-2014-aesthetic/evidence/`.
- Nessun aggiornamento a `PLAN.md` (nessun M6) e a `server/README.md` (server invariato).

### 12.4 Rischi e mitigazioni

| Rischio | Mitigazione |
|---|---|
| La PR 2 è troppo ampia | Commit interni separati; split 2a “chrome”/2b “media” se supera ~1200 righe, senza cambiare l'ordine |
| `play.html` si rompe se aspetta `rw-ready` prima che il client lo invii | La PR 9 arriva dopo le PR 6–8 e include handshake + overlay insieme |
| `generate_scenes.gd` sovrascrive il nuovo HUD | La PR 7 modifica il generatore e aggiunge un controllo che non rigeneri `hud.tscn` |
| Font non inclusi nel PCK Web | Preload in `RwTheme`; verifica con export e `/dev/index.html` |
| Content scaling rompe Studio/editor | `RwLayout.use_editor()` in StudioStart/editor; `test_studio`/`test_editor` nel gate |
| Il server restituisce copy fuori glossario | `RW.localizeServerMessage()` client-side, testato; nessuna modifica server |
| Fixture che sporcano il DB | Data dir temporanea, porte dedicate, `--clean` e trap |
| Screenshot non riproducibili per viewport | Harness a iframe + gallery Godot, nomi file deterministici |
| Nessuna CI | `tools/verify.sh` + gate per PR + evidenze allegate; nessuna aspettativa di automazione GitHub |
| Rate limit durante le prove | Fixture con pochi account e richieste distanziate; server isolato |

## 13. Verifica, evidenze e accettazione

La checklist completa con ID stabili è [`acceptance.md`](acceptance.md). Ogni PR cita
gli ID coperti; il gate finale li verifica tutti.

### 13.1 Gate fast (ogni PR)

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

- Se la PR tocca codice Godot incluso nel Web: `tools/export_web.sh` e apertura di
  `/dev/index.html` con console pulita.
- Se la PR cambia una superficie visibile: screenshot before/after a 1440 e 700,
  allegati alla PR; per le pagine con breakpoint specifici, anche 1000/480.
- Nessuna PR può mergiare con un checker rosso, un errore console o un 404 di asset.

### 13.2 Gate full (solo PR 10)

`tools/verify.sh --full` deve:

1. verificare che le porte 9080/9081 siano libere;
2. creare una data dir temporanea con `mktemp -d`;
3. avviare `server/run.py` con `ROBLOXWEB_DATA_DIR` temporanea e seed demo;
4. eseguire `test_network`, `test_publish`, `test_studio` e tutti i test Godot headless;
5. eseguire `tools/check_design_tokens.py` e `tools/check_site_content.py`;
6. eseguire `tools/export_web.sh`;
7. fermare il server e cancellare la data dir anche in caso di errore (trap).

La matrice visuale e la gallery HUD sono passi separati di
`tools/verify.sh --full --visual` (richiedono display e browser), documentati nel §13.4.

### 13.3 Test esistenti da preservare

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

Nuovi test: `tools/test_theme.gd`, `tools/test_hud.gd`, `tools/check_design_tokens.py`,
`tools/check_site_content.py`.

### 13.4 Harness di verifica visiva

**Dati e fixture.** `tools/visual_fixtures.py` (dev-only) usa una
`ROBLOXWEB_DATA_DIR` temporanea e il server reale, senza toccare `server/data/`:

- crea `visual_owner`, `visual_viewer`, `visual_admin` (admin via
  `ROBLOXWEB_ADMIN_USERS` o `manage.py admin`);
- crea un place pubblico con thumbnail 16:9, uno con thumbnail 4:3, uno non elencato,
  uno privato, uno nascosto via admin;
- crea una segnalazione aperta, un like e un profilo vuoto;
- genera le thumbnail PNG con la sola stdlib (zlib/struct), senza Pillow;
- stampa URL, porte e credenziali; `--clean` cancella la data dir e ferma il server.

Le fixture usano porte dedicate (es. 9082/9083) per non collidere con il server di
sviluppo e con il gate full. I dati sono deterministici e non vengono committati.

**Matrice del sito.** Generata da `tools/visual_matrix.py` in
`WEBhtml/dev/visual-matrix.html` (gitignored). La pagina contiene iframe same-origin a
larghezza fissa; i breakpoint si verificano negli iframe e si fotografano con
`browser.screenshot`.

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

Gli stati transitori di caricamento/errore che dipendono dalla rete o dal DB si verificano
con l'harness dei componenti e con un'interruzione controllata del server dopo il load;
non si aggiungono parametri `?state=` alla produzione. Il wiring reale (fetch, alert,
retry) resta coperto dallo smoke browser e dalla review del codice.

**Matrice HUD.** `tools/hud_gallery.gd` monta HUD, banner, hurt, debug e Game Menu con
dati finti e salva PNG via `get_viewport().get_texture().get_image().save_png()`. Richiede
display, non headless; è escluso dall'export da `tools/*`.

| Gruppo | Viewport | Stati |
|---|---|---|
| HUD completo | 1680×964, 640×364 | chat vuota/5 righe/input aperto/ospite; player list 1/4/16/collassata; salute 100/24/0; banner; hurt; crosshair; FPS |
| HUD base | 1280×684, 1024×732, 800×564 | chat + player list + salute + Menu |
| Menu/dialoghi | 1680×964, 640×364 | Game Menu (focus Riprendi), Leave (focus Resta), Reset (focus Annulla), hover/focus |
| Barra play | 1440×900, 650×900 | loading, ready, error |

Nomi file: `site-<pagina>-<larghezza>-<stato>.png`, `hud-<gruppo>-<stato>-<WxH>.png`.

### 13.5 Accessibilità, performance e pulizia

- `check_design_tokens.py` calcola il contrasto dei token di testo e verifica `#767676`,
  footer e focus.
- Lighthouse sul sito (tutte le pagine, viewport desktop) con gate sugli audit:
  `color-contrast`, `label`, `link-name`, `button-name`, `html-has-lang`,
  `document-title`, `viewport`. Il punteggio sintetico è registrato ma non è un gate.
- Passaggio da tastiera su header, form, dialoghi, card, tab, admin,
  Game Menu/Leave/Reset: focus visibile, ordine logico, Esc/Invio/Spazio.
- Nessun testo affidato al solo colore: badge visibilità, live, preferiti, salute con
  barra + rosso.
- Nessuna richiesta di terze parti; font self-hosted; `font-display: swap`.
- Nessun errore console o 404 di asset nelle pagine e in `/dev/`.
- Layout shift assente nei polling (live, visite, preferiti).
- `check_site_content.py` registra le dimensioni di CSS/JS/font e fallisce se compare un
  URL esterno o un font mancante; nessun budget sintetico Lighthouse.
- Dopo ogni prova: fixture `--clean`, server fermato, `WEBhtml/dev/` rigenerato
  dall'export e non committato.

### 13.6 Evidenze e sign-off

- Ogni PR allega gli screenshot before/after delle superfici cambiate.
- Il set completo resta in `.scratch/roblox-2014-aesthetic/evidence/` (non versionato).
- A fine lavoro si committono solo le contact sheet in `docs/roblox-2014/evidence/`
  (circa 10–14 immagini ottimizzate) e l'`acceptance.md` compilato.
- Il merge finale avviene dopo la revisione umana di contact sheet e acceptance.
- La firma finale è nella tabella di [`acceptance.md`](acceptance.md) §7.

## 14. Tracciabilità delle decisioni della mappa

Ogni decisione registrata in `map.md` è riflessa qui e nei documenti canonici. La tabella
serve alla review di handoff: se una riga non è vera, la spec non è pronta.

| ID | Decisione della mappa | Dove è riflessa | Documento canonico | PR |
|---|---|---|---|---|
| D01 | Riferimenti sito: header blu `#114081` 36 px, colonna 970, Source Sans Pro storico 14/1.428 (Source Sans 3 nel re-skin), link `#0055B3`, CTA verdi/blu, CSS e snapshot citati | §2.1, §4.2, §5.1 | [`tokens.md`](tokens.md), [`research/sito-2014.md`](research/sito-2014.md) | 1–5 |
| D02 | Riferimenti client: niente topbar, Menu a scudo in basso a sinistra, chat 12 px in alto a sinistra, player list 150 px in alto a destra senza avatar, backpack 9×54, health 170×18, Game Menu nero/rosso | §2.2, §9.1–9.6 | [`hud-client.md`](hud-client.md), [`research/client-2014.md`](research/client-2014.md) | 6–9 |
| D03 | Prototipo B: home 1180 con hero e 4 colonne senza sidebar, client con barra HTML + HUD 2014, catalogo 970+sidebar, chat in alto a sinistra, monete nella player list, Game Menu nero/rosso | §2.3, §6.1–6.3, §9 | [`prototype/README.md`](prototype/README.md) | 2–9 |
| D04 | Token: Source Sans 3 14 px, header `#114081`, 970/1180, squadrato senza ombre, 7 deviazioni di accessibilità, CSS + mirror GDScript + checker | §4, §8.5–8.6 | [`tokens.md`](tokens.md) | 1, 6 |
| D05 | Mappatura sito: `games.html` 970+sidebar e home B 1180; login 2 colonne, profilo 2 colonne con tab, admin a tabelle, modali 2014; lessico Giochi/Preferiti/che giocano; header senza search globale; nessuna feature 2014 finta | §3, §5, §6 | [`site-map.md`](site-map.md), [`../GLOSSARY.md`](../../GLOSSARY.md) | 2–5 |
| D06 | HUD: barra HTML 36 px, chat 500×120 con 8 righe/45 s, player list 202 px con monete solo locali, salute 170×18, Menu a scudo, Game Menu 525×430, Leave 525×300, Reset 525×370, banner 525×80, niente backpack/toast, FPS solo F3, scala `clamp(…, 0.8, 1.0)` | §9, §10 | [`hud-client.md`](hud-client.md) | 6–9 |
| D07 | Media: master 512×288 16:9, card 202/192×108 con meta a 2 righe, placeholder cielo/prato/stud/iniziale, avatar blocky da `avatar_color`, hero 430×230, sidebar 300×160/64×36, dettaglio 500×281, stella oro/live verde, nessuna modifica server | §7 | [`media-rules.md`](media-rules.md) | 2–5 |
| D08 | Tema Godot: `Theme` runtime da `rw_tokens.gd` in `themes/rw_theme.gd`, variation `Rw*`, TTF Source Sans 3 + Liberation Sans, `StyleBoxFlat` e scudo in `_draw`, HUD/Game Menu/banner/debug soltanto, client `CONTENT_SCALE_MODE_DISABLED` + design space `viewport/s` e scala 0.8–1.0, test headless strutturali | §8 | [`godot-theme.md`](godot-theme.md) | 6–8 |
| D09 | Piano: 10 PR foundation-first su `aesthetic-2014`, merge finale atomico senza flag; gate fast per PR e full finale; harness a iframe + gallery Godot, niente golden images; fixture su data dir temporanea; checker in `tools/`, `tools/verify.sh` e `tools/export_web.sh`; copy server-origin tradotta lato client; docs canoniche in `docs/roblox-2014/`; spec congelata con change control a ticket | §11, §12, §13 | [`implementation-plan.md`](implementation-plan.md), [`acceptance.md`](acceptance.md) | 1–10 |
| D10 | Spec finale consolidata: docs canonici spostati, `GLOSSARY.md` committato, nessuna domanda aperta, riferimenti linkati | §1, §14, §15 | questa pagina, [`../GLOSSARY.md`](../../GLOSSARY.md) | 10 |

### 14.1 Note della mappa

| Nota | Riflessa in |
|---|---|
| Riferimento canonico metà 2014, desktop | §2.1–2.2 |
| Header blu, non grigio | §2.1, §5.1 |
| Client senza topbar, Game Menu nero/rosso fino al 27/08/2014 | §2.2, §9.6 |
| Pelle 2014 su layout e funzioni attuali, non clone 1:1 | §2.4 |
| Identità originale RobloxWeb, font open source | §2.4, §4.4 |
| Responsive: densità 2014 sopra 1000 px, degrado sotto | §2.4, §5.1, §6 |
| Sito in italiano, lessico adattato | §3 |
| Utente ha accettato i consigli; raccomandazione esplicita a ogni decisione | §14 (matrice completa) |
| Livello, server, API, DB invariati | §11 |
| Fuori scope: feature finte, Studio, mobile, asset Roblox | §2.5 |

## 15. Change control e chiusura

- **Spec congelata.** Le decisioni di questa pagina e dei documenti canonici sono chiuse.
  Nessuna PR può introdurre una variante visiva o di UX non prevista.
- **Scostamento.** Ogni scostamento passa da un nuovo ticket in
  `.scratch/roblox-2014-aesthetic/issues/` e da un aggiornamento di
  `.scratch/roblox-2014-aesthetic/map.md` prima del codice. Il ticket indica la
  decisione, la superficie e l'impatto su `acceptance.md`.
- **Nuovi riferimenti visivi.** L'utente può aggiungere screenshot o riferimenti in
  qualsiasi momento: si registrano in `research/`, si aggiorna `map.md` e, se cambiano
  una decisione, si apre un ticket. Non modificano retroattivamente l'implementazione
  già mergiata.
- **Documenti.** `docs/roblox-2014/` contiene spec, documenti canonici, ricerca,
  prototipo ed evidenze; `GLOSSARY.md` sta alla root; il tracker resta in `.scratch/`.
- **Chiusura dell'effort.** Tutte le righe di [`acceptance.md`](acceptance.md) sono
  verificate con evidenza; il gate full è verde; l'export Web funziona; `play.html`
  supera lo smoke; `git diff main...aesthetic-2014 -- server/` è vuoto; la PR 10
  aggiorna `AGENTS.md` e i documenti; contact sheet e acceptance sono riviste e firmate;
  il merge commit è su `main`.

## 16. Riferimenti

### 16.1 Riferimenti interni

- [Token](tokens.md) · [Mappa del sito](site-map.md) · [HUD client](hud-client.md) ·
  [Media](media-rules.md) · [Tema Godot](godot-theme.md) ·
  [Piano](implementation-plan.md) · [Accettazione](acceptance.md) ·
  [Glossario](../../GLOSSARY.md)
- [Ricerca sito 2014](research/sito-2014.md) · [Ricerca client 2014](research/client-2014.md)
- [Prototipo](prototype/README.md) · [Evidenze](evidence/README.md)
- Progetto: [`AGENTS.md`](../../AGENTS.md), [`PLAN.md`](../../PLAN.md),
  [`README.md`](../../README.md)

### 16.2 Fonti primarie del sito

Snapshot e CSS sono citati con ID in [`research/sito-2014.md`](research/sito-2014.md) §1.
I cinque snapshot rappresentativi:

1. Home, 13 giugno 2014 — <https://web.archive.org/web/20140613192903/http://www.roblox.com/>
2. Giochi, 13 giugno 2014 — <https://web.archive.org/web/20140613192917/http://www.roblox.com/games>
3. Dettaglio gioco, 20 giugno 2014 — <https://web.archive.org/web/20140620221326/http://www.roblox.com/Sword-Fights-on-the-Heights-IV-place?id=47324>
4. Login, 13 giugno 2014 — <https://web.archive.org/web/20140613192914/https://www.roblox.com/NewLogin>
5. Profilo, 18 luglio 2014 — <https://web.archive.org/web/20140718204454/http://www.roblox.com/User.aspx?ID=1>

Bundle CSS principale (S7):
<https://web.archive.org/web/20140613192857/http://www.roblox.com/CSS/Base/CSS/FetchCSS?path=main___67b87d83dbbb8c15045b82cb59da6d20_m.css>

### 16.3 Fonti primarie del client

CoreScripts al commit del 30 giugno 2014:
<https://github.com/Roblox/Core-Scripts/commit/8add333c8f77cbe43e9886aa70daa510972c8aaa>

Screenshot nativi e gallerie datate sono elencati con ID in
[`research/client-2014.md`](research/client-2014.md) §14. I riferimenti principali:

- `RobloxScreenShot06182014_091326830.png` — <https://roblox.fandom.com/wiki/File:RobloxScreenShot06182014_091326830.png>
- `RobloxScreenShot06152014_194850-757.png` — <https://roblox.fandom.com/wiki/File:RobloxScreenShot06152014_194850-757.png>
- `Menu.PNG` (Game Menu 2011–27/08/2014) — <https://roblox.fandom.com/wiki/File:Menu.PNG>
- `September 2013 chat.png` — <https://roblox.fandom.com/wiki/File:September_2013_chat.png>
- Timeline 2015 (topbar 23/04/2015) — <https://roblox.fandom.com/wiki/Timeline_of_Roblox_history/2015>
- In-experience menu — <https://roblox.fandom.com/wiki/In-experience_menu>
- People list — <https://roblox.fandom.com/wiki/People_list>

---

**Esito:** specifica consolidata, congelata e pronta per l'handoff. Nessuna domanda
aperta, nessuna decisione rinviata, nessun riferimento non linkato.
