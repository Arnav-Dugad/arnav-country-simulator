extends Node
## Light vibration feedback (Android). No-op on desktop or when disabled in Settings.

var _enabled_platform := OS.has_feature("mobile")


## Each cue pairs a vibration with its sound (pass sound=false to vibrate only).
func tap(sound: bool = true) -> void:
	_buzz(10, 0.35)
	if sound:
		Audio.play("tap")


func tick() -> void:
	_buzz(6, 0.25)
	Audio.play("tick", -4.0)


func select(sound: bool = true) -> void:
	_buzz(16, 0.5)
	if sound:
		Audio.play("select")


func success(sound: bool = true) -> void:
	_buzz(22, 0.7)
	if sound:
		Audio.play("success")


func warning(sound: bool = true) -> void:
	_buzz(40, 1.0)
	if sound:
		Audio.play("warning")


## Fast slider drags and counting animations would otherwise buzz non-stop:
## light cues closer together than MIN_GAP are dropped (stronger ones always play).
const MIN_GAP_MS := 40
var _last_ms := -1000


func _buzz(ms: int, amplitude: float) -> void:
	if not (_enabled_platform and Settings.haptics):
		return
	var now := Time.get_ticks_msec()
	if amplitude < 0.5 and now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	Input.vibrate_handheld(ms, amplitude)
