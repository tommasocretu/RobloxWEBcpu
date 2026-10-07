class_name GoalZone
extends Area3D
## Traguardo del livello: scatta una sola volta quando il giocatore lo raggiunge.

signal reached


var _is_triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _is_triggered or not (body is PlayerCharacter):
		return
	_is_triggered = true
	reached.emit()
