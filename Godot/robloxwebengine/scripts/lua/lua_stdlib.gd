class_name LuaStdlib
extends RefCounted
## Standard library del sandbox Lua: math, string, table, print/task, pcall,
## conversioni e costruttori Vector3/Color3/Instance. Nessun accesso a OS,
## filesystem, rete, Engine o API Godot arbitrarie.


static func install(vm: LuaVM) -> void:
	var globals := vm.globals
	globals.set_value("print", _builtin("print", func(args: Array, context) -> Variant:
		var parts: Array[String] = []
		for value in args:
			parts.append(LuaValues.to_text(value))
		context.output("\t".join(parts), 0)
		return null
	))
	globals.set_value("warn", _builtin("warn", func(args: Array, context) -> Variant:
		var parts: Array[String] = []
		for value in args:
			parts.append(LuaValues.to_text(value))
		context.output("\t".join(parts), 1)
		return null
	))
	globals.set_value("tostring", _builtin("tostring", func(args: Array, _context) -> Variant:
		return LuaValues.to_text(args[0] if not args.is_empty() else null)
	))
	globals.set_value("tonumber", _builtin("tonumber", func(args: Array, _context) -> Variant:
		if args.is_empty():
			return null
		if args.size() >= 2 and LuaValues.is_number(args[1]):
			return _tonumber_base(args[0], int(args[1]))
		return LuaValues.to_number(args[0])
	))
	globals.set_value("type", _builtin("type", func(args: Array, _context) -> Variant:
		return LuaValues.type_name(args[0] if not args.is_empty() else null)
	))
	globals.set_value("typeof", _builtin("typeof", func(args: Array, _context) -> Variant:
		return LuaValues.type_name(args[0] if not args.is_empty() else null)
	))
	globals.set_value("rawget", _builtin("rawget", func(args: Array, _context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			return null
		return (args[0] as LuaTable).get_value(args[1] if args.size() > 1 else null)
	))
	globals.set_value("rawset", _builtin("rawset", func(args: Array, _context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			return null
		(args[0] as LuaTable).set_value(args[1] if args.size() > 1 else null,
			args[2] if args.size() > 2 else null)
		return args[0]
	))

	var next_function := _builtin("next", func(args: Array, _context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			return null
		var table: LuaTable = args[0]
		var current = args[1] if args.size() > 1 else null
		var key = table.find_key_after(current)
		if key == null:
			return null
		return LuaValues.Multi.new([key, table.get_value(key)])
	)
	globals.set_value("next", next_function)
	globals.set_value("pairs", _builtin("pairs", func(args: Array, context) -> Variant:
		var table = args[0] if not args.is_empty() else LuaTable.new()
		if not (table is LuaTable):
			context.raise_pending("pairs richiede una tabella")
			return null
		return LuaValues.Multi.new([context.get_global("next"), table, null])
	))
	globals.set_value("ipairs", _builtin("ipairs", func(args: Array, context) -> Variant:
		var table = args[0] if not args.is_empty() else LuaTable.new()
		if not (table is LuaTable):
			context.raise_pending("ipairs richiede una tabella")
			return null
		var iterator := _builtin("ipairs_iter", func(iterator_args: Array, _ctx) -> Variant:
			if iterator_args.is_empty() or not (iterator_args[0] is LuaTable):
				return null
			var current := int(iterator_args[1]) if iterator_args.size() > 1 else 0
			var next_index := current + 1
			var value = (iterator_args[0] as LuaTable).get_value(float(next_index))
			if value == null:
				return null
			return LuaValues.Multi.new([float(next_index), value])
		)
		return LuaValues.Multi.new([iterator, table, 0.0])
	))
	globals.set_value("select", _builtin("select", func(args: Array, _context) -> Variant:
		if args.is_empty():
			return null
		if args[0] is String and args[0] == "#":
			return float(maxi(0, args.size() - 1))
		var index := int(args[0]) if LuaValues.is_number(args[0]) else 1
		if index < 0:
			index = args.size() + index
		index = maxi(1, index)
		return LuaValues.Multi.new(args.slice(index))
	))
	globals.set_value("unpack", _builtin("unpack", func(args: Array, _context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			return null
		var table: LuaTable = args[0]
		var first := int(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 1
		var last := int(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else table.length()
		var values: Array = []
		for i in range(first, last + 1):
			values.append(table.get_value(float(i)))
		return LuaValues.Multi.new(values)
	))
	globals.set_value("pcall", _builtin("pcall", func(args: Array, context) -> Variant:
		return LuaValues.Multi.new(context.protected_call(args))
	))
	globals.set_value("error", _builtin("error", func(args: Array, context) -> Variant:
		context.raise_pending(LuaValues.to_text(args[0] if not args.is_empty() else "errore"))
		return null
	))
	globals.set_value("assert", _builtin("assert", func(args: Array, context) -> Variant:
		var condition = args[0] if not args.is_empty() else null
		if not LuaValues.truthy(condition):
			context.raise_pending(
				LuaValues.to_text(args[1]) if args.size() > 1 else "asserzione fallita!"
			)
			return null
		return LuaValues.Multi.new(args)
	))

	_install_task(globals)
	_install_math(globals)
	_install_string(globals)
	_install_table(globals)
	_install_constructors(globals)


static func _builtin(name: String, callable: Callable) -> LuaBuiltin:
	return LuaBuiltin.new(name, callable)


static func _install_task(globals: LuaTable) -> void:
	var task_table := LuaTable.new()
	var wait_function := _builtin("wait", func(args: Array, context) -> Variant:
		var seconds := float(args[0]) if not args.is_empty() and LuaValues.is_number(args[0]) else 0.0
		context.request_wait(seconds)
		return null
	)
	task_table.set_value("wait", wait_function)
	task_table.set_value("spawn", _builtin("spawn", func(args: Array, context) -> Variant:
		if args.is_empty() or not LuaValues.is_callable(args[0]):
			context.raise_pending("task.spawn richiede una funzione")
			return null
		context.spawn(args[0], args.slice(1), 0.0, "task.spawn")
		return null
	))
	task_table.set_value("delay", _builtin("delay", func(args: Array, context) -> Variant:
		if args.size() < 2 or not LuaValues.is_callable(args[1]):
			context.raise_pending("task.delay richiede secondi e una funzione")
			return null
		var seconds := float(args[0]) if LuaValues.is_number(args[0]) else 0.0
		context.spawn(args[1], args.slice(2), maxf(0.0, seconds), "task.delay")
		return null
	))
	globals.set_value("task", task_table)
	globals.set_value("wait", wait_function)
	globals.set_value("spawn", task_table.get_value("spawn"))
	globals.set_value("delay", task_table.get_value("delay"))


static func _install_math(globals: LuaTable) -> void:
	var math_table := LuaTable.new()
	math_table.set_value("pi", PI)
	math_table.set_value("huge", INF)
	math_table.set_value("abs", _math1(func(value: float) -> float: return absf(value)))
	math_table.set_value("ceil", _math1(func(value: float) -> float: return ceilf(value)))
	math_table.set_value("floor", _math1(func(value: float) -> float: return floorf(value)))
	math_table.set_value("sqrt", _math1(func(value: float) -> float: return sqrt(maxf(0.0, value))))
	math_table.set_value("sin", _math1(func(value: float) -> float: return sin(value)))
	math_table.set_value("cos", _math1(func(value: float) -> float: return cos(value)))
	math_table.set_value("tan", _math1(func(value: float) -> float: return tan(value)))
	math_table.set_value("asin", _math1(func(value: float) -> float: return asin(clampf(value, -1.0, 1.0))))
	math_table.set_value("acos", _math1(func(value: float) -> float: return acos(clampf(value, -1.0, 1.0))))
	math_table.set_value("atan", _math1(func(value: float) -> float: return atan(value)))
	math_table.set_value("deg", _math1(func(value: float) -> float: return rad_to_deg(value)))
	math_table.set_value("rad", _math1(func(value: float) -> float: return deg_to_rad(value)))
	math_table.set_value("sign", _math1(func(value: float) -> float: return signf(value)))
	math_table.set_value("round", _math1(func(value: float) -> float: return roundf(value)))
	math_table.set_value("fmod", _builtin("fmod", func(args: Array, _context) -> Variant:
		if args.size() < 2 or not LuaValues.is_number(args[0]) or not LuaValues.is_number(args[1]):
			return null
		return fmod(float(args[0]), float(args[1]))
	))
	math_table.set_value("pow", _builtin("pow", func(args: Array, _context) -> Variant:
		if args.size() < 2 or not LuaValues.is_number(args[0]) or not LuaValues.is_number(args[1]):
			return null
		return pow(float(args[0]), float(args[1]))
	))
	math_table.set_value("max", _builtin("max", func(args: Array, _context) -> Variant:
		if args.is_empty():
			return null
		var result = args[0]
		for value in args:
			if LuaValues.is_number(value) and LuaValues.is_number(result) and float(value) > float(result):
				result = value
		return result
	))
	math_table.set_value("min", _builtin("min", func(args: Array, _context) -> Variant:
		if args.is_empty():
			return null
		var result = args[0]
		for value in args:
			if LuaValues.is_number(value) and LuaValues.is_number(result) and float(value) < float(result):
				result = value
		return result
	))
	math_table.set_value("clamp", _builtin("clamp", func(args: Array, _context) -> Variant:
		if args.size() < 3 or not LuaValues.is_number(args[0]):
			return null
		return clampf(float(args[0]), float(args[1]), float(args[2]))
	))
	math_table.set_value("random", _builtin("random", func(args: Array, _context) -> Variant:
		if args.is_empty():
			return randf()
		if args.size() == 1 and LuaValues.is_number(args[0]):
			var upper := int(args[0])
			return float(randi_range(1, maxi(1, upper)))
		if args.size() >= 2 and LuaValues.is_number(args[0]) and LuaValues.is_number(args[1]):
			return float(randi_range(int(args[0]), int(args[1])))
		return randf()
	))
	math_table.set_value("randomseed", _builtin("randomseed", func(args: Array, _context) -> Variant:
		seed(int(args[0]) if not args.is_empty() and LuaValues.is_number(args[0]) else 0)
		return null
	))
	globals.set_value("math", math_table)


static func _math1(callable: Callable) -> LuaBuiltin:
	return _builtin("math", func(args: Array, context) -> Variant:
		if args.is_empty() or not LuaValues.is_number(args[0]):
			context.raise_pending("la funzione matematica richiede un numero")
			return null
		return callable.call(float(args[0]))
	)


static func _install_string(globals: LuaTable) -> void:
	var string_table := LuaTable.new()
	string_table.set_value("len", _builtin("string.len", func(args: Array, _context) -> Variant:
		return float(LuaValues.to_text(args[0] if not args.is_empty() else "").length())
	))
	string_table.set_value("sub", _builtin("string.sub", func(args: Array, _context) -> Variant:
		return string_sub(
			LuaValues.to_text(args[0] if not args.is_empty() else ""),
			int(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 1,
			int(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else null
		)
	))
	string_table.set_value("upper", _builtin("string.upper", func(args: Array, _context) -> Variant:
		return LuaValues.to_text(args[0] if not args.is_empty() else "").to_upper()
	))
	string_table.set_value("lower", _builtin("string.lower", func(args: Array, _context) -> Variant:
		return LuaValues.to_text(args[0] if not args.is_empty() else "").to_lower()
	))
	string_table.set_value("rep", _builtin("string.rep", func(args: Array, context) -> Variant:
		var text := LuaValues.to_text(args[0] if not args.is_empty() else "")
		var count := int(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 0
		var separator := LuaValues.to_text(args[2]) if args.size() > 2 else ""
		var output := ""
		for i in maxi(0, count):
			if output.length() + text.length() > 1048576:
				context.raise_pending("string.rep: risultato troppo lungo (massimo 1 MB)")
				return null
			if i > 0:
				output += separator
			output += text
		return output
	))
	string_table.set_value("format", _builtin("string.format", func(args: Array, context) -> Variant:
		if args.is_empty():
			return ""
		return string_format(args, context)
	))
	string_table.set_value("find", _builtin("string.find", func(args: Array, _context) -> Variant:
		var text := LuaValues.to_text(args[0] if not args.is_empty() else "")
		var needle := LuaValues.to_text(args[1]) if args.size() > 1 else ""
		var start := int(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else 1
		return string_find(text, needle, start)
	))
	string_table.set_value("gsub", _builtin("string.gsub", func(args: Array, _context) -> Variant:
		var text := LuaValues.to_text(args[0] if not args.is_empty() else "")
		var needle := LuaValues.to_text(args[1]) if args.size() > 1 else ""
		var replacement := LuaValues.to_text(args[2]) if args.size() > 2 else ""
		var result := string_gsub(text, needle, replacement)
		return LuaValues.Multi.new([result[0], float(result[1])])
	))
	string_table.set_value("byte", _builtin("string.byte", func(args: Array, _context) -> Variant:
		var text := LuaValues.to_text(args[0] if not args.is_empty() else "")
		var index := int(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 1
		if index < 0:
			index = text.length() + index + 1
		if index < 1 or index > text.length():
			return null
		return float(text.unicode_at(index - 1))
	))
	string_table.set_value("char", _builtin("string.char", func(args: Array, _context) -> Variant:
		var output := ""
		for value in args:
			if LuaValues.is_number(value):
				output += char(int(value))
		return output
	))
	globals.set_value("string", string_table)


static func _install_table(globals: LuaTable) -> void:
	var table_table := LuaTable.new()
	table_table.set_value("insert", _builtin("table.insert", func(args: Array, context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			context.raise_pending("table.insert richiede una tabella")
			return null
		var table: LuaTable = args[0]
		if args.size() == 2:
			table.set_value(float(table.length() + 1), args[1])
			return null
		if args.size() >= 3 and LuaValues.is_number(args[1]):
			var position := clampi(int(args[1]), 1, table.length() + 1)
			for i in range(table.length(), position - 1, -1):
				table.set_value(float(i + 1), table.get_value(float(i)))
			table.set_value(float(position), args[2])
		return null
	))
	table_table.set_value("remove", _builtin("table.remove", func(args: Array, context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			context.raise_pending("table.remove richiede una tabella")
			return null
		var table: LuaTable = args[0]
		var count := table.length()
		var position := int(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else count
		if position < 1 or position > count:
			return null
		var removed = table.get_value(float(position))
		for i in range(position, count):
			table.set_value(float(i), table.get_value(float(i + 1)))
		table.set_value(float(count), null)
		return removed
	))
	table_table.set_value("concat", _builtin("table.concat", func(args: Array, context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			context.raise_pending("table.concat richiede una tabella")
			return null
		var table: LuaTable = args[0]
		var separator := LuaValues.to_text(args[1]) if args.size() > 1 else ""
		var first := int(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else 1
		var last := int(args[3]) if args.size() > 3 and LuaValues.is_number(args[3]) else table.length()
		var parts: Array[String] = []
		for i in range(first, last + 1):
			parts.append(LuaValues.to_text(table.get_value(float(i))))
		return separator.join(parts)
	))
	table_table.set_value("sort", _builtin("table.sort", func(args: Array, context) -> Variant:
		if args.is_empty() or not (args[0] is LuaTable):
			context.raise_pending("table.sort richiede una tabella")
			return null
		var table: LuaTable = args[0]
		var count := table.length()
		var values: Array = []
		for i in range(1, count + 1):
			values.append(table.get_value(float(i)))
		values.sort_custom(func(left, right) -> bool:
			if LuaValues.is_number(left) and LuaValues.is_number(right):
				return float(left) < float(right)
			return LuaValues.to_text(left) < LuaValues.to_text(right)
		)
		for i in values.size():
			table.set_value(float(i + 1), values[i])
		return null
	))
	globals.set_value("table", table_table)


static func _install_constructors(globals: LuaTable) -> void:
	var vector_table := LuaTable.new()
	vector_table.set_value("new", _builtin("Vector3.new", func(args: Array, _context) -> Variant:
		return Vector3(
			float(args[0]) if args.size() > 0 and LuaValues.is_number(args[0]) else 0.0,
			float(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 0.0,
			float(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else 0.0
		)
	))
	vector_table.set_value("zero", Vector3.ZERO)
	vector_table.set_value("one", Vector3.ONE)
	globals.set_value("Vector3", vector_table)

	var color_table := LuaTable.new()
	color_table.set_value("new", _builtin("Color3.new", func(args: Array, _context) -> Variant:
		return Color(
			float(args[0]) if args.size() > 0 and LuaValues.is_number(args[0]) else 0.0,
			float(args[1]) if args.size() > 1 and LuaValues.is_number(args[1]) else 0.0,
			float(args[2]) if args.size() > 2 and LuaValues.is_number(args[2]) else 0.0
		)
	))
	color_table.set_value("fromRGB", _builtin("Color3.fromRGB", func(args: Array, _context) -> Variant:
		return Color(
			(float(args[0]) / 255.0) if args.size() > 0 and LuaValues.is_number(args[0]) else 0.0,
			(float(args[1]) / 255.0) if args.size() > 1 and LuaValues.is_number(args[1]) else 0.0,
			(float(args[2]) / 255.0) if args.size() > 2 and LuaValues.is_number(args[2]) else 0.0
		)
	))
	globals.set_value("Color3", color_table)

	var instance_table := LuaTable.new()
	instance_table.set_value("new", _builtin("Instance.new", func(args: Array, context) -> Variant:
		var type_name := LuaValues.to_text(args[0]) if not args.is_empty() else "Part"
		var outcome: Dictionary = LuaRobloxAPI.new_instance(context, type_name)
		if not bool(outcome.get("ok", false)):
			context.raise_pending(str(outcome.get("error", "classe non supportata")))
			return null
		return outcome.get("value")
	))
	globals.set_value("Instance", instance_table)


# --- Helper string -------------------------------------------------------------

static func call_string_method(name: String, target: String, args: Array) -> Dictionary:
	var all_args: Array = [target]
	all_args.append_array(args)
	match name:
		"len":
			return {"ok": true, "values": [float(target.length())]}
		"sub":
			return {"ok": true, "values": [string_sub(
				target,
				int(all_args[1]) if all_args.size() > 1 and LuaValues.is_number(all_args[1]) else 1,
				int(all_args[2]) if all_args.size() > 2 and LuaValues.is_number(all_args[2]) else null
			)]}
		"upper":
			return {"ok": true, "values": [target.to_upper()]}
		"lower":
			return {"ok": true, "values": [target.to_lower()]}
		"rep":
			var count := int(all_args[1]) if all_args.size() > 1 and LuaValues.is_number(all_args[1]) else 0
			var separator := LuaValues.to_text(all_args[2]) if all_args.size() > 2 else ""
			var output := ""
			for i in maxi(0, count):
				if output.length() + target.length() > 1048576:
					return {"ok": false, "error": "string.rep: risultato troppo lungo (massimo 1 MB)"}
				if i > 0:
					output += separator
				output += target
			return {"ok": true, "values": [output]}
		"find":
			var needle := LuaValues.to_text(all_args[1]) if all_args.size() > 1 else ""
			var start := int(all_args[2]) if all_args.size() > 2 and LuaValues.is_number(all_args[2]) else 1
			var found: Variant = string_find(target, needle, start)
			if found is LuaValues.Multi:
				return {"ok": true, "values": found.values}
			return {"ok": true, "values": [found]}
		"gsub":
			var needle := LuaValues.to_text(all_args[1]) if all_args.size() > 1 else ""
			var replacement := LuaValues.to_text(all_args[2]) if all_args.size() > 2 else ""
			var result := string_gsub(target, needle, replacement)
			return {"ok": true, "values": [result[0], float(result[1])]}
		"format":
			var context = null
			return {"ok": true, "values": [string_format(all_args, context)]}
	return {"ok": false, "error": "metodo string sconosciuto: %s" % name}


static func string_sub(text: String, start: int, finish = null) -> String:
	var length := text.length()
	var first := start
	if first < 0:
		first = length + first + 1
	if first < 1:
		first = 1
	var last := length if finish == null else int(finish)
	if last < 0:
		last = length + last + 1
	if last > length:
		last = length
	if first > last or first > length:
		return ""
	return text.substr(first - 1, last - first + 1)


static func string_find(text: String, needle: String, start: int = 1) -> Variant:
	var begin := start
	if begin < 0:
		begin = text.length() + begin + 1
	begin = maxi(1, begin)
	if needle == "":
		return LuaValues.Multi.new([float(begin), float(begin - 1)])
	var index := text.find(needle, begin - 1)
	if index < 0:
		return null
	return LuaValues.Multi.new([float(index + 1), float(index + needle.length())])


static func string_gsub(text: String, needle: String, replacement: String) -> Array:
	if needle == "":
		return [text, 0]
	var output := text.replace(needle, replacement)
	var count := text.count(needle)
	return [output, count]


static func string_format(args: Array, _context) -> String:
	if args.is_empty():
		return ""
	var format_text := LuaValues.to_text(args[0])
	var result := ""
	var index := 0
	var arg_index := 1
	while index < format_text.length():
		var character := format_text[index]
		if character != "%":
			result += character
			index += 1
			continue
		if index + 1 >= format_text.length():
			result += "%"
			break
		var spec := "%"
		index += 1
		while index < format_text.length() and format_text[index] in "-+ #0.123456789":
			spec += format_text[index]
			index += 1
		if index >= format_text.length():
			result += spec
			break
		var code := format_text[index]
		index += 1
		spec += code
		if code == "%":
			result += "%"
			continue
		var value = args[arg_index] if arg_index < args.size() else null
		arg_index += 1
		if code == "d" or code == "i" or code == "o" or code == "u" or code == "x" or code == "X":
			result += spec % int(LuaValues.as_number(value))
		elif code == "s":
			result += spec % LuaValues.to_text(value)
		elif code in ["f", "F", "e", "E", "g", "G"]:
			result += spec % float(LuaValues.as_number(value))
		elif code == "c":
			result += char(int(LuaValues.as_number(value)))
		elif code == "q":
			result += "\"%s\"" % LuaValues.to_text(value).replace("\"", "\\\"")
		else:
			result += spec
	return result


static func _tonumber_base(value, base: int) -> Variant:
	var text := LuaValues.to_text(value).strip_edges()
	if base == 10:
		return LuaValues.to_number(text)
	if base < 2 or base > 36:
		return null
	var result := 0.0
	for i in text.length():
		var character := text[i].to_lower()
		var digit := -1
		if character >= "0" and character <= "9":
			digit = character.to_int()
		elif character >= "a" and character <= "z":
			digit = character.unicode_at(0) - "a".unicode_at(0) + 10
		if digit < 0 or digit >= base:
			return null
		result = result * base + digit
	return result
