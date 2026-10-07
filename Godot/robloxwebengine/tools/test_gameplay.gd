extends SceneTree
## Test automatico headless del gameplay: menu → Play → spawn → movimento →
## salto → moneta → checkpoint → morte nella lava → respawn → traguardo.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/test_gameplay.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame

	var menu: CanvasLayer = main.get_node("Menu")
	print("TEST menu visibile all'avvio: ", menu.visible)

	menu.play_pressed.emit()
	await process_frame

	var character = main.character
	print("TEST personaggio spawnato: ", character != null)
	if character == null:
		quit(1)
		return

	for i in 120:
		await physics_frame
	print("TEST pos dopo caduta: %.2f, %.2f, %.2f" % [character.global_position.x, character.global_position.y, character.global_position.z])
	print("TEST a terra: ", character.is_on_floor())

	var start: Vector3 = character.global_position
	Input.action_press("move_forward")
	for i in 60:
		await physics_frame
	Input.action_release("move_forward")
	var moved: float = (character.global_position - start).length()
	print("TEST distanza percorsa in 1s: %.2f" % moved)

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	print("TEST salto attivo: ", character.velocity.y > 0.0)

	print("TEST monete totali: ", main.coins_total)

	# Moneta: teletrasporta il personaggio su una moneta.
	var coin = get_nodes_in_group("collectibles")[0]
	character.global_position = coin.global_position
	for i in 5:
		await physics_frame
	print("TEST monete raccolte dopo contatto: ", main.coins_collected)

	# Checkpoint: teletrasporta sul primo checkpoint.
	var checkpoint = get_nodes_in_group("checkpoints")[0]
	character.global_position = checkpoint.global_position + Vector3(0, 0.5, 0)
	for i in 5:
		await physics_frame
	print("TEST respawn aggiornato al checkpoint: ", main.respawn_position.is_equal_approx(checkpoint.global_position + Vector3(0, 0.5, 0)))

	# Morte nella lava → respawn al checkpoint.
	var lava = main.get_node("World/Lava")
	character.global_position = lava.global_position
	for i in 30:
		await physics_frame
	var respawned = main.character
	print("TEST respawn dopo lava: ", respawned != null and respawned.global_position.distance_to(main.respawn_position) < 5.0)
	print("TEST salute ripristinata: ", respawned != null and is_equal_approx(respawned.health, PlayerCharacter.MAX_HEALTH))

	# Traguardo.
	respawned.global_position = Vector3(0, 13, -96)
	for i in 5:
		await physics_frame
	print("TEST traguardo raggiunto: ", main.goal_reached)

	quit(0)
