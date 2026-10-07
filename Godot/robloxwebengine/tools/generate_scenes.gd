extends SceneTree
## Generatore one-shot di tutte le scene di gioco (Fase 2).
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/generate_scenes.gd

const PART_FACTORY := preload("res://scripts/world/part_factory.gd")
const SPINNER_SCRIPT := preload("res://scripts/world/spinner.gd")
const MOVING_PLATFORM_SCRIPT := preload("res://scripts/world/moving_platform.gd")
const CHECKPOINT_SCRIPT := preload("res://scripts/world/checkpoint.gd")
const COLLECTIBLE_SCRIPT := preload("res://scripts/world/collectible.gd")
const GOAL_SCRIPT := preload("res://scripts/world/goal.gd")
const KILL_BRICK_SCRIPT := preload("res://scripts/world/kill_brick.gd")
const CHARACTER_SCRIPT := preload("res://scripts/player/character.gd")
const REMOTE_CHARACTER_SCRIPT := preload("res://scripts/player/remote_character.gd")
const CAMERA_RIG_SCRIPT := preload("res://scripts/player/camera_rig.gd")
const MENU_SCRIPT := preload("res://scripts/ui/menu.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MAIN_SCRIPT := preload("res://scripts/main.gd")
const NET_CLIENT_SCRIPT := preload("res://scripts/net/net_client.gd")

# Colori in stile Roblox (RGB 0-1)
const YELLOW := Color(0.96, 0.80, 0.19)
const TORSO_BLUE := Color(0.05, 0.41, 0.67)
const LEG_GREEN := Color(0.29, 0.59, 0.29)
const BASEPLATE_GREEN := Color(0.36, 0.56, 0.32)
const GRAY := Color(0.63, 0.64, 0.64)
const RED := Color(0.77, 0.16, 0.11)
const ORANGE := Color(0.96, 0.55, 0.16)
const GOLD := Color(0.90, 0.72, 0.15)
const CYAN := Color(0.24, 0.66, 0.79)
const LAVA_RED := Color(0.85, 0.12, 0.05)
const CHECKPOINT_OFF := Color(0.15, 0.45, 0.90)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://scenes/world")
	DirAccess.make_dir_recursive_absolute("res://scenes/player")
	DirAccess.make_dir_recursive_absolute("res://scenes/ui")

	_save_scene(_build_world(), "res://scenes/world/baseplate.tscn")
	_save_scene(_build_character(), "res://scenes/player/character.tscn")
	_save_scene(_build_remote_character(), "res://scenes/player/remote_character.tscn")
	_save_scene(_build_menu(), "res://scenes/ui/menu.tscn")
	_save_scene(_build_hud(), "res://scenes/ui/hud.tscn")
	_save_scene(_build_main(), "res://scenes/main.tscn")
	quit()


# --- Mondo ---------------------------------------------------------------------

func _build_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"

	world.add_child(_build_environment())

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	world.add_child(sun)

	# Baseplate e spawn.
	world.add_child(_part("Baseplate", Vector3(240, 1, 240), BASEPLATE_GREEN, Vector3(0, -0.5, 0)))
	world.add_child(_part("SpawnLocation", Vector3(10, 1, 10), GRAY, Vector3(0, 0.5, 12)))

	# Sezione A: salti semplici.
	world.add_child(_part("Platform1", Vector3(8, 1, 8), RED, Vector3(0, 2, 0)))
	world.add_child(_part("Platform2", Vector3(6, 1, 6), ORANGE, Vector3(4, 3.5, -10)))
	world.add_child(_part("Platform3", Vector3(6, 1, 6), CYAN, Vector3(-3, 5, -19)))

	# Sezione B: piattaforma con spinner + primo checkpoint.
	world.add_child(_part("SpinnerPlatform", Vector3(12, 1, 12), GRAY, Vector3(0, 6.5, -28)))
	var spinner := AnimatableBody3D.new()
	spinner.name = "Spinner"
	PART_FACTORY.decorate(spinner, Vector3(14, 0.8, 1), RED)
	spinner.position = Vector3(0, 7.9, -28)
	spinner.set_script(SPINNER_SCRIPT)
	world.add_child(spinner)

	world.add_child(_checkpoint("Checkpoint1", Vector3(8, 1, 8), Vector3(0, 6.5, -40)))

	# Sezione C: lago di lava attraversato con piattaforme mobili.
	world.add_child(_lava())
	world.add_child(_moving_platform("MovingPlatform1", Vector3(6, 1, 6), ORANGE, Vector3(-8, 7, -50), Vector3(16, 0, 0), 4.0))
	world.add_child(_part("LavaStep1", Vector3(4, 1, 4), GRAY, Vector3(0, 7.5, -58)))
	world.add_child(_moving_platform("Elevator", Vector3(4, 1, 4), CYAN, Vector3(5, 4, -62), Vector3(0, 5, 0), 3.0))
	world.add_child(_part("LavaStep2", Vector3(4, 1, 4), GRAY, Vector3(3, 8, -68)))
	world.add_child(_checkpoint("Checkpoint2", Vector3(8, 1, 8), Vector3(0, 8, -74)))

	# Sezione D: scalata finale verso il traguardo.
	world.add_child(_part("TowerStep1", Vector3(4, 1, 4), RED, Vector3(4, 9, -82)))
	world.add_child(_part("TowerStep2", Vector3(4, 1, 4), ORANGE, Vector3(-4, 10, -87)))
	world.add_child(_part("GoalPlatform", Vector3(12, 1, 12), GOLD, Vector3(0, 11.5, -96)))
	world.add_child(_part("GoalPillar", Vector3(2, 8, 2), GOLD, Vector3(0, 16, -96)))

	var goal_area := Area3D.new()
	goal_area.name = "Goal"
	goal_area.set_script(GOAL_SCRIPT)
	goal_area.add_to_group("goal", true)
	goal_area.position = Vector3(0, 15, -96)
	var goal_shape := BoxShape3D.new()
	goal_shape.size = Vector3(12, 8, 12)
	var goal_collision := CollisionShape3D.new()
	goal_collision.name = "Collision"
	goal_collision.shape = goal_shape
	goal_area.add_child(goal_collision)
	world.add_child(goal_area)

	var goal_label := Label3D.new()
	goal_label.name = "GoalLabel"
	goal_label.text = "TRAGUARDO"
	goal_label.font_size = 96
	goal_label.pixel_size = 0.012
	goal_label.outline_size = 20
	goal_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	goal_label.position = Vector3(0, 22, -96)
	world.add_child(goal_label)

	# Monete (10).
	var coin_positions: Array[Vector3] = [
		Vector3(4, 5.8, -10),
		Vector3(-3, 7.3, -19),
		Vector3(-4, 8.8, -28),
		Vector3(3, 8.8, -40),
		Vector3(0, 9.3, -50),
		Vector3(0, 9.8, -58),
		Vector3(5, 11.3, -62),
		Vector3(3, 10.3, -68),
		Vector3(0, 10.3, -74),
		Vector3(4, 11.3, -82),
	]
	for i in coin_positions.size():
		world.add_child(_collectible("Coin%d" % (i + 1), coin_positions[i]))

	# Decorazioni: pilastri e alberi a cubetti.
	world.add_child(_part("PillarLeft", Vector3(4, 10, 4), TORSO_BLUE, Vector3(-18, 5, 18)))
	world.add_child(_part("PillarRight", Vector3(4, 10, 4), LEG_GREEN, Vector3(18, 5, 18)))
	for tree_position in [
		Vector3(-30, 0, 20), Vector3(-45, 0, -5), Vector3(-28, 0, -32),
		Vector3(30, 0, 18), Vector3(42, 0, -15), Vector3(34, 0, -70),
		Vector3(-38, 0, -65), Vector3(50, 0, 30), Vector3(-55, 0, 40), Vector3(20, 0, 45),
	]:
		world.add_child(_tree(tree_position))

	# Parti libere: cadono e si impilano (demo fisica Jolt).
	world.add_child(_part("FreePart1", Vector3(2.5, 2.5, 2.5), RED, Vector3(14, 8, 4), false))
	world.add_child(_part("FreePart2", Vector3(2.5, 2.5, 2.5), CYAN, Vector3(15.5, 12, 5), false))
	world.add_child(_part("FreePart3", Vector3(2.5, 2.5, 2.5), GOLD, Vector3(13, 16, 3), false))

	return world


func _build_environment() -> WorldEnvironment:
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


# --- Personaggio ---------------------------------------------------------------

func _build_character() -> CharacterBody3D:
	var character := CharacterBody3D.new()
	character.name = "Character"
	character.set_script(CHARACTER_SCRIPT)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 5.0
	collision.shape = capsule
	collision.position = Vector3(0, 2.5, 0)
	character.add_child(collision)

	character.add_child(_build_visual_rig())

	# Suoni del personaggio.
	var jump_sound := AudioStreamPlayer3D.new()
	jump_sound.name = "JumpSound"
	jump_sound.max_distance = 60.0
	character.add_child(jump_sound)

	var land_sound := AudioStreamPlayer3D.new()
	land_sound.name = "LandSound"
	land_sound.max_distance = 60.0
	character.add_child(land_sound)

	# Camera in terzo persona (pivot + spring arm + camera).
	var camera_rig := Node3D.new()
	camera_rig.name = "CameraRig"
	camera_rig.top_level = true
	camera_rig.set_script(CAMERA_RIG_SCRIPT)
	character.add_child(camera_rig)

	var spring_arm := SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = 12.0
	camera_rig.add_child(spring_arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 70.0
	camera.near = 0.1
	camera.far = 1000.0
	camera.current = true
	spring_arm.add_child(camera)

	return character


func _build_remote_character() -> Node3D:
	var remote := Node3D.new()
	remote.name = "RemoteCharacter"
	remote.set_script(REMOTE_CHARACTER_SCRIPT)
	remote.add_child(_build_visual_rig())
	return remote


func _build_visual_rig() -> Node3D:
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.add_child(_box_mesh("Torso", Vector3(2, 2, 1), TORSO_BLUE, Vector3(0, 3, 0)))
	visual.add_child(_box_mesh("Head", Vector3(1.25, 1.25, 1.25), YELLOW, Vector3(0, 4.625, 0)))
	visual.add_child(_limb("ArmL", YELLOW, Vector3(-1.5, 4, 0)))
	visual.add_child(_limb("ArmR", YELLOW, Vector3(1.5, 4, 0)))
	visual.add_child(_limb("LegL", LEG_GREEN, Vector3(-0.5, 2, 0)))
	visual.add_child(_limb("LegR", LEG_GREEN, Vector3(0.5, 2, 0)))

	var name_tag := Label3D.new()
	name_tag.name = "NameTag"
	name_tag.text = "Giocatore"
	name_tag.font_size = 64
	name_tag.pixel_size = 0.01
	name_tag.outline_size = 16
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.position = Vector3(0, 6.2, 0)
	visual.add_child(name_tag)

	return visual


# --- UI --------------------------------------------------------------------------

func _build_menu() -> CanvasLayer:
	var menu := CanvasLayer.new()
	menu.name = "Menu"
	menu.set_script(MENU_SCRIPT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.07, 0.09, 0.13)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "ROBLOX WEB ENGINE"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "MVP — replica in-browser"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var play_button := Button.new()
	play_button.name = "PlayButton"
	play_button.text = "Play"
	play_button.add_theme_font_size_override("font_size", 32)
	play_button.custom_minimum_size = Vector2(260, 70)
	vbox.add_child(play_button)

	var name_input := LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Il tuo nome"
	name_input.max_length = 20
	name_input.add_theme_font_size_override("font_size", 20)
	name_input.custom_minimum_size = Vector2(260, 0)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_input)

	var controls := Label.new()
	controls.name = "Controls"
	controls.text = "WASD muoviti · Spazio salta · Tasto destro ruota la camera\nRotella zoom · Shift shift-lock · Invio chat"
	controls.add_theme_font_size_override("font_size", 16)
	controls.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls)

	return menu


