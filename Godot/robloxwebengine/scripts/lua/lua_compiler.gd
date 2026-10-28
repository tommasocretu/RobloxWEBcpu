class_name LuaCompiler
extends RefCounted
## Compila l'AST Lua in un LuaPrototype (bytecode a stack).
## Risolve locali/upvalue/globali a tempo di compilazione; le closure catturano
## le celle delle variabili, non i valori.

const OP := LuaPrototype.Op

var error_message := ""
var error_line := 0

var script_name := "script"

var _proto: LuaPrototype
var _parent: LuaCompiler
var _scopes: Array = []
var _scope_slot_bases: Array = []
var _next_slot := 0
var _max_slots := 0
var _loop_breaks: Array = []
var _upvalue_names: Array = []
var _current_line := 1


func compile(ast: Array, name: String) -> LuaPrototype:
	script_name = name
	_proto = LuaPrototype.new()
	_proto.name = name
	_proto.is_vararg = true
	_scopes = [{}]
	_scope_slot_bases = [0]
	_next_slot = 0
	_max_slots = 0
	_loop_breaks = []
	_upvalue_names = []
	_compile_statements(ast)
	_emit(OP.RETURN, 0)
	_proto.max_slots = _max_slots
	return _proto


func _compile_proto(node: Dictionary, function_name: String) -> LuaPrototype:
	_proto = LuaPrototype.new()
	_proto.name = script_name
	_proto.num_params = node.get("params", []).size()
	_proto.is_vararg = bool(node.get("vararg", false))
	_scopes = [{}]
	_scope_slot_bases = [0]
	_next_slot = 0
	_max_slots = 0
	_loop_breaks = []
	_upvalue_names = []
	for param in node.get("params", []):
		_declare_local(str(param))
	_compile_statements(node.get("body", []))
	_emit(OP.RETURN, 0)
	_proto.max_slots = _max_slots
	if not function_name.is_empty():
		_proto.name = script_name
	return _proto


func _failed() -> bool:
	return error_message != ""


func _fail(message: String, line := 0) -> void:
	if not _failed():
		error_message = message
		error_line = line if line > 0 else _current_line


func _pc() -> int:
	return _proto.instructions.size()


func _emit(op: int, a = null, b = null, c = null, line := 0) -> int:
	var instruction := {
		"op": op,
		"a": a,
		"b": b,
		"c": c,
		"line": line if line > 0 else _current_line,
	}
	_proto.instructions.append(instruction)
	return _proto.instructions.size() - 1


func _patch(index: int, target: int) -> void:
	_proto.instructions[index]["a"] = target


func _constant(value) -> int:
	var index := _proto.constants.find(value)
	if index >= 0:
		return index
	_proto.constants.append(value)
	return _proto.constants.size() - 1


# --- Scope ---------------------------------------------------------------------

func _begin_scope() -> void:
	_scopes.append({})
	_scope_slot_bases.append(_next_slot)


func _end_scope() -> void:
	if _scopes.size() <= 1:
		return
	_scopes.pop_back()
	_next_slot = int(_scope_slot_bases.pop_back())


func _alloc_slot() -> int:
	var slot := _next_slot
	_next_slot += 1
	_max_slots = maxi(_max_slots, _next_slot)
	return slot


func _declare_local(local_name: String) -> int:
	var slot := _alloc_slot()
	_scopes[_scopes.size() - 1][local_name] = slot
	return slot


func _find_local(local_name: String) -> int:
	for i in range(_scopes.size() - 1, -1, -1):
		var scope: Dictionary = _scopes[i]
		if scope.has(local_name):
			return int(scope[local_name])
	return -1


func _resolve(local_name: String) -> Dictionary:
	var slot := _find_local(local_name)
	if slot >= 0:
		return {"kind": "local", "index": slot}
	var upvalue := _resolve_upvalue(local_name)
	if upvalue >= 0:
		return {"kind": "upvalue", "index": upvalue}
	return {"kind": "global", "index": 0}


func _resolve_upvalue(local_name: String) -> int:
	if _parent == null:
		return -1
	var parent_slot := _parent._find_local(local_name)
	if parent_slot >= 0:
		return _add_upvalue([true, parent_slot], local_name)
	var parent_upvalue := _parent._resolve_upvalue(local_name)
	if parent_upvalue >= 0:
		return _add_upvalue([false, parent_upvalue], local_name)
	return -1


func _add_upvalue(descriptor: Array, local_name: String) -> int:
	for i in _proto.upvalues.size():
		var existing: Array = _proto.upvalues[i]
		if int(existing[0]) == int(descriptor[0]) and int(existing[1]) == int(descriptor[1]):
			return i
	_proto.upvalues.append(descriptor)
	_upvalue_names.append(local_name)
	return _proto.upvalues.size() - 1


