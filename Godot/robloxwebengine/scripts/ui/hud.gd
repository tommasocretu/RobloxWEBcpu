class_name GameHUD
extends CanvasLayer
## HUD 2014: chat, player list, salute, input chat, pulsante Menu, mirino,
## banner, hurt overlay e FPS di debug.
##
## Il root è in design space (scala 0.8–1.0 applicata al CanvasLayer).
## Nessun `theme_override_*`: colori, font e stylebox arrivano da [RwTheme].

signal chat_submitted(text: String)
signal chat_opened
signal chat_closed
signal menu_requested

const CHAT_LIFETIME := 45.0
const CHAT_FADE := 0.5
const CHAT_PLACEHOLDER := "Per chattare clicca qui o premi \"/\""
const CHAT_GUEST_PLACEHOLDER := "Gli ospiti non possono chattare."
const CHAT_GUEST_WARNING := "Gli ospiti non possono chattare. Accedi per usare la chat."

@onready var root: Control = $Root
@onready var chat_log: RichTextLabel = $Root/ChatLog
@onready var chat_input: LineEdit = $Root/ChatInput
@onready var player_list: PanelContainer = $Root/PlayerList
@onready var player_list_vbox: VBoxContainer = $Root/PlayerList/VBox
@onready var player_list_header: Button = $Root/PlayerList/VBox/Header
@onready var header_name: Label = $Root/PlayerList/VBox/Header/HeaderName
@onready var header_coins: Label = $Root/PlayerList/VBox/Header/HeaderCoins
@onready var header_chevron: Label = $Root/PlayerList/VBox/Header/Chevron
@onready var player_rows: VBoxContainer = $Root/PlayerList/VBox/Rows
@onready var health: Control = $Root/Health
@onready var health_bar: TextureProgressBar = $Root/Health/Bar
@onready var health_label: Label = $Root/Health/Label
@onready var menu_trigger: MenuTrigger = $Root/MenuTrigger
@onready var crosshair: Panel = $Root/Crosshair
@onready var banner: BannerOverlay = $Banner
@onready var debug_overlay: DebugOverlay = $Debug
@onready var hurt_overlay: HurtOverlay = $HurtOverlay

var _chat_entries: Array[Dictionary] = []
var _chat_clock := 0.0
var _chat_enabled := true
var _chat_open := false
var _menu_open := false

var _local_name := ""
var _remote_names: Array[String] = []
var _coins_collected := 0
var _coins_total := 0

var _health_value := 100.0
var _health_tween: Tween
var _health_texture: GradientTexture2D
var _health_texture_low: GradientTexture2D
var _last_viewport_size := Vector2.ZERO

static var _player_list_collapsed := false


func _ready() -> void:
	root.theme = RwTheme.shared()
	chat_log.bbcode_enabled = true
	chat_log.scroll_active = false
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	chat_input.focus_entered.connect(_on_chat_focus_entered)
	chat_input.focus_exited.connect(_on_chat_focus_exited)
	chat_input.gui_input.connect(_on_chat_gui_input)
	player_list_header.pressed.connect(toggle_player_list)
	menu_trigger.pressed.connect(_on_menu_trigger_pressed)
	menu_trigger.visible = false
	_build_health_textures()
	_apply_layout()
	call_deferred("_apply_layout")
	get_viewport().size_changed.connect(_apply_layout)
	set_health(100.0)
	set_local_coins(0, 0)
	set_player_list("", [])
	set_chat_enabled(true)


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_apply_layout()
	if _chat_entries.is_empty():
		return
	_chat_clock += delta
	var changed := false
	while not _chat_entries.is_empty():
		var entry: Dictionary = _chat_entries[0]
		if _chat_clock >= float(entry["born"]) + CHAT_LIFETIME:
			_chat_entries.pop_front()
			changed = true
		else:
			break
	var fading := false
	for entry in _chat_entries:
		var remaining := float(entry["born"]) + CHAT_LIFETIME - _chat_clock
		if remaining <= CHAT_FADE:
			fading = true
			break
	if changed or fading:
		_rebuild_chat()


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	RwLayout.apply(self, root)


# --- Chat ---------------------------------------------------------------------

static func name_color_index(player_name: String) -> int:
	var total := 0
	for byte in player_name.to_utf8_buffer():
		total += int(byte)
	return total % RwTokens.CHAT_NAME_COLORS.size()


static func name_color(player_name: String) -> Color:
	return RwTokens.CHAT_NAME_COLORS[name_color_index(player_name)]


func add_system_line(text: String) -> void:
	_add_chat_entry("", text, true)


func add_chat_line(sender: String, text: String) -> void:
	if sender.strip_edges() == "":
		add_system_line(text)
		return
	_add_chat_entry(sender, text, false)


func _add_chat_entry(sender: String, text: String, system: bool) -> void:
	_chat_entries.append({
		"sender": sender,
		"text": text,
		"system": system,
		"born": _chat_clock,
	})
	while _chat_entries.size() > RwTokens.CHAT_HISTORY:
		_chat_entries.pop_front()
	_rebuild_chat()


