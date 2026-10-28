# HUD e widget del client — specifica 2014

> Documento canonico della [specifica consolidata](spec.md).
> Base: `tokens.md` (token approvati), prototipo client **B** (`prototype/client.html`), `research/client-2014.md`, `site-map.md` §3.4.
> **Approvato il 28 ottobre 2026.** Le decisioni sono chiuse e confluite nella spec.

## 1. Perimetro e principi

Il client usa la variante **B**: una barra HTML di 36 px è chrome del sito e vive fuori dall'iframe/CanvasLayer; dentro il gioco c'è solo l'HUD 2014. A metà 2014 non esisteva una topbar in-game (arriva il 23 aprile 2015), quindi dentro il CanvasLayer non compaiono brand, titolo, autore, conteggio giocatori o "Esci".

1. **Il centro resta libero.** Chat in alto a sinistra, player list in alto a destra, Menu in basso a sinistra, salute in basso al centro, input chat in basso.
2. **Misure fisse** su un riferimento 1680×1000; sotto 1280×720 l'HUD scala in blocco.
3. **Colori e font dai token**, nessun valore hardcoded. Pannelli blu notte traslucidi, bordi 1 px, raggio 4 solo dove previsto, niente ombre.
4. **Solo widget reali.** Niente Impostazioni, Aiuto, Screenshot, Report, Registra, backpack o toast se la funzione non esiste.
5. **Testo bianco con outline nero** sopra il mondo 3D; il testo della barra HTML usa i token del sito.
6. **Lessico:** gioco, lasciare, salute, monete, giocatori. "Esperienza" resta termine di dominio, mai nell'interfaccia.
7. **Niente topbar 2015** (`#1F1F1F`, tre icone in alto): non è il riferimento.

## 2. Inventario: esiste / non esiste / decorativo

| Widget | Stato | Dove / note |
|---|---|---|
| Barra HTML di `play.html` | **esiste** | 36 px, chrome del sito, fuori dal CanvasLayer |
| Brand, titolo, autore, `N che giocano`, `Esci` | **esiste** | nella barra HTML |
| Nome giocatore nella barra | **non esiste** | rimosso; il nome è nella player list |
| Topbar in-canvas | **non esiste** | arriva nel 2015, non è il riferimento |
| Pulsante `Menu` | **esiste** | basso sinistra, 92×48, forma a scudo |
| Game Menu | **esiste** | 525×430, nero/rosso |
| Dialogo `Lasciare questo gioco?` | **esiste** | 525×300 |
| Dialogo `Reimpostare il personaggio?` | **esiste** | 525×370 |
| Impostazioni / Aiuto / Screenshot / Report / Registra | **non esistono** | nessuna funzione reale dietro |
| Chat (log) | **esiste** | alto sinistra, 500×120, senza sfondo |
| Chat (input) | **esiste** | basso, piena larghezza, 20 px |
| Chat ospite | **esiste disabilitata** | placeholder + riga di sistema oro |
| Player list | **esiste** | alto destra, 202 px |
| Avatar nella player list | **non esiste** | il 2014 usava solo icone 16×16; noi nessuna |
| Pannello amico/report su click riga | **non esiste** | le righe non sono interattive |
| Contatore giocatori nell'HUD | **non esiste** | solo nella barra HTML e nelle righe |
| Chip `Monete: N / M` | **non esiste** | sostituito dalla colonna Monete |
| Colonna `Monete` | **esiste** | solo la riga locale ha un valore; gli altri `—` |
| Health bar | **esiste** | 170×18, basso centro |
| Hurt overlay | **esiste** | danno ≥ 5 HP |
| Schermata di morte / countdown | **non esiste** | respawn immediato |
| Messaggio centrale transitorio | **non esiste** | sostituito da chat oro + banner traguardo |
| Banner traguardo | **esiste** | 525×80, 5 s |
| Toast / notifiche social | **non esiste** | nessun evento sociale reale |
| Caricamento in-canvas | **non esiste** | l'overlay HTML è l'unico proprietario |
| Barra di caricamento | **esiste** | HTML, 300×18 |
| FPS | **non esiste** | debug nascosto con F3 |
| Backpack / hotbar / inventario | **non esiste** | nessun tool nel gioco |
| Mirino | **esiste** | solo con shift lock, punto 4×4 |
| Pillola `Lock Mouse` | **non esiste** | Shift è documentato nel Game Menu |
| Leaderboard | **non esiste** | — |
| Name tag 3D | **esiste invariato** | non è HUD, resta com'è |
| Stud del brand nella barra | **decorativo** | unico elemento decorativo ammesso |

Nessun widget è "decorativo ma finto": il prototipo mostrava un toast e un backpack che in produzione non esistono e non vanno replicati.

## 3. Layout, ancore, scala e z-order

### 3.1 Riferimento 1680×1000 (area di gioco, senza barra HTML)

```
┌──────────────────────────────────────────────────────────────────────┐
│ chat 500×120 (0,5)                     player list 202×N (0,5 da dx) │
│                                                                      │
│                              mondo 3D                                │
│                                                                      │
│ [Menu 92×48]                                                         │
│ [================ chat input, 20 px, piena larghezza ==============] │
│                          [health 170×18]                             │
└──────────────────────────────────────────────────────────────────────┘
```