func _begin_loop() -> void:
	_loop_breaks.append([])


func _end_loop(target: int) -> void:
	if _loop_breaks.is_empty():
		return
	var breaks: Array = _loop_breaks.pop_back()
	for index in breaks:
		_patch(int(index), target)


# --- Statements ----------------------------------------------------------------

func _compile_statements(statements: Array) -> void:
	for statement in statements:
		if _failed():
			return
		if typeof(statement) != TYPE_DICTIONARY:
			continue
		_compile_statement(statement)


func _compile_block(statements: Array) -> void:
	_begin_scope()
	_compile_statements(statements)
	_end_scope()


func _compile_statement(statement: Dictionary) -> void:
	_current_line = int(statement.get("line", _current_line))
	match str(statement.get("t", "")):
		"local":
			_compile_local(statement)
		"localfunc":
			_compile_local_function(statement)
		"assign":
			_compile_assignment(statement)
		"callstat":
			_compile_call(statement["call"], 0)
		"do":
			_compile_block(statement.get("body", []))
		"if":
			_compile_if(statement)
		"while":
			_compile_while(statement)
		"repeat":
			_compile_repeat(statement)
		"fornum":
			_compile_numeric_for(statement)
		"forin":
			_compile_generic_for(statement)
		"return":
			_compile_return(statement)
		"break":
			_compile_break(statement)
		"functiondecl":
			_compile_function_declaration(statement)
		_:
			_fail("istruzione sconosciuta: %s" % str(statement.get("t", "?")), _current_line)


func _compile_local(statement: Dictionary) -> void:
	var names: Array = statement.get("names", [])
	var exprs: Array = statement.get("exprs", [])
	_compile_expr_list(exprs, names.size())
	var slots: Array = []
	for local_name in names:
		slots.append(_declare_local(str(local_name)))
	for i in range(slots.size() - 1, -1, -1):
		_emit(OP.STORE_LOCAL, slots[i])


func _compile_local_function(statement: Dictionary) -> void:
	var slot := _declare_local(str(statement["name"]))
	_emit(OP.NEW_LOCAL, slot)
	_compile_expr(statement["func"], false)
	_emit(OP.STORE_LOCAL, slot)


func _compile_function_declaration(statement: Dictionary) -> void:
	_compile_expr(statement["func"], false)
	var temp := _alloc_slot()
	_emit(OP.STORE_LOCAL, temp)
	_compile_target_store(statement["target"], temp)
	_next_slot -= 1


func _compile_assignment(statement: Dictionary) -> void:
	var targets: Array = statement.get("targets", [])
	var exprs: Array = statement.get("exprs", [])
	if targets.is_empty():
		return
	var count := targets.size()
	var temps: Array = []
	for i in count:
		temps.append(_alloc_slot())
	_compile_expr_list(exprs, count)
	for i in range(count - 1, -1, -1):
		_emit(OP.STORE_LOCAL, temps[i])
	for i in count:
		_compile_target_store(targets[i], temps[i])
	for i in count:
		_next_slot -= 1


func _compile_target_store(target: Dictionary, temp_slot: int) -> void:
	var kind := str(target.get("t", ""))
	if kind == "name":
		var resolved := _resolve(str(target["v"]))
		_emit(OP.LOAD_LOCAL, temp_slot)
		match str(resolved["kind"]):
			"local":
				_emit(OP.STORE_LOCAL, resolved["index"])
			"upvalue":
				_emit(OP.STORE_UPVAL, resolved["index"])
			_:
				_emit(OP.STORE_GLOBAL, _constant(str(target["v"])))
	elif kind == "index":
		_compile_expr(target["obj"], false)
		_compile_expr(target["key"], false)
		_emit(OP.LOAD_LOCAL, temp_slot)
		_emit(OP.SET_INDEX)
	else:
		_fail("destinazione non valida", _current_line)


func _compile_if(statement: Dictionary) -> void:
	var end_jumps: Array = []
	for clause in statement.get("clauses", []):
		_compile_expr(clause["cond"], false)
		var jump_false := _emit(OP.JUMP_IF_FALSE)
		_compile_block(clause.get("body", []))
		end_jumps.append(_emit(OP.JUMP))
		_patch(jump_false, _pc())
	_compile_block(statement.get("else", []))
	var target := _pc()
	for jump in end_jumps:
		_patch(int(jump), target)


func _compile_while(statement: Dictionary) -> void:
	var start := _pc()
	_compile_expr(statement["cond"], false)
	var jump_false := _emit(OP.JUMP_IF_FALSE)
	_begin_loop()
	_compile_block(statement.get("body", []))
	_emit(OP.JUMP, start)
	var exit := _pc()
	_patch(jump_false, exit)
	_end_loop(exit)


