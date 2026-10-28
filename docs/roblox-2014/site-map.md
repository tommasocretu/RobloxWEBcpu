# Mappa del sito — re-skin 2014

> Documento canonico della [specifica consolidata](spec.md).
> Base: `tokens.md`, prototipo variante **B**, ricerca `research/sito-2014.md`.
> **Approvato il 28 ottobre 2026.** Le decisioni sono chiuse e confluite nella spec.

## 1. Stato attuale

Sette pagine statiche + `site.js` + `site.css`, nessun build step:

| Pagina | Cosa è oggi |
|---|---|
| `index.html` | Home **e** catalogo: hero, sort, griglia, ricerca globale nell'header |
| `place.html` | Dettaglio gioco: media + info, play/like/report, dialog segnalazione |
| `play.html` | Barra scura 48 px + iframe Godot + overlay di caricamento |
| `login.html` | Card centrata con tab Accedi/Registrati + ospite |
| `profile.html` | Profilo a colonna: head, griglia “Le mie esperienze”, preferiti, dialog modifica/versioni |
| `admin.html` | Due colonne di card: segnalazioni e giochi nascosti |
| `studio.html` | Hero due colonne + box “Come pubblicare” |

L'header è generato da `RW.headerHTML()`: brand, Home, Studio, **search globale**, account. Il footer è una riga di testo per pagina.

## 2. Chrome globale

### 2.1 Header (36 px, blu `#114081`)

- Inner 970 px (1180 sulla home B), logo a sinistra, nav orizzontale, account a destra.
- **Niente ricerca globale:** nel 2014 la ricerca era locale alla pagina Giochi. Si sposta nel catalogo (approvato: `games.html`).
- **Ospite:** Home · Giochi · Studio · `Registrati` (link bianco) · “oppure” `#9EC3E7` · `Accedi` (`btn-control-large`) · `Ospite` (`btn-control`, mantenuto per non perdere il flusso attuale).
- **Account:** Home · Giochi · Studio · Profilo · `Moderazione` (solo admin) · username link al profilo · tag `Ospite` · `Esci` (`btn-control`).
- **Pagina attiva:** voce in grassetto bianco; niente underline o pill.
- **Hover:** `rgba(255,255,255,.14)`.
- **Play page:** barra minima, non nav completa: brand · titolo · autore · `N che giocano` · `Esci`.
- **Responsive:** sotto 1000 px la nav si compatta (Home, Giochi, account); sotto 700 restano brand + account + `Giochi`.

### 2.2 Footer (blu `#123F83`)

- Inner 970/1180, link solo a pagine reali: Home · Giochi · Studio · Profilo (se loggato) · Moderazione (se admin).
- Testo legale: “© 2026 RobloxWeb — piattaforma di giochi creati dagli utenti. Progetto locale in sviluppo.”
- Niente link morti (Chi siamo, Termini, Privacy, Forum) e niente “© 2014”: l'anno è quello corrente, l'estetica è 2014.
- Assente su `play.html` (schermo pieno).

### 2.3 Componenti condivisi

| Componente | Trattamento 2014 |
|---|---|
| Card gioco | Colonna 202 px, thumb 192×108 (16:9), bordo 1 px `#D2D2D2`, titolo 14/600, meta 12 px `#666`; hover con barra bianca “Gioca” in fondo alla thumb, **niente lift/ombra**; badge live non flottante: “N che giocano” nella meta |
| Card home B | 4 colonne a 1180, thumb 16:9 fluida, stessa tipografia |
| Pulsanti | `.btn-small` 20, `.btn-medium` 28, `.btn-large` 39; verde primario, blu neutro, grigio negativo; `.btn-control` 18/21/25 per header e toolbar |
| Tab | `#D6D6D6`, bordo `#9E9E9E`, attiva bianca, testo 15/700; usate per il sort in home |
| Input | Bordo `#A7A7A7`, altezza 21 px (medium), label 14/600, focus ring 2 px `#00A1DA` |
| Alert | Errore `#FAE5E5`/`#CC0000`, info `#E5EFFA`/`#0066CC`, warning `#FFF4D6`/`#AA6611`; bordo 1 px, raggio 0, padding 10 |
| Dialoghi | `<dialog>` nativo, bianco, titolo 27/700/−1, corpo 14, azioni a destra, overlay `rgba(0,0,0,.45)`; niente blur, niente radius |
| Tabelle | Header `#F1F1F1`, bordi `#CCC`, padding 5, righe alternate `#EEE`; usate in admin e storico versioni |
| Badge | Quadrato/2 px, 10–11 px bold, bordo 1 px, **testo sempre presente**: Pubblica, Non elencata, Privata, Nascosta, Admin |
| Empty/loading | Box `#F1F1F1` bordo `#CCC`, testo 14 `#666`, “Caricamento…” senza skeleton |
| Avatar | 48×48 autore, 352×352 profilo; placeholder blocky dal colore utente (ticket 07), bordo 1 px `#CCC` |
| Thumb | 192×108 card, 500×281 dettaglio, 430×230 hero; placeholder a studs + iniziale |
| Ricerca | Locale al catalogo: input 20 px, bordo `#BBB`, icona 16×16; nessuna search nell'header |
| Paginazione | Il 2014 aveva il pager 27×27; l'API restituisce tutti i giochi, quindi **niente pager** (deviazione dichiarata) |

