class_name PlayerCharacter
extends CharacterBody3D
## Personaggio in stile Roblox (R6): WASD relativo alla camera, salto,
## camminata animata a cubetti, respawn quando cade nel vuoto.

signal died
signal health_changed(value: float)
signal shift_lock_changed(locked: bool)

const WALK_SPEED := 16.0
const JUMP_VELOCITY := 50.0
const GROUND_ACCELERATION := 160.0
const AIR_ACCELERATION := 64.0
const KILL_PLANE_Y := -500.0
const MAX_HEALTH := 100.0
const TURN_SPEED := 14.0

var health := MAX_HEALTH
var shift_lock := false
var input_enabled := true

var _walk_phase := 0.0
var _walk_amplitude := 0.0

@onready var visual: Node3D = $Visual
@onready var camera_rig: CameraRig = $CameraRig
@onready var limb_left_arm: Node3D = $Visual/ArmL
@onready var limb_right_arm: Node3D = $Visual/ArmR
@onready var limb_left_leg: Node3D = $Visual/LegL
@onready var limb_right_leg: Node3D = $Visual/LegR
@onready var jump_sound: AudioStreamPlayer3D = $JumpSound
@onready var land_sound: AudioStreamPlayer3D = $LandSound

var _was_on_floor := true


func _ready() -> void:
	camera_rig.setup(self)
	camera_rig.shift_lock_changed.connect(_on_shift_lock_changed)
	jump_sound.stream = SfxFactory.jump()
	land_sound.stream = SfxFactory.land()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_rig.yaw)
	if move_direction.length() > 1.0:
		move_direction = move_direction.normalized()

	var acceleration := GROUND_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	var target_velocity := move_direction * WALK_SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if is_on_floor():
		if input_enabled and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			jump_sound.play()
	else:
		velocity += get_gravity() * delta

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		land_sound.play()
	_was_on_floor = is_on_floor()

	_update_facing(move_direction, delta)
	_animate_walk(delta)

	if global_position.y < KILL_PLANE_Y:
		died.emit()


func take_damage(amount: float) -> void:
	set_health(health - amount)


func set_character_name(display_name: String) -> void:
	var name_tag := get_node_or_null("Visual/NameTag") as Label3D
	if name_tag:
		name_tag.text = display_name


func set_health(value: float) -> void:
	var new_health := clampf(value, 0.0, MAX_HEALTH)
	if is_equal_approx(new_health, health):
		return
	health = new_health
	health_changed.emit(health)
	if health <= 0.0:
		died.emit()


func _update_facing(move_direction: Vector3, delta: float) -> void:
	var target_yaw := visual.rotation.y
	if shift_lock:
		target_yaw = camera_rig.yaw
	elif move_direction.length() > 0.01:
		target_yaw = atan2(-move_direction.x, -move_direction.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, minf(1.0, TURN_SPEED * delta))


func _animate_walk(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var target_amplitude := 1.0 if is_on_floor() and speed > 0.5 else 0.0
	_walk_amplitude = move_toward(_walk_amplitude, target_amplitude, delta * 4.0)
	_walk_phase += delta * speed * 1.1
	var swing := sin(_walk_phase) * _walk_amplitude * 0.8
	limb_left_arm.rotation.x = swing
	limb_right_arm.rotation.x = -swing
	limb_left_leg.rotation.x = -swing
	limb_right_leg.rotation.x = swing


func _on_shift_lock_changed(locked: bool) -> void:
	shift_lock = locked
	shift_lock_changed.emit(locked)
