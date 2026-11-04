class_name DebugOverlay
extends CanvasLayer
## FPS di debug: nascosto di default, F3 mostra/nasconde `FPS <n>` in basso a destra.
## Stato non persistito ed escluso da screenshot e demo.

@onready var root: Control = $Root
@onready var label: Label = $Root/Label

var _timer := 0.0
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	root.theme = RwTheme.shared()
	call_deferred("_apply_layout")
	get_viewport().size_changed.connect(_apply_layout)
	visible = false


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_apply_layout()
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.25
		label.text = "FPS %d" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F3:
		visible = not visible
		if visible:
			label.text = "FPS %d" % Engine.get_frames_per_second()
		get_viewport().set_input_as_handled()


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	RwLayout.apply(self, root)
