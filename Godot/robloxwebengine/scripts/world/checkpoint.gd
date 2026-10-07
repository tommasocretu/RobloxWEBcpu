class_name Checkpoint
extends Area3D
## Punto di respawn attivabile toccandolo: si accende (blu → verde) la prima volta.

signal activated(spawn_position: Vector3)

const COLOR_OFF := Color(0.15, 0.45, 0.90)
const COLOR_ON := Color(0.20, 0.80, 0.30)

var _is_active := false

@onready var _pad: MeshInstance3D = $Pad
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	_sound.stream = SfxFactory.checkpoint()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _is_active or not (body is PlayerCharacter):
		return
	_is_active = true
	var material := _pad.material_override as StandardMaterial3D
	if material:
		material.albedo_color = COLOR_ON
	_sound.play()
	activated.emit(global_position + Vector3(0, 0.5, 0))
