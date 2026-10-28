# Architettura del tema Godot

Type: grilling
Status: resolved
Blocked by: 01, 02, 04

## Question

Decidere come implementare la pelle 2014 in Godot senza sporcare le scene:

- `Theme` condiviso vs override per scena vs script;
- font TTF, dimensioni, scaling e DPI;
- StyleBox per bottoni/panel/input, nove-patch per texture se servono;
- gestione risoluzioni/anchors e comportamento nel web export;
- dove vive il tema (`res://themes/...`) e come si applica a HUD e dialoghi;
- cosa resta testabile headless e cosa richiede verifica visiva.

Esito: decisione architetturale + vincoli per il piano di implementazione.

## Answer

Approvate tutte e sei le proposte il 28 ottobre 2026. Specifica completa in [`godot-theme.md`](../../../docs/roblox-2014/godot-theme.md).

- **Tema runtime:** `Theme` costruito da `rw_tokens.gd` in `res://themes/rw_theme.gd` (`RwTheme.shared()` con cache), variation `Rw*` per label, bottoni, input, pannelli; niente `.tres` e niente `theme_override_*` in HUD/Game Menu.
- **Applicazione:** solo HUD, Game Menu/Leave/Reset, banner e FPS debug. Studio, editor, LevelSelect e MainMenu restano sul tema Godot; la barra HTML resta sito.
- **Font:** TTF Source Sans 3 (Regular/Bold) per chat/salute/banner/debug e Liberation Sans (Regular/Bold) per menu/player list, in `res://assets/fonts/` con OFL, `preload` e AA grayscale/light hinting. Niente MSDF, bitmap font o Google Fonts a runtime; le dimensioni sono i token e scala il CanvasLayer.
- **StyleBox:** `StyleBoxFlat` per bottoni, pannelli, righe, header, banner e input; niente nine-patch o texture UI. Scudo del Menu in `_draw`; health bar con `GradientTexture2D`, hurt overlay radiale generato, mirino 4×4.
- **Scala:** nel client `Window.CONTENT_SCALE_MODE_DISABLED` e HUD in design space (`CanvasLayer.scale = s`, `Root.size = viewport/s`, `s = clamp(min(w/1280,h/720),0.8,1.0)`); Studio/editor restano `CANVAS_ITEMS`. Il Root non usa `PRESET_FULL_RECT`.
- **Test:** `tools/test_theme.gd` headless per varianti/base type, font, dimensioni, colori, stylebox, `scale_for` e scan dei `.tscn` senza `theme_override_`; verifica visiva browser/manuale, niente golden images in questo ticket.

Esito: architettura del tema pronta per il piano (09).

Vincolo dal ticket 04: `rw_tokens.gd` è il mirror delle costanti; il `Theme` si costruisce da lì; `tools/check_design_tokens.py` confronta il sottoinsieme condiviso con il CSS di `site.css`. Il client non ha topbar: la barra è HTML (ticket 05/06); il tema copre HUD, Game Menu e dialoghi in-canvas.
