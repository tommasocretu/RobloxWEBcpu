extends SceneTree
## Tool one-shot: converte res://scenes/world/baseplate.tscn in res://levels/default.rwl.json.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/export_default_level.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/world/baseplate.tscn") as PackedScene
	if scene == null:
		push_error("export_default_level: scena baseplate non trovata")
		quit(1)
		return
	var world := scene.instantiate() as Node3D
	var data := LevelIO.serialize_world(world)
	data["meta"] = {
		"title": "Obby predefinito",
		"author": "RobloxWebEngine",
		"description": "Il livello di esempio originale, remixabile con l'editor.",
	}
	var err := LevelIO.save_to_path(LevelIO.DEFAULT_LEVEL_PATH, data)
	var errors := LevelData.validate(data)
	print("DEFAULT_LEVEL_EXPORT err=%d parti=%d errori=%d" % [err, data["parts"].size(), errors.size()])
	for message in errors:
		print("  - ", message)
	world.free()
	quit(0 if err == OK and errors.is_empty() else 1)
