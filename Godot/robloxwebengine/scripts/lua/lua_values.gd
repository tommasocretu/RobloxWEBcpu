class_name LuaValues
extends RefCounted
## Utilità comuni sui valori Lua: tipi, verità, uguaglianza, conversioni e
## piccoli oggetti di supporto (celle, ritorni multipli, metodi legati).

const MAX_SAFE_NUMBER := 1.0e15


## Cella condivisa da una variabile locale e dalle closure che la catturano.
class Cell extends RefCounted:
	var value = null

	func _init(initial_value = null) -> void:
		value = initial_value


## Ritorno multiplo di una funzione (builtin o callback).
class Multi extends RefCounted:
	var values: Array = []

	func _init(items: Array = []) -> void:
		values = items


## Metodo legato a un oggetto userdata: `part:Destroy()`.
class Method extends RefCounted:
	var target
	var method_name: String

	func _init(object, name: String) -> void:
		target = object
		method_name = name


static func truthy(value) -> bool:
	if value == null:
		return false
	if value is bool:
		return value
	return true


static func type_name(value) -> String:
	if value == null:
		return "nil"
	if value is bool:
		return "boolean"
	if value is int or value is float:
		return "number"
	if value is String:
		return "string"
	if value is LuaTable:
		return "table"
	if value is LuaFunction or value is LuaBuiltin or value is Method:
		return "function"
	return "userdata"


static func is_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func as_number(value, fallback := 0.0) -> float:
	if value is int or value is float:
		return float(value)
	return fallback


static func normalize_number(value: float) -> Variant:
	## Tutti i numeri Lua sono float; evita int dove non serve.
	return float(value)


static func to_text(value) -> String:
	if value == null:
		return "nil"
	if value is bool:
		return "true" if value else "false"
	if value is int or value is float:
		var f := float(value)
		if is_finite(f) and f == floor(f) and absf(f) < MAX_SAFE_NUMBER:
			return "%d" % int(f)
		return "%.14g" % f
	if value is String:
		return value
	if value is LuaTable:
		return "table: 0x%x" % value.get_instance_id()
	if value is LuaFunction or value is LuaBuiltin:
		return "function: 0x%x" % value.get_instance_id()
	if value is Method:
		return "function: %s" % value.method_name
	if value is Vector3:
		return "Vector3(%s, %s, %s)" % [
			to_text(value.x), to_text(value.y), to_text(value.z)
		]
	if value is Color:
		return "Color(%s, %s, %s)" % [
			to_text(value.r), to_text(value.g), to_text(value.b)
		]
	if value is Object:
		return str(value.name) if value.name != "" else "Instance"
	return str(value)


static func equals(a, b) -> bool:
	if a == null or b == null:
		return a == null and b == null
	if a is int or a is float:
		return (b is int or b is float) and float(a) == float(b)
	if a is String and b is String:
		return a == b
	if a is bool and b is bool:
		return a == b
	if a is LuaTable or a is LuaFunction or a is LuaBuiltin or a is Method:
		return a == b
	if a is Vector3 and b is Vector3:
		return a.is_equal_approx(b)
	if a is Color and b is Color:
		return a.is_equal_approx(b)
	if a is Object and b is Object:
		return a == b
	return false


static func to_number(value) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is String:
		var text: String = str(value).strip_edges()
		if text.is_valid_float():
			return text.to_float()
		if text.is_valid_int():
			return float(text.to_int())
	return null


static func to_vec3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is LuaTable:
		var x = value.get_value(1.0)
		var y = value.get_value(2.0)
		var z = value.get_value(3.0)
		return Vector3(as_number(x), as_number(y), as_number(z))
	return Vector3.ZERO


static func to_color(value) -> Color:
	if value is Color:
		return value
	if value is LuaTable:
		return Color(
			as_number(value.get_value(1.0)),
			as_number(value.get_value(2.0)),
			as_number(value.get_value(3.0))
		)
	return Color.WHITE


static func is_callable(value) -> bool:
	return value is LuaFunction or value is LuaBuiltin or value is Method
