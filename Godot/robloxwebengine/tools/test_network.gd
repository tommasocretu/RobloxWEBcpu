extends SceneTree
## Test headless del client con il server M0 attivo:
##   python3 server/run.py
## Ottiene un ticket dall'API (login demo), avvia il gioco come client web e
## simula un secondo giocatore WebSocket con lo stesso ticket.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_network.gd

const API_URL := "http://127.0.0.1:9080"
const PLACE_ID := 1
const BOT_POSITION := Vector3(10, 20, 30)

var _main
var _net
var _peer
var _http: HTTPRequest
var _ws_url := ""
var _ticket := ""
var _player_name := ""
var _bot_id := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_http = HTTPRequest.new()
	root.add_child(_http)
	var credentials := await _api_play()
	print("TEST credenziali play ottenute: ", not credentials.is_empty())
	if credentials.is_empty():
		quit(1)
		return
	_ws_url = credentials["ws_url"]
	_ticket = credentials["ticket"]
	_player_name = credentials["player"]["name"]

	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame

	var level_data := LevelIO.load_default()
	print("TEST livello predefinito caricato: ", not level_data.is_empty())
	_main.start_level(level_data)
	await process_frame

	_main._place_mode = true
	_main._pending_ws_url = _ws_url
	_main._pending_ticket = _ticket
	_main._player_info = credentials["player"]
	_main.net.player_name = _player_name
	_main.net.peer_joined.connect(func(id, peer_name): print("TEST segnale join: id=", id, " name=", peer_name, " mio=", _main.net.my_id))
	_main.net.peer_left.connect(func(id): print("TEST segnale leave: id=", id))
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

	# Secondo giocatore simulato (stesso ticket, connessione separata).
	_peer = WebSocketPeer.new()
	_peer.connect_to_url(_ws_url)
	var peer_open := await _wait_for(_check_peer_open, 6.0)
	print("TEST peer simulato connesso: ", peer_open)
	if not peer_open:
		quit(1)
		return
	_peer.send_text(JSON.stringify({"type": "hello", "ticket": _ticket}))
	_peer.send_text(JSON.stringify({"type": "state", "p": [BOT_POSITION.x, BOT_POSITION.y, BOT_POSITION.z], "y": 0.5, "s": 3.0}))
	var bot_welcome := await _wait_for(_capture_bot_welcome, 6.0)
	print("TEST welcome peer ricevuto: ", bot_welcome, " id=", _bot_id)

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


func _api_post(path: String, body: Dictionary, cookie := "") -> Array:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Origin: " + API_URL,
	])
	if cookie != "":
		headers.append("Cookie: " + cookie)
	var err := _http.request(API_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return []
	var response = await _http.request_completed
	return response


func _api_play() -> Dictionary:
	var login = await _api_post("/api/login", {"username": "demo", "password": "demo1234"})
	if login.is_empty() or int(login[1]) != 200:
		print("TEST login API fallito (demo/demo1234); il seed è stato eseguito?")
		return {}
	var cookie := ""
	for header in login[2]:
		var text := str(header)
		if text.to_lower().begins_with("set-cookie:"):
			cookie = text.split(":", true, 1)[1].strip_edges().split(";", true, 1)[0]
	if cookie == "":
		print("TEST Set-Cookie assente nella risposta di login")
		return {}
	var play = await _api_post("/api/places/%d/play" % PLACE_ID, {}, cookie)
	if play.is_empty() or int(play[1]) != 200:
		print("TEST play API fallito con codice ", 0 if play.is_empty() else play[1])
		return {}
	var parsed = JSON.parse_string(play[3].get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _check_connected() -> bool:
	return _net.is_open()


func _check_id() -> bool:
	return _net.my_id > 0


func _check_peer_open() -> bool:
	_peer.poll()
	return _peer.get_ready_state() == WebSocketPeer.STATE_OPEN


func _check_remote_exists() -> bool:
	return _bot_id > 0 and _main._remote_characters.has(_bot_id)


func _check_remote_state() -> bool:
	var remote = _main._remote_characters.get(_bot_id)
	if remote == null:
		return false
	return remote._target_position.distance_to(BOT_POSITION) < 0.5


func _check_chat() -> bool:
	return _main.hud.get_node("ChatLog").text.contains("%s: ciao dal bot" % _player_name)


func _check_remote_removed() -> bool:
	return _bot_id > 0 and not _main._remote_characters.has(_bot_id)


func _capture_bot_welcome() -> bool:
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var parsed = JSON.parse_string(_peer.get_packet().get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY and str(parsed.get("type", "")) == "welcome":
			_bot_id = int(parsed.get("id", -1))
			return true
	return false


func _wait_for(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return false
