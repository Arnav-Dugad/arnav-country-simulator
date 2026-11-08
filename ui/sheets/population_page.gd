class_name PopulationPage
extends SheetPage
## People & cities: population, births, the age structure, cities and housing.

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "People & cities"


func _build() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	var s := Population.st()
	var dp := c.population / maxf(float(s.pop0), 1.0) - 1.0
	_box.add_child(photo_header("city", "%s people" % DS.compact(c.population), "%s since you took office  ·  %d%% live in cities" % [
		("+" if dp >= 0.0 else "−") + "%s%%" % String.num(absf(dp) * 100.0, 1), roundi(Population.urban())], 140.0))
	var g := grid(_box, 2)
	var tfr := Population.fertility()
	g.add_child(_tile("baby", DS.TEAL, "Births", String.num(tfr, 2), "children per woman" + ("  ·  below 2.1" if tfr < 2.1 else "")))
	var af := Population.afford()
	g.add_child(_tile("house", DS.GREEN if af >= 95.0 else (DS.ORANGE if af >= 80.0 else DS.RED), "Housing", "%d" % roundi(af),
		"affordability  ·  100 = at start"))
	# Age structure.
	var st := Population.structure(c)
	var ab := section("Age structure", _box)
	var labels := ["Children (0-14)", "Working age", "Over 65"]
	var cols := [DS.TEAL, DS.ACCENT, DS.ORANGE]
	for k in 3:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		ab.add_child(row)
		var l := Label.new()
		l.theme_type_variation = &"Footnote"
		l.text = labels[k]
		l.custom_minimum_size = Vector2(118, 0)
		row.add_child(l)
		var bar := meter(float(st[k]) / 70.0, 0.0, cols[k], 10.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var v := Label.new()
		v.theme_type_variation = &"StatSmall"
		v.text = "%d%%" % roundi(float(st[k]))
		v.custom_minimum_size = Vector2(44, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
	note("Fewer children and longer lives mean more retirees for each worker: pensions cost more and growth slows. Births, migrants and a later pension age all help.", ab)
	# Family policy.
	var fb := section("Family policy", _box)
	var fl := PackedStringArray()
	for f in Population.FAMILY:
		fl.append(str(Population.FAMILY_INFO[f].title))
	var seg := SegmentedControl.new().setup(fl, [], Population.FAMILY.find(str(s.family)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Population.set_family(str(Population.FAMILY[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	fb.add_child(seg)
	var cost := Population.family_cost_pct()
	note(str(Population.FAMILY_INFO[str(s.family)].desc) + ("  Costs %s a year. Births rise slowly over a few years; families are happier." % DS.money(c.gdp * cost / 100.0) if cost > 0.0 else ""), fb)
	# Housing.
	var hb := section("Cities & housing", _box)
	var bal := Population.housing_balance(c)
	var hl := ListRow.new().setup("Housing market", ("Homes are getting more affordable" if bal > 0.3 else ("Rents are rising faster than wages" if bal < -0.3 else "Keeping pace")) +
		"  ·  cities grow %s a year" % ("+%s pts" % String.num(float(s.get("urban_rate", 0.0)), 1)))
	hl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hl.set_leading(ListRow.icon_tile("building-2", DS.GREEN if bal > 0.3 else (DS.ORANGE if bal >= -0.3 else DS.RED)))
	hb.add_child(hl)
	if not bool(s.zoning):
		var zb := AppButton.make("Reform zoning  ·  %d capital" % int(Economy.POPC_ZONING_CAPITAL), &"", "landmark")
		zb.disabled = not Capital.can(Economy.POPC_ZONING_CAPITAL)
		zb.pressed.connect(func() -> void:
			if Population.reform_zoning():
				Haptics.success()
			refresh())
		hb.add_child(zb)
		note("Lets private builders put up far more homes. Some neighbourhoods will object.", hb)
	else:
		note("Zoning reformed: private builders are adding homes faster.", hb)
	var bb := AppButton.make("Build affordable homes", &"", "house")
	bb.pressed.connect(func() -> void:
		var gs := get_tree().current_scene
		if gs and gs.has_method("open_page"):
			gs.open_page("build")
			var bp = gs._pages.get("build")
			if bp:
				bp._order("housing"))
	hb.add_child(bb)


func _tile(icon: String, color: Color, head: String, value: String, sub: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	v.add_child(h)
	var ic := TextureRect.new()
	ic.texture = DS.icon(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(16, 16)
	ic.modulate = color
	h.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Caption"
	t.text = head.to_upper()
	h.add_child(t)
	var val := Label.new()
	val.theme_type_variation = &"StatValue"
	val.text = value
	v.add_child(val)
	var c := Label.new()
	c.theme_type_variation = &"Caption"
	c.text = sub
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size = Vector2(30, 0)
	v.add_child(c)
	return p
