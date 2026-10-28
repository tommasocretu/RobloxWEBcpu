class_name StudioStart
extends Control
## Schermata iniziale di RobloxWeb Studio (M2): account, URL del server,
## elenco delle proprie place e accesso all'editor (nuovo livello, file o
## download dell'ultima versione pubblicata).

const EDITOR_SCENE_PATH := "res://scenes/editor/editor.tscn"
const SETTINGS_PATH := PublishClient.PUBLISH_SETTINGS_PATH

var _publish_client: PublishClient
var _file_io: LevelFileIO

var _server_url_edit: LineEdit
var _account_user_edit: LineEdit
var _account_pass_edit: LineEdit
var _login_button: Button
var _account_status: Label
var _places_list: ItemList
var _places_status: Label
var _refresh_button: Button
var _open_button: Button
var _new_button: Button
var _file_button: Button
var _offline_button: Button
var _quit_button: Button


func _ready() -> void:
	DisplayServer.window_set_title("RobloxWeb Studio")
	_publish_client = PublishClient.new()
	_publish_client.name = "PublishClient"
	_publish_client.base_url = PublishClient.default_base_url()
	add_child(_publish_client)
	_file_io = LevelFileIO.new()
	_file_io.name = "LevelFileIO"
	add_child(_file_io)

	_build_ui()
	_load_settings()
	if _publish_client.restore_session():
		_server_url_edit.text = _publish_client.base_url
		if _account_user_edit.text == "":
			_account_user_edit.text = str(_publish_client.user.get("username", ""))
		_update_account_ui()
		_refresh_places()
	else:
		_update_account_ui()
	print("STUDIO_READY")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()
		if _publish_client.is_logged_in():
			_publish_client.save_session()


# --- UI ---------------------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.045, 0.06, 0.09)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := Label.new()
	title.text = "RobloxWeb Studio"
	title.add_theme_font_size_override("font_size", 34)
	titles.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Crea, testa e pubblica le tue esperienze."
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.70, 0.82))
	titles.add_child(subtitle)
	_quit_button = _make_button("Esci", "Chiudi Studio")
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	header.add_child(_quit_button)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	content.add_child(_build_account_panel())
	content.add_child(_build_places_panel())


func _build_account_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 380
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Account"
	heading.add_theme_font_size_override("font_size", 20)
	box.add_child(heading)

	box.add_child(_field_label("Server"))
	_server_url_edit = LineEdit.new()
	_server_url_edit.placeholder_text = PublishClient.DEFAULT_BASE_URL
	_server_url_edit.text = _publish_client.base_url
	box.add_child(_server_url_edit)

	box.add_child(_field_label("Username"))
	_account_user_edit = LineEdit.new()
	_account_user_edit.placeholder_text = "Il tuo username"
	box.add_child(_account_user_edit)

	box.add_child(_field_label("Password"))
	_account_pass_edit = LineEdit.new()
	_account_pass_edit.placeholder_text = "Password"
	_account_pass_edit.secret = true
	_account_pass_edit.text_submitted.connect(
		func(_text: String) -> void: _on_login_pressed()
	)
	box.add_child(_account_pass_edit)

	_login_button = _make_button("Accedi", "Accedi con l'account del sito")
	_login_button.pressed.connect(_on_login_pressed)
	box.add_child(_login_button)

	_account_status = Label.new()
	_account_status.add_theme_font_size_override("font_size", 13)
	_account_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_account_status)

	box.add_child(HSeparator.new())

	var editor_heading := Label.new()
	editor_heading.text = "Editor"
	editor_heading.add_theme_font_size_override("font_size", 20)
	box.add_child(editor_heading)

	_new_button = _make_button("Nuova esperienza", "Crea un livello vuoto")
	_new_button.pressed.connect(_open_new)
	box.add_child(_new_button)

	_file_button = _make_button("Apri file…", "Apri un livello .rwl.json dal disco")
	_file_button.pressed.connect(_open_file)
	box.add_child(_file_button)

	_offline_button = _make_button(
		"Continua offline (autosave)", "Riprendi il livello salvato automaticamente"
	)
	_offline_button.pressed.connect(_open_offline)
	box.add_child(_offline_button)

	var hint := Label.new()
	hint.text = "Puoi lavorare offline: per pubblicare serve un account."
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	return panel


