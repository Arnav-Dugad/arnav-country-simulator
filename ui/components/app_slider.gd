class_name AppSlider
extends VBoxContainer
## iOS-style labelled slider: title + live value on top, rounded track with an
## accent fill and a soft-shadowed knob. Light haptic ticks as the value steps.
## Styles come from theme type "AppSlider" (track / fill / knob styleboxes).

signal value_changed(value: float)
signal drag_ended(value: float)

var title := ""
## Plain-language explanation shown from a small (i) next to the title.
var info_text := ""
var min_value := 0.0
var max_value := 100.0
var step := 0.5
var formatter: Callable = func(v: float) -> String: return String.num(v, 1) + "%"
## Optional marker (e.g. the starting value) drawn as a tick on the track.
var marker := NAN
var left_hint := ""
var right_hint := ""
var value := 0.0

var _title_label: Label
var _value_label: Label
var _track: Control
var _hints: HBoxContainer
var _dragging := false
var _knob_scale := 1.0
var _tween: Tween


func setup(title_: String, min_v: float, max_v: float, step_: float, v: float) -> AppSlider:
	title = title_
	min_value = min_v
	max_value = max_v
	step = step_
	value = v
	return self


func _ready() -> void:
	add_theme_constant_override(&"separation", 2)
	var head := HBoxContainer.new()
	add_child(head)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"Subhead"
	_title_label.text = title
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Titles shorten with "…" on narrow phones instead of widening the page.
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title_label.custom_minimum_size = Vector2(48, 0)
	head.add_child(_title_label)
	var info: Button = null
	if info_text != "":
		info = Button.new()
		info.theme_type_variation = &"InfoButton"
		info.icon = DS.icon("info")
		info.focus_mode = Control.FOCUS_NONE
		info.custom_minimum_size = Vector2(30, 24)
		info.pressed.connect(_show_info)
	_value_label = Label.new()
	_value_label.theme_type_variation = &"StatSmall"
	head.add_child(_value_label)
	if info:
		head.add_child(info)   # (i) at the far right; the title keeps the spare width
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 34)
	# PASS: touches also reach the parent ScrollContainer, so a vertical swipe that
	# starts on the slider still scrolls the page (see _on_input arbitration).
	_track.mouse_filter = Control.MOUSE_FILTER_PASS
	_track.draw.connect(_draw_track)
	_track.gui_input.connect(_on_input)
	add_child(_track)
	if left_hint != "" or right_hint != "":
		_hints = HBoxContainer.new()
		add_child(_hints)
		for t in [left_hint, right_hint]:
			var l := Label.new()
			l.theme_type_variation = &"Caption"
			l.text = t
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if t == left_hint else HORIZONTAL_ALIGNMENT_RIGHT
			_hints.add_child(l)
	set_value(value, false)


func set_value(v: float, emit: bool = true) -> void:
	var nv := clampf(snappedf(v, step), min_value, max_value)
	var changed := not is_equal_approx(nv, value)
	value = nv
	if _value_label:
		_value_label.text = formatter.call(value)
	if _track:
		_track.queue_redraw()
	if changed and emit:
		if absf(fmod(value, step * 4.0)) < step * 0.5:
			Haptics.tick()
		value_changed.emit(value)


func _ratio() -> float:
	return (value - min_value) / maxf(max_value - min_value, 0.0001)


func _draw_track() -> void:
	var w := _track.size.x
	var cy := _track.size.y * 0.5
	var knob_r := 13.0
	var x0 := knob_r
	var x1 := w - knob_r
	var track := get_theme_stylebox(&"track", &"AppSlider")
	var fill := get_theme_stylebox(&"fill", &"AppSlider")
	var knob := get_theme_stylebox(&"knob", &"AppSlider")
	_track.draw_style_box(track, Rect2(x0 - 3, cy - 3, x1 - x0 + 6, 6))
	var kx := lerpf(x0, x1, _ratio())
	_track.draw_style_box(fill, Rect2(x0 - 3, cy - 3, kx - x0 + 6, 6))
	if not is_nan(marker):
		var mx := lerpf(x0, x1, clampf((marker - min_value) / (max_value - min_value), 0.0, 1.0))
		_track.draw_rect(Rect2(mx - 1, cy - 7, 2, 14), Color(1, 1, 1, 0.35))
	var r := knob_r * _knob_scale
	_track.draw_style_box(knob, Rect2(kx - r, cy - r, r * 2.0, r * 2.0))


const SLOP := 8.0
var _press := Vector2.ZERO
var _pending := false   # finger down, direction not decided yet


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pending = true
			_press = e.position
		else:
			if _pending:            # a tap: jump to that spot
				_set_from_x(e.position.x)
				drag_ended.emit(value)
			elif _dragging:
				_animate_knob(1.0)
				drag_ended.emit(value)
				_track.accept_event()
			_pending = false
			_dragging = false
	elif e is InputEventMouseMotion:
		if _pending:
			var d: Vector2 = e.position - _press
			if absf(d.x) > SLOP and absf(d.x) > absf(d.y):
				_pending = false
				_dragging = true      # horizontal: this is a slider drag
				_animate_knob(1.18)
			elif absf(d.y) > SLOP:
				_pending = false      # vertical: leave it to the scroll view
		if _dragging:
			_set_from_x(e.position.x)
			_track.accept_event()


func _set_from_x(x: float) -> void:
	var knob_r := 13.0
	var t := clampf((x - knob_r) / maxf(_track.size.x - knob_r * 2.0, 1.0), 0.0, 1.0)
	set_value(lerpf(min_value, max_value, t))


func _animate_knob(s: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	DS.spring(_tween)
	_tween.tween_method(func(v: float) -> void:
		_knob_scale = v
		_track.queue_redraw(), _knob_scale, s, 0.22)


func _show_info() -> void:
	Haptics.tap()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("info", DS.ACCENT, "What it does", title)
	m.body(info_text)
	m.choice("Got it", "", &"PrimaryButton", m.dismiss)
