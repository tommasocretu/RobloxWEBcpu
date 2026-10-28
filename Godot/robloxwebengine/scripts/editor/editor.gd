class_name LevelEditor
extends Node3D
## Editor di livelli v1: camera libera, piazzamento a click, selezione con pannello
## proprietà, snap a griglia, duplica/elimina, undo/redo, salva/apri file,
## autosave in user://, test-play e pubblicazione sul server (M1/M2, usato da Studio).

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const STUDIO_SCENE_PATH := "res://scenes/studio/studio_start.tscn"
const AUTOSAVE_PATH := "user://editor_autosave.rwl.json"
const PUBLISH_SETTINGS_PATH := PublishClient.PUBLISH_SETTINGS_PATH
const THUMBNAIL_SIZE := Vector2i(512, 288)
const UNDO_LIMIT := 100
const COALESCE_MS := 800

const DEFAULT_SIZES := {
	"part": Vector3(4, 1, 4),
	"spawn": Vector3(10, 1, 10),
	"checkpoint": Vector3(8, 1, 8),
	"coin": Vector3(2.4, 3.2, 2.4),
	"goal": Vector3(12, 8, 12),
	"kill": Vector3(12, 4, 12),
	"moving_platform": Vector3(6, 1, 6),
	"spinner": Vector3(14, 0.8, 1),
	"label": Vector3(0.1, 0.1, 0.1),
}
const DEFAULT_COLORS := {
	"part": Color(0.63, 0.64, 0.64),
	"spawn": Color(0.63, 0.64, 0.64),
	"checkpoint": Color(0.15, 0.45, 0.90),
	"coin": Color(0.98, 0.82, 0.22),
	"goal": Color(0.90, 0.72, 0.15),
	"kill": Color(0.85, 0.12, 0.05),
	"moving_platform": Color(0.96, 0.55, 0.16),
	"spinner": Color(0.77, 0.16, 0.11),
	"label": Color(1, 1, 1),
}
const KIND_LABELS := {
	"part": "Parte",
	"spawn": "Spawn",
	"checkpoint": "Checkpoint",
	"coin": "Moneta",
	"goal": "Traguardo",
	"kill": "Lava",
	"moving_platform": "Piattaforma",
	"spinner": "Spinner",
	"label": "Testo",
}
const KIND_BASE_NAMES := {
	"part": "Parte",
	"spawn": "SpawnLocation",
	"checkpoint": "Checkpoint",
	"coin": "Moneta",
	"goal": "Traguardo",
	"kill": "Lava",
	"moving_platform": "PiattaformaMobile",
	"spinner": "Spinner",
	"label": "Etichetta",
}
const PALETTE_ORDER: Array[String] = [
	"part", "spawn", "checkpoint", "coin", "goal", "kill",
	"moving_platform", "spinner", "label",
]

@onready var world: Node3D = $World
@onready var camera: Camera3D = $EditorCamera
@onready var ui: CanvasLayer = $UI

var data: Dictionary = {}
var selected_id := ""
var placing_kind := ""
var snap_enabled := true
var grid_step := 1.0
var simulate := false

var _file_io: LevelFileIO
var _undo_stack: Array = []
var _redo_stack: Array = []
var _undo_key := ""
var _undo_time := 0
var _rebuild_queued := false
var _autosave_timer: Timer
var _highlight: MeshInstance3D

# UI
var _status: Label
var _explorer: ItemList
var _props_root: VBoxContainer
var _no_selection: Label
var _name_edit: LineEdit
var _pos_spins: Array[SpinBox] = []
var _rot_spins: Array[SpinBox] = []
var _size_spins: Array[SpinBox] = []
var _part_rows: VBoxContainer
var _color_row: HBoxContainer
var _color_picker: ColorPickerButton
var _anchored_check: CheckButton
var _collide_check: CheckButton
var _transparency: HSlider
var _transparency_label: Label
var _moving_rows: VBoxContainer
var _moving_offset_spins: Array[SpinBox] = []
var _moving_duration: SpinBox
var _spinner_rows: VBoxContainer
var _spinner_speed: SpinBox
var _label_rows: VBoxContainer
var _label_text: LineEdit
var _label_pixel: SpinBox
var _grid_button: Button
var _palette_buttons: Dictionary = {}
var _account_label: Label

# Pubblicazione (M1)
var _publish_client: PublishClient
var _server_window: Window
var _server_url_edit: LineEdit
var _account_user_edit: LineEdit
var _account_pass_edit: LineEdit
var _account_button: Button
var _account_status: Label
var _account_tabs: TabContainer
var _target_label: Label
var _publish_title_edit: LineEdit
var _publish_description: TextEdit
var _visibility_option: OptionButton
var _thumbnail_check: CheckBox
var _thumbnail_preview: TextureRect
var _thumbnail_preview_status: Label
var _thumbnail_preview_button: Button
var _publish_button: Button
var _publish_status: Label
var _places_list: ItemList
var _places_status: Label
var _places_open_button: Button


func _ready() -> void:
	_file_io = LevelFileIO.new()
	add_child(_file_io)
	_publish_client = PublishClient.new()
	_publish_client.name = "PublishClient"
	_publish_client.base_url = PublishClient.default_base_url()
	add_child(_publish_client)
	_build_ui()

	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = 1.5
	_autosave_timer.timeout.connect(_write_autosave)
	add_child(_autosave_timer)

	_highlight = MeshInstance3D.new()
	_highlight.name = "SelectionHighlight"
	_highlight.visible = false
	add_child(_highlight)

	var pending := StudioSession.take_pending()
	var pending_message := StudioSession.take_message()
	if not pending.is_empty() and LevelData.validate(pending).is_empty():
		data = pending
		_status.text = pending_message if pending_message != "" else "Livello aperto."
	else:
		if not pending.is_empty():
			push_warning("StudioSession: il livello ricevuto non è valido, uso l'autosave.")
		var restored := LevelIO.load_from_path(AUTOSAVE_PATH)
		if not restored.is_empty() and LevelData.validate(restored).is_empty():
			data = restored
			_status.text = "Sessione ripristinata dall'autosave."
		else:
			data = LevelData.new_level()
	_rebuild()
	_refresh_properties()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_autosave()


# --- UI --------------------------------------------------------------------------

