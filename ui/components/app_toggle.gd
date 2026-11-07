class_name AppToggle
extends HBoxContainer
## Settings row with an iOS-style animated switch. Styles: theme type "AppToggle".

signal toggled(on: bool)

var on := false
var _title: Label
var _switch: Control
var _t := 0.0
var _tween: Tween


func setup(title: String, value: bool, icon_name: String = "") -> AppToggle:
	on = value
	_t = 1.0 if value else 0.0
	add_theme_constant_override(&"separation", DS.S3)
	if icon_name != "":
		add_child(ListRow.icon_tile(icon_name, DS.ACCENT))
	_title = Label.new()
	_title.theme_type_variation = &"Body"
	_title.text = title
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_title)
	_switch = Control.new()
	_switch.custom_minimum_size = Vector2(51, 31)
	_switch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_switch.mouse_filter = Control.MOUSE_FILTER_STOP
	_switch.draw.connect(_draw_switch)
	_switch.gui_input.connect(_on_input)
	add_child(_switch)
	return self


func set_on(v: bool, emit: bool = true) -> void:
	if v == on:
		return
	on = v
	if _tween:
		_tween.kill()
	_tween = create_tween()
	DS.spring(_tween)
	_tween.tween_method(func(x: float) -> void:
		_t = x
		_switch.queue_redraw(), _t, 1.0 if v else 0.0, Settings.dur(DS.DUR))
	if emit:
		Haptics.select()
		toggled.emit(v)


func _draw_switch() -> void:
	var s := _switch.size
	var off_box := get_theme_stylebox(&"off", &"AppToggle")
	var on_box := get_theme_stylebox(&"on", &"AppToggle")
	var knob := get_theme_stylebox(&"knob", &"AppToggle")
	_switch.draw_style_box(off_box, Rect2(Vector2.ZERO, s))
	var on_color := (on_box as StyleBoxFlat).bg_color if on_box is StyleBoxFlat else DS.GREEN
	var fill := on_box.duplicate() as StyleBoxFlat
	if fill:
		fill.bg_color = Color(on_color, clampf(_t, 0.0, 1.0))
		_switch.draw_style_box(fill, Rect2(Vector2.ZERO, s))
	var d := s.y - 4.0
	var x := lerpf(2.0, s.x - d - 2.0, clampf(_t, -0.1, 1.1))
	_switch.draw_style_box(knob, Rect2(x, 2.0, d, d))


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		set_on(not on)
		_switch.accept_event()
