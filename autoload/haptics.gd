extends Node
## Light vibration feedback (Android). No-op on desktop or when disabled in Settings.

var _enabled_platform := OS.has_feature("mobile")


func tap() -> void:
	_buzz(10, 0.35)


func select() -> void:
	_buzz(16, 0.5)


func success() -> void:
	_buzz(22, 0.7)


func warning() -> void:
	_buzz(40, 1.0)


func _buzz(ms: int, amplitude: float) -> void:
	if _enabled_platform and Settings.haptics:
		Input.vibrate_handheld(ms, amplitude)
