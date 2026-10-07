# AGENTS.md

## Layout

- The actual Godot project lives in `Godot/robloxwebengine/`, not the repo root. All `project.godot` / `res://` paths resolve from there.
- `WEBhtml/` hosts the web side: `WEBhtml/dev/` is the current Web export output of the Godot build; `WEBhtml/index.html` is a minimal site that embeds it in an iframe.
- `server/` hosts the multiplayer relay (pure-Python WebSocket server + CLI test peer). See "Multiplayer" below.
- No Git repo is initialized at the top level (`Godot/robloxwebengine/` has `.gitignore`/`.gitattributes` files but no `.git` anywhere).

## Running Godot

- Godot is installed only as a Flatpak (4.7.2, `org.godotengine.Godot`); there is no `godot` binary on PATH. Run CLI commands as:
  `flatpak run org.godotengine.Godot --path Godot/robloxwebengine` (add flags like `-e`, `--headless` after the binary name).
- After adding/removing scripts with `class_name`, run `--import` once before using `--script` tools, otherwise the global class cache is stale and tools fail with "Identifier ... not declared".

## Web export

- Export templates: only the Web ones are needed and are installed manually at `~/.var/app/org.godotengine.Godot/data/godot/export_templates/4.7.2.stable/` (Flatpak data dir). The full `Godot_v4.7.2-stable_export_templates.tpz` lives in `/tmp/opencode/`.
- Export preset `Web` in `export_presets.cfg`: **single-threaded** (`variant/thread_support=false` → uses `web_nothreads_*` templates), no GDExtensions, exports to `WEBhtml/dev/index.html`. This needs no COOP/COEP headers. `include_filter="levels/*"` ships the default level JSON inside the `.pck`.
- Export command (from repo root):
  `flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine --export-release "Web" /home/tommaso/Documenti/RobloxWEBCpu/WEBhtml/dev/index.html`
- Local test serve: `python3 /tmp/opencode/serve_web.py 8080 /home/tommaso/Documenti/RobloxWEBCpu/WEBhtml` then open `http://127.0.0.1:8080/dev/index.html`. The script exists only to force the `.wasm` MIME type.

## Project structure (Phase 1-2 MVP + levels)

- `scenes/main.tscn` — bootstrap: `scripts/main.gd`. Flow: schermata `LevelSelect` → il mondo viene costruito dai dati del livello con `LevelBuilder` → `Menu` (nome + Play) → spawn/respawn, monete, checkpoint, traguardo. Children: `World` (vuoto finché non si scegle il livello), `LevelSelect`, `Menu`, `HUD`, `GlobalSound`, `NetClient`.
- **Livelli**: un livello è un unico file JSON (`.rwl.json`) con mondo + metadati (+ script in futuro):
  - `scripts/world/level_data.gd` (`LevelData`) — formato v1, `new_level()`, `make_entity()`, validazione (`validate()`), helper colori/vettori/`slug`.
  - `scripts/world/level_builder.gd` (`LevelBuilder`) — dati → scena (PartFactory + script speciali + Environment/Sun fissi).
  - `scripts/world/level_io.gd` (`LevelIO`) — JSON, salva/carica file, `serialize_world()` (scena → dati) e `res://levels/default.rwl.json` (`DEFAULT_LEVEL_PATH`).
  - **Tipi entità** (`kind`): `part`, `spawn`, `checkpoint`, `coin`, `goal`, `kill`, `moving_platform`, `spinner`, `label`. Campi comuni: `id`, `name`, `position`, `rotation` (gradi), `size`, `color` (`#RRGGBB`), `anchored`, `collide`, `transparency`, `props`.
  - L'obby originale è solo contenuto: `levels/default.rwl.json`, rigenerabile con `tools/export_default_level.gd`.
- `scripts/io/level_file_io.gd` (`LevelFileIO`) — apertura/salvataggio file verso l'utente. Su web: `<input type=file>` via `JavaScriptBridge` (niente dialog nativi) e `download_buffer`; su nativo: `FileDialog`.
- `scenes/ui/level_select.tscn` — prima schermata: livello predefinito, carica da file, apri editor.
- `scenes/editor/editor.tscn` — editor v1 (`scripts/editor/editor.gd`, `editor_camera.gd`): camera libera (WASD/E/Q, tasto destro ruota, rotella velocità), palette, piazzamento a click, selezione raycast (meta `level_id`), pannello proprietà, snap a griglia, duplica/elimina, undo/redo (Ctrl+Z/Y), Simula, Testa (play), salva/apri file, autosave in `user://editor_autosave.rwl.json`.
- `scenes/world/baseplate.tscn` — obby originale (fallback/contenuto, non più usato direttamente da `main.tscn`); parti built by `scripts/world/part_factory.gd` (`PartFactory.make_part(size, color, anchored)`; anchored → `StaticBody3D`, not → `RigidBody3D`). Le parti "decorative" con `collide=false` hanno la `CollisionShape3D` disabilitata.
  - Special world scripts: `checkpoint.gd` (Area3D in group `checkpoints`, emits `activated`, pad turns blue→green), `collectible.gd` (coin, group `collectibles`), `kill_brick.gd` (insta-kill area, group `kill`), `goal.gd` (group `goal`, emits `reached`), `moving_platform.gd` (AnimatableBody3D oscillating, exports `offset`/`duration`), `spinner.gd` (rotating bar). `spawn` entities finiscono nel gruppo `spawn`.