| Widget | Ancora | Offset / misura |
|---|---|---|
| Chat log | sinistra-alto | `x=0`, `y=5`, 500×120; testo indentato 12 px |
| Player list | destra-alto | `right=0`, `y=5`, larghezza 202; altezza `56 + 20×N` |
| Pulsante Menu | sinistra-basso | `left=8`, `bottom=28`, 92×48 |
| Health | centro-basso | `bottom=22`, 170×18 |
| Chat input | sinistra+destra-basso | `left=0`, `right=0`, `bottom=0`, altezza 20 |
| Banner traguardo | centro | centro orizzontale, centro verticale al 40%, 525×80 |
| Mirino | centro | punto 4×4 |
| FPS debug | destra-basso | `right=12`, `bottom=28`, 11 px |
| Hurt overlay | schermo intero | sotto l'HUD, sopra il mondo |

### 3.2 Scala

La scala si calcola sull'area dell'iframe (viewport meno la barra HTML da 36 px):

```
scale = clamp(min(width / 1280, height / 720), 0.8, 1.0)
```

- Se entrambe le dimensioni sono ≥ 1280×720: `1.0`; nessun upscaling oltre 1680×1000.
- Sotto 1280×720: tutti i widget a misura fissa scalano insieme, inclusi font e offset; l'input chat resta ancorato a sinistra e destra (piena larghezza) e la player list resta ancorata a destra.
- Minimo supportato: schermo 640×400 (iframe 640×364) con scala 0.8. Sotto, il sito degrada e l'HUD può essere tagliato: non è un target.

| Area iframe | Scala | Chat | Player list | Game Menu |
|---|---|---|---|---|
| 1680×964 | 1.00 | 500×120 | 202 | 525×430 |
| 1366×732 | 1.00 | 500×120 | 202 | 525×430 |
| 1280×684 | 0.95 | 475×114 | 192 | 499×409 |
| 1024×732 | 0.80 | 400×96 | 162 | 420×344 |
| 800×564 | 0.80 | 400×96 | 162 | 420×344 |
| 640×364 | 0.80 | 400×96 | 162 | 420×344 |

L'input chat è l'eccezione: larghezza piena a ogni scala, altezza e font scalati (20 px e 12 px a scala 1.0).

Implementazione Godot: `godot-theme.md` §8. Il client usa `CONTENT_SCALE_MODE_DISABLED`; ogni CanvasLayer ha `scale = s` e un Root Control in design space `viewport / s`, così gli anchor restano ai bordi fisici e i font scalano con il canvas.

### 3.3 Z-order

| Livello | Contenuto | Note |
|---|---|---|
| HTML sopra l'iframe | overlay caricamento/errore (`z-index: 10`), barra (`z-index: 30`) | copre tutto finché il client non è pronto |
| CanvasLayer 40 | boot fallback standalone | solo se `/dev/index.html` è aperto fuori dal wrapper; fuori specifica |
| CanvasLayer 30 | shield + Game Menu / Leave / Reset | modale, sopra ogni cosa in-canvas |
| CanvasLayer 15 | FPS debug | sopra l'HUD, sotto il banner |
| CanvasLayer 20 | banner traguardo | sopra l'HUD, sotto i menu |
| CanvasLayer 10 | HUD: chat, player list, health, input chat, Menu, mirino | ordine figli: chat, player list, health, input, Menu, mirino |
| CanvasLayer 5 | hurt overlay | sotto l'HUD per non coprire i testi |
| 0 | mondo 3D | — |

Il banner non è un toast: non compare sopra i menu e non ha una pila di notifiche.

## 4. Barra HTML di `play.html`

### 4.1 Struttura

```
[stud] RobloxWeb   Welcome Obby · di RobloxWeb        3 che giocano   [Esci]
```

- Altezza **36 px**, sfondo `--rw-color-header` `#114081`, testo `--rw-color-on-dark`; bordo inferiore 1 px `--rw-color-header-divider` `#7394C1`.
- Padding orizzontale 15 px, gap 15 px. Nessuna ombra, nessun radius.
- **Brand:** stud + wordmark `RobloxWeb`, link a `/`. Font 14/600.
- **Titolo:** 14/700 bianco, ellissi se troppo lungo; nessun link.
- **Autore:** 13 px `--rw-color-or` `#9EC3E7`, testo `di <autore>`; link a `/profile.html?user=<owner_id>` quando `owner_id` è presente.
- **Conteggio:** 13 px bianco, `font-variant-numeric: tabular-nums`; forme `1 che gioca` / `N che giocano` / `Nessuno sta giocando`. Dal momento in cui il client è pronto il valore non scende sotto 1.
- **Esci:** link `btn-control` a `/place.html?id=<id>`; target minimo 24×24; focus ring del sito.
- **Nessun nome giocatore**, nessun `#play-player`.
- Sotto 700 px: restano solo titolo (ellissi) + `Esci`; brand, autore e conteggio nascosti. La barra resta alta 36 px.
- La pagina continua a richiedere una sessione (account o ospite); senza sessione si va al login, come oggi.
- `document.title = "Gioca a <titolo> — RobloxWeb"`.

### 4.2 Conteggio live

- Valore iniziale da `GET /api/places/<id>` (`live_players`).
- Polling ogni **10 s**, sospeso con `document.hidden`; nessun layout shift (larghezza minima del blocco).
- In caso di errore di rete si tiene l'ultimo valore; nessun alert.
- La player list in-game è la fonte autorevole delle righe; il numero nella barra è il conteggio del relay visto dall'API.

