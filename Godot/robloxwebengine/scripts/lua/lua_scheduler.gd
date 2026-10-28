class_name LuaRuntime
extends Node
## Orchestra gli script di un livello: crea una VM per script, distribuisce il
## budget di esecuzione per frame, raccoglie output/errori e gestisce i segnali
## `Touched` condivisi tra le VM.

signal output_line(text: String, level: int)
signal script_error(text: String)

const FRAME_BUDGET_US := 3000
const INSTANCE_LIMIT := 500

var world: Node3D
var character: PlayerCharacter
var player_name := ""
var running := false

var _scripts: Array = []  # {name, vm, parent, source, error}
var _signals: Array = []
var _instances: Array = []
var _nodes_by_id: Dictionary = {}


func start(
	level_data: Dictionary,
	target_world: Node3D,
	nodes_by_id: Dictionary,
	player_character: PlayerCharacter = null,
	player_label := ""
) -> void:
	stop()
	world = target_world
	character = player_character
	player_name = player_label
	_nodes_by_id = nodes_by_id
	if world == null:
		return
	running = true
	var scripts: Array = level_data.get("scripts", [])
	for script_data in scripts:
		if typeof(script_data) != TYPE_DICTIONARY:
			continue
		if not bool(script_data.get("enabled", true)):
			continue
		var source := str(script_data.get("source", ""))
		if source.strip_edges() == "":
			continue
		var script_name := str(script_data.get("name", "Script"))
		var parent_id := str(script_data.get("parent_id", ""))
		var parent: Node3D = world
		if parent_id != "" and _nodes_by_id.has(parent_id):
			parent = _nodes_by_id[parent_id] as Node3D
		elif parent_id != "":
			emit_output(script_name, "parte collegata non trovata, uso workspace", 1)
		var vm := LuaVM.new(self, script_name)
		LuaStdlib.install(vm)
		var script_table := LuaTable.new()
		script_table.set_value("Name", script_name)
		script_table.set_value("Parent", parent)
		script_table.set_value("Enabled", true)
		vm.set_global("workspace", world)
		vm.set_global("game", LuaRobloxAPI.LuaGame.new(self))
		vm.set_global("script", script_table)
		var state := {
			"name": script_name,
			"vm": vm,
			"parent": parent,
			"source": source,
			"error": false,
		}
		if vm.start(source):
			_scripts.append(state)
		else:
			state["error"] = true
			_scripts.append(state)


func stop() -> void:
	running = false
	for state in _scripts:
		var vm = state.get("vm")
		if vm:
			vm.stop()
	_scripts.clear()
	for lua_signal in _signals:
		if lua_signal != null and is_instance_valid(lua_signal):
			lua_signal.clear()
	_signals.clear()
	for node in _instances:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_instances.clear()
	_nodes_by_id.clear()
	world = null
	character = null


func _exit_tree() -> void:
	stop()


func _process(delta: float) -> void:
	if not running:
		return
	var deadline := Time.get_ticks_usec() + FRAME_BUDGET_US
	for state in _scripts:
		if Time.get_ticks_usec() >= deadline:
			break
		var vm: LuaVM = state.get("vm")
		if vm == null or vm.stopped:
			continue
		vm.step(delta, deadline - Time.get_ticks_usec())


func emit_output(script_name: String, text: String, level := 0) -> void:
	var line := text if level >= 2 else "[%s] %s" % [script_name, text]
	output_line.emit(line, level)
	print(line)


func report_error(text: String, vm: LuaVM = null) -> void:
	output_line.emit(text, 2)
	script_error.emit(text)
	push_warning(text)
	if vm != null:
		vm.stopped = true
		for state in _scripts:
			if state.get("vm") == vm:
				state["error"] = true
				break


func dispatch(vm: LuaVM, lua_function, args: Array, label := "evento") -> void:
	if not running or vm == null or vm.stopped:
		return
	vm.enqueue(lua_function, args, label)


func register_signal(lua_signal) -> void:
	_signals.append(lua_signal)


func instance_count() -> int:
	return _instances.size()


func track_instance(node: Node) -> void:
	if _instances.size() >= INSTANCE_LIMIT:
		return
	_instances.append(node)


func script_states() -> Array:
	return _scripts.duplicate()


func active_script_count() -> int:
	var count := 0
	for state in _scripts:
		if not bool(state.get("error", false)):
			count += 1
	return count
