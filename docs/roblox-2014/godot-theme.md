# Architettura del tema Godot — pelle 2014

> Documento canonico della [specifica consolidata](spec.md).
> Base: `tokens.md`, `hud-client.md`, `media-rules.md`, `project.godot` (Godot 4.7.2, GL Compatibility, Web single-threaded).
> **Approvato il 28 ottobre 2026.** Le decisioni sono chiuse e confluite nella spec.

## 1. Perimetro e principi

Il tema copre **solo le superfici 2014 in-canvas**: HUD, Game Menu, Leave, Reset, banner traguardo, FPS debug. Non copre la barra HTML di `play.html` (sito, ticket 05/06), né Studio, editor, LevelSelect o MainMenu (fuori scope). Il client non ha una topbar in-canvas.

1. **Una sola fonte di valori.** `rw_tokens.gd` è il mirror delle costanti approvate; il tema si costruisce da lì. Niente colori/font scritti a mano nelle scene.
2. **Tema costruito, non disegnato a mano.** Un `Theme` runtime con **type variation** `Rw*`; le scene usano solo `theme_type_variation`, anchors e size.
3. **Squadrato e leggibile.** `StyleBoxFlat`, bordi 1 px, niente ombre, radius 4 solo sul pannello player list. Testo bianco con outline nero dove sta sopra il mondo.
4. **Niente texture di UI.** Niente nine-patch, PNG o sprite: scudo del Menu in `_draw`, gradienti di salute/hurt generati a runtime.
5. **Web-first.** Font TTF e `StyleBoxFlat` funzionano nell'export single-threaded; niente GDExtension, MSDF o thread.
6. **Il tema non sporca le scene.** Zero `theme_override_*` in HUD/Game Menu; gli override restano solo nelle scene fuori scope (Studio/editor).
7. **Il tema non governa il layout.** Misure, anchors, z-order e scala sono di `hud-client.md`; il tema governa font, colori, stylebox e stati.

## 2. Architettura

```
scripts/ui/rw_tokens.gd        valori canonici (colori, font, misure)
        │
        ├── themes/rw_theme.gd          Theme + variation Rw*
        ├── scripts/ui/rw_layout.gd     content scale + design-space scale
        └── assets/fonts/*.ttf          font + OFL

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
| `scenes/ui/hud.tscn` | HUD (chat, player list, salute, Menu, mirino) |
| `scenes/ui/game_menu.tscn` | shield, Game Menu, Leave, Reset |
| `scenes/ui/banner.tscn` | banner traguardo |
| `scenes/ui/debug.tscn` | FPS F3 |
| `scenes/world/hurt_overlay.tscn` | vignetta rossa, nessun tema |

### 2.1 Perché un `Theme` runtime

- I valori devono venire da `rw_tokens.gd`, che è il mirror controllato da `tools/check_design_tokens.py`; un `.tres` statico duplicherebbe i valori e richiederebbe una sincronizzazione manuale.
- Il tema è testabile headless: si costruisce, si ispezionano stylebox/font/colori senza renderer.
- Non serve un autoload: `RwTheme` è una classe statica con cache; il primo `shared()` costruisce il tema, gli altri riusano la stessa istanza.
- Il tema non appare nell'anteprima editor delle scene (le scene usano varianti senza `.tres`). È accettato: l'HUD/Game Menu sono UI runtime; l'editor di Godot non è il target.

### 2.2 Niente override nelle scene

- `hud.tscn` e `game_menu.tscn` non contengono `theme_override_*` di colori/font: solo anchors, offset, size, `theme_type_variation`, testo e proprietà di gioco.
- Le scene Studio/editor/LevelSelect/MainMenu restano com'è: non ricevono `RwTheme`.
- Un test legge i `.tscn` e fallisce se trova `theme_override_` in HUD/Game Menu.

## 3. `RwTheme`: API e costruzione

```gdscript
class_name RwTheme
extends RefCounted

