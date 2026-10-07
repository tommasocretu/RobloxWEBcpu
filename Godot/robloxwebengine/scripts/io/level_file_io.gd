class_name LevelFileIO
extends Node
## Sceglie i file di livello dall'utente (apertura e salvataggio).
## Web: <input type=file> via JavaScriptBridge e download_buffer (niente dialog nativi).
## Nativo: FileDialog con fallback al filesystem.

signal _web_open_finished

const FILE_FILTERS := "*.json,*.rwl ; Livello RobloxWeb"

var _web_callback: JavaScriptObject
var _web_result := ""
var _dialog_done := false
var _dialog_path := ""


func is_web() -> bool:
	return OS.has_feature("web")


## Chiede all'utente un file di livello. Ritorna il testo ("" se annullato).
func choose_open_file(title := "Apri livello") -> String:
	if is_web():
		return await _web_choose_open()
	return await _native_choose_open(title)


## Salva/scarica il testo del livello. Ritorna true se il salvataggio è partito.
func save_text_file(text: String, suggested_name: String) -> bool:
	if is_web():
		return _web_save(text, suggested_name)
	return await _native_save(text, suggested_name)


# --- Web ------------------------------------------------------------------------

func _web_choose_open() -> String:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		push_error("LevelFileIO: JavaScriptBridge non disponibile.")
		return ""
	if _web_callback == null:
		_web_callback = bridge.create_callback(_on_web_file_picked)
	var window: JavaScriptObject = bridge.get_interface("window")
	window["__godotLevelFilePicked"] = _web_callback
	_web_result = ""
	bridge.eval("""
(function () {
	const input = document.createElement('input');
	input.type = 'file';
	input.accept = '.json,.rwl';
	input.style.display = 'none';
	document.body.appendChild(input);
	let finished = false;
	const finish = (text) => {
		if (finished) { return; }
		finished = true;
		window.__godotLevelFilePicked(String(text));
		input.remove();
	};
	input.addEventListener('change', () => {
		const file = input.files && input.files[0];
		if (!file) { finish(''); return; }
		const reader = new FileReader();
		reader.onload = () => finish(reader.result || '');
		reader.onerror = () => finish('');
		reader.readAsText(file);
	});
	input.addEventListener('cancel', () => finish(''));
	input.click();
})();
""", true)
	await _web_open_finished
	var result := _web_result
	_web_result = ""
	_web_callback = null
	return result


func _on_web_file_picked(args: Array) -> void:
	_web_result = str(args[0]) if args.size() > 0 else ""
	_web_open_finished.emit()


func _web_save(text: String, suggested_name: String) -> bool:
	var bridge := Engine.get_singleton("JavaScriptBridge")
	if bridge == null:
		push_error("LevelFileIO: JavaScriptBridge non disponibile.")
		return false
	# Nota: il browser accetta il download solo da interazione utente (pulsante).
	bridge.download_buffer(text.to_utf8_buffer(), suggested_name, "application/json")
	return true


# --- Nativo ---------------------------------------------------------------------

func _native_choose_open(title: String) -> String:
	var dialog := _make_dialog(FileDialog.FILE_MODE_OPEN_FILE, title, "")
	dialog.popup_centered_ratio(0.7)
	while not _dialog_done:
		await get_tree().process_frame
	dialog.queue_free()
	if _dialog_path == "":
		return ""
	var file := FileAccess.open(_dialog_path, FileAccess.READ)
	if file == null:
		push_warning("LevelFileIO: impossibile leggere %s" % _dialog_path)
		return ""
	return file.get_as_text()


func _native_save(text: String, suggested_name: String) -> bool:
	var dialog := _make_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Salva livello", suggested_name)
	dialog.popup_centered_ratio(0.7)
	while not _dialog_done:
		await get_tree().process_frame
	dialog.queue_free()
	if _dialog_path == "":
		return false
	var path := _dialog_path
	if path.get_extension() == "":
		path += ".rwl.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("LevelFileIO: impossibile salvare %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


func _make_dialog(mode: FileDialog.FileMode, title: String, current_file: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.title = title
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray([FILE_FILTERS])
	dialog.use_native_dialog = true
	if current_file != "":
		dialog.current_file = current_file
	_dialog_done = false
	_dialog_path = ""
	dialog.files_selected.connect(_on_dialog_files_selected)
	dialog.canceled.connect(_on_dialog_canceled)
	add_child(dialog)
	return dialog


func _on_dialog_files_selected(files: PackedStringArray) -> void:
	_dialog_path = files[0] if files.size() > 0 else ""
	_dialog_done = true


func _on_dialog_canceled() -> void:
	_dialog_path = ""
	_dialog_done = true
