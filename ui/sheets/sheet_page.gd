class_name SheetPage
extends VBoxContainer
## Base for bottom-sheet pages. Subclasses build UI in _build() and update it in
## refresh() (called when opened and every simulated month while visible).

var title := ""
## Snap stop the sheet opens at for this page.
var open_at := BottomSheet.Snap.HALF


func _init() -> void:
	add_theme_constant_override(&"separation", DS.S4)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build()


func _build() -> void:
	pass


func refresh() -> void:
	pass


## Called when the page becomes visible.
func on_open() -> void:
	refresh()


# ---------------------------------------------------------------- helpers ---
## Grouped card with an overline header. Returns the inner VBox to fill.
var _sections := {}      # header -> wrapper (for "Find anything" and the jump bar)


## Long pages fold their sections: only the title shows until tapped. Headers in
## `open_sections` start open; the player's choices are remembered.
var collapsible := false
var open_sections: Array = []
## Tests: show every section's content.
static var unfold_all := false


func _fold_key(header: String) -> String:
	return "%s/%s" % [title, header]


func is_open(header: String) -> bool:
	if unfold_all:
		return true
	var saved: Dictionary = Settings.get_value("sections_open", {})
	var k := _fold_key(header)
	return bool(saved[k]) if saved.has(k) else header in open_sections


func set_open(header: String, on: bool) -> void:
	var saved: Dictionary = (Settings.get_value("sections_open", {}) as Dictionary).duplicate()
	saved[_fold_key(header)] = on
	Settings.set_value("sections_open", saved)
	var wrap: Control = _sections.get(header)
	if wrap != null and is_instance_valid(wrap) and wrap.get_child_count() >= 2:
		var card := wrap.get_child(wrap.get_child_count() - 1) as Control
		card.visible = on
		var chev := wrap.get_child(0).get_child(1) as TextureRect if wrap.get_child(0).get_child_count() > 1 else null
		if chev:
			chev.texture = DS.icon("chevron-down" if on else "chevron-right")


func section(header: String, parent: Control = self) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override(&"separation", DS.S2)
	parent.add_child(wrap)
	if header != "":
		_sections[header] = wrap
	var folds := collapsible and header != ""
	if folds:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S2)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.custom_minimum_size = Vector2(0, 34)
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = header.to_upper()
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var chev := TextureRect.new()
		chev.texture = DS.icon("chevron-down" if is_open(header) else "chevron-right")
		chev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		chev.custom_minimum_size = Vector2(16, 16)
		chev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chev.modulate = DS.TEXT_3
		chev.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chev)
		var st := {"p": Vector2.ZERO, "down": false}
		var hh := header
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					st.p = e.global_position
					st.down = true
				elif st.down:
					st.down = false
					if e.global_position.distance_to(st.p) < 10.0:
						Haptics.tap()
						set_open(hh, not is_open(hh))
			elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.p) >= 10.0:
				st.down = false)
		wrap.add_child(row)
	elif header != "":
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = header.to_upper()
		wrap.add_child(h)
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	if folds:
		card.visible = is_open(header)
	wrap.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(inner)
	return inner


func grid(parent: Control, columns: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	parent.add_child(g)
	return g


## At a glance: a grid of small tiles [icon, colour, head, value, section]; tapping one scrolls to its section.
func glance(items: Array, parent: Control = self) -> GridContainer:
	var g := grid(parent, 3 if Settings.text_scale < 1.0 and items.size() % 3 == 0 else 2)
	for t in items:
		var p := PanelContainer.new()
		p.theme_type_variation = &"TilePanel"
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override(&"separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		var ic := TextureRect.new()
		ic.texture = DS.icon(str(t[0]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(16, 16)
		ic.modulate = t[1]
		h.add_child(ic)
		var hl := Label.new()
		hl.theme_type_variation = &"Caption"
		hl.text = str(t[2]).to_upper()
		hl.clip_text = true
		hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.custom_minimum_size = Vector2(20, 0)
		h.add_child(hl)
		var vl := Label.new()
		vl.theme_type_variation = &"StatValue"
		vl.text = str(t[3])
		vl.clip_text = true
		vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vl.custom_minimum_size = Vector2(20, 0)
		v.add_child(vl)
		var sec := str(t[4])
		var stt := {"p": Vector2.ZERO, "down": false}
		p.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed:
					stt.p = e.global_position
					stt.down = true
				elif stt.down:
					stt.down = false
					if e.global_position.distance_to(stt.p) < 10.0:
						Haptics.tap()
						scroll_to_section(sec)
			elif e is InputEventMouseMotion and stt.down and e.global_position.distance_to(stt.p) >= 10.0:
				stt.down = false)
		g.add_child(p)
	return g


## Thin progress meter: solid fill to a, lighter "pending" fill to b.
func meter(a: float, b: float, color: Color, h: float = 6.0) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, w, h))
		var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		if b > a:
			f.bg_color = Color(color, 0.35)
			bar.draw_style_box(f, Rect2(0, 0, maxf(w * clampf(b, 0.0, 1.0), h), h))
		f.bg_color = color
		if a > 0.0:
			bar.draw_style_box(f, Rect2(0, 0, maxf(w * clampf(a, 0.0, 1.0), h), h)))
	return bar


