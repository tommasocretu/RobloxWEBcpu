extends SceneTree
## Test del motore Lua (M3): lexer/parser/compiler/VM, stdlib, chiusure, errori,
## sandbox e integrazione con LuaRuntime/LevelData.
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> \
##        --script res://tools/test_lua.gd

var _failures := 0


class TestHost extends RefCounted:
	var lines: Array = []
	var errors: Array = []

	func emit_output(script_name: String, text: String, level := 0) -> void:
		lines.append({"script": script_name, "text": text, "level": level})

	func report_error(text: String, _vm = null) -> void:
		errors.append(text)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_core_values()
	_test_control_flow()
	_test_tables_and_closures()
	_test_multiple_returns()
	_test_stdlib()
	_test_errors_and_pcall()
	_test_sandbox()
	_test_limits()
	_test_level_format()
	await _test_runtime_roblox_api()
	await _test_touched_signal()
	await _test_demo_level()
	await _test_main_scene_with_scripts()
	await _test_scheduler()

	print("TEST_LUA_%s" % ("OK" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	print("TEST %s: %s" % [label, condition])
	if not condition:
		_failures += 1


func _new_vm(name := "TestScript") -> Array:
	var host := TestHost.new()
	var vm := LuaVM.new(host, name)
	LuaStdlib.install(vm)
	return [vm, host]


func _run_source(source: String, name := "TestScript") -> Array:
	var pair := _new_vm(name)
	var vm: LuaVM = pair[0]
	var host: TestHost = pair[1]
	vm.start(source)
	for i in 5000:
		if _threads_done(vm):
			break
		vm.step(0.016, 1000000)
	if not host.errors.is_empty():
		print("  errori script %s: %s" % [name, host.errors])
	if vm.get_global("result") != null:
		print("  result %s = %s" % [name, LuaValues.to_text(vm.get_global("result"))])
	return [vm, host]


func _threads_done(vm: LuaVM) -> bool:
	for thread in vm.threads:
		if thread.status == "ready":
			return false
	return true


func _num(vm: LuaVM, name: String) -> float:
	return LuaValues.as_number(vm.get_global(name), -999999.0)


func _test_core_values() -> void:
	var result := _run_source("""
result = 2 + 3 * 4 - 10 / 2
text_result = "ab" .. 2 .. "cd"
bool_result = (1 < 2) and not false
len_result = #"hello"
unary_result = -2 ^ 2
mod_result = 7 % 4
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "nessun errore negli operatori di base")
	_check(_num(vm, "result") == 9.0, "precedenza aritmetica (9)")
	_check(str(vm.get_global("text_result")) == "ab2cd", "concatenazione")
	_check(vm.get_global("bool_result") == true, "operatori booleani")
	_check(_num(vm, "len_result") == 5.0, "lunghezza stringa")
	_check(_num(vm, "unary_result") == -4.0, "precedenza unaria e potenza")
	_check(_num(vm, "mod_result") == 3.0, "modulo")


func _test_control_flow() -> void:
	var result := _run_source("""
local total = 0
for i = 1, 10 do
  if i == 6 then break end
  total = total + i
end
local n = 0
while n < 5 do
  n = n + 1
end
local r = 0
repeat
  r = r + 1
until r >= 3
result = total + n * 10 + r * 100
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "nessun errore nei cicli")
	_check(_num(vm, "result") == 365.0, "for/while/repeat/break")


func _test_tables_and_closures() -> void:
	var result := _run_source("""
local t = {10, 20, 30, nome = "test"}
local sum = 0
for i, v in ipairs(t) do
  sum = sum + v
end
local keys = 0
for k, v in pairs(t) do
  keys = keys + 1
end
local function counter()
  local value = 0
  return function()
    value = value + 1
    return value
  end
end
local c = counter()
c()
c()
result = sum + keys * 1000 + c()
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "nessun errore in tabelle/closure")
	_check(_num(vm, "result") == 60.0 + 4000.0 + 3.0, "ipairs/pairs/upvalue")


func _test_multiple_returns() -> void:
	var result := _run_source("""
local function pair()
  return 4, 5
end
local a, b = pair()
local c = 0
local function pass(...)
  return ...
end
local x, y = pass(a, b)
result = a * 100 + b * 10 + c + x + y
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "nessun errore nei ritorni multipli")
	_check(_num(vm, "result") == 459.0, "ritorni multipli e vararg")


func _test_stdlib() -> void:
	var result := _run_source("""
local values = {3, 1, 2}
table.sort(values)
table.insert(values, 4)
local removed = table.remove(values, 1)
local formatted = string.format("%02d-%s", 7, "x")
local sub = string.sub("abcdef", 2, 4)
local upper = ("ciao"):upper()
result = values[1] * 100 + values[2] * 10 + values[3] + removed + #formatted + #sub
text_result = formatted .. sub .. upper
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "nessun errore nella stdlib")
	_check(_num(vm, "result") == 242.0, "table/string")
	_check(str(vm.get_global("text_result")) == "07-xbcdCIAO", "string.format/sub/upper")


func _test_errors_and_pcall() -> void:
	var result := _run_source("""
local ok, message = pcall(function()
  error("esplosione")
end)
result = ok and 1 or 0
text_result = message
local ok2 = pcall(function()
  return 10 / 2
end)
second = ok2 and 1 or 0
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "pcall cattura l'errore senza crash")
	_check(_num(vm, "result") == 0.0, "pcall ritorna false")
	_check(str(vm.get_global("text_result")).contains("esplosione"), "messaggio pcall")
	_check(_num(vm, "second") == 1.0, "pcall riuscito")

	var failing := _run_source("local x = nil\nx:metodo()", "ErroreScript")
	_check(not failing[1].errors.is_empty(), "errore runtime segnalato")
	_check(str(failing[1].errors[0]).begins_with("ErroreScript:2:"), "errore con nome e riga")


func _test_sandbox() -> void:
	var result := _run_source("""
result = (os == nil) and (io == nil) and (debug == nil) and (package == nil)
  and (require == nil) and (loadstring == nil) and (getfenv == nil) and (setfenv == nil)
""")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "sandbox senza errori")
	_check(vm.get_global("result") == true, "escape test: OS/io/debug/package/require/loadstring assenti")


func _test_limits() -> void:
	var result := _run_source("""
local function recurse(n)
  return recurse(n + 1)
end
recurse(1)
""", "Ricorsione")
	_check(not result[1].errors.is_empty(), "limite chiamate annidate")
	_check(str(result[1].errors[0]).contains("troppe chiamate"), "messaggio limite chiamate")

	var table_limit := _run_source("""
local t = {}
for i = 1, 10001 do
  t[i] = i
end
""", "TabellaGrande")
	_check(not table_limit[1].errors.is_empty(), "limite dimensione tabella")
	_check(str(table_limit[1].errors[0]).contains("tabella troppo grande"), "messaggio limite tabella")


func _test_level_format() -> void:
	var level := LevelData.new_level()
	_check(int(level["version"]) == 2, "nuovo livello versione 2")
	level["scripts"] = [{
		"id": "s1", "name": "Porta", "parent_id": level["parts"][0]["id"],
		"enabled": true, "source": "print('ciao')",
	}]
	_check(LevelData.validate(level).is_empty(), "livello v2 con script valido")
	var bad := level.duplicate(true)
	bad["scripts"][0]["parent_id"] = "p999"
	_check(not LevelData.validate(bad).is_empty(), "parent_id inesistente rifiutato")
	bad = level.duplicate(true)
	bad["scripts"].append(bad["scripts"][0].duplicate(true))
	_check(not LevelData.validate(bad).is_empty(), "id script duplicato rifiutato")
	var old := level.duplicate(true)
	old["version"] = 1
	_check(not LevelData.validate(old).is_empty(), "v1 con script rifiutato")


func _test_runtime_roblox_api() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var level := LevelData.new_level()
	var part_id := str(level["parts"][0]["id"])
	level["scripts"] = [{
		"id": "s1",
		"name": "ApiScript",
		"parent_id": part_id,
		"enabled": true,
		"source": """
local p = script.Parent
p.Size = Vector3.new(2, 2, 2)
p.Color = Color3.fromRGB(255, 0, 0)
local nuovo = Instance.new("Part")
nuovo.Name = "DaScript"
nuovo.Parent = workspace
print("api-ok", p.Name)
""",
	}]
	var mapping := LevelBuilder.build_into(world, level)
	var runtime := LuaRuntime.new()
	runtime.name = "TestLuaRuntime"
	var lines: Array = []
	runtime.output_line.connect(func(text: String, level_value: int) -> void:
		lines.append({"text": text, "level": level_value})
	)
	root.add_child(runtime)
	runtime.start(level, world, mapping)
	for i in 20:
		await process_frame
	_check(runtime.active_script_count() == 1, "runtime avvia lo script")
	var part: Node3D = mapping.get(part_id)
	var mesh := part.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh != null and (mesh.mesh as BoxMesh).size.is_equal_approx(Vector3(2, 2, 2)),
		"script modifica Size")
	_check(mesh != null and (mesh.material_override as StandardMaterial3D).albedo_color.r > 0.9,
		"script modifica Color")
	_check(world.find_child("DaScript", true, false) != null, "Instance.new + Parent")
	var printed := false
	for line in lines:
		if str(line["text"]).contains("api-ok"):
			printed = true
	_check(printed, "print finisce nell'output del runtime")
	_check(part.find_child("LuaTouchedSensor", true, false) == null, "nessun sensore senza Touched")
	runtime.stop()
	runtime.queue_free()
	world.queue_free()
	await process_frame


