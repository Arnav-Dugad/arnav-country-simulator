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


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_icon = false


func _ready() -> void:
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


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
