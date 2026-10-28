class_name LuaError
extends RefCounted
## Formattazione uniforme degli errori Lua: `NomeScript:riga: messaggio`.
## Lexer/parser/compiler espongono `error_message` e `error_line`; la VM usa
## `format()` per gli errori a runtime.


static func format(script_name: String, line: int, message: String) -> String:
	var name := script_name.strip_edges()
	if name == "":
		name = "script"
	if line > 0:
		return "%s:%d: %s" % [name, line, message]
	return "%s: %s" % [name, message]


static func describe(value) -> String:
	if value == null:
		return "nil"
	if value is String:
		return value
	return str(value)
