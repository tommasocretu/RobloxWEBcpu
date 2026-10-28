class_name LuaFunction
extends RefCounted
## Funzione Lua compilata + celle upvalue catturate.

var proto: LuaPrototype
var upvalues: Array = []


func _init(function_proto: LuaPrototype = null) -> void:
	proto = function_proto
