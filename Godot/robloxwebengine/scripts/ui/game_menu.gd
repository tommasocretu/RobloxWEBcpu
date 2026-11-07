class_name GameMenu
extends CanvasLayer
## Game Menu, dialogo Leave e dialogo Reset del client web 2014.
##
## Il mondo non va in pausa: il menu gestisce solo focus e visibilità.
## `Riprendi`, `Resta` e `Annulla` sono i default sicuri.

signal leave_requested
signal reset_requested
signal menu_opened
signal menu_closed

enum State { CLOSED, MENU, LEAVE, RESET }

@onready var root: Control = $Root
@onready var menu_frame: Control = $Root/Center/MenuFrame
@onready var leave_frame: Control = $Root/Center/LeaveFrame
@onready var reset_frame: Control = $Root/Center/ResetFrame
@onready var resume_button: Button = $Root/Center/MenuFrame/Resume
@onready var reset_choice: Button = $Root/Center/MenuFrame/ResetChoice
@onready var leave_choice: Button = $Root/Center/MenuFrame/LeaveChoice
@onready var leave_keep: Button = $Root/Center/LeaveFrame/Keep
@onready var leave_confirm: Button = $Root/Center/LeaveFrame/Confirm
@onready var reset_cancel: Button = $Root/Center/ResetFrame/Cancel
@onready var reset_confirm: Button = $Root/Center/ResetFrame/Confirm

var state := State.CLOSED

var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	root.theme = RwTheme.shared()
	_apply_layout()
	call_deferred("_apply_layout")
	get_viewport().size_changed.connect(_apply_layout)
	visible = false
	resume_button.pressed.connect(close_menu)
	reset_choice.pressed.connect(_show_reset)
	leave_choice.pressed.connect(_show_leave)
	leave_keep.pressed.connect(close_menu)
	leave_confirm.pressed.connect(_on_leave_confirmed)
	reset_cancel.pressed.connect(close_menu)
	reset_confirm.pressed.connect(_on_reset_confirmed)


func open_menu() -> void:
	if state != State.CLOSED:
		return
	state = State.MENU
	_show_only(menu_frame)
	visible = true
	menu_opened.emit()
	resume_button.grab_focus()


func close_menu() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	visible = false
	menu_closed.emit()


func handle_escape() -> bool:
	if state == State.CLOSED:
		return false
	close_menu()
	return true


func is_open() -> bool:
	return state != State.CLOSED


func is_menu_open() -> bool:
	return state == State.MENU


func is_leave_open() -> bool:
	return state == State.LEAVE


func is_reset_open() -> bool:
	return state == State.RESET


func _show_leave() -> void:
	state = State.LEAVE
	_show_only(leave_frame)
	leave_keep.grab_focus()


func _show_reset() -> void:
	state = State.RESET
	_show_only(reset_frame)
	reset_cancel.grab_focus()


func _on_leave_confirmed() -> void:
	close_menu()
	leave_requested.emit()


func _on_reset_confirmed() -> void:
	close_menu()
	reset_requested.emit()


func _show_only(frame: Control) -> void:
	menu_frame.visible = frame == menu_frame
	leave_frame.visible = frame == leave_frame
	reset_frame.visible = frame == reset_frame


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_apply_layout()


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	RwLayout.apply(self, root)
