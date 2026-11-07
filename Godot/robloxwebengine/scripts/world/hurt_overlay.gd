class_name HurtOverlay
extends CanvasLayer
## Vignetta rossa ai bordi dello schermo: alpha 0 → 0,5 → 0 in 0,6 s.
## Vive sotto l'HUD (CanvasLayer 5) e non intercetta l'input.

const FLASH_TIME := 0.6
const FLASH_ALPHA := 0.5

@onready var rect: TextureRect = $Rect

var _tween: Tween


func _ready() -> void:
	rect.texture = _make_vignette()
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	rect.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(rect, "modulate:a", FLASH_ALPHA, FLASH_TIME * 0.5)
	_tween.tween_property(rect, "modulate:a", 0.0, FLASH_TIME * 0.5)


func _make_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.75, 0.0, 0.0, 0.0),
		Color(0.75, 0.0, 0.0, 0.05),
		Color(0.75, 0.0, 0.0, 1.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture
