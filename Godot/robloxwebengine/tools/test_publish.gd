extends SceneTree
## Test headless della pubblicazione M1 contro il server locale:
##   python3 server/run.py
## Login Bearer, creazione place, nuova versione, download e cancellazione.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_publish.gd

const API_URL := "http://127.0.0.1:9080"
const USERNAME := "demo"
const PASSWORD := "demo1234"

var _client: PublishClient
var _http: HTTPRequest
var _failures := 0
var _title := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_client = PublishClient.new()
	_client.base_url = API_URL
	root.add_child(_client)
	_http = HTTPRequest.new()
	root.add_child(_http)
	_title = "Test M1 %d" % (Time.get_unix_time_from_system())

	if not _client.login(USERNAME, PASSWORD):
		print("TEST_PUBLISH_FAIL (server non raggiungibile)")
		quit(1)
		return
	var login = await _client.login_finished
	_check(bool(login[0]), "login Bearer: %s" % str(login[1]))
	if not bool(login[0]):
		quit(1)
		return
	_check(_client.display_name() == "demo", "nome utente dal token")

	var level := LevelIO.load_default()
	level["meta"] = {"title": _title, "author": "", "description": "Pubblicato dal test"}
	level["version"] = 2
	level["scripts"] = [{
		"id": "s1",
		"name": "PortaScript",
		"parent_id": str(level["parts"][0].get("id", "")),
		"enabled": true,
		"source": "script.Parent.Touched:Connect(function(hit)\n\tprint(hit.Name)\nend)\n",
	}]
	_check(LevelData.validate(level).is_empty(), "livello di partenza valido")

	# Creazione della place.
	_check(_client.publish(0, _title, "Descrizione del test", "public", level), "richiesta di creazione")
	var created = await _client.published
	_check(bool(created[0]), "creazione place: %s" % str(created[1]))
	if not bool(created[0]):
		quit(1)
		return
	var place: Dictionary = created[2]
	var place_id := int(place.get("id", 0))
	_check(place_id > 0, "id place assegnato")
	_check(int(created[3]) == 1, "prima versione")

	# Compare nell'elenco delle proprie place.
	_check(_client.fetch_places(), "richiesta elenco place")
	var places = await _client.places_loaded
	_check(bool(places[0]), "elenco place: %s" % str(places[1]))
	var found := false
	for item in places[2]:
		if int(item.get("id", 0)) == place_id:
			found = true
	_check(found, "la place compare in /api/me/places")

	# Seconda versione con titolo aggiornato.
	level["meta"]["title"] = _title + " v2"
	_check(
		_client.publish(place_id, _title + " v2", "Seconda versione", "unlisted", level),
		"richiesta di nuova versione"
	)
	var published = await _client.published
	_check(bool(published[0]), "nuova versione: %s" % str(published[1]))
	_check(int(published[3]) == 2, "versione incrementata")

	# Download dell'ultima versione.
	_check(_client.fetch_level(place_id), "richiesta download livello")
	var loaded = await _client.level_loaded
	_check(bool(loaded[0]), "download livello: %s" % str(loaded[1]))
	_check(
		typeof(loaded[3]) == TYPE_DICTIONARY and str(loaded[3].get("meta", {}).get("title", "")) == _title + " v2",
		"il livello scaricato è la versione 2"
	)
	_check(
		typeof(loaded[3]) == TYPE_DICTIONARY
			and loaded[3].get("scripts", []).size() == 1
			and str(loaded[3]["scripts"][0].get("name", "")) == "PortaScript",
		"gli script sopravvivono alla pubblicazione"
	)

	# La pagina esperienza pubblica vede autore e versione.
	var detail := await _api_get("/api/places/%d" % place_id)
	_check(detail.get("place", {}).get("author", "") == "demo", "autore visibile nel dettaglio")
	_check(int(detail.get("place", {}).get("current_version", 0)) == 2, "versione corrente pubblica")

	# Pulsante Pubblica dell'editor (stessa finestra usata dall'utente).
	var editor = (load("res://scenes/editor/editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await process_frame
	editor.new_level()
	editor._build_server_window()
	editor._server_url_edit.text = API_URL
	editor._account_user_edit.text = USERNAME
	editor._account_pass_edit.text = PASSWORD
	editor._publish_title_edit.text = _title + " da editor"
	editor._publish_description.text = "Pubblicato dall'editor"
	editor._visibility_option.select(0)
	editor._thumbnail_check.button_pressed = false
	editor._on_publish_pressed()
	var editor_place := 0
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		editor_place = int(editor.data.get("meta", {}).get("place_id", 0))
		if editor_place > 0:
			break
		await process_frame
	_check(editor_place > 0, "publish dall'editor")
	_check(
		str(editor._publish_status.text).begins_with("Pubblicata"),
		"stato dell'editor: %s" % str(editor._publish_status.text)
	)
	var editor_title := str(editor.data.get("meta", {}).get("title", ""))
	_check(editor_title == _title + " da editor", "meta.title aggiornato nell'editor")
	_check(
		int(editor.data.get("meta", {}).get("published_version", 0)) == 1,
		"meta.published_version salvata"
	)
	if editor_place > 0:
		var editor_detail := await _api_get("/api/places/%d" % editor_place)
		_check(
			editor_detail.get("place", {}).get("author", "") == USERNAME,
			"la place dell'editor ha l'autore giusto"
		)
		await _api_delete("/api/places/%d" % editor_place)
	editor.queue_free()
	await process_frame

	# Pulizia: cancelliamo la place di test.
	var deleted := await _api_delete("/api/places/%d" % place_id)
	_check(int(deleted) == 200, "cancellazione della place di test")
	var after := await _api_get("/api/places/%d" % place_id)
	_check(int(after.get("status", 0)) == 404, "la place non esiste più")

	print("TEST_PUBLISH_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _api_request(method: int, path: String) -> Array:
	var headers := PackedStringArray([
		"Accept: application/json", "Authorization: Bearer " + _client.token
	])
	var err := _http.request(API_URL + path, headers, method, "")
	if err != OK:
		return []
	return await _http.request_completed


func _api_get(path: String) -> Dictionary:
	var response = await _api_request(HTTPClient.METHOD_GET, path)
	if response.is_empty():
		return {}
	var payload = JSON.parse_string(response[3].get_string_from_utf8())
	var parsed: Dictionary = payload if typeof(payload) == TYPE_DICTIONARY else {}
	parsed["status"] = int(response[1])
	return parsed


func _api_delete(path: String) -> int:
	var response = await _api_request(HTTPClient.METHOD_DELETE, path)
	return 0 if response.is_empty() else int(response[1])


func _check(condition: bool, label: String) -> void:
	print("TEST %s: %s" % [label, condition])
	if not condition:
		_failures += 1
