class_name LevelSelect
extends CanvasLayer
## Schermata iniziale: scegliere il livello (predefinito o da file) o aprire l'editor.

signal level_chosen(data: Dictionary, source: String)
signal editor_requested

@onready var default_button: Button = $Center/VBox/DefaultButton
@onready var load_button: Button = $Center/VBox/LoadButton
@onready var editor_button: Button = $Center/VBox/EditorButton
@onready var status_label: Label = $Center/VBox/Status

var _file_io: LevelFileIO


func _ready() -> void:
	_file_io = LevelFileIO.new()
	add_child(_file_io)
	default_button.pressed.connect(_on_default_pressed)
	load_button.pressed.connect(_on_load_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	status_label.text = ""
	if not LevelIO.has_default_level():
		default_button.disabled = true
		status_label.text = "Livello predefinito non presente nella build."
	default_button.grab_focus()


func _on_default_pressed() -> void:
	var data := LevelIO.load_default()
	if data.is_empty():
		status_label.text = "Livello predefinito non leggibile."
		return
	var errors := LevelData.validate(data)
	if not errors.is_empty():
		status_label.text = "Livello predefinito non valido: " + errors[0]
		return
	_emit_level(data, "default")


func _on_load_pressed() -> void:
	load_button.disabled = true
	status_label.text = "Scegli il file del livello…"
	var text := await _file_io.choose_open_file("Apri un livello RobloxWeb")
	load_button.disabled = false
	if text == "":
		status_label.text = "Nessun file selezionato."
		return
	var data := LevelIO.from_json(text)
	if data.is_empty():
		status_label.text = "File non valido: JSON non leggibile."
		return
	var errors := LevelData.validate(data)
	if not errors.is_empty():
		status_label.text = "File non valido: " + errors[0]
		return
	_emit_level(data, "file")


func _on_editor_pressed() -> void:
	editor_requested.emit()


func _emit_level(data: Dictionary, source: String) -> void:
	status_label.text = "Livello scelto: %s" % LevelData.title(data)
	level_chosen.emit(data, source)