func clear_chat() -> void:
	_chat_entries.clear()
	_chat_clock = 0.0
	_rebuild_chat()


func chat_has_line(sender: String, text: String) -> bool:
	for entry in _chat_entries:
		if bool(entry["system"]):
			if sender == "" and str(entry["text"]) == text:
				return true
		elif str(entry["sender"]) == sender and str(entry["text"]) == text:
			return true
	return false


func chat_line_count() -> int:
	return _chat_entries.size()


func visible_chat_line_count() -> int:
	return mini(_chat_entries.size(), RwTokens.CHAT_VISIBLE_LINES)


func _rebuild_chat() -> void:
	var lines: Array[String] = []
	var first := maxi(0, _chat_entries.size() - RwTokens.CHAT_VISIBLE_LINES)
	for index in range(first, _chat_entries.size()):
		var entry: Dictionary = _chat_entries[index]
		var alpha := 1.0
		var remaining := float(entry["born"]) + CHAT_LIFETIME - _chat_clock
		if remaining < CHAT_FADE:
			alpha = clampf(remaining / CHAT_FADE, 0.0, 1.0)
		if alpha <= 0.0:
			continue
		if bool(entry["system"]):
			lines.append("[color=%s]%s[/color]" % [
				_color_hex(RwTokens.GOLD, alpha),
				_escape_bbcode(str(entry["text"])),
			])
		else:
			var sender := str(entry["sender"])
			lines.append("[color=%s]%s[/color][color=%s]: %s[/color]" % [
				_color_hex(name_color(sender), alpha),
				_escape_bbcode(sender),
				_color_hex(RwTokens.UI_TEXT, alpha),
				_escape_bbcode(str(entry["text"])),
			])
	chat_log.text = "\n".join(lines)


static func _color_hex(color: Color, alpha: float) -> String:
	return "#" + Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0)).to_html(true)


static func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")


func set_chat_enabled(enabled: bool) -> void:
	_chat_enabled = enabled
	chat_input.editable = enabled
	chat_input.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	chat_input.placeholder_text = CHAT_PLACEHOLDER if enabled else CHAT_GUEST_PLACEHOLDER
	if not enabled:
		_close_chat()


func is_chat_enabled() -> bool:
	return _chat_enabled


func is_chat_open() -> bool:
	return _chat_open


func close_chat() -> void:
	_close_chat()


func _open_chat() -> void:
	if _menu_open:
		return
	if not _chat_enabled:
		add_system_line(CHAT_GUEST_WARNING)
		return
	if _chat_open:
		chat_input.grab_focus()
		return
	_chat_open = true
	chat_input.grab_focus()
	chat_opened.emit()


func _close_chat() -> void:
	if not _chat_open:
		return
	_chat_open = false
	chat_input.text = ""
	if chat_input.has_focus():
		chat_input.release_focus()
	chat_closed.emit()


func _on_chat_focus_entered() -> void:
	if _chat_open or not _chat_enabled or _menu_open:
		return
	_chat_open = true
	chat_input.text = ""
	chat_opened.emit()


func _on_chat_focus_exited() -> void:
	if _chat_open:
		_close_chat()


func _on_chat_text_submitted(text: String) -> void:
	var clean := text.strip_edges()
	_close_chat()
	if clean != "":
		chat_submitted.emit(clean)


func _on_chat_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not _chat_open:
		_open_chat()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_close_chat()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _chat_open or _menu_open:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if key != KEY_SLASH and key != KEY_ENTER and key != KEY_KP_ENTER:
		return
	if _chat_enabled:
		_open_chat()
	else:
		add_system_line(CHAT_GUEST_WARNING)
	get_viewport().set_input_as_handled()


# --- Player list --------------------------------------------------------------

func set_local_coins(collected: int, total: int) -> void:
	_coins_collected = maxi(collected, 0)
	_coins_total = maxi(total, 0)
	_refresh_player_list()


func set_player_list(local_name: String, remote_names: Array[String]) -> void:
	_local_name = local_name.strip_edges()
	_remote_names.clear()
	for remote in remote_names:
		var clean := str(remote).strip_edges()
		if clean == "" or clean == _local_name or _remote_names.has(clean):
			continue
		_remote_names.append(clean)
	_refresh_player_list()


func toggle_player_list() -> void:
	_player_list_collapsed = not _player_list_collapsed
	_refresh_player_list()


func is_player_list_collapsed() -> bool:
	return _player_list_collapsed


func player_list_names() -> Array[String]:
	var names: Array[String] = []
	for row in player_rows.get_children():
		var label := row.find_child("Name", true, false) as Label
		if label:
			names.append(label.text)
	return names


