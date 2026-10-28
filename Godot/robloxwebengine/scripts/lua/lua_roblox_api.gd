class_name LuaRobloxAPI
extends RefCounted
## Ponte tra Lua e il mondo Godot: proprietà delle parti, `Instance.new`,
## `Touched`/`TouchEnded`, `workspace`, `game:GetService` e wrapper Humanoid.
## Solo le proprietà/metodi whitelisted sono raggiungibili dal sandbox.

const INSTANCE_LIMIT := 500
const STRING_METHODS := [
	"len", "sub", "upper", "lower", "rep", "find", "gsub", "format",
]
const NODE_METHODS := ["Destroy", "FindFirstChild", "GetChildren"]
const SIGNAL_METHODS := ["Connect", "Once", "Disconnect"]
const GAME_METHODS := ["GetService"]
const HUMANOID_METHODS := ["TakeDamage", "FindFirstChild", "Destroy"]


class LuaGame extends RefCounted:
	var runtime = null

	func _init(host) -> void:
		runtime = host


class LuaHumanoid extends RefCounted:
	var character = null

	func _init(player_character) -> void:
		character = player_character


class LuaSignal extends RefCounted:
	var owner = null
	var signal_name := "Touched"
	var runtime = null
	var sensor: Area3D = null
	var connections: Array = []
	var meta_key := ""

	func connect_function(lua_function, vm, once := false) -> bool:
		if not LuaValues.is_callable(lua_function):
			return false
		connections.append({"fn": lua_function, "vm": vm, "once": once})
		return true

	func disconnect_all() -> void:
		connections.clear()

	func emit(value) -> void:
		if connections.is_empty():
			return
		var pending: Array = connections.duplicate()
		for connection in pending:
			if connection["once"]:
				connections.erase(connection)
			if runtime and is_instance_valid(runtime):
				runtime.dispatch(connection["vm"], connection["fn"], [value], signal_name)

	func clear() -> void:
		connections.clear()
		if sensor != null and is_instance_valid(sensor) and not sensor.is_queued_for_deletion():
			sensor.queue_free()
			sensor = null
		if owner != null and is_instance_valid(owner) and meta_key != ""\
				and owner.has_meta(meta_key) and owner.get_meta(meta_key) == self:
			owner.remove_meta(meta_key)

	func _on_body_entered(body: Node) -> void:
		if body == owner:
			return
		emit(body)

	func _on_body_exited(body: Node) -> void:
		if body == owner:
			return
		emit(body)


static func new_instance(vm: LuaVM, type_name: String) -> Dictionary:
	if vm.host == null:
		return {"ok": false, "error": "runtime non disponibile"}
	if vm.host.instance_count() >= INSTANCE_LIMIT:
		return {"ok": false, "error": "limite di %d istanze raggiunto" % INSTANCE_LIMIT}
	match type_name:
		"Part":
			var body := RigidBody3D.new()
			body.name = "Part"
			body.freeze = true
			PartFactory.decorate(body, Vector3(4, 1, 4), Color(0.63, 0.64, 0.64))
			body.set_meta("lua_runtime_instance", true)
			body.set_meta("lua_anchored", true)
			vm.host.track_instance(body)
			return {"ok": true, "value": body}
		"Folder", "Model":
			var node := Node3D.new()
			node.name = type_name
			node.set_meta("lua_runtime_instance", true)
			vm.host.track_instance(node)
			return {"ok": true, "value": node}
	return {"ok": false, "error": "Instance.new: classe non supportata \"%s\"" % type_name}