func _build_ui() -> void:
	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ui.add_child(top)
	var top_box := HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top.add_child(top_box)

	_add_top_button(top_box, "Nuovo", new_level)
	_add_top_button(top_box, "Apri…", _open_file_pressed)
	_add_top_button(top_box, "Salva…", _save_file_pressed)
	top_box.add_child(VSeparator.new())

	for kind in PALETTE_ORDER:
		var button := _make_button(KIND_LABELS[kind], "Piazza: %s" % KIND_LABELS[kind])
		button.toggle_mode = true
		button.toggled.connect(_on_palette_toggled.bind(kind))
		top_box.add_child(button)
		_palette_buttons[kind] = button

	top_box.add_child(VSeparator.new())
	_grid_button = _make_button("Griglia: 1", "Passo della griglia")
	_grid_button.pressed.connect(_cycle_grid)
	top_box.add_child(_grid_button)
	_add_top_button(top_box, "Snap: ON", _toggle_snap).name = "SnapButton"

	# Seconda riga: pubblicazione, account e strumenti di test.
	var publish_bar := PanelContainer.new()
	publish_bar.name = "PublishBar"
	publish_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	publish_bar.offset_top = 44
	publish_bar.offset_bottom = 80
	ui.add_child(publish_bar)
	var publish_box := HBoxContainer.new()
	publish_box.add_theme_constant_override("separation", 6)
	publish_bar.add_child(publish_box)

	var publish_button := _add_top_button(publish_box, "Pubblica", _open_server_window)
	publish_button.name = "PublishButton"
	_add_top_button(publish_box, "Place…", _open_my_places)
	_add_top_button(publish_box, "Account", _open_server_window)
	if _studio_mode():
		var script_button := _add_top_button(publish_box, "Script", _coming_soon)
		script_button.disabled = true
		script_button.tooltip_text = "Editor degli script: disponibile in M3"
		var output_button := _add_top_button(publish_box, "Output", _coming_soon)
		output_button.disabled = true
		output_button.tooltip_text = "Console degli script: disponibile in M3"
	_account_label = Label.new()
	_account_label.text = "Non connesso"
	_account_label.add_theme_font_size_override("font_size", 13)
	_account_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
	_account_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_account_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_account_label.clip_text = true
	publish_box.add_child(_account_label)
	publish_box.add_child(VSeparator.new())
	_add_top_button(publish_box, "Simula", _toggle_simulate)
	_add_top_button(publish_box, "Testa", _test_play)
	_add_top_button(publish_box, "Esci", _exit_editor)

	# Esploratore oggetti (sinistra).
	var left := PanelContainer.new()
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 8
	left.offset_right = 218
	left.offset_top = 84
	left.offset_bottom = -36
	ui.add_child(left)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	var explorer_title := Label.new()
	explorer_title.text = "Oggetti"
	explorer_title.add_theme_font_size_override("font_size", 14)
	left_box.add_child(explorer_title)
	_explorer = ItemList.new()
	_explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_explorer.item_selected.connect(_on_explorer_selected)
	left_box.add_child(_explorer)

	# Pannello proprietà (destra).
	var right := PanelContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.offset_left = -316
	right.offset_right = -8
	right.offset_top = 84
	right.offset_bottom = -36
	ui.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var props := VBoxContainer.new()
	props.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	props.custom_minimum_size.x = 280
	scroll.add_child(props)
	_build_properties(props)

	# Barra di stato (in basso).
	_status = Label.new()
	_status.name = "Status"
	_status.anchor_top = 1.0
	_status.anchor_bottom = 1.0
	_status.offset_left = 8
	_status.offset_right = -324
	_status.offset_top = -30
	_status.offset_bottom = -6
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.85, 0.90, 1.0))
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 4)
	ui.add_child(_status)