> Regole media complete (crop, placeholder, avatar blocky, hero/sidebar/dettaglio) in [`media-rules.md`](media-rules.md).

## 3. Pagine

### 3.1 `index.html` — Home (variante B)

Struttura:

1. **Hero 1180** in stile box 2014 (bordo, blu, niente radius): h1 32 “Benvenuto su RobloxWeb”, paragrafo 15, CTA verde `Gioca ora` (ancora `#giochi`) + CTA blu `Crea` (→ `studio.html`); a destra art 430×230 del gioco più popolare con badge “In evidenza · <titolo>”.
2. **Sezione Giochi**: h2 30/400 “Giochi popolari”, tab 2014 `Popolari / Più apprezzati / Recenti` a destra, griglia 4 colonne, **8 card**, pulsante blu `btn-medium` “Vedi tutti” → `games.html`.
3. **Stati:** caricamento “Caricamento…”, errore alert 2014, empty “Nessun gioco trovato.” + link “Vedi tutti i giochi”.
4. **Dati:** `/api/places?sort=…` come oggi; il primo gioco popolare alimenta l'hero. Polling live 10 s, aggiorna “N che giocano” senza ridisegnare.
5. **Auth:** l'header gestisce accedi/ospite/profilo; l'hero non duplica “Ciao, nome”. Il guest button resta nell'header e in login.
6. **Copy:** “Giochi”, “che giocano”, “preferiti”; niente “esperienze” nell'interfaccia.

### 3.2 `games.html` — Giochi (nuova)

Pagina 970 con la struttura “Games” 2014:

- H1 “Giochi” 32.
- Riga filtri: select `Ordina per` (Popolari / Più apprezzati / Recenti) + campo ricerca locale + icona. **Niente filtri Tempo/Genere finti:** l'API non li supporta.
- Layout a due colonne: main 610 (griglia 3×202, card 192×108, 9+ giochi) + sidebar 300.
- Sidebar con dati reali:
  - “In evidenza”: il gioco più popolare, mini-thumb 300×160 + `Gioca`.
  - “Più giocati”: i primi 3, righe con thumb 64×36, titolo, visite.
  - “Crea il tuo gioco”: box con link a Studio.
