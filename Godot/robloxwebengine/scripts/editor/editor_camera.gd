class_name EditorCamera
extends Camera3D
## Camera libera dell'editor: WASD muove, E/Q sale/scende, tasto destro ruota,
## rotella regola la velocità, Shift accelera.

const SENSITIVITY := 0.0025
const PITCH_MIN := deg_to_rad(-89.0)
const PITCH_MAX := deg_to_rad(89.0)
const SPEED_MIN := 4.0
const SPEED_MAX := 300.0

var speed := 24.0
var yaw := 0.0
var pitch := 0.0


func _ready() -> void:
	yaw = rotation.y
	pitch = rotation.x


func _process(delta: float) -> void:
	if _text_field_focused():
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	if Input.is_key_pressed(KEY_E):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_Q):
		direction.y -= 1.0
	if direction.length() > 1.0:
		direction = direction.normalized()
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	global_position += direction * speed * boost * delta
	rotation = Vector3(pitch, yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _text_field_focused():
		return
	if event is InputEventMouseMotion \
			and (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)):
		yaw -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed = clampf(speed * 1.15, SPEED_MIN, SPEED_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed = clampf(speed / 1.15, SPEED_MIN, SPEED_MAX)


func _text_field_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is SpinBox
