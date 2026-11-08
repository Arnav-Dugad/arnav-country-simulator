class_name StorePage
extends SheetPage
## DEMO store. Real prices are shown, but nothing is ever charged.

var _list: VBoxContainer
var _toast: Label


func _init() -> void:
	super._init()
	title = "Store"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	var banner := PanelContainer.new()
	banner.theme_type_variation = &"DemoBanner"
	add_child(banner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	banner.add_child(row)
	row.add_child(ListRow.icon_tile("info", DS.ORANGE))
	var bl := Label.new()
	bl.theme_type_variation = &"Footnote"
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bl.text = "Demo store. Prices are examples; purchases are simulated and nothing is ever charged."
	row.add_child(bl)
	_toast = note("")
	_toast.visible = false
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S4)
	add_child(_list)
	var footer := VBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 0)
	add_child(footer)
	var restore := AppButton.make("Restore purchases", &"GhostButton", "refresh-cw")
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(func() -> void: _flash("Purchases restored.", true))
	footer.add_child(restore)
	var reset := AppButton.make("Reset demo", &"GhostButton", "rotate-ccw")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		Store.reset_demo()
		_flash("Demo purchases cleared.", false))
	footer.add_child(reset)
	note("Every item is optional and priced in real money. No ads, no loot boxes, " +
		"no paid boosts, and nothing that changes the simulation's fairness.")
	Store.changed.connect(refresh)


func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	_list.add_child(_hero(Store.item("complete")))
	_carousel_section("Map themes", "Give the world map a new look.", "Map themes")
	_section_cards("Expansions")
	_pass_section()
	_tips_section()


## The featured bundle: a full-width painting with the offer over it.
func _hero(it: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(v)
	if Photo.has_scene("store"):
		v.add_child(Photo.scene("store", 150.0))
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", DS.S2)
	v.add_child(head)
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = str(it.title)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(40, 0)
	head.add_child(t)
	if it.has("badge"):
		var b := Label.new()
		b.theme_type_variation = &"BadgeLabel"
		b.text = str(it.badge)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(b)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(60, 0)
	d.text = str(it.desc)
	v.add_child(d)
	var inc := HFlowContainer.new()
	inc.add_theme_constant_override(&"h_separation", 6)
	inc.add_theme_constant_override(&"v_separation", 6)
	v.add_child(inc)
	for x in it.get("includes", []):
		inc.add_child(_pill(str(x), DS.GOLD))
	v.add_child(_action_button(it))
	return card


## Map themes as swipeable cards, each with a live palette preview.
func _carousel_section(section_name: String, blurb: String, catalog_section: String) -> void:
	var head := Label.new()
	head.theme_type_variation = &"Overline"
	head.text = section_name.to_upper()
	_list.add_child(head)
	var sub := Label.new()
	sub.theme_type_variation = &"Caption"
	sub.text = blurb
	_list.add_child(sub)
	var sc := TouchScroll.make_horizontal()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.custom_minimum_size = Vector2(0, 236)
	_list.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	sc.add_child(row)
	for it in Store.CATALOG:
		if it.section != catalog_section:
			continue
		var card := PanelContainer.new()
		card.theme_type_variation = &"GroupPanel"
		card.custom_minimum_size = Vector2(176, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", DS.S2)
		card.add_child(v)
		v.add_child(_palette(it))
		var t := Label.new()
		t.theme_type_variation = &"Headline"
		t.text = str(it.title)
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size = Vector2(40, 0)
		v.add_child(t)
		var d := Label.new()
		d.theme_type_variation = &"Caption"
		d.text = str(it.desc)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(40, 34)
		v.add_child(d)
		v.add_child(_action_button(it))
		row.add_child(card)


## A tiny abstract "map" in the theme's palette (bundles show all four).
func _palette(it: Dictionary) -> Control:
	var cols: Array = []
	if it.has("theme"):
		cols = MapModes.THEMES.get(str(it.theme), MapModes.POLITICAL)
	else:
		for k in ["gold", "aurora", "graphite", "ember"]:
			cols.append((MapModes.THEMES[k] as Array)[0])
			cols.append((MapModes.THEMES[k] as Array)[3])
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 72)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, c.size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("0b1a2e")
		sb.set_corner_radius_all(DS.R_CARD / 2)
		c.draw_style_box(sb, r)
		# Blobby "countries": overlapping rounded shapes in the palette.
		var spots := [Vector2(0.18, 0.4), Vector2(0.36, 0.62), Vector2(0.52, 0.35), Vector2(0.7, 0.58),
			Vector2(0.86, 0.38), Vector2(0.3, 0.25), Vector2(0.62, 0.78), Vector2(0.45, 0.5)]
		for k in spots.size():
			var p: Vector2 = spots[k] * r.size
			var rad := r.size.y * (0.22 + 0.06 * (k % 3))
			c.draw_circle(p, rad, cols[k % cols.size()], true, -1.0, true)
		c.draw_circle(spots[7] * r.size, r.size.y * 0.16, Color(DS.GOLD, 0.9), true, -1.0, true))
	return c


func _section_cards(sec: String) -> void:
	var box := section(sec, _list)
	for it in Store.CATALOG:
		if it.section == sec:
			box.add_child(_product_card(it))


