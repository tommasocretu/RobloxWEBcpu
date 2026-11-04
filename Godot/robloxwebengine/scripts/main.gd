extends Node
## Launcher del gioco:
## - web: legge `?place=`, carica il livello dall'API e si connette al relay con un ticket;
## - build desktop Studio (`studio` feature): schermata iniziale di Studio;
## - build nativa dev: LevelSelect → LevelBuilder → Menu/Play;
## - test play / Studio: avvio diretto con `LevelData.play_request`.
## Comune: checkpoint/morte/respawn, monete, traguardo, multiplayer, HUD 2014.

const CHARACTER_SCENE_PATH := "res://scenes/player/character.tscn"
const REMOTE_CHARACTER_SCENE_PATH := "res://scenes/player/remote_character.tscn"
const EDITOR_SCENE_PATH := "res://scenes/editor/editor.tscn"
const STUDIO_SCENE_PATH := "res://scenes/studio/studio_start.tscn"
const SPAWN_OFFSET := Vector3(0, 5, 0)
const STATE_SEND_INTERVAL := 1.0 / 15.0

@onready var world: Node3D = $World
@onready var menu: MainMenu = $Menu
@onready var hud: GameHUD = $HUD
@onready var game_menu: GameMenu = $GameMenu
@onready var level_select: LevelSelect = $LevelSelect
@onready var global_sound: AudioStreamPlayer = $GlobalSound
@onready var net: NetClient = $NetClient
@onready var place_client: PlaceClient = $PlaceClient

var character: PlayerCharacter
var level_data: Dictionary = {}
var respawn_position := Vector3(0, 5, 12)
var coins_total := 0
var coins_collected := 0
var goal_reached := false

var _game_started := false
var _test_mode := false
var _state_timer := 0.0
var _remote_characters: Dictionary = {}  # id -> RemoteCharacter

var _place_mode := false
var _place_info: Dictionary = {}
var _player_info: Dictionary = {}
var _pending_ws_url := ""
var _pending_ticket := ""
var _ready_posted := false
var _menu_restore_shift_lock := false
var _chat_restore_shift_lock := false
var _respawn_shift_lock := false
var _lua_runtime: LuaRuntime


func _enter_tree() -> void:
	if _studio_mode() and LevelData.play_request.is_empty():
		RwLayout.use_editor(get_window())
	else:
		RwLayout.use_client(get_window())


func _ready() -> void:
	print("ROBLOXWEBENGINE_READY")
	menu.play_pressed.connect(_on_play_pressed)
	hud.visible = false
	menu.visible = false
	game_menu.visible = false
	hud.set_menu_enabled(false)
	hud.menu_requested.connect(_open_game_menu)
	game_menu.leave_requested.connect(_on_game_menu_leave)
	game_menu.reset_requested.connect(_on_game_menu_reset)
	game_menu.menu_opened.connect(_on_game_menu_opened)
	game_menu.menu_closed.connect(_on_game_menu_closed)
	hud.chat_submitted.connect(_on_chat_submitted)
	hud.chat_opened.connect(_on_chat_opened)
	hud.chat_closed.connect(_on_chat_closed)
	net.connected.connect(_on_net_connected)
	net.disconnected.connect(_on_net_disconnected)
	net.connection_failed.connect(_on_net_failed)
	net.peer_joined.connect(_on_peer_joined)
	net.peer_left.connect(_on_peer_left)
	net.peer_state.connect(_on_peer_state)
	net.chat_received.connect(_on_chat_received)
	net.server_error.connect(_on_net_server_error)
	level_select.level_chosen.connect(_on_level_chosen)
	level_select.editor_requested.connect(_on_editor_requested)
	place_client.level_loaded.connect(_on_place_loaded)
	place_client.request_failed.connect(_on_place_failed)

	if not LevelData.play_request.is_empty():
		# Avvio diretto in modalità test (pulsante "Testa" dell'editor).
		var request: Dictionary = LevelData.play_request
		LevelData.play_request = {}
		_test_mode = true
		level_select.visible = false
		start_level(request)
		_on_play_pressed()
	elif _studio_mode():
		get_tree().call_deferred("change_scene_to_file", STUDIO_SCENE_PATH)
	elif OS.has_feature("web"):
		# Client web: nessun LevelSelect/Menu/editor; l'HTML possiede il caricamento.
		level_select.visible = false
		menu.visible = false
		hud.visible = false
		place_client.start()
	else:
		level_select.visible = true


