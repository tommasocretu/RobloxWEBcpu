class_name NetClient
extends Node
## Client WebSocket verso il relay multiplayer (server/relay.py).
## La connessione web usa un ticket HMAC ricevuto da /api/places/<id>/play.

signal connected
signal disconnected
signal connection_failed
signal peer_joined(id: int, player_name: String)
signal peer_left(id: int)
signal peer_state(id: int, position: Vector3, yaw: float, speed: float)
signal chat_received(sender_name: String, text: String)
signal server_error(code: String, message: String)

const DEFAULT_URL := "ws://127.0.0.1:9081"
const RETRY_INTERVAL := 3.0

var player_name := "Giocatore"
var my_id := -1

var _socket := WebSocketPeer.new()
var _url := ""
var _ticket := ""
var _enabled := false
var _was_open := false
var _reported_failure := false
var _retry_timer := 0.0


func start(url: String) -> void:
	_url = url if url != "" else DEFAULT_URL
	_enabled = true
	_retry_timer = RETRY_INTERVAL
	_connect()


## Connessione autenticata: il server identifica giocatore e place dal ticket.
func start_with_ticket(url: String, ticket: String, name: String) -> void:
	_ticket = ticket
	if name != "":
		player_name = name
	start(url)


func stop() -> void:
	_enabled = false
	_ticket = ""
	if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		_socket.close()


func is_open() -> bool:
	return _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func send_state(position: Vector3, yaw: float, speed: float) -> void:
	_send({
		"type": "state",
		"p": [snappedf(position.x, 0.01), snappedf(position.y, 0.01), snappedf(position.z, 0.01)],
		"y": snappedf(yaw, 0.01),
		"s": snappedf(speed, 0.01),
	})


func send_chat(text: String) -> void:
	_send({"type": "chat", "text": text})


func _connect() -> void:
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(_url)
	if err != OK:
		push_warning("NetClient: connessione a %s fallita (err %d)" % [_url, err])


func _process(delta: float) -> void:
	if not _enabled:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _was_open:
				_was_open = true
				_reported_failure = false
				my_id = -1
				if _ticket != "":
					_send({"type": "hello", "ticket": _ticket})
				else:
					_send({"type": "hello", "name": player_name})
				connected.emit()
			while _socket.get_available_packet_count() > 0:
				_handle_message(_socket.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			if _was_open:
				_was_open = false
				my_id = -1
				disconnected.emit()
			elif _enabled and not _reported_failure:
				_reported_failure = true
				connection_failed.emit()
			_retry_timer -= delta
			if _retry_timer <= 0.0:
				_retry_timer = RETRY_INTERVAL
				_connect()


func _send(payload: Dictionary) -> void:
	if is_open():
		_socket.send_text(JSON.stringify(payload))


func _handle_message(text: String) -> void:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var message: Dictionary = parsed
	match str(message.get("type", "")):
		"welcome":
			my_id = int(message.get("id", -1))
			for peer in message.get("peers", []):
				if typeof(peer) != TYPE_DICTIONARY:
					continue
				peer_joined.emit(int(peer.get("id", -1)), str(peer.get("name", "?")))
				_emit_peer_state(peer)
		"join":
			peer_joined.emit(int(message.get("id", -1)), str(message.get("name", "?")))
		"leave":
			peer_left.emit(int(message.get("id", -1)))
		"state":
			_emit_peer_state(message)
		"chat":
			chat_received.emit(str(message.get("name", "?")), str(message.get("text", "")))
		"error":
			server_error.emit(
				str(message.get("code", "error")), str(message.get("message", "Errore del server."))
			)


func _emit_peer_state(message: Dictionary) -> void:
	var point = message.get("p")
	if point is Array and (point as Array).size() == 3:
		peer_state.emit(
			int(message.get("id", -1)),
			Vector3(float(point[0]), float(point[1]), float(point[2])),
			float(message.get("y", 0.0)),
			float(message.get("s", 0.0))
		)


static func resolve_server_url() -> String:
	var url := str(ProjectSettings.get_setting("net/server_url", DEFAULT_URL))
	if OS.has_feature("web"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		if bridge:
			var override = bridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
			if typeof(override) == TYPE_STRING and str(override) != "":
				url = str(override)
	return url
