extends SceneTree
## Test headless dell'HUD 2014 e del Game Menu: palette, storia chat, player
## list, collapse, scala, API di stato e default sicuri dei dialoghi.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_hud.gd

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var hud: GameHUD = (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await process_frame

	_check(hud.root.theme == RwTheme.shared(), "HUD usa RwTheme.shared()")
	_check(GameHUD.name_color_index("tu") == GameHUD.name_color_index("tu"),
		"palette nome deterministica")
	_check(GameHUD.name_color("Blocco99") == RwTokens.CHAT_NAME_COLORS[
		GameHUD.name_color_index("Blocco99")
	], "colore nome dalla palette")
	var expected_index := 0
	for byte in "LavaGirl".to_utf8_buffer():
		expected_index += int(byte)
	expected_index %= RwTokens.CHAT_NAME_COLORS.size()
	_check(GameHUD.name_color_index("LavaGirl") == expected_index,
		"hash UTF-8 della palette")

	for index in 25:
		hud.add_chat_line("tu", "riga %d" % index)
	_check(hud.chat_line_count() == RwTokens.CHAT_HISTORY, "storia limitata a 20 righe")
	_check(hud.visible_chat_line_count() == RwTokens.CHAT_VISIBLE_LINES,
		"massimo 8 righe visibili")
	_check(hud.chat_has_line("tu", "riga 24"), "chat_has_line trova l'ultima riga")
	_check(not hud.chat_has_line("tu", "riga 0"), "la riga più vecchia è stata scartata")
	hud.add_system_line("Checkpoint raggiunto!")
	_check(hud.chat_has_line("", "Checkpoint raggiunto!"), "riga di sistema in chat")
	hud._process(GameHUD.CHAT_LIFETIME + 1.0)
	_check(hud.chat_line_count() == 0, "la chat scade dopo 45 s")

	hud.set_local_coins(3, 10)
	hud.set_player_list("tu", ["Zeta", "alpha", "Beta"])
	var names := hud.player_list_names()
	_check(names == ["alpha", "Beta", "tu", "Zeta"], "player list alfabetica case-insensitive")
	_check(_row_coins(hud, "tu") == "3/10", "monete locali collected/total")
	_check(_row_coins(hud, "Zeta") == "—", "monete remote assenti")

	hud.toggle_player_list()
	_check(hud.is_player_list_collapsed(), "player list collassata")
	_check(not hud.get_node("Root/PlayerList/VBox/Rows").visible, "righe nascoste da collassata")
	_check(hud.player_list.offset_bottom == 29.0, "barra collassata alta 24 px")
	hud.toggle_player_list()
	_check(not hud.is_player_list_collapsed(), "player list espansa di nuovo")

	hud.set_chat_enabled(false)
	_check(not hud.is_chat_enabled(), "chat ospite disabilitata")
	hud._open_chat()
	_check(hud.chat_has_line("", GameHUD.CHAT_GUEST_WARNING), "avviso ospite in chat")
	hud.set_chat_enabled(true)
	hud._open_chat()
	_check(hud.is_chat_open(), "chat aperta per account")
	hud.close_chat()
	_check(not hud.is_chat_open(), "chat chiusa")

	hud.set_menu_enabled(true)
	var menu_requested := [false]
	hud.menu_requested.connect(func() -> void: menu_requested[0] = true)
	hud.menu_trigger.pressed.emit()
	_check(menu_requested[0], "pulsante Menu emette menu_requested")
	hud.set_menu_open(true)
	_check(hud.is_menu_open(), "stato menu aperto nel HUD")
	hud.set_menu_open(false)

	hud.set_health(24.0)
	_check(hud.health_bar.texture_progress == hud._health_texture_low,
		"salute sotto 25% usa il gradiente rosso")
	hud.set_crosshair_visible(true)
	_check(hud.crosshair.visible, "mirino visibile con shift lock")
	hud.set_crosshair_visible(false)
	_check(not hud.crosshair.visible, "mirino nascosto con mouse libero")
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	_check(not hud.debug_overlay.visible, "FPS nascosto di default")
	hud.debug_overlay._unhandled_input(f3)
	_check(hud.debug_overlay.visible, "F3 mostra l'FPS")
	hud.debug_overlay._unhandled_input(f3)
	_check(not hud.debug_overlay.visible, "F3 nasconde l'FPS")
	hud.show_banner("GIOCO COMPLETATO!", 5.0)
	_check(hud.banner.visible and hud.banner.label.text == "GIOCO COMPLETATO!",
		"banner del traguardo visibile")

	var menu: GameMenu = (load("res://scenes/ui/game_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	menu.open_menu()
	await process_frame
	_check(menu.is_menu_open() and menu.visible, "Game Menu aperto")
	_check(menu.resume_button.has_focus(), "focus iniziale su Riprendi")
	menu.leave_choice.pressed.emit()
	await process_frame
	_check(menu.is_leave_open(), "dialogo Leave aperto")
	_check(menu.leave_keep.has_focus(), "focus iniziale su Resta")
	_check(menu.handle_escape() and not menu.is_open(), "Esc chiude Leave")
	menu.open_menu()
	menu.reset_choice.pressed.emit()
	await process_frame
	_check(menu.is_reset_open(), "dialogo Reset aperto")
	_check(menu.reset_cancel.has_focus(), "focus iniziale su Annulla")
	_check(menu.handle_escape() and not menu.is_open(), "Esc chiude Reset")
	menu.open_menu()
	_check(menu.handle_escape() and not menu.is_open(), "Esc chiude Game Menu")

	hud.queue_free()
	menu.queue_free()
	await process_frame
	print("TEST_HUD_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _row_coins(hud: GameHUD, player_name: String) -> String:
	for row in hud.player_rows.get_children():
		var name_label := row.find_child("Name", true, false) as Label
		if name_label and name_label.text == player_name:
			var coins_label := row.find_child("Coins", true, false) as Label
			return coins_label.text if coins_label else ""
	return ""


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
	else:
		_failures += 1
		print("  FAIL: ", label)
