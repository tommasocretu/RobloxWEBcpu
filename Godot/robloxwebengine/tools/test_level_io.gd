extends SceneTree
## Test headless del formato livello: validazione, roundtrip scena ↔ dati, JSON e file.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_level_io.gd

const TEST_PATH := "user://test_level_io.rwl.json"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(LevelIO.has_default_level(), "livello predefinito presente")
	var default_data := LevelIO.load_default()
	if default_data.is_empty():
		print("TEST_LEVEL_IO_FAIL (esegui prima tools/export_default_level.gd)")
		quit(1)
		return

	var errors := LevelData.validate(default_data)
	_check(errors.is_empty(), "validazione livello predefinito (%d errori)" % errors.size())
	for message in errors:
		print("  - ", message)

	# Scena → dati → scena → dati (normalizzato come un salvataggio su file).
	var world := Node3D.new()
	root.add_child(world)
	LevelBuilder.build_into(world, default_data)
	var rebuilt := LevelIO.serialize_world(world, default_data.get("scripts", []))
	rebuilt["meta"] = default_data["meta"]
	rebuilt = LevelIO.from_json(LevelIO.to_json(rebuilt))
	var json_a := LevelIO.to_json(default_data)
	var json_b := LevelIO.to_json(rebuilt)
	_check(json_a == json_b, "roundtrip scena ↔ dati")
	if json_a != json_b:
		_print_first_diff(json_a, json_b)
	world.free()

	# JSON → dati.
	var parsed := LevelIO.from_json(json_a)
	_check(LevelIO.to_json(parsed) == json_a, "roundtrip JSON")

	# File.
	_check(LevelIO.save_to_path(TEST_PATH, default_data) == OK, "scrittura file di test")
	var from_file := LevelIO.load_from_path(TEST_PATH)
	_check(LevelIO.to_json(from_file) == json_a, "roundtrip file")
	DirAccess.remove_absolute(TEST_PATH)

	# Validazione: casi negativi.
	var bad := LevelData.new_level()
	bad["parts"][0]["kind"] = "boh"
	_check(LevelData.validate(bad).size() > 0, "rifiuta tipo sconosciuto")
	bad = LevelData.new_level()
	bad["parts"][0]["name"] = bad["parts"][1]["name"]
	_check(LevelData.validate(bad).size() > 0, "rifiuta nomi duplicati")
	bad = LevelData.new_level()
	bad["format"] = "altro"
	_check(LevelData.validate(bad).size() > 0, "rifiuta formato sconosciuto")
	_check(LevelData.validate("non un oggetto").size() > 0, "rifiuta JSON non oggetto")

	# v1 retrocompatibile e script.
	var old := LevelData.new_level()
	old["version"] = 1
	old["scripts"] = []
	_check(LevelData.validate(old).is_empty(), "accetta v1 senza script")
	old["scripts"] = [{"id": "s1", "name": "Vecchio", "parent_id": "",
		"enabled": true, "source": "print('x')"}]
	_check(not LevelData.validate(old).is_empty(), "rifiuta script in v1")
	var with_script := LevelData.new_level()
	with_script["scripts"] = [{"id": "s1", "name": "Nuovo", "parent_id": "p1",
		"enabled": true, "source": "print('x')"}]
	_check(LevelData.validate(with_script).is_empty(), "accetta script v2")

	print("TEST_LEVEL_IO_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	print("TEST %s: %s" % [label, condition])
	if not condition:
		_failures += 1


func _print_first_diff(a: String, b: String) -> void:
	var lines_a := a.split("\n")
	var lines_b := b.split("\n")
	for i in range(mini(lines_a.size(), lines_b.size())):
		if lines_a[i] != lines_b[i]:
			print("  diff riga %d:\n    atteso: %s\n    trovato: %s" % [i + 1, lines_a[i], lines_b[i]])
			return
	print("  diff: lunghezze %d vs %d" % [lines_a.size(), lines_b.size()])
