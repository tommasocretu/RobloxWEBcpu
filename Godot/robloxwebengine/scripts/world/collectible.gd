class_name Collectible
extends Area3D
## Moneta da raccogliere: ruota, oscilla e sparisce con un suono quando la tocchi.

signal collected(collectible: Collectible)

var _is_taken := false
var _time := 0.0

@onready var _visual: Node3D = $Visual
@onready var _sound: AudioStreamPlayer3D = $Sound


func _ready() -> void:
	_sound.stream = SfxFactory.collect()
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_taken:
		return
	_time += delta
	_visual.rotate_y(delta * 2.4)
	_visual.position.y = 0.25 * sin(_time * 3.0)


func _on_body_entered(body: Node3D) -> void:
	if _is_taken or not (body is PlayerCharacter):
		return
	_is_taken = true
	set_deferred("monitoring", false)
	_visual.visible = false
	_sound.play()
	collected.emit(self)
	# Il nodo si libera da solo poco dopo (il suono è breve).
	get_tree().create_timer(1.0).timeout.connect(queue_free)