### 4.3 Stati della barra

| Stato | Titolo | Autore | Conteggio | Esci |
|---|---|---|---|---|
| Caricamento | `Caricamento…` | vuoto | `—` | attivo |
| Pronto | titolo del gioco | `di <autore>` linkato | valore API, min 1 | attivo |
| Errore API | `Caricamento…` o titolo se noto | vuoto | `—` | attivo |
| Poll fallito | invariato | invariato | ultimo valore | attivo |
| <700 px | titolo, ellissi | nascosto | nascosto | attivo |

### 4.4 Iframe

- `width: 100%`, `height: calc(100vh - 36px)`, bordo 0, sfondo `#000`.
- Nessun header del sito, nessun footer.
- L'overlay di caricamento ha `inset: 36px 0 0`.

## 5. Caricamento ed errori

### 5.1 Un solo proprietario

Nel wrapper `play.html` l'HTML è l'unico responsabile di caricamento ed errori di bootstrap. Il client Godot **non mostra** più `_show_boot` nel caso embedded: non ci sono due schermate sovrapposte.

### 5.2 Overlay di caricamento

- Area nera `#000` sotto la barra.
- Contenuto centrato: `CARICAMENTO` 12 px maiuscolo, `letter-spacing: 2px`, colore `--rw-color-loading-text` `#E6E6E6`; sotto, barra 300×18. Il maiuscolo 2014 sostituisce il generico "Caricamento…" della mappa.
- Barra: track `--rw-color-loading-track` `#8C8C8C`, fill `--rw-color-loading-bar` `#D2D400`, bordo 1 px `--rw-color-border-strong` `#777777`. Indeterminata (fill ~30% che scorre) finché non arriva `rw-ready`; con `prefers-reduced-motion` il fill resta fermo al 40%.
- Nessuno spinner moderno, nessun logo, nessun titolo del gioco.
- Transizione di uscita 120 ms (token motion), poi `pointer-events: none`.

### 5.3 Handshake

| Messaggio | Quando | Effetto |
|---|---|---|
| `rw-ready` | livello costruito e personaggio spawnato, anche se il WebSocket non è connesso | nasconde l'overlay e mostra il gioco |
| `rw-error` | errore fatale di bootstrap | mostra il box di errore; non nasconde la barra |
| `rw-leave` | uscita dal Game Menu | già gestito da `site.js`: torna a `place.html` |

- `rw-error` porta `{type, message, detail?}`. `message` è la frase breve, `detail` il suggerimento (es. "Controlla che il server sia attivo"). Il client compone il detail in `_on_place_failed`; `PlaceClient._fail` non deve più chiamare `_post_error`, altrimenti partirebbero due messaggi.
- L'evento `load` dell'iframe **non** nasconde più l'overlay: si aspetta `rw-ready`.
- Timeout di sicurezza **30 s**: box di errore `Il client non risponde. Ricarica la pagina.` Se `rw-ready` arriva dopo, l'errore sparisce e il gioco parte.
- Un fallimento del solo multiplayer non produce `rw-error`: è una riga oro in chat.

### 5.4 Box di errore

- Box bianco 2014, max 460 px, bordo 1 px `--rw-color-border`, padding 20, nessun radius.
- Titolo `Impossibile avviare il gioco` 27/700.
- Messaggio 14/1.428 `--rw-color-text`; detail 12/1.4 `--rw-color-text-secondary`.
- Pulsante `Torna al gioco` (`btn-negative`, grigio) verso `/place.html?id=<id>`.
- La barra HTML resta visibile e utilizzabile.

### 5.5 Testi di errore

| Codice | Testo |
|---|---|
| id non valido | `Gioco non valido. Apri un gioco dal catalogo.` |
| 401 | `Accedi per giocare.` |
| 403/404 | `Gioco non trovato o privato.` |
| 503 | `L'autore non ha ancora pubblicato una versione giocabile.` |
| rete | `Server non raggiungibile.` |
| export mancante | `Il client Web non è disponibile. Esegui l'export Godot in WEBhtml/dev/ e riprova.` |

## 6. Chat

### 6.1 Log

| Proprietà | Valore |
|---|---|
| Posizione | alto sinistra, `x=0`, `y=5` |
| Dimensione | 500×120 (scalata) |
| Sfondo | nessuno |
| Font | Source Sans 3 12 px, line-height 15 px |
| Testo | bianco `#FFFFFF`, outline nero 1 px |
| Rientro | 12 px |
| Righe visibili | 8 |
| Storico | 20 righe |
| Durata | 45 s per riga, dissolvenza 0,5 s |
| Ordinamento | nuove in basso, le vecchie scorrono in alto |
| Timestamp / tab / scrollbar | assenti |
| Join/leave | nessun messaggio |

- Formato: `Nome: testo`; il nome usa il colore deterministico, il testo è bianco.
- Righe di sistema: oro `GOLD` `#FFD700`, senza nome.
- Nomi colorati con la palette approvata, indice `somma dei byte UTF-8 del nome % 8`:

| Indice | Colore |
|---|---|
| 0 | `#C4281C` |
| 1 | `#0D69AC` |
| 2 | `#27462D` |
| 3 | `#6B327C` |
| 4 | `#DA8541` |
| 5 | `#F5CD30` |
| 6 | `#B480FF` |
| 7 | `#D7C59A` |

- Il nome locale usa lo stesso algoritmo degli altri: nessun colore speciale.
- Il testo dell'utente non è BBCode: si costruisce con `add_text`/`push_color`, mai parsing di tag forniti dall'utente.
- Storico azzerato a ogni nuovo livello, conservato attraverso morte e respawn.

### 6.2 Input

| Proprietà | Valore |
|---|---|
| Posizione | basso, `left=0`, `right=0`, `bottom=0` |
| Altezza | 20 px (scalata) |
| Sfondo | `CHAT_BAR` `rgba(0,0,0,0.75)`; focus `CHAT_BAR_FOCUS` `rgba(0,0,0,0.88)` |
| Testo | bianco 12 px, Source Sans 3 |
| Placeholder | `Per chattare clicca qui o premi "/"`, colore `rgba(255,255,0.9)` |
| Focus | bordo superiore 2 px `FOCUS` `#00A1DA` (deviazione focus visibile) |
| Apertura | click, tasto `/`, Invio |
| Invio | invia; con testo vuoto chiude |
| Esc | chiude senza inviare |
| Limite | 120 caratteri, `strip_edges`, vuoto ignorato |
| Movimento | disabilitato mentre l'input è aperto; ripristinato alla chiusura |

- `/` non inserisce lo slash: la chat non ha comandi.
- Mentre si scrive, il personaggio non si muove e il Game Menu non si apre con Esc (prima si chiude la chat).
- La chat non si apre se il Game Menu, Leave o Reset sono aperti.

### 6.3 Ospite

- All'ingresso: riga oro `Sei un ospite: accedi per chattare.`
- Input visibile ma disabilitato, placeholder `Gli ospiti non possono chattare.`
- `/`, Invio e click non aprono l'input; se l'utente insiste, riga oro `Gli ospiti non possono chattare. Accedi per usare la chat.`
- Il blocco server resta invariato: nessun invio lato client.

### 6.4 Stati

| Stato | Comportamento |
|---|---|
| Vuota | area vuota, nessun placeholder nel log |
| Con messaggi | ultime 8 righe, storico 20 |
| Input aperto | focus, movimento off, bordo cyan |
| Menu aperto | input chiuso; log sotto lo shield |
| Ospite | input disabilitato |
| Disconnesso | log invariato; riga oro di sistema |
| Nuovo livello | storico azzerato |
| Respawn | storico conservato |

## 7. Player list

### 7.1 Struttura

```
┌────────────────────────────┐
│ Giocatori         Monete   │ 56 px
├────────────────────────────┤
│ tu                  3/10   │ 20 px, locale in grassetto
│ Blocco99              —    │ 20 px
│ LavaGirl              —    │ 20 px
└────────────────────────────┘
```

| Proprietà | Valore |
|---|---|
| Posizione | alto destra, `right=0`, `y=5` |
| Larghezza | 202 px: 150 nome + 52 monete |
| Header | 56 px, `UI_PANEL_DARK`, bordo inferiore 1 px `UI_BORDER` |
| Righe | 20 px, max 16 (cap relay), nessuno scroll |
| Pannello | `UI_PANEL` 0.86, bordo 1 px `UI_BORDER`, raggio 4 |
| Righe alternate | overlay `PLAYERLIST_ROW_ALT` `rgba(255,255,255,0.06)` sulle pari |
| Bordo righe | 1 px `UI_BORDER` al 40% |
| Font | `FONT_LEGACY` Liberation Sans |
| Header nome | `Giocatori` 24/700 bianco, outline nero |
| Header monete | `Monete` 11/700 `UI_TEXT` |
| Nome riga | 14 px bianco, outline nero; locale in grassetto |
| Monete riga | 14/700 `GOLD` |
| Avatar / icone | nessuno |
| Click riga | nessuna azione, cursore normale |
| Ordinamento | alfabetico case-insensitive; il locale non è pinnato |
| Nomi lunghi | troncati con `…` nella colonna da 138 px |

- La riga locale mostra `collected/total` se `total > 0`, altrimenti `—`.
- Le righe remote mostrano sempre `—`: le monete sono client-side e sincronizzarle richiederebbe una modifica al relay, fuori scope.
- Il conteggio giocatori non si ripete nell'HUD: sta nella barra HTML e, implicitamente, nelle righe.

### 7.2 Collapse

- Click sull'header (o Invio/Spazio con focus) chiude la lista.
- Espansa: 56 px di header + righe.
- Chiusa: barra da 24 px con `Giocatori` 12 px a sinistra e chevron a destra; monete e righe nascoste.
- Lo stato è ricordato per la sessione, non persistito su disco.
- Default: espansa.

### 7.3 Aggiornamento

- All'avvio: riga locale con `net.player_name`.
- `peer_joined`: aggiunge e riordina.
- `peer_left`: rimuove.
- Disconnessione: rimuove tutti i remoti, resta il locale; riga oro in chat.
- Nuovo livello: riparte dal locale.
- Ospite: compare come qualsiasi altro giocatore.
- Test/network: funziona anche nella build nativa dev e in `test_network`.

## 8. Salute, danno, morte

### 8.1 Health bar