const FONT_UI_REGULAR: FontFile = preload("res://assets/fonts/SourceSans3-Regular.ttf")
const FONT_UI_BOLD: FontFile = preload("res://assets/fonts/SourceSans3-Bold.ttf")
const FONT_LEGACY_REGULAR: FontFile = preload("res://assets/fonts/LiberationSans-Regular.ttf")
const FONT_LEGACY_BOLD: FontFile = preload("res://assets/fonts/LiberationSans-Bold.ttf")

static var _shared: Theme

static func shared() -> Theme:
    if _shared == null:
        _shared = build()
    return _shared

static func build() -> Theme:
    _configure_fonts()
    var theme := Theme.new()
    theme.default_font = FONT_UI_REGULAR
    theme.default_font_size = RwTokens.FONT_SIZE_BODY
    _install_labels(theme)
    _install_buttons(theme)
    _install_chat(theme)
    _install_panels(theme)
    return theme

static func reset_cache() -> void:
    _shared = null
```

- `_configure_fonts()` imposta una sola volta `antialiasing = GRAY`, `hinting = LIGHT`, `subpixel_positioning = AUTO`, `multichannel_signed_distance_field = false`, `allow_system_fallback = true`.
- `build()` è idempotente e non dipende dalla scena; `reset_cache()` serve ai test.
- `shared()` è chiamato dal `_ready()`/`_enter_tree()` dei root Control di HUD/GameMenu/Banner/Debug.
- Il tema non viene mai mutato a runtime (nessun cambio di stylebox per stato di gioco): gli stati sono stylebox separati; la salute cambia texture sul nodo, non sul tema.

### 3.1 Helper interni

```gdscript
static func _flat(
    bg: Color,
    border: Color = Color.TRANSPARENT,
    width: int = 0,
    radius: int = 0
) -> StyleBoxFlat
```

- `bg_color`, `border_color`, `set_border_width_all`, `set_corner_radius_all`, `anti_aliasing = true`, niente shadow.
- Per i bottoni: `content_margin_left/right = 8`, `top/bottom = 4`.
- Per il focus: `StyleBoxFlat` con `bg_color = Color(0,0,0,0)`, bordo 2 px `FOCUS`, `expand_margin_all(1)`.
- Per il pannello player list: radius 4; `clip_contents = true` sul nodo, così header/righe rispettano gli angoli.
- Per le righe: bordo inferiore 1 px `Color(UI_BORDER, 0.4)`; nessun bordo laterale.

## 4. Type variation

Convenzione: prefisso `Rw`, PascalCase, base `Label`/`Button`/`LineEdit`/`RichTextLabel`/`Panel`/`PanelContainer`.

| Variation | Base | Font | Size | Colore / outline | Stylebox / note |
|---|---|---|---|---|---|
| **Base `Label`** | Label | Source Sans 3 Regular | 14 | bianco, outline 0 | fallback |
| **Base `Button`** | Button | Liberation Sans Regular | 24 | bianco | menu nero, bordo `#808080` |
| **Base `LineEdit`** | LineEdit | Source Sans 3 Regular | 12 | bianco | chat, focus cyan |
| **Base `RichTextLabel`** | RichTextLabel | Source Sans 3 Regular | 12 | bianco, outline 3 | chat trasparente |
| `RwLabelHealth` | Label | Source Sans 3 Bold | 14 | bianco, outline 2 | label `Salute` |
| `RwLabelPlayerHead` | Label | Liberation Sans Bold | 24 | bianco, outline 2 | header `Giocatori` |
| `RwLabelPlayerCoinsHead` | Label | Liberation Sans Bold | 11 | bianco, outline 1 | header `Monete` |
| `RwLabelPlayerName` | Label | Liberation Sans Regular | 14 | bianco, outline 2 | righe player list |
| `RwLabelPlayerNameLocal` | Label | Liberation Sans Bold | 14 | bianco, outline 2 | riga locale |
| `RwLabelPlayerCoins` | Label | Liberation Sans Bold | 14 | oro `GOLD`, outline 2 | colonna Monete |
| `RwLabelMenuTitle` | Label | Liberation Sans Bold | 36 | bianco, outline 2 | `Menu di gioco`, Leave, Reset |
| `RwLabelMenuSmall` | Label | Liberation Sans Regular | 18 | bianco, outline 2 | sottotesto Reset |
| `RwLabelComandiTitle` | Label | Liberation Sans Bold | 18 | bianco, outline 2 | titolo `Comandi` |
| `RwLabelComandi` | Label | Liberation Sans Regular | 12 | bianco, outline 2 | righe comandi |
| `RwLabelBanner` | Label | Source Sans 3 Bold | 36 | bianco, outline 2 | `GIOCO COMPLETATO!` |
| `RwLabelDebug` | Label | Source Sans 3 Regular | 11 | bianco, outline 1 | FPS F3 |
| `RwButtonMenu` | Button | Liberation Sans Regular | 24 | bianco | menu nero/`#808080`, focus cyan |
| `RwButtonMenuDefault` | Button | Liberation Sans Regular | 24 | bianco | come sopra, bordo `MENU_DEFAULT` |
| `RwButtonPlayerHeader` | Button | Liberation Sans Bold | 24 | bianco | header `UI_PANEL_DARK`, bordo basso |
| `RwButtonMenuTrigger` | Button | Source Sans 3 Regular | 12 | bianco, outline 2 | stylebox vuoti; scudo in `_draw` |
| `RwLineEditChat` | LineEdit | Source Sans 3 Regular | 12 | bianco | `CHAT_BAR`, focus cyan |
| `RwRichChat` | RichTextLabel | Source Sans 3 Regular | 12 | bianco, outline 3 | trasparente, `line_separation=1` |
| `RwPanelPlayerList` | PanelContainer | — | — | — | `UI_PANEL`, bordo 1, radius 4 |
| `RwPanelPlayerRow` | PanelContainer | — | — | — | trasparente, bordo basso 1 |
| `RwPanelPlayerRowAlt` | PanelContainer | — | — | — | `PLAYERLIST_ROW_ALT`, bordo basso 1 |
| `RwPanelBanner` | PanelContainer | — | — | — | `BANNER_BG`, bordo 1 `MENU_DEFAULT` |
| `RwPanelMenuShield` | Panel | — | — | — | `MENU_SHIELD` |
| `RwPanelCrosshair` | Panel | — | — | — | bianco, bordo 1 nero |
| `RwPanelHealthTrack` | Panel | — | — | — | nero, bordo 1 nero |

