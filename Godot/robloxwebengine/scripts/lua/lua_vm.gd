class_name LuaVM
extends RefCounted
## Macchina virtuale Lua a stack. Esegue il bytecode prodotto da LuaCompiler,
## gestisce frame, closure/upvalue, chiamate native, sospensioni (`task.wait`)
## e limiti di sicurezza.

const OP := LuaPrototype.Op
const MAX_CALL_DEPTH := 200
const MAX_INSTRUCTIONS_PER_SLICE := 200000


class Marker extends RefCounted:
	pass


var _marker := Marker.new()


class LuaThread extends RefCounted:
	var frames: Array = []
	var status := "ready"  # ready | waiting | done
	var wake_at := 0.0
	var pending_function = null
	var pending_args: Array = []
	var label := "main"
	var error_text := ""


var host = null
var script_name := "script"
var globals := LuaTable.new()
var threads: Array = []
var stopped := false

var _current_thread: LuaThread
var _pending_error := ""
var _wait_requested := false
var _wait_seconds := 0.0


func _init(host_ref = null, name := "script") -> void:
	host = host_ref
	script_name = name


func set_global(name: String, value) -> void:
	globals.set_value(name, value)


func get_global(name: String):
	return globals.get_value(name)


func start(source: String, script_object = null) -> bool:
	var lexer := LuaLexer.new()
	var tokens := lexer.tokenize(source)
	if lexer.error_message != "":
		_report_compile_error(lexer.error_message, lexer.error_line)
		return false
	var parser := LuaParser.new()
	var ast := parser.parse(tokens)
	if parser.error_message != "":
		_report_compile_error(parser.error_message, parser.error_line)
		return false
	var compiler := LuaCompiler.new()
	var proto := compiler.compile(ast, script_name)
	if compiler.error_message != "":
		_report_compile_error(compiler.error_message, compiler.error_line)
		return false
	var thread := LuaThread.new()
	thread.label = "main"
	var lua_function := LuaFunction.new(proto)
	thread.frames.append(_make_frame(lua_function, [], 0))
	threads.append(thread)
	return true


func enqueue(lua_function, args: Array = [], label := "callback") -> void:
	if not LuaValues.is_callable(lua_function):
		return
	var thread := LuaThread.new()
	thread.label = label
	thread.pending_function = lua_function
	thread.pending_args = args.duplicate()
	threads.append(thread)


func spawn(lua_function, args: Array = [], delay := 0.0, label := "spawn") -> void:
	if not LuaValues.is_callable(lua_function):
		_pending_error = "task.spawn richiede una funzione"
		return
	var thread := LuaThread.new()
	thread.label = label
	thread.pending_function = lua_function
	thread.pending_args = args.duplicate()
	if delay > 0.0:
		thread.status = "waiting"
		thread.wake_at = _now() + delay
	threads.append(thread)


func request_wait(seconds: float) -> void:
	_wait_requested = true
	_wait_seconds = maxf(0.0, seconds)


func raise_pending(message: String) -> void:
	_pending_error = message


func output(text: String, level := 0) -> void:
	if host:
		host.emit_output(script_name, text, level)


func step(delta: float, budget_us: int) -> void:
	if stopped or threads.is_empty():
		return
	var now := _now()
	for thread in threads:
		if thread.status == "waiting" and now >= thread.wake_at:
			if thread.pending_function != null:
				_begin_pending(thread)
			else:
				thread.status = "ready"
	var deadline := Time.get_ticks_usec() + maxi(budget_us, 100)
	for thread in threads:
		if stopped or Time.get_ticks_usec() >= deadline:
			break
		if thread.status == "ready" and thread.frames.is_empty() and thread.pending_function != null:
			_begin_pending(thread)
		if thread.status != "ready":
			continue
		_run_thread(thread, deadline)


func stop() -> void:
	stopped = true
	threads.clear()
	_current_thread = null


