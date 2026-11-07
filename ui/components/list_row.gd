class_name ListRow
extends PanelContainer
## Tappable list row: [leading tile] title / subtitle ........ trailing / trailing_sub
## Works inside ScrollContainers (mouse_filter PASS) — a drag scrolls, a tap selects.

signal tapped

const TAP_SLOP := 10.0

var title_label: Label
var subtitle_label: Label
var trailing_label: Label
var trailing_sub_label: Label
var leading: Control
var selected := false:
	set(v):
		selected = v
		theme_type_variation = &"ListRowSelected" if v else &"ListRow"

var _press_pos := Vector2.ZERO
var _pressing := false
var _tween: Tween


func _init() -> void:
	theme_type_variation = &"ListRow"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", DS.S3)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	leading = Control.new()
	leading.visible = false
	leading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(leading)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mid)
	title_label = _label(&"Headline", mid)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	subtitle_label = _label(&"Footnote", mid)
	subtitle_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 1)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(right)
	trailing_label = _label(&"StatSmall", right)
	trailing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trailing_sub_label = _label(&"Caption", right)
	trailing_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func setup(title: String, subtitle: String = "", trailing: String = "", trailing_sub: String = "") -> ListRow:
	title_label.text = title
	subtitle_label.text = subtitle
	subtitle_label.visible = subtitle != ""
	trailing_label.text = trailing
	trailing_label.visible = trailing != ""
	trailing_sub_label.text = trailing_sub
	trailing_sub_label.visible = trailing_sub != ""
	return self


## Replace the leading slot with a custom control (icon tile, colour dot …).
func set_leading(c: Control) -> void:
	var parent := leading.get_parent()
	var idx := leading.get_index()
	leading.queue_free()
	leading = c
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	parent.move_child(c, idx)


func _label(variant: StringName, parent: Node) -> Label:
	var l := Label.new()
	l.theme_type_variation = variant
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_pos = event.global_position
			_scale_to(0.98)
		elif _pressing:
			_pressing = false
			_scale_to(1.0)
			if event.global_position.distance_to(_press_pos) < TAP_SLOP:
				Haptics.tap()
				tapped.emit()
	elif event is InputEventMouseMotion and _pressing:
		if event.global_position.distance_to(_press_pos) >= TAP_SLOP:
			_pressing = false
			_scale_to(1.0)


func _scale_to(s: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	DS.ease_out(_tween)
	_tween.tween_property(self, "scale", Vector2.ONE * s, 0.18)


## Small rounded tile with a Lucide icon, used as a leading element.
static func icon_tile(icon_name: String, tint: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"IconTile"
	p.custom_minimum_size = Vector2(36, 36)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.self_modulate = tint
	var t := TextureRect.new()
	t.texture = DS.icon(icon_name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(20, 20)
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(t)
	return p