func _studio_mode() -> bool:
	## Build desktop Studio (custom feature) o anteprima in sviluppo con `-- --studio`.
	return OS.has_feature("studio") or OS.get_cmdline_user_args().has("--studio")


## Costruisce il mondo a partire dai dati di un livello. Ritorna false se non validi.
func start_level(incoming: Dictionary) -> bool:
	if incoming.is_empty() or not LevelData.validate(incoming).is_empty():
		return false
	level_data = incoming
	var nodes_by_id := LevelBuilder.build_into(world, level_data)
	goal_reached = false
	coins_total = 0
	coins_collected = 0
	respawn_position = Vector3(0, 5, 12)
	_respawn_shift_lock = false
	hud.clear_chat()
	hud.set_local_coins(0, 0)
	_refresh_player_list()
	_start_lua(nodes_by_id)
	return true


func _start_lua(nodes_by_id: Dictionary) -> void:
	if _lua_runtime != null:
		_lua_runtime.stop()
		_lua_runtime.queue_free()
		_lua_runtime = null
	_lua_runtime = LuaRuntime.new()
	_lua_runtime.name = "LuaRuntime"
	_lua_runtime.script_error.connect(_on_script_error)
	add_child(_lua_runtime)
	_lua_runtime.start(level_data, world, nodes_by_id, character, net.player_name)


func _on_script_error(message: String) -> void:
	if _game_started and hud.visible:
		hud.add_system_line("Script: %s" % message)


func _process(delta: float) -> void:
	if not _game_started or character == null or not net.is_open():
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = STATE_SEND_INTERVAL
		var speed := Vector2(character.velocity.x, character.velocity.z).length()
		net.send_state(character.global_position, character.visual.rotation.y, speed)


func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if not (event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE):
		return
	if hud.is_chat_open():
		hud.close_chat()
	elif game_menu.is_open():
		game_menu.handle_escape()
	elif _test_mode:
		_return_to_editor()
	elif _place_mode:
		_open_game_menu()
	else:
		return
	get_viewport().set_input_as_handled()


func _on_level_chosen(incoming: Dictionary, source: String) -> void:
	if not start_level(incoming):
		level_select.status_label.text = "Livello non valido."
		return
	level_select.visible = false
	menu.visible = true
	menu.set_level_title(LevelData.title(incoming))
	if source == "file":
		print("Livello caricato da file: %s" % LevelData.title(incoming))


func _on_editor_requested() -> void:
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


func _on_play_pressed() -> void:
	if _game_started:
		return
	_game_started = true
	menu.visible = false
	hud.visible = true
	if not _place_mode:
		net.player_name = menu.player_name()
	hud.set_menu_enabled(_place_mode)
	_connect_world_nodes()
	_spawn_character()
	_refresh_player_list()
	if _test_mode:
		hud.add_system_line("Modalità test — Esc per tornare all'editor")
	elif _place_mode:
		net.start_with_ticket(_pending_ws_url, _pending_ticket, net.player_name)
		_post_ready_once()
	else:
		# Build nativa di sviluppo: nessun ticket place, si gioca in single player.
		hud.add_system_line("Modalità sviluppo — single player")


func _return_to_editor() -> void:
	net.stop()
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


# --- Bootstrap della place (client web) ---------------------------------------

