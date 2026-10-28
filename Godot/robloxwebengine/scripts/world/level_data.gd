class_name LevelData
extends RefCounted
## Formato dati di un livello condivisibile (`.rwl.json`): mondo + metadati + script.
## V1: entità piatte (nessuna gerarchia), solo box, ambiente e luci fissi.
## Dati → scena: LevelBuilder. Scena → dati e file: LevelIO.

const FORMAT := "robloxweb-level"
const VERSION := 2
const DEFAULT_TITLE := "Livello senza titolo"
const KINDS: Array[String] = [
	"part", "spawn", "checkpoint", "coin", "goal", "kill",
	"moving_platform", "spinner", "label",
]
const MAX_PARTS := 2000
const MAX_NAME_LENGTH := 40
const MAX_TITLE_LENGTH := 60
const MAX_LABEL_LENGTH := 120
const MAX_SCRIPTS := 200
const MAX_SCRIPT_BYTES := 65536
const MAX_COORD := 100000.0
const MAX_SIZE := 2048.0

## Livello richiesto dal pulsante "Testa" dell'editor; main.gd lo consuma all'avvio.
static var play_request: Dictionary = {}


# --- Costruzione dati -------------------------------------------------------------

static func new_level(level_title := "Nuovo livello") -> Dictionary:
	var parts: Array = []
	var baseplate := make_entity(
		"part", "Baseplate", Vector3(0, -0.5, 0), Vector3(200, 1, 200), Color(0.36, 0.56, 0.32)
	)
	baseplate["id"] = "p1"
	parts.append(baseplate)
	var spawn := make_entity(
		"spawn", "SpawnLocation", Vector3(0, 0.5, 12), Vector3(10, 1, 10), Color(0.63, 0.64, 0.64)
	)
	spawn["id"] = "p2"
	parts.append(spawn)
	return {
		"format": FORMAT,
		"version": VERSION,
		"meta": {
			"title": level_title,
			"author": "",
			"description": "",
		},
		"parts": parts,
		"scripts": [],
	}


static func make_entity(
	kind: String, entity_name: String, position: Vector3, size: Vector3, color: Color
) -> Dictionary:
	return {
		"id": "",
		"name": entity_name,
		"kind": kind,
		"position": vec3_array(position),
		"rotation": [0.0, 0.0, 0.0],
		"size": vec3_array(size),
		"color": color_to_hex(color),
		"anchored": true,
		"collide": true,
		"transparency": 0.0,
		"props": {},
	}


static func next_id(parts: Array) -> String:
	var max_id := 0
	for entity in parts:
		if typeof(entity) != TYPE_DICTIONARY:
			continue
		var id := str(entity.get("id", ""))
		if id.begins_with("p") and id.substr(1).is_valid_int():
			max_id = maxi(max_id, id.substr(1).to_int())
	return "p%d" % (max_id + 1)


static func next_name(parts: Array, base: String) -> String:
	var used := {}
	for entity in parts:
		if typeof(entity) == TYPE_DICTIONARY:
			used[str(entity.get("name", ""))] = true
	if not used.has(base):
		return base
	var index := 2
	while used.has("%s%d" % [base, index]):
		index += 1
	return "%s%d" % [base, index]


static func next_script_id(scripts: Array) -> String:
	var max_id := 0
	for script in scripts:
		if typeof(script) != TYPE_DICTIONARY:
			continue
		var id := str(script.get("id", ""))
		if id.begins_with("s") and id.substr(1).is_valid_int():
			max_id = maxi(max_id, id.substr(1).to_int())
	return "s%d" % (max_id + 1)


static func next_script_name(scripts: Array, base := "Script") -> String:
	var used := {}
	for script in scripts:
		if typeof(script) == TYPE_DICTIONARY:
			used[str(script.get("name", ""))] = true
	if not used.has(base):
		return base
	var index := 2
	while used.has("%s%d" % [base, index]):
		index += 1
	return "%s%d" % [base, index]


static func title(data: Dictionary) -> String:
	var meta = data.get("meta", {})
	if typeof(meta) == TYPE_DICTIONARY:
		var value := str(meta.get("title", "")).strip_edges()
		if value != "":
			return value
	return DEFAULT_TITLE


