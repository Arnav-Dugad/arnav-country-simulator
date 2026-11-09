class_name IndustriesPage
extends SheetPage
## Industries & trade: the sectors of your economy, how competitive each is and
## why, subsidies, world shocks and your biggest trading partners.

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "Industries"


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
	var s := Industries.st()
	var top := ""
	var best := 0.0
	for id in s.sec:
		if str(id) != "services" and float(s.sec[id].share) > best:
			best = float(s.sec[id].share)
			top = str(Industries.SECTORS[id].title)
	_box.add_child(photo_header("factory", "Industries & trade", "Biggest industry: %s  ·  %d subsidised" % [top.to_lower(), Industries.subsidy_count()], 132.0))
	var me_ := Minerals.mine_list()
	var mx := 0.0
	for m in me_:
		mx += Minerals.earnings_pct(str(m))
	var ss := Food.self_sufficiency()
	var items: Array = [
		["battery-charging", DS.GOLD if not me_.is_empty() else DS.TEXT_3, "Minerals", DS.pct(mx, 1) if not me_.is_empty() else "None", "Critical minerals"],
		["wheat", DS.GREEN if ss >= 90.0 else (DS.ORANGE if ss >= 40.0 else DS.RED), "Food", "%d%%" % roundi(ss), "Food security"],
	]
	if Fisheries.coastal():
		items.append(["fish", Fisheries.color(Fisheries.stock()), "Fish", "%d" % roundi(Fisheries.stock()), "Fisheries & oceans"])
	items.append(["bot", DS.PURPLE, "Robots", "%d" % roundi(Automation.level()), "Robots & AI"])
	items.append(["wifi", DS.ACCENT, "Online", "%d%%" % roundi(Digital.online()), "Digital nation"])
	glance(items, _box)
	var sh: Dictionary = s.shock
	if not sh.is_empty():
		var r := ListRow.new().setup("World shock", "%s  ·  %d months left" % [str(sh.text), maxi(0, int(sh.until) - Game.months_played)])
		r.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		r.set_leading(ListRow.icon_tile("globe", DS.ORANGE))
		r.theme_type_variation = &"GroupPanel"
		_box.add_child(r)
	var box := section("Your economy, sector by sector", _box)
	var ids: Array = s.sec.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return float(s.sec[a].share) > float(s.sec[b].share))
	for id in ids:
		box.add_child(_sector_row(c, str(id)))
	note("Tap a sector to see what drives it and to subsidise it. Competitive sectors grow and hire; struggling ones shrink. Skills, research, infrastructure and clean government help every sector.", box)
	_digital_nation()
	_minerals()
	_food()
	_fisheries()
	_automation()
	# Partners.
	var pb := section("Biggest trading partners", _box)
	for pr in Industries.partners(5):
		var j := int(pr[0])
		var tags: PackedStringArray = []
		if Diplomacy.has_deal(j):
			tags.append("trade deal")
		if j in World.neighbours_of(Game.player):
			tags.append("neighbour")
		if Tariffs.has(j):
			tags.append("tariffs")
		var row := ListRow.new().setup(World.map.names[j], ", ".join(tags).capitalize() if not tags.is_empty() else Diplomacy.relation_text(Game.relations[j]), "›")
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(Flag.new().show_country(j, 22.0))
		row.tapped.connect(func() -> void:
			var gs := get_tree().current_scene
			if gs and gs.has_method("_open_country"):
				gs._open_country(j, true))
		pb.add_child(row)


func _sector_row(c: CountryState, id: String) -> Control:
	var info: Dictionary = Industries.SECTORS[id]
	var sec: Dictionary = Industries.st().sec[id]
	var comp := float(sec.get("comp", Industries.competitiveness(c, id)))
	var d := float(sec.share) - float(sec.share0)
	var col := DS.GREEN if comp >= 60.0 else (DS.ACCENT if comp >= 45.0 else (DS.ORANGE if comp >= 30.0 else DS.RED))
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	var row := ListRow.new().setup(str(info.title), "%s of the economy%s%s" % [DS.pct(float(sec.share), 1),
		("  ·  %s since you took office" % (("+" if d >= 0.0 else "") + String.num(d, 1) + " pts")) if absf(d) >= 0.1 else "",
		"  ·  subsidised" if bool(sec.sub) else ""], "%d" % roundi(comp), "competitive")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.trailing_label.add_theme_color_override(&"font_color", col)
	row.set_leading(ListRow.icon_tile(str(info.icon), col))
	row.tapped.connect(_sector_card.bind(id))
	v.add_child(row)
	v.add_child(meter(comp / 100.0, 0.0, col, 3.0))
	return v


