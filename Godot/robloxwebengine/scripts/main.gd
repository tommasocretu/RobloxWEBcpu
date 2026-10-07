extends Node
## Bootstrap del gioco: schermata di scelta del livello (file o predefinito) →
## mondo costruito dai dati con LevelBuilder → menu → Play → multiplayer via
## WebSocket, checkpoint/morte/respawn, monete e traguardo.

const CHARACTER_SCENE_PATH := "res://scenes/player/character.tscn"
const REMOTE_CHARACTER_SCENE_PATH := "res://scenes/player/remote_character.tscn"
const EDITOR_SCENE_PATH := "res://scenes/editor/editor.tscn"
const SPAWN_OFFSET := Vector3(0, 5, 0)
const MESSAGE_TIME := 3.0
const STATE_SEND_INTERVAL := 1.0 / 15.0

@onready var world: Node3D = $World
@onready var menu: MainMenu = $Menu
@onready var hud: GameHUD = $HUD
@onready var level_select: LevelSelect = $LevelSelect
@onready var global_sound: AudioStreamPlayer = $GlobalSound
@onready var net: NetClient = $NetClient

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


func _ready() -> void:
	print("ROBLOXWEBENGINE_READY")
	menu.play_pressed.connect(_on_play_pressed)
	hud.visible = false
	menu.visible = false
	hud.chat_submitted.connect(_on_chat_submitted)
	net.connected.connect(_on_net_connected)
	net.disconnected.connect(_on_net_disconnected)
	net.connection_failed.connect(_on_net_failed)
	net.peer_joined.connect(_on_peer_joined)
	net.peer_left.connect(_on_peer_left)
	net.peer_state.connect(_on_peer_state)
	net.chat_received.connect(_on_chat_received)
	level_select.level_chosen.connect(_on_level_chosen)
	level_select.editor_requested.connect(_on_editor_requested)

	if not LevelData.play_request.is_empty():
		# Avvio diretto in modalità test (pulsante "Testa" dell'editor).
		var request: Dictionary = LevelData.play_request
		LevelData.play_request = {}
		_test_mode = true
		level_select.visible = false
		start_level(request)
		_on_play_pressed()
	else:
		level_select.visible = true


## Costruisce il mondo a partire dai dati di un livello. Ritorna false se non validi.
func start_level(incoming: Dictionary) -> bool:
	if incoming.is_empty() or not LevelData.validate(incoming).is_empty():
		return false
	level_data = incoming
	LevelBuilder.build_into(world, level_data)
	goal_reached = false
	coins_total = 0
	coins_collected = 0
	respawn_position = Vector3(0, 5, 12)
	hud.set_coins(0, 0)
	return true


func _process(delta: float) -> void:
	if not _game_started or character == null or not net.is_open():
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state_timer = STATE_SEND_INTERVAL
		var speed := Vector2(character.velocity.x, character.velocity.z).length()
		net.send_state(character.global_position, character.visual.rotation.y, speed)


func _unhandled_input(event: InputEvent) -> void:
	if not _test_mode or not _game_started:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and not hud.is_chat_open():
		_return_to_editor()
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
	net.player_name = menu.player_name()
	_connect_world_nodes()
	_spawn_character()
	if _test_mode:
		hud.show_message("Modalità test — Esc per tornare all'editor", 4.0)
	else:
		hud.show_message("Raggiungi il traguardo in alto!", MESSAGE_TIME)
		net.start(NetClient.resolve_server_url())


func _return_to_editor() -> void:
	net.stop()
	get_tree().change_scene_to_file(EDITOR_SCENE_PATH)


func _connect_world_nodes() -> void:
	var spawn := _find_spawn()
	if spawn:
		respawn_position = spawn.global_position + SPAWN_OFFSET

	for node in get_tree().get_nodes_in_group("checkpoints"):
		node.activated.connect(_on_checkpoint_activated)

	for node in get_tree().get_nodes_in_group("collectibles"):
		coins_total += 1
		node.collected.connect(_on_collectible_collected)
	hud.set_coins(coins_collected, coins_total)

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
	character.set_character_name(net.player_name if net.player_name != "" else menu.player_name())
	character.died.connect(_on_character_died)
	character.shift_lock_changed.connect(hud.set_crosshair_visible)
	character.health_changed.connect(hud.set_health)
	world.add_child(character)
	character.global_position = respawn_position
	hud.set_health(character.health)
	hud.set_crosshair_visible(false)


func _on_character_died() -> void:
	character.queue_free()
	character = null
	global_sound.stream = SfxFactory.death()
	global_sound.play()
	call_deferred("_spawn_character")


func _on_checkpoint_activated(spawn_position: Vector3) -> void:
	respawn_position = spawn_position
	hud.show_message("Checkpoint raggiunto!", 2.0)


func _on_collectible_collected(_collectible: Collectible) -> void:
	coins_collected += 1
	hud.set_coins(coins_collected, coins_total)
	if coins_collected == coins_total:
		hud.show_message("Tutte le monete raccolte!", 2.5)


func _on_goal_reached() -> void:
	if goal_reached:
		return
	goal_reached = true
	global_sound.stream = SfxFactory.goal()
	global_sound.play()
	hud.show_message("TRAGUARDO! Livello completato.", 5.0)


# --- Multiplayer ---------------------------------------------------------------

func _on_net_connected() -> void:
	hud.show_message("Connesso in multiplayer!", 2.0)
	hud.set_players(1 + _remote_characters.size())


func _on_net_disconnected() -> void:
	_clear_remote_characters()
	hud.show_message("Connessione persa: modalità single player.", 3.0)


func _on_net_failed() -> void:
	hud.show_message("Server non raggiungibile: modalità single player.", 3.0)


func _on_peer_joined(id: int, peer_name: String) -> void:
	if id == net.my_id or _remote_characters.has(id):
		return
	var scene := load(REMOTE_CHARACTER_SCENE_PATH) as PackedScene
	var remote := scene.instantiate() as RemoteCharacter
	world.add_child(remote)
	remote.setup(peer_name, Vector3(0, 30, 0), 0.0)
	_remote_characters[id] = remote
	hud.set_players(1 + _remote_characters.size())


func _on_peer_left(id: int) -> void:
	var remote: RemoteCharacter = _remote_characters.get(id)
	if remote:
		_remote_characters.erase(id)
		remote.queue_free()
		hud.set_players(1 + _remote_characters.size())


func _on_peer_state(id: int, position: Vector3, yaw: float, speed: float) -> void:
	var remote: RemoteCharacter = _remote_characters.get(id)
	if remote:
		remote.apply_state(position, yaw, speed)


func _on_chat_submitted(text: String) -> void:
	var clean := text.strip_edges()
	if clean == "":
		return
	hud.add_chat_line(net.player_name, clean)
	net.send_chat(clean)


func _on_chat_received(sender: String, text: String) -> void:
	hud.add_chat_line(sender, text)


func _clear_remote_characters() -> void:
	for remote in _remote_characters.values():
		remote.queue_free()
	_remote_characters.clear()
	hud.set_players(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		net.stop()