func _test_touched_signal() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var level := LevelData.new_level()
	var part_id := str(level["parts"][0]["id"])
	level["scripts"] = [{
		"id": "s1",
		"name": "TouchScript",
		"parent_id": part_id,
		"enabled": true,
		"source": """
local p = script.Parent
p.Touched:Connect(function(hit)
  p.Color = Color3.fromRGB(0, 255, 0)
  print("toccato", hit.Name)
end)
""",
	}]
	var mapping := LevelBuilder.build_into(world, level)
	var runtime := LuaRuntime.new()
	var lines: Array = []
	runtime.output_line.connect(func(text: String, _level: int) -> void: lines.append(text))
	root.add_child(runtime)
	runtime.start(level, world, mapping)
	for i in 5:
		await process_frame
	var part: Node3D = mapping.get(part_id)
	_check(part.find_child("LuaTouchedSensor", true, false) != null, "Touched crea il sensore")
	var body := CharacterBody3D.new()
	body.name = "TestPlayer"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	body.add_child(shape)
	world.add_child(body)
	body.global_position = part.global_position
	for i in 30:
		await physics_frame
		await process_frame
		var mesh := part.get_node_or_null("Mesh") as MeshInstance3D
		if mesh and (mesh.material_override as StandardMaterial3D).albedo_color.g > 0.9:
			break
	var mesh := part.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh != null and (mesh.material_override as StandardMaterial3D).albedo_color.g > 0.9,
		"Touched esegue il callback e modifica il colore")
	var touched := false
	for line in lines:
		if str(line).contains("toccato"):
			touched = true
	_check(touched, "Touched riceve il nome del corpo")
	body.queue_free()
	runtime.stop()
	runtime.queue_free()
	world.queue_free()
	await process_frame