static func get_property(target, key, vm: LuaVM) -> Dictionary:
	if key == null:
		return {"ok": false}
	if target is LuaGame:
		if key is String and key == "Workspace":
			return {"ok": true, "value": vm.host.world if vm.host else null}
		if key is String and GAME_METHODS.has(key):
			return {"ok": true, "value": LuaValues.Method.new(target, key)}
		return {"ok": false}
	if target is LuaHumanoid:
		if key is String and HUMANOID_METHODS.has(key):
			return {"ok": true, "value": LuaValues.Method.new(target, key)}
		return _humanoid_property(target, key)
	if target is LuaSignal:
		if key is String and SIGNAL_METHODS.has(key):
			return {"ok": true, "value": LuaValues.Method.new(target, key)}
		return {"ok": false}
	if target is String:
		if key is String and STRING_METHODS.has(key):
			return {"ok": true, "value": LuaValues.Method.new(target, key)}
		return {"ok": false}
	if target is Vector3:
		match str(key):
			"x":
				return {"ok": true, "value": target.x}
			"y":
				return {"ok": true, "value": target.y}
			"z":
				return {"ok": true, "value": target.z}
			"Magnitude":
				return {"ok": true, "value": target.length()}
			"Unit":
				return {"ok": true, "value": target.normalized()}
		return {"ok": false}
	if target is Color:
		match str(key):
			"r":
				return {"ok": true, "value": target.r}
			"g":
				return {"ok": true, "value": target.g}
			"b":
				return {"ok": true, "value": target.b}
		return {"ok": false}
	if target is Object:
		return _node_property(target, key, vm)
	return {"ok": false}


static func set_property(target, key, value, vm: LuaVM) -> bool:
	if target is LuaHumanoid:
		if str(key) == "Health":
			target.character.set_health(float(LuaValues.as_number(value)))
			return true
		return false
	if target is Object:
		return _node_set(target, str(key), value)
	return false


static func call_method(target, method_name: String, args: Array, vm: LuaVM) -> Dictionary:
	if target is LuaGame:
		if method_name == "GetService":
			var service_name := LuaValues.to_text(args[0]) if not args.is_empty() else ""
			if service_name == "Workspace":
				return {"ok": true, "values": [vm.host.world if vm.host else null]}
			return {"ok": true, "values": [null]}
		return {"ok": false, "error": "metodo game sconosciuto: %s" % method_name}
	if target is LuaHumanoid:
		match method_name:
			"TakeDamage":
				var amount := LuaValues.as_number(args[0]) if not args.is_empty() else 0.0
				target.character.take_damage(float(amount))
				return {"ok": true, "values": []}
			"FindFirstChild":
				var wanted := LuaValues.to_text(args[0]) if not args.is_empty() else ""
				if wanted == "HumanoidRootPart":
					return {"ok": true, "values": [target.character]}
				if wanted == "Humanoid":
					return {"ok": true, "values": [target]}
				return {"ok": true, "values": [null]}
			"Destroy":
				target.character.queue_free()
				return {"ok": true, "values": []}
		return {"ok": false, "error": "metodo Humanoid sconosciuto: %s" % method_name}
	if target is LuaSignal:
		match method_name:
			"Connect", "Once":
				if args.is_empty():
					return {"ok": false, "error": "%s richiede una funzione" % method_name}
				var connected: bool = target.connect_function(args[0], vm, method_name == "Once")
				if not connected:
					return {"ok": false, "error": "connessione non valida"}
				return {"ok": true, "values": [true]}
			"Disconnect":
				target.disconnect_all()
				return {"ok": true, "values": []}
		return {"ok": false, "error": "metodo segnale sconosciuto: %s" % method_name}
	if target is String:
		return LuaStdlib.call_string_method(method_name, target, args)
	if target is Object:
		return _node_method(target, method_name, args, vm)
	return {"ok": false, "error": "metodo non disponibile su %s" % LuaValues.type_name(target)}


# --- Nodi ----------------------------------------------------------------------

