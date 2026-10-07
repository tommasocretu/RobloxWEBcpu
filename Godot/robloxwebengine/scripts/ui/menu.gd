class_name MainMenu
extends CanvasLayer
## Menu iniziale: nome giocatore + Play (col mouse oppure Invio/Spazio).

signal play_pressed

@onready var play_button: Button = $Center/VBox/PlayButton
@onready var name_input: LineEdit = $Center/VBox/NameInput


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	name_input.text = "Giocatore%d" % randi_range(10, 99)
	name_input.text_submitted.connect(_on_name_submitted)
	play_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER and not name_input.has_focus():
		_on_play_pressed()
		get_viewport().set_input_as_handled()


func player_name() -> String:
	var value := name_input.text.strip_edges()
	return value if value != "" else "Giocatore"


func _on_name_submitted(_text: String) -> void:
	_on_play_pressed()


func _on_play_pressed() -> void:
	if not visible:
		return
	play_pressed.emit()