func _test_demo_level() -> void:
	var path := "res://levels/scripts_demo.rwl.json"
	_check(FileAccess.file_exists(path), "livello demo script presente")
	var level := LevelIO.load_from_path(path)
	_check(not level.is_empty(), "livello demo leggibile")
	var errors := LevelData.validate(level)
	_check(errors.is_empty(), "livello demo valido")
	for message in errors:
		print("  - ", message)
	var world := Node3D.new()
	root.add_child(world)
	var mapping := LevelBuilder.build_into(world, level)
	var runtime := LuaRuntime.new()
	var runtime_errors: Array = []
	runtime.script_error.connect(func(text: String) -> void: runtime_errors.append(text))
	root.add_child(runtime)
	runtime.start(level, world, mapping)
	for i in 5:
		await process_frame
	_check(runtime.active_script_count() == 4, "demo: quattro script attivi")
	_check(runtime_errors.is_empty(), "demo: nessun errore di script")
	var rotating: Node3D = mapping.get("p4")
	var before := rotating.rotation_degrees.y
	await create_timer(0.2).timeout
	for i in 3:
		await process_frame
	_check(not is_equal_approx(rotating.rotation_degrees.y, before), "demo: piattaforma rotante")
	var portal: Node3D = mapping.get("p3")
	_check(portal.find_child("LuaTouchedSensor", true, false) != null, "demo: sensore della porta")
	runtime.stop()
	runtime.queue_free()
	world.queue_free()
	await process_frame


func _test_main_scene_with_scripts() -> void:
	var level := LevelIO.load_from_path("res://levels/scripts_demo.rwl.json")
	LevelData.play_request = level
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 5:
		await process_frame
	_check(main._lua_runtime != null, "main crea il runtime Lua")
	_check(main._lua_runtime.active_script_count() == 4, "main avvia tutti gli script")
	var rotating: Node3D = main.world.find_child("PiattaformaRotante", true, false)
	_check(rotating != null, "main costruisce la piattaforma demo")
	var before := rotating.rotation_degrees.y if rotating else 0.0
	await create_timer(0.2).timeout
	for i in 3:
		await process_frame
	_check(rotating != null and not is_equal_approx(rotating.rotation_degrees.y, before),
		"main esegue gli script del livello")
	LevelData.play_request = {}
	main.get_node("NetClient").stop()
	main.queue_free()
	await process_frame


func _test_scheduler() -> void:
	var result := _run_source("""
spawned = 0
task.spawn(function()
  task.wait(0.01)
  spawned = 1
end)
task.delay(0.01, function()
  spawned = spawned + 1
end)
result = 1
""", "Scheduler")
	var vm: LuaVM = result[0]
	var host: TestHost = result[1]
	_check(host.errors.is_empty(), "scheduler senza errori")
	_check(_num(vm, "result") == 1.0, "script principale completa")
	_check(_num(vm, "spawned") == 0.0, "task.spawn/delay partono sospesi")
	for i in 200:
		await create_timer(0.005).timeout
		vm.step(0.01, 1000000)
		if _num(vm, "spawned") >= 2.0:
			break
	_check(_num(vm, "spawned") == 2.0, "task.spawn e task.delay riprendono")