func _build_hud() -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HUD_SCRIPT)

	var crosshair := ColorRect.new()
	crosshair.name = "Crosshair"
	crosshair.color = Color(1, 1, 1, 0.85)
	crosshair.size = Vector2(6, 6)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -3
	crosshair.offset_top = -3
	crosshair.offset_right = 3
	crosshair.offset_bottom = 3
	crosshair.visible = false
	hud.add_child(crosshair)

	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.anchor_left = 0.5
	health_bar.anchor_top = 1.0
	health_bar.anchor_right = 0.5
	health_bar.anchor_bottom = 1.0
	health_bar.offset_left = -110
	health_bar.offset_top = -44
	health_bar.offset_right = 110
	health_bar.offset_bottom = -16
	hud.add_child(health_bar)

	var coins := Label.new()
	coins.name = "Coins"
	coins.text = "Monete: 0 / 0"
	coins.add_theme_font_size_override("font_size", 22)
	coins.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	coins.offset_left = 14
	coins.offset_top = 12
	coins.offset_right = 320
	coins.offset_bottom = 42
	hud.add_child(coins)

	var message := Label.new()
	message.name = "Message"
	message.add_theme_font_size_override("font_size", 38)
	message.add_theme_color_override("font_color", Color(1, 1, 1))
	message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	message.add_theme_constant_override("outline_size", 10)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.anchor_right = 1.0
	message.offset_top = 80
	message.offset_bottom = 140
	message.modulate.a = 0.0
	hud.add_child(message)

	var fps := Label.new()
	fps.name = "FPS"
	fps.text = "-- FPS"
	fps.add_theme_font_size_override("font_size", 16)
	fps.anchor_left = 1.0
	fps.anchor_right = 1.0
	fps.offset_left = -110
	fps.offset_top = 12
	fps.offset_right = -12
	fps.offset_bottom = 36
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(fps)

	var players := Label.new()
	players.name = "Players"
	players.text = "Giocatori: 1"
	players.add_theme_font_size_override("font_size", 16)
	players.anchor_left = 1.0
	players.anchor_right = 1.0
	players.offset_left = -180
	players.offset_top = 36
	players.offset_right = -12
	players.offset_bottom = 60
	players.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(players)

	var chat_log := Label.new()
	chat_log.name = "ChatLog"
	chat_log.add_theme_font_size_override("font_size", 16)
	chat_log.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	chat_log.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	chat_log.add_theme_constant_override("outline_size", 6)
	chat_log.anchor_left = 0.0
	chat_log.anchor_top = 1.0
	chat_log.anchor_right = 0.0
	chat_log.anchor_bottom = 1.0
	chat_log.offset_left = 14
	chat_log.offset_top = -190
	chat_log.offset_right = 470
	chat_log.offset_bottom = -58
	chat_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hud.add_child(chat_log)

	var chat_input := LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.placeholder_text = "Scrivi... (Invio per inviare, Esc per annullare)"
	chat_input.max_length = 120
	chat_input.add_theme_font_size_override("font_size", 16)
	chat_input.anchor_left = 0.0
	chat_input.anchor_top = 1.0
	chat_input.anchor_right = 0.0
	chat_input.anchor_bottom = 1.0
	chat_input.offset_left = 14
	chat_input.offset_top = -50
	chat_input.offset_right = 470
	chat_input.offset_bottom = -20
	hud.add_child(chat_input)

	return hud