func _begin_pending(thread: LuaThread) -> void:
	var lua_function = thread.pending_function
	var args: Array = thread.pending_args
	thread.pending_function = null
	thread.pending_args = []
	if lua_function is LuaFunction:
		thread.frames.append(_make_frame(lua_function, args, 0))
		thread.status = "ready"
	elif lua_function is LuaBuiltin or lua_function is LuaValues.Method:
		var dummy := _make_builtin_frame()
		thread.status = "ready"
		_invoke(thread, dummy, lua_function, args, 0, 0)
		if thread.status == "ready":
			thread.status = "done"
	else:
		thread.status = "done"


func _make_builtin_frame() -> Dictionary:
	return {
		"proto": null,
		"closure": null,
		"pc": 0,
		"locals": [],
		"stack": [],
		"varargs": [],
		"return_adjust": 0,
	}


func _run_thread(thread: LuaThread, deadline: int) -> void:
	_current_thread = thread
	var counter := 0
	while thread.status == "ready":
		if thread.frames.is_empty():
			thread.status = "done"
			break
		var frame: Dictionary = thread.frames[thread.frames.size() - 1]
		var proto: LuaPrototype = frame["proto"]
		if int(frame["pc"]) >= proto.instructions.size():
			_return_from_frame(thread, frame, [])
			continue
		var instruction: Dictionary = proto.instructions[int(frame["pc"])]
		frame["pc"] = int(frame["pc"]) + 1
		_execute(thread, frame, instruction)
		if thread.status != "ready":
			break
		counter += 1
		if counter >= 128:
			counter = 0
			if Time.get_ticks_usec() >= deadline:
				break
	if thread.status == "error":
		if host:
			host.report_error(thread.error_text, self)
		thread.status = "done"
		thread.frames.clear()


