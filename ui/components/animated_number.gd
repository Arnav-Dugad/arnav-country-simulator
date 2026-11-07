class_name AnimatedNumber
extends Label
## Label that counts smoothly to new values. `formatter` turns a float into text.

var formatter: Callable = func(v: float) -> String: return String.num(v, 1)
var duration := 0.6
var value := 0.0:
	set(v):
		if is_equal_approx(v, value) and _initialised:
			return
		value = v
		_animate_to(v)

var _shown := 0.0
var _tween: Tween
var _initialised := false


func _init() -> void:
	theme_type_variation = &"StatValue"


func set_instant(v: float) -> void:
	value = v
	if _tween:
		_tween.kill()
	_set_shown(v)


func _animate_to(v: float) -> void:
	if not _initialised or not is_inside_tree():
		_initialised = true
		_set_shown(v)
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	DS.ease_out(_tween)
	_tween.tween_method(_set_shown, _shown, v, Settings.dur(duration))


func _set_shown(v: float) -> void:
	_shown = v
	text = formatter.call(v)
