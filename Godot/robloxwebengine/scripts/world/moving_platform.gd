class_name MovingPlatform
extends AnimatableBody3D
## Piattaforma mobile: oscilla dolcemente tra la posizione iniziale e + offset,
## trasportando chi ci sta sopra (sync_to_physics attivo di default).

@export var offset := Vector3(0, 0, 8)
@export var duration := 4.0

var _start := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_start = position


func _physics_process(delta: float) -> void:
	_time += delta
	var t := 0.5 - 0.5 * cos(TAU * _time / duration)
	position = _start + offset * t