func _on_place_loaded(
	level: Dictionary, place: Dictionary, player: Dictionary, ws_url: String, ticket: String
) -> void:
	_place_mode = true
	_place_info = place
	_player_info = player
	_pending_ws_url = ws_url
	_pending_ticket = ticket
	_ready_posted = false
	net.player_name = str(player.get("name", "Giocatore"))
	if not start_level(level):
		_on_place_failed("Livello non valido.", "invalid")
		return
	_on_play_pressed()
	var is_guest := bool(player.get("is_guest", true))
	hud.set_chat_enabled(not is_guest)
	hud.add_system_line("Benvenuto, %s!" % net.player_name)
	if is_guest:
		hud.add_system_line("Sei un ospite: accedi per chattare.")


func _on_place_failed(message: String, code: String) -> void:
	hud.visible = false
	hud.set_menu_enabled(false)
	game_menu.close_menu()
	place_client.post_error(message, _failure_detail(code))


func _failure_detail(code: String) -> String:
	match code:
		"no_place":
			return "Apri un gioco dal catalogo."
		"unauthorized":
			return "Apri il gioco dal sito e accedi con un account o come ospite."
		"not_found", "forbidden":
			return "Il gioco non esiste o non è visibile al tuo account."
		"unavailable":
			return "L'autore non ha ancora pubblicato una versione giocabile."
		"network":
			return "Controlla che il server sia attivo: python3 server/run.py"
		"invalid":
			return "Il contenuto del gioco non è valido."
		_:
			return "Riprova più tardi o torna ai giochi."


func _post_ready_once() -> void:
	if not _place_mode or _ready_posted or not OS.has_feature("web"):
		return
	_ready_posted = true
	place_client.post_ready()


func _connect_world_nodes() -> void:
	var spawn := _find_spawn()
	if spawn:
		respawn_position = spawn.global_position + SPAWN_OFFSET

	for node in get_tree().get_nodes_in_group("checkpoints"):
		node.activated.connect(_on_checkpoint_activated)

	for node in get_tree().get_nodes_in_group("collectibles"):
		coins_total += 1
		node.collected.connect(_on_collectible_collected)
	hud.set_local_coins(coins_collected, coins_total)

	for node in get_tree().get_nodes_in_group("goal"):
		node.reached.connect(_on_goal_reached)


func _find_spawn() -> Node3D:
	for node in get_tree().get_nodes_in_group("spawn"):
		if node is Node3D:
			return node
	return world.get_node_or_null("SpawnLocation") as Node3D


func _spawn_character() -> void:
	var scene := load(CHARACTER_SCENE_PATH) as PackedScene
	character = scene.instantiate() as PlayerCharacter
	var display_name := _local_player_name()
	character.set_character_name(display_name)
	character.set_meta("lua_name", display_name)
	character.died.connect(_on_character_died)
	character.shift_lock_changed.connect(hud.set_crosshair_visible)
	character.health_changed.connect(_on_character_health_changed)
	world.add_child(character)
	character.global_position = respawn_position
	character.input_enabled = not game_menu.is_open() and not hud.is_chat_open()
	if _respawn_shift_lock:
		character.camera_rig.set_shift_lock(true)
	hud.set_health(character.health)
	hud.set_crosshair_visible(_respawn_shift_lock)
	if _lua_runtime != null:
		_lua_runtime.character = character
		_lua_runtime.player_name = display_name


func _on_character_health_changed(value: float) -> void:
	hud.set_health(value)


func _on_character_died() -> void:
	if _lua_runtime != null:
		_lua_runtime.character = null
	if character:
		_respawn_shift_lock = character.shift_lock
	character.queue_free()
	character = null
	global_sound.stream = SfxFactory.death()
	global_sound.play()
	call_deferred("_spawn_character")


func _on_checkpoint_activated(spawn_position: Vector3) -> void:
	respawn_position = spawn_position
	hud.add_system_line("Checkpoint raggiunto!")


func _on_collectible_collected(_collectible: Collectible) -> void:
	coins_collected += 1
	hud.set_local_coins(coins_collected, coins_total)
	if coins_collected == coins_total:
		hud.add_system_line("Hai raccolto tutte le monete!")


func _on_goal_reached() -> void:
	if goal_reached:
		return
	goal_reached = true
	global_sound.stream = SfxFactory.goal()
	global_sound.play()
	hud.show_banner("GIOCO COMPLETATO!", 5.0)
	hud.add_system_line("Traguardo raggiunto!")