# --- Scena principale -------------------------------------------------------------

func _build_main() -> Node:
	var main := Node.new()
	main.name = "Main"
	main.set_script(MAIN_SCRIPT)

	var world := (load("res://scenes/world/baseplate.tscn") as PackedScene).instantiate()
	world.name = "World"
	main.add_child(world)

	var menu := (load("res://scenes/ui/menu.tscn") as PackedScene).instantiate()
	menu.name = "Menu"
	main.add_child(menu)

	var hud := (load("res://scenes/ui/hud.tscn") as PackedScene).instantiate()
	hud.name = "HUD"
	hud.visible = false
	main.add_child(hud)

	var global_sound := AudioStreamPlayer.new()
	global_sound.name = "GlobalSound"
	main.add_child(global_sound)

	var net := Node.new()
	net.name = "NetClient"
	net.set_script(NET_CLIENT_SCRIPT)
	main.add_child(net)

	return main


# --- Parti speciali ----------------------------------------------------------------

func _checkpoint(node_name: String, size: Vector3, position: Vector3) -> Area3D:
	var check := Area3D.new()
	check.name = node_name
	check.set_script(CHECKPOINT_SCRIPT)
	check.add_to_group("checkpoints", true)
	check.position = position

	# Materiale condiviso: cambia colore insieme su piattaforma e piastra.
	var material := StandardMaterial3D.new()
	material.albedo_color = CHECKPOINT_OFF
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


