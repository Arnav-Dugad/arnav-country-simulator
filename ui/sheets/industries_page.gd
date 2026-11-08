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
