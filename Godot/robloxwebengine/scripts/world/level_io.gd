class_name LevelIO
extends RefCounted
## Lettura/scrittura dei livelli: JSON (`.rwl.json`) e conversione scena ↔ dati.
## La scena → dati è usata per convertire il livello predefinito e per i test.

const DEFAULT_LEVEL_PATH := "res://levels/default.rwl.json"


# --- JSON e file ----------------------------------------------------------------

static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ", true)


static func from_json(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LevelIO: il file non contiene un oggetto JSON.")
		return {}
	return parsed


static func save_to_path(path: String, data: Dictionary) -> Error:
	var dir := path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var err := FileAccess.get_open_error()
		push_error("LevelIO: impossibile scrivere %s (err %d)" % [path, err])
		return err
	file.store_string(to_json(data))
	file.close()
	return OK


static func load_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	return from_json(text)


static func has_default_level() -> bool:
	return FileAccess.file_exists(DEFAULT_LEVEL_PATH)


static func load_default() -> Dictionary:
	return load_from_path(DEFAULT_LEVEL_PATH)


# --- Scena → dati ----------------------------------------------------------------

static func serialize_world(world: Node3D) -> Dictionary:
	var parts: Array = []
	var index := 0
	for child in world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			continue
		var entity := serialize_entity(child)
		if entity.is_empty():
			continue
		index += 1
		entity["id"] = "p%d" % index
		parts.append(entity)
	return {
		"format": LevelData.FORMAT,
		"version": LevelData.VERSION,
		"meta": {},
		"parts": parts,
		"scripts": [],
	}


static func serialize_entity(node: Node) -> Dictionary:
	if node is SpinnerPart:
		return _serialize_spinner(node)
	if node is MovingPlatform:
		return _serialize_moving_platform(node)
	if node is Checkpoint:
		return _serialize_checkpoint(node)
	if node is Collectible:
		return _serialize_coin(node)
	if node is GoalZone:
		return _serialize_goal(node)
	if node is KillBrick:
		return _serialize_kill(node)
	if node is Label3D:
		return _serialize_label(node)
	if node is StaticBody3D or node is RigidBody3D:
		return _serialize_part(node)
	return {}


static func _base(kind: String, node: Node3D, size: Vector3, color: Color) -> Dictionary:
	var entity := LevelData.make_entity(kind, str(node.name), node.position, size, color)
	entity["rotation"] = LevelData.vec3_array(node.rotation_degrees)
	return entity


static func _serialize_part(node: Node3D) -> Dictionary:
	var size := Vector3(1, 1, 1)
	var color := Color.WHITE
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		if mesh.mesh is BoxMesh:
			size = (mesh.mesh as BoxMesh).size
		if mesh.material_override is StandardMaterial3D:
			color = (mesh.material_override as StandardMaterial3D).albedo_color
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	var kind := "part"
	if node.is_in_group("spawn") or str(node.name) == "SpawnLocation":
		kind = "spawn"
	var entity := _base(kind, node, size, color)
	entity["anchored"] = node is StaticBody3D
	entity["collide"] = collision == null or not collision.disabled
	entity["transparency"] = snappedf(1.0 - color.a, 0.001)
	return entity


static func _serialize_checkpoint(node: Checkpoint) -> Dictionary:
	var size := Vector3(8, 1, 8)
	var color := Color(0.15, 0.45, 0.90)
	var mesh := node.get_node_or_null("Platform/PlatformMesh") as MeshInstance3D
	if mesh:
		if mesh.mesh is BoxMesh:
			size = (mesh.mesh as BoxMesh).size
		if mesh.material_override is StandardMaterial3D:
			color = (mesh.material_override as StandardMaterial3D).albedo_color
	return _base("checkpoint", node, size, color)


static func _serialize_coin(node: Collectible) -> Dictionary:
	var size := Vector3(2.4, 3.2, 2.4)
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		size = (collision.shape as BoxShape3D).size
	var color := LevelBuilder.COIN_COLOR
	var mesh := node.get_node_or_null("Visual/Mesh") as MeshInstance3D
	if mesh and mesh.material_override is StandardMaterial3D:
		color = (mesh.material_override as StandardMaterial3D).albedo_color
	return _base("coin", node, size, color)


static func _serialize_goal(node: GoalZone) -> Dictionary:
	var size := Vector3(12, 8, 12)
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		size = (collision.shape as BoxShape3D).size
	return _base("goal", node, size, Color.WHITE)


static func _serialize_kill(node: KillBrick) -> Dictionary:
	var size := Vector3(12, 4, 12)
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		size = (collision.shape as BoxShape3D).size
	var color := Color(0.85, 0.12, 0.05)
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.material_override is StandardMaterial3D:
		color = (mesh.material_override as StandardMaterial3D).albedo_color
	var entity := _base("kill", node, size, color)
	var mesh_offset := Vector3(0, -1.5, 0)
	if mesh:
		mesh_offset = mesh.position
	entity["props"] = {"mesh_offset": LevelData.vec3_array(mesh_offset)}
	return entity


static func _serialize_moving_platform(node: MovingPlatform) -> Dictionary:
	var size := Vector3(6, 1, 6)
	var color := Color(0.96, 0.55, 0.16)
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		if mesh.mesh is BoxMesh:
			size = (mesh.mesh as BoxMesh).size
		if mesh.material_override is StandardMaterial3D:
			color = (mesh.material_override as StandardMaterial3D).albedo_color
	var entity := _base("moving_platform", node, size, color)
	var offset: Vector3 = node.get("offset")
	entity["props"] = {
		"offset": LevelData.vec3_array(offset),
		"duration": snappedf(float(node.get("duration")), 0.001),
	}
	return entity


static func _serialize_spinner(node: SpinnerPart) -> Dictionary:
	var size := Vector3(14, 0.8, 1)
	var color := Color(0.77, 0.16, 0.11)
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh:
		if mesh.mesh is BoxMesh:
			size = (mesh.mesh as BoxMesh).size
		if mesh.material_override is StandardMaterial3D:
			color = (mesh.material_override as StandardMaterial3D).albedo_color
	var entity := _base("spinner", node, size, color)
	entity["props"] = {"speed": snappedf(float(node.get("rotation_speed_degrees")), 0.001)}
	return entity


static func _serialize_label(node: Label3D) -> Dictionary:
	var entity := _base("label", node, Vector3.ZERO, Color.WHITE)
	entity["props"] = {
		"text": node.text,
		"font_size": snappedf(float(node.font_size), 0.001),
		"pixel_size": snappedf(node.pixel_size, 0.000001),
	}
	return entity