- `Theme.set_type_variation("Rw…", "Label")` per ogni riga.
- `Theme.set_font`, `set_font_size`, `set_color("font_color", …)`, `set_color("font_outline_color", …)`, `set_constant("outline_size", …)`.
- Per `Button`: `font_color`, `font_hover_color`, `font_pressed_color`, `font_focus_color`, `font_disabled_color`, `font_outline_color`, `outline_size`, e stylebox `normal/hover/pressed/hover_pressed/focus/disabled`.
- Per `LineEdit`: `font_color`, `font_placeholder_color`, `font_selected_color`, `caret_color`, `selection_color`, `font_uneditable_color`, stylebox `normal/focus/read_only`.
- Per `RichTextLabel`: `normal_font`, `bold_font`, `normal_font_size`, `bold_font_size`, `default_color`, `font_outline_color`, `outline_size`, `line_separation`, stylebox `normal`.

## 5. StyleBox e risorse generate

### 5.1 Bottoni menu

| Stato | Fill | Bordo |
|---|---|---|
| normal | `MENU_BUTTON_BG` `#000000` | 1 px `MENU_BUTTON_BORDER` `#808080` |
| hover | `MENU_BUTTON_HOVER` `#111111` | 1 px `#808080` |
| pressed / hover_pressed | `#000000` | 1 px `#808080` |
| focus | trasparente | 2 px `FOCUS` `#00A1DA`, expand 1 |
| disabled | `#000000` | 1 px `#808080`, testo `TEXT_DISABLED` |

