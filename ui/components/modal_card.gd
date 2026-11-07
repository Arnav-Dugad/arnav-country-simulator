class_name ModalCard
extends Control
## Centered glass card over a dimmed backdrop, with spring pop-in. Fill `content`.

signal closed

var card: GlassPanel
var content: VBoxContainer
var _dim: ColorRect


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.01, 0.03, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	card = GlassPanel.new()
	card.theme_type_variation = &"GlassSheet"
	card.tint = DS.GLASS_TINT_STRONG
	add_child(card)
	content = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(content)


func _ready() -> void:
	resized.connect(_layout)
	_layout.call_deferred()
	_pop_in.call_deferred()


func _layout() -> void:
	var w := minf(size.x - DS.S4 * 2.0, 420.0)
	card.size = Vector2(w, 0)
	card.size = Vector2(w, card.get_combined_minimum_size().y)
	card.position = Vector2((size.x - w) * 0.5,
		clampf((size.y - card.size.y) * 0.5, Screen.top + DS.S4, size.y - card.size.y - Screen.bottom - DS.S4))
	card.pivot_offset = card.size * 0.5


func _enter_tree() -> void:
	Audio.duck(true)


func _exit_tree() -> void:
	Audio.duck(false)


func _pop_in() -> void:
	await get_tree().process_frame
	_layout()
	_dim.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * 0.92
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(_dim, "modulate:a", 1.0, Settings.dur(DS.DUR))
	t.tween_property(card, "modulate:a", 1.0, Settings.dur(DS.DUR_FAST))
	DS.spring(t)
	t.tween_property(card, "scale", Vector2.ONE, Settings.dur(DS.DUR_SLOW))


func dismiss() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(_dim, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.tween_property(card, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	t.tween_property(card, "scale", Vector2.ONE * 0.95, Settings.dur(DS.DUR_FAST))
	await t.finished
	closed.emit()
	queue_free()


## Header block: icon tile + overline + title.
func header(icon_name: String, tint: Color, overline: String, title: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	content.add_child(row)
	var tile := ListRow.icon_tile(icon_name, tint)
	tile.custom_minimum_size = Vector2(44, 44)
	row.add_child(tile)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var o := Label.new()
	o.theme_type_variation = &"Overline"
	o.text = overline.to_upper()
	v.add_child(o)
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = title
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(240, 0)
	v.add_child(t)


func body(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"BodySecondary"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
	return l


## A choice button with a caption underneath describing the tradeoff.
func choice(label: String, detail: String, variant: StringName, cb: Callable) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	content.add_child(box)
	var b := AppButton.make(label, variant)
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	box.add_child(b)
	if detail != "":
		var d := Label.new()
		d.theme_type_variation = &"Caption"
		d.text = detail
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(d)
