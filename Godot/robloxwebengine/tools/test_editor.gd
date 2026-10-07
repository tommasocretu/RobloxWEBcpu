extends SceneTree
## Test headless dell'editor: piazzamento, duplica/elimina, undo/redo,
## serializzazione della scena e autosave.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_editor.gd

const TEST_PATH := "user://test_editor_level.rwl.json"

var _failures := 0
var _editor


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var autosave := LevelEditor.AUTOSAVE_PATH
	if FileAccess.file_exists(autosave):
		DirAccess.remove_absolute(autosave)

	_editor = (load("res://scenes/editor/editor.tscn") as PackedScene).instantiate()
	root.add_child(_editor)
	await process_frame

	_editor.new_level()
	_check(_editor.data["parts"].size() == 2, "nuovo livello con baseplate e spawn")
	var parts_before: int = _editor.data["parts"].size()

	var id: String = _editor.add_entity("part", Vector3(4, 0.5, 4))
	_check(id != "", "piazzamento parte")
	_check(_editor.data["parts"].size() == parts_before + 1, "conteggio dopo piazzamento")
	_check(_editor.selected_id == id, "la parte piazzata è selezionata")

	_check(_editor.duplicate_selected(), "duplica selezione")
	_check(_editor.data["parts"].size() == parts_before + 2, "conteggio dopo duplica")
	_check(_editor.delete_selected(), "elimina selezione")
	_check(_editor.data["parts"].size() == parts_before + 1, "conteggio dopo elimina")
	_check(_editor.undo(), "undo")
	_check(_editor.data["parts"].size() == parts_before + 2, "conteggio dopo undo")
	_check(_editor.redo(), "redo")
	_check(_editor.data["parts"].size() == parts_before + 1, "conteggio dopo redo")

	# La scena ricostruita corrisponde ai dati.
	var serialized := LevelIO.serialize_world(_editor.world)
	serialized["meta"] = _editor.data["meta"]
	_check(
		serialized["parts"].size() == _editor.data["parts"].size(),
		"scena e dati hanno lo stesso numero di parti"
	)
	_check(LevelData.validate(serialized).is_empty(), "dati serializzati validi")

	# Salvataggio e ricaricamento.
	_check(LevelIO.save_to_path(TEST_PATH, _editor.data) == OK, "salvataggio file")
	var loaded := LevelIO.load_from_path(TEST_PATH)
	var normalized := LevelIO.from_json(LevelIO.to_json(_editor.data))
	_check(LevelIO.to_json(loaded) == LevelIO.to_json(normalized), "ricaricamento identico")
	DirAccess.remove_absolute(TEST_PATH)

	# Autosave.
	_editor._write_autosave()
	_check(FileAccess.file_exists(autosave), "autosave scritto")
	var restored := LevelIO.load_from_path(autosave)
	_check(not restored.is_empty(), "autosave rileggibile")
	DirAccess.remove_absolute(autosave)

	# Integrazione "Testa": l'editor passa il livello a main via play_request.
	LevelData.play_request = _editor.data.duplicate(true)
	_editor.queue_free()
	await process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	_check(main._test_mode, "main avviato in modalità test")
	_check(main._game_started, "partita avviata automaticamente in test")
	_check(main.character != null, "personaggio creato in test")
	LevelData.play_request = {}
	main.get_node("NetClient").stop()
	main.queue_free()
	await process_frame

	print("TEST_EDITOR_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	print("TEST %s: %s" % [label, condition])
	if not condition:
		_failures += 1