- `RwButtonMenuDefault` usa `MENU_DEFAULT` `#C1272D` al posto di `#808080` in normal/hover/pressed.
- Radius 0, content margin 8/4, testo centrato.
- Nessuna ombra.

### 5.2 Header player list

- `RwButtonPlayerHeader`: fill `UI_PANEL_DARK`, bordo inferiore 1 px `UI_BORDER`, radius 0; hover `UI_PANEL`, pressed `UI_PANEL_DARK`; focus cyan.
- Il Button non ha testo: le due Label (`Giocatori`, `Monete`) sono figlie e usano `RwLabelPlayerHead`/`RwLabelPlayerCoinsHead`.

### 5.3 Chat

- `RwLineEditChat`: normal `CHAT_BAR` 0.75, focus `CHAT_BAR_FOCUS` 0.88 + bordo superiore 2 px `FOCUS`, read_only `CHAT_BAR`; content margin 4; radius 0.
- `RwRichChat`: stylebox `StyleBoxEmpty`, font UI 12, outline nero 3, `line_separation=1`, colore default bianco. I colori dei nomi/system sono BBCode nel testo, non nel tema.
- Placeholder `rgba(255,255,0.9)`, caret bianco, selezione `FOCUS`.

### 5.4 Pannelli

- `RwPanelPlayerList`: `UI_PANEL` 0.86, bordo 1 px `UI_BORDER`, radius 4; il nodo ha `clip_contents=true`.
- `RwPanelPlayerRow`: trasparente, bordo inferiore 1 px `UI_BORDER` al 40%.
- `RwPanelPlayerRowAlt`: `PLAYERLIST_ROW_ALT` `rgba(255,255,255,0.06)`, stesso bordo.
- `RwPanelBanner`: `BANNER_BG` 0.90, bordo 1 px `MENU_DEFAULT`, radius 0.
- `RwPanelMenuShield`: `MENU_SHIELD` 0.40, nessun bordo.
- `RwPanelCrosshair`: bianco, bordo 1 px nero.
- `RwPanelHealthTrack`: nero, bordo 1 px nero.

### 5.5 Scudo del pulsante Menu

- Il pulsante 92×48 è un `Button` con `RwButtonMenuTrigger` (font/colori) ma **senza StyleBox visibile**: il fill e il bordo a scudo sono disegnati in `_draw`.
- Poligono: `(14,0) (92,0) (92,48) (0,48) (0,14)`, fill trasparente, bordo 1 px `UI_BORDER`; hover fill `MENU_TRIGGER_HOVER`; focus bordo 2 px `FOCUS`.
- Casa 24×24 e testo `Menu` 12 px sono disegnati sopra; colori `UI_TEXT`/`UI_TEXT_SHADOW`.
- È l'unica eccezione "custom draw" insieme a health/hurt/crosshair.

### 5.6 Risorse generate

| Elemento | Generazione |
|---|---|
| Health fill | `GradientTexture2D` 1×18, verticale `HEALTH_TOP` → `HEALTH_MID` 45% → `HEALTH_DARK`; sotto 25% sostituita da un gradiente `HEALTH_RED` |
| Health track | `RwPanelHealthTrack` nero dietro il `TextureProgressBar` |
| Hurt overlay | `GradientTexture2D` radiale 256×256, centro trasparente → bordo rosso; `TextureRect` full-rect, alpha animata |
| Crosshair | `Panel` 4×4 con `RwPanelCrosshair` |
| Player list rows | `PanelContainer` con `RwPanelPlayerRow`/`Alt` |

- Le texture generate sono CPU-side e funzionano headless; nessun PNG.
- La salute cambia `texture_progress` sul nodo, non il tema.
- L'hurt overlay vive nel CanvasLayer 5 e non scala con l'HUD.

### 5.7 Niente nine-patch

