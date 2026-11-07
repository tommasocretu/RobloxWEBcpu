class_name RwTheme
extends RefCounted
## Tema runtime della pelle 2014 per HUD, Game Menu, banner e debug.
##
## I valori vengono da [RwTokens]; le scene usano solo type variation `Rw*` e
## nessun override locale. Il tema non viene mutato a runtime.

const FONT_UI_REGULAR: FontFile = preload("res://assets/fonts/SourceSans3-Regular.ttf")
const FONT_UI_BOLD: FontFile = preload("res://assets/fonts/SourceSans3-Bold.ttf")
const FONT_LEGACY_REGULAR: FontFile = preload("res://assets/fonts/LiberationSans-Regular.ttf")
const FONT_LEGACY_BOLD: FontFile = preload("res://assets/fonts/LiberationSans-Bold.ttf")

static var _shared: Theme
static var _fonts_configured := false


static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func reset_cache() -> void:
	_shared = null


static func build() -> Theme:
	_configure_fonts()
	var theme := Theme.new()
	theme.default_font = FONT_UI_REGULAR
	theme.default_font_size = RwTokens.FONT_SIZE_BODY
	_install_labels(theme)
	_install_buttons(theme)
	_install_chat(theme)
	_install_panels(theme)
	return theme


static func _configure_fonts() -> void:
	if _fonts_configured:
		return
	for font: FontFile in [FONT_UI_REGULAR, FONT_UI_BOLD, FONT_LEGACY_REGULAR, FONT_LEGACY_BOLD]:
		font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		font.hinting = TextServer.HINTING_LIGHT
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		font.multichannel_signed_distance_field = false
		font.allow_system_fallback = true
		font.force_autohinter = false
	_fonts_configured = true


static func _flat(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	width: int = 0,
	radius: int = 0
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	if width > 0:
		box.set_border_width_all(width)
	if radius > 0:
		box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.shadow_size = 0
	return box


static func _button_flat(bg: Color, border: Color) -> StyleBoxFlat:
	var box := _flat(bg, border, 1, 0)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func _focus_box() -> StyleBoxFlat:
	var box := _flat(Color.TRANSPARENT, RwTokens.FOCUS, 2, 0)
	box.expand_margin_left = 1
	box.expand_margin_right = 1
	box.expand_margin_top = 1
	box.expand_margin_bottom = 1
	return box


static func _label(
	theme: Theme,
	type: StringName,
	font: Font,
	size: int,
	color: Color,
	outline: int = 0,
	outline_color: Color = RwTokens.UI_TEXT_SHADOW
) -> void:
	theme.set_type_variation(type, &"Label")
	theme.set_font(&"font", type, font)
	theme.set_font_size(&"font_size", type, size)
	theme.set_color(&"font_color", type, color)
	if outline > 0:
		theme.set_color(&"font_outline_color", type, outline_color)
		theme.set_constant(&"outline_size", type, outline)


static func _button(
	theme: Theme,
	type: StringName,
	font: Font,
	size: int,
	normal: StyleBox,
	hover: StyleBox,
	pressed: StyleBox,
	hover_pressed: StyleBox,
	disabled: StyleBox
) -> void:
	theme.set_type_variation(type, &"Button")
	theme.set_font(&"font", type, font)
	theme.set_font_size(&"font_size", type, size)
	theme.set_color(&"font_color", type, RwTokens.UI_TEXT)
	theme.set_color(&"font_hover_color", type, RwTokens.UI_TEXT)
	theme.set_color(&"font_pressed_color", type, RwTokens.UI_TEXT)
	theme.set_color(&"font_focus_color", type, RwTokens.UI_TEXT)
	theme.set_color(&"font_disabled_color", type, RwTokens.TEXT_DISABLED)
	theme.set_stylebox(&"normal", type, normal)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, pressed)
	theme.set_stylebox(&"hover_pressed", type, hover_pressed)
	theme.set_stylebox(&"focus", type, _focus_box())
	theme.set_stylebox(&"disabled", type, disabled)


static func _install_labels(theme: Theme) -> void:
	theme.set_font(&"font", &"Label", FONT_UI_REGULAR)
	theme.set_font_size(&"font_size", &"Label", RwTokens.FONT_SIZE_BODY)
	theme.set_color(&"font_color", &"Label", RwTokens.UI_TEXT)

	_label(theme, &"RwLabelHealth", FONT_UI_BOLD, RwTokens.FONT_SIZE_HEALTH,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelPlayerHead", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_PLAYER_HEAD,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelPlayerCoinsHead", FONT_LEGACY_BOLD, 11,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_SMALL)
	_label(theme, &"RwLabelPlayerName", FONT_LEGACY_REGULAR, RwTokens.FONT_SIZE_PLAYER_NAME,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelPlayerNameLocal", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_PLAYER_NAME,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelPlayerCollapsed", FONT_LEGACY_BOLD, 12,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_SMALL)
	_label(theme, &"RwLabelPlayerCoins", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_PLAYER_NAME,
		RwTokens.GOLD, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelMenuTitle", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_MENU_TITLE,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelMenuSmall", FONT_LEGACY_REGULAR, RwTokens.FONT_SIZE_MENU_SMALL,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelComandiTitle", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_MENU_SMALL,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelComandi", FONT_LEGACY_REGULAR, 12,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelBanner", FONT_UI_BOLD, RwTokens.FONT_SIZE_MENU_TITLE,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_TEXT)
	_label(theme, &"RwLabelDebug", FONT_UI_REGULAR, RwTokens.FONT_SIZE_TINY,
		RwTokens.UI_TEXT, RwTokens.OUTLINE_SMALL)


static func _install_buttons(theme: Theme) -> void:
	theme.set_font(&"font", &"Button", FONT_LEGACY_REGULAR)
	theme.set_font_size(&"font_size", &"Button", RwTokens.FONT_SIZE_MENU_BUTTON)
	theme.set_color(&"font_color", &"Button", RwTokens.UI_TEXT)
	theme.set_color(&"font_hover_color", &"Button", RwTokens.UI_TEXT)
	theme.set_color(&"font_pressed_color", &"Button", RwTokens.UI_TEXT)
	theme.set_color(&"font_focus_color", &"Button", RwTokens.UI_TEXT)
	theme.set_color(&"font_disabled_color", &"Button", RwTokens.TEXT_DISABLED)
	theme.set_stylebox(&"normal", &"Button", _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER))
	theme.set_stylebox(&"hover", &"Button", _button_flat(RwTokens.MENU_BUTTON_HOVER, RwTokens.MENU_BUTTON_BORDER))
	theme.set_stylebox(&"pressed", &"Button", _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER))
	theme.set_stylebox(&"hover_pressed", &"Button", _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER))
	theme.set_stylebox(&"focus", &"Button", _focus_box())
	theme.set_stylebox(&"disabled", &"Button", _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER))

	var menu_normal := _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER)
	var menu_hover := _button_flat(RwTokens.MENU_BUTTON_HOVER, RwTokens.MENU_BUTTON_BORDER)
	var menu_pressed := _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER)
	var menu_disabled := _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_BUTTON_BORDER)
	_button(theme, &"RwButtonMenu", FONT_LEGACY_REGULAR, RwTokens.FONT_SIZE_MENU_BUTTON,
		menu_normal, menu_hover, menu_pressed, menu_pressed, menu_disabled)

	var default_normal := _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_DEFAULT)
	var default_hover := _button_flat(RwTokens.MENU_BUTTON_HOVER, RwTokens.MENU_DEFAULT)
	var default_pressed := _button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_DEFAULT)
	_button(theme, &"RwButtonMenuDefault", FONT_LEGACY_REGULAR, RwTokens.FONT_SIZE_MENU_BUTTON,
		default_normal, default_hover, default_pressed, default_pressed,
		_button_flat(RwTokens.MENU_BUTTON_BG, RwTokens.MENU_DEFAULT))

	var header_normal := _flat(RwTokens.UI_PANEL_DARK, RwTokens.UI_BORDER, 0, 0)
	header_normal.border_width_bottom = 1
	var header_hover := _flat(RwTokens.UI_PANEL, RwTokens.UI_BORDER, 0, 0)
	header_hover.border_width_bottom = 1
	var header_pressed := _flat(RwTokens.UI_PANEL_DARK, RwTokens.UI_BORDER, 0, 0)
	header_pressed.border_width_bottom = 1
	var header_disabled := _flat(RwTokens.UI_PANEL_DARK, RwTokens.UI_BORDER, 0, 0)
	header_disabled.border_width_bottom = 1
	_button(theme, &"RwButtonPlayerHeader", FONT_LEGACY_BOLD, RwTokens.FONT_SIZE_PLAYER_HEAD,
		header_normal, header_hover, header_pressed, header_pressed, header_disabled)

	var empty := StyleBoxEmpty.new()
	theme.set_type_variation(&"RwButtonMenuTrigger", &"Button")
	theme.set_font(&"font", &"RwButtonMenuTrigger", FONT_UI_REGULAR)
	theme.set_font_size(&"font_size", &"RwButtonMenuTrigger", 12)
	theme.set_color(&"font_color", &"RwButtonMenuTrigger", RwTokens.UI_TEXT)
	theme.set_color(&"font_hover_color", &"RwButtonMenuTrigger", RwTokens.UI_TEXT)
	theme.set_color(&"font_pressed_color", &"RwButtonMenuTrigger", RwTokens.UI_TEXT)
	theme.set_color(&"font_focus_color", &"RwButtonMenuTrigger", RwTokens.UI_TEXT)
	theme.set_color(&"font_outline_color", &"RwButtonMenuTrigger", RwTokens.UI_TEXT_SHADOW)
	theme.set_constant(&"outline_size", &"RwButtonMenuTrigger", RwTokens.OUTLINE_TEXT)
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		theme.set_stylebox(state, &"RwButtonMenuTrigger", empty)


static func _install_chat(theme: Theme) -> void:
	theme.set_font(&"font", &"LineEdit", FONT_UI_REGULAR)
	theme.set_font_size(&"font_size", &"LineEdit", RwTokens.FONT_SIZE_CHAT)
	theme.set_color(&"font_color", &"LineEdit", RwTokens.UI_TEXT)
	theme.set_color(&"font_placeholder_color", &"LineEdit", Color(1, 1, 1, 0.9))
	theme.set_color(&"font_selected_color", &"LineEdit", RwTokens.UI_TEXT)
	theme.set_color(&"caret_color", &"LineEdit", RwTokens.UI_TEXT)
	theme.set_color(&"selection_color", &"LineEdit", RwTokens.FOCUS)
	var line_normal := _flat(RwTokens.CHAT_BAR, Color.TRANSPARENT, 0, 0)
	var line_focus := _flat(RwTokens.CHAT_BAR_FOCUS, Color.TRANSPARENT, 0, 0)
	line_focus.border_width_top = 2
	line_focus.border_color = RwTokens.FOCUS
	var line_readonly := _flat(RwTokens.CHAT_BAR, Color.TRANSPARENT, 0, 0)
	for box in [line_normal, line_focus, line_readonly]:
		box.content_margin_left = 4
		box.content_margin_right = 4
		box.content_margin_top = 2
		box.content_margin_bottom = 2
	theme.set_stylebox(&"normal", &"LineEdit", line_normal)
	theme.set_stylebox(&"focus", &"LineEdit", line_focus)
	theme.set_stylebox(&"read_only", &"LineEdit", line_readonly)

	theme.set_font(&"normal_font", &"RichTextLabel", FONT_UI_REGULAR)
	theme.set_font(&"bold_font", &"RichTextLabel", FONT_UI_BOLD)
	theme.set_font_size(&"normal_font_size", &"RichTextLabel", RwTokens.FONT_SIZE_CHAT)
	theme.set_font_size(&"bold_font_size", &"RichTextLabel", RwTokens.FONT_SIZE_CHAT)
	theme.set_color(&"default_color", &"RichTextLabel", RwTokens.UI_TEXT)
	theme.set_color(&"font_outline_color", &"RichTextLabel", RwTokens.UI_TEXT_SHADOW)
	theme.set_constant(&"outline_size", &"RichTextLabel", RwTokens.OUTLINE_CHAT)
	theme.set_constant(&"line_separation", &"RichTextLabel", 1)
	theme.set_stylebox(&"normal", &"RichTextLabel", StyleBoxEmpty.new())

	var chat_normal := _flat(RwTokens.CHAT_BAR, Color.TRANSPARENT, 0, 0)
	chat_normal.content_margin_left = 4
	chat_normal.content_margin_right = 4
	chat_normal.content_margin_top = 2
	chat_normal.content_margin_bottom = 2
	var chat_focus := _flat(RwTokens.CHAT_BAR_FOCUS, Color.TRANSPARENT, 0, 0)
	chat_focus.border_width_top = 2
	chat_focus.border_color = RwTokens.FOCUS
	var chat_readonly := _flat(RwTokens.CHAT_BAR, Color.TRANSPARENT, 0, 0)
	theme.set_type_variation(&"RwLineEditChat", &"LineEdit")
	theme.set_font(&"font", &"RwLineEditChat", FONT_UI_REGULAR)
	theme.set_font_size(&"font_size", &"RwLineEditChat", RwTokens.FONT_SIZE_CHAT)
	theme.set_stylebox(&"normal", &"RwLineEditChat", chat_normal)
	theme.set_stylebox(&"focus", &"RwLineEditChat", chat_focus)
	theme.set_stylebox(&"read_only", &"RwLineEditChat", chat_readonly)

	theme.set_type_variation(&"RwRichChat", &"RichTextLabel")
	theme.set_font(&"normal_font", &"RwRichChat", FONT_UI_REGULAR)
	theme.set_font(&"bold_font", &"RwRichChat", FONT_UI_BOLD)
	theme.set_font_size(&"normal_font_size", &"RwRichChat", RwTokens.FONT_SIZE_CHAT)
	theme.set_font_size(&"bold_font_size", &"RwRichChat", RwTokens.FONT_SIZE_CHAT)
	theme.set_color(&"default_color", &"RwRichChat", RwTokens.UI_TEXT)
	theme.set_color(&"font_outline_color", &"RwRichChat", RwTokens.UI_TEXT_SHADOW)
	theme.set_constant(&"outline_size", &"RwRichChat", RwTokens.OUTLINE_CHAT)
	theme.set_constant(&"line_separation", &"RwRichChat", 1)
	theme.set_stylebox(&"normal", &"RwRichChat", StyleBoxEmpty.new())


