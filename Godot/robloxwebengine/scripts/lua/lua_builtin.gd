class_name LuaBuiltin
extends RefCounted
## Funzione nativa esposta a Lua. `fn` riceve `(args: Array, vm: LuaVM)` e può
## ritornare un valore singolo o `LuaValues.Multi` per più risultati.

var builtin_name := "builtin"
var fn: Callable


func _init(name: String, callable: Callable) -> void:
	builtin_name = name
	fn = callable