- URL `games.html?q=&sort=`; il form di ricerca usa GET.
- Empty “Nessun gioco trovato.” + “Azzera ricerca”.
- Nessuna paginazione (l'API restituisce tutto).
- **Alternativa non scelta:** una sola home B come catalogo, ricerca nella riga filtri della home e 970+sidebar solo per place/profilo/admin.

### 3.3 `place.html` — Dettaglio gioco

- 970 px; `← Torna ai giochi` (o home).
- H1 32 sopra le due colonne, autore 14 con avatar 48.
- **Sinistra 500:** media 500×281 bordo `#CCC`, descrizione 14/1.4, eventuale “aggiornata il…”.
- **Destra 240:** `Gioca` verde `btn-medium` largo 150; `★ N preferiti` come `btn-control` (stella oro se attivo, grigia se no); link `Segnala`; box statistiche con righe `Visite / Giocano ora / Versione / Aggiornata`.
- **Ospite anonimo:** box “Accedi per giocare” 250 px con `Accedi`, `Registrati`, `Gioca come ospite`; il play button resta e reindirizza al login.
- **Owner:** link `Modifica` → profilo (il dialog resta nel profilo).
- **Nascosto:** alert warning 2014; non-admin: play disabilitato “Non disponibile”, like/report nascosti; admin può giocare.
- **Like:** diventa “Preferiti” con stella; API `/like` invariata.
- **Segnala:** dialog 2014 “Segnala gioco”, select motivo, textarea, `Invia segnalazione` verde, `Annulla` grigio.
- **403/404:** box errore 2014 “Gioco non trovato” + link.
- Polling 10 s su visite/live/preferiti, senza layout shift.

### 3.4 `play.html` — Gioca

- Barra blu 36 px: brand · `<titolo> · di <autore>` · `N che giocano` · `Esci` (`btn-control`). Niente nav completa, niente nome giocatore (la player list è nel client).
- Iframe a `calc(100vh - 36px)`, sfondo nero.
- **Caricamento:** area nera, testo `CARICAMENTO` 12 px maiuscolo e barra 300×18 con track `#8C8C8C` e fill `#D2D400`; niente spinner moderno. La barra è indeterminata finché non arriva `rw-ready`.
- **Errore:** box/modale bianco 2014 “Impossibile avviare il gioco”, messaggio 14, `Torna al gioco` grigio.
- `Esci` e `rw-leave` tornano a `place.html?id=…` (già gestito da `site.js`).
- Responsive <700: brand e autore nascosti, titolo + `Esci`; barra a piena larghezza.
- **HUD e widget:** la specifica è in [`hud-client.md`](hud-client.md). Il caricamento HTML è l'unico proprietario (`CARICAMENTO` + barra) e aspetta `rw-ready`; il client non mostra un boot in-canvas. Il conteggio `N che giocano` è nella barra, non nell'HUD.

### 3.5 `login.html` — Accedi / Registrati

- 970 px, **due colonne 465 + 484, entrambe visibili, niente tab**:
  - Sinistra: pannello “Accedi a RobloxWeb” con titolo h2 30/400, label + input medium 21 px, `Accedi` blu `btn-medium`, `Annulla` grigio, `Gioca come ospite` link blu.
  - Destra: pannello “Registrati” con titolo h2 30/400, username/password/ripeti, footnote 12 `#666`, `Crea account` verde `btn-medium`.
- Nota demo `demo/demo1234` in footnote 12 px (solo sviluppo).
- Se già loggato: alert info “Sei connesso come X” + link profilo/Esci; i form restano per cambiare account.
- Errori 2014 `#FAE5E5`/`#CC0000`.
- Responsive: stack, login prima, registrazione dopo.
- Il titolo “Bentornato!” e il sottotitolo moderno spariscono: titoli dei due pannelli.

### 3.6 `profile.html` — Profilo

- 970 px, **due colonne**:
  - **Sinistra 484:** h2 “<Nome>” 30, `@username · dal …` 12, avatar 352×352 bordo `#CCC`, box statistiche `#EEE` con righe `Giochi / Visite / Preferiti`, azioni `Apri Studio` + `Esci` (`btn-control-large`); ospite: `Registrati` + `Esci`; profilo pubblico: `Sfoglia i giochi`.
  - **Destra:** tab verticali 35 px (`Giochi`, `Preferiti` solo per il proprio profilo), pannello con bordo `#CCC`, griglia 2 colonne di card 202×108.
- **Giochi:** card con badge visibilità **testuale**, versione, visite, preferiti; sotto la card `Modifica`, `Versioni`, `Gioca` (solo owner). Pubblico: solo giochi pubblici, nessun badge.
- **Preferiti:** “Giochi preferiti”, stesse card ma senza azioni owner.
- **Empty:** “Non hai ancora pubblicato giochi. Apri Studio e premi Pubblica.” / “Questo autore non ha giochi pubblici.” / “Nessun gioco preferito.”
- **Dialog Modifica:** titolo 27, campi titolo/descrizione/visibilità, `Salva` verde, `Annulla` grigio, alert 2014.
- **Dialog Versioni:** tabella 2014 (Versione, Data, Dimensione, Azioni), badge “corrente”, `Ripristina` blu; conferma con modale 2014, non `confirm()`; `Chiudi` grigio.
- Polling live 12 s sulle card.

### 3.7 `admin.html` — Moderazione

- 970 px, h1 32, `← Torna alla home`.
- **Due sezioni impilate, non colonne di card**, ciascuna con tabella 2014:
  - “Segnalazioni aperte (N)”: colonne Gioco, Motivo, Segnalato da, Data, Azioni. Riga: titolo link + badge Visibile/Nascosta, autore 12; motivo; dettagli 12; `Ignora` `btn-control`, `Nascondi` `btn-control` con testo/bordo rosso.
  - “Giochi nascosti (N)”: colonne Gioco, Autore, Motivo, Data, Azioni; `Ripristina` `btn-control` verde.
- Conferme con modale 2014 (Nascondere/Ripristinare), default sicuro `Annulla`.
- Empty: riga “Nessuna segnalazione aperta.” / “Nessun gioco nascosto.”
- Non admin: box errore “Questa pagina è riservata agli amministratori.” + link home.
- Tabelle scrollabili in orizzontale sotto 700 px.

### 3.8 `studio.html` — RobloxWeb Studio

- 970 px, h1 32, due colonne fisse 600 + 300.
- Sinistra: intro 14/1.5; box download con due `btn-large` verdi `Scarica per Windows` / `Scarica per Linux` + meta “zip · x86_64”; nota 404 in piccolo; requisiti e comandi in `<code>` 2014.
- Destra: box “Come pubblicare” con lista numerata 14/1.6, box “Server locale” con comando e URL, `Torna ai giochi` `btn-neutral`.
- Niente hero moderno con gradienti/radius: box 2014 con bordo.
- Il download rotto resta un errore del browser; la nota dice di eseguire `./build_studio.sh`.

## 4. Vocabolario (approvato)

| Oggi | Proposto | Dove |
|---|---|---|
| Esperienze / esperienza | **Giochi / gioco** | nav, titoli, card, empty, pulsanti, admin, report |
| Esperienze che ti piacciono | **Giochi preferiti** | profilo |
| like / mi piace | **preferiti** (UI); API `/like` invariata | card, place, profilo |
| online / live | **N che giocano** / **giocano ora** | card, place, play |
| Più apprezzati | **Più apprezzati** (sort) | home/games |
| Crea | **Crea con Studio** / **Studio** | hero, nav |
| Catalogo | **Giochi** | nav; nessun “Catalogo” merci |
| Continua come ospite | **Gioca come ospite** | login/header |
| Torna alla home | **Torna ai giochi** (dove esiste games.html) | place/admin |
| Esperienza non trovata | **Gioco non trovato** | errori |

Termini di dominio da mettere in `GLOSSARY.md`: **Gioco** (unità user-facing), **Esperienza** (termine di dominio/marketing), **Place** (entità API), **Preferito** (like UI), **Ospite**, **Pubblico/Non elencato/Privato/Nascosto**.

## 5. Responsive

| Breakpoint | Comportamento |
|---|---|
| ≥1200 | home 1180, catalogo 970, due colonne piene |
| 1000–1199 | home fluida `min(1180px, 100% - 40px)`, catalogo 970 |
| <1000 | contenitori `100% - 32px`; griglie 2 colonne; place/login/profilo/studio stack; nav compatta |
| <700 | griglie 1 colonna; header brand + account + `Giochi`; play bar titolo + Esci; dialoghi `calc(100vw - 24px)` e scroll; tabelle admin scroll orizzontale |
| <480 | avatar profilo 200 px; card a piena larghezza; footer link in colonna |

Nessuna UI mobile 2014: è un degrado dignitoso.

## 6. Cosa non facciamo

- Niente Tix, Builders Club, catalogo merci, forum, party, leaderboard, Robux: solo estetica, nessuna feature finta.
- Niente “Notizie” o “Top creatori” inventati: la sidebar di `games.html` usa solo dati reali (featured, più giocati, Studio).
- Niente video introduttivo, splash login 2014, “Play Now” sprite: la home resta un catalogo con hero B.
- Niente footer con link morti; niente “© 2014” in produzione.
- Niente asset o logo Roblox: wordmark RobloxWeb + stud originale.
- Niente modifiche a server/API/DB: solo `WEBhtml/` (e i token condivisi con Godot).

## 7. Decisioni approvate

1. **Pagina Giochi:** creata `games.html` 970+sidebar; home B landing con 8 giochi e “Vedi tutti”; ricerca nel catalogo; nav “Giochi” → `games.html`.
2. **Pagine interne:** login a due colonne, profilo a due colonne con tab verticali, admin a tabelle, conferme con modale 2014 invece di `confirm()`.
3. **Vocabolario:** “Giochi/gioco”, “Preferiti”, “che giocano” nell'interfaccia; “esperienza” solo dominio/marketing, “place” solo API.
4. **Chrome:** niente search globale, nav Home/Giochi/Studio/Profilo(+Moderazione), footer con soli link reali e anno 2026, ospite in header e login, nessuna feature 2014 finta.

Nessuna decisione residua: la mappa è confluita nella [specifica consolidata](spec.md).