func _build_places_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 10)
	box.add_child(heading_row)
	var heading := Label.new()
	heading.text = "Le mie place"
	heading.add_theme_font_size_override("font_size", 20)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	_refresh_button = _make_button("Aggiorna", "Ricarica l'elenco dal server")
	_refresh_button.pressed.connect(_refresh_places)
	heading_row.add_child(_refresh_button)

	_places_list = ItemList.new()
	_places_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_places_list.item_activated.connect(func(_index: int) -> void: _on_open_place_pressed())
	box.add_child(_places_list)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	_open_button = _make_button("Apri nell'editor", "Scarica l'ultima versione e aprila")
	_open_button.pressed.connect(_on_open_place_pressed)
	actions.add_child(_open_button)

	_places_status = Label.new()
	_places_status.add_theme_font_size_override("font_size", 13)
	_places_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_places_status)
	return panel


func _make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 14)
	return button


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.85))
	return label


func _set_status(label: Label, text: String, error := false) -> void:
	if label == null:
		return
	label.text = text
	label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.55, 0.6) if error else Color(0.75, 0.88, 0.78)
	)


# --- Account ----------------------------------------------------------------------

func _on_login_pressed() -> void:
	if _publish_client.is_logged_in():
		_publish_client.clear_session()
		_places_list.clear()
		_update_account_ui()
		_set_status(_account_status, "Disconnesso.", false)
		_set_status(_places_status, "Accedi per vedere le tue esperienze.", false)
		_save_settings()
		return

	var username := _account_user_edit.text.strip_edges()
	var password := _account_pass_edit.text
	if username == "" or password == "":
		_set_status(_account_status, "Inserisci username e password.", true)
		return

	_publish_client.base_url = _publish_client.normalize_base_url(_server_url_edit.text)
	_server_url_edit.text = _publish_client.base_url
	_login_button.disabled = true
	_set_status(_account_status, "Accesso in corso…", false)
	if not _publish_client.login(username, password):
		_login_button.disabled = false
		_set_status(_account_status, "Richiesta già in corso.", true)
		return
	var result = await _publish_client.login_finished
	_login_button.disabled = false
	if not bool(result[0]):
		_update_account_ui()
		_set_status(_account_status, str(result[1]), true)
		return
	_save_settings()
	_publish_client.save_session()
	_update_account_ui()
	_set_status(_account_status, str(result[1]), false)
	_refresh_places()


func _update_account_ui() -> void:
	if _login_button == null:
		return
	var logged := _publish_client.is_logged_in()
	_login_button.text = "Esci" if logged else "Accedi"
	_account_user_edit.editable = not logged
	_account_pass_edit.editable = not logged
	_server_url_edit.editable = not logged
	_refresh_button.disabled = not logged
	_open_button.disabled = not logged
	if logged:
		_set_status(
			_account_status,
			"Connesso come %s." % _publish_client.display_name(),
			false
		)
	else:
		_set_status(_account_status, "Non connesso.", false)
	if not logged and _places_list != null and _places_list.item_count == 0:
		_set_status(_places_status, "Accedi per vedere le tue esperienze.", false)


# --- Place -------------------------------------------------------------------------

func _refresh_places() -> void:
	if not _publish_client.is_logged_in():
		_places_list.clear()
		_set_status(_places_status, "Accedi per vedere le tue esperienze.", false)
		return
	_refresh_button.disabled = true
	_set_status(_places_status, "Caricamento delle tue esperienze…", false)
	if not _publish_client.fetch_places():
		_refresh_button.disabled = false
		_set_status(_places_status, "Richiesta già in corso.", true)
		return
	var result = await _publish_client.places_loaded
	_refresh_button.disabled = false
	if not _publish_client.is_logged_in():
		_places_list.clear()
		_update_account_ui()
		return
	if not bool(result[0]):
		_set_status(_places_status, str(result[1]), true)
		if not _publish_client.is_logged_in():
			_update_account_ui()
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
				_visibility_label(str(place.get("visibility", "public"))),
			]
		)
		_places_list.set_item_metadata(index, int(place.get("id", 0)))
	if _places_list.item_count > 0:
		_places_list.select(0)
		_set_status(
			_places_status,
			"Seleziona una place e premi «Apri nell'editor» (o doppio click).",
			false
		)
	else:
		_set_status(_places_status, "Non hai ancora pubblicato esperienze.", false)