func _execute(thread: LuaThread, frame: Dictionary, instruction: Dictionary) -> void:
	var op := int(instruction["op"])
	var line := int(instruction["line"])
	var a = instruction["a"]
	var b = instruction["b"]
	var c = instruction["c"]
	var stack: Array = frame["stack"]
	match op:
		OP.LOADK:
			stack.append(frame["proto"].constants[int(a)])
		OP.LOADNIL:
			stack.append(null)
		OP.LOADTRUE:
			stack.append(true)
		OP.LOADFALSE:
			stack.append(false)
		OP.LOAD_LOCAL:
			stack.append(_cell(frame, int(a), thread, line).value)
		OP.STORE_LOCAL:
			_cell(frame, int(a), thread, line).value = _pop(stack, thread, line)
		OP.NEW_LOCAL:
			if frame["locals"][int(a)] == null:
				frame["locals"][int(a)] = LuaValues.Cell.new()
		OP.LOAD_UPVAL:
			stack.append(_upvalue(frame, int(a), thread, line).value)
		OP.STORE_UPVAL:
			_upvalue(frame, int(a), thread, line).value = _pop(stack, thread, line)
		OP.LOAD_GLOBAL:
			stack.append(globals.get_value(frame["proto"].constants[int(a)]))
		OP.STORE_GLOBAL:
			globals.set_value(frame["proto"].constants[int(a)], _pop(stack, thread, line))
		OP.GET_INDEX:
			var key = _pop(stack, thread, line)
			var target = _pop(stack, thread, line)
			var indexed = _index_get(target, key, thread, line)
			if thread.status == "ready":
				stack.append(indexed)
		OP.SET_INDEX:
			var value = _pop(stack, thread, line)
			var key = _pop(stack, thread, line)
			var target = _pop(stack, thread, line)
			_index_set(target, key, value, thread, line)
		OP.GET_FIELD:
			var target = _pop(stack, thread, line)
			var indexed = _index_get(target, frame["proto"].constants[int(a)], thread, line)
			if thread.status == "ready":
				stack.append(indexed)
		OP.SET_FIELD:
			var value = _pop(stack, thread, line)
			var target = _pop(stack, thread, line)
			_index_set(target, frame["proto"].constants[int(a)], value, thread, line)
		OP.SET_ARRAY:
			var value = _pop(stack, thread, line)
			var table = _peek(stack, thread, line)
			if not (table is LuaTable):
				_raise(thread, "tentativo di indicizzare un valore non tabella", line)
				return
			if (table as LuaTable).size() >= LuaTable.MAX_ENTRIES\
					and not (table as LuaTable).has_key(float(int(a))):
				_raise(thread, "tabella troppo grande (massimo %d elementi)" % LuaTable.MAX_ENTRIES, line)
				return
			(table as LuaTable).set_value(float(int(a)), value)
		OP.SET_HASH:
			var value = _pop(stack, thread, line)
			var key = _pop(stack, thread, line)
			var table = _peek(stack, thread, line)
			if not (table is LuaTable):
				_raise(thread, "tentativo di indicizzare un valore non tabella", line)
				return
			if (table as LuaTable).size() >= LuaTable.MAX_ENTRIES\
					and not (table as LuaTable).has_key(key):
				_raise(thread, "tabella troppo grande (massimo %d elementi)" % LuaTable.MAX_ENTRIES, line)
				return
			(table as LuaTable).set_value(key, value)
		OP.NEW_TABLE:
			stack.append(LuaTable.new())
		OP.DUP:
			stack.append(_peek(stack, thread, line))
		OP.POP:
			_pop(stack, thread, line)
		OP.SWAP:
			var top = _pop(stack, thread, line)
			var below = _pop(stack, thread, line)
			stack.append(top)
			stack.append(below)
		OP.PUSH_MARK:
			stack.append(_marker)
		OP.ADJUST:
			var values := _pop_until_marker(stack, thread, line)
			if thread.status != "ready":
				return
			var wanted := int(a)
			while values.size() < wanted:
				values.append(null)
			values.resize(wanted)
			stack.append_array(values)
		OP.RETURN_MARK:
			var values := _pop_until_marker(stack, thread, line)
			if thread.status == "ready":
				_return_from_frame(thread, frame, values)
		OP.ADD, OP.SUB, OP.MUL, OP.DIV, OP.MOD, OP.POW:
			var right = _pop(stack, thread, line)
			var left = _pop(stack, thread, line)
			var outcome := _binary_arithmetic(op, left, right)
			if not outcome[0]:
				_raise(thread, str(outcome[1]), line)
				return
			stack.append(outcome[1])
		OP.CONCAT:
			var right = _pop(stack, thread, line)
			var left = _pop(stack, thread, line)
			if not _concat_operand(left) or not _concat_operand(right):
				_raise(thread, "concatenazione non valida tra %s e %s" % [
					LuaValues.type_name(left), LuaValues.type_name(right)
				], line)
				return
			var concatenated := LuaValues.to_text(left) + LuaValues.to_text(right)
			if concatenated.length() > 1048576:
				_raise(thread, "stringa troppo lunga (massimo 1 MB)", line)
				return
			stack.append(concatenated)
		OP.EQ:
			var right = _pop(stack, thread, line)
			var left = _pop(stack, thread, line)
			stack.append(LuaValues.equals(left, right))
		OP.NE:
			var right = _pop(stack, thread, line)
			var left = _pop(stack, thread, line)
			stack.append(not LuaValues.equals(left, right))
		OP.LT, OP.LE, OP.GT, OP.GE:
			var right = _pop(stack, thread, line)
			var left = _pop(stack, thread, line)
			var outcome := _compare(op, left, right)
			if not outcome[0]:
				_raise(thread, str(outcome[1]), line)
				return
			stack.append(outcome[1])
		OP.UNM:
			var value = _pop(stack, thread, line)
			if LuaValues.is_number(value):
				stack.append(float(-float(value)))
			elif value is Vector3:
				stack.append(-value)
			else:
				_raise(thread, "tentativo di negare un %s" % LuaValues.type_name(value), line)
		OP.NOT:
			stack.append(not LuaValues.truthy(_pop(stack, thread, line)))
		OP.LEN:
			var value = _pop(stack, thread, line)
			if value is LuaTable:
				stack.append(float((value as LuaTable).length()))
			elif value is String:
				stack.append(float((value as String).length()))
			else:
				_raise(thread, "tentativo di ottenere la lunghezza di un %s" % LuaValues.type_name(value), line)
		OP.JUMP:
			frame["pc"] = int(a)
		OP.JUMP_IF_FALSE:
			var condition = _pop(stack, thread, line)
			if not LuaValues.truthy(condition):
				frame["pc"] = int(a)
		OP.JUMP_IF_TRUE:
			var condition = _pop(stack, thread, line)
			if LuaValues.truthy(condition):
				frame["pc"] = int(a)
		OP.JUMP_IF_FALSE_KEEP:
			if not LuaValues.truthy(_peek(stack, thread, line)):
				frame["pc"] = int(a)
		OP.JUMP_IF_TRUE_KEEP:
			if LuaValues.truthy(_peek(stack, thread, line)):
				frame["pc"] = int(a)
		OP.FOR_CHECK:
			var step = _pop(stack, thread, line)
			var limit = _pop(stack, thread, line)
			var control = _pop(stack, thread, line)
			if not LuaValues.is_number(step) or not LuaValues.is_number(limit)\
					or not LuaValues.is_number(control):
				_raise(thread, "for numerico richiede valori numerici", line)
				return
			var step_value := float(step)
			if step_value == 0.0:
				_raise(thread, "il passo del ciclo for non può essere zero", line)
				return
			var control_value := float(control)
			var limit_value := float(limit)
			if step_value > 0.0:
				stack.append(control_value <= limit_value)
			else:
				stack.append(control_value >= limit_value)
		OP.CALL:
			_call_fixed(thread, frame, int(a), int(b), line)
		OP.CALL_MARK:
			_call_mark(thread, frame, int(a), int(b), line)
		OP.VARARG:
			var values: Array = frame["varargs"]
			if int(a) == -1:
				stack.append_array(values)
			elif values.is_empty():
				stack.append(null)
			else:
				stack.append(values[0])
		OP.RETURN:
			var count := int(a)
			var values: Array = []
			if count > 0:
				values = stack.slice(maxi(0, stack.size() - count))
				stack.resize(maxi(0, stack.size() - count))
			_return_from_frame(thread, frame, values)
		OP.CLOSURE:
			var proto: LuaPrototype = frame["proto"].protos[int(a)]
			var lua_function := LuaFunction.new(proto)
			for descriptor in proto.upvalues:
				if bool(descriptor[0]):
					lua_function.upvalues.append(_cell(frame, int(descriptor[1]), thread, line))
				else:
					lua_function.upvalues.append(_upvalue(frame, int(descriptor[1]), thread, line))
			stack.append(lua_function)
		OP.TFORRESULT:
			var count := maxi(1, b.size())
			var values := stack.slice(maxi(0, stack.size() - count))
			stack.resize(maxi(0, stack.size() - count))
			if values.is_empty() or values[0] == null:
				stack.append(false)
			else:
				_cell(frame, int(a), thread, line).value = values[0]
				for i in b.size():
					var value = values[i] if i < values.size() else null
					_cell(frame, int(b[i]), thread, line).value = value
				stack.append(true)
		_:
			_raise(thread, "opcode non implementato: %d" % op, line)


