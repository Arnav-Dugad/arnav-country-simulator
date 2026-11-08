class_name PopulationPage
extends SheetPage
## People & society: regions, health, schools, births, the age structure, cities and housing.

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "People & society"


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
	_box.add_child(jump_bar(["Regions", "Health system", "Air quality", "Schools & universities", "Diaspora & remittances", "Age structure", "Family policy", "Cities & housing"]))
	_regions()
	_health()
	_air()
	_education()
	_diaspora()
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
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(20, 0)
	h.add_child(t)
	var val := Label.new()
	val.theme_type_variation = &"StatValue"
	val.text = value
	val.clip_text = true
	val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	val.custom_minimum_size = Vector2(20, 0)
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


# ---------------------------------------------------- schools & universities ---
func _education() -> void:
	var eb := section("Schools & universities", _box)
	var e := Education.st()
	var c := Game.me()
	var g := grid(eb, 2)
	var sc := Education.score()
	var ds := sc - float(e.score0)
	g.add_child(_tile("school", DS.GREEN if sc >= 490.0 else (DS.ACCENT if sc >= 450.0 else DS.ORANGE), "Learning score", "%d" % roundi(sc),
		"%s  ·  %s since you took office" % [Education.score_text(sc), ("%+d" % roundi(ds)) if absf(ds) >= 1.0 else "no change"]))
	var dr := Education.drain()
	g.add_child(_tile("plane-takeoff", DS.GREEN if dr < 8.0 else (DS.ORANGE if dr < 18.0 else DS.RED), "Brain drain", "%d%%" % roundi(dr),
		"of graduates leave each year"))
	var tg := Education.score_target()
	note("An international test of what 15-year-olds can do (300-600). It moves slowly: today's pupils are tomorrow's workforce. %s" % (
		("Heading to %d with your current choices." % roundi(tg)) if absf(tg - sc) >= 3.0 else "More education budget or a reform will raise it."), eb)
	# Universities: world ranks.
	var ranks := Education.ranks()
	var ranks0 := Education.ranks(true)
	for k in Education.UNIS.size():
		var rk := int(ranks[k])
		var r0 := int(ranks0[k])
		var sub := "World rank"
		if rk != r0 and r0 < 1000:
			sub += "  ·  %s from #%d" % ["up" if rk < r0 else "down", r0]
		var row := ListRow.new().setup(str(Education.UNIS[k]), sub, "#%d" % rk if rk < 1000 else "1000+")
		row.trailing_label.add_theme_color_override(&"font_color", DS.GOLD if rk <= 10 else (DS.GREEN if rk <= 100 else DS.TEXT_2))
		row.set_leading(ListRow.icon_tile("graduation-cap", DS.GOLD if rk <= 10 else (DS.ACCENT if rk <= 100 else DS.TEXT_3)))
		eb.add_child(row)
	var fl := PackedStringArray()
	for f in Education.FUNDING:
		fl.append(str(Education.FUNDING_INFO[f].title))
	var seg := SegmentedControl.new().setup(fl, [], Education.FUNDING.find(str(e.fund)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Education.set_fund(str(Education.FUNDING[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	eb.add_child(seg)
	var fc := float(Education.FUNDING_INFO[str(e.fund)].cost)
	note("University funding%s. Better universities climb the world table over years and bring research, foreign students and prestige. The research budget and campuses help too." % (
		"  ·  %s a year" % DS.money(c.gdp * fc / 100.0) if fc > 0.0 else ""), eb)
	# Reforms.
	for id in Education.REFORMS:
		var r: Dictionary = Education.REFORMS[id]
		var on := Education.has_reform(str(id))
		var bits := PackedStringArray([str(r.desc)])
		if float(r.cost) > 0.0:
			bits.append("%s a year" % DS.money(c.gdp * float(r.cost) / 100.0))
		if float(r.capital) > 0.0 and not on:
			bits.append("%d political capital" % int(r.capital))
		if r.has("score"):
			bits.append("score +%d" % int(r.score))
		if r.has("drain"):
			bits.append("brain drain %d pts" % int(r.drain))
		var row := ListRow.new().setup(str(r.title), "  ·  ".join(bits), "On" if on else "›")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.GREEN if on else DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(r.icon), DS.GREEN if on else DS.ACCENT))
		var rid := str(id)
		row.tapped.connect(func() -> void:
			if Education.has_reform(rid):
				if float(Education.REFORMS[rid].cost) > 0.0:
					Education.cancel(rid)
					Haptics.select()
			elif Education.reform(rid):
				Haptics.success()
			Simulation.update_finances(Game.me())
			refresh())
		eb.add_child(row)
	note("Tap a reform to start it. Reforms that cost money each year can be stopped again; a new curriculum stays.", eb)


# ------------------------------------------------------------- health system ---
func _health() -> void:
	var hb := section("Health system", _box)
	var s := Health.st()
	var c := Game.me()
	var g := grid(hb, 3 if Settings.text_scale < 1.0 else 2)
	var dw := Health.wait() - float(s.wait0)
	g.add_child(_tile("hourglass", DS.GREEN if dw < -1.0 else (DS.TEXT_2 if dw < 2.0 else DS.RED), "Waiting", "%d wk" % roundi(Health.wait()),
		"for an operation"))
	g.add_child(_tile("stethoscope", DS.ACCENT, "Doctors", String.num(Health.docs(), 1), "per 1,000 people"))
	var u := Health.uhc()
	g.add_child(_tile("heart-pulse", DS.GREEN if u >= 80.0 else (DS.ORANGE if u >= 55.0 else DS.RED), "Coverage", "%d" % roundi(u), "of 100 (WHO)"))
	var hint := PackedStringArray()
	if absf(dw) >= 1.0:
		hint.append("Waits are %s %d weeks since you took office" % ["up" if dw > 0.0 else "down", roundi(absf(dw))])
	if Health.in_training() > 0.005:
		hint.append("%s more doctors per 1,000 in medical school" % String.num(Health.in_training(), 2))
	note((("  ·  ".join(hint) + ". ") if not hint.is_empty() else "") + "An ageing population and epidemics lengthen waits; doctors and the health budget shorten them.", hb)
	# Training places.
	var tl := PackedStringArray()
	for t in Health.TRAIN:
		tl.append(str(Health.TRAIN_INFO[t].title))
	var seg := SegmentedControl.new().setup(tl, [], Health.TRAIN.find(str(s.train)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Health.set_train(str(Health.TRAIN[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	hb.add_child(seg)
	var tc := float(Health.TRAIN_INFO[str(s.train)].cost)
	note("Medical school places. New doctors arrive after six years%s." % ("  ·  %s a year" % DS.money(c.gdp * tc / 100.0) if tc > 0.0 else ""), hb)
	var ab := AppToggle.new().setup("Recruit doctors abroad  ·  %s a year" % DS.money(c.gdp * Economy.HLTH_ABROAD_COST / 100.0), bool(s.abroad), "plane-landing")
	ab.toggled.connect(func(on: bool) -> void:
		Health.set_abroad(on)
		Simulation.update_finances(Game.me())
		Haptics.select())
	hb.add_child(ab)
	# Medicine prices.
	var dl := PackedStringArray()
	for d in Health.DRUGS:
		dl.append(str(Health.DRUGS_INFO[d].title))
	var dseg := SegmentedControl.new().setup(dl, [], Health.DRUGS.find(str(s.drugs)))
	dseg.fill = true
	dseg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dseg.changed.connect(func(k: int) -> void:
		Health.set_drugs(str(Health.DRUGS[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	hb.add_child(dseg)
	var di: Dictionary = Health.DRUGS_INFO[str(s.drugs)]
	note("Medicine prices: %s%s" % [str(di.desc), ("  Saves %s a year." % DS.money(c.gdp * float(di.save) / 100.0)) if float(di.save) > 0.0 else ""], hb)


# ---------------------------------------------------- diaspora & remittances ---
func _diaspora() -> void:
	var db := section("Diaspora & remittances", _box)
	var s := Diaspora.st()
	var c := Game.me()
	var r := Diaspora.rate()
	if absf(float(s.r0)) < 0.5:
		note("Few families here depend on money from relatives abroad, and few foreign workers send money home.", db)
		return
	var d := r - float(s.r0)
	var hl := ListRow.new().setup("Money sent home" if not Diaspora.host() else "Money sent abroad",
		"%s of GDP  ·  %s a year" % [DS.pct(absf(r), 1), DS.money(c.gdp * absf(r) / 100.0)] + (("  ·  %+.1f pts since you took office" % d) if absf(d) >= 0.1 else ""))
	hl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hl.set_leading(ListRow.icon_tile("plane-landing" if not Diaspora.host() else "plane-takeoff", DS.TEAL))
	db.add_child(hl)
	if Diaspora.host():
		note("Many foreign workers live here and send part of their pay home. A tax on outgoing transfers raises money, but the countries they come from resent it.", db)
		var tt := AppToggle.new().setup("Tax money sent abroad  ·  +%s a year" % DS.money(c.gdp * absf(r) * Economy.DIAS_TAX_RATE / 100.0), bool(s.tax), "receipt")
		tt.toggled.connect(func(on: bool) -> void:
			Diaspora.set_tax(on)
			Simulation.update_finances(Game.me())
			Haptics.select())
		db.add_child(tt)
		return
	note("Citizens working abroad support their families at home. More arrives when transfers are cheap and when the economies they work in are booming.", db)
	var ft := AppToggle.new().setup("Cheaper money transfers  ·  %s a year" % DS.money(c.gdp * Economy.DIAS_FEES_COST / 100.0), bool(s.fees), "hand-coins")
	ft.toggled.connect(func(on: bool) -> void:
		Diaspora.set_fees(on)
		Simulation.update_finances(Game.me())
		Haptics.select())
	db.add_child(ft)
	if not bool(s.vote):
		var vb := AppButton.make("Overseas vote  ·  %d capital" % int(Economy.DIAS_VOTE_CAPITAL), &"", "vote")
		vb.disabled = not Diaspora.can_vote()
		vb.pressed.connect(func() -> void:
			if Diaspora.give_vote():
				Haptics.success()
			refresh())
		db.add_child(vb)
	else:
		note("Citizens abroad vote and keep both passports: they stay close to home.", db)
	if not bool(s.vote):
		note("Voting from abroad and dual citizenship keep emigrants close: a little more money home, approval and soft power.", db)
	if r >= 1.0:
		var wait := Diaspora.bond_wait()
		var bb := AppButton.make(("Diaspora bonds  ·  raise %s" % DS.money(Diaspora.bond_size())) if wait == 0 else "Diaspora bonds again in %d months" % wait, &"", "landmark")
		bb.disabled = wait > 0
		bb.pressed.connect(func() -> void:
			if Diaspora.issue_bond():
				Simulation.update_finances(Game.me())
				Haptics.success()
			refresh())
		db.add_child(bb)
		note("Your people abroad lend to their country at a low rate. It adds to the debt, so use it wisely.", db)


# --------------------------------------------------------------- air quality ---
func _air() -> void:
	var ab := section("Air quality", _box)
	var s := Air.st()
	var v := Air.pm()
	var d := v - float(s.pm0)
	var c := Game.me()
	var hl := ListRow.new().setup(Air.label(v),
		"%d µg/m³ of fine dust (WHO guideline: 5)" % roundi(v) + (("  ·  %+d since you took office" % roundi(d)) if absf(d) >= 1.0 else ""))
	hl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hl.set_leading(ListRow.icon_tile("wind", Air.color(v)))
	ab.add_child(hl)
	ab.add_child(meter(clampf(v / 80.0, 0.0, 1.0), 0.0, Air.color(v), 6.0))
	note("It follows your power plants, traffic and industry: cleaner energy clears the air too. Dirty air costs years of life. %s" % (
		("Heading to %d." % roundi(Air.target())) if absf(Air.target() - v) >= 1.0 else ""), ab)
	for id in Air.POLICIES:
		if not Air.available(str(id)):
			continue
		var p: Dictionary = Air.POLICIES[id]
		var t := AppToggle.new().setup("%s  ·  %s a year" % [str(p.title), DS.money(c.gdp * float(p.cost) / 100.0)], Air.has(str(id)), str(p.icon))
		var pid := str(id)
		t.toggled.connect(func(_on: bool) -> void:
			Air.toggle(pid)
			Simulation.update_finances(Game.me())
			Haptics.select())
		ab.add_child(t)