| Proprietà | Valore |
|---|---|
| Posizione | centro-basso, `bottom=22` |
| Dimensione | 170×18 |
| Bordo | nero 1 px, nessun raggio |
| Riempimento | `health / MAX_HEALTH`, tween 0,2 s |
| Gradiente | `HEALTH_TOP` `#25B230` → `HEALTH_MID` `#00AB00` 45% → `HEALTH_DARK` `#004F00` |
| Sotto 25% | `HEALTH_RED` `#FF1C00` |
| Label | `Salute` a destra, Source Sans 3 14/700 bianco, outline nero, 4 px dal bordo |
| Valore numerico | assente |
| Visibilità | sempre, anche a piena salute |

La barra non usa il colore da sola: la lunghezza del riempimento è l'informazione principale; il rosso è un rinforzo.

### 8.2 Hurt overlay

- Vignetta rossa ai bordi dello schermo, sotto l'HUD.
- Scatta quando il danno è **≥ 5 HP** (5% di 100), non su cura o respawn.
- Alpha 0 → 0,5 → 0 in **0,6 s**.
- Non blocca input né HUD.

### 8.3 Morte e respawn

- Il core 2014 non aveva una schermata di morte.
- Alla morte (salute 0 o caduta sotto la kill plane): nessun overlay, nessun countdown, nessun testo; il personaggio viene rimosso e respawna **immediatamente** come oggi.
- La salute torna a 100 e la barra si riempie; il respawn usa l'ultimo checkpoint.
- La player list e la chat restano; lo storico chat non si azzera.
- Un eventuale "Sei morto" è fuori specifica: sarebbe un'aggiunta di prodotto con ritardo di gameplay.

## 9. Pulsante Menu, Game Menu, Leave e Reset

### 9.1 Pulsante Menu

