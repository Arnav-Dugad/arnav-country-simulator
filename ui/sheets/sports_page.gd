class_name SportsPage
extends SheetPage
## Sport: your national teams, the calendar, the last tournament (bracket or
## medal table), funding, academy focus, doping policy and the trophy cabinet.

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "Sport"


func _build() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


func refresh() -> void:
	if Game.me() == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	var s := Sports.st()
	var up := Sports.upcoming()
	var nxt := "Next: %s in %d months" % [str(up[0][0]), int(up[0][1])] if not up.is_empty() else ""
	if not up.is_empty() and int(up[0][1]) == 0:
		nxt = "%s: this month!" % str(up[0][0])
	_box.add_child(photo_header("games" if Photo.has_scene("games") else "stadium", "Sport", "%s  ·  %d %s in the cabinet" % [
		nxt, (s.cabinet as Array).size(), "trophy" if (s.cabinet as Array).size() == 1 else "trophies"], 150.0))
	_live()
	_teams()
	_calendar(up)
	_last()
	_programme()
	_cabinet()


func _live() -> void:
	var cup: Dictionary = Sports.st().cup
	if cup.is_empty():
		return
	var box := section("Live: %s %d" % [str(cup.title), int(cup.year)], _box)
	var alive: Array = cup.alive
	var me_alive := alive.has(Game.player)
	var r := ListRow.new().setup(("Still in it!" if me_alive else ("Out in the %s" % str(cup.me_out).to_lower() if str(cup.me_out) != "" else "Not qualified")),
		"%d teams left: %s" % [alive.size(), ", ".join(PackedStringArray(alive.slice(0, 8).map(func(j: int) -> String: return World.map.names[j])))])
	r.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	r.set_leading(ListRow.icon_tile("trophy", DS.GOLD if me_alive else DS.TEXT_3))
	box.add_child(r)
	_rounds(cup.rounds, box)


func _teams() -> void:
	var box := section("Your national teams", _box)
	var c := Game.me()
	var ids: Array = []
	for sp in Sports.SPORTS:
		if Sports.base(Game.player, str(sp)) > 0.0:
			ids.append(str(sp))
	ids.sort_custom(func(a: String, b: String) -> bool: return Sports.rank(a) < Sports.rank(b))
	for sp in ids:
		var info: Dictionary = Sports.SPORTS[sp]
		var rk := Sports.rank(sp)
		var strn := Sports.strength(Game.player, sp)
		var col := DS.GOLD if rk <= 3 else (DS.GREEN if rk <= 10 else (DS.ACCENT if rk <= 30 else DS.TEXT_3))
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", 4)
		box.add_child(v)
		var row := ListRow.new().setup(str(info.title), ("Academy focus  ·  " if str(Sports.st().focus) == sp else "") + "strength %d" % roundi(strn),
			"#%d" % rk, "in the world")
		row.trailing_label.add_theme_color_override(&"font_color", col)
		row.set_leading(ListRow.icon_tile(str(info.icon), col))
		row.tapped.connect(_focus_card.bind(sp))
		v.add_child(row)
		v.add_child(meter(clampf((strn - 20.0) / 80.0, 0.0, 1.0), 0.0, col, 3.0))
	note("Tap a sport to make it your academy focus. Stadiums and sports centres (Build tab) strengthen every team.", box)