- `scenes/player/character.tscn` — R6-style blocky avatar (`CharacterBody3D`, capsule collider, cube limbs animated while walking, jump/land 3D sounds) + `CameraRig` (`top_level`, `SpringArm3D` + `Camera3D`; orbit with right/middle mouse drag, wheel zoom, Shift shift-lock via `toggle_shift_lock`).
- `scenes/ui/menu.tscn` / `scenes/ui/hud.tscn` — menu with Play button (Enter/Space also works), level title label, controls hint; HUD with crosshair (shift-lock), health bar, coin counter, fading messages, FPS.
- `scripts/audio/sfx_factory.gd` — procedural sound effects (jump/land/collect/checkpoint/death/goal) generated as `AudioStreamWAV`, no external assets.
- Input map (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `toggle_shift_lock`) is stored in `project.godot`; events use `device=-1` (DEVICE_ID_EMULATION) so they match any input device (in 4.7 keyboard events come in with device 16, so device 0 events would NOT match).
- `physics/3d/default_gravity=196.2` (Roblox-like stud/s²; world units are "studs": walk speed 16, jump velocity 50).
- One-shot tools in `tools/` (excluded from export via the preset's `exclude_filter`):
  - `setup_project_settings.gd` — writes the input map + gravity into `project.godot` (run with `--script`).
  - `generate_scenes.gd` — regenerates all `.tscn` files above (`--script`, then re-export). Edit scenes in the Godot editor or extend the generator, not by hand.
  - `export_default_level.gd` — serializza `res://scenes/world/baseplate.tscn` in `res://levels/default.rwl.json` (va rieseguito dopo ogni modifica della scena demo).
  - `test_gameplay.gd` — headless smoke test: scelta livello → Play → landing → walk → jump → coin → checkpoint → lava death/respawn → goal.
  - `test_level_io.gd` — validazione, roundtrip scena ↔ dati ↔ JSON ↔ file, casi negativi.
  - `test_editor.gd` — piazzamento/duplica/elimina/undo/redo, serializzazione e autosave dell'editor.

## Multiplayer (Phase 3)

- `server/` is the third folder: a pure-Python WebSocket relay (stdlib only, no dependencies). Run: `python3 server/server.py` (port 9080). Protocol documented at the top of `server/server.py`; helper `server/test_peer.py` simulates a player from the CLI.
- Godot client: `scripts/net/net_client.gd` (`NetClient` node in `main.tscn`) connects on Play, sends `hello`, sends local state 15×/s, and emits signals for remote players and chat. Auto-retries every 3s; if unavailable the game stays single-player.
- Server URL: project setting `net/server_url` (default `ws://127.0.0.1:9080`). On web it can be overridden with a `?server=wss://host:9080` query param (read via JavaScriptBridge).
- Remote avatars: `scenes/player/remote_character.tscn` + `scripts/player/remote_character.gd` — visual-only R6 rig interpolated toward the latest network state, walking animation driven by the received speed.
- Chat: Enter opens the chat input in the HUD, Enter sends, Esc cancels. Typing disables character input. Player count shown in HUD top-right.
- Headless integration test (server must be running): `flatpak run org.godotengine.Godot --headless --path Godot/robloxwebengine --script res://tools/test_network.gd` (checks connection, remote avatar creation/state/removal, chat). It carica prima il livello predefinito e poi preme Play.
- Nota: il livello non viene sincronizzato in rete. Senza cloud, ogni giocatore deve caricare lo stesso file a mano.
- `WEBhtml/index.html` is a minimal site that embeds the dev build in a fullscreen iframe.

## Engine settings (non-defaults)

- Renderer: GL Compatibility (`gl_compatibility`) on all platforms except Windows, which uses D3D12 via `rendering_device/driver.windows`.
- 3D physics engine: Jolt Physics, not Godot's default physics — don't assume default Godot physics behavior.
- Stretch mode: `canvas_items` with `expand` aspect.

## Gotchas

- `project.godot` header warns it's best edited through the Godot editor UI, not by hand.
- `.godot/` is generated editor cache (ignored by the project's `.gitignore`); never rely on or commit its contents.
- Web builds have no native file dialogs: `LevelFileIO` uses `<input type=file>` and `download_buffer` (both need a user gesture; the buttons provide it).
- On web `user://` maps to IndexedDB (editor autosave survives refreshes); in some embedded/incognito contexts persistence may be unavailable.
- `JSON.parse_string` returns all numbers as floats: mantenere i valori numerici float nei dati generati (o normalizzare con `from_json(to_json(...))`) quando si confrontano dati.
