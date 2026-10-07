class_name KillBrick
extends Area3D
## Zona che uccide istantaneamente chi la tocca (il classico "kill brick" di Roblox).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerCharacter:
		body.take_damage(PlayerCharacter.MAX_HEALTH)