func _call_fixed(thread: LuaThread, frame: Dictionary, nargs: int, nresults: int, line: int) -> void:
	var stack: Array = frame["stack"]
	if stack.size() < nargs + 1:
		_raise(thread, "stack della chiamata non valido", line)
		return
	var args: Array = stack.slice(stack.size() - nargs)
	stack.resize(stack.size() - nargs)
	var lua_function = stack.pop_back()
	_invoke(thread, frame, lua_function, args, nresults, line)


func _call_mark(thread: LuaThread, frame: Dictionary, nbelow: int, nresults: int, line: int) -> void:
	var stack: Array = frame["stack"]
	var marker_index := stack.rfind(_marker)
	if marker_index < 0 or marker_index - nbelow - 1 < 0:
		_raise(thread, "stack della chiamata non valido", line)
		return
	var above: Array = stack.slice(marker_index + 1)
	var below: Array = stack.slice(marker_index - nbelow, marker_index)
	stack.resize(marker_index - nbelow)
	var lua_function = stack.pop_back()
	_invoke(thread, frame, lua_function, below + above, nresults, line)


func _invoke(
	thread: LuaThread, frame: Dictionary, lua_function, args: Array, nresults: int, line: int
) -> void:
	if lua_function is LuaFunction:
		if thread.frames.size() >= MAX_CALL_DEPTH:
			_raise(thread, "troppe chiamate annidate (massimo %d)" % MAX_CALL_DEPTH, line)
			return
		thread.frames.append(_make_frame(lua_function, args, nresults))
		return
	if lua_function is LuaBuiltin:
		_pending_error = ""
		_wait_requested = false
		var result = lua_function.fn.call(args, self)
		if _pending_error != "":
			var message := _pending_error
			_pending_error = ""
			_raise(thread, message, line)
			return
		var values: Array = []
		if result is LuaValues.Multi:
			values = result.values
		else:
			values = [result]
		_push_results(frame, values, nresults)
		if _wait_requested:
			_wait_requested = false
			thread.status = "waiting"
			thread.wake_at = _now() + _wait_seconds
		return
	if lua_function is LuaValues.Method:
		var call_args: Array = args
		if not call_args.is_empty() and call_args[0] == lua_function.target:
			call_args = call_args.slice(1)
		var outcome: Dictionary = LuaRobloxAPI.call_method(
			lua_function.target, lua_function.method_name, call_args, self
		)
		if not bool(outcome.get("ok", false)):
			_raise(thread, str(outcome.get("error", "metodo non disponibile")), line)
			return
		var values: Array = outcome.get("values", [])
		_push_results(frame, values, nresults)
		return
	if lua_function == null:
		_raise(thread, "tentativo di chiamare un valore nil", line)
		return
	_raise(thread, "tentativo di chiamare un %s" % LuaValues.type_name(lua_function), line)