- Nessun `NinePatchRect`, nessun `StyleBoxTexture`, nessun asset UI esterno.
- I bordi 1 px dei pannelli/righe sono `StyleBoxFlat`; il radius 4 è l'unico arrotondamento.
- Il 2014 è squadrato: niente ombre (`shadow_size=0`), niente gradienti di bottone.

## 6. Font

### 6.1 File

| File | Famiglia | Uso |
|---|---|---|
| `SourceSans3-Regular.ttf` | Source Sans 3 400 | chat, salute, banner, debug, label base |
| `SourceSans3-Bold.ttf` | Source Sans 3 700 | salute, banner, grassetti |
| `LiberationSans-Regular.ttf` | Liberation Sans 400 | Game Menu, player list, Comandi |
| `LiberationSans-Bold.ttf` | Liberation Sans 700 | titoli menu, header player list, monete |

- Licenze OFL nella stessa cartella: `OFL-SourceSans3.txt`, `OFL-LiberationSans.txt`.
- I TTF sono preloadati in `RwTheme`; così l'export Web li include come dipendenze. Non si caricano per path a runtime.
- Niente Google Fonts, niente font di sistema per il testo normale; il fallback di sistema è ammesso solo per glifi mancanti.

### 6.2 Import settings

- `antialiasing = GRAY`
- `hinting = LIGHT`
- `subpixel_positioning = AUTO`
- `multichannel_signed_distance_field = false`
- `allow_system_fallback = true`
- `force_autohinter = false`
- Niente bitmap font, niente MSDF: la scala HUD è 0.8–1.0 e il canvas transform gestisce il ridimensionamento; i font restano leggeri nell'export Web single-threaded.

### 6.3 Dimensioni

Le dimensioni sono i token (px di design): 11, 12, 14, 18, 24, 36. Non si creano varianti DPI o temi scalati: la scala la applica `RwLayout` al CanvasLayer, quindi anche i glifi scalano insieme.

## 7. Applicazione alle scene

### 7.1 HUD

- `hud.tscn`: root `CanvasLayer` (layer 10) → `Root` Control (design space, `mouse_filter = IGNORE`, `theme = RwTheme.shared()` in `_ready`).
- Figli: chat, player list, salute, input, Menu, mirino.
- `hud.gd` assegna il tema al Root e chiama `RwLayout.apply(self, root)`; connette `get_viewport().size_changed`.
- Mouse filter: Root e chat log `IGNORE`; pannelli non interattivi `IGNORE`; input chat, header player list e Menu trigger `STOP`. Il Game Menu root è `STOP`.
- Nessun `theme_override_*`; le Label usano le variation, i pannelli le variation, il Button Menu il custom draw.

### 7.2 Game Menu

- `game_menu.tscn`: root `CanvasLayer` (layer 30) → `Root` Control (design space, `mouse_filter = STOP`, tema in `_ready`).
- Shield `RwPanelMenuShield` full-rect; titolo `RwLabelMenuTitle`; pulsanti `RwButtonMenu`/`RwButtonMenuDefault`; Comandi `RwLabelComandiTitle`/`RwLabelComandi`; Leave/Reset con gli stessi stili.
- `game_menu.gd` chiama `RwTheme.shared()` e `RwLayout.apply`.

### 7.3 Banner e debug

- `banner.tscn`: CanvasLayer 20 → Root (design space, `mouse_filter = IGNORE`); `RwPanelBanner` + `RwLabelBanner`; tema e layout.
- `debug.tscn`: CanvasLayer 15 → Root (design space, `mouse_filter = IGNORE`); `RwLabelDebug`; tema e layout.
- Il banner non è un toast e non ha pila; il debug è invisibile di default.

### 7.4 Cosa resta intatto

