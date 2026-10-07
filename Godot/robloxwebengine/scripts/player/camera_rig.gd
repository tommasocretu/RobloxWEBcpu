class_name CameraRig
extends Node3D
## Camera in terzo persona in stile Roblox.
## Tasto destro: orbita. Rotella: zoom. Shift: shift-lock (camera agganciata dietro).

signal shift_lock_changed(locked: bool)

const SENSITIVITY := 0.0025
const PITCH_MIN := deg_to_rad(-80.0)
const PITCH_MAX := deg_to_rad(75.0)
const MIN_DISTANCE := 4.0
const MAX_DISTANCE := 24.0
const ZOOM_STEP := 2.0
const HEAD_OFFSET := Vector3(0, 4.5, 0)

var yaw := 0.0
var pitch := -0.15
var distance := 12.0
var shift_lock := false
var target: PhysicsBody3D

@onready var spring_arm: SpringArm3D = $SpringArm3D


func _process(_delta: float) -> void:
	if target:
		global_position = target.global_position + HEAD_OFFSET
	rotation = Vector3(pitch, yaw, 0.0)
	spring_arm.spring_length = distance


func setup(new_target: PhysicsBody3D) -> void:
	target = new_target
	spring_arm.add_excluded_object(new_target.get_rid())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _is_rotating():
		yaw -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, PITCH_MIN, PITCH_MAX)
	elif event.is_action_pressed("toggle_shift_lock"):
		_set_shift_lock(not shift_lock)


func _is_rotating() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				distance = maxf(MIN_DISTANCE, distance - ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				distance = minf(MAX_DISTANCE, distance + ZOOM_STEP)


func _set_shift_lock(enabled: bool) -> void:
	if shift_lock == enabled:
		return
	shift_lock = enabled
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
	shift_lock_changed.emit(enabled)