## Statesman Pass: monthly and yearly plans side by side.
func _pass_section() -> void:
	var head := Label.new()
	head.theme_type_variation = &"Overline"
	head.text = "STATESMAN PASS"
	_list.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	_list.add_child(row)
	for id in ["pass_monthly", "pass_yearly"]:
		var it := Store.item(id)
		var card := PanelContainer.new()
		card.theme_type_variation = &"GroupPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(60, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", DS.S2)
		card.add_child(v)
		var tile := ListRow.icon_tile("crown", DS.GOLD)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(tile)
		var t := Label.new()
		t.theme_type_variation = &"Headline"
		t.text = "Yearly" if id == "pass_yearly" else "Monthly"
		v.add_child(t)
		var price := Label.new()
		price.theme_type_variation = &"StatSmall"
		price.text = Store.price_text(id)
		price.clip_text = true
		price.custom_minimum_size = Vector2(20, 0)
		v.add_child(price)
		if it.has("badge"):
			v.add_child(_pill(str(it.badge), DS.GREEN))
		v.add_child(_action_button(it, "Subscribe"))
		row.add_child(card)
	var n := Label.new()
	n.theme_type_variation = &"Caption"
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(60, 0)
	n.text = str(Store.item("pass_monthly").desc)
	_list.add_child(n)


func _tips_section() -> void:
	var head := Label.new()
	head.theme_type_variation = &"Overline"
	head.text = "SUPPORT THE DEVELOPER"
	_list.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	_list.add_child(row)
	for it in Store.CATALOG:
		if it.section != "Support the developer":
			continue
		var card := PanelContainer.new()
		card.theme_type_variation = &"TilePanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(40, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", 4)
		card.add_child(v)
		var t := Label.new()
		t.theme_type_variation = &"Subhead"
		t.text = str(it.title)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var pr := Label.new()
		pr.theme_type_variation = &"StatSmall"
		pr.text = Store.price_text(str(it.id))
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pr)
		var b := _action_button(it, "Tip")
		v.add_child(b)
		row.add_child(card)


func _pill(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ForecastChip"
	var l := Label.new()
	l.theme_type_variation = &"ChipValue"
	l.text = text
	l.add_theme_color_override(&"font_color", color)
	p.add_child(l)
	return p


func _product_card(it: Dictionary) -> Control:
	var card := VBoxContainer.new()
	card.add_theme_constant_override(&"separation", DS.S2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(top)
	var tile := ListRow.icon_tile(str(it.icon), Store.tint(str(it.tint)))
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tile)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var title_row := HBoxContainer.new()
	mid.add_child(title_row)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = str(it.title)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(t)
	if it.has("badge"):
		var b := Label.new()
		b.theme_type_variation = &"BadgeLabel"
		b.text = str(it.badge)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(b)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.text = str(it.desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(d)
	if it.has("includes"):
		var inc := Label.new()
		inc.theme_type_variation = &"Caption"
		inc.text = "  ·  ".join(PackedStringArray(it.includes))
		inc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(inc)
	card.add_child(_action_button(it))
	return card


func _action_button(it: Dictionary, buy_label: String = "") -> Control:
	var id := str(it.id)
	if it.has("theme") and Store.owns_product(id):
		var on: bool = Settings.map_theme == it.theme
		var b := AppButton.make("In use" if on else "Use this theme", &"Chip" if on else &"PrimaryButton",
			"check" if on else "")
		b.disabled = on
		b.pressed.connect(func() -> void:
			Settings.set_value("map_theme", str(it.theme))
			Haptics.success()
			refresh())
		return b
	if it.kind == "subscription" and Store.owns_product(id):
		var c := AppButton.make("Active · Cancel subscription", &"GhostButton")
		c.pressed.connect(func() -> void:
			Store.cancel_subscription()
			_flash("Subscription cancelled. (Demo)", false))
		return c
	if Store.owns_product(id):
		var o := AppButton.make("Owned" + ("  ·  arrives in a future update" if it.get("soon", false) else ""),
			&"Chip", "check")
		o.disabled = true
		return o
	var buy := AppButton.make(buy_label if buy_label != "" else Store.price_text(id), &"", "")
	buy.pressed.connect(_confirm.bind(it))
	return buy


func _confirm(it: Dictionary) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(it.icon), Store.tint(str(it.tint)), "Confirm purchase", str(it.title))
	var price := Store.price_text(str(it.id))
	m.body("%s\n\n%s" % [str(it.desc), "Renews each %s until you cancel." % it.period if it.kind == "subscription" else "One-time purchase."])
	var demo := Label.new()
	demo.theme_type_variation = &"Footnote"
	demo.add_theme_color_override(&"font_color", DS.ORANGE)
	demo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demo.text = "Demo store: you will not be charged."
	m.content.add_child(demo)
	m.choice("Buy for %s" % price, "", &"PrimaryButton", func() -> void:
		demo.text = "Processing…"
		var r: Dictionary = await Store.purchase(str(it.id))
		if r.ok:
			Haptics.success()
			m.dismiss()
			_flash("Thank you! %s is yours." % it.title, true))
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


func _flash(text: String, good: bool) -> void:
	_toast.text = text
	_toast.visible = true
	_toast.add_theme_color_override(&"font_color", DS.GREEN if good else DS.TEXT_2)
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
