# Token — estetica Roblox 2014

> Documento canonico della [specifica consolidata](spec.md).
> Valori storici da `research/sito-2014.md` e `research/client-2014.md`; le deviazioni deliberate sono marcate **[D]**.
> **Approvato il 28 ottobre 2026.** Questa è la tabella canonica dei token: nessun altro documento ridefinisce i valori.

## 1. Principi

1. **Il 2014 è chiaro, denso e squadrato.** Sito bianco, header blu, testo 14 px, card 192×108, niente ombre, niente angoli arrotondati (tranne tooltip e pannelli in-game).
2. **Il colore non è decorazione.** Blu = link/azione neutra, verde = azione primaria/positivo, rosso = errore/pericolo, oro = sistema/notifica in-game.
3. **Il testo si legge.** I valori 2014 che non passano il contrasto vengono corretti, non copiati.
4. **Niente dark mode.** Il 2014 non ce l'aveva e il re-skin non la introduce.
5. **Un solo set di valori.** CSS e Godot leggono la stessa tabella; un controllo automatico impedisce che divergano.

## 2. Token del sito

### 2.1 Colori

| Token CSS | Valore | Uso | Fonte |
|---|---|---|---|
| `--rw-color-header` | `#114081` | barra superiore, 36 px | V |
| `--rw-color-header-divider` | `#7394C1` | divisori nella barra | V |
| `--rw-color-nav-text` | `#FFFFFF` | voci nav | V |
| `--rw-color-nav-hover` | `rgba(255,255,255,0.14)` | hover nav (sprite 2014 ignoto) | **[D]** |
| `--rw-color-or` | `#9EC3E7` | “oppure” nell'header | V |
| `--rw-color-on-dark` | `#FFFFFF` | testo su header/footer/CTA | V |
| `--rw-color-footer` | `#123F83` | footer | V |
| `--rw-color-canvas` | `#FFFFFF` | sfondo pagina | V |
| `--rw-color-text` | `#343434` | testo primario | V |
| `--rw-color-text-secondary` | `#666666` | testi secondari, footnote, meta | V (2014 usava anche `#999`) |
| `--rw-color-text-muted` | `#767676` | testo attenuato su bianco, minimo 4.5:1 | **[D]** (2014: `#999`, 2.85:1) |
| `--rw-color-text-disabled` | `#A7A7A7` | disabilitato (esente contrasto) | V |
| `--rw-color-text-footer` | `#C7CFDD` | testo footer | **[D]** (2014: `#AAA`, 4.38:1) |
| `--rw-color-text-footer-legal` | `#AFC0D8` | legalese footer | **[D]** (2014: `#899FC1`, 3.78:1) |
| `--rw-color-link` | `#0055B3` | link | V |
| `--rw-color-link-hover` | `#0055B3` | hover: solo underline | V |
| `--rw-color-link-secondary` | `#095FB5` | link secondari/footer games | V |
| `--rw-color-border` | `#CCCCCC` | bordi standard | V |
| `--rw-color-border-input` | `#A7A7A7` | bordi input | V |
| `--rw-color-border-strong` | `#777777` | bottoni `btn-control`, dropdown | V |
| `--rw-color-border-table` | `#9E9E9E` | tabelle e tab | V |
| `--rw-color-surface-subtle` | `#F1F1F1` | intestazioni tabella, box | V |
| `--rw-color-surface-tab` | `#D6D6D6` | tab inattive | V |
| `--rw-color-surface-tab-hover` | `#E9E9E9` | tab hover | V |
| `--rw-color-surface-box` | `#E1E1E1` | box login/featured | V |
| `--rw-color-primary` | `#007001` | CTA primaria (Gioca, Pubblica) | V |
| `--rw-color-primary-hover` | `#005A01` | hover CTA primaria | **[D]** inferito |
| `--rw-color-primary-disabled` | `#99C699` | CTA primaria disabilitata | V |
| `--rw-color-neutral` | `#0852B7` | CTA neutra (Accedi, Vedi tutti) | V |
| `--rw-color-neutral-hover` | `#06408F` | hover CTA neutra | **[D]** inferito |
| `--rw-color-neutral-disabled` | `#9CBAE2` | CTA neutra disabilitata | V |
| `--rw-color-negative` | `#565656` | CTA negativa (Annulla) | V |
| `--rw-color-negative-hover` | `#404040` | hover CTA negativa | **[D]** inferito |
| `--rw-color-negative-disabled` | `#BBBCBB` | CTA negativa disabilitata | V |
| `--rw-color-danger` | `#CC0000` | errore, bordo messaggi | V |
| `--rw-color-danger-bg` | `#FAE5E5` | sfondo errore | V |
| `--rw-color-success` | `#007001` | conferma/positivo | V (verde CTA) |
| `--rw-color-warning` | `#AA6611` | warning, Tix | V |
| `--rw-color-info-bg` | `#E5EFFA` | conferma informativa | V |
| `--rw-color-info-border` | `#0066CC` | bordo conferma | V |
| `--rw-color-selection` | `#00A1DA` | selezione testo | V |
| `--rw-color-focus` | `#00A1DA` | focus ring 2 px | **[D]** (2014: `outline: none`) |
| `--rw-color-robux` | `#006600` | valuta Robux-like | V |
| `--rw-color-tix` | `#AA6611` | valuta Tix-like | V |
| `--rw-color-gold` | `#FFD700` | messaggi di sistema in-game | V |
| `--rw-color-loading-bar` | `#D2D400` | fill barra caricamento `play.html` | I (spostato dal client, ticket 06) |
| `--rw-color-loading-track` | `#8C8C8C` | track barra caricamento `play.html` | I (spostato dal client, ticket 06) |
| `--rw-color-loading-text` | `#E6E6E6` | testo `CARICAMENTO` in `play.html` | I |
| `--rw-color-overlay` | `rgba(0,0,0,0.45)` | overlay modali sito | **[D]** (2014 non dichiarato) |