func _compile_repeat(statement: Dictionary) -> void:
	var start := _pc()
	_begin_scope()
	_begin_loop()
	# Il corpo non apre un nuovo scope: la condizione `until` vede i locali.
	_compile_statements(statement.get("body", []))
	_compile_expr(statement["cond"], false)
	_emit(OP.JUMP_IF_FALSE, start)
	var exit := _pc()
	_end_loop(exit)
	_end_scope()


func _compile_numeric_for(statement: Dictionary) -> void:
	_begin_scope()
	var limit_slot := _alloc_slot()
	var step_slot := _alloc_slot()
	var control_slot := _alloc_slot()
	_compile_expr(statement["start"], false)
	_emit(OP.STORE_LOCAL, control_slot)
	_compile_expr(statement["stop"], false)
	_emit(OP.STORE_LOCAL, limit_slot)
	if statement.get("step") != null:
		_compile_expr(statement["step"], false)
	else:
		_emit(OP.LOADK, _constant(1.0))
	_emit(OP.STORE_LOCAL, step_slot)
	var variable_slot := _declare_local(str(statement["name"]))
	var loop_start := _pc()
	_emit(OP.LOAD_LOCAL, control_slot)
	_emit(OP.LOAD_LOCAL, limit_slot)
	_emit(OP.LOAD_LOCAL, step_slot)
	_emit(OP.FOR_CHECK)
	var jump_false := _emit(OP.JUMP_IF_FALSE)
	_emit(OP.LOAD_LOCAL, control_slot)
	_emit(OP.STORE_LOCAL, variable_slot)
	_begin_loop()
	_compile_block(statement.get("body", []))
	_emit(OP.LOAD_LOCAL, control_slot)
	_emit(OP.LOAD_LOCAL, step_slot)
	_emit(OP.ADD)
	_emit(OP.STORE_LOCAL, control_slot)
	_emit(OP.JUMP, loop_start)
	var exit := _pc()
	_patch(jump_false, exit)
	_end_loop(exit)
	_end_scope()


func _compile_generic_for(statement: Dictionary) -> void:
	_begin_scope()
	var function_slot := _alloc_slot()
	var state_slot := _alloc_slot()
	var control_slot := _alloc_slot()
	_compile_expr_list(statement.get("exprs", []), 3)
	_emit(OP.STORE_LOCAL, control_slot)
	_emit(OP.STORE_LOCAL, state_slot)
	_emit(OP.STORE_LOCAL, function_slot)
	_emit(OP.NEW_LOCAL, function_slot)
	_emit(OP.NEW_LOCAL, state_slot)
	_emit(OP.NEW_LOCAL, control_slot)
	var variable_slots: Array = []
	for variable_name in statement.get("names", []):
		var slot := _declare_local(str(variable_name))
		_emit(OP.NEW_LOCAL, slot)
		variable_slots.append(slot)
	var loop_start := _pc()
	var result_count := maxi(1, variable_slots.size())
	_emit(OP.LOAD_LOCAL, function_slot)
	_emit(OP.LOAD_LOCAL, state_slot)
	_emit(OP.LOAD_LOCAL, control_slot)
	_emit(OP.CALL, 2, result_count)
	_emit(OP.TFORRESULT, control_slot, variable_slots)
	var jump_false := _emit(OP.JUMP_IF_FALSE)
	_begin_loop()
	_compile_block(statement.get("body", []))
	_emit(OP.JUMP, loop_start)
	var exit := _pc()
	_patch(jump_false, exit)
	_end_loop(exit)
	_end_scope()


func _compile_return(statement: Dictionary) -> void:
	var exprs: Array = statement.get("exprs", [])
	if exprs.is_empty():
		_emit(OP.RETURN, 0)
		return
	_emit(OP.PUSH_MARK)
	_compile_expr_list_values(exprs, true)
	_emit(OP.RETURN_MARK)


func _compile_break(statement: Dictionary) -> void:
	if _loop_breaks.is_empty():
		_fail("break fuori da un ciclo", int(statement.get("line", _current_line)))
		return
	var jump := _emit(OP.JUMP)
	_loop_breaks[_loop_breaks.size() - 1].append(jump)


# --- Espressioni ---------------------------------------------------------------

func _compile_expr_list(exprs: Array, count: int) -> void:
	_emit(OP.PUSH_MARK)
	_compile_expr_list_values(exprs, true)
	_emit(OP.ADJUST, count)


func _compile_expr_list_values(exprs: Array, allow_multi := false) -> void:
	for i in exprs.size():
		var is_last := i == exprs.size() - 1
		_compile_expr(exprs[i], allow_multi and is_last)