func _collectible(node_name: String, position: Vector3) -> Area3D:
	var coin := Area3D.new()
	coin.name = node_name
	coin.set_script(COLLECTIBLE_SCRIPT)
	coin.add_to_group("collectibles", true)
	coin.position = position

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
	material.albedo_color = Color(0.98, 0.82, 0.22)
	material.roughness = 0.35
	material.metallic = 0.4
	mesh.material_override = material
	mesh.rotation_degrees = Vector3(90, 0, 0)
	visual.add_child(mesh)

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 3.2, 2.4)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	coin.add_child(collision)

	var sound := AudioStreamPlayer3D.new()
	sound.name = "Sound"
	sound.max_distance = 40.0
	coin.add_child(sound)

	return coin


func _lava() -> Area3D:
	var lava := Area3D.new()
	lava.name = "Lava"
	lava.set_script(KILL_BRICK_SCRIPT)
	lava.position = Vector3(0, 2.0, -67)

	var shape := BoxShape3D.new()
	shape.size = Vector3(40, 4, 46)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	lava.add_child(collision)

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = Vector3(40, 1, 46)
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = LAVA_RED
	material.emission_enabled = true
	material.emission = Color(0.9, 0.25, 0.05)
	material.emission_energy_multiplier = 0.6
	mesh.material_override = material
	mesh.position = Vector3(0, -1.5, 0)
	lava.add_child(mesh)

	return lava