**Accenti di prodotto** (non storici, ma coerenti): `--rw-color-like: #0055B3` (link), `--rw-color-like-icon: #FFD700` (stella), `--rw-color-live: #007001` (pallino/badge live), `--rw-color-hidden: #AA6611` (badge Nascosta). Approvati; l'uso è definito in [`media-rules.md`](media-rules.md) §7.

**Media:**

| Token CSS | Valore | Uso |
|---|---|---|
| `--rw-color-thumb-border` | `#D2D2D2` | bordo thumbnail delle card |
| `--rw-color-placeholder-ground` | `#3F8F3F` | prato del placeholder |
| `--rw-color-placeholder-studs` | `rgba(255,255,255,0.22)` | stud del placeholder |
| `--rw-color-avatar-bg` | `#EEEEEE` | fondo avatar blocky |
| `--rw-color-avatar-skin` | `#F5CD30` | testa/braccia avatar |
| `--rw-color-avatar-skin-dark` | `#B38F00` | bordo testa/braccia avatar |
| `--rw-color-avatar-fallback` | `#9E9E9E` | avatar senza colore |
| `--rw-color-hero-art-border` | `rgba(255,255,255,0.5)` | bordo art dell'hero |

### 2.2 Tipografia

| Token | Valore | Uso |
|---|---|---|
| `--rw-font-sans` | `"Source Sans 3", "Source Sans Pro", "Segoe UI", Arial, sans-serif` | tutto il sito |
| `--rw-font-size-body` | `14px` (`0.875rem`) | body, tabelle, form |
| `--rw-line-height-body` | `1.428` | body |
| `--rw-font-size-small` | `12px` (`0.75rem`) | meta, footnote, badge |
| `--rw-font-size-tiny` | `11px` (`0.6875rem`) | label minime, tooltip |
| `--rw-font-size-h1` | `32px` (`2rem`) / 700 / -1px | titolo pagina |
| `--rw-font-size-h2` | `30px` (`1.875rem`) / 400 / -1px | sezione |
| `--rw-font-size-h3` | `15px` (`0.9375rem`) / 700 | sottosezione, filtro |
| `--rw-font-size-nav` | `15px` (`0.9375rem`) / 600 | nav |
| `--rw-font-size-button-small` | `14px` | `.btn-small` |
| `--rw-font-size-button-medium` | `20px` | `.btn-medium` |
| `--rw-font-size-button-large` | `23px` | `.btn-large` |
| `--rw-font-size-modal` | `27px` / 700 / -1px | titolo modale |
| `--rw-font-size-footer` | `13px` | footer |
| `--rw-font-size-legal` | `12px` | legalese |