func _compile_expr(node: Dictionary, multi := false) -> void:
	if _failed():
		return
	var kind := str(node.get("t", ""))
	match kind:
		"nil":
			_emit(OP.LOADNIL)
		"true":
			_emit(OP.LOADTRUE)
		"false":
			_emit(OP.LOADFALSE)
		"number", "string":
			_emit(OP.LOADK, _constant(node.get("v")))
		"name":
			var resolved := _resolve(str(node["v"]))
			match str(resolved["kind"]):
				"local":
					_emit(OP.LOAD_LOCAL, resolved["index"])
				"upvalue":
					_emit(OP.LOAD_UPVAL, resolved["index"])
				_:
					_emit(OP.LOAD_GLOBAL, _constant(str(node["v"])))
		"paren":
			_compile_expr(node["e"], false)
		"vararg":
			if not _proto.is_vararg:
				_fail("'...' usato fuori da una funzione variadica", int(node.get("line", _current_line)))
				return
			_emit(OP.VARARG, -1 if multi else 1)
		"index":
			_compile_expr(node["obj"], false)
			_compile_expr(node["key"], false)
			_emit(OP.GET_INDEX)
		"call":
			_compile_call(node, -1 if multi else 1)
		"binop":
			_compile_binop(node)
		"unop":
			_compile_expr(node["e"], false)
			match str(node["op"]):
				"-":
					_emit(OP.UNM)
				"not":
					_emit(OP.NOT)
				"#":
					_emit(OP.LEN)
		"function":
			var child := LuaCompiler.new()
			child.script_name = script_name
			child._parent = self
			var child_proto := child._compile_proto(node, "")
			var index := _proto.protos.size()
			_proto.protos.append(child_proto)
			_emit(OP.CLOSURE, index)
		"table":
			_emit(OP.NEW_TABLE)
			var array: Array = node.get("array", [])
			for i in array.size():
				_compile_expr(array[i], false)
				_emit(OP.SET_ARRAY, i + 1)
			for field in node.get("hash", []):
				_compile_expr(field["key"], false)
				_compile_expr(field["value"], false)
				_emit(OP.SET_HASH)
		_:
			_fail("espressione sconosciuta: %s" % kind, int(node.get("line", _current_line)))


func _compile_binop(node: Dictionary) -> void:
	var op := str(node["op"])
	if op == "and":
		_compile_expr(node["l"], false)
		var jump := _emit(OP.JUMP_IF_FALSE_KEEP)
		_emit(OP.POP)
		_compile_expr(node["r"], false)
		_patch(jump, _pc())
		return
	if op == "or":
		_compile_expr(node["l"], false)
		var jump := _emit(OP.JUMP_IF_TRUE_KEEP)
		_emit(OP.POP)
		_compile_expr(node["r"], false)
		_patch(jump, _pc())
		return
	_compile_expr(node["l"], false)
	_compile_expr(node["r"], false)
	match op:
		"+":
			_emit(OP.ADD)
		"-":
			_emit(OP.SUB)
		"*":
			_emit(OP.MUL)
		"/":
			_emit(OP.DIV)
		"%":
			_emit(OP.MOD)
		"^":
			_emit(OP.POW)
		"..":
			_emit(OP.CONCAT)
		"==":
			_emit(OP.EQ)
		"~=":
			_emit(OP.NE)
		"<":
			_emit(OP.LT)
		"<=":
			_emit(OP.LE)
		">":
			_emit(OP.GT)
		">=":
			_emit(OP.GE)
		_:
			_fail("operatore sconosciuto: %s" % op)


func _compiles_multi(node: Dictionary) -> bool:
	var kind := str(node.get("t", ""))
	return kind == "call" or kind == "vararg"


func _compile_call(node: Dictionary, nresults: int) -> void:
	var args: Array = node.get("args", [])
	var has_multi := not args.is_empty() and _compiles_multi(args[args.size() - 1])
	if node.has("method"):
		_compile_expr(node["receiver"], false)
		_emit(OP.DUP)
		_emit(OP.GET_FIELD, _constant(str(node["method"])))
		_emit(OP.SWAP)
		if has_multi:
			_emit(OP.PUSH_MARK)
			_compile_list_with_multi(args)
			_emit(OP.CALL_MARK, 1, nresults)
		else:
			for argument in args:
				_compile_expr(argument, false)
			_emit(OP.CALL, args.size() + 1, nresults)
	else:
		_compile_expr(node["fn"], false)
		if has_multi:
			_emit(OP.PUSH_MARK)
			_compile_list_with_multi(args)
			_emit(OP.CALL_MARK, 0, nresults)
		else:
			for argument in args:
				_compile_expr(argument, false)
			_emit(OP.CALL, args.size(), nresults)


func _compile_list_with_multi(args: Array) -> void:
	for i in args.size():
		_compile_expr(args[i], i == args.size() - 1)
