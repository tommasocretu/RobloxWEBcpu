class_name LuaTable
extends RefCounted
## Tabella Lua: chiavi e valori Variant, ordine di inserimento stabile (pairs).
## Le chiavi numeriche intere vengono normalizzate a float, così `t[1]` e `t[1.0]`
## sono la stessa chiave.

var _data: Dictionary = {}


const MAX_ENTRIES := 10000


func get_value(key):
	if key == null:
		return null
	return _data.get(_normalize_key(key), null)


func set_value(key, value) -> bool:
	if key == null:
		return false
	var normalized: Variant = _normalize_key(key)
	if value == null:
		_data.erase(normalized)
		return true
	if not _data.has(normalized) and _data.size() >= MAX_ENTRIES:
		return false
	_data[normalized] = value
	return true


func has_key(key) -> bool:
	if key == null:
		return false
	return _data.has(_normalize_key(key))


func length() -> int:
	var count := 0
	while _data.has(float(count + 1)):
		count += 1
	return count


func size() -> int:
	return _data.size()


func keys() -> Array:
	return _data.keys()


func values() -> Array:
	return _data.values()


func clear() -> void:
	_data.clear()


func find_key_after(key) -> Variant:
	## Supporto a `next(table, key)`: ritorna la chiave successiva o null.
	var found := key == null
	for candidate in _data.keys():
		if found:
			return candidate
		if LuaValues.equals(candidate, key):
			found = true
	return null


func to_dictionary() -> Dictionary:
	return _data.duplicate()


func _normalize_key(key) -> Variant:
	if key is int:
		return float(key)
	return key