func _build_properties(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Proprietà"
	title.add_theme_font_size_override("font_size", 14)
	parent.add_child(title)

	_no_selection = Label.new()
	_no_selection.text = "Nessun oggetto selezionato.\nScegli una parte dalla palette in alto e clicca nel mondo."
	_no_selection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_selection.add_theme_font_size_override("font_size", 13)
	parent.add_child(_no_selection)

	_props_root = VBoxContainer.new()
	_props_root.add_theme_constant_override("separation", 5)
	parent.add_child(_props_root)

	_add_row_label(_props_root, "Nome")
	_name_edit = LineEdit.new()
	_name_edit.add_theme_font_size_override("font_size", 13)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(func() -> void: _on_name_submitted(_name_edit.text))
	_props_root.add_child(_name_edit)

	_add_row_label(_props_root, "Posizione")
	_add_vec3_row(_props_root, "", 0.5, _pos_spins).name = "PositionRow"
	for spin in _pos_spins:
		spin.value_changed.connect(_on_position_changed)

	_add_row_label(_props_root, "Rotazione (gradi)")
	_add_vec3_row(_props_root, "", 1.0, _rot_spins).name = "RotationRow"
	for spin in _rot_spins:
		spin.value_changed.connect(_on_rotation_changed)

	var size_label := _add_row_label(_props_root, "Dimensione")
	_add_vec3_row(_props_root, "", 0.5, _size_spins).name = "SizeRow"
	for spin in _size_spins:
		spin.value_changed.connect(_on_size_changed)

	var color_label := _add_row_label(_props_root, "Colore")
	_color_row = HBoxContainer.new()
	var spacer := Label.new()
	spacer.custom_minimum_size.x = 62
	_color_row.add_child(spacer)
	_color_picker = ColorPickerButton.new()
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.custom_minimum_size.y = 26
	_color_picker.color_changed.connect(_on_color_changed)
	_color_row.add_child(_color_picker)
	_props_root.add_child(_color_row)

	_part_rows = VBoxContainer.new()
	_part_rows.add_theme_constant_override("separation", 2)
	_props_root.add_child(_part_rows)
	_anchored_check = CheckButton.new()
	_anchored_check.text = "Ancorata"
	_anchored_check.add_theme_font_size_override("font_size", 13)
	_anchored_check.toggled.connect(_on_anchored_toggled)
	_part_rows.add_child(_anchored_check)
	_collide_check = CheckButton.new()
	_collide_check.text = "Collisione"
	_collide_check.add_theme_font_size_override("font_size", 13)
	_collide_check.toggled.connect(_on_collide_toggled)
	_part_rows.add_child(_collide_check)

	_transparency_label = _add_row_label(_props_root, "Trasparenza")
	_transparency = HSlider.new()
	_transparency.min_value = 0.0
	_transparency.max_value = 0.95
	_transparency.step = 0.05
	_transparency.value_changed.connect(_on_transparency_changed)
	_props_root.add_child(_transparency)

	# Piattaforma mobile.
	_moving_rows = VBoxContainer.new()
	_props_root.add_child(_moving_rows)
	_add_row_label(_moving_rows, "Offset movimento")
	_add_vec3_row(_moving_rows, "", 0.5, _moving_offset_spins)
	for spin in _moving_offset_spins:
		spin.value_changed.connect(_on_moving_changed)
	_add_row_label(_moving_rows, "Durata (s)")
	_moving_duration = _add_float_row(_moving_rows, 0.1, 120.0, 0.1)
	_moving_duration.value_changed.connect(_on_moving_changed)

	# Spinner.
	_spinner_rows = VBoxContainer.new()
	_props_root.add_child(_spinner_rows)
	_add_row_label(_spinner_rows, "Velocità (gradi/s)")
	_spinner_speed = _add_float_row(_spinner_rows, 5.0, 720.0, 5.0)
	_spinner_speed.value_changed.connect(_on_spinner_changed)

	# Etichetta.
	_label_rows = VBoxContainer.new()
	_props_root.add_child(_label_rows)
	_add_row_label(_label_rows, "Testo")
	_label_text = LineEdit.new()
	_label_text.add_theme_font_size_override("font_size", 13)
	_label_text.text_changed.connect(_on_label_changed)
	_label_rows.add_child(_label_text)
	_add_row_label(_label_rows, "Dimensione carattere (pixel)")
	_label_pixel = _add_float_row(_label_rows, 0.002, 0.2, 0.002)
	_label_pixel.value_changed.connect(_on_label_changed)

	# Riferimenti alle righe da mostrare/nascondere.
	size_label.name = "SizeLabel"
	color_label.name = "ColorLabel"


func _add_top_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := _make_button(text, "")
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	return button


func _add_row_label(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	parent.add_child(label)
	return label


func _add_vec3_row(
	parent: Control, label_text: String, step: float, output: Array
) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 62
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	for i in 3:
		var spin := SpinBox.new()
		spin.min_value = -LevelData.MAX_COORD
		spin.max_value = LevelData.MAX_COORD
		spin.step = step
		spin.allow_greater = false
		spin.allow_lesser = false
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.add_theme_font_size_override("font_size", 12)
		row.add_child(spin)
		output.append(spin)
	parent.add_child(row)
	return row


func _add_float_row(parent: Control, min_value: float, max_value: float, step: float) -> SpinBox:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.custom_minimum_size.x = 62
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.allow_greater = false
	spin.allow_lesser = false
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", 12)
	row.add_child(spin)
	parent.add_child(row)
	return spin


# --- Stato e selezione -------------------------------------------------------------

func selected_entity() -> Dictionary:
	if selected_id == "":
		return {}
	for entity in data.get("parts", []):
		if typeof(entity) == TYPE_DICTIONARY and str(entity.get("id", "")) == selected_id:
			return entity
	return {}


func select_entity(id: String) -> void:
	selected_id = id
	_refresh_properties()
	_update_highlight()


func _find_node(entity_id: String) -> Node3D:
	for child in world.get_children():
		if child is Node3D and child.has_meta("level_id") \
				and str(child.get_meta("level_id")) == entity_id:
			return child
	return null


func _rebuild() -> void:
	LevelBuilder.build_into(world, data)
	if not simulate:
		_freeze_dynamics()
	_refresh_explorer()
	_update_highlight()
	_update_window_title()


func _update_window_title() -> void:
	if not _studio_mode():
		return
	var suffix := LevelData.title(data)
	if suffix != "":
		DisplayServer.window_set_title("RobloxWeb Studio — %s" % suffix)
	else:
		DisplayServer.window_set_title("RobloxWeb Studio")


func _freeze_dynamics() -> void:
	for child in world.get_children():
		if child is RigidBody3D:
			(child as RigidBody3D).freeze = true
		if child is SpinnerPart or child is MovingPlatform:
			(child as Node).process_mode = Node.PROCESS_MODE_DISABLED


func _schedule_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_deferred_rebuild")


func _deferred_rebuild() -> void:
	_rebuild_queued = false
	_rebuild()


func _refresh_explorer() -> void:
	_explorer.clear()
	var parts: Array = data.get("parts", [])
	for i in parts.size():
		var entity = parts[i]
		if typeof(entity) != TYPE_DICTIONARY:
			continue
		var kind := str(entity.get("kind", ""))
		var index := _explorer.add_item("%s  [%s]" % [
			str(entity.get("name", "?")), KIND_LABELS.get(kind, kind)
		])
		if str(entity.get("id", "")) == selected_id:
			_explorer.select(index)


func _on_explorer_selected(index: int) -> void:
	var parts: Array = data.get("parts", [])
	if index < 0 or index >= parts.size():
		return
	if typeof(parts[index]) == TYPE_DICTIONARY:
		select_entity(str(parts[index].get("id", "")))


func _update_highlight() -> void:
	var entity := selected_entity()
	if entity.is_empty() or str(entity.get("kind", "")) == "label":
		_highlight.visible = false
		return
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3.ONE)
	var box := BoxMesh.new()
	box.size = size + Vector3(0.2, 0.2, 0.2)
	_highlight.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.25, 1.0, 0.4, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	_highlight.material_override = material
	_highlight.position = LevelData.array_to_vec3(entity.get("position", []))
	_highlight.rotation_degrees = LevelData.array_to_vec3(entity.get("rotation", []))
	_highlight.visible = true


# --- Proprietà ---------------------------------------------------------------------

func _refresh_properties() -> void:
	var entity := selected_entity()
	if entity.is_empty():
		_no_selection.visible = true
		_props_root.visible = false
		return
	_no_selection.visible = false
	_props_root.visible = true

	_name_edit.text = str(entity.get("name", ""))
	var position := LevelData.array_to_vec3(entity.get("position", []))
	var rotation := LevelData.array_to_vec3(entity.get("rotation", []))
	var size := LevelData.array_to_vec3(entity.get("size", []))
	for i in 3:
		_pos_spins[i].set_value_no_signal(position[i])
		_rot_spins[i].set_value_no_signal(rotation[i])
		_size_spins[i].set_value_no_signal(size[i])
	_color_picker.set_pick_color(LevelData.hex_to_color(entity.get("color", "")))
	_anchored_check.set_pressed_no_signal(bool(entity.get("anchored", true)))
	_collide_check.set_pressed_no_signal(bool(entity.get("collide", true)))
	_transparency.set_value_no_signal(float(entity.get("transparency", 0.0)))

	var kind := str(entity.get("kind", ""))
	var is_simple := kind == "part" or kind == "spawn"
	var props: Dictionary = entity.get("props", {})
	var size_row := _props_root.get_node_or_null("SizeRow") as HBoxContainer
	var size_label := _props_root.get_node_or_null("SizeLabel") as Label
	var color_label := _props_root.get_node_or_null("ColorLabel") as Label
	if size_row:
		size_row.visible = kind != "label"
	if size_label:
		size_label.visible = kind != "label"
	if color_label:
		color_label.visible = kind != "label"
	_color_row.visible = kind != "label"
	_part_rows.visible = is_simple
	_transparency.visible = is_simple
	_transparency_label.visible = is_simple

	_moving_rows.visible = kind == "moving_platform"
	_spinner_rows.visible = kind == "spinner"
	_label_rows.visible = kind == "label"

	if kind == "moving_platform":
		var offset := LevelData.array_to_vec3(props.get("offset", []), Vector3(8, 0, 0))
		for i in 3:
			_moving_offset_spins[i].set_value_no_signal(offset[i])
		_moving_duration.set_value_no_signal(float(props.get("duration", 4.0)))
	elif kind == "spinner":
		_spinner_speed.set_value_no_signal(float(props.get("speed", 90.0)))
	elif kind == "label":
		_label_text.text = str(props.get("text", "Testo"))
		_label_pixel.set_value_no_signal(float(props.get("pixel_size", 0.012)))


func _apply_live(entity: Dictionary) -> void:
	var node := _find_node(str(entity.get("id", "")))
	if node == null:
		return
	node.position = LevelData.array_to_vec3(entity.get("position", []))
	node.rotation_degrees = LevelData.array_to_vec3(entity.get("rotation", []))
	var kind := str(entity.get("kind", ""))
	if kind == "part" or kind == "spawn":
		_apply_simple_visual(entity, node)
	elif kind == "label" and node is Label3D:
		var props: Dictionary = entity.get("props", {})
		(node as Label3D).text = str(props.get("text", "Testo"))
		(node as Label3D).pixel_size = float(props.get("pixel_size", 0.012))
	else:
		_schedule_rebuild()
	_update_highlight()


func _apply_simple_visual(entity: Dictionary, node: Node3D) -> void:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3.ONE)
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		(mesh.mesh as BoxMesh).size = size
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision:
		if collision.shape is BoxShape3D:
			(collision.shape as BoxShape3D).size = size
		collision.disabled = not bool(entity.get("collide", true))
	if mesh:
		var material := mesh.material_override as StandardMaterial3D
		if material:
			var transparency := clampf(float(entity.get("transparency", 0.0)), 0.0, 0.95)
			var color := LevelData.hex_to_color(entity.get("color", ""))
			color.a = 1.0 - transparency
			material.albedo_color = color
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if transparency > 0.0 \
				else BaseMaterial3D.TRANSPARENCY_DISABLED


