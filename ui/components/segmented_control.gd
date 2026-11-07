class_name SegmentedControl
extends GlassPanel
## Glass segmented control. Segments are icon-only except the selected one,
## which expands to icon + label; a soft pill indicator glides between them.

signal changed(index: int)

var labels: PackedStringArray = []
var icons: PackedStringArray = []
var selected := 0
## When false, every segment shows its label (use for short label sets).
var compact := true
## Plain = no glass of its own (for use inside another glass surface).
var plain := false
## Minimum width of each segment.
var segment_width := 40.0
## Tight = smaller horizontal padding (SegmentTight theme variations).
var tight := false
## Fill = equal-width segments that share the available width (iOS style) and
## shrink with an ellipsis instead of overflowing (large text sizes).
var fill := false

var _stack: Control
var _indicator: Panel
var _row: HBoxContainer
var _buttons: Array[AppButton] = []
var _tween: Tween


func setup(labels_: PackedStringArray, icons_: PackedStringArray = [], selected_: int = 0) -> SegmentedControl:
	labels = labels_
	icons = icons_
	selected = selected_
	return self


func _ready() -> void:
	if fill:
		tight = true   # equal-width segments need the compact padding
	theme_type_variation = &"PanelContainer" if plain else &"GlassPill"
	super._ready()
	_glass.visible = not plain
	_stack = Control.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stack)
	_indicator = Panel.new()
	_indicator.theme_type_variation = &"SegmentIndicator"
	_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_child(_indicator)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override(&"separation", 2)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(_row)
	for i in labels.size():
		var b := AppButton.new()
		b.theme_type_variation = &"SegmentTight" if tight else &"Segment"
		if i < icons.size() and icons[i] != "":
			b.icon_name = icons[i]
		b.custom_minimum_size = Vector2(segment_width if not fill else 0.0, 36)
		if fill:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(_on_pressed.bind(i))
		b.tooltip_text = labels[i]
		_row.add_child(b)
		_buttons.append(b)
	_row.minimum_size_changed.connect(_sync_size)
	_row.sort_children.connect(_move_indicator.bind(true))
	_refresh(false)


func select(i: int, emit: bool = true) -> void:
	if i == selected:
		return
	selected = i
	_refresh(true)
	if emit:
		changed.emit(i)


func _on_pressed(i: int) -> void:
	Haptics.select()
	select(i)


func _refresh(animate: bool) -> void:
	for i in _buttons.size():
		var on := i == selected
		var base := "SegmentTight" if tight else "Segment"
		_buttons[i].theme_type_variation = StringName(base + ("Selected" if on else ""))
		var has_icon := i < icons.size() and icons[i] != ""
		_buttons[i].text = labels[i] if (on or not compact or not has_icon) else ""
	_sync_size()
	# Move after layout settles (labels may change width). Needed explicitly when
	# no re-sort happens (non-compact controls where every label stays visible).
	_move_indicator.call_deferred(animate)


func _sync_size() -> void:
	if _row:
		_stack.custom_minimum_size = _row.get_combined_minimum_size()
		if fill:
			_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _move_indicator(animate: bool) -> void:
	if _buttons.is_empty() or selected >= _buttons.size():
		return
	var b := _buttons[selected]
	var target := Rect2(b.position, b.size)
	if _tween:
		_tween.kill()
	if not animate or _indicator.size.x < 1.0:
		_indicator.position = target.position
		_indicator.size = target.size
		return
	_tween = create_tween().set_parallel(true)
	DS.ease_out(_tween)
	_tween.tween_property(_indicator, "position", target.position, Settings.dur(DS.DUR))
	_tween.tween_property(_indicator, "size", target.size, Settings.dur(DS.DUR))
