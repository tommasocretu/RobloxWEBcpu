class_name LevelEditor
extends Node3D
## Editor di livelli v1: camera libera, piazzamento a click, selezione con pannello
## proprietà, snap a griglia, duplica/elimina, undo/redo, salva/apri file,
## autosave in user:// e test-play nella scena principale.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const AUTOSAVE_PATH := "user://editor_autosave.rwl.json"
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


func _ready() -> void:
	_file_io = LevelFileIO.new()
	add_child(_file_io)
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
	top_box.add_child(VSeparator.new())
	_add_top_button(top_box, "Simula", _toggle_simulate)
	_add_top_button(top_box, "Testa", _test_play)
	_add_top_button(top_box, "Esci", _exit_editor)

	# Esploratore oggetti (sinistra).
	var left := PanelContainer.new()
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_left = 8
	left.offset_right = 218
	left.offset_top = 44
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
	right.offset_top = 44
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
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


# --- Input e piazzamento ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
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