func _focus_card(sp: String) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(Sports.SPORTS[sp].icon), DS.GOLD, "Academy focus", str(Sports.SPORTS[sp].title))
	if str(Sports.st().focus) == sp:
		m.body("Your academies already focus on %s." % str(Sports.SPORTS[sp].title).to_lower())
	else:
		m.body("Pour coaching, scouting and science into %s: up to +%d strength over four years. Costs %s a year. Only one sport can be the focus." % [
			str(Sports.SPORTS[sp].title).to_lower(), int(Economy.SPORT_FOCUS), DS.money(Game.me().gdp * Economy.SPORT_FOCUS_COST / 100.0)])
		m.choice("Make it the focus", "", &"PrimaryButton", func() -> void:
			Sports.set_focus(sp)
			Simulation.update_finances(Game.me())
			Haptics.success()
			m.dismiss()
			refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _calendar(up: Array) -> void:
	var box := section("Coming up", _box)
	for ev in up:
		var mo := int(ev[1])
		var row := ListRow.new().setup(str(ev[0]), "This month" if mo == 0 else ("In %d %s" % [mo, "month" if mo == 1 else "months"]))
		row.set_leading(ListRow.icon_tile(str(ev[2]), DS.GOLD if mo <= 3 else DS.ACCENT))
		box.add_child(row)


func _last() -> void:
	var last: Array = Sports.st().last
	if last.is_empty():
		return
	var e: Dictionary = last[0]
	var box := section("Last: %s" % str(e.title), _box)
	if e.has("table"):
		var mine := int(e.mine)
		note(("You won %d %s, %s in the table." % [mine, "medal" if mine == 1 else "medals", Sports._ordinal(int(e.place))]) if mine > 0 else "No medals for you this time.", box)
		var k := 0
		for row in e.table:
			k += 1
			var j := int(row[0])
			var r := ListRow.new().setup("%d. %s" % [k, World.map.names[j]], "", str(int(row[1])), "medals")
			r.set_leading(Flag.new().show_country(j, 22.0))
			if j == Game.player:
				r.trailing_label.add_theme_color_override(&"font_color", DS.GOLD)
			box.add_child(r)
	else:
		var champ := int(e.champ)
		var r2 := ListRow.new().setup("Champions: %s" % World.map.names[champ], ("You went out in the %s" % str(e.me_out).to_lower()) if str(e.me_out) != "" else ("That's you!" if champ == Game.player else ""))
		r2.set_leading(Flag.new().show_country(champ, 22.0))
		box.add_child(r2)
		_rounds((e.rounds as Array).slice(-3), box)


## The last rounds of a knockout, like a bracket: winner first.
func _rounds(rounds: Array, box: Control) -> void:
	for rd in rounds:
		var res: Array = rd.results
		if res.size() > 8:
			continue
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = str(rd.name).to_upper()
		box.add_child(h)
		for m in res:
			var w := int(m.w)
			var l := int(m.l)
			var line := HBoxContainer.new()
			line.add_theme_constant_override(&"separation", DS.S2)
			box.add_child(line)
			line.add_child(Flag.new().show_country(w, 16.0))
			var t := Label.new()
			t.theme_type_variation = &"Footnote"
			t.text = "%s  %s  %s" % [World.map.names[w], str(m.score) if str(m.score) != "" else "beat", World.map.names[l]]
			t.clip_text = true
			t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t.custom_minimum_size = Vector2(40, 0)
			if w == Game.player or l == Game.player:
				t.add_theme_color_override(&"font_color", DS.GREEN if w == Game.player else DS.RED)
			line.add_child(t)


func _programme() -> void:
	var s := Sports.st()
	var box := section("Sports programme", _box)
	var seg := SegmentedControl.new().setup(PackedStringArray(Sports.FUNDING), [], int(s.funding))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Sports.set_funding(k)
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	box.add_child(seg)
	note("Funding: %s a year. Up to +%d strength in every sport, building up over three years." % [
		DS.money(Game.me().gdp * float(Sports.FUNDING_COST[int(s.funding)]) / 100.0), int(Sports.FUNDING_BOOST[int(s.funding)])], box)
	var tg := AppToggle.new().setup("Look the other way on doping", bool(s.doping), "syringe")
	tg.toggled.connect(func(on: bool) -> void:
		s.doping = on
		Haptics.select())
	box.add_child(tg)
	note("+%d strength everywhere, but each Games carries a %d%% chance of a scandal that strips medals and shames the nation." % [
		int(Economy.SPORT_DOPING), roundi(Economy.SPORT_DOPING_RISK * 100.0)], box)


func _cabinet() -> void:
	var cab: Array = Sports.st().cabinet
	var box := section("Trophy cabinet", _box)
	if cab.is_empty():
		note("Empty for now. Win a World Cup or top a medal table to fill it.", box)
		return
	for t in cab:
		var r := ListRow.new().setup(str(t.title), str(int(t.year)))
		r.set_leading(ListRow.icon_tile(str(t.icon), DS.GOLD))
		box.add_child(r)
	var hist: Array = Sports.st().medals_hist
	if not hist.is_empty():
		var tot := 0
		for h in hist:
			tot += int(h.medals)
		note("%d Games medals in total." % tot, box)