func _make_frame(lua_function: LuaFunction, args: Array, return_adjust: int) -> Dictionary:
	var proto := lua_function.proto
	var locals: Array = []
	locals.resize(proto.max_slots)
	for i in mini(proto.num_params, args.size()):
		locals[i] = LuaValues.Cell.new(args[i])
	for i in range(args.size(), proto.num_params):
		locals[i] = LuaValues.Cell.new()
	var varargs: Array = []
	if proto.is_vararg and args.size() > proto.num_params:
		varargs = args.slice(proto.num_params)
	return {
		"proto": proto,
		"closure": lua_function,
		"pc": 0,
		"locals": locals,
		"stack": [],
		"varargs": varargs,
		"return_adjust": return_adjust,
	}


func _return_from_frame(thread: LuaThread, frame: Dictionary, results: Array) -> void:
	thread.frames.pop_back()
	var adjusted := _adjust_results(results, int(frame.get("return_adjust", 0)))
	if thread.frames.is_empty():
		thread.status = "done"
		return
	var caller: Dictionary = thread.frames[thread.frames.size() - 1]
	caller["stack"].append_array(adjusted)


func _adjust_results(results: Array, nresults: int) -> Array:
	if nresults == 0:
		return []
	if nresults == 1:
		return [results[0] if not results.is_empty() else null]
	if nresults < 0:
		return results
	var output: Array = results.duplicate()
	while output.size() < nresults:
		output.append(null)
	output.resize(nresults)
	return output


func _push_results(frame: Dictionary, values: Array, nresults: int) -> void:
	frame["stack"].append_array(_adjust_results(values, nresults))


func _run_until(thread: LuaThread, depth: int, instruction_cap: int) -> void:
	var count := 0
	while thread.status == "ready" and thread.frames.size() > depth:
		var frame: Dictionary = thread.frames[thread.frames.size() - 1]
		var proto: LuaPrototype = frame["proto"]
		if int(frame["pc"]) >= proto.instructions.size():
			_return_from_frame(thread, frame, [])
			continue
		var instruction: Dictionary = proto.instructions[int(frame["pc"])]
		frame["pc"] = int(frame["pc"]) + 1
		_execute(thread, frame, instruction)
		count += 1
		if count >= instruction_cap:
			_raise(thread, "esecuzione troppo lunga", int(instruction["line"]))
			return