static func _node_property(node: Object, key, vm: LuaVM) -> Dictionary:
	if not (key is String):
		return {"ok": false}
	var name := str(key)
	if name == "Touched" or name == "TouchEnded":
		return {"ok": true, "value": _get_signal(node, name, vm)}
	if NODE_METHODS.has(name):
		return {"ok": true, "value": LuaValues.Method.new(node, name)}
	if node is PlayerCharacter:
		if name == "Humanoid":
			return {"ok": true, "value": LuaHumanoid.new(node)}
	if name == "Name":
		if node.has_meta("lua_name"):
			return {"ok": true, "value": str(node.get_meta("lua_name"))}
		return {"ok": true, "value": str(node.name)}
	if name == "Parent":
		return {"ok": true, "value": node.get_parent()}
	if name == "ClassName":
		if node is RigidBody3D or node is StaticBody3D or node is AnimatableBody3D:
			return {"ok": true, "value": "Part"}
		return {"ok": true, "value": str(node.get_class())}
	if name == "Position":
		if node is Node3D:
			return {"ok": true, "value": (node as Node3D).position}
		return {"ok": true, "value": Vector3.ZERO}
	if name == "Rotation":
		if node is Node3D:
			return {"ok": true, "value": (node as Node3D).rotation_degrees}
		return {"ok": true, "value": Vector3.ZERO}
	if name == "Size":
		return {"ok": true, "value": _get_size(node)}
	if name == "Color":
		return {"ok": true, "value": _get_color(node)}
	if name == "Transparency":
		return {"ok": true, "value": 1.0 - _get_color(node).a}
	if name == "Anchored":
		return {"ok": true, "value": _is_anchored(node)}
	if name == "Collide" or name == "CanCollide":
		var collision := node.get_node_or_null("Collision") as CollisionShape3D
		return {"ok": true, "value": collision == null or not collision.disabled}
	if name == "Velocity":
		if node is RigidBody3D:
			return {"ok": true, "value": (node as RigidBody3D).linear_velocity}
		return {"ok": true, "value": Vector3.ZERO}
	return {"ok": false}


static func _node_set(node: Object, key: String, value) -> bool:
	match key:
		"Name":
			var text := LuaValues.to_text(value).strip_edges()
			if text != "":
				node.name = text
			return true
		"Parent":
			return _set_parent(node, value)
		"Position":
			if node is Node3D:
				(node as Node3D).position = LuaValues.to_vec3(value)
			return true
		"Rotation":
			if node is Node3D:
				(node as Node3D).rotation_degrees = LuaValues.to_vec3(value)
			return true
		"Size":
			_set_size(node, LuaValues.to_vec3(value))
			return true
		"Color":
			_set_color(node, LuaValues.to_color(value))
			return true
		"Transparency":
			var color := _get_color(node)
			color.a = 1.0 - clampf(LuaValues.as_number(value), 0.0, 0.95)
			_set_color(node, color)
			return true
		"Anchored":
			var anchored := LuaValues.truthy(value)
			if node is RigidBody3D:
				(node as RigidBody3D).freeze = anchored
			node.set_meta("lua_anchored", anchored)
			return true
		"Collide", "CanCollide":
			var collision := node.get_node_or_null("Collision") as CollisionShape3D
			if collision:
				collision.disabled = not LuaValues.truthy(value)
			return true
		"Velocity":
			if node is RigidBody3D:
				(node as RigidBody3D).linear_velocity = LuaValues.to_vec3(value)
			return true
	return false


static func _node_method(node: Object, method_name: String, args: Array, vm: LuaVM) -> Dictionary:
	match method_name:
		"Destroy":
			node.queue_free()
			return {"ok": true, "values": []}
		"FindFirstChild":
			var wanted := LuaValues.to_text(args[0]) if not args.is_empty() else ""
			if node is PlayerCharacter and (wanted == "Humanoid" or wanted == "HumanoidRootPart"):
				if wanted == "Humanoid":
					return {"ok": true, "values": [LuaHumanoid.new(node)]}
				return {"ok": true, "values": [node]}
			return {"ok": true, "values": [(node as Node).find_child(wanted, false, false)]}
		"GetChildren":
			var table := LuaTable.new()
			var index := 1
			for child in (node as Node).get_children():
				table.set_value(float(index), child)
				index += 1
			return {"ok": true, "values": [table]}
	return {"ok": false, "error": "metodo sconosciuto: %s" % method_name}