func _on_position_changed(_value := 0.0) -> void:
	_edit_vector_field("position", _pos_spins, "pos")


func _on_rotation_changed(_value := 0.0) -> void:
	_edit_vector_field("rotation", _rot_spins, "rot")


func _on_size_changed(_value := 0.0) -> void:
	_edit_vector_field("size", _size_spins, "size")


func _edit_vector_field(field: String, spins: Array[SpinBox], key: String) -> void:
	var entity := selected_entity()
	if entity.is_empty():
		return
	_push_undo_coalesced("%s:%s" % [key, selected_id])
	entity[field] = [spins[0].value, spins[1].value, spins[2].value]
	_apply_live(entity)
	_mark_dirty()


func _on_color_changed(color: Color) -> void:
	var entity := selected_entity()
	if entity.is_empty():
		return
	_push_undo_coalesced("color:%s" % selected_id)
	entity["color"] = LevelData.color_to_hex(color)
	_apply_live(entity)
	_mark_dirty()


func _on_transparency_changed(value: float) -> void:
	var entity := selected_entity()
	if entity.is_empty():
		return
	_push_undo_coalesced("alpha:%s" % selected_id)
	entity["transparency"] = snappedf(value, 0.01)
	_apply_live(entity)
	_mark_dirty()


func _on_anchored_toggled(pressed: bool) -> void:
	var entity := selected_entity()
	if entity.is_empty() or bool(entity.get("anchored", true)) == pressed:
		return
	_push_undo()
	entity["anchored"] = pressed
	_schedule_rebuild()
	_mark_dirty()


func _on_collide_toggled(pressed: bool) -> void:
	var entity := selected_entity()
	if entity.is_empty() or bool(entity.get("collide", true)) == pressed:
		return
	_push_undo()
	entity["collide"] = pressed
	_apply_live(entity)
	_mark_dirty()


func _on_name_submitted(text: String) -> void:
	var entity := selected_entity()
	if entity.is_empty():
		return
	var clean := text.strip_edges().left(LevelData.MAX_NAME_LENGTH)
	if clean == "" or (clean != str(entity.get("name", "")) and _name_exists(clean)):
		_status.text = "Nome non valido o già in uso."
		_name_edit.text = str(entity.get("name", ""))
		return
	if clean == str(entity.get("name", "")):
		return
	_push_undo()
	entity["name"] = clean
	var node := _find_node(str(entity.get("id", "")))
	if node:
		node.name = clean
	_refresh_explorer()
	_mark_dirty()


func _name_exists(entity_name: String) -> bool:
	for entity in data.get("parts", []):
		if typeof(entity) == TYPE_DICTIONARY and str(entity.get("name", "")) == entity_name:
			return true
	return false


func _on_moving_changed(_value := 0.0) -> void:
	var entity := selected_entity()
	if entity.is_empty() or str(entity.get("kind", "")) != "moving_platform":
		return
	_push_undo_coalesced("moving:%s" % selected_id)
	var offset := Vector3(
		_moving_offset_spins[0].value, _moving_offset_spins[1].value, _moving_offset_spins[2].value
	)
	var duration := _moving_duration.value
	entity["props"] = {"offset": LevelData.vec3_array(offset), "duration": snappedf(duration, 0.001)}
	_apply_live(entity)
	_mark_dirty()


func _on_spinner_changed(_value := 0.0) -> void:
	var entity := selected_entity()
	if entity.is_empty() or str(entity.get("kind", "")) != "spinner":
		return
	_push_undo_coalesced("spinner:%s" % selected_id)
	entity["props"] = {"speed": snappedf(_spinner_speed.value, 0.001)}
	_apply_live(entity)
	_mark_dirty()


func _on_label_changed(_value := "") -> void:
	var entity := selected_entity()
	if entity.is_empty() or str(entity.get("kind", "")) != "label":
		return
	_push_undo_coalesced("label:%s" % selected_id)
	var props: Dictionary = entity.get("props", {})
	props["text"] = _label_text.text.left(LevelData.MAX_LABEL_LENGTH)
	props["pixel_size"] = snappedf(_label_pixel.value, 0.000001)
	if not props.has("font_size"):
		props["font_size"] = 96.0
	entity["props"] = props
	_apply_live(entity)
	_mark_dirty()


# --- Operazioni -------------------------------------------------------------------

func new_level() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	selected_id = ""
	data = LevelData.new_level()
	_rebuild()
	_refresh_properties()
	_status.text = "Nuovo livello."
	_mark_dirty()


