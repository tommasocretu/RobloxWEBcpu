extends SceneTree
## Test headless di Studio (M2) contro il server locale:
##   python3 server/run.py
## Verifica preset di export, passaggio start screen → editor, login, download
## dell'ultima versione e consumo del livello da parte dell'editor.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> \
##        --script res://tools/test_studio.gd

const API_URL := "http://127.0.0.1:9080"
const USERNAME := "demo"
const PASSWORD := "demo1234"

var _client: PublishClient
var _http: HTTPRequest
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_client = PublishClient.new()
	_client.base_url = API_URL
	root.add_child(_client)
	_http = HTTPRequest.new()
	root.add_child(_http)

	_check_presets()

	var title := "Test Studio %d" % Time.get_unix_time_from_system()
	if not _client.login(USERNAME, PASSWORD):
		print("TEST_STUDIO_FAIL (server non raggiungibile)")
		quit(1)
		return
	var login = await _client.login_finished
	_check(bool(login[0]), "login per preparare la place: %s" % str(login[1]))
	if not bool(login[0]):
		quit(1)
		return

	# Place privata di prova (non compare nel catalogo pubblico).
	var level := LevelIO.load_default()
	level["meta"] = {
		"title": title,
		"author": "",
		"description": "Creata da test_studio.gd",
	}
	_check(LevelData.validate(level).is_empty(), "livello di partenza valido")
	_check(
		_client.publish(0, title, "Descrizione Studio", "private", level),
		"richiesta creazione place"
	)
	var created = await _client.published
	_check(bool(created[0]), "creazione place: %s" % str(created[1]))
	if not bool(created[0]):
		quit(1)
		return
	var place_id := int(created[2].get("id", 0))
	_check(place_id > 0, "id place assegnato")

	# StudioSession: il livello in attesa viene consumato una sola volta.
	StudioSession.clear_pending()
	StudioSession.set_pending(level, "messaggio di prova")
	_check(StudioSession.has_pending(), "StudioSession accetta un livello")
	var pending := StudioSession.take_pending()
	_check(not StudioSession.has_pending(), "StudioSession svuotata dopo il prelievo")
	_check(
		str(pending.get("meta", {}).get("title", "")) == title,
		"StudioSession conserva il livello"
	)
	_check(StudioSession.take_message() == "messaggio di prova", "messaggio StudioSession")

	# Start screen: login e apertura della place.
	if FileAccess.file_exists(PublishClient.SESSION_PATH):
		DirAccess.remove_absolute(PublishClient.SESSION_PATH)
	var start = (load("res://scenes/studio/studio_start.tscn") as PackedScene).instantiate()
	root.add_child(start)
	await process_frame
	_check(start.size.x > 100 and start.size.y > 100, "start screen a schermo intero")
	start._server_url_edit.text = API_URL
	start._account_user_edit.text = USERNAME
	start._account_pass_edit.text = PASSWORD
	start._on_login_pressed()
	var deadline := Time.get_ticks_msec() + 15000
	while not start._publish_client.is_logged_in() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(start._publish_client.is_logged_in(), "login dalla start screen")
	_check(
		str(start._login_button.text) == "Esci",
		"la start screen mostra lo stato connesso: %s" % str(start._login_button.text)
	)
	_check(
		FileAccess.file_exists(PublishClient.SESSION_PATH),
		"la sessione di Studio viene salvata in user://"
	)
	var restored_client := PublishClient.new()
	root.add_child(restored_client)
	_check(restored_client.restore_session(), "ripristino della sessione salvata")
	_check(restored_client.display_name() == USERNAME, "nome utente ripristinato")
	_check(restored_client.base_url == API_URL, "URL del server ripristinato")
	restored_client.clear_session()
	_check(
		not FileAccess.file_exists(PublishClient.SESSION_PATH),
		"logout/cancellazione della sessione salvata"
	)
	restored_client.queue_free()
	deadline = Time.get_ticks_msec() + 15000
	while start._places_list.item_count == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	var index := _find_place_index(start._places_list, place_id)
	_check(index >= 0, "la place compare nella start screen")
	if index < 0:
		start.queue_free()
		quit(1)
		return
	start._places_list.select(index)
	var opened: bool = await start._load_place_into_session(place_id)
	_check(opened, "download della place dalla start screen")
	_check(StudioSession.has_pending(), "la start screen prepara il livello per l'editor")
	_check(
		str(start._places_status.text) == "Livello pronto.",
		"stato download: %s" % str(start._places_status.text)
	)

	# L'editor consuma il pending senza ripristinare l'autosave.
	var editor = (load("res://scenes/editor/editor.tscn") as PackedScene).instantiate()
	root.add_child(editor)
	await process_frame
	var meta: Dictionary = editor.data.get("meta", {})
	_check(int(meta.get("place_id", 0)) == place_id, "l'editor apre la place scaricata")
	_check(str(meta.get("title", "")) == title, "titolo dal server nell'editor")
	_check(str(meta.get("visibility", "")) == "private", "visibilità dal server nell'editor")
	_check(
		int(meta.get("published_version", 0)) == 1,
		"versione pubblicata salvata nell'editor"
	)
	_check(not StudioSession.has_pending(), "l'editor svuota il pending")
	var thumbnail: PackedByteArray = await editor._capture_thumbnail()
	_check(thumbnail.is_empty(), "la cattura thumbnail è no-op in headless")
	editor.queue_free()
	start.queue_free()
	await process_frame

	# Pulizia.
	var deleted: bool = await _api_delete("/api/places/%d" % place_id)
	_check(deleted, "cancellazione della place di prova")
	_client.clear_session()

	print("TEST_STUDIO_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check_presets() -> void:
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(text.contains('name="Linux Studio"'), "preset Linux Studio")
	_check(text.contains('name="Windows Studio"'), "preset Windows Studio")
	_check(text.contains('custom_features="studio"'), "feature studio nei preset desktop")
	_check(
		text.contains("scenes/editor/*") and text.contains("scripts/editor/*"),
		"il preset Web esclude l'editor"
	)
	_check(text.contains("scenes/studio/*"), "il preset Web esclude la start screen")


func _find_place_index(list: ItemList, place_id: int) -> int:
	for i in list.item_count:
		if int(list.get_item_metadata(i)) == place_id:
			return i
	return -1


func _api_delete(path: String) -> bool:
	var headers := PackedStringArray(["Authorization: Bearer " + _client.token])
	var err := _http.request(API_URL + path, headers, HTTPClient.METHOD_DELETE)
	if err != OK:
		return false
	var result = await _http.request_completed
	return int(result[1]) >= 200 and int(result[1]) < 300


func _check(condition: bool, label: String) -> void:
	print("TEST %s: %s" % [label, condition])
	if not condition:
		_failures += 1
