class_name StudioSession
extends RefCounted
## Stato condiviso tra la schermata iniziale di Studio e l'editor.
## Le variabili statiche sopravvivono al cambio di scena: la start screen prepara
## il livello (nuovo, da file o dal server) e l'editor lo consuma in `_ready()`.

static var pending_level: Dictionary = {}
static var pending_message := ""


## Vero nella build desktop "Studio" (custom feature del preset) oppure quando
## si avvia il progetto con `-- --studio` per provarla in sviluppo.
static func is_studio_build() -> bool:
	return OS.has_feature("studio") or OS.get_cmdline_user_args().has("--studio")


static func set_pending(level: Dictionary, message := "") -> void:
	pending_level = level.duplicate(true)
	pending_message = message


static func has_pending() -> bool:
	return not pending_level.is_empty()


## Restituisce il livello in attesa e svuota lo slot. Il messaggio resta
## disponibile con `take_message()` per la barra di stato dell'editor.
static func take_pending() -> Dictionary:
	var level := pending_level
	pending_level = {}
	return level


static func take_message() -> String:
	var message := pending_message
	pending_message = ""
	return message


static func clear_pending() -> void:
	pending_level = {}
	pending_message = ""
