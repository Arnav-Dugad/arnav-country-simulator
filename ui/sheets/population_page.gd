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
	_regions()
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


# ------------------------------------------------------------------- regions ---
func _regions() -> void:
	var rb := section("Regions", _box)
	var regs := Regions.list()
	var u := Regions.unity()
	note("Each region has its own wealth and loyalty. The capital pulls ahead unless you invest elsewhere; poor or neglected regions, and regions with their own identity, drift away. Tap a region to act.", rb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", DS.S3)
	rb.add_child(head)
	var ul := Label.new()
	ul.theme_type_variation = &"Subhead"
	ul.text = "National unity"
	ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ul)
	var uv := Label.new()
	uv.theme_type_variation = &"StatSmall"
	uv.text = "%d" % roundi(u)
	uv.add_theme_color_override(&"font_color", DS.GREEN if u >= 70.0 else (DS.ACCENT if u >= 55.0 else DS.ORANGE))
	head.add_child(uv)
	# A proportional strip: each region's share of the people, coloured by mood.
	var strip := Control.new()
	strip.custom_minimum_size = Vector2(0, 14)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(func() -> void:
		var x := 0.0
		for g in regs:
			var w := strip.size.x * float(g.share)
			var col: Color = Color(1, 1, 1, 0.08) if bool(g.lost) else Regions.mood_color(g)
			strip.draw_rect(Rect2(x + 1.0, 0, maxf(w - 2.0, 1.0), 14), Color(col, 0.85))
			x += w)
	rb.add_child(strip)
	for k in regs.size():
		var g: Dictionary = regs[k]
		var tags := PackedStringArray()
		if bool(g.lost):
			tags.append("Independent")
		else:
			tags.append("%d%% of people" % roundi(float(g.share) * 100.0))
			tags.append("incomes %d%% of avg" % roundi(float(g.wealth) * 100.0))
			if bool(g.distinct):
				tags.append("own identity")
			if bool(g.autonomy):
				tags.append("autonomous")
			if Regions.fund_active(g):
				tags.append("fund: %d months left" % (Economy.REG_FUND_MONTHS - (Game.months_played - int(g.fund))))
			if int(g.tension) > 0:
				tags.append("separatists gaining")
		var econ: Dictionary = Regions.ECON.get(str(g.econ), Regions.ECON.farming)
		var row := ListRow.new().setup(str(g.name), str(econ.text).left(1).to_upper() + str(econ.text).substr(1) + "  ·  " + "  ·  ".join(tags),
			"" if bool(g.lost) else "%s %d" % [Regions.mood(g), roundi(float(g.loyalty))])
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3 if bool(g.lost) else Regions.mood_color(g))
		row.set_leading(ListRow.icon_tile(str(econ.icon), DS.TEXT_3 if bool(g.lost) else Regions.mood_color(g)))
		rb.add_child(row)
		if not bool(g.lost):
			rb.add_child(meter(float(g.loyalty) / 100.0, 0.0, Regions.mood_color(g), 4.0))
			var kk := k
			row.tapped.connect(func() -> void: _region_actions(kk))


func _region_actions(k: int) -> void:
	var g: Dictionary = Regions.list()[k]
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("map-pin", Regions.mood_color(g), "Region", str(g.name))
	var why := PackedStringArray()
	if float(g.wealth) < 0.85:
		why.append("it is poorer than the rest of the country")
	if bool(g.distinct):
		why.append("it has its own language and history")
	if c.approval < 45.0:
		why.append("the government is unpopular")
	if Game.months_played - int(g.crack) < 36:
		why.append("the crackdown is remembered")
	m.body("%s  ·  loyalty %d, heading to %d%s.%s" % [Regions.mood(g), roundi(float(g.loyalty)), roundi(Regions.target(g)),
		(" (%s)" % ", ".join(why)) if not why.is_empty() else "",
		("  A referendum now: about %d%% would vote to leave." % roundi(Regions.yes_share(g))) if float(g.loyalty) < 45.0 else ""])
	var fund_note := "%s a year for 3 years · the region catches up" % DS.money(c.gdp * Economy.REG_FUND_COST / 100.0)
	if Regions.fund_active(g):
		fund_note = "Running · %d months left" % (Economy.REG_FUND_MONTHS - (Game.months_played - int(g.fund)))
	elif not Regions.can_fund(g):
		fund_note = "At most %d funds at once" % Economy.REG_FUND_MAX
	var f := m.choice("Development fund", fund_note, &"PrimaryButton", func() -> void:
		if Regions.fund(k):
			Simulation.update_finances(Game.me())
			Haptics.success()
		m.dismiss()
		refresh())
	if not Regions.can_fund(g):
		for bb in f.find_children("*", "Button", true, false):
			(bb as Button).disabled = true
	if not bool(g.autonomy):
		var a := m.choice("Grant autonomy", "Own parliament · %d political capital · much more loyal" % int(Economy.REG_AUTONOMY_CAPITAL), &"GhostButton", func() -> void:
			if Regions.grant_autonomy(k):
				Simulation.update_finances(Game.me())
				Haptics.success()
			m.dismiss()
			refresh())
		if not Capital.can(Economy.REG_AUTONOMY_CAPITAL):
			for bb in a.find_children("*", "Button", true, false):
				(bb as Button).disabled = true
	if Regions.can_crack(g):
		m.choice("Crack down on separatists", "Quiet for a while · loyalty falls, approval −2", &"DestructiveButton", func() -> void:
			if Regions.crack(k):
				Haptics.warning()
			m.dismiss()
			refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)