func _sector_card(id: String) -> void:
	var c := Game.me()
	var info: Dictionary = Industries.SECTORS[id]
	var sec: Dictionary = Industries.st().sec[id]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(info.icon), DS.ACCENT, "Industry", str(info.title))
	m.body("%s of your economy. Competitiveness %d / 100." % [DS.pct(float(sec.share), 1), roundi(Industries.competitiveness(c, id))])
	var chips: Array = []
	for dr in Industries.drivers(c, id):
		var val := float(dr[1])
		if absf(val) >= 0.5:
			chips.append(["%s %+d" % [str(dr[0]), roundi(val)], DS.GREEN if val > 0.0 else DS.RED])
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	m.content.add_child(flow)
	for ch in chips:
		var p := PanelContainer.new()
		p.theme_type_variation = &"ForecastChip"
		var l := Label.new()
		l.theme_type_variation = &"ChipValue"
		l.text = str(ch[0])
		l.add_theme_color_override(&"font_color", ch[1])
		p.add_child(l)
		flow.add_child(p)
	var cost := c.gdp * Economy.IND_SUBSIDY_COST * maxf(float(sec.share), 2.0) / 10.0 / 100.0
	if bool(sec.sub):
		m.choice("End the subsidies", "Saves %s a year" % DS.money(cost), &"", func() -> void:
			Industries.set_subsidy(id, false)
			Simulation.update_finances(c)
			Haptics.tap()
			m.dismiss()
			refresh())
	else:
		m.choice("Subsidise it", "+%d competitiveness  ·  costs %s a year  ·  three or more subsidies annoy trade partners" % [
			int(Economy.IND_SUBSIDY), DS.money(cost)], &"PrimaryButton", func() -> void:
			Industries.set_subsidy(id, true)
			Simulation.update_finances(c)
			Haptics.success()
			m.dismiss()
			refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------- automation ---
func _automation() -> void:
	var s := Automation.st()
	var c := Game.me()
	var box := section("Robots & AI", _box)
	var lv := Automation.level()
	var disp := float(s.displaced)
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(r)
	r.add_child(ListRow.icon_tile("bot", DS.PURPLE))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Automation %d / 100" % roundi(lv)
	col.add_child(t)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	cap.text = "+%s a year  ·  %s of workers displaced and still looking" % [String.num(Automation.pace(), 1), DS.pct(disp, 1)]
	col.add_child(cap)
	box.add_child(meter(lv / 100.0, 0.0, DS.PURPLE, 4.0))
	note("Robots and AI make the economy more productive, but some jobs vanish faster than new ones appear. Research (AI, automation) speeds it up.", box)
	for row in [["retraining", "Retraining programme", "graduation-cap", "Moves displaced workers into new jobs faster. Costs %s a year." % DS.money(c.gdp * Economy.AUTO_RETRAIN_COST / 100.0)],
			["robot_tax", "Robot tax", "coins", "Raises revenue from automation, but slows it down."],
			["short_week", "Four-day working week", "calendar", "Happier people and shared work; a little less output."]]:
		var key := str(row[0])
		var tg := AppToggle.new().setup(str(row[1]), bool(s.get(key, false)), str(row[2]))
		tg.toggled.connect(func(on: bool) -> void:
			Automation.set_policy(key, on)
			Simulation.update_finances(Game.me())
			Haptics.select()
			refresh())
		box.add_child(tg)
		var d := Label.new()
		d.theme_type_variation = &"Caption"
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(60, 0)
		d.text = str(row[3])
		box.add_child(d)
	if not Laws.is_active(c, "basic_income"):
		note("A basic income (Laws page) also cushions people who lose their jobs to machines.", box)


# ------------------------------------------------------------- food security ---
func _food() -> void:
	var fb := section("Food security", _box)
	var s := Food.st()
	var c := Game.me()
	var ss := Food.self_sufficiency()
	var g := grid(fb, 2)
	g.add_child(_food_tile("wheat", DS.GREEN if ss >= 90.0 else (DS.ORANGE if ss >= 40.0 else DS.RED), "Grown at home", "%d%%" % roundi(ss), Food.label(ss)))
	var rv := Food.reserve()
	g.add_child(_food_tile("warehouse", DS.GREEN if rv >= 4.0 else (DS.ORANGE if rv >= 1.5 else DS.RED), "Grain reserve", "%s mo" % String.num(rv, 1), "of food in store"))
	var fg := Game.markets.food_gap()
	note("World food prices are %s.%s A full reserve is released automatically when prices spike." % [
		("%d%% above normal" % roundi(fg * 100.0)) if fg > 0.05 else (("%d%% below normal" % roundi(-fg * 100.0)) if fg < -0.05 else "normal"),
		"  You import much of your food, so spikes hit hard." if ss < 60.0 else ""], fb)
	var sl := PackedStringArray()
	for k in Food.SUPPORT:
		sl.append(str(Food.SUPPORT_INFO[k].title))
	var seg := SegmentedControl.new().setup(sl, [], Food.SUPPORT.find(str(s.support)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Food.set_support(str(Food.SUPPORT[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	fb.add_child(seg)
	var si: Dictionary = Food.SUPPORT_INFO[str(s.support)]
	note("Farm support%s. Subsidies raise harvests over the years and please rural voters, but cost money and some efficiency." % (
		"  ·  %s a year" % DS.money(c.gdp * float(si.cost) / 100.0) if float(si.cost) > 0.0 else ""), fb)
	var ft := AppToggle.new().setup("Fill the grain reserve  ·  %s a year" % DS.money(c.gdp * Economy.FOOD_SEC_FILL_COST / 100.0), bool(s.fill), "warehouse")
	ft.toggled.connect(func(on: bool) -> void:
		Food.set_fill(on)
		Simulation.update_finances(Game.me())
		Haptics.select())
	fb.add_child(ft)
	if Food.can_ban() and Food.spike():
		var bt := AppToggle.new().setup("Ban food exports until prices calm", bool(s.ban), "ban")
		bt.toggled.connect(func(on: bool) -> void:
			Food.set_ban(on)
			Haptics.select()
			refresh())
		fb.add_child(bt)
		note("Keeps food cheap at home, but countries that buy your food will resent it.", fb)
	elif Food.can_ban():
		note("As a food exporter you can ban exports during a world price spike.", fb)


func _food_tile(icon: String, color: Color, head: String, value: String, sub: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 6)
	v.add_child(top)
	var ic := TextureRect.new()
	ic.texture = DS.icon(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(14, 14)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = color
	top.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Caption"
	t.text = head.to_upper()
	top.add_child(t)
	var val := Label.new()
	val.theme_type_variation = &"StatSmall"
	val.text = value
	v.add_child(val)
	var sl := Label.new()
	sl.theme_type_variation = &"Caption"
	sl.text = sub
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)
	return p


# ---------------------------------------------------------- critical minerals ---
func _minerals() -> void:
	var box := section("Critical minerals", _box)
	var mine := Minerals.mine_list()
	note("Batteries, wind turbines and chips need a handful of minerals, and a few countries mine most of them. Demand climbs as the world electrifies." +
		("" if not mine.is_empty() else "  You produce none yet: a survey may find some."), box)
	for m in mine:
		var info: Dictionary = Minerals.ALL[m]
		var s := Minerals.st()
		var sh := Minerals.share(m)
		var bits := PackedStringArray(["%s of world output" % DS.pct(sh, 0), ("%s of GDP in exports" % DS.pct(Minerals.earnings_pct(m), 1)) if Minerals.earnings_pct(m) >= 0.05 else "under 0.1% of GDP",
			"price %d" % roundi(float(s.price[m]))])
		if (s.deal as Dictionary).has(m):
			bits.append("deal with %s" % ("the West" if str(s.deal[m]) == "west" else "China"))
		if (s.ban as Dictionary).has(m):
			bits.append("refined at home")
		if Minerals.expanding(m):
			bits.append("new mines in %d months" % (Economy.MIN_EXPAND_MONTHS - (Game.months_played - int(s.build[m]))))
		var row := ListRow.new().setup(str(info.title), "  ·  ".join(bits), "›")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.set_leading(ListRow.icon_tile(str(info.icon), DS.GOLD))
		var mid := str(m)
		row.tapped.connect(func() -> void: _mineral_actions(mid))
		box.add_child(row)
	var wait := Minerals.survey_wait()
	var sb := AppButton.make(("Mineral survey  ·  %d capital" % int(Economy.MIN_SURVEY_CAPITAL)) if wait == 0 else "Next survey in %d months" % wait, &"", "search")
	sb.disabled = wait > 0 or not Capital.can(Economy.MIN_SURVEY_CAPITAL)
	sb.pressed.connect(func() -> void:
		var found := Minerals.survey()
		if found != "":
			Simulation.update_finances(Game.me())
			if found != "-":
				Haptics.success()
			else:
				Haptics.select()
		refresh())
	box.add_child(sb)


func _mineral_actions(m: String) -> void:
	var info: Dictionary = Minerals.ALL[m]
	var s := Minerals.st()
	var c := Game.me()
	var mm := ModalCard.new()
	get_tree().current_scene.add_child(mm)
	mm.header(str(info.icon), DS.GOLD, "Critical minerals", str(info.title))
	var top := PackedStringArray()
	for iso in info.producers:
		var j := World.index_of(str(iso))
		if j >= 0:
			top.append("%s %d%%" % [World.map.names[j], int(info.producers[iso])])
		if top.size() >= 4:
			break
	mm.body("You mine %s of the world's %s. Biggest producers: %s." % [DS.pct(Minerals.share(m), 0), str(info.title).to_lower(), ", ".join(top)])
	var ex := mm.choice("Open new mines", "%s a year for 3 years · more output, local protests" % DS.money(c.gdp * Economy.MIN_EXPAND_COST / 100.0), &"PrimaryButton", func() -> void:
		if Minerals.expand(m):
			Simulation.update_finances(Game.me())
			Haptics.success()
		mm.dismiss()
		refresh())
	if not Minerals.can_expand(m):
		for bb in ex.find_children("*", "Button", true, false):
			(bb as Button).disabled = true
	var deal := str((s.deal as Dictionary).get(m, ""))
	if deal != "west":
		mm.choice("Supply deal with the West", "Better prices · the West warms, China cools", &"GhostButton", func() -> void:
			Minerals.set_deal(m, "west")
			Simulation.update_finances(Game.me())
			Haptics.select()
			mm.dismiss()
			refresh())
	if deal != "east":
		mm.choice("Supply deal with China", "Better prices · China warms, the West cools", &"GhostButton", func() -> void:
			Minerals.set_deal(m, "east")
			Simulation.update_finances(Game.me())
			Haptics.select()
			mm.dismiss()
			refresh())
	var banned := (s.ban as Dictionary).has(m)
	mm.choice("Sell raw ore again" if banned else "Refine it at home", "Exports recover now" if banned else "Ban raw exports · earnings dip for 3 years, then refineries and factories come", &"GhostButton", func() -> void:
		Minerals.ban(m)
		Simulation.update_finances(Game.me())
		Haptics.select()
		mm.dismiss()
		refresh())
	mm.choice("Close", "", &"GhostButton", mm.dismiss)


# --------------------------------------------------------- fisheries & oceans ---
func _fisheries() -> void:
	if not Fisheries.coastal():
		return
	var box := section("Fisheries & oceans", _box)
	var s := Fisheries.st()
	var v := Fisheries.stock()
	var d := v - float(s.stock0)
	var hl := ListRow.new().setup("Fish stocks: %s" % Fisheries.label(v),
		"%d / 100%s  ·  fishing is %s of the economy" % [roundi(v), ("  ·  %+d since you took office" % roundi(d)) if absf(d) >= 1.0 else "",
		DS.pct(Fisheries.share_gdp(), 1)] + ("  ·  the fishery has collapsed" if Fisheries.collapsed() else ""))
	hl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hl.set_leading(ListRow.icon_tile("fish", Fisheries.color(v)))
	box.add_child(hl)
	box.add_child(meter(v / 100.0, 0.0, Fisheries.color(v), 6.0))
	var ql := PackedStringArray()
	for q in Fisheries.QUOTAS:
		ql.append(str(Fisheries.QUOTA_INFO[q].title))
	var seg := SegmentedControl.new().setup(ql, [], Fisheries.QUOTAS.find(str(s.quota)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Fisheries.set_quota(str(Fisheries.QUOTAS[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	box.add_child(seg)
	var ml := PackedStringArray()
	for p in Fisheries.MPAS:
		ml.append("%d%% protected" % int(p) if int(p) > 0 else "No reserves")
	var mseg := SegmentedControl.new().setup(ml, [], Fisheries.MPAS.find(int(s.mpa)))
	mseg.fill = true
	mseg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mseg.changed.connect(func(k: int) -> void:
		Fisheries.set_mpa(int(Fisheries.MPAS[k]))
		Haptics.select()
		refresh())
	box.add_child(mseg)
	note("The catch is %d%% of what it was when you took office. Fishing hard pays now but empties the sea; below 25 a stock can collapse for years. Marine reserves let fish recover and bring divers." % roundi(Fisheries.catch_index() * 100.0), box)


# ------------------------------------------------------------ digital nation ---
func _digital_nation() -> void:
	var box := section("Digital nation", _box)
	var s := Digital.st()
	var c := Game.me()
	var net := Digital.online()
	var d := net - float(s.net0)
	var hl := ListRow.new().setup("%d%% of people online" % roundi(net),
		("%+d pts since you took office" % roundi(d) if absf(d) >= 1.0 else "Build Broadband for all to connect everyone faster"))
	hl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	hl.set_leading(ListRow.icon_tile("wifi", DS.ACCENT))
	box.add_child(hl)
	box.add_child(meter(net / 100.0, 0.0, DS.ACCENT, 6.0))
	if not Digital.has_id():
		var ib := AppButton.make("Launch a digital ID  ·  %d capital" % int(Economy.DGT_ID_CAPITAL), &"", "fingerprint")
		ib.disabled = not Capital.can(Economy.DGT_ID_CAPITAL)
		ib.pressed.connect(func() -> void:
			if Digital.launch_id():
				Simulation.update_finances(Game.me())
				Haptics.success()
			refresh())
		box.add_child(ib)
		note("One number for every citizen: taxes and benefits leak less, officials steal less. Some worry about privacy.", box)
	else:
		note("Every citizen has a digital ID: about %s more tax collected a year." % DS.money(c.gdp * Digital.revenue_pct() / 100.0), box)
	var et := AppToggle.new().setup("Public services online  ·  %s a year" % DS.money(c.gdp * Economy.DGT_EGOV_COST / 100.0), bool(s.egov), "monitor-smartphone")
	et.toggled.connect(func(on: bool) -> void:
		Digital.set_egov(on)
		Simulation.update_finances(Game.me())
		Haptics.select())
	box.add_child(et)
	var ct := AppToggle.new().setup("Cyber defence agency  ·  %s a year" % DS.money(c.gdp * Economy.DGT_CYBER_COST / 100.0), bool(s.cyber), "shield-check")
	ct.toggled.connect(func(on: bool) -> void:
		Digital.set_cyber(on)
		Simulation.update_finances(Game.me())
		Haptics.select())
	box.add_child(ct)
	note("The more you put online, the more hackers try their luck: about a %d%% chance of a major attack in the next three years." % roundi((1.0 - pow(1.0 - Digital.attack_chance(), 36.0)) * 100.0), box)
