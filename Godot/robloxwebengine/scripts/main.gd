extends Node
## Launcher del gioco:
## - web: legge `?place=`, carica il livello dall'API e si connette al relay con un ticket;
## - build nativa dev: LevelSelect → LevelBuilder → Menu/Play;
## - test play / Studio: avvio diretto con `LevelData.play_request`.
## Comune: checkpoint/morte/respawn, monete, traguardo, multiplayer.

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
var _boot_layer: CanvasLayer
var _boot_title: Label
var _boot_detail: Label
var _leave_layer: CanvasLayer


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
	elif OS.has_feature("studio"):
		get_tree().call_deferred("change_scene_to_file", EDITOR_SCENE_PATH)
	elif OS.has_feature("web"):
		if place_client.read_query_param("editor") == "1":
			# Editor web temporaneo (M1): la build definitiva lo esclude in M2.
			get_tree().call_deferred("change_scene_to_file", EDITOR_SCENE_PATH)
			return
		# Client web: nessun LevelSelect/Menu/editor, si carica la place da `?place=`.
		level_select.visible = false
		menu.visible = false
		hud.visible = false
		_show_boot("Caricamento esperienza…", "Connessione al server e preparazione del mondo.")
		place_client.start()
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
	if not _game_started:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE and not hud.is_chat_open():
		if _leave_layer != null and _leave_layer.visible:
			_hide_leave_menu()
		elif _place_mode:
			_show_leave_menu()
		elif _test_mode:
			_return_to_editor()
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
	_connect_world_nodes()
	_spawn_character()
	if _test_mode:
		hud.show_message("Modalità test — Esc per tornare all'editor", 4.0)
	elif _place_mode:
		# Il messaggio di benvenuto lo mostra _on_place_loaded.
		net.start_with_ticket(_pending_ws_url, _pending_ticket, net.player_name)
	else:
		# Build nativa di sviluppo: nessun ticket place, si gioca in single player.
		# Il multiplayer si prova dal sito (client web) o con tools/test_network.gd.
		hud.show_message("Modalità sviluppo — single player", 3.0)


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
	net.player_name = str(player.get("name", "Giocatore"))
	if not start_level(level):
		_on_place_failed("Livello non valido.", "invalid")
		return
	_hide_boot()
	_on_play_pressed()
	var is_guest := bool(player.get("is_guest", true))
	hud.set_chat_enabled(not is_guest)
	if is_guest:
		hud.show_message(
			"Benvenuto, %s! Sei un ospite: accedi per chattare." % net.player_name, 5.0
		)
	else:
		hud.show_message("Benvenuto, %s!" % net.player_name, 3.0)


func _on_place_failed(message: String, code: String) -> void:
	hud.visible = false
	var hint := ""
	match code:
		"no_place":
			hint = ""
		"unauthorized":
			hint = "Apri l'esperienza dal sito e accedi con un account o come ospite."
		"not_found", "forbidden":
			hint = "L'esperienza non esiste o non è visibile al tuo account."
		"unavailable":
			hint = "L'autore non ha ancora pubblicato una versione giocabile."
		"network":
			hint = "Controlla che il server sia attivo: python3 server/run.py"
		_:
			hint = "Riprova più tardi o torna al catalogo."
	var detail := message
	if hint != "" and hint != message:
		detail = "%s\n\n%s" % [message, hint]
	_show_boot("Impossibile avviare l'esperienza", detail, true)


func _show_boot(title_text: String, detail_text: String, show_leave := false) -> void:
	if _boot_layer == null:
		_boot_layer = CanvasLayer.new()
		_boot_layer.name = "BootOverlay"
		add_child(_boot_layer)
		var background := ColorRect.new()
		background.color = Color(0.035, 0.05, 0.08, 1.0)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_boot_layer.add_child(background)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_boot_layer.add_child(center)
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(560, 0)
		box.add_theme_constant_override("separation", 16)
		center.add_child(box)
		_boot_title = Label.new()
		_boot_title.add_theme_font_size_override("font_size", 32)
		_boot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boot_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_boot_title)
		_boot_detail = Label.new()
		_boot_detail.add_theme_font_size_override("font_size", 17)
		_boot_detail.add_theme_color_override("font_color", Color(0.62, 0.69, 0.8))
		_boot_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_boot_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(_boot_detail)
		var leave_button := Button.new()
		leave_button.name = "LeaveButton"
		leave_button.text = "Torna al sito"
		leave_button.custom_minimum_size = Vector2(220, 46)
		leave_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		leave_button.pressed.connect(place_client.leave)
		box.add_child(leave_button)
	_boot_title.text = title_text
	_boot_detail.text = detail_text
	var button := _boot_layer.get_node_or_null("CenterContainer/VBoxContainer/LeaveButton") as Button
	if button == null:
		button = _find_boot_button()
	if button:
		button.visible = show_leave
	_boot_layer.visible = true


func _find_boot_button() -> Button:
	if _boot_layer == null:
		return null
	for node in _boot_layer.get_children():
		if node is CenterContainer:
			for child in node.get_children():
				if child is VBoxContainer:
					for item in child.get_children():
						if item is Button:
							return item
	return null


func _hide_boot() -> void:
	if _boot_layer:
		_boot_layer.visible = false


func _show_leave_menu() -> void:
	if _leave_layer == null:
		_leave_layer = CanvasLayer.new()
		_leave_layer.name = "LeaveMenu"
		add_child(_leave_layer)
		var background := ColorRect.new()
		background.color = Color(0, 0, 0, 0.65)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_leave_layer.add_child(background)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_leave_layer.add_child(center)
		var panel := PanelContainer.new()
		center.add_child(panel)
		var margin := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 26)
		panel.add_child(margin)
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(380, 0)
		box.add_theme_constant_override("separation", 14)
		margin.add_child(box)
		var title := Label.new()
		title.text = "Lascia l'esperienza?"
		title.add_theme_font_size_override("font_size", 26)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var leave := Button.new()
		leave.name = "LeaveButton"
		leave.text = "Lascia l'esperienza"
		leave.custom_minimum_size = Vector2(0, 44)
		leave.pressed.connect(place_client.leave)
		box.add_child(leave)
		var resume := Button.new()
		resume.text = "Continua a giocare"
		resume.custom_minimum_size = Vector2(0, 44)
		resume.pressed.connect(_hide_leave_menu)
		box.add_child(resume)
	_leave_layer.visible = true
	var focus_button := _leave_layer.find_child("LeaveButton", true, false) as Button
	if focus_button:
		focus_button.grab_focus()


func _hide_leave_menu() -> void:
	if _leave_layer:
		_leave_layer.visible = false


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


func _on_net_server_error(code: String, message: String) -> void:
	hud.show_message(message, 4.0)
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
	if _place_mode and bool(_player_info.get("is_guest", false)):
		hud.show_message("Gli ospiti non possono chattare. Accedi per usare la chat.", 3.0)
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
