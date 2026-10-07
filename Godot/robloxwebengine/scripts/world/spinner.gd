class_name SpinnerPart
extends AnimatableBody3D
## Parte ancorata rotante: l'ostacolo classico degli obby di Roblox.

@export var rotation_speed_degrees := 90.0


func _physics_process(delta: float) -> void:
	rotate_y(deg_to_rad(rotation_speed_degrees) * delta)
