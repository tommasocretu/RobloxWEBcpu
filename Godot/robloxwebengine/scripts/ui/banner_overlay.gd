class_name BannerOverlay
extends CanvasLayer
## Banner del traguardo: 525×80, centrato al 40%, fade 120 ms, un solo banner.
## Non è un toast e non si accumula.

const FADE_TIME := 0.12

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Anchor/Center/Panel
@onready var label: Label = $Root/Anchor/Center/Panel/Label

var _tween: Tween
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	root.theme = RwTheme.shared()
	call_deferred("_apply_layout")
	get_viewport().size_changed.connect(_apply_layout)
	visible = false


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size != _last_viewport_size:
		_last_viewport_size = viewport_size
		_apply_layout()


func show_banner(text: String, duration: float = 5.0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	label.text = text
	panel.modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_interval(maxf(duration, 0.0))
	_tween.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(func() -> void: visible = false)


func _apply_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	RwLayout.apply(self, root)
