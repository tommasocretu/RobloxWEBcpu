class_name GameHUD
extends CanvasLayer
## HUD di gioco: mirino, barra salute, monete, messaggi, chat multiplayer e FPS.

signal chat_submitted(text: String)
signal chat_opened
signal chat_closed

const CHAT_MAX_LINES := 7
const MESSAGE_TIME := 3.0

@onready var crosshair: Control = $Crosshair
@onready var health_bar: ProgressBar = $HealthBar
@onready var coins_label: Label = $Coins
@onready var message_label: Label = $Message
@onready var fps_label: Label = $FPS
@onready var players_label: Label = $Players
@onready var chat_log: Label = $ChatLog
@onready var chat_input: LineEdit = $ChatInput

var _message_tween: Tween
var _chat_lines: Array[String] = []


func _ready() -> void:
	chat_input.visible = false
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	chat_input.gui_input.connect(_on_chat_gui_input)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or chat_input.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_open_chat()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func set_crosshair_visible(enabled: bool) -> void:
	crosshair.visible = enabled


func set_health(value: float) -> void:
	health_bar.value = value


func set_coins(collected: int, total: int) -> void:
	coins_label.text = "Monete: %d / %d" % [collected, total]


func set_players(count: int) -> void:
	players_label.text = "Giocatori: %d" % count


func show_message(text: String, duration: float = MESSAGE_TIME) -> void:
	message_label.text = text
	message_label.modulate.a = 1.0
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.8)


func is_chat_open() -> bool:
	return chat_input.visible


func add_chat_line(sender: String, text: String) -> void:
	_chat_lines.append("%s: %s" % [sender, text])
	while _chat_lines.size() > CHAT_MAX_LINES:
		_chat_lines.pop_front()
	chat_log.text = "\n".join(_chat_lines)


func _open_chat() -> void:
	chat_input.visible = true
	chat_input.text = ""
	chat_input.grab_focus()
	chat_opened.emit()


func _close_chat() -> void:
	if not chat_input.visible:
		return
	chat_input.visible = false
	chat_input.release_focus()
	chat_closed.emit()


func _on_chat_text_submitted(text: String) -> void:
	_close_chat()
	chat_submitted.emit(text)


func _on_chat_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_chat()
		get_viewport().set_input_as_handled()