func add_entity(kind: String, position: Vector3) -> String:
	if not LevelData.kind_is_valid(kind):
		return ""
	_push_undo()
	var parts: Array = data["parts"]
	var entity := LevelData.make_entity(
		kind,
		LevelData.next_name(parts, str(KIND_BASE_NAMES.get(kind, "Parte"))),
		position,
		DEFAULT_SIZES[kind],
		DEFAULT_COLORS[kind]
	)
	entity["id"] = LevelData.next_id(parts)
	entity["props"] = _default_props(kind)
	parts.append(entity)
	_mark_dirty()
	_rebuild()
	select_entity(str(entity["id"]))
	return str(entity["id"])


func duplicate_selected() -> bool:
	var entity := selected_entity()
	if entity.is_empty():
		return false
	var parts: Array = data["parts"]
	_push_undo()
	var copy: Dictionary = entity.duplicate(true)
	copy["id"] = LevelData.next_id(parts)
	copy["name"] = LevelData.next_name(parts, str(entity.get("name", "Parte")))
	var position := LevelData.array_to_vec3(copy.get("position", []))
	position += Vector3(grid_step * 2.0, 0.0, grid_step * 2.0)
	copy["position"] = LevelData.vec3_array(position)
	var insert_at := parts.size()
	for i in parts.size():
		if str(parts[i].get("id", "")) == selected_id:
			insert_at = i + 1
			break
	parts.insert(insert_at, copy)
	_mark_dirty()
	_rebuild()
	select_entity(str(copy["id"]))
	return true


func delete_selected() -> bool:
	if selected_entity().is_empty():
		return false
	_push_undo()
	var parts: Array = data["parts"]
	for i in parts.size():
		if str(parts[i].get("id", "")) == selected_id:
			parts.remove_at(i)
			break
	selected_id = ""
	_mark_dirty()
	_rebuild()
	_refresh_properties()
	return true


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append(data.duplicate(true))
	data = _undo_stack.pop_back()
	_after_history_change()
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_undo_stack.append(data.duplicate(true))
	data = _redo_stack.pop_back()
	_after_history_change()
	return true


func _after_history_change() -> void:
	if selected_entity().is_empty():
		selected_id = ""
	_rebuild()
	_refresh_properties()
	_mark_dirty()


func _default_props(kind: String) -> Dictionary:
	match kind:
		"moving_platform":
			return {"offset": [8.0, 0.0, 0.0], "duration": 4.0}
		"spinner":
			return {"speed": 90.0}
		"kill":
			return {"mesh_offset": [0.0, -1.5, 0.0]}
		"label":
			return {"text": "Testo", "font_size": 96.0, "pixel_size": 0.012}
	return {}


func _push_undo(break_coalesce := true) -> void:
	_undo_stack.append(data.duplicate(true))
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()
	if break_coalesce:
		_undo_key = ""
		_undo_time = 0


func _push_undo_coalesced(key: String) -> void:
	var now := Time.get_ticks_msec()
	if key == _undo_key and now - _undo_time < COALESCE_MS:
		_undo_time = now
		return
	_push_undo(false)
	_undo_key = key
	_undo_time = now


func _mark_dirty() -> void:
	if _autosave_timer:
		_autosave_timer.start()


func _write_autosave() -> void:
	if data.is_empty():
		return
	LevelIO.save_to_path(AUTOSAVE_PATH, data)


# --- File ------------------------------------------------------------------------

func _open_file_pressed() -> void:
	_status.text = "Scegli il file del livello…"
	var text := await _file_io.choose_open_file("Apri un livello RobloxWeb")
	if text == "":
		_status.text = "Apertura annullata."
		return
	var parsed := LevelIO.from_json(text)
	if parsed.is_empty():
		_status.text = "File non valido: JSON non leggibile."
		return
	var errors := LevelData.validate(parsed)
	if not errors.is_empty():
		_status.text = "File non valido: " + errors[0]
		return
	_push_undo()
	data = parsed
	selected_id = ""
	_rebuild()
	_refresh_properties()
	_mark_dirty()
	_status.text = "Livello aperto: %s" % LevelData.title(data)


func _save_file_pressed() -> void:
	var file_name := "%s.rwl.json" % LevelData.slug(LevelData.title(data))
	var ok := await _file_io.save_text_file(LevelIO.to_json(data), file_name)
	_status.text = "Livello salvato: %s" % file_name if ok else "Salvataggio annullato."


func _test_play() -> void:
	_write_autosave()
	LevelData.play_request = data.duplicate(true)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _exit_editor() -> void:
	_write_autosave()
	if _studio_mode():
		get_tree().change_scene_to_file(STUDIO_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _studio_mode() -> bool:
	return StudioSession.is_studio_build()


func _coming_soon() -> void:
	_status.text = "Gli script arrivano con la milestone M3."


# --- Pubblicazione (M1) -------------------------------------------------------------

func _open_server_window() -> void:
	_build_server_window()
	_load_publish_settings()
	var meta := _meta()
	_publish_title_edit.text = LevelData.title(data)
	_publish_description.text = str(meta.get("description", ""))
	_select_visibility(str(meta.get("visibility", "public")))
	_update_target_label()
	_update_account_ui()
	_server_window.popup_centered()
	_refresh_thumbnail_preview()
	if _publish_client.is_logged_in():
		_refresh_places()


func _open_my_places() -> void:
	_open_server_window()
	_account_tabs.current_tab = 1


func _meta() -> Dictionary:
	var value = data.get("meta", {})
	if typeof(value) != TYPE_DICTIONARY:
		value = {}
		data["meta"] = value
	return value


func _update_target_label() -> void:
	if _target_label == null:
		return
	var meta := _meta()
	var place_id := int(meta.get("place_id", 0))
	if place_id > 0:
		_target_label.text = "Aggiornerà l'esperienza #%d (versione %d)." % [
			place_id, int(meta.get("published_version", 0))
		]
	else:
		_target_label.text = "Verrà creata una nuova esperienza."


func _build_server_window() -> void:
	if _server_window != null:
		return
	_server_window = Window.new()
	_server_window.name = "PublishWindow"
	_server_window.title = "RobloxWeb — Pubblica esperienza"
	_server_window.size = Vector2i(620, 700)
	_server_window.min_size = Vector2i(520, 560)
	_server_window.visible = false
	_server_window.close_requested.connect(func() -> void: _server_window.hide())
	add_child(_server_window)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_server_window.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var account_title := Label.new()
	account_title.text = "Account"
	account_title.add_theme_font_size_override("font_size", 16)
	root.add_child(account_title)

	var server_row := HBoxContainer.new()
	var server_label := _make_field_label("Server")
	server_row.add_child(server_label)
	_server_url_edit = LineEdit.new()
	_server_url_edit.text = _publish_client.base_url
	_server_url_edit.placeholder_text = "http://127.0.0.1:9080"
	_server_url_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(_server_url_edit)
	root.add_child(server_row)

	var login_row := HBoxContainer.new()
	login_row.add_child(_make_field_label("Credenziali"))
	_account_user_edit = LineEdit.new()
	_account_user_edit.placeholder_text = "Username"
	_account_user_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	login_row.add_child(_account_user_edit)
	_account_pass_edit = LineEdit.new()
	_account_pass_edit.placeholder_text = "Password"
	_account_pass_edit.secret = true
	_account_pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_account_pass_edit.text_submitted.connect(func(_text: String) -> void: _on_account_pressed())
	login_row.add_child(_account_pass_edit)
	_account_button = Button.new()
	_account_button.text = "Accedi"
	_account_button.custom_minimum_size.x = 90
	_account_button.pressed.connect(_on_account_pressed)
	login_row.add_child(_account_button)
	root.add_child(login_row)

	_account_status = Label.new()
	_account_status.add_theme_font_size_override("font_size", 12)
	_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_account_status)

	root.add_child(HSeparator.new())

	_account_tabs = TabContainer.new()
	_account_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_account_tabs)

	# --- tab Pubblica ---
	var publish_tab := VBoxContainer.new()
	publish_tab.name = "Pubblica"
	publish_tab.add_theme_constant_override("separation", 6)
	_account_tabs.add_child(publish_tab)

	_target_label = Label.new()
	_target_label.add_theme_font_size_override("font_size", 13)
	_target_label.add_theme_color_override("font_color", Color(0.70, 0.78, 0.90))
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	publish_tab.add_child(_target_label)

	publish_tab.add_child(_make_field_label("Titolo"))
	_publish_title_edit = LineEdit.new()
	_publish_title_edit.max_length = LevelData.MAX_TITLE_LENGTH
	_publish_title_edit.placeholder_text = "Nome dell'esperienza"
	publish_tab.add_child(_publish_title_edit)

	publish_tab.add_child(_make_field_label("Descrizione"))
	_publish_description = TextEdit.new()
	_publish_description.custom_minimum_size = Vector2(0, 90)
	_publish_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	publish_tab.add_child(_publish_description)

	publish_tab.add_child(_make_field_label("Visibilità"))
	_visibility_option = OptionButton.new()
	_visibility_option.add_item("Pubblica — visibile nel catalogo", 0)
	_visibility_option.add_item("Non elencata — solo con il link", 1)
	_visibility_option.add_item("Privata — solo per te", 2)
	publish_tab.add_child(_visibility_option)

	_thumbnail_check = CheckBox.new()
	_thumbnail_check.text = "Aggiorna la thumbnail dalla vista attuale"
	_thumbnail_check.button_pressed = true
	publish_tab.add_child(_thumbnail_check)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 10)
	publish_tab.add_child(preview_row)
	_thumbnail_preview = TextureRect.new()
	_thumbnail_preview.custom_minimum_size = Vector2(256, 144)
	_thumbnail_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumbnail_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumbnail_preview.texture = null
	preview_row.add_child(_thumbnail_preview)
	var preview_side := VBoxContainer.new()
	preview_side.add_theme_constant_override("separation", 6)
	preview_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_row.add_child(preview_side)
	_thumbnail_preview_button = Button.new()
	_thumbnail_preview_button.text = "Aggiorna anteprima"
	_thumbnail_preview_button.pressed.connect(_refresh_thumbnail_preview)
	preview_side.add_child(_thumbnail_preview_button)
	_thumbnail_preview_status = Label.new()
	_thumbnail_preview_status.add_theme_font_size_override("font_size", 12)
	_thumbnail_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_side.add_child(_thumbnail_preview_status)

	var publish_actions := HBoxContainer.new()
	publish_actions.add_theme_constant_override("separation", 8)
	publish_tab.add_child(publish_actions)
	var publish_spacer := Control.new()
	publish_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	publish_actions.add_child(publish_spacer)
	var close_button := Button.new()
	close_button.text = "Chiudi"
	close_button.pressed.connect(func() -> void: _server_window.hide())
	publish_actions.add_child(close_button)
	_publish_button = Button.new()
	_publish_button.text = "Pubblica"
	_publish_button.pressed.connect(_on_publish_pressed)
	publish_actions.add_child(_publish_button)

	_publish_status = Label.new()
	_publish_status.add_theme_font_size_override("font_size", 13)
	_publish_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	publish_tab.add_child(_publish_status)

	# --- tab Le mie place ---
	var places_tab := VBoxContainer.new()
	places_tab.name = "Le mie place"
	places_tab.add_theme_constant_override("separation", 6)
	_account_tabs.add_child(places_tab)

	var places_actions := HBoxContainer.new()
	places_actions.add_theme_constant_override("separation", 8)
	places_tab.add_child(places_actions)
	var refresh_button := Button.new()
	refresh_button.text = "Aggiorna"
	refresh_button.pressed.connect(_refresh_places)
	places_actions.add_child(refresh_button)
	_places_open_button = Button.new()
	_places_open_button.text = "Apri nell'editor"
	_places_open_button.pressed.connect(_on_open_server_place)
	places_actions.add_child(_places_open_button)

	_places_list = ItemList.new()
	_places_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_places_list.item_activated.connect(func(_index: int) -> void: _on_open_server_place())
	places_tab.add_child(_places_list)

	_places_status = Label.new()
	_places_status.add_theme_font_size_override("font_size", 12)
	_places_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	places_tab.add_child(_places_status)


func _make_field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 96
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	return label


func _set_status_label(label: Label, text: String, error := false) -> void:
	if label == null:
		return
	label.text = text
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.55, 0.6) if error else Color(0.75, 0.88, 0.78)
	)


func _on_account_pressed() -> void:
	if _publish_client.is_logged_in():
		_publish_client.clear_session()
		_publish_client.base_url = _server_url_edit.text
		_places_list.clear()
		_set_status_label(_account_status, "Disconnesso.", false)
		_update_account_ui()
		return
	_account_button.disabled = true
	_set_status_label(_account_status, "Accesso in corso…", false)
	await _ensure_login()
	_account_button.disabled = false
	_update_account_ui()


func _ensure_login() -> bool:
	if _publish_client.is_logged_in():
		return true
	var username := _account_user_edit.text.strip_edges()
	var password := _account_pass_edit.text
	if username == "" or password == "":
		_set_status_label(_account_status, "Inserisci username e password.", true)
		_account_tabs.current_tab = 0
		return false
	_publish_client.base_url = _server_url_edit.text
	if not _publish_client.login(username, password):
		_set_status_label(_account_status, "Richiesta già in corso.", true)
		return false
	var result = await _publish_client.login_finished
	_update_account_ui()
	if not bool(result[0]):
		_set_status_label(_account_status, str(result[1]), true)
		return false
	_set_status_label(_account_status, str(result[1]), false)
	_save_publish_settings()
	return true