**Caricamento:** Source Sans 3 self-hosted, woff2, pesi 300/400/600/700; `font-display: swap`; preload di 400 e 600. Licenza OFL. La produzione non usa Google Fonts.

### 2.3 Spazi, bordi, raggi

| Token | Valore | Uso |
|---|---|---|
| `--rw-content` | `970px` | larghezza catalogo |
| `--rw-content-wide` | `1180px` | home B |
| `--rw-page-pad-y` | `5px` | padding verticale `#Body` 2014 |
| `--rw-page-pad-x` | `25px` | padding orizzontale `#Body` 2014 |
| `--rw-header-height` | `36px` | header |
| `--rw-footer-pad` | `20px` | footer |
| `--rw-space-1` | `5px` | ritmo 2014 |
| `--rw-space-2` | `7px` | nav, controlli |
| `--rw-space-3` | `10px` | card, box |
| `--rw-space-4` | `15px` | sezioni |
| `--rw-space-5` | `20px` | blocchi |
| `--rw-space-6` | `25px` | pagina |
| `--rw-space-7` | `30px` | titoli |
| `--rw-card-width` | `202px` | colonna card catalogo |
| `--rw-card-thumb-width` | `192px` | thumbnail |
| `--rw-card-thumb-height` | `108px` | thumbnail 16:9 |
| `--rw-sidebar-width` | `300px` | sidebar catalogo |
| `--rw-radius` | `0` | sito squadrato |
| `--rw-radius-tooltip` | `3px` | tooltip |
| `--rw-shadow` | `none` | niente ombre |
| `--rw-border-width` | `1px` | bordi |

### 2.4 Stati, motion, z-index

| Token | Valore | Uso |
|---|---|---|
| `--rw-state-hover` | `filter: brightness(0.92)` per CTA; underline per link | hover 2014 |
| `--rw-state-focus` | `outline: 2px solid var(--rw-color-focus); outline-offset: 1px` | **[D]** focus visibile |
| `--rw-state-disabled` | colori `*-disabled` + `cursor: default` | disabilitato |
| `--rw-motion-fast` | `120ms ease` | hover bordo/opacità |
| `--rw-motion-reduced` | `0.01ms` | `prefers-reduced-motion` |
| `--rw-z-header` | `30` | header sticky |
| `--rw-z-dropdown` | `40` | menu Altro |
| `--rw-z-modal` | `100` | modali sito |
| `--rw-z-toast` | `110` | toast sito |

**Niente transform, scale o bounce.** Il 2014 cambiava sprite, non animava le card.

## 3. Token del client (Godot)

### 3.1 Colori

| Token GDScript | Valore | Uso | Fonte |
|---|---|---|---|
| `UI_PANEL` | `Color(30,58,120,0.86)` | player list, pannelli | I |
| `UI_PANEL_DARK` | `Color(23,42,79,0.90)` | header player list, slot | I |
| `UI_BORDER` | `#6E7FA6` | bordi 1 px | I |
| `UI_TEXT` | `#FFFFFF` | testo | V |
| `UI_TEXT_SHADOW` | `#000000` | outline/ombra | V |
| `TEXT_DISABLED` | `#A7A7A7` | testo disabilitato | **[D]** (come sito) |
| `CHAT_BAR` | `Color(0,0,0,0.75)` | barra input chat | V |
| `HEALTH_TOP` | `#25B230` | alto gradiente salute | I |
| `HEALTH_MID` | `#00AB00` | centro | I |
| `HEALTH_DARK` | `#004F00` | fondo | I |
| `HEALTH_RED` | `#FF1C00` | sotto 25% | I |
| `GOLD` | `#FFD700` | system/admin | V |
| `MENU_SHIELD` | `Color(51,51,51,0.40)` | shield Game Menu | V |
| `MENU_BUTTON_BG` | `#000000` | fill pulsanti | V |
| `MENU_BUTTON_BORDER` | `#808080` | bordo normale | V |
| `MENU_DEFAULT` | `#C1272D` | bordo default | I |
| `INVENTORY_BG` | `#202020` | inventario | V |