- `main.tscn` non riceve un tema globale: `HUD`, `GameMenu`, `Banner`, `Debug` hanno i loro root tematizzati.
- `LevelSelect`, `Menu` iniziale, Studio start, editor: nessun `RwTheme`, nessun cambio di stile. Restano con il tema di default di Godot. LevelSelect/MainMenu vivono nel main del client e quindi ereditano il content scaling disabilitato: non sono un target e non vengono ridisegnati.
- `BootOverlay` dinamico di `main.gd`: il boot web è rimosso (ticket 06); il fallback standalone `/dev` può restare non tematizzato, fuori scope.
- La barra HTML e il sito restano CSS.

### 7.5 Nodi dinamici

- Le righe della player list create a runtime usano `RwPanelPlayerRow`/`Alt`, `RwLabelPlayerName`/`Local`, `RwLabelPlayerCoins`.
- Le righe di chat/system usano il `RwRichChat` già presente; i colori sono BBCode.
- Il banner usa `RwLabelBanner`; il debug `RwLabelDebug`.
- Il Menu trigger è il custom draw; non si duplica il tema.

## 8. Scala, content scaling e web

### 8.1 Problema

`project.godot` ha `window/stretch/mode="canvas_items"` senza base size. Con quella modalità la UI 2D viene scalata dal transform di Godot in modo imprevedibile rispetto alle misure 2014 e alla formula del ticket 06.

### 8.2 Scelta

- Il **client** (web, build dev, Studio Test) imposta a runtime `Window.CONTENT_SCALE_MODE_DISABLED`: i 2D sono pixel CSS/iframe.
- **Studio/editor/start screen** restano su `CONTENT_SCALE_MODE_CANVAS_ITEMS` (default di progetto): la loro UI non viene toccata.

```gdscript
static func use_client(window: Window) -> void:
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

static func use_editor(window: Window) -> void:
    window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
```
- Lo switch avviene in `_enter_tree()` di `main.gd` (prima dei `_ready` dei figli) e in `_enter_tree()`/`_ready()` di StudioStart/editor quando si entra.
- `main.gd`: se `_studio_mode()` e non c'è `play_request` → `RwLayout.use_editor(get_window())`; altrimenti `RwLayout.use_client(get_window())`.
- StudioStart/editor: `RwLayout.use_editor(get_window())` per ripristinare dopo un Test.

### 8.3 Design space

```gdscript
static func scale_for(viewport: Vector2) -> float:
    return clampf(minf(viewport.x / 1280.0, viewport.y / 720.0), 0.8, 1.0)

static func apply(layer: CanvasLayer, root: Control) -> float:
    var viewport := layer.get_viewport().get_visible_rect().size
    var s := scale_for(viewport)
    layer.scale = Vector2(s, s)
    root.position = Vector2.ZERO
    root.size = viewport / s
    return s
```

- Il Root **non** usa `PRESET_FULL_RECT`: ha anchors top-left, `position = (0,0)` e `size = viewport / s`; il `CanvasLayer.scale = s` lo riporta esattamente alle dimensioni fisiche.
- Il CanvasLayer scala tutto (testo compreso); il Root viene dimensionato in **design space** `viewport / s`, così gli anchor restano ai bordi fisici:
  - chat a sinistra, player list a destra, input a piena larghezza, salute/menu in basso;
  - Game Menu e dialoghi centrati nel design space;
  - banner al 40% del design space.
- Il tema usa le dimensioni di design; non si ricostruisce a ogni resize.
- `RwLayout.apply` va chiamato in `_ready` e su `get_viewport().size_changed` per HUD, GameMenu, Banner, Debug.
- L'hurt overlay non usa `RwLayout`: è full-rect nel suo CanvasLayer 5.

| Viewport iframe | Scala | Design space | Chat visiva | Menu visivo |
|---|---|---|---|---|
| 1680×964 | 1.00 | 1680×964 | 500×120 | 525×430 |
| 1366×732 | 1.00 | 1366×732 | 500×120 | 525×430 |
| 1280×684 | 0.95 | 1347×720 | 475×114 | 499×409 |
| 1024×732 | 0.80 | 1280×915 | 400×96 | 420×344 |
| 800×564 | 0.80 | 1000×705 | 400×96 | 420×344 |
| 640×364 | 0.80 | 800×455 | 400×96 | 420×344 |

