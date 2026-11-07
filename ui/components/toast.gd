class_name Toast
extends GlassPanel
## A calm headline banner: slides down under the top chrome, stays a few seconds,
## then fades away. Tap to dismiss early.

const HOLD := 3.6

var _label: Label
var _icon: Control


static func show_headline(parent: Control, text: String, icon_name: String, tint: Color, top: float) -> void:
	var t: GlassPanel = load("res://ui/components/toast.gd").new()
	parent.add_child(t)
	t.call(&"_present", text, icon_name, tint, top)


func _present(text: String, icon_name: String, icon_tint: Color, top: float) -> void:
	theme_type_variation = &"GlassPill"
	tint = DS.GLASS_TINT_STRONG
	mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = ListRow.icon_tile(icon_name, icon_tint)
	_icon.custom_minimum_size = Vector2(30, 30)
	row.add_child(_icon)
	_label = Label.new()
	_label.theme_type_variation = &"Headline"
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(10, 0)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	var parent_w := (get_parent() as Control).size.x
	var w := minf(parent_w - DS.S4 * 2.0, 380.0)
	size = Vector2(w, 0)
	await get_tree().process_frame
	size = Vector2(w, get_combined_minimum_size().y)
	position = Vector2((parent_w - w) * 0.5, top - 16.0)
	modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	DS.spring(t)
	t.tween_property(self, "position:y", top, Settings.dur(DS.DUR_SLOW))
	DS.ease_out(t)
	t.tween_property(self, "modulate:a", 1.0, Settings.dur(DS.DUR))
	get_tree().create_timer(HOLD).timeout.connect(_leave)
	gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and not e.pressed:
			_leave())


func _leave() -> void:
	if not is_inside_tree() or mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(self, "position:y", position.y - 12.0, Settings.dur(DS.DUR_FAST))
	t.tween_property(self, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.chain().tween_callback(queue_free)
