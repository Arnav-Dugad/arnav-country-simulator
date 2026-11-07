class_name StatTile
extends PanelContainer
## Compact stat: caption, animated value, and a coloured change indicator.

signal tapped

var caption: Label
var number: AnimatedNumber
var delta_label: Label
## true = higher is good (green when rising); false = higher is bad.
var higher_is_good := true
var _info: TextureRect
var _press := Vector2.ZERO
var _pressing := false


func setup(title: String, fmt: Callable, good_up: bool = true) -> StatTile:
	theme_type_variation = &"TilePanel"
	higher_is_good = good_up
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	caption = Label.new()
	caption.theme_type_variation = &"Overline"
	caption.text = title.to_upper()
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.custom_minimum_size = Vector2(20, 0)
	head.add_child(caption)
	_info = TextureRect.new()
	_info.texture = DS.icon("info")
	_info.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_info.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info.custom_minimum_size = Vector2(14, 14)
	_info.modulate = DS.TEXT_3
	_info.visible = false
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_info)
	number = AnimatedNumber.new()
	number.formatter = fmt
	number.clip_text = true
	number.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	number.custom_minimum_size = Vector2(20, 0)
	v.add_child(number)
	delta_label = Label.new()
	delta_label.theme_type_variation = &"Caption"
	delta_label.clip_text = true
	delta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delta_label.custom_minimum_size = Vector2(20, 0)
	v.add_child(delta_label)
	return self


## Updates the value and shows the change vs `previous` (e.g. a year ago).
func show_value(v: float, previous: float = NAN, delta_fmt: Callable = Callable()) -> void:
	number.value = v
	if is_nan(previous):
		delta_label.text = " "
		return
	var d := v - previous
	var good := (d >= 0.0) == higher_is_good
	var txt: String = delta_fmt.call(d) if delta_fmt.is_valid() else ("%+.1f" % d)
	# Anything that rounds to zero at one decimal reads as "No change".
	var flat := absf(d) < 0.05 or txt.begins_with("0.0 ") or txt == "$0.0" or txt == "0.0"
	delta_label.text = "No change in a year" if flat else (("↑ " if d >= 0.0 else "↓ ") + txt + " in a year")
	delta_label.add_theme_color_override(&"font_color", DS.TEXT_3 if flat else (DS.GREEN if good else DS.RED))


## Makes the tile tappable (shows a small info mark). Emits `tapped`.
func make_tappable() -> StatTile:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_info.visible = true
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	return self


func _gui_input(e: InputEvent) -> void:
	if not _info or not _info.visible:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = true
			_press = e.global_position
			create_tween().tween_property(self, "scale", Vector2.ONE * 0.97, 0.1)
		elif _pressing:
			_pressing = false
			DS.spring(create_tween()).tween_property(self, "scale", Vector2.ONE, 0.25)
			if e.global_position.distance_to(_press) < 10.0:
				Haptics.tap()
				tapped.emit()
	elif e is InputEventMouseMotion and _pressing and e.global_position.distance_to(_press) >= 10.0:
		_pressing = false
		DS.spring(create_tween()).tween_property(self, "scale", Vector2.ONE, 0.25)
