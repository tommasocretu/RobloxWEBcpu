class_name PublishClient
extends Node
## Pubblicazione delle esperienze (M1): login Bearer, creazione place, nuove
## versioni, thumbnail e download dei propri livelli.
## Usato dall'editor (nativo e web temporaneo); Studio userà lo stesso client.
##
## Tutte le operazioni sono asincrone: ogni metodo avvia una richiesta e uno dei
## segnali qui sotto riporta l'esito. Una sola richiesta alla volta.

signal login_finished(ok: bool, message: String)
signal places_loaded(ok: bool, message: String, places: Array)
signal level_loaded(ok: bool, message: String, place: Dictionary, level: Dictionary)
signal published(ok: bool, message: String, place: Dictionary, version: int)
signal thumbnail_uploaded(ok: bool, message: String)

const DEFAULT_BASE_URL := "http://127.0.0.1:9080"
const REQUEST_TIMEOUT := 20.0

var base_url := DEFAULT_BASE_URL
var token := ""
var user: Dictionary = {}

var _http: HTTPRequest
var _busy := false
var _pending := ""
var _pending_id := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "PublishRequest"
	_http.timeout = REQUEST_TIMEOUT
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


func is_logged_in() -> bool:
	return token != ""


func display_name() -> String:
	return str(user.get("name", ""))


func clear_session() -> void:
	token = ""
	user = {}


## URL di default: sul web lo stesso origin del sito, altrimenti localhost.
static func default_base_url() -> String:
	if OS.has_feature("web"):
		var bridge := Engine.get_singleton("JavaScriptBridge")
		if bridge != null:
			var value = bridge.eval("window.location.origin || ''", true)
			if typeof(value) == TYPE_STRING and str(value).strip_edges() != "":
				return str(value).strip_edges().trim_suffix("/")
	return DEFAULT_BASE_URL


func normalize_base_url(value: String) -> String:
	var text := value.strip_edges().trim_suffix("/")
	if text == "":
		return default_base_url()
	if not text.begins_with("http://") and not text.begins_with("https://"):
		text = "http://" + text
	return text


# --- Operazioni -----------------------------------------------------------------

func login(username: String, password: String) -> bool:
	var payload := JSON.stringify({"username": username, "password": password})
	return _send("login", HTTPClient.METHOD_POST, "/api/token", payload)


func fetch_places() -> bool:
	return _send("places", HTTPClient.METHOD_GET, "/api/me/places")


func fetch_level(place_id: int) -> bool:
	return _send("level", HTTPClient.METHOD_GET, "/api/places/%d/data" % int(place_id))


func publish(
	place_id: int,
	title: String,
	description: String,
	visibility: String,
	level: Dictionary
) -> bool:
	var body := JSON.stringify({
		"title": title,
		"description": description,
		"visibility": visibility,
		"level": level,
	})
	if int(place_id) > 0:
		return _send(
			"published", HTTPClient.METHOD_POST, "/api/places/%d/versions" % int(place_id), body
		)
	return _send("published", HTTPClient.METHOD_POST, "/api/places", body)


func upload_thumbnail(place_id: int, png: PackedByteArray) -> bool:
	if png.is_empty():
		return false
	return _send(
		"thumbnail",
		HTTPClient.METHOD_POST,
		"/api/places/%d/thumbnail" % int(place_id),
		"",
		"image/png",
		png
	)


# --- HTTP -----------------------------------------------------------------------

func _send(
	kind: String,
	method: int,
	path: String,
	body: String = "",
	content_type: String = "application/json",
	raw: PackedByteArray = PackedByteArray()
) -> bool:
	if _busy:
		push_warning("PublishClient: richiesta già in corso")
		return false
	base_url = normalize_base_url(base_url)
	var headers := PackedStringArray(["Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if not raw.is_empty():
		headers.append("Content-Type: " + content_type)
	elif body != "":
		headers.append("Content-Type: application/json")
	_pending = kind
	_busy = true
	var url := base_url + path
	var err := OK
	if not raw.is_empty():
		err = _http.request_raw(url, headers, method, raw)
	else:
		err = _http.request(url, headers, method, body)
	if err != OK:
		_busy = false
		_pending = ""
		_emit_failure(kind, "Server non raggiungibile (%s)." % base_url)
		return false
	return true


func _on_request_completed(
	_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	var kind := _pending
	_pending = ""
	_busy = false
	if kind == "":
		return
	if _result != HTTPRequest.RESULT_SUCCESS:
		_emit_failure(kind, "Server non raggiungibile.")
		return
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text) if text.strip_edges() != "" else null
	var payload: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	var message := str(payload.get("error", ""))
	if response_code == 401:
		clear_session()
		_emit_failure(kind, message if message != "" else "Sessione scaduta: accedi di nuovo.")
		return
	if response_code < 200 or response_code >= 300:
		_emit_failure(
			kind,
			message if message != "" else "Errore del server (%d)." % response_code,
		)
		return
	_emit_success(kind, payload)


func _emit_success(kind: String, payload: Dictionary) -> void:
	match kind:
		"login":
			token = str(payload.get("token", ""))
			user = payload.get("user", {}) if typeof(payload.get("user", {})) == TYPE_DICTIONARY else {}
			var name := display_name()
			var message := (
				("Connesso come %s." % name)
				if token != ""
				else "Risposta di login non valida."
			)
			login_finished.emit(token != "", message)
		"places":
			var items = payload.get("places", [])
			places_loaded.emit(
				true, "", items if typeof(items) == TYPE_ARRAY else []
			)
		"level":
			var level = payload.get("level", {})
			var place = payload.get("place", {})
			if typeof(level) != TYPE_DICTIONARY or typeof(place) != TYPE_DICTIONARY:
				level_loaded.emit(false, "Risposta del server non valida.", {}, {})
				return
			level_loaded.emit(true, "", place, level)
		"published":
			var place = payload.get("place", {})
			if typeof(place) != TYPE_DICTIONARY:
				published.emit(false, "Risposta del server non valida.", {}, 0)
				return
			published.emit(true, "", place, int(payload.get("version", 0)))
		"thumbnail":
			thumbnail_uploaded.emit(true, "")
		_:
			pass


func _emit_failure(kind: String, message: String) -> void:
	match kind:
		"login":
			login_finished.emit(false, message)
		"places":
			places_loaded.emit(false, message, [])
		"level":
			level_loaded.emit(false, message, {}, {})
		"published":
			published.emit(false, message, {}, 0)
		"thumbnail":
			thumbnail_uploaded.emit(false, message)
		_:
			push_warning("PublishClient: %s" % message)
