class_name AppButton
extends Button
## Button with press-down scale (spring release) and a light haptic tick.
## Style comes from the theme via theme_type_variation (PrimaryButton, Chip, …).

@export var icon_name: String = "":
	set(v):
		icon_name = v
		icon = DS.icon(v) if v != "" else null
@export var haptic: bool = true

var _tween: Tween
var _press_pos := Vector2.ZERO
var _tracking := false


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	# PASS so a swipe starting on a button can still scroll its list; the press is
	# cancelled if the finger travels (see _gui_input).
	mouse_filter = Control.MOUSE_FILTER_PASS
	expand_icon = false


func _ready() -> void:
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_tracking = e.pressed
		_press_pos = e.global_position
	elif e is InputEventMouseMotion and _tracking:
		if e.global_position.distance_to(_press_pos) > 14.0:
			_cancel_press()


## Abort a press without firing `pressed` (the user was scrolling).
func _cancel_press() -> void:
	_tracking = false
	if disabled:
		return
	disabled = true
	_animate(1.0, DS.DUR_FAST, false)
	set_deferred(&"disabled", false)


func _on_down() -> void:
	_animate(DS.PRESS_SCALE, 0.12, false)


func _on_up() -> void:
	_animate(1.0, DS.DUR, true)


func _on_pressed() -> void:
	if haptic:
		Haptics.tap()


func _animate(to: float, dur: float, springy: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if springy:
		DS.spring(_tween)
	else:
		DS.ease_out(_tween)
	_tween.tween_property(self, "scale", Vector2.ONE * to, dur)


static func make(text_: String, variant: StringName = &"", icon_: String = "") -> AppButton:
	var b := AppButton.new()
	b.text = text_
	if variant != &"":
		b.theme_type_variation = variant
	if icon_ != "":
		b.icon_name = icon_
	return b
