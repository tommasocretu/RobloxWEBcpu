extends SceneTree
## Test automatico headless della Fase 3 (multiplayer), richiede server attivo:
##   python3 server/server.py
## Avvia il gioco, si connette al server e simula un secondo giocatore
## (WebSocketPeer "grezzo" nello stesso processo) per verificare avatar remoti,
## stato e chat.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_network.gd

const SERVER_URL := "ws://127.0.0.1:9080"
const BOT_POSITION := Vector3(10, 20, 30)

var _main
var _net
var _peer


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame

	var level_data := LevelIO.load_default()
	print("TEST livello predefinito caricato: ", not level_data.is_empty())
	_main.start_level(level_data)
	await process_frame

	_main.get_node("Menu").play_pressed.emit()
	await process_frame

	_net = _main.get_node("NetClient")
	var connected := await _wait_for(_check_connected, 6.0)
	print("TEST connessione al server: ", connected)
	if not connected:
		quit(1)
		return
	var id_ok := await _wait_for(_check_id, 4.0)
	print("TEST id assegnato: ", id_ok)

	# Secondo giocatore simulato.
	_peer = WebSocketPeer.new()
	_peer.connect_to_url(SERVER_URL)
	var peer_open := await _wait_for(_check_peer_open, 6.0)
	print("TEST peer simulato connesso: ", peer_open)
	if not peer_open:
		quit(1)
		return
	_peer.send_text(JSON.stringify({"type": "hello", "name": "Bot"}))
	_peer.send_text(JSON.stringify({"type": "state", "p": [BOT_POSITION.x, BOT_POSITION.y, BOT_POSITION.z], "y": 0.5, "s": 3.0}))

	var has_remote := await _wait_for(_check_remote_exists, 6.0)
	print("TEST avatar remoto creato: ", has_remote)
	var state_ok := await _wait_for(_check_remote_state, 6.0)
	print("TEST stato remoto ricevuto: ", state_ok)

	_peer.send_text(JSON.stringify({"type": "chat", "text": "ciao dal bot"}))
	var chat_ok := await _wait_for(_check_chat, 6.0)
	print("TEST chat ricevuta: ", chat_ok)

	_peer.close()
	var left_ok := await _wait_for(_check_remote_removed, 6.0)
	print("TEST avatar rimosso dopo la disconnessione: ", left_ok)

	_net.stop()
	var all_ok: bool = connected and peer_open and has_remote and state_ok and chat_ok and left_ok
	print("TEST_NETWORK_%s" % ("OK" if all_ok else "FAIL"))
	quit(0 if all_ok else 1)


func _check_connected() -> bool:
	return _net.is_open()


func _check_id() -> bool:
	return _net.my_id > 0


func _check_peer_open() -> bool:
	_peer.poll()
	return _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func _check_remote_exists() -> bool:
	return _main._remote_characters.size() == 1


func _check_remote_state() -> bool:
	if _main._remote_characters.is_empty():
		return false
	var remote = _main._remote_characters.values()[0]
	return remote._target_position.distance_to(BOT_POSITION) < 0.5


func _check_chat() -> bool:
	return _main.hud.get_node("ChatLog").text.contains("Bot: ciao dal bot")


func _check_remote_removed() -> bool:
	return _main._remote_characters.is_empty()


func _wait_for(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false