## Photo with a title and caption over its lower edge.
func photo_header(scene: String, title_text: String, sub: String, h: float) -> Control:
	var ph := Photo.scene(scene, h, true)
	ph.set(&"fade_bottom", 0.55)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = DS.S4
	v.offset_right = -DS.S4
	v.offset_bottom = -DS.S3
	var t := Label.new()
	t.theme_type_variation = &"PhotoTitle"
	t.text = title_text
	v.add_child(t)
	if sub != "":
		var s := Label.new()
		s.theme_type_variation = &"PhotoCaption"
		s.text = sub
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(40, 0)
		v.add_child(s)
	return ph


## A grid of picture tiles that open deeper pages: [[scene, icon, colour, title, caption, callback], …].
func hub(items: Array, parent: Control = self, header: String = "") -> GridContainer:
	if header != "":
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = header.to_upper()
		parent.add_child(h)
	var g := grid(parent, 2)
	for it in items:
		g.add_child(_hub_tile(it))
	return g


func _hub_tile(it: Array) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var ph := Photo.scene(str(it[0]), 70.0, false)
	ph.set(&"radius", 12.0)
	v.add_child(ph)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = DS.icon(str(it[1]))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(16, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = it[2]
	top.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Subhead"
	t.add_theme_color_override(&"font_color", DS.TEXT)
	t.text = str(it[3])
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(30, 0)
	top.add_child(t)
	var c := Label.new()
	c.theme_type_variation = &"Caption"
	c.text = str(it[4])
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(30, 0)
	v.add_child(c)
	var cb: Callable = it[5]
	var st := {"p": Vector2.ZERO, "down": false}
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.p = e.global_position
				st.down = true
				p.pivot_offset = p.size * 0.5
				p.create_tween().tween_property(p, "scale", Vector2.ONE * 0.97, 0.08)
			elif st.down:
				st.down = false
				p.create_tween().tween_property(p, "scale", Vector2.ONE, Settings.dur(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				if e.global_position.distance_to(st.p) < 10.0:
					Haptics.tap()
					cb.call()
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.p) >= 10.0:
			st.down = false
			p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.12))
	return p


## Scroll the sheet so the named section is at the top (with a soft highlight).
func scroll_to_section(header: String) -> void:
	var wrap: Control = _sections.get(header)
	var gs := get_tree().current_scene
	if wrap == null or not is_instance_valid(wrap) or gs == null or not ("_scroll" in gs):
		return
	if collapsible and not is_open(header):
		set_open(header, true)
		await get_tree().process_frame
	if not wrap.is_visible_in_tree():
		return
	var sc: ScrollContainer = gs._scroll
	var y := wrap.global_position.y - sc.global_position.y + sc.scroll_vertical - 12.0
	var tw := sc.create_tween()
	DS.ease_out(tw)
	tw.tween_property(sc, "scroll_vertical", int(y), Settings.dur(0.45))
	var flash := wrap.create_tween()
	flash.tween_property(wrap, "modulate", Color(1.25, 1.25, 1.35), Settings.dur(0.2)).set_delay(Settings.dur(0.4))
	flash.tween_property(wrap, "modulate", Color.WHITE, Settings.dur(0.5))


## A row of chips at the top of a long page that jump to its sections.
func jump_bar(headers: Array) -> Control:
	var sc := TouchScroll.make_horizontal()
	sc.custom_minimum_size = Vector2(0, 40)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	sc.add_child(row)
	for h in headers:
		var hh := str(h)
		var b := AppButton.make(hh, &"Chip")
		b.pressed.connect(func() -> void:
			Haptics.select()
			scroll_to_section(hh))
		row.add_child(b)
	return sc


func note(text: String, parent: Control = self) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Footnote"
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## Value one year ago from the player's history (NAN if not available).
static func year_ago(key: String) -> float:
	var h: PackedFloat32Array = Game.history.get(key, PackedFloat32Array())
	return h[h.size() - 13] if h.size() > 12 else NAN


static func fmt_pct(v: float) -> String:
	return String.num(v, 1) + "%"


static func fmt_pts(d: float) -> String:
	return String.num(absf(d), 1) + " pts"