# --- Game Menu, Leave e Reset --------------------------------------------------

func _open_game_menu() -> void:
	if not _place_mode or not _game_started or hud.is_chat_open() or game_menu.is_open():
		return
	game_menu.open_menu()


func _on_game_menu_opened() -> void:
	hud.set_menu_open(true)
	_menu_restore_shift_lock = character != null and character.shift_lock
	_set_character_input(false)
	if character and _menu_restore_shift_lock:
		character.camera_rig.set_shift_lock(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_game_menu_closed() -> void:
	hud.set_menu_open(false)
	_set_character_input(true)
	if character and _menu_restore_shift_lock:
		character.camera_rig.set_shift_lock(true)
	_menu_restore_shift_lock = false


func _on_game_menu_leave() -> void:
	place_client.leave()


func _on_game_menu_reset() -> void:
	if character:
		character.set_health(0.0)


func _on_chat_opened() -> void:
	_chat_restore_shift_lock = character != null and character.shift_lock
	_set_character_input(false)
	if character and _chat_restore_shift_lock:
		character.camera_rig.set_shift_lock(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_chat_closed() -> void:
	if game_menu.is_open():
		_chat_restore_shift_lock = false
		return
	_set_character_input(true)
	if character and _chat_restore_shift_lock:
		character.camera_rig.set_shift_lock(true)
	_chat_restore_shift_lock = false


func _set_character_input(enabled: bool) -> void:
	if character:
		character.input_enabled = enabled


# --- Multiplayer ---------------------------------------------------------------

func _on_net_connected() -> void:
	hud.add_system_line("Connesso in multiplayer!")
	_refresh_player_list()


func _on_net_disconnected() -> void:
	_clear_remote_characters()
	hud.add_system_line("Connessione persa: modalità single player.")


func _on_net_failed() -> void:
	hud.add_system_line("Server non raggiungibile: modalità single player.")


func _on_net_server_error(code: String, message: String) -> void:
	hud.add_system_line(message)
	if code in ["rejected", "full"]:
		net.stop()
		_clear_remote_characters()


func _on_peer_joined(id: int, peer_name: String) -> void:
	if id == net.my_id or _remote_characters.has(id):
		return
	var scene := load(REMOTE_CHARACTER_SCENE_PATH) as PackedScene
	var remote := scene.instantiate() as RemoteCharacter
	world.add_child(remote)
	remote.setup(peer_name, Vector3(0, 30, 0), 0.0)
	_remote_characters[id] = remote
	_refresh_player_list()


func _on_peer_left(id: int) -> void:
	var remote: RemoteCharacter = _remote_characters.get(id)
	if remote:
		_remote_characters.erase(id)
		remote.queue_free()
		_refresh_player_list()


func _on_peer_state(id: int, position: Vector3, yaw: float, speed: float) -> void:
	var remote: RemoteCharacter = _remote_characters.get(id)
	if remote:
		remote.apply_state(position, yaw, speed)


func _on_chat_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	if _place_mode and bool(_player_info.get("is_guest", false)):
		hud.add_system_line("Gli ospiti non possono chattare. Accedi per usare la chat.")
		return
	hud.add_chat_line(net.player_name, clean)
	net.send_chat(clean)


func _on_chat_received(sender: String, text: String) -> void:
	hud.add_chat_line(sender, text)


func _clear_remote_characters() -> void:
	for remote in _remote_characters.values():
		remote.queue_free()
	_remote_characters.clear()
	_refresh_player_list()


func _refresh_player_list() -> void:
	var names: Array[String] = []
	for remote in _remote_characters.values():
		var remote_name := str(remote.display_name)
		if remote_name != "":
			names.append(remote_name)
	hud.set_player_list(_local_player_name(), names)


func _local_player_name() -> String:
	if net.player_name.strip_edges() != "":
		return net.player_name
	return menu.player_name() if not _place_mode else "Giocatore"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		net.stop()