func _refresh_player_list() -> void:
	if not is_instance_valid(player_rows):
		return
	for child in player_rows.get_children():
		child.queue_free()

	var entries: Array[Dictionary] = []
	if _local_name != "":
		entries.append({"name": _local_name, "local": true})
	for remote in _remote_names:
		entries.append({"name": remote, "local": false})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]).nocasecmp_to(str(b["name"])) < 0
	)
	if entries.size() > RwTokens.PLAYERLIST_ROWS_MAX:
		entries.resize(RwTokens.PLAYERLIST_ROWS_MAX)

	for index in entries.size():
		var entry: Dictionary = entries[index]
		player_rows.add_child(_make_player_row(entry, index))

	var height := RwTokens.PLAYERLIST_COLLAPSED_H if _player_list_collapsed \
		else RwTokens.PLAYERLIST_HEAD_H + RwTokens.PLAYERLIST_ROW_H * entries.size()
	player_list.offset_left = -float(RwTokens.PLAYERLIST_W + RwTokens.PLAYERLIST_COINS_W)
	player_list.offset_right = 0.0
	player_list.offset_top = 5.0
	player_list.offset_bottom = 5.0 + float(height)
	player_list.custom_minimum_size = Vector2(
		RwTokens.PLAYERLIST_W + RwTokens.PLAYERLIST_COINS_W, height
	)
	player_list_header.custom_minimum_size = Vector2(
		0, RwTokens.PLAYERLIST_COLLAPSED_H if _player_list_collapsed \
			else RwTokens.PLAYERLIST_HEAD_H
	)
	player_list_vbox.add_theme_constant_override("separation", 0)
	player_rows.visible = not _player_list_collapsed
	header_coins.visible = not _player_list_collapsed
	header_chevron.visible = _player_list_collapsed
	if _player_list_collapsed:
		header_name.theme_type_variation = &"RwLabelPlayerCollapsed"
		header_name.text = "Giocatori"
		header_name.offset_top = 3.0
		header_name.offset_bottom = 21.0
	else:
		header_name.theme_type_variation = &"RwLabelPlayerHead"
		header_name.text = "Giocatori"
		header_name.offset_top = 7.0
		header_name.offset_bottom = 49.0


func _make_player_row(entry: Dictionary, index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "Row%d" % index
	row.theme_type_variation = &"RwPanelPlayerRowAlt" if index % 2 == 1 \
		else &"RwPanelPlayerRow"
	row.custom_minimum_size = Vector2(0, RwTokens.PLAYERLIST_ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var indent := Control.new()
	indent.custom_minimum_size = Vector2(8, 0)
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(indent)

	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = str(entry["name"])
	name_label.theme_type_variation = &"RwLabelPlayerNameLocal" if bool(entry["local"]) \
		else &"RwLabelPlayerName"
	name_label.custom_minimum_size = Vector2(138, RwTokens.PLAYERLIST_ROW_H)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)

	var coins_label := Label.new()
	coins_label.name = "Coins"
	if bool(entry["local"]) and _coins_total > 0:
		coins_label.text = "%d/%d" % [_coins_collected, _coins_total]
	else:
		coins_label.text = "—"
	coins_label.theme_type_variation = &"RwLabelPlayerCoins"
	coins_label.custom_minimum_size = Vector2(RwTokens.PLAYERLIST_COINS_W, RwTokens.PLAYERLIST_ROW_H)
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(coins_label)

	var right_pad := Control.new()
	right_pad.custom_minimum_size = Vector2(4, 0)
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(right_pad)
	return row


# --- Salute, mirino, menu -----------------------------------------------------

func set_health(value: float) -> void:
	var clamped := clampf(value, 0.0, PlayerCharacter.MAX_HEALTH)
	if clamped < _health_value - 0.001 and _health_value - clamped >= 5.0:
		hurt_overlay.flash()
	_health_value = clamped
	health_bar.texture_progress = _health_texture_low if clamped < 25.0 else _health_texture
	if _health_tween and _health_tween.is_valid():
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.tween_property(health_bar, "value", clamped, 0.2)


func flash_hurt() -> void:
	hurt_overlay.flash()


func set_crosshair_visible(enabled: bool) -> void:
	crosshair.visible = enabled


func set_menu_enabled(enabled: bool) -> void:
	menu_trigger.visible = enabled


func set_menu_open(open: bool) -> void:
	_menu_open = open
	if open:
		_close_chat()


func is_menu_open() -> bool:
	return _menu_open


func show_banner(text: String, duration: float = 5.0) -> void:
	banner.show_banner(text, duration)


func _on_menu_trigger_pressed() -> void:
	menu_requested.emit()


func _build_health_textures() -> void:
	_health_texture = _gradient_texture(
		PackedColorArray([RwTokens.HEALTH_TOP, RwTokens.HEALTH_MID, RwTokens.HEALTH_DARK]),
		PackedFloat32Array([0.0, 0.45, 1.0])
	)
	_health_texture_low = _gradient_texture(
		PackedColorArray([RwTokens.HEALTH_RED, RwTokens.HEALTH_RED, RwTokens.HEALTH_RED]),
		PackedFloat32Array([0.0, 0.45, 1.0])
	)
	health_bar.texture_progress = _health_texture
	health_bar.value = 100.0


func _gradient_texture(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = RwTokens.HEALTH_W
	texture.height = RwTokens.HEALTH_H
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	return texture
