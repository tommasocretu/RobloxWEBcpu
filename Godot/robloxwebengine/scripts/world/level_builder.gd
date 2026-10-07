class_name LevelBuilder
extends RefCounted
## Costruisce la scena 3D di un livello partendo dai dati (vedi LevelData / LevelIO).
## Riutilizza PartFactory e gli script delle parti speciali del gioco.

const PART_FACTORY := preload("res://scripts/world/part_factory.gd")
const SPINNER_SCRIPT := preload("res://scripts/world/spinner.gd")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/world/moving_platform.gd")
const CHECKPOINT_SCRIPT := preload("res://scripts/world/checkpoint.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/world/collectible.gd")
const GOAL_SCRIPT := preload("res://scripts/world/goal.gd")
const KILL_BRICK_SCRIPT := preload("res://scripts/world/kill_brick.gd")

const COIN_COLOR := Color(0.98, 0.82, 0.22)
const LAVA_EMISSION := Color(0.9, 0.25, 0.05)


static func build_into(world: Node3D, data: Dictionary) -> void:
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	world.add_child(build_environment())
	world.add_child(build_sun())
	for entity in data.get("parts", []):
		if typeof(entity) != TYPE_DICTIONARY:
			continue
		var node := build_entity(entity)
		if node:
			world.add_child(node)


static func build_environment() -> WorldEnvironment:
	var environment := WorldEnvironment.new()
	environment.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.19, 0.38, 0.75)
	sky_material.sky_horizon_color = Color(0.64, 0.79, 0.90)
	sky_material.ground_bottom_color = Color(0.30, 0.34, 0.30)
	sky_material.ground_horizon_color = Color(0.64, 0.79, 0.90)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	environment.environment = env
	return environment


static func build_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	return sun


static func build_entity(entity: Dictionary) -> Node3D:
	var kind := str(entity.get("kind", "part"))
	var node: Node3D
	match kind:
		"checkpoint":
			node = _build_checkpoint(entity)
		"coin":
			node = _build_coin(entity)
		"goal":
			node = _build_goal(entity)
		"kill":
			node = _build_kill(entity)
		"moving_platform":
			node = _build_moving_platform(entity)
		"spinner":
			node = _build_spinner(entity)
		"label":
			node = _build_label(entity)
		_:
			node = _build_part(entity)
	_apply_common(node, entity)
	return node


static func _apply_common(node: Node3D, entity: Dictionary) -> void:
	node.name = str(entity.get("name", "Part"))
	node.position = LevelData.array_to_vec3(entity.get("position", []), Vector3.ZERO)
	node.rotation_degrees = LevelData.array_to_vec3(entity.get("rotation", []), Vector3.ZERO)
	node.set_meta("level_id", str(entity.get("id", "")))


# --- Parti semplici -------------------------------------------------------------

static func _build_part(entity: Dictionary) -> Node3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(4, 1, 4))
	var color := LevelData.hex_to_color(entity.get("color", ""), Color(0.63, 0.64, 0.64))
	var anchored := bool(entity.get("anchored", true))
	var body := PART_FACTORY.make_part(size, color, anchored) as Node3D
	_apply_transparency(body, float(entity.get("transparency", 0.0)))
	if not bool(entity.get("collide", true)):
		var collision := body.get_node_or_null("Collision") as CollisionShape3D
		if collision:
			collision.disabled = true
	if str(entity.get("kind", "")) == "spawn":
		body.add_to_group("spawn", true)
	return body


static func _build_checkpoint(entity: Dictionary) -> Area3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(8, 1, 8))
	var check := Area3D.new()
	check.set_script(CHECKPOINT_SCRIPT)
	check.add_to_group("checkpoints", true)

	# Materiale condiviso: pad e piattaforma cambiano colore insieme.
	var color := LevelData.hex_to_color(entity.get("color", ""), Color(0.15, 0.45, 0.90))
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85

	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(size.x, size.y + 5.0, size.z)
	var area_collision := CollisionShape3D.new()
	area_collision.name = "Collision"
	area_collision.shape = area_shape
	area_collision.position = Vector3(0, 2.5, 0)
	check.add_child(area_collision)

	var platform := StaticBody3D.new()
	platform.name = "Platform"
	var platform_mesh := MeshInstance3D.new()
	platform_mesh.name = "PlatformMesh"
	var platform_box := BoxMesh.new()
	platform_box.size = size
	platform_mesh.mesh = platform_box
	platform_mesh.material_override = material
	platform.add_child(platform_mesh)
	var platform_collision := CollisionShape3D.new()
	platform_collision.name = "PlatformCollision"
	var platform_shape := BoxShape3D.new()
	platform_shape.size = size
	platform_collision.shape = platform_shape
	platform.add_child(platform_collision)
	check.add_child(platform)

	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	var pad_box := BoxMesh.new()
	pad_box.size = Vector3(size.x - 2.0, 0.2, size.z - 2.0)
	pad.mesh = pad_box
	pad.material_override = material
	pad.position = Vector3(0, size.y * 0.5 - 0.08, 0)
	check.add_child(pad)

	var sound := AudioStreamPlayer3D.new()
	sound.name = "Sound"
	sound.max_distance = 50.0
	check.add_child(sound)

	return check