func _moving_platform(node_name: String, size: Vector3, color: Color, position: Vector3, offset: Vector3, duration: float) -> AnimatableBody3D:
	var platform := AnimatableBody3D.new()
	platform.name = node_name
	platform.set_script(MOVING_PLATFORM_SCRIPT)
	PART_FACTORY.decorate(platform, size, color)
	platform.position = position
	platform.set("offset", offset)
	platform.set("duration", duration)
	return platform


func _tree(position: Vector3) -> Node3D:
	var tree := Node3D.new()
	tree.name = "Tree"
	tree.position = position
	var trunk := PART_FACTORY.make_part(Vector3(1, 4, 1), Color(0.45, 0.30, 0.16), true)
	trunk.name = "Trunk"
	trunk.position = Vector3(0, 2, 0)
	tree.add_child(trunk)
	tree.add_child(_box_mesh("Leaves", Vector3(4.5, 3.5, 4.5), Color(0.13, 0.42, 0.16), Vector3(0, 5.5, 0)))
	return tree


# --- Helper --------------------------------------------------------------------

func _part(node_name: String, size: Vector3, color: Color, position: Vector3, anchored := true) -> Node3D:
	var part := PART_FACTORY.make_part(size, color, anchored)
	part.name = node_name
	part.position = position
	return part


func _box_mesh(node_name: String, size: Vector3, color: Color, position: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	mesh.position = position
	return mesh


func _limb(node_name: String, color: Color, pivot: Vector3) -> Node3D:
	var limb := Node3D.new()
	limb.name = node_name
	limb.position = pivot
	limb.add_child(_box_mesh("Mesh", Vector3(1, 2, 1), color, Vector3(0, -1, 0)))
	return limb


func _save_scene(root: Node, path: String) -> void:
	_set_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack() fallita per %s: %d" % [path, err])
		return
	err = ResourceSaver.save(packed, path)
	print("SCENA_SALVATA %s err=%d" % [path, err])


func _set_owners(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.scene_file_path.is_empty():
			_set_owners(child, scene_root)