**Palette nomi chat (8 BrickColor):** `#C4281C`, `#0D69AC`, `#27462D`, `#6B327C`, `#DA8541`, `#F5CD30`, `#B480FF`, `#D7C59A`.

**Stati e superfici dei widget (ticket 06):**

| Token GDScript | Valore | Uso |
|---|---|---|
| `CHAT_BAR_FOCUS` | `Color(0,0,0,0.88)` | input chat a fuoco |
| `PLAYERLIST_ROW_ALT` | `Color(255,255,255,0.06)` | righe pari player list |
| `MENU_TRIGGER_HOVER` | `Color(255,255,255,0.12)` | hover pulsante Menu |
| `MENU_BUTTON_HOVER` | `#111111` | hover pulsanti Game Menu |
| `BANNER_BG` | `Color(0,0,0,0.90)` | banner traguardo |
| `FOCUS` | `#00A1DA` | focus ring in-canvas |

> `LOADING_BAR`/`LOADING_TRACK` sono passati ai token del sito (ticket 06): il caricamento è HTML, non in-canvas.

### 3.2 Tipografia e misure

| Token | Valore | Uso |
|---|---|---|
| `FONT_UI` | Source Sans 3 | chat, health, messaggi |
| `FONT_LEGACY` | Liberation Sans | Game Menu, player list, backpack (sostituto Arial, OFL) |
| `FONT_SIZE_BODY` | `14px` | default del tema |
| `FONT_SIZE_TINY` | `11px` | header Monete, FPS debug |
| `FONT_SIZE_CHAT` | `12px` | chat |
| `FONT_SIZE_HEALTH` | `14px` | label Salute |
| `FONT_SIZE_MENU_TITLE` | `36px` | Game Menu / Leave |
| `FONT_SIZE_MENU_BUTTON` | `24px` | pulsanti principali |
| `FONT_SIZE_MENU_SMALL` | `18px` | pulsanti secondari |
| `FONT_SIZE_PLAYER_NAME` | `14px` | righe player list |
| `FONT_SIZE_PLAYER_HEAD` | `24px` | header player list |
| `OUTLINE_CHAT` | `3px` | outline chat |
| `OUTLINE_TEXT` | `2px` | outline label/health/menu/banner |
| `OUTLINE_SMALL` | `1px` | outline header Monete e debug |
| `CHAT_W` / `CHAT_H` | `500×120` | chat |
| `PLAYERLIST_W` | `150px` base + colonne | player list |
| `PLAYERLIST_ROW_H` | `20px` | righe |
| `PLAYERLIST_HEAD_H` | `56px` | header |
| `HEALTH_W` / `HEALTH_H` | `170×18` | health |
| `MENU_W` / `MENU_H` | `525×430` | Game Menu |
| `LEAVE_W` / `LEAVE_H` | `525×300` | Leave |
| `MENU_BUTTON_W` / `H` | `340×50` | pulsanti menu |
| `HOTBAR_SLOT` | `54×54` | hotbar (solo con tool) |
| `HOTBAR_GAP` | `6px` | gap |
| `HOTBAR_BOTTOM` | `31px` | bottom hotbar |
| `CHAT_INPUT_H` | `20px` | input chat |
| `UI_RADIUS` | `4px` | pannelli in-game |
| `UI_SCALE_BASE` | `1680×1000` | riferimento; scala sotto 1280×720 |

### 3.3 Widget del client (aggiunte del ticket 06)

Costanti solo client, nessun mirror CSS; il ticket 08 le legge da `rw_tokens.gd`.

| Token GDScript | Valore | Uso |
|---|---|---|
| `PLAYERLIST_COINS_W` | `52px` | colonna Monete |
| `PLAYERLIST_COLLAPSED_H` | `24px` | player list chiusa |
| `PLAYERLIST_ROWS_MAX` | `16` | cap del relay, nessuno scroll |
| `MENU_TRIGGER_W` / `H` | `92×48px` | pulsante Menu a scudo |
| `RESET_W` / `H` | `525×370px` | conferma reset |
| `DIALOG_BUTTON_W` / `H` | `128×50px` | Resta/Esci, Annulla/Reimposta |
| `BANNER_W` / `H` | `525×80px` | banner traguardo |
| `BANNER_Y` | `0.40` | centro verticale del banner |
| `CROSSHAIR_SIZE` | `4px` | punto in shift lock |
| `CHAT_INDENT` | `12px` | rientro del log chat |
| `CHAT_VISIBLE_LINES` | `8` | righe visibili |
| `CHAT_HISTORY` | `20` | righe conservate |
| `UI_SCALE_TRIGGER` | `1280×720px` | sotto, scala uniforme |
| `UI_SCALE_MIN` | `0.8` | scala minima supportata |