static func slug(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i].to_lower()
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9"):
			out += c
		elif c == " " or c == "-" or c == "_":
			out += "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	out = out.trim_prefix("-").trim_suffix("-")
	return out if out != "" else "livello"


# --- Conversioni ----------------------------------------------------------------

static func vec3_array(v: Vector3) -> Array:
	return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]


static func array_to_vec3(value, fallback := Vector3.ZERO) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return fallback
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func color_to_hex(c: Color) -> String:
	return "#" + c.to_html(false)


static func hex_to_color(value, fallback := Color.WHITE) -> Color:
	if typeof(value) != TYPE_STRING:
		return fallback
	var text := str(value).strip_edges()
	if text.begins_with("#"):
		text = text.substr(1)
	if not is_valid_hex(text):
		return fallback
	return Color.html(text)


static func is_valid_hex(text: String) -> bool:
	if text.length() != 6:
		return false
	for i in text.length():
		var c := text[i].to_lower()
		if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")):
			return false
	return true


static func kind_is_valid(kind: String) -> bool:
	return KINDS.has(kind)


# --- Validazione ----------------------------------------------------------------

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("Il file non contiene un oggetto JSON.")
		return errors
	var dict: Dictionary = data
	if str(dict.get("format", "")) != FORMAT:
		errors.append("Formato non riconosciuto (atteso \"%s\")." % FORMAT)
	var version := int(dict.get("version", 0))
	if version < 1 or version > VERSION:
		errors.append("Versione del formato non supportata: %d." % version)

	var meta = dict.get("meta", {})
	if typeof(meta) != TYPE_DICTIONARY:
		errors.append("Campo \"meta\" mancante o non valido.")

	var parts = dict.get("parts")
	if typeof(parts) != TYPE_ARRAY:
		errors.append("Campo \"parts\" mancante o non valido.")
		return errors
	if parts.size() > MAX_PARTS:
		errors.append("Troppe parti: %d (massimo %d)." % [parts.size(), MAX_PARTS])

	var names := {}
	var ids := {}
	for i in parts.size():
		var entity = parts[i]
		if typeof(entity) != TYPE_DICTIONARY:
			errors.append("Parte #%d: non è un oggetto." % i)
			continue
		_validate_entity(entity, i, names, ids, errors)

	_validate_scripts(dict.get("scripts", []), ids, version, errors)
	return errors


static func _validate_entity(
	entity: Dictionary, index: int, names: Dictionary, ids: Dictionary, errors: PackedStringArray
) -> void:
	var prefix := "Parte #%d" % index
	var entity_name := str(entity.get("name", "")).strip_edges()
	var id := str(entity.get("id", ""))
	if entity_name == "":
		errors.append("%s: nome mancante." % prefix)
	elif entity_name.length() > MAX_NAME_LENGTH:
		errors.append("%s: nome troppo lungo (max %d)." % [prefix, MAX_NAME_LENGTH])
	elif names.has(entity_name):
		errors.append("%s: nome duplicato \"%s\"." % [prefix, entity_name])
	else:
		names[entity_name] = true
	if id == "":
		errors.append("%s: id mancante." % prefix)
	elif ids.has(id):
		errors.append("%s: id duplicato \"%s\"." % [prefix, id])
	else:
		ids[id] = true

	var kind := str(entity.get("kind", ""))
	if not kind_is_valid(kind):
		errors.append("%s: tipo sconosciuto \"%s\"." % [prefix, kind])

	if not _is_vec3(entity.get("position", null)):
		errors.append("%s: posizione non valida." % prefix)
	elif _vec3_max_abs(entity["position"]) > MAX_COORD:
		errors.append("%s: posizione fuori limite." % prefix)

	if not _is_vec3(entity.get("rotation", null)):
		errors.append("%s: rotazione non valida." % prefix)

	if not _is_vec3(entity.get("size", null)):
		errors.append("%s: dimensione non valida." % prefix)
	elif kind != "label":
		var size: Vector3 = array_to_vec3(entity["size"])
		if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
			errors.append("%s: dimensione nulla o negativa." % prefix)
		elif size.x > MAX_SIZE or size.y > MAX_SIZE or size.z > MAX_SIZE:
			errors.append("%s: dimensione troppo grande (max %d)." % [prefix, int(MAX_SIZE)])

	if not is_valid_hex(str(entity.get("color", "")).trim_prefix("#")):
		errors.append("%s: colore non valido (atteso #RRGGBB)." % prefix)
	if typeof(entity.get("anchored", null)) != TYPE_BOOL:
		errors.append("%s: \"anchored\" deve essere true/false." % prefix)
	if typeof(entity.get("collide", null)) != TYPE_BOOL:
		errors.append("%s: \"collide\" deve essere true/false." % prefix)
	var transparency = entity.get("transparency", null)
	if not _is_number(transparency) or float(transparency) < 0.0 or float(transparency) > 1.0:
		errors.append("%s: trasparenza fuori intervallo (0-1)." % prefix)

	var props = entity.get("props", {})
	if typeof(props) != TYPE_DICTIONARY:
		errors.append("%s: \"props\" non valido." % prefix)
		return

	match kind:
		"moving_platform":
			if props.has("offset") and not _is_vec3(props["offset"]):
				errors.append("%s: props.offset non valido." % prefix)
			if props.has("duration") and (not _is_number(props["duration"]) or float(props["duration"]) <= 0.0):
				errors.append("%s: props.duration deve essere > 0." % prefix)
		"spinner":
			if props.has("speed") and not _is_number(props["speed"]):
				errors.append("%s: props.speed non valido." % prefix)
		"kill":
			if props.has("mesh_offset") and not _is_vec3(props["mesh_offset"]):
				errors.append("%s: props.mesh_offset non valido." % prefix)
		"label":
			var text := str(props.get("text", ""))
			if text.length() > MAX_LABEL_LENGTH:
				errors.append("%s: testo troppo lungo (max %d)." % [prefix, MAX_LABEL_LENGTH])
			if props.has("pixel_size") and (not _is_number(props["pixel_size"]) or float(props["pixel_size"]) <= 0.0):
				errors.append("%s: props.pixel_size deve essere > 0." % prefix)