func protected_call(args: Array) -> Array:
	## Implementa `pcall`: esegue una funzione senza sospensioni e cattura gli errori.
	if args.is_empty() or not LuaValues.is_callable(args[0]):
		return [false, "pcall: funzione mancante o non valida"]
	var thread := _current_thread
	if thread == null or thread.frames.is_empty():
		return [false, "pcall: nessun contesto di esecuzione"]
	var frame: Dictionary = thread.frames[thread.frames.size() - 1]
	var depth := thread.frames.size()
	var stack_start: int = frame["stack"].size()
	var lua_function = args[0]
	var call_args: Array = args.slice(1)
	_pending_error = ""
	_wait_requested = false
	if lua_function is LuaFunction:
		thread.frames.append(_make_frame(lua_function, call_args, -1))
		_run_until(thread, depth, MAX_INSTRUCTIONS_PER_SLICE)
	elif lua_function is LuaBuiltin or lua_function is LuaValues.Method:
		_invoke(thread, frame, lua_function, call_args, -1, 0)
	else:
		return [false, "pcall: valore non chiamabile"]
	if thread.status == "error":
		var message := thread.error_text
		thread.status = "ready"
		thread.error_text = ""
		thread.frames.resize(mini(depth, thread.frames.size()))
		frame["stack"].resize(stack_start)
		_pending_error = ""
		_wait_requested = false
		return [false, message]
	if thread.status == "waiting":
		thread.status = "ready"
		thread.wake_at = 0.0
		thread.frames.resize(mini(depth, thread.frames.size()))
		frame["stack"].resize(stack_start)
		_pending_error = ""
		_wait_requested = false
		return [false, "task.wait non può sospendere dentro pcall"]
	var results: Array = frame["stack"].slice(stack_start)
	frame["stack"].resize(stack_start)
	return [true] + results


# --- Helper --------------------------------------------------------------------

func _cell(frame: Dictionary, index: int, thread: LuaThread, line: int) -> LuaValues.Cell:
	if index < 0 or index >= frame["locals"].size():
		_raise(thread, "slot locale non valido: %d" % index, line)
		return LuaValues.Cell.new()
	var cell = frame["locals"][index]
	if cell == null:
		cell = LuaValues.Cell.new()
		frame["locals"][index] = cell
	return cell


func _upvalue(frame: Dictionary, index: int, thread: LuaThread, line: int) -> LuaValues.Cell:
	var closure: LuaFunction = frame["closure"]
	if closure == null or index < 0 or index >= closure.upvalues.size():
		_raise(thread, "upvalue non valido: %d" % index, line)
		return LuaValues.Cell.new()
	return closure.upvalues[index]


func _pop(stack: Array, thread: LuaThread, line: int):
	if stack.is_empty():
		_raise(thread, "stack vuoto", line)
		return null
	return stack.pop_back()


func _peek(stack: Array, thread: LuaThread, line: int):
	if stack.is_empty():
		_raise(thread, "stack vuoto", line)
		return null
	return stack[stack.size() - 1]


func _pop_until_marker(stack: Array, thread: LuaThread, line: int) -> Array:
	var index := stack.rfind(_marker)
	if index < 0:
		_raise(thread, "marcatore di stack mancante", line)
		return []
	var values: Array = stack.slice(index + 1)
	stack.resize(index)
	return values


func _raise(thread: LuaThread, message: String, line: int) -> void:
	if thread.status == "error":
		return
	thread.error_text = LuaError.format(script_name, line, message)
	thread.status = "error"


func _report_compile_error(message: String, line: int) -> void:
	if host:
		host.report_error(LuaError.format(script_name, line, message), self)


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


func _concat_operand(value) -> bool:
	return value is String or LuaValues.is_number(value)


