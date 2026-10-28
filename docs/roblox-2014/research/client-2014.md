# Client Roblox — UI in-game di metà 2014

**Ambito:** client desktop, giugno 2014 (punto di riferimento: snapshot CoreScripts del 30 giugno 2014).
**Data della ricerca:** 28 ottobre 2026.
**Uso:** riferimento per il re-skin 2014 di RobloxWeb. Nessun asset Roblox è stato scaricato o committato: solo URL, screenshot di riferimento in `/tmp` e valori.

> **Stato:** ricerca storica di riferimento. Le raccomandazioni e le incertezze della
> fonte sono state chiuse in [`hud-client.md`](../hud-client.md) e
> [`tokens.md`](../tokens.md); non sono decisioni aperte.

Legenda affidabilità:

- **V** = verificato su fonte primaria (codice CoreScripts d'epoca, screenshot nativo datato, pagina wiki con datazione esplicita).
- **I** = inferito o ricostruito (engine C++ non pubblico, screenshot non datati, convenzione di famiglia visiva).
- **R** = raccomandazione di design per RobloxWeb, non un valore storico.

## Metodo

- **Codice primario:** snapshot del repo ufficiale `Roblox/Core-Scripts` al commit `8add333c8f77cbe43e9886aa70daa510972c8aaa` (30/06/2014), letto da `raw.githubusercontent.com`. I file rilevanti sono `ChatScript.lua`, `PlayerListScript.lua`, `HealthScript.lua`, `NotificationScript.lua`, `Settings.lua` e `BackpackScripts/*`.
- **Screenshot primari:** screenshot nativi `RobloxScreenShot06182014_*` e `RobloxScreenShot06152014_*` (giugno 2014, 1680×988/1000), più `Menu.PNG`, `Classic Connecting Loading Screen.png` e le gallerie datate della wiki. Le immagini sono state scaricate solo in `/tmp` per ispezione e misura (PIL), non committate.
- **Date di cambio:** wiki Roblox (Fandom) per i confini temporali (topbar aprile 2015, menu agosto 2014, safe chat aprile 2014); la fonte primaria resta il codice e lo screenshot datato.
- **Video:** non usati per le misure. I frame YouTube 2014 sono spesso ricompresi o ricostruiti; gli screenshot nativi 1680×1000 sono più affidabili. I video sono citati solo dove la wiki li usa come galleria.
- **Limite:** l'engine C++ (Menu button, Lock Mouse, toast `SendNotification`, loading) non è pubblico; per questi elementi le misure vengono dagli screenshot e sono marcate **I**.

## Risposta in breve

1. **Nel client di metà 2014 non esiste una topbar in-game.** Non c'è nessuna barra persistente in alto, nessun logo, nessun player count, nessun pulsante "Leave" in alto. L'header scuro che si vede nel 2014 è quello del **sito**, non del client. **V**
2. La navigazione in-game è in **basso a sinistra**: un pulsante a forma di scudo con casa + scritta `Menu`. Il backpack/hotbar è in **basso al centro**, la chat in **alto a sinistra** (messaggi) e in **basso a sinistra** (input), la player list in **alto a destra**, la health bar in **basso al centro**. **V**
3. La topbar con le tre icone in alto a sinistra arriva il **23 aprile 2015**. Fino a quella data la "navigation bar" è quella inferiore. **V** (screenshot + timeline wiki; vedi §1).
4. Il menu Esc è il **Game Menu** nero/rosso, non il menu grigio/blu di fine 2014. Il cambio di stile avviene il **27 agosto 2014**. **V** (wiki + due screenshot).
5. Il player count non è un numero nell'HUD: la player list mostra le righe dei giocatori. Il conteggio "Playing: N" vive nella pagina web dell'esperienza, non nel CanvasLayer. **V/I**

> **Conseguenza per il re-skin:** non aggiungere una finta topbar 2014 al client Godot. L'eventuale barra con titolo/autore/leave resta nell'HTML di `play.html` come chrome del sito; dentro il gioco si replica il Menu in basso a sinistra e il Game Menu su Esc. **R**

---

## 1. Topbar e navigazione in-game

### 1.1 Cosa c'era (e cosa no)

| Voce richiesta dal ticket | Metà 2014 | Evidenza |
|---|---|---|
| Altezza topbar | **0 px: non esiste** | Tree CoreScripts 30/06/2014 senza `Topbar.lua`; screenshot giugno 2014 senza barra superiore. **V** |
| Colore topbar | n/a | — |
| Logo in-game | assente | Screenshot 18/06/2014 e 15/06/2014: nessun logo a schermo. **V** |
| Voci/pulsanti in alto | nessuno | Idem. **V** |
| Player count | assente dall'HUD; la player list mostra le righe | `PlayerListScript.lua` non crea un contatore. **V** |
| "Leave" | nel Game Menu (Esc), voce `Leave Game` | `Settings.lua`, `createGameMainMenu`. **V** |

La confusione nasce perché la **home del sito** nel 2014 aveva l'header scuro con logo, `Home / Games / Catalog / Leaderboards / Builders Club / Forum / More`, Robux e username. Quello è chrome del sito, non del client. **V** (screenshot sito 2014; ticket 01).

Nota di supporto: nei CoreScripts del 30/06/2014 le sole core GUI disattivabili sono `All`, `Backpack`, `Chat`, `Health`, `PlayerList`; non esiste un `CoreGuiType.Topbar`. **V** (`grep` sui CoreScripts).

### 1.2 Quando compare la topbar

- **23 aprile 2015:** "The in-game navigation bar is updated, introducing a new topbar with 3 icons at the left, as well as the default smile." Fonte: Roblox Wiki, *Timeline of Roblox history/2015*. **V**
- La topbar 2015-2020 (versione 2018 del codice) è alta **36 px** (costante; l'immagine `Topbar 2015.png` è 721×34, ritagliata), colore **`#1F1F1F`**, username a destra, health integrata. Fonte: `TopbarConstants.lua`. **V** — da **non** usare per il 2014.

### 1.3 La navigazione reale: Menu in basso a sinistra

Dagli screenshot nativi di giugno 2014 (1680×1000):

- **Menu button**: in basso a sinistra, circa **92×48 px**, circa **8 px dal bordo sinistro** e **20 px dal fondo** (sopra la barra chat). Forma a scudo/pentagono con il lato sinistro smussato, **fill trasparente**, **bordo 1 px** grigio-azzurro chiaro, icona casa bianca ~24×24 e testo `Menu` ~12 px bianco con ombra nera. **V** (screenshot) / **I** (misure, engine C++).
- **Lock Mouse**: sopra il Menu, pillola trasparente con bordo, ~**142×25 px**, icona lucchetto bianca, testo `Lock Mouse` bianco e `SHIFT` in verde. Compare quando il mouse è libero; è un indicatore di stato, non un pulsante di navigazione. **V** (screenshot) / **I** (comportamento).
- **Backpack button**: in basso al centro, sopra l'hotbar, **120×18 px**, forma a trapezio con doppio chevron verso l'alto, fill trasparente e bordo chiaro. Apre l'inventario. **V** (CoreScripts: `BackpackButton.Size = UDim2.new(0, 120, 0, 18)`, posizione `0.5,-60, 1,-108`).

> **R:** in Godot il `Menu` button va disegnato come Control separato, ancorato bottom-left, sopra la barra chat; non deve essere una topbar. Il `Lock Mouse` può essere omesso se il gioco non ha mouse lock.

---

## 2. Chat

Fonte primaria: `CoreScripts/ChatScript.lua` @ `8add333c8f77cbe43e9886aa70daa510972c8aaa` (30/06/2014). **V** salvo dove indicato.

### 2.1 Struttura

| Proprietà | Valore 2014 | Note |
|---|---|---|
| Finestra messaggi | **500×120 px**, posizione **(0, 5)** | `Chat:CreateGui`: `Size = UDim2.new(0, 500, 0, 120)`, `Position = UDim2.new(0, 0, 0, 5)` |
| Sfondo messaggi | **nessuno** (trasparente) | `BackgroundTransparency = 1.0`; l'immagine di sfondo `97120937` esiste ma è `Visible = false` |
| Bordo | `#ECECEC` 1 px a 80% altezza, `Visible = false` di default | `Border` frame |
| Font | default del client (all'epoca Source Sans Pro; il codice non imposta `Font`); **Size12** | `Configuration.FontSize = Enum.FontSize.Size12` |
| Colore messaggio | bianco `#FFFFFF` | `MessageColor = Color3.new(1,1,1)` |
| Colore admin/system | oro `#FFD700` (1, 215/255, 0) | `AdminMessageColor` |
| Stroke | nero, trasparenza 0.8 / 1.0 a seconda dello stato | `TextStrokeColor3 = 0.5` o nero, `TextStrokeTransparency` 0.75/1.0 |
| Indentazione | 2.5% della larghezza della finestra (~12.5 px) | `XScale = 0.025` |
| Storico | 20 messaggi (commento: "up to 50"); ring buffer fino a 100 TextLabel | `HistoryLength = 20` |
| Durata | 45 s | `LifeTime = 45` |
| Ordinamento | i messaggi nuovi stanno in basso; i vecchi scorrono in alto | codice di shift + screenshot |
| Tab | **nessuna** | il ChatScript 2014 non crea tab |
| Safe chat | **rimossa il 3 aprile 2014** | Roblox Wiki, *Chat*: "On April 3, 2014, the Super Safe Chat button was removed" |

### 2.2 Colori username

Palette di 8 `BrickColor` scelta in modo **deterministico dal nome** (`GetNameValue`: hash dei byte del nome, modulo 8), quindi stabile per lo stesso giocatore (`ChatColors`):

`Bright red`, `Bright blue`, `Earth green`, `Bright violet`, `Bright orange`, `Bright yellow`, `Light reddish violet`, `Brick yellow`.

Approssimazione RGB (BrickColor, non campionata): `#C4281C`, `#0D69AC`, `#27462D`, `#6B327C`, `#DA8541`, `#F5CD30`, `#B480FF`, `#D7C59A`. **V** (nomi) / **I** (RGB).

### 2.3 Input

| Proprietà | Valore |
|---|---|
| Barra input | **larghezza piena × 20 px**, ancorata in basso (`1,0`) |
| Sfondo | nero, **trasparenza 0.25** (75% opaco) |
| Testo | bianco, **Size12**, allineato a sinistra |
| Placeholder | `To chat click here or press "/" key`, colore **(1, 1, 0.9)**, Size12 |
| Apertura | click sul placeholder oppure tasto `/`; Invio invia |
| Posizione messaggi | **alto a sinistra**, non in basso: la finestra 500×120 parte da y=5 |

> **Attenzione:** gli screenshot di giugno 2014 mostrano in alcuni giochi una chat **custom** con riquadri scuri per riga e messaggi `Server:` gialli. Non è la chat core: la chat core è testo bianco con stroke nero, senza sfondo. Non copiare i riquadri come stile di default. **V** (confronto codice vs screenshot).

> **R:** in Godot usare una `RichTextLabel` in alto a sinistra (500×120, 7-8 righe, 12 px), nomi colorati con la palette, testo bianco con outline nero 1 px, nessun pannello di sfondo. La `LineEdit` va in basso, larga tutto lo schermo, 20 px, nero al 75%, placeholder `Per chattare clicca qui o premi "/"`.

---

## 3. Player list

Fonte primaria: `CoreScripts/PlayerListScript.lua` @ 30/06/2014. **V** salvo dove indicato.

### 3.1 Struttura

| Proprietà | Valore |
|---|---|
| Posizione | **alto a destra**: `Position = UDim2.new(1, -150, 0.005, 0)` |
| Larghezza base | **150 px**; si allarga con le colonne leaderstats |
| Altezza | **800 px** (poi si comprime al contenuto) |
| Header | **7% di 800 = 56 px**; immagine di sfondo asset `94692054` |
| Nome header | `ArialBold`, **Size24**, bianco, stroke nero, allineato a destra |
| Punteggio header | `ArialBold`, Size24, bianco, allineato a destra |
| Righe | **150×20 px** (`0.5` di 300 × `0.025` di 800) |
| Nome riga | `Arial`, **Size14**, bianco |
| Punteggio riga | `ArialBold`, Size14 |
| Icone | **16×16 px**: BC/TBC/OBC, amico, admin; nessun avatar |
| Bottom bar | **3% di 800 = 24 px**; immagine `94754966`; chevron di collapse `94692731` |
| Sfondo righe | immagini alternate chiare/scure: `97112126` / `97109338`; top `97108784` |
| Local player | riga in `ArialBold` con drop shadow nero |
| Ordinamento | alfabetico (commit "Sort players alphabeticly", 27/06/2014) |
| Avatars | **assenti**: solo icone 16×16 |

### 3.2 Interazione

- Click sull'header: collapse/expand con tween.
- Click su una riga: apre il pannello con report/amicizia; il pannello è largo 150 px e si espande a sinistra.
- Le colonne leaderstats compaiono a destra del nome, con titoli; il pannello si allarga quanto basta.
- La lista è sopra il mondo ma sotto i menu modali.

### 3.3 Player count

Non esiste un contatore "N giocatori" nell'HUD 2014. Il numero è implicito nelle righe. Il dato "Playing: N" è nella pagina web dell'esperienza (ticket 01): da confermare con lo snapshot della pagina gioco. **I**

> **R:** aggiungere una player list Godot in alto a destra, 150 px, header 56 px, righe 20 px, senza avatar. Se non si vuole implementare la lista, meglio **non** mostrare un contatore moderno "Giocatori: N": spostarlo nella barra HTML di `play.html`. **R**

---

## 4. Backpack e hotbar

Fonte primaria: `BackpackScripts/BackpackBuilder.lua`, `BackpackManager.lua`, `BackpackResizer.lua` @ 30/06/2014. **V** salvo dove indicato.

### 4.1 Hotbar (current loadout)

| Proprietà | Valore |
|---|---|
| Contenitore | **600×54 px**, `Position = (0.5, -300, 1, -85)`: top a 85 px dal fondo, quindi bottom a 31 px dal fondo |
| Slot | **54×54 px**, passo **60 px** (54 + 6 di gap), **9 slot** visibili (1–9) |
| Numero slot | `ArialBold`, **Size18**, bianco, in alto a sinistra, box 10×15, con due ombre nere (down/up) |
| Nome oggetto | `Arial`, **Size14**, bianco, centrato in basso, con stroke nero |
| Bordo slot | 1 px chiaro, fill blu scuro traslucido (`97613075` come texture) |
| Highlight | texture `97643886` |
| Tooltip | `ArialBold`, Size14, bianco su nero al 50%, 20 px di altezza |
| Backpack button | **120×18 px**, `Position = (0.5, -60, 1, -108)`; texture `97617958` (doppio chevron) |

### 4.2 Inventario aperto

| Proprietà | Valore |
|---|---|
| Pannello | **600×400 px**, centrato, apre dal centro verso `0.5`/`0.2` e si ancora a `1, -88` |
| Sfondo | **`#202020`** (`Color3.new(32/255,32/255,32/255)`), bordo 0 |
| Tab bar | fascia nera sopra il pannello, alta 10% + 4 px; linea `#353535` |
| Tab `Gear` | 60×30 px, bianco, testo nero, `ArialBold` Size18 |
| Tab `Wardrobe` | 90×30 px, nero, bordo bianco, testo bianco, `ArialBold` Size18 |
| Close | 30×30 px in alto a destra, texture X `75547445` |
| Search | 220×24 px in alto a destra, placeholder `Search...`, `ArialBold` Size12 |
| Griglia | slot **54×54 px**, scrollbar 17 px |
| Loadout laterale | 30% della larghezza, lista dei loadout |

> **R:** RobloxWeb non ha inventario/tool e **non mostra l'hotbar**. Il riferimento 9 slot da 54×54, gap 6 px e numeri 1–9 in `ArialBold` 18 resta solo storico, da usare se un ticket separato introdurrà tool. **R**

---

## 5. Health bar e indicatori di stato

Fonte primaria: `CoreScripts/HealthScript.lua` @ 30/06/2014. **V** salvo dove indicato.

| Proprietà | Valore |
|---|---|
| Frame | **170×18 px**, `Position = (0.5, -85, 1, -22)`: centrata, bottom a 22 px dal fondo |
| Sfondo/bordo | nero `#000000`, bordo nero |
| Barra | immagine verde `35238053`; rossa `35238036` sotto il **25%**; oro `154646431` se il rapporto è NaN/god mode |
| Riempimento | `width = health / MaxHealth`, tween 0–0.3 s |
| Etichetta | `Health  ` (due spazi), **SourceSansBold Size14**, bianco, stroke nero, allineata a destra |
| Hurt overlay | immagine `34854607`, rosso ai bordi; scatta se il danno ≥ **5%** di MaxHealth; espande a tutto schermo e svanisce in **10 s** |
| Morte | `Humanoid.Died` → `UpdateGui(0)`; nessuna UI di morte core; respawn del personaggio dopo il tempo del server |

Dagli screenshot di giugno 2014: la barra è un gradiente verticale verde, più chiaro in alto (`#25B230`) e più scuro in basso (`#004F00`), con bordo nero 1 px e label bianca a destra. **V** (screenshot) / **I** (gradiente esatto).

> **R:** in Godot sostituire la `ProgressBar` con un `TextureProgressBar`/`Control` 170×18, gradiente verticale verde, bordo nero, label `Salute` a destra in Source Sans 3 Bold 14 con outline nero. L'overlay rosso va tenuto separato e attivato solo per danni ≥5%.

---

## 6. Notifiche e toast

### 6.1 Cosa è verificato

`NotificationScript.lua` usa l'API engine:

```lua
game:GetService("GuiService"):SendNotification(
    "Friend Request",
    "From " .. fromPlayer.Name,
    "http://www.roblox.com/thumbs/avatar.ashx?userId=...&x=48&y=48",
    8,
    callback
)
```

Durate osservate: **5 s** (amicizia accettata, punti) e **8 s** (richiesta di amicizia). Icona 48×48. **V** (codice)

Il `NotificationScript` contiene anche un **dialog centrale** per le richieste di amicizia: pannello **330×350 px**, avatar 352×352, testo `Accept Friend Request from <name>?`, pulsanti `Accept` / `Decline`, tween 1 s. **V** (codice)

### 6.2 Cosa è inferito

L'aspetto del toast engine-rendered non è nei CoreScripts (è C++). Dagli screenshot 2014 non ne ho trovato uno pulito. La famiglia visiva 2014 (player list, hotbar, menu) suggerisce:

- posizione **alto a destra**, sotto la player list (o alto al centro se la lista è aperta);
- pannello **~300×64 px**, blu notte traslucido `rgba(16,28,60,0.9)`, bordo 1 px `#6E7FA6`, raggio 4 px;
- icona 48×48 a sinistra, titolo 14 px bold bianco, corpo 12 px `#E6E6E6`;
- entrata slide/fade da destra, uscita fade; 5 s di default.

**I** — da validare con uno screenshot d'epoca se l'utente ne trova uno.

> **R:** per checkpoint/goal usare la chat di sistema in oro `#FFD700`, non un toast moderno. Un toast 2014-style va bene per eventi sociali (amicizia, badge), non per il gameplay.

---

## 7. Menu Esc e dialogo "Leave Game?"

Fonte primaria: `CoreScripts/Settings.lua` @ 30/06/2014. **V** salvo dove indicato.

### 7.1 Game Menu (metà 2014)

| Proprietà | Valore |
|---|---|
| Shield | full screen, `#333333` a **0.4** di opacità, bordo `#1B2A35` |
| Pannello | **525×430 px**, centrato |
| Titolo | `Game Menu`, `ArialBold` **Size36**, bianco, stroke nero, y=4, h=36 |
| Pulsanti principali | **340×50 px**, x=82 |
| Resume Game | y=54, stile **default** (bordo rosso) |
| Reset Character | y=105 |
| Game Settings | y=156 |
| Game Instructions | y=207 (solo se esiste `LoadingGuiService`) |
| Help | **164×50**, (82, 256) |
| Screenshot | **168×50**, (254, 256) |
| Report Abuse | **164×50**, (82, 306) |
| Record Video | **168×50**, (254, 306) |
| Leave Game | **340×50**, (82, 358) |
| Font pulsanti | `Arial` Size18 (Help/Screenshot/Report/Record), `Arial` **Size24** (Resume/Reset/Settings/Leave) |
| Shortcut | `F1`, `PrintSc`, `F12` in verde, Size12 |
| Stile | fill nero, bordo 1 px grigio `#808080`; default con bordo rosso `#C1272D`; testo bianco centrato |

Lo screenshot `Menu.PNG` (527×432, usato fino al 27/08/2014) conferma il look nero/rosso; in quella cattura `Report Abuse` non è visibile, ma il codice del 30/06/2014 lo crea. La differenza è probabilmente una versione precedente del menu. **V/I**

### 7.2 Leave confirmation

| Proprietà | Valore |
|---|---|
| Pannello | **525×300 px**, centrato |
| Testo | `Leave this game?`, `ArialBold` **Size36**, bianco, centrato, h=80% |
| `Stay` | **128×50**, (90, 0.8·H), stile **default** (bordo rosso) |
| `Leave` | **128×50**, (313, 0.8·H), stile normale, `SetVerb("Exit")` |
| Font pulsanti | `Arial` Size24 |
| Semantica | il default sicuro è **Stay**, non Leave |

### 7.3 Reset confirmation

| Proprietà | Valore |
|---|---|
| Pannello | **525×370 px** |
| Testo | `Are you sure you want to reset your character?` (`ArialBold` 36) |
| Sottotesto | `You will be put back on a spawn point` (`Arial` 18, 303×18, x=109, y=215) |
| `Reset` | 128×50, (313, 299), stile default |
| `Cancel` | 128×50, (90, 299), stile normale |

### 7.4 Confine temporale

- **Fino al 27/08/2014:** menu nero con bordo rosso (screenshot `Menu.PNG`; codice 30/06/2014). **V**
- **Dal 27/08/2014 al 09/09/2015:** menu grigio/blu, pulsante default blu, `Report Abuse` visibile (screenshot `Late 2014 to Mid 2015.png`). **V**

> **R:** per metà 2014 usare il menu nero/rosso, non quello grigio/blu. Il flusso è a due passi: Esc → Game Menu → Leave Game → "Lasciare l'esperienza?" con `Resta` evidenziato. **R**

---

## 8. Loading, morte/respawn, checkpoint, goal

### 8.1 Loading screen

Screenshot del web player dell'epoca (`Classic Connecting Loading Screen.png`; data non certa, UI compatibile con il 2014):

- area di gioco **nera `#000000`**;
- spinner circolare bianco a segmenti, centrato;
- testo `LOADING` in maiuscolo, grigio chiaro/bianco, ~12 px, letter-spacing ~2 px, a destra dello spinner;
- **nessun logo** e nessun testo di titolo dentro il client;
- la barra di progresso (`Loading 23% - Writing Fusion Ports...`, fill **giallo-verde `#D2D400`**, track **`#8C8C8C`**, bordo oliva) è nella pagina web attorno alla finestra di gioco, non nel client. **V** (screenshot) / **I** (attribuzione client vs sito).

> **R:** schermo di caricamento Godot nero, spinner bianco, `CARICAMENTO` 12 px spaziato; la barra di progresso può stare nell'HTML di `play.html` con fill `#D2D400` su track `#8C8C8C`.

### 8.2 Morte e respawn

- Il core 2014 **non ha una schermata di morte**: `HealthScript` porta la barra a 0, il personaggio ragdolla, la camera resta; il respawn è del `Players`/server (default ~5 s). **V** (codice) / **I** (tempo esatto).
- L'unico effetto core è l'**hurt overlay** rosso (`34854607`), non una schermata di morte. **V**

> **R:** se serve feedback, overlay minimo: nero al 60%, `Sei morto` 36 px bianco, `Respawn tra N…` 18 px, 5 s. È un'aggiunta di prodotto, non un elemento 2014 documentato. **R**

### 8.3 Checkpoint e goal

Non sono UI core 2014: sono entità di livello. Nel 2014 i giochi le implementavano con messaggi in chat, `Message` GUI o cartelli 3D. **V** (assenza nel core) / **I** (convenzioni).

> **R:** checkpoint → riga di sistema in chat, oro `#FFD700`, `Checkpoint raggiunto`; goal → banner centrato nero con bordo rosso/grigio, `Esperienza completata!`, 36 px bianco, più eventuale riga chat. Nessun riferimento 1:1, solo linguaggio visivo 2014. **R**

---

## 9. Font, dimensioni, spaziature, z-order

### 9.1 Font

| Uso 2014 | Font | Evidenza |
|---|---|---|
| Game Menu, player list, backpack, tooltip | **Arial / ArialBold** | `Settings.lua`, `PlayerListScript.lua`, `BackpackBuilder.lua` |
| Health label | **SourceSansBold** Size14 | `HealthScript.lua` |
| Chat | default del client (Source Sans Pro) | `ChatScript.lua` non imposta `Font` |
| Titoli/footer sito | Source Sans Pro / Arial | ticket 01 |

**R:** per RobloxWeb usare **Source Sans 3** come font globale (come da `map.md`), riservando Arial solo se serve un match 1:1 dei label legacy (`Game Menu`, player list). Non introdurre Inter/Roboto.

### 9.2 Type scale osservata

| Elemento | Size |
|---|---|
| Titolo Game Menu / Leave | 36 |
| Pulsanti principali menu | 24 |
| Pulsanti secondari menu | 18 |
| Nome header player list | 24 |
| Nome/score riga player list | 14 |
| Numero slot hotbar | 18 |
| Nome oggetto hotbar | 14 |
| Chat | 12 |
| Health label | 14 |
| Tab inventario | 18 |
| Search inventario | 12 |
| Loading | ~12, caps, letter-spacing 2 |

### 9.3 Spaziature e misure chiave

- Hotbar: **600×54**, 9 slot **54×54**, gap **6**, bottom **31 px** (top a 85 px dal fondo).
- Health: **170×18**, bottom **22 px**, centrata.
- Chat: **500×120** da top 5 px; input full-width **20 px** al fondo.
- Player list: **150 px** di larghezza, header **56 px**, righe **20 px**, bottom **24 px**.
- Menu: **525×430** centrato; pulsanti **340×50**, passo 51 px; laterali **164/168×50**.
- Leave: **525×300**; Reset: **525×370**.
- Inventario: **600×400**; slot **54×54**; scrollbar **17 px**.
- Bordi: **1 px**; raggio pannelli **~4 px**; health bar senza raggio.

### 9.4 Layout a 1680×1000 (riferimento)

```
┌──────────────────────────────────────────────────────────────┐
│ chat messaggi 500×120 (x=0,y=5)        player list 150×…      │
│                                                              │
│                        game world                            │
│                                                              │
│ [Lock Mouse]                                                 │
│ [Menu]                          [▲ backpack 120×18]         │
│                                [hotbar 600×54]               │
│                                [health 170×18]               │
│ chat input 20 px, full width, nero 75%                       │
└──────────────────────────────────────────────────────────────┘
```

### 9.5 Z-order

1. **Loading screen** (sopra tutto).
2. **Menu shield + Game Menu / Leave dialog** (modale).
3. **Notifiche/toast** (sopra HUD, sotto modali).
4. **HUD**: player list, chat, hotbar, health, Menu button.
5. **Mondo di gioco**.

Nel 2014 la chat è a `ZIndex 0`, la player list sopra il mondo, il menu a `baseZIndex+2/+4`, il loading sopra tutto. **V** (codice) / **I** (toast).

---

## 10. Palette di riferimento

Valori campionati dagli screenshot 1680×1000 (quindi influenzati dallo sfondo e dalla compressione) salvo quelli marcati "codice".

| Token | Hex | Uso | Affidabilità |
|---|---|---|---|
| `ui.panel` | `#1E3A78` | player list, pannelli blu notte su cielo | I (campionato) |
| `ui.panelDark` | `#172A4F` | fill slot hotbar | I (campionato) |
| `ui.border` | `#6E7FA6` | bordi 1 px di pannelli/slot/Menu | I (campionato) |
| `ui.text` | `#FFFFFF` | testo | V (codice) |
| `ui.textShadow` | `#000000` | stroke/ombra testo | V (codice) |
| `ui.chatBar` | `#071126` | barra input chat su blu (nero 75%) | V (alpha 0.25) / I (hex) |
| `ui.healthGreenTop` | `#25B230` | highlight alto barra salute | I (campionato) |
| `ui.healthGreen` | `#00AB00` | verde barra | I (campionato; l'immagine 35238053 è la sorgente) |
| `ui.healthGreenDark` | `#004F00` | fondo gradiente barra | I (campionato) |
| `ui.healthRed` | `#FF1C00` | barra sotto 25% | I (campionato; l'immagine 35238036 è la sorgente) |
| `ui.gold` | `#FFD700` | messaggi admin/system | V (codice: 1, 215/255, 0) |
| `ui.menuShield` | `#333333` @ 0.4 | shield del Game Menu | V (codice) |
| `ui.menuButtonFill` | `#000000` | fill pulsanti menu | V (stile engine) / I (hex) |
| `ui.menuButtonBorder` | `#808080` | bordo pulsante normale | V (stile engine) / I (hex) |
| `ui.menuButtonDefault` | `#C1272D` | bordo rosso pulsante default | I (campionato) |
| `ui.inventory` | `#202020` | pannello inventario | V (codice) |
| `ui.loadingBar` | `#D2D400` | fill barra caricamento sito | I (campionato) |
| `ui.loadingTrack` | `#8C8C8C` | track barra caricamento | I (campionato) |

> I pannelli 2014 sono **traslucidi**: il colore finale dipende dallo sfondo. Per Godot usare i valori come base e applicare `modulate.a`/`self_modulate` coerenti, non congelare il pixel campionato.

---

## 11. Mappatura sul client RobloxWeb attuale

| Widget attuale | Dove | Trattamento 2014 | Note |
|---|---|---|---|
| `HealthBar` (`ProgressBar`) | `hud.tscn` | 170×18, gradiente verde, bordo nero, label `Salute` a destra | Sostituisce l'attuale barra; bottom 22 px |
| `Coins` (`Label`) | `hud.tscn` | **rimuovere** dal HUD; mostra `Monete` come colonna leaderstats nella player list | Il 2014 non aveva un contatore monete separato |
| `Players` (`Label`) | `hud.tscn` | **rimuovere** dal HUD; il conteggio va nella barra HTML di `play.html` | Il 2014 non mostra "Giocatori: N" in-game |
| `FPS` (`Label`) | `hud.tscn` | nascondere (debug only) | Il 2014 non aveva FPS visibile |
| `ChatLog` (`Label`) | `hud.tscn` | `RichTextLabel` 500×120 in alto a sinistra, 12 px, nomi colorati, testo bianco con outline, nessuno sfondo | Richiede BBCode per i colori |
| `ChatInput` (`LineEdit`) | `hud.tscn` | barra full-width 20 px al fondo, nero 75%, placeholder, 12 px | Apertura con `/` e Invio |
| `Message` (`Label`) | `hud.tscn` | testo centrato bianco con outline (stile `Message` 2014), non un toast moderno | Per checkpoint/goal |
| `Crosshair` (`Control`) | `hud.tscn` | opzionale: punto bianco 4 px con outline nero; il 2014 mostrava il cursore di sistema | I |
| Player list | **nuovo** | 150 px a destra, header 56 px, righe 20 px, icone 16 px, no avatar | Core 2014 |
| Menu button | **nuovo** | 92×48 bottom-left, scudo, casa + `Menu` | Apre il Game Menu |
| Game Menu / Leave | **nuovo** | 525×430 / 525×300, nero/rosso, `Resta` default | Sostituisce il dialogo attuale |
| Hotbar/backpack | **opzionale** | solo se ci sono tool; 9 slot 54×54, 6 px gap | Con zero tool: assente |
| Loading | **nuovo** | nero, spinner, `CARICAMENTO` | La barra progresso nell'HTML |
| Death overlay | **opzionale** | nero 60%, `Sei morto`, countdown | Non core 2014 |

---

## 12. Do / Don't per il re-skin

**Do**

- Lasciare il **centro dello schermo libero**: la UI 2014 è ai bordi (chat a sinistra, player list a destra, hotbar/health in basso).
- Usare **pannelli blu notte traslucidi** con bordo 1 px chiaro per player list e slot.
- Usare **testo bianco con outline nero 1 px** su chat, health, player list.
- Usare **misure fisse in px** a una base 1680×1000; scalare solo sotto 1280×720.
- Riprodurre il **flusso a due passi** Esc → Game Menu → Leave Game → "Lasciare l'esperienza?".
- Tenere il **Menu in basso a sinistra** e il **backpack in basso al centro**.
- Usare **Source Sans 3** per il testo nuovo e Arial solo per i label legacy se serve il match.

**Don't**

- **Non** aggiungere una topbar in-game 2014: non esisteva.
- **Non** mettere il logo Roblox o un player count in alto nel CanvasLayer.
- **Non** usare la topbar 2015-2020 (`#1F1F1F`, 36 px, 3 icone) come riferimento 2014.
- **Non** usare avatar 3D nella player list: solo icone 16×16.
- **Non** copiare i riquadri scuri della chat custom vista negli screenshot: la chat core è senza sfondo.
- **Non** mostrare FPS, monete e player count come chip moderni.
- **Non** usare il menu grigio/blu di fine 2014 per giugno 2014.

---

## 13. Incertezze della fonte (chiuse nella spec)

1. **Menu button e Lock Mouse**: sono engine C++ (non CoreScripts). Misure e colori sono campionati da screenshot 1680×1000; il valore esatto del texture/9-slice non è pubblico. **I**
2. **Toast `SendNotification`**: aspetto engine non documentato; la ricostruzione è basata sulla famiglia visiva 2014. **I**
3. **Morte/respawn**: nessuna UI core; il tempo di respawn dipende dal server. **I**
4. **Hotbar senza tool**: non è chiaro se il client 2014 mostrasse 9 slot vuoti o nascondesse l'hotbar. Raccomandazione: nascondere. **I/R**
5. **Scala GUI**: le misure sono fisse a 1680×1000; non è verificato se il client 2014 applicasse uno scale factor a risoluzioni molto alte. **I**
6. **Screenshot di giugno**: provengono da giochi con chat/leaderstats custom; per la chat core fare fede a `ChatScript.lua` + `September 2013 chat.png`, non ai riquadri scuri. **V/I**
7. **Report Abuse nel menu**: il codice 30/06/2014 lo prevede, lo screenshot `Menu.PNG` non lo mostra. Probabile differenza di versione. **V/I**

---

## 14. Fonti

Accesso: 28 ottobre 2026. Le immagini sono state scaricate solo in `/tmp` per ispezione e misura; non sono state committate.

### Primarie (codice)

- **S1** — Roblox, *Core-Scripts*, commit `8add333c8f77cbe43e9886aa70daa510972c8aaa` (30/06/2014): <https://github.com/Roblox/Core-Scripts/commit/8add333c8f77cbe43e9886aa70daa510972c8aaa>
  - `CoreScripts/ChatScript.lua`
  - `CoreScripts/PlayerListScript.lua`
  - `CoreScripts/HealthScript.lua`
  - `CoreScripts/NotificationScript.lua`
  - `CoreScripts/Settings.lua`
  - `CoreScripts/BackpackScripts/BackpackBuilder.lua`
  - `CoreScripts/BackpackScripts/BackpackManager.lua`
  - `CoreScripts/BackpackScripts/BackpackResizer.lua`
- **S2** — Roblox, *Core-Scripts*, `CoreScriptsRoot/Modules/TopbarConstants.lua` (versione 2018, per il confine 2015): <https://github.com/Roblox/Core-Scripts/blob/master/CoreScriptsRoot/Modules/TopbarConstants.lua>

### Screenshot nativi 2014 (Fandom)

- **S3** — `RobloxScreenShot06182014_091326830.png` (18/06/2014, 1680×988): <https://roblox.fandom.com/wiki/File:RobloxScreenShot06182014_091326830.png>
- **S4** — `RobloxScreenShot06182014_091359565.png` (18/06/2014, 1680×988): <https://roblox.fandom.com/wiki/File:RobloxScreenShot06182014_091359565.png>
- **S5** — `RobloxScreenShot06182014_091432581.png` (18/06/2014, 1680×988): <https://roblox.fandom.com/wiki/File:RobloxScreenShot06182014_091432581.png>
- **S6** — `RobloxScreenShot06152014_194850-757.png` (15/06/2014, 1680×1000): <https://roblox.fandom.com/wiki/File:RobloxScreenShot06152014_194850-757.png>
- **S7** — `RobloxScreenShot06182014_230744-698.png` (18/06/2014, 1680×1000): <https://roblox.fandom.com/wiki/File:RobloxScreenShot06182014_230744-698.png>

### Wiki e gallerie datate

- **S8** — Roblox Wiki, *Timeline of Roblox history/2015* (23/04/2015: nuova topbar): <https://roblox.fandom.com/wiki/Timeline_of_Roblox_history/2015>
- **S9** — Roblox Wiki, *Game Controls* (galleria `Topbar 2015.png`, aprile 2015–maggio 2020): <https://roblox.fandom.com/wiki/Game_Controls>
- **S10** — Roblox Wiki, *In-experience menu* (galleria `Menu.PNG` fino al 27/08/2014; `Late 2014 to Mid 2015.png` dal 27/08/2014): <https://roblox.fandom.com/wiki/In-experience_menu>
- **S11** — Roblox Wiki, *Chat* (galleria `September 2013 chat.png`, settembre 2013–settembre 2014; rimozione Super Safe Chat il 03/04/2014): <https://roblox.fandom.com/wiki/Chat>
- **S12** — Roblox Wiki, *Backpack* (sezione "November 2012 – late 2014" e immagini `2013-2014 Backpack.png`, `Late 2012 till Late 2014.png`): <https://roblox.fandom.com/wiki/Backpack>
- **S13** — Roblox Wiki, *People list* (asset `48488235`, codice usato intorno al 29/08/2014; icone BC/amico/admin): <https://roblox.fandom.com/wiki/People_list>
- **S14** — Roblox Wiki, *Classic Connecting Loading Screen.png* (loading screen del web player; data non certa, UI 2014-compatibile): <https://roblox.fandom.com/wiki/File:Classic_Connecting_Loading_Screen.png>
- **S15** — Roblox Wiki, *Menu.PNG* (menu 2011–27/08/2014): <https://roblox.fandom.com/wiki/File:Menu.PNG>
- **S16** — Roblox Wiki, *Late 2014 to Mid 2015.png* (menu 27/08/2014–09/09/2015): <https://roblox.fandom.com/wiki/File:Late_2014_to_Mid_2015.png>
- **S17** — Roblox Wiki, *September 2013 chat.png* (chat settembre 2013–settembre 2014): <https://roblox.fandom.com/wiki/File:September_2013_chat.png>
- **S18** — Roblox Wiki, *Topbar 2015.png* (topbar aprile 2015–maggio 2020): <https://roblox.fandom.com/wiki/File:Topbar_2015.png>

### Progetto RobloxWeb (per la mappatura)

- **S19** — `Godot/robloxwebengine/scripts/ui/hud.gd` e `Godot/robloxwebengine/scenes/ui/hud.tscn` (widget attuali: health, coins, players, FPS, chat, message, crosshair).
- **S20** — `WEBhtml/play.html` (barra HTML con titolo/autore/leave attorno all'iframe).

---

## 15. Sintesi per il ticket 06

- **Topbar:** non esiste nel client 2014; la barra con titolo/autore/player count resta HTML. Dentro Godot: Menu in basso a sinistra.
- **Chat:** alto a sinistra 500×120, 12 px, bianco con outline, nomi colorati, nessuno sfondo; input full-width 20 px in basso, nero 75%.
- **Player list:** alto a destra 150 px, header 56 px, righe 20 px, icone 16 px, **niente avatar**, nessun contatore.
- **Backpack/hotbar:** 600×54, 9 slot 54×54, gap 6, numeri 1–9; assente se non ci sono tool.
- **Health:** 170×18, bottom 22 px, gradiente verde, label a destra, hurt overlay rosso.
- **Menu/Leave:** 525×430 e 525×300, nero/rosso, `Resta` default, `Lascia` a destra.
- **Loading:** nero + spinner + `LOADING`.
- **Font:** Source Sans 3 per il nuovo; Arial per i label legacy.