static func _validate_scripts(
	value, part_ids: Dictionary, version: int, errors: PackedStringArray
) -> void:
	if typeof(value) != TYPE_ARRAY:
		errors.append("Campo \"scripts\" non valido.")
		return
	var scripts: Array = value
	if scripts.size() > MAX_SCRIPTS:
		errors.append("Troppi script: %d (massimo %d)." % [scripts.size(), MAX_SCRIPTS])
	if version < 2 and not scripts.is_empty():
		errors.append("Gli script richiedono la versione 2 del formato.")
		return
	var script_ids := {}
	for i in scripts.size():
		var script = scripts[i]
		if typeof(script) != TYPE_DICTIONARY:
			errors.append("Script #%d: non è un oggetto." % i)
			continue
		var prefix := "Script #%d" % i
		var script_id := str(script.get("id", "")).strip_edges()
		if script_id == "":
			errors.append("%s: id mancante." % prefix)
		elif script_ids.has(script_id):
			errors.append("%s: id duplicato \"%s\"." % [prefix, script_id])
		else:
			script_ids[script_id] = true
		var script_name := str(script.get("name", "")).strip_edges()
		if script_name == "":
			errors.append("%s: nome mancante." % prefix)
		elif script_name.length() > MAX_NAME_LENGTH:
			errors.append("%s: nome troppo lungo (max %d)." % [prefix, MAX_NAME_LENGTH])
		var parent_id := str(script.get("parent_id", ""))
		if parent_id != "" and not part_ids.has(parent_id):
			errors.append("%s: parent_id \"%s\" non esiste." % [prefix, parent_id])
		if typeof(script.get("enabled", true)) != TYPE_BOOL:
			errors.append("%s: \"enabled\" deve essere true/false." % prefix)
		var source := str(script.get("source", ""))
		if source.to_utf8_buffer().size() > MAX_SCRIPT_BYTES:
			errors.append("%s: sorgente troppo lungo (max %d byte)." % [prefix, MAX_SCRIPT_BYTES])


static func _is_number(value) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


static func _is_vec3(value) -> bool:
	return typeof(value) == TYPE_ARRAY and value.size() == 3 \
		and _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2])


static func _vec3_max_abs(value: Array) -> float:
	return maxf(absf(float(value[0])), maxf(absf(float(value[1])), absf(float(value[2]))))