- La barra HTML 36 px è fuori dal viewport Godot; l'iframe è `100vh - 36px`.
- Il mondo 3D usa i pixel fisici; solo l'HUD/Menu usano la scala.
- Sotto 640×400 non c'è garanzia (ticket 06).

### 8.4 Web

- Il content scaling disabilitato è impostato a runtime, non nel `project.godot`; il progetto resta utilizzabile in editor/Studio.
- `CanvasLayer.scale` e il design space funzionano nell'export Web single-threaded.
- Nessun header COOP/COEP; nessuna GDExtension.

## 9. Export Web

- I font sono `preload` in `RwTheme`, quindi finiscono nel PCK come dipendenze; non serve aggiungerli a `include_filter`.
- `themes/rw_theme.gd`, `scripts/ui/rw_layout.gd`, `scripts/ui/rw_tokens.gd` sono inclusi perché referenziati da HUD/GameMenu.
- Nessun `.tres` da esportare; il tema è codice.
- Le texture di salute/hurt sono generate a runtime.
- Dopo aver aggiunto i font e i nuovi `class_name`, eseguire `--headless --import` (cache classi/import).
- Verifica: aprire `/dev/index.html` dentro `play.html`, controllare font, scala e assenza di errori in console.

## 10. Test e verifica

### 10.1 Headless (strutturale)

`tools/test_theme.gd`:

- `RwTheme.build()` non produce errori e `shared()` restituisce la stessa istanza.
- `theme.default_font` è il FontFile UI; `default_font_size == RwTokens.FONT_SIZE_BODY`.
- Ogni variation ha il base type atteso (`Theme.get_type_variation_base`).
- Font, dimensioni e colori attesi per `RwLabelHealth`/`RwLabelMenuTitle`/`RwLabelBanner`/`RwLabelDebug`/`RwLabelPlayerCoins`.
- `RwButtonMenu.normal` è `StyleBoxFlat` con `MENU_BUTTON_BG` e bordo `MENU_BUTTON_BORDER`; `RwButtonMenuDefault` ha bordo `MENU_DEFAULT`.
- `RwLineEditChat.focus` ha bordo superiore 2 px `FOCUS`; `RwRichChat` ha font/outline attesi.
- `RwPanelPlayerList` ha `UI_PANEL`, bordo `UI_BORDER`, radius 4; `RwPanelBanner` ha `BANNER_BG`/`MENU_DEFAULT`.
- `RwLayout.scale_for` restituisce 1.0 / 0.95 / 0.80 / 0.80 per i viewport della tabella; `apply` imposta layer scale e root size attesi.
- Scan di `scenes/ui/hud.tscn` e `scenes/ui/game_menu.tscn`: nessun `theme_override_`.
- `tools/check_design_tokens.py` continua a passare per il sottoinsieme condiviso.

### 10.2 Visivo (renderer reale)

- HUD a 1680×964, 1280×684, 1024×732, 800×564, 640×364: chat, player list, salute, Menu, banner.
- Game Menu, Leave, Reset: titolo, pulsanti, default, focus, Comandi.
- Testo bianco su mondo chiaro/scuro; outline leggibile; 1 px non sbavato; radius 4 player list.
- Hover/focus: bordo rosso default, focus cyan, hover `#111`.
- Health 100/24/0; hurt overlay; crosshair.
- Font: Source Sans 3 e Liberation Sans caricati, nessun fallback inatteso.
- Browser tool su `play.html`: barra HTML, iframe, scala, console.

Headless non valida i pixel (dummy renderer): la verifica visiva è manuale/browser. Niente golden images; l'harness è definito in [`implementation-plan.md`](implementation-plan.md) §8.

### 10.3 Test esistenti