static func _humanoid_property(humanoid: LuaHumanoid, key) -> Dictionary:
	match str(key):
		"Health":
			return {"ok": true, "value": float(humanoid.character.health)}
		"MaxHealth":
			return {"ok": true, "value": float(PlayerCharacter.MAX_HEALTH)}
		"Name":
			return {"ok": true, "value": "Humanoid"}
		"Parent":
			return {"ok": true, "value": humanoid.character}
		"Character":
			return {"ok": true, "value": humanoid.character}
	return {"ok": false}


static func _set_parent(node: Object, value) -> bool:
	if not (node is Node):
		return false
	if value == null:
		var parent := (node as Node).get_parent()
		if parent:
			parent.remove_child(node)
		return true
	if value is Node:
		var target := value as Node
		var current := (node as Node).get_parent()
		if current:
			current.remove_child(node)
		target.add_child(node)
		return true
	return false


# --- Parti ---------------------------------------------------------------------

static func _get_size(node: Object) -> Vector3:
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		return (mesh.mesh as BoxMesh).size
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision and collision.shape is BoxShape3D:
		return (collision.shape as BoxShape3D).size
	return Vector3(1, 1, 1)


static func _set_size(node: Object, size: Vector3) -> void:
	var safe := Vector3(maxf(0.1, size.x), maxf(0.1, size.y), maxf(0.1, size.z))
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.mesh is BoxMesh:
		(mesh.mesh as BoxMesh).size = safe
	var collision := node.get_node_or_null("Collision") as CollisionShape3D
	if collision:
		if collision.shape is BoxShape3D:
			(collision.shape as BoxShape3D).size = safe
		else:
			var shape := BoxShape3D.new()
			shape.size = safe
			collision.shape = shape


static func _get_color(node: Object) -> Color:
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh and mesh.material_override is StandardMaterial3D:
		return (mesh.material_override as StandardMaterial3D).albedo_color
	return Color.WHITE


static func _set_color(node: Object, color: Color) -> void:
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		material = StandardMaterial3D.new()
		mesh.material_override = material
	material.albedo_color = color


static func _is_anchored(node: Object) -> bool:
	if node is RigidBody3D:
		return (node as RigidBody3D).freeze
	if node is StaticBody3D or node is AnimatableBody3D:
		return true
	return bool(node.get_meta("lua_anchored", true))


# --- Segnali -------------------------------------------------------------------

static func _get_signal(node: Object, signal_name: String, vm: LuaVM) -> LuaSignal:
	var key := "__lua_signal_%s" % signal_name
	if node.has_meta(key):
		var existing = node.get_meta(key)
		if existing is LuaSignal and existing.runtime == vm.host:
			return existing
		if existing is LuaSignal:
			existing.clear()
	var lua_signal := LuaSignal.new()
	lua_signal.owner = node
	lua_signal.signal_name = signal_name
	lua_signal.runtime = vm.host
	lua_signal.meta_key = key
	var area := Area3D.new()
	area.name = "Lua%sSensor" % signal_name
	area.monitorable = false
	area.monitoring = true
	var shape := BoxShape3D.new()
	shape.size = _get_size(node) + Vector3(0.4, 0.4, 0.4)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	area.add_child(collision)
	(node as Node).add_child(area)
	lua_signal.sensor = area
	if signal_name == "Touched":
		area.body_entered.connect(lua_signal._on_body_entered)
	else:
		area.body_exited.connect(lua_signal._on_body_exited)
	node.set_meta(key, lua_signal)
	if vm.host:
		vm.host.register_signal(lua_signal)
	return lua_signal
