extends SceneTree
## Test headless delle fondamenta del tema 2014: costruzione, cache, type
## variation, stylebox, font, scala e scan delle scene migrate.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_theme.gd

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RwTheme.reset_cache()
	var theme := RwTheme.build()
	_check(theme != null, "RwTheme.build() restituisce un tema")
	_check(RwTheme.shared() == RwTheme.shared(), "RwTheme.shared() usa la cache")
	_check(RwTheme.shared() != theme, "build() crea una nuova istanza")

	_check(theme.default_font == RwTheme.FONT_UI_REGULAR, "font UI predefinito")
	_check(theme.default_font_size == RwTokens.FONT_SIZE_BODY, "dimensione body predefinita")

	var base_font := theme.get_font(&"font", &"Label")
	_check(base_font == RwTheme.FONT_UI_REGULAR, "Label base usa Source Sans 3")
	_check(theme.get_font_size(&"font_size", &"Label") == RwTokens.FONT_SIZE_BODY,
		"Label base 14 px")
	_check(_color(theme.get_color(&"font_color", &"Label"), RwTokens.UI_TEXT),
		"Label base bianca")

	_check_variation(theme, &"RwLabelHealth", &"Label", RwTheme.FONT_UI_BOLD,
		RwTokens.FONT_SIZE_HEALTH, RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_check_variation(theme, &"RwLabelMenuTitle", &"Label", RwTheme.FONT_LEGACY_BOLD,
		RwTokens.FONT_SIZE_MENU_TITLE, RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_check_variation(theme, &"RwLabelBanner", &"Label", RwTheme.FONT_UI_BOLD,
		RwTokens.FONT_SIZE_MENU_TITLE, RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_check_variation(theme, &"RwLabelDebug", &"Label", RwTheme.FONT_UI_REGULAR,
		RwTokens.FONT_SIZE_TINY, RwTokens.UI_TEXT, RwTokens.OUTLINE_SMALL)
	_check_variation(theme, &"RwLabelPlayerCoins", &"Label", RwTheme.FONT_LEGACY_BOLD,
		RwTokens.FONT_SIZE_PLAYER_NAME, RwTokens.GOLD, RwTokens.OUTLINE_TEXT)
	_check_variation(theme, &"RwLabelPlayerNameLocal", &"Label", RwTheme.FONT_LEGACY_BOLD,
		RwTokens.FONT_SIZE_PLAYER_NAME, RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_check_variation(theme, &"RwLabelPlayerCollapsed", &"Label", RwTheme.FONT_LEGACY_BOLD,
		12, RwTokens.UI_TEXT, RwTokens.OUTLINE_SMALL)

	var menu_normal := theme.get_stylebox(&"normal", &"RwButtonMenu") as StyleBoxFlat
	_check(menu_normal != null, "RwButtonMenu ha normal StyleBoxFlat")
	if menu_normal:
		_check(_color(menu_normal.bg_color, RwTokens.MENU_BUTTON_BG), "menu nero")
		_check(_color(menu_normal.border_color, RwTokens.MENU_BUTTON_BORDER), "menu bordo #808080")
		_check(menu_normal.content_margin_left == 8, "menu content margin 8")

	var default_normal := theme.get_stylebox(&"normal", &"RwButtonMenuDefault") as StyleBoxFlat
	_check(default_normal != null and _color(default_normal.border_color, RwTokens.MENU_DEFAULT),
		"RwButtonMenuDefault bordo rosso")
	var focus := theme.get_stylebox(&"focus", &"RwButtonMenu") as StyleBoxFlat
	_check(focus != null and _color(focus.border_color, RwTokens.FOCUS)
		and focus.border_width_left == 2, "focus cyan 2 px")
	_check(theme.get_stylebox(&"normal", &"RwButtonMenuTrigger") is StyleBoxEmpty,
		"RwButtonMenuTrigger senza stylebox visibile")

	var chat_focus := theme.get_stylebox(&"focus", &"RwLineEditChat") as StyleBoxFlat
	_check(chat_focus != null, "RwLineEditChat focus StyleBoxFlat")
	if chat_focus:
		_check(chat_focus.border_width_top == 2 and _color(chat_focus.border_color, RwTokens.FOCUS),
			"chat focus bordo superiore cyan 2 px")
	var rich_font := theme.get_font(&"normal_font", &"RwRichChat")
	_check(rich_font == RwTheme.FONT_UI_REGULAR, "RwRichChat font UI")
	_check(theme.get_constant(&"outline_size", &"RwRichChat") == RwTokens.OUTLINE_CHAT,
		"RwRichChat outline 3")

	var panel := theme.get_stylebox(&"panel", &"RwPanelPlayerList") as StyleBoxFlat
	_check(panel != null, "RwPanelPlayerList pannello")
	if panel:
		_check(_color(panel.bg_color, RwTokens.UI_PANEL), "player list UI_PANEL")
		_check(_color(panel.border_color, RwTokens.UI_BORDER), "player list UI_BORDER")
		_check(panel.corner_radius_top_left == RwTokens.UI_RADIUS, "player list radius 4")
	var row := theme.get_stylebox(&"panel", &"RwPanelPlayerRow") as StyleBoxFlat
	_check(row != null and row.border_width_bottom == 1 and row.border_width_top == 0,
		"riga player list con solo bordo inferiore")
	var banner := theme.get_stylebox(&"panel", &"RwPanelBanner") as StyleBoxFlat
	_check(banner != null and _color(banner.bg_color, RwTokens.BANNER_BG)
		and _color(banner.border_color, RwTokens.MENU_DEFAULT), "banner nero con bordo rosso")
	var shield := theme.get_stylebox(&"panel", &"RwPanelMenuShield") as StyleBoxFlat
	_check(shield != null and _color(shield.bg_color, RwTokens.MENU_SHIELD),
		"shield del Game Menu MENU_SHIELD")
	_check(_color(RwTokens.UI_PANEL, Color("#1E3A78DB")), "UI_PANEL blu notte 0.86")
	_check(_color(RwTokens.UI_PANEL_DARK, Color("#172A4FE6")), "UI_PANEL_DARK blu notte 0.90")
	_check(_color(RwTokens.MENU_SHIELD, Color("#33333366")), "MENU_SHIELD grigio 0.40")

	_check(is_equal_approx(RwLayout.scale_for(Vector2(1680, 964)), 1.0), "scala 1680×964 = 1.0")
	_check(is_equal_approx(RwLayout.scale_for(Vector2(1280, 684)), 0.95), "scala 1280×684 = 0.95")
	_check(is_equal_approx(RwLayout.scale_for(Vector2(1024, 732)), 0.8), "scala 1024×732 = 0.8")
	_check(is_equal_approx(RwLayout.scale_for(Vector2(800, 564)), 0.8), "scala 800×564 = 0.8")
	_check(is_equal_approx(RwLayout.scale_for(Vector2(640, 364)), 0.8), "scala 640×364 = 0.8")

	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 684)
	get_root().add_child(viewport)
	var layer := CanvasLayer.new()
	var ui_root := Control.new()
	viewport.add_child(layer)
	layer.add_child(ui_root)
	var applied := RwLayout.apply(layer, ui_root)
	_check(is_equal_approx(applied, 0.95), "apply restituisce 0.95")
	_check(layer.scale.is_equal_approx(Vector2(0.95, 0.95)), "apply imposta layer.scale")
	_check(ui_root.position.is_equal_approx(Vector2.ZERO), "apply posiziona il root a zero")
	_check(ui_root.size.is_equal_approx(Vector2(1280.0 / 0.95, 684.0 / 0.95)),
		"apply imposta root.size in design space")
	viewport.free()

	var window := Window.new()
	RwLayout.use_client(window)
	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED,
		"use_client disabilita il content scaling")
	RwLayout.use_editor(window)
	_check(window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
		"use_editor ripristina CANVAS_ITEMS")
	window.free()

	_check_scene(&"res://scenes/ui/hud.tscn")
	_check_scene(&"res://scenes/ui/game_menu.tscn")

	print("TEST_THEME_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check_variation(
	theme: Theme,
	type: StringName,
	base: StringName,
	font: Font,
	size: int,
	color: Color,
	outline: int
) -> void:
	_check(String(theme.get_type_variation_base(type)) == String(base),
		"%s ha base %s" % [type, base])
	_check(theme.get_font(&"font", type) == font, "%s usa il font atteso" % type)
	_check(theme.get_font_size(&"font_size", type) == size, "%s ha size %d" % [type, size])
	_check(_color(theme.get_color(&"font_color", type), color), "%s ha il colore atteso" % type)
	_check(theme.get_constant(&"outline_size", type) == outline,
		"%s ha outline %d" % [type, outline])


func _check_scene(path: StringName) -> void:
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "lettura %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	if not text.contains("theme_override_"):
		return
	# Le scene vengono migrate nelle PR 7–8: prima di allora l'override è noto.
	if text.contains("theme_type_variation") or text.contains("RwTheme"):
		_check(false, "%s contiene theme_override_ dopo la migrazione" % path)
	else:
		print("  - %s: scena pre-2014, scan degli override rimandato" % path)


func _color(actual: Color, expected: Color) -> bool:
	return actual.is_equal_approx(expected)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		_failures += 1
		print("  FAIL: ", label)