- `tools/test_gameplay.gd`, `test_lua.gd`, `test_publish.gd`, `test_studio.gd`: invariati, salvo eventuali path dei nodi HUD (`Root/...`) e `hud.chat_has_line`.
- `tools/test_network.gd`: aggiornare l'assert chat come da ticket 06.
- `server/tests`: invariati.

## 11. Handoff implementativo

Ordine consigliato:

1. aggiungere `assets/fonts/*.ttf` + OFL e importarli;
2. creare `scripts/ui/rw_tokens.gd` (ticket 04) con le nuove costanti (`FONT_SIZE_BODY`, `FONT_SIZE_TINY`, `OUTLINE_*`, `TEXT_DISABLED`, `FOCUS`, ecc.);
3. creare `themes/rw_theme.gd` con variation/stylebox;
4. creare `scripts/ui/rw_layout.gd` con content scale e design space;
5. rifare `hud.tscn`/`hud.gd` con Root Control, tema e variation, senza override;
6. creare `game_menu.tscn`/`game_menu.gd` (ticket 06) con tema;
7. creare banner/debug/hurt (ticket 06) e assegnare tema/layout;
8. collegare `main.gd` (`use_client`/`use_editor`, `rw-ready`/`rw-error`, player list);
9. test headless + verifica visiva;
10. export Web e smoke test.

File toccati: `themes/rw_theme.gd`, `scripts/ui/rw_layout.gd`, `scripts/ui/rw_tokens.gd`, `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`, `scenes/ui/game_menu.tscn`, `scripts/ui/game_menu.gd`, `scenes/ui/banner.tscn`, `scenes/ui/debug.tscn`, `scenes/world/hurt_overlay.tscn`, `scripts/main.gd`, `scripts/studio/studio_start.gd`, `scripts/editor/editor.gd` (solo `RwLayout.use_editor`), `tools/test_theme.gd`, `tools/check_design_tokens.py`. Nessuna modifica a server/API/DB.

## 12. Deviazioni e limiti

1. **Tema runtime, non `.tres`**: l'anteprima editor delle scene non mostra la pelle 2014; è una UI runtime.
2. **Studio/editor non tematizzati**: restano con il tema Godot; fuori scope.
3. **Content scaling disabilitato solo nel client**: Studio/editor restano `canvas_items`; una riga di switch in più.
4. **Niente MSDF/bitmap font**: TTF con AA standard; la scala 0.8–1.0 è gestita dal canvas.
5. **Niente nine-patch/texture UI**: StyleBoxFlat; scudo in `_draw`, gradienti generati.
6. **Scala a design space**: il CanvasLayer scala e il Root è `viewport/s`; non si scala ogni widget a mano.
7. **Niente tema globale**: HUD/GameMenu/Banner/Debug soltanto.
8. **Nessun golden image**: verifica visiva manuale/browser con la gallery e la matrice definite in [`implementation-plan.md`](implementation-plan.md) §8.
9. **Font OFL**: Source Sans 3 e Liberation Sans, nessun font Roblox.

## 13. Decisioni approvate

1. `Theme` runtime da `rw_tokens.gd`, `RwTheme.shared()` con cache, variation `Rw*`, niente `.tres`, niente override nelle scene.
2. Tema applicato a HUD/Game Menu/Leave/Reset/banner/debug; Studio/editor/LevelSelect/MainMenu intatti.
3. TTF Source Sans 3 + Liberation Sans in `assets/fonts/`, preload, OFL, AA standard, niente MSDF.
4. `StyleBoxFlat` per tutto; scudo del Menu in `_draw`, health/hurt/crosshair generati; niente nine-patch o texture UI.
5. Client con `CONTENT_SCALE_MODE_DISABLED`, design space `viewport/s` e scala `clamp(min(w/1280,h/720),0.8,1.0)`; Studio/editor `CANVAS_ITEMS`.
6. Test headless strutturali + scan scene senza `theme_override_`; verifica visiva browser/manuale, niente golden images.

Esito: architettura del tema consolidata nella [specifica](spec.md) e pronta per l'implementazione.
