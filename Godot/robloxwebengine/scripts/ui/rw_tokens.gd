class_name RwTokens
extends RefCounted
## Token canonici della pelle Roblox 2014.
##
## Mirror GDScript di `WEBhtml/assets/site.css` per il sottoinsieme condiviso;
## le costanti solo client sono marcate e non hanno un equivalente CSS.
## La fonte dei valori resta `docs/roblox-2014/tokens.md`.

# --- Colori condivisi con il sito (--rw-color-*) -------------------------

const COLOR_HEADER := Color("#114081")
const COLOR_HEADER_DIVIDER := Color("#7394C1")
const COLOR_NAV_TEXT := Color("#FFFFFF")
const COLOR_NAV_HOVER := Color(1.0, 1.0, 1.0, 0.14)
const COLOR_OR := Color("#9EC3E7")
const COLOR_ON_DARK := Color("#FFFFFF")
const COLOR_FOOTER := Color("#123F83")
const COLOR_CANVAS := Color("#FFFFFF")
const COLOR_TEXT := Color("#343434")
const COLOR_TEXT_SECONDARY := Color("#666666")
const COLOR_TEXT_MUTED := Color("#767676")
const COLOR_TEXT_DISABLED := Color("#A7A7A7")
const COLOR_TEXT_FOOTER := Color("#C7CFDD")
const COLOR_TEXT_FOOTER_LEGAL := Color("#AFC0D8")
const COLOR_LINK := Color("#0055B3")
const COLOR_LINK_HOVER := Color("#0055B3")
const COLOR_LINK_SECONDARY := Color("#095FB5")
const COLOR_BORDER := Color("#CCCCCC")
const COLOR_BORDER_INPUT := Color("#A7A7A7")
const COLOR_BORDER_STRONG := Color("#777777")
const COLOR_BORDER_TABLE := Color("#9E9E9E")
const COLOR_SURFACE_SUBTLE := Color("#F1F1F1")
const COLOR_SURFACE_TAB := Color("#D6D6D6")
const COLOR_SURFACE_TAB_HOVER := Color("#E9E9E9")
const COLOR_SURFACE_BOX := Color("#E1E1E1")
const COLOR_PRIMARY := Color("#007001")
const COLOR_PRIMARY_HOVER := Color("#005A01")
const COLOR_PRIMARY_DISABLED := Color("#99C699")
const COLOR_NEUTRAL := Color("#0852B7")
const COLOR_NEUTRAL_HOVER := Color("#06408F")
const COLOR_NEUTRAL_DISABLED := Color("#9CBAE2")
const COLOR_NEGATIVE := Color("#565656")
const COLOR_NEGATIVE_HOVER := Color("#404040")
const COLOR_NEGATIVE_DISABLED := Color("#BBBCBB")
const COLOR_DANGER := Color("#CC0000")
const COLOR_DANGER_BG := Color("#FAE5E5")
const COLOR_SUCCESS := Color("#007001")
const COLOR_WARNING := Color("#AA6611")
const COLOR_INFO_BG := Color("#E5EFFA")
const COLOR_INFO_BORDER := Color("#0066CC")
const COLOR_SELECTION := Color("#00A1DA")
const COLOR_FOCUS := Color("#00A1DA")
const COLOR_ROBUX := Color("#006600")
const COLOR_TIX := Color("#AA6611")
const COLOR_GOLD := Color("#FFD700")
const COLOR_LOADING_BAR := Color("#D2D400")
const COLOR_LOADING_TRACK := Color("#8C8C8C")
const COLOR_LOADING_TEXT := Color("#E6E6E6")
const COLOR_OVERLAY := Color(0.0, 0.0, 0.0, 0.45)

const COLOR_LIKE := Color("#0055B3")
const COLOR_LIKE_ICON := Color("#FFD700")
const COLOR_LIVE := Color("#007001")
const COLOR_HIDDEN := Color("#AA6611")
const COLOR_THUMB_BORDER := Color("#D2D2D2")
const COLOR_PLACEHOLDER_GROUND := Color("#3F8F3F")
const COLOR_PLACEHOLDER_STUDS := Color(1.0, 1.0, 1.0, 0.22)
const COLOR_AVATAR_BG := Color("#EEEEEE")
const COLOR_AVATAR_SKIN := Color("#F5CD30")
const COLOR_AVATAR_SKIN_DARK := Color("#B38F00")
const COLOR_AVATAR_FALLBACK := Color("#9E9E9E")
const COLOR_HERO_ART_BORDER := Color(1.0, 1.0, 1.0, 0.5)

# --- Tipografia condivisa ------------------------------------------------

const FONT_SANS := "Source Sans 3"
const FONT_SIZE_BODY := 14
const LINE_HEIGHT_BODY := 1.428
const FONT_SIZE_SMALL := 12
const FONT_SIZE_TINY := 11
const FONT_SIZE_H1 := 32
const FONT_SIZE_H2 := 30
const FONT_SIZE_H3 := 15
const FONT_SIZE_NAV := 15
const FONT_SIZE_BUTTON_SMALL := 14
const FONT_SIZE_BUTTON_MEDIUM := 20
const FONT_SIZE_BUTTON_LARGE := 23
const FONT_SIZE_MODAL := 27
const FONT_SIZE_FOOTER := 13
const FONT_SIZE_LEGAL := 12

# --- Misure condivise ----------------------------------------------------