- Visibile solo nel client web in place mode. In Studio Test e build nativa dev resta il comportamento attuale (fuori scope) e il pulsante non compare.
- Posizione `left=8`, `bottom=28` (sopra l'input chat da 20 px), 92×48.
- Forma a scudo: rettangolo con punta a sinistra, bordo 1 px `UI_BORDER`, fill trasparente.
- Contenuto: casa bianca 24×24 + `Menu` 12 px bianco con outline nero.
- Stati: normale, hover (fill `MENU_TRIGGER_HOVER` `rgba(255,255,255,0.12)`), premuto, focus ring 2 px `FOCUS` `#00A1DA`.
- Click o Invio/Spazio apre il Game Menu.

### 9.2 Priorità di Esc

1. Chat input aperto → chiude la chat, non apre il menu.
2. Game Menu aperto → chiude il menu (`Riprendi`).
3. Leave aperto → `Resta` (chiude).
4. Reset aperto → `Annulla` (chiude).
5. Altrimenti → apre il Game Menu.

Esc non mette in pausa il gioco.

### 9.3 Game Menu

- Shield a schermo intero `MENU_SHIELD` `rgba(51,51,51,0.40)`, nessun bordo.
- Pannello 525×430 centrato, nessun fill: i pulsanti stanno sullo shield.
- Titolo `Menu di gioco` 36/700 Liberation Sans bianco, outline nero, centrato in alto.
- Pulsanti 340×50, `x=92` (centrati nel pannello da 525):
  - `Riprendi` a `y=54`, default (bordo 1 px `MENU_DEFAULT` `#C1272D`)
  - `Reimposta personaggio` a `y=105`
  - `Esci dal gioco` a `y=358`
- Fill nero `MENU_BUTTON_BG`, bordo 1 px `MENU_BUTTON_BORDER` `#808080`, testo bianco 24 px; hover fill `MENU_BUTTON_HOVER` `#111111`.
- Blocco statico `Comandi` tra `y=175` e `y=320`: titolo 18/700, righe 12 px/18:
  - `WASD — muoviti`
  - `Spazio — salta`
  - `Shift — blocca il mouse`
  - `/ o Invio — chat`
  - `Esc — menu`
- Niente Impostazioni/Aiuto/Screenshot/Report/Registra: non esistono funzioni dietro.
- Focus iniziale su `Riprendi`; Tab/Shift+Tab e frecce muovono il focus; Invio/Spazio attivano; Esc chiude.
- All'apertura: chiude la chat, rilascia il mouse/shift lock, disabilita il movimento del personaggio. Il mondo continua a girare (multiplayer, nessuna pausa).
- Alla chiusura: ripristina l'input e, se lo shift lock era attivo prima, lo riattiva.

### 9.4 Leave

- Il Game Menu si nasconde; appare il dialogo 525×300 sullo stesso shield.
- Titolo `Lasciare questo gioco?` 36/700 bianco, centrato, margine superiore 40.
- Pulsanti 128×50 in fondo (`bottom=22`): `Resta` a `x=90`, default con bordo rosso; `Esci` a `x=313`.
- `Resta` (o Esc): chiude tutto e torna al gioco.
- `Esci`: chiude tutto e chiama `place_client.leave()`; la pagina torna a `place.html`.
- Il pulsante `Riprendi` non è presente in questo dialogo.

### 9.5 Reset

- Il Game Menu si nasconde; appare il dialogo 525×370 sullo stesso shield.
- Titolo `Reimpostare il personaggio?` 36/700 bianco, centrato, margine superiore 40.
- Sottotesto `Tornerai al punto di spawn.` 18 px, centrato, `y=215`.
- Pulsanti 128×50 in fondo (`bottom=22`): `Annulla` a `x=90`, **default** con bordo rosso; `Reimposta` a `x=313`.
- `Annulla` (o Esc): chiude tutto e torna al gioco.
- `Reimposta`: chiude tutto e uccide il personaggio; il respawn è immediato e usa l'ultimo checkpoint.
- Deviazione dal 2014: il default è `Annulla`, non `Reimposta`, per evitare reset accidentali.

### 9.6 Macchina a stati

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

- Se il gioco non è ancora partito o è in errore, il Menu non si apre.
- Se il client è in Studio Test o nella build dev, questo sottosistema è disabilitato.

## 10. Eventi, messaggi e notifiche

Nessun toast: non ci sono amicizie, badge, acquisti o altri eventi sociali reali. Il toast del prototipo resta illustrativo e non va implementato.

| Evento | Canale | Testo | Durata |
|---|---|---|---|
| Ingresso account | chat oro | `Benvenuto, <nome>!` | 45 s (riga chat) |
| Ingresso ospite | chat oro | `Benvenuto, <nome>!` + `Sei un ospite: accedi per chattare.` | 45 s |
| Connessione multiplayer | chat oro | `Connesso in multiplayer!` | 45 s |
| Connessione persa | chat oro | `Connessione persa: modalità single player.` | 45 s |
| Server non raggiungibile | chat oro | `Server non raggiungibile: modalità single player.` | 45 s |
| Server rifiuta / stanza piena | chat oro | messaggio del server | 45 s |
| Checkpoint | chat oro | `Checkpoint raggiunto!` | 45 s |
| Tutte le monete | chat oro | `Hai raccolto tutte le monete!` | 45 s |
| Traguardo | banner + chat oro | `GIOCO COMPLETATO!` + `Traguardo raggiunto!` | 5 s banner, 45 s chat |
| Errore script | chat oro | `Script: <NomeScript>:<riga>: <messaggio>` | 45 s |
| Morte / respawn | nessuno | — | — |
| Join/leave di altri | nessuno | la player list basta | — |

### 10.1 Banner traguardo

- 525×80, centrato orizzontalmente, centro verticale al 40%.
- Fill `BANNER_BG` `rgba(0,0,0,0.90)`, bordo 1 px `MENU_DEFAULT` `#C1272D`, nessun raggio.
- Testo `GIOCO COMPLETATO!` 36/700 bianco, centrato.
- Entra e esce senza slide: fade 120 ms; resta 5 s.
- Non è un toast e non si accumula: un solo banner alla volta.

### 10.2 `show_message` e API

- `GameHUD.show_message` viene sostituito da due metodi espliciti: `add_system_line(text)` e `show_banner(text, duration)`.
- Le chiamate di `main.gd` per benvenuto, checkpoint, monete, connessione e script passano a `add_system_line`.
- Il vecchio `Message` centrale non esiste più per gli eventi ordinari.
- `print`/`warn` degli script restano nella console e nel pannello Output di Studio, non nell'HUD.

## 11. Debug e widget omessi

- **FPS:** nessun FPS nell'HUD. F3 mostra/nasconde un debug 11 px in basso a destra (`FPS 60`), stato non persistito, escluso da screenshot e demo.
- **Backpack/hotbar:** assenti. Non ci sono tool/inventario; con zero tool il 2014 non mostrava l'hotbar. Nessun chevron decorativo, nessun pannello inventario.
- **Mirino:** punto bianco 4×4 con outline nero 1 px, solo quando lo shift lock è attivo. Con il mouse libero si vede il cursore di sistema.
- **Lock Mouse:** nessuna pillola. Shift è documentato nel blocco Comandi del Game Menu.
- **Leaderboard:** assente. Le monete stanno nella player list.
- **Name tag 3D:** invariati, non fanno parte di questa specifica.
- **Toast:** assente.
- **Schermata di morte:** assente.

## 12. Testi (copy)

| Contesto | Testo |
|---|---|
| Barra, uscita | `Esci` |
| Barra, autore | `di <autore>` |
| Barra, conteggio | `1 che gioca` / `<N> che giocano` / `Nessuno sta giocando` |
| Caricamento | `CARICAMENTO` |
| Errore caricamento | `Impossibile avviare il gioco` |
| Errore, pulsante | `Torna al gioco` |
| Errore, timeout | `Il client non risponde. Ricarica la pagina.` |
| Chat, placeholder | `Per chattare clicca qui o premi "/"` |
| Chat, ospite | `Gli ospiti non possono chattare.` |
| Chat, avviso ospite | `Sei un ospite: accedi per chattare.` |
| Chat, blocco ospite | `Gli ospiti non possono chattare. Accedi per usare la chat.` |
| Player list, header | `Giocatori` / `Monete` |
| Player list, valore assente | `—` |
| Health | `Salute` |
| Menu, pulsante | `Menu` |
| Menu, titolo | `Menu di gioco` |
| Menu, voci | `Riprendi` / `Reimposta personaggio` / `Esci dal gioco` |
| Menu, comandi | `Comandi` + le cinque righe del §9.3 |
| Leave, titolo | `Lasciare questo gioco?` |
| Leave, pulsanti | `Resta` / `Esci` |
| Reset, titolo | `Reimpostare il personaggio?` |
| Reset, sottotitolo | `Tornerai al punto di spawn.` |
| Reset, pulsanti | `Annulla` / `Reimposta` |
| Traguardo, banner | `GIOCO COMPLETATO!` |
| Traguardo, chat | `Traguardo raggiunto!` |
| Checkpoint | `Checkpoint raggiunto!` |
| Monete complete | `Hai raccolto tutte le monete!` |
| Benvenuto | `Benvenuto, <nome>!` |
| Multiplayer | `Connesso in multiplayer!` |
| Disconnessione | `Connessione persa: modalità single player.` |
| Server assente | `Server non raggiungibile: modalità single player.` |
| Script | `Script: <NomeScript>:<riga>: <messaggio>` |
| Debug | `FPS <n>` |

Nessun testo in inglese nell'interfaccia, nessun "esperienza" nelle etichette, nessun "© 2014".

## 13. Accessibilità

- Focus ring 2 px `FOCUS` `#00A1DA` con offset 1 su pulsanti del menu, dialoghi, header player list e input chat (deviazione 04).
- Navigazione da tastiera completa nei menu: Tab/Shift+Tab, frecce, Invio/Spazio, Esc. Focus iniziale su `Riprendi`; `Resta` e `Annulla` sono i default sicuri.
- Il colore non è l'unica informazione: salute = lunghezza + rosso; locale = grassetto + nome; default = bordo rosso + focus; ospite = testo esplicito; monete = numero o `—`.
- Testi dell'HUD con outline nero per leggibilità su qualsiasi sfondo 3D.
- Target: pulsanti 340×50 e 128×50; Menu 92×48; header player list 202×56; l'input chat è pieno e alto 20 px (eccezione documentata: è un campo di testo a piena larghezza).
- Motion: 120 ms per hover/focus, 200 ms per la salute, 600 ms per l'hurt overlay; nessun bounce/scale.
- Il contrasto dei testi segue i token approvati; il giallo `#FFD700` è usato solo su pannelli scuri/nero.

## 14. Handoff implementativo

### 14.1 File

| File | Lavoro |
|---|---|
| `WEBhtml/play.html` | barra 36 px, conteggio, overlay caricamento/errore, handshake |
| `WEBhtml/assets/site.css` | stili della barra play, overlay, barra di caricamento, box errore |
| `WEBhtml/assets/site.js` | poll del conteggio (10 s, pausa in background), nessun header sito |
| `Godot/robloxwebengine/scenes/ui/hud.tscn` | nuova struttura: chat, player list, health, input, Menu, mirino, banner, hurt, FPS debug; tema/layout da `godot-theme.md` |
| `Godot/robloxwebengine/scripts/ui/hud.gd` | API `add_system_line`, `show_banner`, `set_player_list`, `set_local_coins`, `set_menu_enabled`, stati chat/menu |
| `Godot/robloxwebengine/scenes/ui/game_menu.tscn` + `scripts/ui/game_menu.gd` | shield, Game Menu, Leave, Reset; nodo `GameMenu`, distinto dal `Menu` iniziale |
| `Godot/robloxwebengine/themes/rw_theme.gd` + `scripts/ui/rw_layout.gd` | tema runtime da `rw_tokens.gd`, varianti `Rw*`, design space e content scaling (`godot-theme.md`) |
| `Godot/robloxwebengine/scripts/main.gd` | alimenta la player list, gestisce menu/leave/reset, toglie `_show_boot` embedded, posta `rw-ready`/`rw-error` |
| `Godot/robloxwebengine/scripts/net/place_client.gd` | `rw-error` con `message` + `detail`; nessun boot |
| `Godot/robloxwebengine/scripts/player/remote_character.gd` | espone `display_name` per la player list |
| `Godot/robloxwebengine/tools/test_network.gd` | usa `hud.chat_has_line(...)` invece di `ChatLog.text.contains(...)` |
| `tools/check_design_tokens.py` | verifica i nuovi token condivisi; i token client-only restano in `rw_tokens.gd` |

Nessuna modifica a server, API, DB, relay o formato livello.

### 14.2 API del HUD

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

`set_players(int)` e `set_coins(int, int)` vengono ritirati o diventano wrapper interni.

### 14.3 Dati player list

- `main.gd` mantiene `_remote_names: Dictionary` (id → nome) oppure legge `remote.display_name`.
- `RemoteCharacter.setup(name, ...)` già riceve il nome: basta salvarlo in una property.
- Al `peer_joined` si aggiunge, al `peer_left` si rimuove; `set_player_list` riordina alfabeticamente.
- Il locale è `net.player_name` (o `menu.player_name()` in dev).

### 14.4 Handshake web

- In `main.gd`, dopo `_on_place_loaded` → `_on_play_pressed` → personaggio creato, chiamare `place_client.post_ready()` una sola volta per caricamento.
- `post_ready()` fa `window.parent.postMessage({type:'rw-ready'}, origin)` solo se `OS.has_feature("web")`; se `window.parent === window`, non fa nulla.
- `_on_place_failed` compone `detail` e chiama `post_error(message, detail)`.
- `PlaceClient._fail` chiama solo `request_failed`; `_post_error` viene rimosso o reso privato e usato solo da `post_error`.
- `place_client.leave()` resta invariato (`rw-leave`).

## 15. Verifica e accettazione

### 15.1 Checklist funzionale

- [ ] La barra HTML mostra brand, titolo, autore linkato, conteggio, `Esci`; nessun nome giocatore; alta 36 px.
- [ ] Il conteggio si aggiorna ogni 10 s, non scende sotto 1 a gioco pronto, non fa layout shift.
- [ ] L'overlay di caricamento resta finché arriva `rw-ready`; `rw-error` mostra il box; il timeout 30 s funziona.
- [ ] La chat conserva 20 righe, ne mostra 8, sfuma a 45 s, colora i nomi in modo stabile, usa l'oro per i system.
- [ ] La chat si apre con click, `/` e Invio; Esc chiude; il movimento si blocca mentre si scrive; l'ospite è bloccato.
- [ ] La player list mostra locale in grassetto, ordina alfabeticamente, gestisce join/leave, collassa a 24 px, mostra `3/10` solo sul locale e `—` sugli altri.
- [ ] La salute scende, diventa rossa sotto 25%, l'hurt overlay scatta solo per danni ≥ 5; la morte respawna subito senza schermata.
- [ ] Il Menu si apre con click e Esc; il flusso Esc → Leave → `Resta`/`Esci` è a due passi; `Riprendi` è il default; Reset ha `Annulla` default.
- [ ] Il Game Menu non appare in Studio Test/native dev; il pulsante Menu è nascosto lì.
- [ ] Il traguardo mostra il banner 5 s e la riga oro; nessun toast.
- [ ] F3 mostra/nasconde l'FPS; backpack e Lock Mouse non esistono.
- [ ] A 1680×1000, 1366×768, 1280×720, 1024×768, 800×600 e 640×400 l'HUD resta dentro lo schermo e leggibile.

### 15.2 Test esistenti

- `tools/test_gameplay.gd`: invariato (Menu iniziale ≠ Game Menu).
- `tools/test_network.gd`: aggiornare l'assert sulla chat a `hud.chat_has_line(...)`.
- `tools/test_lua.gd`: invariato.
- `tools/test_studio.gd`: invariato; verificare che il client web non includa `game_menu` se è una scena separata, o che il tema non rompa l'export.
- `server/tests`: invariati.

### 15.3 Test e harness

- Unit headless per: palette deterministica, ordinamento player list, collapse, history/timer chat, formula di scala, macchina a stati del menu.
- Visuale: screenshot a 1680×964, 1280×684, 1024×732, 800×564, 640×364; stati chat vuota/5 righe/input aperto, player list 1/4/16, salute 100/24/0, menu/leave/reset, banner traguardo, overlay caricamento/errore.
- Browser tool per `play.html`: conteggio, handshake, errore, `Esci`.
- L'harness completo (fixture, matrice, gallery, gate) è definito in [`implementation-plan.md`](implementation-plan.md) §6–8.

## 16. Deviazioni e adattamenti

**Adattamenti dichiarati (non fedeltà 1:1):**

1. Il caricamento è HTML, non in-canvas: una sola schermata, barra `#D2D400` come il web player 2014.
2. Niente Impostazioni/Aiuto/Screenshot/Report/Registra: non esistono le funzioni.
3. Niente backpack/hotbar: non esistono tool/inventario.
4. Niente pillola Lock Mouse: Shift è nel menu.
5. Monete solo locali nella player list: il relay non sincronizza le monete e non si tocca.
6. Mirino 4×4 solo in shift lock: il 2014 mostrava il cursore di sistema, ma qui il mouse è catturato.
7. FPS su F3: debug, non UI.
8. Nessuna schermata di morte (fedele al core 2014).
9. Nessun toast: nessun evento sociale.
10. Copy italiana: il lessico 2014 è adattato, non tradotto.

**Deviazione di sicurezza:**

11. Nel Reset il default è `Annulla`, non `Reimposta` come nel 2014.

## 17. Decisioni approvate

1. Barra HTML 36 px con brand, titolo, autore linkato, conteggio via polling 10 s ed `Esci` diretto; niente nome giocatore.
2. Un solo caricamento HTML con handshake `rw-ready`/`rw-error`, timeout 30 s, nessun boot in-canvas embedded.
3. Chat 500×120 in alto a sinistra, 8 righe visibili/20 conservate, 45 s, nomi colorati, system oro, input full-width 20 px, ospite disabilitato, movimento bloccato mentre si scrive.
4. Player list 202 px (150+52) in alto a destra, header 56, righe 20, niente avatar, locale in grassetto, monete solo locali, collapse a 24 px.
5. Salute 170×18, gradiente verde, rossa sotto 25%, hurt overlay ≥5 HP; morte senza schermata e respawn immediato.
6. Menu a scudo in basso a sinistra, Game Menu 525×430 nero/rosso con soli comandi reali, Leave 525×300, Reset 525×370 con `Annulla` default; nessuna pausa.
7. Chat oro per gli eventi, banner 525×80 solo per il traguardo, nessun toast.
8. FPS solo su F3, backpack assente, mirino solo in shift lock.
9. Scala `clamp(min(w/1280, h/720), 0.8, 1.0)`; input chat a piena larghezza; minimo 640×400.

Esito: specifica HUD/widget consolidata nella [specifica](spec.md) e pronta per l'implementazione.