static func _install_panels(theme: Theme) -> void:
	theme.set_type_variation(&"RwPanelPlayerList", &"PanelContainer")
	theme.set_stylebox(&"panel", &"RwPanelPlayerList",
		_flat(RwTokens.UI_PANEL, RwTokens.UI_BORDER, 1, RwTokens.UI_RADIUS))

	theme.set_type_variation(&"RwPanelPlayerRow", &"PanelContainer")
	var row := _flat(Color.TRANSPARENT, RwTokens.UI_BORDER, 0, 0)
	row.border_width_bottom = 1
	row.border_color = Color(RwTokens.UI_BORDER, 0.4)
	theme.set_stylebox(&"panel", &"RwPanelPlayerRow", row)

	theme.set_type_variation(&"RwPanelPlayerRowAlt", &"PanelContainer")
	var row_alt := _flat(RwTokens.PLAYERLIST_ROW_ALT, RwTokens.UI_BORDER, 0, 0)
	row_alt.border_width_bottom = 1
	row_alt.border_color = Color(RwTokens.UI_BORDER, 0.4)
	theme.set_stylebox(&"panel", &"RwPanelPlayerRowAlt", row_alt)

	theme.set_type_variation(&"RwPanelBanner", &"PanelContainer")
	theme.set_stylebox(&"panel", &"RwPanelBanner",
		_flat(RwTokens.BANNER_BG, RwTokens.MENU_DEFAULT, 1, 0))

	theme.set_type_variation(&"RwPanelMenuShield", &"Panel")
	theme.set_stylebox(&"panel", &"RwPanelMenuShield", _flat(RwTokens.MENU_SHIELD))

	theme.set_type_variation(&"RwPanelCrosshair", &"Panel")
	theme.set_stylebox(&"panel", &"RwPanelCrosshair",
		_flat(RwTokens.UI_TEXT, RwTokens.UI_TEXT_SHADOW, 1, 0))

	theme.set_type_variation(&"RwPanelHealthTrack", &"Panel")
	theme.set_stylebox(&"panel", &"RwPanelHealthTrack",
		_flat(Color.BLACK, Color.BLACK, 1, 0))
