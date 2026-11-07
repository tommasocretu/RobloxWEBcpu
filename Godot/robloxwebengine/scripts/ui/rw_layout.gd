class_name RwLayout
extends RefCounted
## Content scaling e design space della UI 2014.
##
## Il client disabilita il content scaling del progetto; HUD e menu vivono in
## design space e il CanvasLayer applica la scala 0.8–1.0. Studio ed editor
## restano in `CANVAS_ITEMS`.

const DESIGN_BASE := Vector2(1280, 720)
const SCALE_MIN := 0.8
const SCALE_MAX := 1.0


static func scale_for(viewport: Vector2) -> float:
	return clampf(minf(viewport.x / DESIGN_BASE.x, viewport.y / DESIGN_BASE.y), SCALE_MIN, SCALE_MAX)


static func apply(layer: CanvasLayer, root: Control) -> float:
	var viewport := layer.get_viewport().get_visible_rect().size
	var scale := scale_for(viewport)
	layer.scale = Vector2(scale, scale)
	root.position = Vector2.ZERO
	root.size = viewport / scale
	return scale


static func use_client(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED


static func use_editor(window: Window) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