func _update_account_ui() -> void:
	if _account_button == null:
		return
	var logged := _publish_client.is_logged_in()
	_account_button.text = "Esci" if logged else "Accedi"
	_account_user_edit.editable = not logged
	_account_pass_edit.editable = not logged
	_server_url_edit.editable = not logged
	_publish_button.disabled = not logged
	_places_open_button.disabled = not logged
	_account_label.text = (
		("Account: %s" % _publish_client.display_name())
		if logged
		else "Non connesso: premi Pubblica per accedere"
	)
	if logged:
		_account_status.text = "Connesso come %s." % _publish_client.display_name()
		_account_status.add_theme_color_override("font_color", Color(0.75, 0.88, 0.78))
	_update_target_label()


func _visibility_value() -> String:
	match _visibility_option.selected:
		1:
			return "unlisted"
		2:
			return "private"
	return "public"


func _select_visibility(value: String) -> void:
	_visibility_option.select({"public": 0, "unlisted": 1, "private": 2}.get(value, 0))


func _on_publish_pressed() -> void:
	var title := _publish_title_edit.text.strip_edges()
	if title == "":
		_set_status_label(_publish_status, "Il titolo è obbligatorio.", true)
		return
	var description := _publish_description.text.strip_edges()
	var visibility := _visibility_value()
	_publish_button.disabled = true
	_set_status_label(_publish_status, "Accesso…", false)
	if not await _ensure_login():
		_publish_button.disabled = false
		return

	_set_status_label(_publish_status, "Pubblicazione in corso…", false)
	var meta: Dictionary = data.get("meta", {}) if typeof(data.get("meta")) == TYPE_DICTIONARY else {}
	var place_id := int(meta.get("place_id", 0))

	var png := PackedByteArray()
	if _thumbnail_check.button_pressed:
		png = await _capture_thumbnail()

	if not _publish_client.publish(place_id, title, description, visibility, data):
		_set_status_label(_publish_status, "Richiesta già in corso.", true)
		_publish_button.disabled = false
		return
	var result = await _publish_client.published
	if not bool(result[0]):
		_set_status_label(_publish_status, str(result[1]), true)
		_publish_button.disabled = false
		if not _publish_client.is_logged_in():
			_update_account_ui()
		return
	var place: Dictionary = result[2]
	var version := int(result[3])
	var new_id := int(place.get("id", place_id))
	var url := "%s/place.html?id=%d" % [_publish_client.base_url, new_id]

	meta["place_id"] = new_id
	meta["title"] = title
	meta["description"] = description
	meta["visibility"] = visibility
	meta["published_version"] = version
	if _publish_client.display_name() != "":
		meta["author"] = _publish_client.display_name()
	data["meta"] = meta
	_update_target_label()
	_mark_dirty()
	_write_autosave()

	var note := "Pubblicata v%d: %s" % [version, url]
	if not png.is_empty():
		_set_status_label(_publish_status, note + "\nCaricamento thumbnail…", false)
		if _publish_client.upload_thumbnail(new_id, png):
			var thumb = await _publish_client.thumbnail_uploaded
			if not bool(thumb[0]):
				note += "\nThumbnail non caricata: " + str(thumb[1])
	_set_status_label(_publish_status, note, false)
	_status.text = "Pubblicata v%d (place #%d)." % [version, new_id]
	_publish_button.disabled = false
	_refresh_places()


func _refresh_thumbnail_preview() -> void:
	if _thumbnail_preview == null:
		return
	if _thumbnail_preview_button:
		_thumbnail_preview_button.disabled = true
	if _thumbnail_preview_status:
		_thumbnail_preview_status.text = "Cattura della vista…"
	var png := await _capture_thumbnail()
	if png.is_empty():
		_thumbnail_preview.texture = null
		if _thumbnail_preview_status:
			_thumbnail_preview_status.text = "Anteprima non disponibile (renderer non attivo)."
	else:
		var image := Image.new()
		if image.load_png_from_buffer(png) == OK:
			_thumbnail_preview.texture = ImageTexture.create_from_image(image)
			if _thumbnail_preview_status:
				_thumbnail_preview_status.text = "Anteprima %d×%d pronta." % [
					image.get_width(), image.get_height()
				]
		else:
			_thumbnail_preview.texture = null
			if _thumbnail_preview_status:
				_thumbnail_preview_status.text = "Impossibile leggere il PNG catturato."
	if _thumbnail_preview_button:
		_thumbnail_preview_button.disabled = false


func _capture_thumbnail() -> PackedByteArray:
	## Renderizza la vista attuale in un SubViewport 512x288 che condivide il
	## World3D dell'editor e la converte in PNG.
	## Best-effort: in headless o se il renderer non è pronto ritorna un buffer vuoto.
	if DisplayServer.get_name() == "headless":
		return PackedByteArray()
	var viewport := SubViewport.new()
	viewport.size = THUMBNAIL_SIZE
	viewport.world_3d = get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var snapshot_camera := Camera3D.new()
	snapshot_camera.fov = camera.fov
	snapshot_camera.near = camera.near
	snapshot_camera.far = camera.far
	viewport.add_child(snapshot_camera)
	snapshot_camera.global_transform = camera.global_transform
	snapshot_camera.current = true
	var highlight_was_visible := _highlight != null and _highlight.visible
	if _highlight:
		_highlight.visible = false
	await RenderingServer.frame_post_draw
	if _highlight:
		_highlight.visible = highlight_was_visible
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		return PackedByteArray()
	if image.get_width() != THUMBNAIL_SIZE.x or image.get_height() != THUMBNAIL_SIZE.y:
		image.resize(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return image.save_png_to_buffer()


func _refresh_places() -> void:
	if _places_list == null or not _publish_client.is_logged_in():
		return
	_set_status_label(_places_status, "Caricamento delle tue esperienze…", false)
	if not _publish_client.fetch_places():
		_set_status_label(_places_status, "Richiesta già in corso.", true)
		return
	var result = await _publish_client.places_loaded
	if not bool(result[0]):
		_set_status_label(_places_status, str(result[1]), true)
		return
	_places_list.clear()
	var items: Array = result[2]
	for place in items:
		if typeof(place) != TYPE_DICTIONARY:
			continue
		var index := _places_list.add_item(
			"[v%d] %s · %s" % [
				int(place.get("current_version", 0)),
				str(place.get("title", "?")),
				str(place.get("visibility", "public")),
			]
		)
		_places_list.set_item_metadata(index, int(place.get("id", 0)))
	_set_status_label(
		_places_status,
		"Premi due volte una place (o Apri nell'editor) per caricarla." if not items.is_empty()
		else "Non hai ancora pubblicato esperienze.",
		false
	)


func _on_open_server_place() -> void:
	var selected := _places_list.get_selected_items()
	if selected.is_empty():
		_set_status_label(_places_status, "Seleziona una place dall'elenco.", true)
		return
	var place_id := int(_places_list.get_item_metadata(selected[0]))
	_places_open_button.disabled = true
	_set_status_label(_places_status, "Download del livello…", false)
	if not _publish_client.fetch_level(place_id):
		_places_open_button.disabled = false
		return
	var result = await _publish_client.level_loaded
	_places_open_button.disabled = false
	if not bool(result[0]):
		_set_status_label(_places_status, str(result[1]), true)
		return
	var place: Dictionary = result[2]
	var level: Dictionary = result[3]
	var errors := LevelData.validate(level)
	if not errors.is_empty():
		_set_status_label(_places_status, "Livello non valido: " + errors[0], true)
		return
	_push_undo()
	data = level
	var meta: Dictionary = data.get("meta", {}) if typeof(data.get("meta")) == TYPE_DICTIONARY else {}
	meta["place_id"] = place_id
	meta["published_version"] = int(place.get("current_version", 0))
	meta["title"] = str(place.get("title", LevelData.title(data)))
	meta["description"] = str(place.get("description", ""))
	meta["visibility"] = str(place.get("visibility", "public"))
	if _publish_client.display_name() != "":
		meta["author"] = _publish_client.display_name()
	data["meta"] = meta
	selected_id = ""
	_rebuild()
	_refresh_properties()
	_mark_dirty()
	_publish_title_edit.text = str(place.get("title", LevelData.title(data)))
	_publish_description.text = str(place.get("description", ""))
	_select_visibility(str(place.get("visibility", "public")))
	_update_target_label()
	_server_window.hide()
	_status.text = "Aperta dal server: %s (v%d)." % [
		str(place.get("title", "")), int(place.get("current_version", 0))
	]


func _load_publish_settings() -> void:
	var stored := LevelIO.load_from_path(PUBLISH_SETTINGS_PATH)
	if stored.is_empty():
		return
	var server_url := str(stored.get("server_url", "")).strip_edges()
	if server_url != "":
		_server_url_edit.text = server_url
		_publish_client.base_url = server_url
	var username := str(stored.get("username", "")).strip_edges()
	if username != "" and _account_user_edit.text == "":
		_account_user_edit.text = username


func _save_publish_settings() -> void:
	var payload := {
		"server_url": _publish_client.base_url,
		"username": _account_user_edit.text.strip_edges(),
	}
	LevelIO.save_to_path(PUBLISH_SETTINGS_PATH, payload)


# --- Input e piazzamento ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _server_window != null and _server_window.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_world_click(event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_cancel_placement()
				get_viewport().set_input_as_handled()
			KEY_DELETE:
				delete_selected()
				get_viewport().set_input_as_handled()
			KEY_D:
				if event.ctrl_pressed:
					duplicate_selected()
					get_viewport().set_input_as_handled()
			KEY_Z:
				if event.ctrl_pressed:
					if event.shift_pressed:
						redo()
					else:
						undo()
					get_viewport().set_input_as_handled()
			KEY_Y:
				if event.ctrl_pressed:
					redo()
					get_viewport().set_input_as_handled()


func _on_world_click(mouse_position: Vector2) -> void:
	if placing_kind != "":
		add_entity(placing_kind, _compute_placement_point(placing_kind, mouse_position))
	else:
		select_entity(_pick_entity_id(mouse_position))


func _pick_entity_id(mouse_position: Vector2) -> String:
	var space := get_world_3d().direct_space_state
	var from := camera.project_ray_origin(mouse_position)
	var to := from + camera.project_ray_normal(mouse_position) * 4000.0
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return ""
	var node: Node = hit.get("collider")
	while node != null and node != self:
		if node.has_meta("level_id"):
			return str(node.get_meta("level_id"))
		node = node.get_parent()
	return ""


func _compute_placement_point(kind: String, mouse_position: Vector2) -> Vector3:
	var size: Vector3 = DEFAULT_SIZES[kind]
	var from := camera.project_ray_origin(mouse_position)
	var direction := camera.project_ray_normal(mouse_position)
	var params := PhysicsRayQueryParameters3D.create(from, from + direction * 4000.0)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	var point: Vector3
	if not hit.is_empty():
		var normal: Vector3 = hit.get("normal", Vector3.UP)
		var offset := size.y * 0.5 if normal.y >= 0.5 else maxf(size.x, size.z) * 0.5
		point = hit.get("position", Vector3.ZERO) + normal * offset
	else:
		if absf(direction.y) > 0.0001:
			point = from + direction * maxf(-from.y / direction.y, 10.0)
		else:
			point = from + direction * 30.0
		point.y = size.y * 0.5
	return _snap_point(point)


func _snap_point(point: Vector3) -> Vector3:
	if not snap_enabled:
		return point
	return Vector3(
		snappedf(point.x, grid_step), snappedf(point.y, grid_step), snappedf(point.z, grid_step)
	)


func _cancel_placement() -> void:
	placing_kind = ""
	for button in _palette_buttons.values():
		(button as Button).set_pressed_no_signal(false)
	_status.text = "Pronto."


func _on_palette_toggled(pressed: bool, kind: String) -> void:
	if pressed:
		placing_kind = kind
		for other in _palette_buttons:
			if other != kind:
				(_palette_buttons[other] as Button).set_pressed_no_signal(false)
		_status.text = "Piazzamento: %s — click nel mondo (Esc per uscire)." % KIND_LABELS[kind]
	elif placing_kind == kind:
		placing_kind = ""
		_status.text = "Pronto."


func _cycle_grid() -> void:
	var steps := [0.5, 1.0, 2.0, 4.0]
	var index := steps.find(grid_step)
	grid_step = steps[(index + 1) % steps.size()]
	_grid_button.text = "Griglia: %s" % str(grid_step)


func _toggle_snap() -> void:
	snap_enabled = not snap_enabled
	var button := _find_child_button("SnapButton")
	if button:
		button.text = "Snap: ON" if snap_enabled else "Snap: OFF"


func _toggle_simulate() -> void:
	simulate = not simulate
	_rebuild()
	_status.text = "Simulazione attiva." if simulate else "Simulazione in pausa."


func _find_child_button(button_name: String) -> Button:
	var found := ui.find_child(button_name, true, false)
	return found as Button