func _index_get(target, key, thread: LuaThread, line: int):
	if target is LuaTable:
		return (target as LuaTable).get_value(key)
	if target == null:
		_raise(thread, "tentativo di indicizzare nil", line)
		return null
	if target is int or target is float or target is bool:
		_raise(thread, "tentativo di indicizzare un %s" % LuaValues.type_name(target), line)
		return null
	var outcome: Dictionary = LuaRobloxAPI.get_property(target, key, self)
	if bool(outcome.get("ok", false)):
		return outcome.get("value")
	if target is Object:
		if key is String and target is Node:
			var child: Node = (target as Node).find_child(str(key), false, false)
			return child
		return null
	_raise(thread, "tentativo di indicizzare un %s" % LuaValues.type_name(target), line)
	return null


func _index_set(target, key, value, thread: LuaThread, line: int) -> void:
	if target is LuaTable:
		var table: LuaTable = target
		if table.size() >= LuaTable.MAX_ENTRIES and not table.has_key(key):
			_raise(thread, "tabella troppo grande (massimo %d elementi)" % LuaTable.MAX_ENTRIES, line)
			return
		table.set_value(key, value)
		return
	if target == null:
		_raise(thread, "tentativo di assegnare un campo di nil", line)
		return
	if LuaRobloxAPI.set_property(target, key, value, self):
		return
	_raise(thread, "impossibile assegnare il campo \"%s\" a un %s" % [
		str(key), LuaValues.type_name(target)
	], line)


func _binary_arithmetic(op: int, left, right) -> Array:
	var left_number = LuaValues.to_number(left) if not (left is String) else null
	var right_number = LuaValues.to_number(right) if not (right is String) else null
	if LuaValues.is_number(left) and LuaValues.is_number(right):
		left_number = float(left)
		right_number = float(right)
	match op:
		OP.ADD:
			if left_number != null and right_number != null:
				return [true, float(left_number) + float(right_number)]
			if left is Vector3 and right is Vector3:
				return [true, left + right]
			if left is Vector3 and right_number != null:
				return [true, left + Vector3(float(right_number), float(right_number), float(right_number))]
			if right is Vector3 and left_number != null:
				return [true, Vector3(float(left_number), float(left_number), float(left_number)) + right]
		OP.SUB:
			if left_number != null and right_number != null:
				return [true, float(left_number) - float(right_number)]
			if left is Vector3 and right is Vector3:
				return [true, left - right]
			if left is Vector3 and right_number != null:
				return [true, left - Vector3(float(right_number), float(right_number), float(right_number))]
		OP.MUL:
			if left_number != null and right_number != null:
				return [true, float(left_number) * float(right_number)]
			if left is Vector3 and right_number != null:
				return [true, left * float(right_number)]
			if right is Vector3 and left_number != null:
				return [true, right * float(left_number)]
		OP.DIV:
			if left_number != null and right_number != null:
				var divisor := float(right_number)
				if divisor == 0.0:
					return [true, INF if float(left_number) > 0.0 else (-INF if float(left_number) < 0.0 else NAN)]
				return [true, float(left_number) / divisor]
			if left is Vector3 and right_number != null:
				return [true, left / float(right_number)]
		OP.MOD:
			if left_number != null and right_number != null:
				if float(right_number) == 0.0:
					return [true, NAN]
				return [true, fmod(float(left_number), float(right_number))]
		OP.POW:
			if left_number != null and right_number != null:
				return [true, pow(float(left_number), float(right_number))]
	return [false, "operazione non valida tra %s e %s" % [
		LuaValues.type_name(left), LuaValues.type_name(right)
	]]


func _compare(op: int, left, right) -> Array:
	if LuaValues.is_number(left) and LuaValues.is_number(right):
		var a := float(left)
		var b := float(right)
		match op:
			OP.LT:
				return [true, a < b]
			OP.LE:
				return [true, a <= b]
			OP.GT:
				return [true, a > b]
			OP.GE:
				return [true, a >= b]
	if left is String and right is String:
		match op:
			OP.LT:
				return [true, left < right]
			OP.LE:
				return [true, left <= right]
			OP.GT:
				return [true, left > right]
			OP.GE:
				return [true, left >= right]
	return [false, "confronto non valido tra %s e %s" % [
		LuaValues.type_name(left), LuaValues.type_name(right)
	]]