## 4. Accessibilità — deviazioni deliberate

| Tema | 2014 | Nostro | Perché |
|---|---|---|---|
| Testo attenuato | `#999` (2.85:1) | `#767676` (4.54:1) su bianco; `#666` su superfici | WCAG AA |
| Footer | `#AAA` (4.38:1) / `#899FC1` (3.78:1) | `#C7CFDD` / `#AFC0D8` | WCAG AA |
| Focus | `outline: none` | 2 px `#00A1DA`, offset 1 px, `:focus-visible` | WCAG 2.4.7 |
| Link nel testo | blu, senza underline | underline nei paragrafi; nav/card senza | WCAG 1.4.1 |
| Target piccoli | 18–25 px | area cliccabile minima 24×24 px, anche se il bottone resta 18–25 px | WCAG 2.5.8 |
| Motion | sprite istantanei | 120 ms, disattivati con `prefers-reduced-motion` | WCAG 2.3.3 |
| Colore unico | badge solo colore | badge con testo (Nascosta, Live, Admin) | WCAG 1.4.1 |

**Non** aggiungiamo outline permanenti, testi nascosti o icone moderne: il ring si vede solo da tastiera.

## 5. Storage e sincronizzazione

- **Sito:** blocco `:root` in `WEBhtml/assets/site.css` come fonte canonica dei token `--rw-*`. Nessun build step, nessun file in più da caricare.
- **Client:** `Godot/robloxwebengine/scripts/ui/rw_tokens.gd` con costanti `COLOR_*`, `FONT_SIZE_*`, `SIZE_*`, e un `Theme` costruito da quelle costanti (l'applicazione è del ticket 08).
- **Controllo:** `tools/check_design_tokens.py` legge il `:root` CSS e le costanti GDScript, confronta il sottoinsieme condiviso (colori e misure) e fallisce con un diff leggibile. Gira a mano e nei test.
- **Perché non un JSON + generatore:** il sito non ha build step e non vogliamo introdurne uno per il design. Il checker dà la stessa garanzia senza generare file.
- **Font:** `WEBhtml/assets/fonts/source-sans-3/` (woff2) e `Godot/robloxwebengine/assets/fonts/` (TTF). Includere `OFL.txt`. Liberation Sans solo client legacy.

## 6. Deviazioni dal 2014 (elenco completo)

1. Testo attenuato e footer schiariti per contrasto.
2. Focus ring visibile.
3. Link nei paragrafi sottolineati.
4. Area cliccabile minima 24×24 px.
5. Hover CTA con darkening 8% (il colore esatto degli sprite 2014 è ignoto).
6. `Source Sans 3` al posto di Source Sans Pro (successore, OFL).
7. `Liberation Sans` al posto di Arial nel client legacy (OFL, metric-compatibile).
8. Responsive sotto 1000 px (degrado, non UI mobile 2014).
9. Overlay modali sito `rgba(0,0,0,.45)` (2014 non documentato).
10. Niente Tix/Robux reali: i token restano per citazioni visive, non per funzionalità.

## 7. Documenti che usano questi token

- **05:** mappatura pagina-per-pagina in [`site-map.md`](site-map.md).
- **06:** widget del client in [`hud-client.md`](hud-client.md).
- **07:** thumbnail/card/avatar in [`media-rules.md`](media-rules.md).
- **08:** architettura del tema Godot in [`godot-theme.md`](godot-theme.md).
- **09:** piano PR e harness di verifica in [`implementation-plan.md`](implementation-plan.md) e [`acceptance.md`](acceptance.md).
- **10:** specifica consolidata in [`spec.md`](spec.md).

Nessun valore è lasciato ai ticket successivi: il set è chiuso e sincronizzato da `tools/check_design_tokens.py`.
