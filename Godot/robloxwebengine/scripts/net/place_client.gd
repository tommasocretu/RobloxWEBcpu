class_name PlaceClient
extends Node
## Bootstrap del client web: legge `?place=` dall'URL, chiama
## `POST /api/places/<id>/play` e consegna livello, giocatore, ticket e URL WS.
## Sul web i cookie di sessione sono inviati dall'HTTPRequest same-origin.

signal level_loaded(level: Dictionary, place: Dictionary, player: Dictionary, ws_url: String, ticket: String)
signal request_failed(message: String, code: String)

const REQUEST_TIMEOUT := 15.0

var _http: HTTPRequest
var _busy := false
var _place_id := ""
var _base_url := ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "PlayRequest"
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func start() -> bool:
	if _busy:
		return false
	_place_id = read_query_param("place")
	if _place_id == "" or not _place_id.is_valid_int():
		_fail("Apri questa esperienza dal sito.", "no_place")
		return false
	_base_url = _origin()
	if _base_url == "":
		_fail("Server non raggiungibile.", "network")
		return false
	_busy = true
	var url := "%s/api/places/%s/play" % [_base_url, _place_id]
	var err := _http.request(
		url,
		PackedStringArray(["Content-Type: application/json", "Accept: application/json"]),
		HTTPClient.METHOD_POST,
		"{}"
	)
	if err != OK:
		_busy = false
		_fail("Server non raggiungibile.", "network")
		return false
	return true


func read_query_param(name: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return ""
	var value = bridge.eval(
		"new URLSearchParams(window.location.search).get(%s) || ''" % JSON.stringify(name), true
	)
	if typeof(value) == TYPE_STRING:
		return str(value).strip_edges()
	return ""


## Torna alla pagina dell'esperienza (il client gira dentro play.html).
func leave() -> void:
	if not OS.has_feature("web"):
		return
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return
	bridge.eval(
		"if (window.parent === window) { window.location.href = '/'; }"
		+ " else { window.parent.postMessage({type:'rw-leave'}, window.location.origin); }",
		true
	)


func _origin() -> String:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return ""
	var value = bridge.eval("window.location.origin || ''", true)
	var origin := str(value).strip_edges() if typeof(value) == TYPE_STRING else ""
	if origin == "" or origin == "null":
		return ""
	return origin.trim_suffix("/")


func _on_request_completed(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Server non raggiungibile.", "network")
		return
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text) if text.strip_edges() != "" else null
	var payload: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	match response_code:
		200:
			pass
		401:
			_fail("Accedi per giocare.", "unauthorized")
			return
		403:
			_fail("Esperienza non trovata o privata.", "forbidden")
			return
		404:
			_fail("Esperienza non trovata o privata.", "not_found")
			return
		503:
			_fail(
				str(payload.get("error", "L'esperienza non ha una versione pubblicata.")),
				"unavailable"
			)
			return
		_:
			_fail(str(payload.get("error", "Errore del server (%d)." % response_code)), "server")
			return

	var level = payload.get("level", {})
	var place = payload.get("place", {})
	var player = payload.get("player", {})
	if typeof(level) != TYPE_DICTIONARY or typeof(place) != TYPE_DICTIONARY \
			or typeof(player) != TYPE_DICTIONARY:
		_fail("Risposta del server non valida.", "invalid")
		return
	var errors := LevelData.validate(level)
	if not errors.is_empty():
		_fail("Livello non valido: %s" % errors[0], "invalid")
		return
	var ws_url := str(payload.get("ws_url", "")).strip_edges()
	var ticket := str(payload.get("ticket", "")).strip_edges()
	if ws_url == "" or ticket == "":
		_fail("Il server non ha fornito i dati multiplayer.", "invalid")
		return
	level_loaded.emit(level, place, player, ws_url, ticket)


func _fail(message: String, code: String) -> void:
	push_warning("PlaceClient: %s" % message)
	_post_error(message)
	request_failed.emit(message, code)


func _post_error(message: String) -> void:
	if not OS.has_feature("web"):
		return
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		return
	bridge.eval(
		"window.parent.postMessage({type:'rw-error', message:%s}, window.location.origin)"
		% JSON.stringify(message),
		true
	)
