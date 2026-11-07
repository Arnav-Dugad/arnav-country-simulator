extends Node
## Persistent user preferences (user://settings.cfg).

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"

var haptics: bool = true
var reduce_motion: bool = false
var onboarding_done: bool = false
var last_update_check: int = 0
var skipped_version: String = ""

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		haptics = _cfg.get_value("prefs", "haptics", haptics)
		reduce_motion = _cfg.get_value("prefs", "reduce_motion", reduce_motion)
		onboarding_done = _cfg.get_value("prefs", "onboarding_done", onboarding_done)
		last_update_check = _cfg.get_value("prefs", "last_update_check", 0)
		skipped_version = _cfg.get_value("prefs", "skipped_version", "")


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_cfg.set_value("prefs", key, value)
	_cfg.save(PATH)
	changed.emit(key, value)


## Animation duration helper that honours "Reduce motion".
func dur(d: float) -> float:
	return 0.01 if reduce_motion else d