static func _build_coin(entity: Dictionary) -> Area3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(2.4, 3.2, 2.4))
	var color := LevelData.hex_to_color(entity.get("color", ""), COIN_COLOR)
	var coin := Area3D.new()
	coin.set_script(COLLECTIBLE_SCRIPT)
	coin.add_to_group("collectibles", true)

	var visual := Node3D.new()
	visual.name = "Visual"
	coin.add_child(visual)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.1
	cylinder.bottom_radius = 1.1
	cylinder.height = 0.35
	mesh.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.35
	material.metallic = 0.4
	mesh.material_override = material
	mesh.rotation_degrees = Vector3(90, 0, 0)
	visual.add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	coin.add_child(collision)

	var sound := AudioStreamPlayer3D.new()
	sound.name = "Sound"
	sound.max_distance = 40.0
	coin.add_child(sound)

	return coin


static func _build_goal(entity: Dictionary) -> Area3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(12, 8, 12))
	var goal := Area3D.new()
	goal.set_script(GOAL_SCRIPT)
	goal.add_to_group("goal", true)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	goal.add_child(collision)
	return goal


static func _build_kill(entity: Dictionary) -> Area3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(12, 4, 12))
	var color := LevelData.hex_to_color(entity.get("color", ""), Color(0.85, 0.12, 0.05))
	var props: Dictionary = entity.get("props", {})
	var mesh_offset := LevelData.array_to_vec3(props.get("mesh_offset", []), Vector3(0, -1.5, 0))

	var lava := Area3D.new()
	lava.set_script(KILL_BRICK_SCRIPT)
	lava.add_to_group("kill", true)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	lava.add_child(collision)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 1, size.z)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = LAVA_EMISSION
	material.emission_energy_multiplier = 0.6
	mesh.material_override = material
	mesh.position = mesh_offset
	lava.add_child(mesh)

	return lava


static func _build_moving_platform(entity: Dictionary) -> AnimatableBody3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(6, 1, 6))
	var color := LevelData.hex_to_color(entity.get("color", ""), Color(0.96, 0.55, 0.16))
	var props: Dictionary = entity.get("props", {})
	var platform := AnimatableBody3D.new()
	platform.set_script(MOVING_PLATFORM_SCRIPT)
	PART_FACTORY.decorate(platform, size, color)
	platform.set("offset", LevelData.array_to_vec3(props.get("offset", []), Vector3(8, 0, 0)))
	platform.set("duration", float(props.get("duration", 4.0)))
	return platform


static func _build_spinner(entity: Dictionary) -> AnimatableBody3D:
	var size := LevelData.array_to_vec3(entity.get("size", []), Vector3(14, 0.8, 1))
	var color := LevelData.hex_to_color(entity.get("color", ""), Color(0.77, 0.16, 0.11))
	var props: Dictionary = entity.get("props", {})
	var spinner := AnimatableBody3D.new()
	spinner.set_script(SPINNER_SCRIPT)
	PART_FACTORY.decorate(spinner, size, color)
	spinner.set("rotation_speed_degrees", float(props.get("speed", 90.0)))
	return spinner


static func _build_label(entity: Dictionary) -> Label3D:
	var props: Dictionary = entity.get("props", {})
	var label := Label3D.new()
	label.text = str(props.get("text", "Testo"))
	label.font_size = int(props.get("font_size", 96))
	label.pixel_size = float(props.get("pixel_size", 0.012))
	label.outline_size = 20
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label


static func _apply_transparency(node: Node3D, value: float) -> void:
	var clamped := clampf(value, 0.0, 0.95)
	if clamped <= 0.0:
		return
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		return
	var color := material.albedo_color
	color.a = 1.0 - clamped
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
