class_name MenuTrigger
extends Button
## Pulsante Menu a forma di scudo (92×48) disegnato in `_draw`.
## Il tema fornisce solo font e colori (`RwButtonMenuTrigger`); qui non si usa
## nessuna texture esterna.

const HOME_COLOR := RwTokens.UI_TEXT
const OUTLINE_COLOR := RwTokens.UI_TEXT_SHADOW


func _ready() -> void:
	theme_type_variation = &"RwButtonMenuTrigger"
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Apri il menu di gioco"
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var width := size.x
	var height := size.y
	var polygon := PackedVector2Array([
		Vector2(14, 0),
		Vector2(width, 0),
		Vector2(width, height),
		Vector2(0, height),
		Vector2(0, 14),
	])
	if button_pressed:
		draw_colored_polygon(polygon, Color(1, 1, 1, 0.20))
	elif is_hovered():
		draw_colored_polygon(polygon, RwTokens.MENU_TRIGGER_HOVER)
	var outline := PackedVector2Array([
		Vector2(14, 0),
		Vector2(width, 0),
		Vector2(width, height),
		Vector2(0, height),
		Vector2(0, 14),
		Vector2(14, 0),
	])
	draw_polyline(outline, RwTokens.UI_BORDER, 1.0, true)

	if has_focus():
		var focus := PackedVector2Array([
			Vector2(14, -1),
			Vector2(width + 1, -1),
			Vector2(width + 1, height + 1),
			Vector2(-1, height + 1),
			Vector2(-1, 14),
			Vector2(14, -1),
		])
		draw_polyline(focus, RwTokens.FOCUS, 2.0, true)

	_draw_home()
	_draw_label()


func _draw_home() -> void:
	var lines := [
		PackedVector2Array([Vector2(26, 25), Vector2(38, 16), Vector2(50, 25)]),
		PackedVector2Array([Vector2(29, 24), Vector2(29, 36), Vector2(47, 36), Vector2(47, 24)]),
		PackedVector2Array([Vector2(36, 36), Vector2(36, 29), Vector2(40, 29), Vector2(40, 36)]),
	]
	for line in lines:
		draw_polyline(line, HOME_COLOR, 2.0, true)


func _draw_label() -> void:
	var font := get_theme_font(&"font")
	if font == null:
		return
	var font_size := get_theme_font_size(&"font_size")
	var baseline := Vector2(55, 31)
	draw_string_outline(
		font, baseline, "Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2,
		OUTLINE_COLOR
	)
	draw_string(
		font, baseline, "Menu", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HOME_COLOR
	)
