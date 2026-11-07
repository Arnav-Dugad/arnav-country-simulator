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
	# Short screens (landscape): shrink the card to fit rather than overflow.
	var avail := size.y - Screen.top - Screen.bottom - DS.S4 * 2.0
	var s := clampf(avail / maxf(card.size.y, 1.0), 0.62, 1.0)
	card.position = Vector2((size.x - w) * 0.5,
		clampf((size.y - card.size.y) * 0.5, Screen.top + DS.S4, maxf(size.y - card.size.y - Screen.bottom - DS.S4, Screen.top)))
	card.pivot_offset = card.size * 0.5
	if s < 1.0:
		card.position.y = (size.y - card.size.y) * 0.5
	set_meta(&"fit", s)


func _enter_tree() -> void:
	Audio.duck(true)


func _exit_tree() -> void:
	Audio.duck(false)


func _pop_in() -> void:
	await get_tree().process_frame
	_layout()
	_dim.modulate.a = 0.0
	card.modulate.a = 0.0
	card.scale = Vector2.ONE * 0.92 * float(get_meta(&"fit", 1.0))
	var t := create_tween().set_parallel(true)
	DS.ease_out(t)
	t.tween_property(_dim, "modulate:a", 1.0, Settings.dur(DS.DUR))
	t.tween_property(card, "modulate:a", 1.0, Settings.dur(DS.DUR_FAST))
	DS.spring(t)
	t.tween_property(card, "scale", Vector2.ONE * float(get_meta(&"fit", 1.0)), Settings.dur(DS.DUR_SLOW))


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
func choice(label: String, detail: String, variant: StringName, cb: Callable, chips: Array = []) -> Control:
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
	if not chips.is_empty():
		var flow := HFlowContainer.new()
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override(&"h_separation", 5)
		flow.add_theme_constant_override(&"v_separation", 5)
		box.add_child(flow)
		for ch in chips:
			var p := PanelContainer.new()
			p.theme_type_variation = &"ForecastChip"
			var l := Label.new()
			l.theme_type_variation = &"ChipValue"
			l.add_theme_font_size_override(&"font_size", 12)
			l.add_theme_color_override(&"font_color", DS.GREEN if ch[1] else DS.RED)
			l.text = str(ch[0])
			p.add_child(l)
			flow.add_child(p)
	return box


## A soft diagonal band of light sweeping across the card (election win…).
func sweep(color: Color, duration: float = 1.1) -> void:
	if Settings.reduce_motion:
		return
	var o := Control.new()
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.clip_contents = true
	o.position = card.position
	o.size = card.size
	add_child(o)
	var st := {"x": -0.4}
	o.draw.connect(func() -> void:
		var w := o.size.x
		var h := o.size.y
		var cx: float = st.x * (w + h)
		var band := 70.0
		for k in 6:
			var f := float(k) / 6.0
			var a := color
			a.a = color.a * (1.0 - absf(f - 0.5) * 2.0)
			var x0 := cx + f * band
			o.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + band / 6.0, 0),
				Vector2(x0 + band / 6.0 - h * 0.6, h), Vector2(x0 - h * 0.6, h)]), a))
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		st.x = v
		o.queue_redraw(), -0.4, 1.3, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(o.queue_free)


## Darken the backdrop further (0.55 default) for cinematic moments.
func set_dim(alpha: float) -> void:
	var t := create_tween()
	DS.ease_out(t)
	t.tween_property(_dim, "color:a", alpha, Settings.dur(0.8))