const SIZE_CONTENT := 970
const SIZE_CONTENT_WIDE := 1180
const SIZE_PAGE_PAD_Y := 5
const SIZE_PAGE_PAD_X := 25
const SIZE_HEADER_HEIGHT := 36
const SIZE_FOOTER_PAD := 20
const SIZE_SPACE_1 := 5
const SIZE_SPACE_2 := 7
const SIZE_SPACE_3 := 10
const SIZE_SPACE_4 := 15
const SIZE_SPACE_5 := 20
const SIZE_SPACE_6 := 25
const SIZE_SPACE_7 := 30
const SIZE_CARD_WIDTH := 202
const SIZE_CARD_THUMB_WIDTH := 192
const SIZE_CARD_THUMB_HEIGHT := 108
const SIZE_SIDEBAR_WIDTH := 300
const SIZE_RADIUS := 0
const SIZE_RADIUS_TOOLTIP := 3
const SIZE_BORDER_WIDTH := 1
const SHADOW := "none"

# --- Stati, motion, livelli ----------------------------------------------

const STATE_HOVER := "brightness(0.92)"
const STATE_FOCUS := "2px solid #00A1DA"
const STATE_DISABLED := "text-disabled"
const MOTION_FAST := "120ms ease"
const MOTION_REDUCED := "0.01ms"
const Z_HEADER := 30
const Z_DROPDOWN := 40
const Z_MODAL := 100
const Z_TOAST := 110

# --- Colori del client ---------------------------------------------------

const UI_PANEL := Color(30, 58, 120, 0.86)
const UI_PANEL_DARK := Color(23, 42, 79, 0.90)
const UI_BORDER := Color("#6E7FA6")
const UI_TEXT := Color("#FFFFFF")
const UI_TEXT_SHADOW := Color("#000000")
const TEXT_DISABLED := COLOR_TEXT_DISABLED
const CHAT_BAR := Color(0, 0, 0, 0.75)
const CHAT_BAR_FOCUS := Color(0, 0, 0, 0.88)
const HEALTH_TOP := Color("#25B230")
const HEALTH_MID := Color("#00AB00")
const HEALTH_DARK := Color("#004F00")
const HEALTH_RED := Color("#FF1C00")
const GOLD := COLOR_GOLD
const MENU_SHIELD := Color(51, 51, 51, 0.40)
const MENU_BUTTON_BG := Color("#000000")
const MENU_BUTTON_BORDER := Color("#808080")
const MENU_BUTTON_HOVER := Color("#111111")
const MENU_DEFAULT := Color("#C1272D")
const INVENTORY_BG := Color("#202020")
const PLAYERLIST_ROW_ALT := Color(1.0, 1.0, 1.0, 0.06)
const MENU_TRIGGER_HOVER := Color(1.0, 1.0, 1.0, 0.12)
const BANNER_BG := Color(0, 0, 0, 0.90)
const FOCUS := COLOR_FOCUS

## Palette deterministica dei nomi in chat, indice = somma byte UTF-8 % 8.
const CHAT_NAME_COLORS := [
	Color("#C4281C"),
	Color("#0D69AC"),
	Color("#27462D"),
	Color("#6B327C"),
	Color("#DA8541"),
	Color("#F5CD30"),
	Color("#B480FF"),
	Color("#D7C59A"),
]

# --- Tipografia del client -----------------------------------------------

const FONT_UI := FONT_SANS
const FONT_LEGACY := "Liberation Sans"
const FONT_SIZE_CHAT := 12
const FONT_SIZE_HEALTH := 14
const FONT_SIZE_MENU_TITLE := 36
const FONT_SIZE_MENU_BUTTON := 24
const FONT_SIZE_MENU_SMALL := 18
const FONT_SIZE_PLAYER_NAME := 14
const FONT_SIZE_PLAYER_HEAD := 24
const OUTLINE_CHAT := 3
const OUTLINE_TEXT := 2
const OUTLINE_SMALL := 1

# --- Misure del client ---------------------------------------------------

const CHAT_W := 500
const CHAT_H := 120
const CHAT_INPUT_H := 20
const CHAT_INDENT := 12
const CHAT_VISIBLE_LINES := 8
const CHAT_HISTORY := 20
const PLAYERLIST_W := 150
const PLAYERLIST_COINS_W := 52
const PLAYERLIST_ROW_H := 20
const PLAYERLIST_HEAD_H := 56
const PLAYERLIST_COLLAPSED_H := 24
const PLAYERLIST_ROWS_MAX := 16
const HEALTH_W := 170
const HEALTH_H := 18
const MENU_W := 525
const MENU_H := 430
const LEAVE_W := 525
const LEAVE_H := 300
const RESET_W := 525
const RESET_H := 370
const MENU_BUTTON_W := 340
const MENU_BUTTON_H := 50
const DIALOG_BUTTON_W := 128
const DIALOG_BUTTON_H := 50
const MENU_TRIGGER_W := 92
const MENU_TRIGGER_H := 48
const BANNER_W := 525
const BANNER_H := 80
const BANNER_Y := 0.40
const CROSSHAIR_SIZE := 4
const HOTBAR_SLOT := Vector2i(54, 54)
const HOTBAR_GAP := 6
const HOTBAR_BOTTOM := 31
const UI_RADIUS := 4
const UI_SCALE_BASE := Vector2(1680, 1000)
const UI_SCALE_TRIGGER := Vector2(1280, 720)
const UI_SCALE_MIN := 0.8
