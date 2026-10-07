extends SceneTree
## Setup una tantum del progetto: input map in stile Roblox e gravità in stud/s².
## Uso: flatpak run org.godotengine.Godot --headless --path <progetto> --script res://tools/setup_project_settings.gd

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"toggle_shift_lock": [KEY_SHIFT],
}


func _init() -> void:
	for action in ACTIONS:
		_set_action(action, ACTIONS[action])
	ProjectSettings.set_setting("physics/3d/default_gravity", 196.2)
	ProjectSettings.set_setting("net/server_url", "ws://127.0.0.1:9080")
	var err := ProjectSettings.save()
	print("PROJECT_SETTINGS_SAVED err=%d" % err)
	quit()


func _set_action(action: String, keys: Array) -> void:
	var events: Array = []
	for key in keys:
		var key_event := InputEventKey.new()
		key_event.device = -1  # DEVICE_ID_EMULATION: matcha qualsiasi device in ingresso
		key_event.physical_keycode = key
		events.append(key_event)
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": 0.2,
		"events": events,
	})
