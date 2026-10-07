class_name RemoteCharacter
extends Node3D
## Avatar remoto (solo visuale): insegue con interpolazione lo stato ricevuto
## dalla rete e anima braccia/gambe in base alla velocità inviata dal peer.

const POSITION_LERP_SPEED := 12.0
const TURN_LERP_SPEED := 14.0
const WALK_ANIM_SPEED := 10.0
const WALK_ANIM_AMPLITUDE := 0.8

var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _net_speed := 0.0
var _walk_phase := 0.0
var _walk_amplitude := 0.0

@onready var visual: Node3D = $Visual
@onready var name_tag: Label3D = $Visual/NameTag
@onready var limb_left_arm: Node3D = $Visual/ArmL
@onready var limb_right_arm: Node3D = $Visual/ArmR
@onready var limb_left_leg: Node3D = $Visual/LegL
@onready var limb_right_leg: Node3D = $Visual/LegR


func setup(display_name: String, position: Vector3, yaw: float) -> void:
	name_tag.text = display_name
	global_position = position
	visual.rotation.y = yaw
	_target_position = position
	_target_yaw = yaw


func apply_state(position: Vector3, yaw: float, speed: float) -> void:
	_target_position = position
	_target_yaw = yaw
	_net_speed = speed


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(
		_target_position, clampf(delta * POSITION_LERP_SPEED, 0.0, 1.0)
	)
	visual.rotation.y = lerp_angle(visual.rotation.y, _target_yaw, minf(1.0, TURN_LERP_SPEED * delta))

	var moving := _net_speed > 0.5
	_walk_amplitude = move_toward(_walk_amplitude, 1.0 if moving else 0.0, delta * 4.0)
	_walk_phase += delta * WALK_ANIM_SPEED * (1.0 if moving else 0.0)
	var swing := sin(_walk_phase) * _walk_amplitude * WALK_ANIM_AMPLITUDE
	limb_left_arm.rotation.x = swing
	limb_right_arm.rotation.x = -swing
	limb_left_leg.rotation.x = -swing
	limb_right_leg.rotation.x = swing