func _visibility_label(value: String) -> String:
	match value:
		"unlisted":
			return "non elencata"
		"private":
			return "privata"
	return "pubblica"


func _on_open_place_pressed() -> void:
	var selected := _places_list.get_selected_items()
	if selected.is_empty():
		_set_status(_places_status, "Seleziona una place dall'elenco.", true)
		return
	var place_id := int(_places_list.get_item_metadata(selected[0]))
	_open_button.disabled = true
	var opened := await _load_place_into_session(place_id)
	_open_button.disabled = false
	if opened:
		_leave_to_editor()


## Scarica l'ultima versione e la prepara per l'editor. Separata dal pulsante
## per poter essere testata senza cambiare scena.
func _load_place_into_session(place_id: int) -> bool:
	_set_status(_places_status, "Download del livello…", false)
	if not _publish_client.fetch_level(place_id):
		_set_status(_places_status, "Richiesta già in corso.", true)
		return false
	var result = await _publish_client.level_loaded
	if not bool(result[0]):
		_set_status(_places_status, str(result[1]), true)
		if not _publish_client.is_logged_in():
			_update_account_ui()
		return false
	var place: Dictionary = result[2]
	var level: Dictionary = result[3]
	var errors := LevelData.validate(level)
	if not errors.is_empty():
		_set_status(_places_status, "Livello non valido: " + errors[0], true)
		return false
	var meta: Dictionary = level.get("meta", {}) if typeof(level.get("meta")) == TYPE_DICTIONARY else {}
	meta["place_id"] = place_id
	meta["published_version"] = int(place.get("current_version", 0))
	meta["title"] = str(place.get("title", LevelData.title(level)))
	meta["description"] = str(place.get("description", ""))
	meta["visibility"] = str(place.get("visibility", "public"))
	if _publish_client.display_name() != "":
		meta["author"] = _publish_client.display_name()
	level["meta"] = meta
	StudioSession.set_pending(level, "Aperta dal server: %s (v%d)." % [
		str(place.get("title", "")), int(place.get("current_version", 0))
	])
	_set_status(_places_status, "Livello pronto.", false)
	return true


# --- Editor ------------------------------------------------------------------------

func _open_new() -> void:
	StudioSession.set_pending(LevelData.new_level("Nuova esperienza"), "Nuovo livello.")
	_leave_to_editor()


func _open_file() -> void:
	_set_status(_account_status, "Scegli il file del livello…", false)
	var text := await _file_io.choose_open_file("Apri un livello RobloxWeb")
	if text == "":
		_set_status(_account_status, "Apertura annullata.", false)
		return
	var parsed := LevelIO.from_json(text)
	if parsed.is_empty():
		_set_status(_account_status, "File non valido: JSON non leggibile.", true)
		return
	var errors := LevelData.validate(parsed)
	if not errors.is_empty():
		_set_status(_account_status, "File non valido: " + errors[0], true)
		return
	StudioSession.set_pending(parsed, "Livello aperto: %s" % LevelData.title(parsed))
	_leave_to_editor()


func _open_offline() -> void:
	StudioSession.clear_pending()
	_leave_to_editor()


func _leave_to_editor() -> void:
	_save_settings()
	if _publish_client.is_logged_in():
		_publish_client.save_session()
	var error := get_tree().change_scene_to_file(EDITOR_SCENE_PATH)
	if error != OK:
		StudioSession.clear_pending()
		_set_status(_account_status, "Impossibile aprire l'editor (%d)." % error, true)


# --- Impostazioni ------------------------------------------------------------------

func _load_settings() -> void:
	var stored := LevelIO.load_from_path(SETTINGS_PATH)
	if stored.is_empty():
		return
	var server_url := str(stored.get("server_url", "")).strip_edges()
	if server_url != "":
		_server_url_edit.text = server_url
		_publish_client.base_url = _publish_client.normalize_base_url(server_url)
	var username := str(stored.get("username", "")).strip_edges()
	if username != "":
		_account_user_edit.text = username


func _save_settings() -> void:
	if _server_url_edit == null:
		return
	_publish_client.base_url = _publish_client.normalize_base_url(_server_url_edit.text)
	LevelIO.save_to_path(
		SETTINGS_PATH,
		{
			"server_url": _publish_client.base_url,
			"username": _account_user_edit.text.strip_edges(),
		}
	)
