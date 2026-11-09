class_name CountryPage
extends SheetPage
## Details for a tapped country: key stats, relation with you and diplomacy actions.

signal page_requested(page: String)

var country := -1
var _sub: Label
var _gov: Label
var _traits: HFlowContainer
var _leader_row: ListRow
var _tiles := {}
var _rel_box: VBoxContainer
var _rel_bar: Control
var _rel_label: Label
var _actions: VBoxContainer
var _status: Label
var _est: Label


func _init() -> void:
	super._init()
	title = "Country"
	open_at = BottomSheet.Snap.PEEK


func _build() -> void:
	_sub = Label.new()
	_sub.theme_type_variation = &"Subhead"
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	_gov = Label.new()
	_gov.theme_type_variation = &"Footnote"
	_gov.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_gov)
	_facts = GridContainer.new()
	_facts.columns = 2
	_facts.add_theme_constant_override(&"h_separation", DS.S3)
	_facts.add_theme_constant_override(&"v_separation", DS.S2)
	add_child(_facts)
	_leader_row = ListRow.new()
	add_child(_leader_row)
	_traits = HFlowContainer.new()
	_traits.add_theme_constant_override(&"h_separation", 6)
	_traits.add_theme_constant_override(&"v_separation", 6)
	add_child(_traits)
	var g := grid(self, 3)
	var money := func(v: float) -> String: return DS.money(v)
	_tiles.gdp = _tile(g, "GDP", money)
	_tiles.pc = _tile(g, "Per person", func(v: float) -> String: return DS.money(v, 0))
	_tiles.growth = _tile(g, "Growth", SheetPage.fmt_pct)
	_tiles.approval = _tile(g, "Support", SheetPage.fmt_pct)
	_tiles.stability = _tile(g, "Stability", func(v: float) -> String: return String.num(v, 0))
	_tiles.military = _tile(g, "Military", func(v: float) -> String: return String.num(v, 0))

	_rel_box = section("Relations with you")
	var rel_row := HBoxContainer.new()
	_rel_box.add_child(rel_row)
	_rel_label = Label.new()
	_rel_label.theme_type_variation = &"Headline"
	_rel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rel_row.add_child(_rel_label)
	_rel_bar = Control.new()
	_rel_bar.custom_minimum_size = Vector2(0, 10)
	_rel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rel_bar.draw.connect(_draw_rel_bar)
	_rel_box.add_child(_rel_bar)

	_actions = section("Diplomacy")
	_status = note("")
	_est = note("")
	_est.add_theme_color_override(&"font_color", DS.ORANGE)


var _facts: GridContainer


## Society & resources at a glance (real data, yours live): two columns of small facts.
func _fill_facts(i: int, show: bool) -> void:
	for ch in _facts.get_children():
		ch.queue_free()
	_facts.visible = show
	if not show:
		return
	var rk := Education.rank_of(i)
	var ws := Water.stress_of(i)
	var items: Array = [
		["school", "Test scores", "%d  ·  %s" % [roundi(Education.score_of(i)), Education.score_text(Education.score_of(i)).to_lower()]],
		["graduation-cap", "Best university", ("#%d in the world" % rk) if rk < 1000 else "outside top 1,000"],
		["droplets", "Water stress", "%s of 5  ·  %s" % [String.num(ws, 1), Water.label(ws).to_lower()]],
		["wheat", "Food grown at home", "%d%%" % roundi(Food.ss_of(i))],
	]
	var wh := Nuclear.warheads(i)
	if wh > 0:
		items.append(["atom", "Nuclear warheads", "about %d" % wh])
	var rm := Diaspora.rate_of(i)
	if absf(rm) >= 2.0:
		items.append(["plane-landing" if rm > 0.0 else "plane-takeoff", "Remittances", "%s of GDP %s" % [DS.pct(absf(rm), 0), "in" if rm > 0.0 else "out"]])
	for it in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ic := TextureRect.new()
		ic.texture = DS.icon(str(it[0]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(16, 16)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.modulate = DS.TEXT_3
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var t := Label.new()
		t.theme_type_variation = &"Caption"
		t.text = str(it[1])
		col.add_child(t)
		var v := Label.new()
		v.theme_type_variation = &"Footnote"
		v.text = str(it[2])
		v.clip_text = true
		v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.custom_minimum_size = Vector2(40, 0)
		col.add_child(v)
		_facts.add_child(row)


func _tile(parent: Control, t: String, fmt: Callable) -> StatTile:
	var tile := StatTile.new().setup(t, fmt, true)
	tile.delta_label.visible = false
	parent.add_child(tile)
	return tile


func show_country(i: int) -> void:
	country = i
	_status.text = ""
	refresh()


func refresh() -> void:
	if country < 0 or not Game.has_game():
		return
	var i := country
	title = World.map.names_long[i]
	var c: CountryState = Game.state(i)
	var sov := World.sovereign_of(i)
	var playable := World.is_playable(i)
	if c == null:
		_sub.text = "Uninhabited" if World.map.iso3[i] == "ATA" else "Territory"
	elif not playable and sov >= 0 and sov != i:
		_sub.text = "%s  ·  territory of %s" % [World.map.subregions[i], World.map.names[sov]]
	else:
		_sub.text = "%s  ·  %s people" % [World.map.subregions[i], DS.compact(c.population)]
	_leader_row.visible = playable and c != null
	if _leader_row.visible:
		if i == Game.player:
			var me_name := str(Settings.leader_name).strip_edges()
			_leader_row.setup(me_name if me_name != "" else "You", Government.leader_title(i), "")
			var pk := Leaders.player_portrait()
			_leader_row.set_leading(Photo.portrait(pk, 44.0, Color(DS.GOLD, 0.6)) if pk != "" else
				Avatar.make(me_name if me_name != "" else "?", Settings.PARTY_COLORS[clampi(Settings.party_color, 0, 5)], 44.0))
		else:
			var ld := Leaders.leader(i)
			var per: Dictionary = Leaders.PERSONALITIES[ld.personality]
			_leader_row.setup(str(ld.name), "%s  ·  %s" % [str(ld.title), str(per.desc)], str(per.label))
			_leader_row.trailing_label.add_theme_color_override(&"font_color", DS.ACCENT_SOFT)
			_leader_row.set_leading(Photo.portrait(str(ld.portrait), 44.0))
	_gov.visible = playable
	if playable:
		var lines: PackedStringArray = []
		if Profiles.tagline(i) != "":
			lines.append(Profiles.tagline(i) + ".")
		lines.append("%s  ·  led by the %s" % [Government.describe(i), Government.leader_title(i).to_lower()]
			if i != Game.player else "%s  ·  %s" % [Government.describe(i), Government.leader_display(i)])
		if not Profiles.exports(i).is_empty():
			lines.append("Sells: " + ", ".join(Profiles.exports(i)).to_lower())
		if Profiles.fact(i) != "":
			lines.append(Profiles.fact(i))
		var st: CountryState = Game.state(i)
		if st != null:
			lines.append("Emits %s t of CO₂ a person  ·  %d%% renewable energy" % [String.num(Climate.co2_pc(st), 1),
				roundi(Climate.renewables(st))])
			lines.append(Migration.describe(st))
			lines.append("Clean government: %d/100 (%s)" % [roundi(Corruption.value(st)), Corruption.label(Corruption.value(st))])
			lines.append("Life expectancy %s years  ·  %d%% can read" % [String.num(Outcomes.life(st), 1), roundi(Outcomes.literacy(st))])
			lines.append("Inequality: Gini %s (%s)  ·  %s%% aged 65+" % [String.num(st.gini, 1), Inequality.label(st.gini),
				String.num(Ageing.share(st), 1)])
		_gov.text = "\n".join(lines)
	_fill_facts(i, playable and Game.state(i) != null)
	for ch in _traits.get_children():
		ch.queue_free()
	if playable:
		for chip in Profiles.trait_chips(i):
			var pc := PanelContainer.new()
			pc.theme_type_variation = &"ForecastChip"
			var lc := Label.new()
			lc.theme_type_variation = &"ChipValue"
			lc.add_theme_font_size_override(&"font_size", 12)
			lc.add_theme_color_override(&"font_color", DS.GREEN if chip[1] else DS.ORANGE)
			lc.text = str(chip[0])
			pc.add_child(lc)
			_traits.add_child(pc)
		for t in World.traits(i).filter(func(x: String) -> bool: return x in ["Landlocked", "Island nation", "Ageing population", "Very young population"]):
			var p := PanelContainer.new()
			p.theme_type_variation = &"ForecastChip"
			var l := Label.new()
			l.theme_type_variation = &"ChipValue"
			l.add_theme_font_size_override(&"font_size", 12)
			l.add_theme_color_override(&"font_color", DS.TEXT_2)
			l.text = t
			p.add_child(l)
			_traits.add_child(p)
	for t in _tiles.values():
		t.visible = c != null
	if c:
		_tiles.gdp.show_value(c.gdp)
		_tiles.pc.show_value(c.gdp_per_capita())
		_tiles.growth.show_value(c.growth)
		_tiles.approval.show_value(c.approval)
		_tiles.stability.show_value(c.stability)
		_tiles.military.show_value(c.military)
	var est: Array = World.stats[i].get("estimated", [])
	_est.visible = not est.is_empty()
	_est.text = "Estimated starting data: %s (regional averages)." % ", ".join(est.map(
		func(k: String) -> String: return k.replace("_pct", "").replace("_", " ")))
	var is_me := i == Game.player
	_rel_box.get_parent().get_parent().visible = playable and not is_me
	_rel_label.text = "%s  %+.0f" % [Diplomacy.relation_text(Game.relations[i]), Game.relations[i]]
	_rel_label.add_theme_color_override(&"font_color", Diplomacy.relation_color(Game.relations[i]))
	_rel_bar.queue_redraw()
	_build_actions(i, is_me, playable)


func _build_actions(i: int, is_me: bool, playable: bool) -> void:
	for ch in _actions.get_children():
		ch.queue_free()
	_actions.get_parent().get_parent().visible = playable
	if is_me:
		var h := Label.new()
		h.theme_type_variation = &"Body"
		h.text = "This is your nation. Shape it from Economy and Budget, build in Build, reform in Laws."
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_actions.add_child(h)
		var row := HBoxContainer.new()
		_actions.add_child(row)
		for p in [["Economy", "economy", "chart"], ["Build", "build", "hammer"]]:
			var b := AppButton.make(p[0], &"", p[2])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void: page_requested.emit(p[1]))
			row.add_child(b)
		return
	if not playable:
		return
	_action("Compare with you", &"", "scale", _compare.bind(i))
	var wait := Leaders.call_wait(i)
	var ld := Leaders.leader(i)
	_action("Call %s" % str(ld.name).split(" ")[0], &"", "message-circle", _call.bind(i), wait > 0,
		"You can call again in %d months" % wait if wait > 0 else "Leaders react to tone by personality")
	var vwait := Visits.wait()
	_action("Visit %s" % World.the_name(i), &"", "plane-takeoff", _visit.bind(i), vwait > 0,
		"One state visit a year · next in %d months" % vwait if vwait > 0 else "Fly over and meet %s" % str(ld.name).split(" ")[0])
	# Trade
	if Diplomacy.has_deal(i):
		_action("Cancel trade deal", &"", "x", func() -> void:
			Diplomacy.cancel_deal(i)
			_done("Trade deal cancelled.", false))
	else:
		var ok := Diplomacy.can_propose_deal(i)
		_action("Propose trade deal", &"PrimaryButton" if ok else &"", "handshake", func() -> void:
			var acc := Diplomacy.propose_deal(i)
			if acc:
				var gs := get_tree().current_scene
				if gs and gs.has_method("learned"):
					gs.learned("deal")
			_done("%s signed the deal." % World.map.names[i] if acc else "%s declined." % World.map.names[i], acc),
			not ok, "Needs relations of %d+" % int(Diplomacy.DEAL_MIN_RELATION) if not ok
				else "Likely to accept: %d%%" % int(Diplomacy.acceptance(i, "deal") * 100.0))
	# Alliance
	if Diplomacy.has_alliance(i):
		_action("Leave alliance", &"", "log-out", func() -> void:
			Diplomacy.break_alliance(i)
			_done("Alliance ended.", false))
	else:
		var ok2 := Diplomacy.can_propose_alliance(i)
		_action("Propose alliance", &"", "shield", func() -> void:
			var acc := Diplomacy.propose_alliance(i)
			_done("Alliance formed with %s." % World.map.names[i] if acc else "%s declined." % World.map.names[i], acc),
			not ok2, "Needs relations of %d+" % int(Diplomacy.ALLIANCE_MIN_RELATION) if not ok2
				else "Likely to accept: %d%%" % int(Diplomacy.acceptance(i, "alliance") * 100.0))
	# Aid
	var cd := Diplomacy.aid_cooldown(i)
	_action("Send aid  ·  %s" % DS.money(Diplomacy.aid_amount()), &"", "hand-coins", func() -> void:
		var gain := Diplomacy.send_aid(i)
		_done("Aid delivered. Relations %+.0f." % gain, true),
		not Diplomacy.can_send_aid(i), "Available again in %d months" % cd if cd > 0 else "Paid from the treasury")
	# War
	if War.is_at_war_with(i):
		_action("Open the war room", &"DestructiveButton", "swords", func() -> void:
			WarRoom.open(get_tree().current_scene, i))
	else:
		var wb := War.blocked(i)
		_action("Declare war", &"DestructiveButton", "swords", _declare_war.bind(i), wb != "",
			wb if wb != "" else "Battle odds %d%% · costs %d political capital" % [roundi(War.odds(i) * 100.0), int(Economy.WAR_DECLARE_CAPITAL)])
	# Peaceful union (friendly, smaller neighbours)
	if War.is_neighbour(i) and not War.is_at_war_with(i):
		var ub := Annexation.union_blocked(i)
		if ub == "" or Game.relations[i] >= 50.0 or Annexation.is_vassal(i):
			_action("Propose a union", &"", "handshake", _union.bind(i), ub != "",
				ub if ub != "" else "They vote on joining you: about %d%% chance" % roundi(Annexation.union_chance(i) * 100.0))
	# Covert operations
	var run := Intel.running_against(i)
	_action("Covert operations", &"", "eye", _covert.bind(i), not run.is_empty(),
		("Under way: %s, %d months left" % [str(Intel.OPS[str(run.op)].title).to_lower(), Intel.months_left(run)]) if not run.is_empty()
		else "Spy, steal technology, sabotage or meddle")
	# Tariffs (trade war)
	if Tariffs.has(i):
		_action("Lift tariffs", &"", "check", func() -> void:
			Tariffs.lift(i)
			_done("Tariffs lifted. Trade flows again.", true),
			false, "Prices calm down" + (", and they drop theirs" if Tariffs.retaliating(i) else ""))
	else:
		_action("Put tariffs on their goods  ·  %d" % int(Economy.CAPITAL_TARIFF), &"", "ban", func() -> void:
			if not Capital.spend(Economy.CAPITAL_TARIFF):
				return
			var back := Tariffs.impose(i)
			_done("Tariffs imposed. %s" % ("They hit back with their own." if back else "They chose not to retaliate."), not back),
			not Capital.can(Economy.CAPITAL_TARIFF), "Prices rise · %d%% chance they hit back" % roundi(Tariffs.retaliation_chance(i) * 100.0))
	# Sanctions
	if Diplomacy.is_sanctioning(i):
		_action("Lift sanctions", &"", "check", func() -> void:
			Diplomacy.lift_sanction(i)
			_done("Sanctions lifted.", true))
	else:
		_action("Impose sanctions", &"DestructiveButton", "ban", func() -> void:
			Diplomacy.sanction(i)
			_done("Sanctions imposed on %s." % World.map.names[i], false),
			false, "Hurts their economy, and yours a little")


## A phone call with another leader: pick a tone; their personality decides.
func _call(i: int) -> void:
	var ld := Leaders.leader(i)
	var per: Dictionary = Leaders.PERSONALITIES[ld.personality]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	var holder := CenterContainer.new()
	holder.add_child(Photo.portrait(str(ld.portrait), 120.0, Color(DS.ACCENT, 0.6)))
	m.content.add_child(holder)
	m.header("message-circle", DS.ACCENT, "%s of %s" % [str(ld.title), World.map.names[i]], str(ld.name))
	m.body("%s: %s. What do you want from this call?" % [str(per.label), str(per.desc).to_lower()])
	for tone in ["warm", "firm", "ask"]:
		var info: Dictionary = Leaders.CALLS[tone]
		m.choice(str(info.label), str(info.desc), &"PrimaryButton" if tone == "warm" else &"", func() -> void:
			var r := Leaders.make_call(i, tone)
			if float(r.relation) >= 0.0:
				Haptics.success()
			else:
				Haptics.warning()
			m.dismiss()
			_status.text = str(r.line)
			_status.add_theme_color_override(&"font_color", DS.GREEN if float(r.relation) >= 0.0 else DS.ORANGE)
			Game.add_feed("Call with %s: %s" % [str(ld.name), str(r.line)], "message-circle", "green" if float(r.relation) >= 0.0 else "orange")
			refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _declare_war(i: int) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.content.add_child(Illustration.banner("war", "swords", DS.RED, 104.0))
	m.header("swords", DS.RED, "Declare war", "War with %s?" % World.map.names[i])
	var them: CountryState = Game.state(i)
	m.body("Your military %d vs theirs %d. You'd win about %d%% of battles at the start. War costs about %s a year, slows the economy and wears people down after the first months. The world will condemn the attack." % [
		roundi(Game.me().military), roundi(them.military), roundi(War.odds(i) * 100.0),
		DS.money(Game.me().gdp * Economy.WAR_COST_PCT / 100.0 * sqrt(clampf(them.gdp / maxf(Game.me().gdp, 1.0), 0.3, 2.5)))])
	var ov := Label.new()
	ov.theme_type_variation = &"Overline"
	ov.text = "CHOOSE YOUR WAR GOAL  ·  %d POLITICAL CAPITAL" % int(Economy.WAR_DECLARE_CAPITAL)
	m.content.add_child(ov)
	for gid in War.GOALS:
		var g: Dictionary = War.GOALS[gid]
		var chips: Array = [["Take up to %d%%" % roundi(float(g.max_occ) * 100.0), DS.TEXT_2],
			["World anger ×%s" % String.num(float(g.anger), 1), DS.RED if float(g.anger) > 1.0 else DS.ORANGE]]
		if gid == "total":
			chips.append(["Annex the whole country", DS.GOLD])
		m.choice(str(g.title), str(g.desc), &"DestructiveButton" if gid == "total" else &"", func() -> void:
			War.declare(i, str(gid))
			Haptics.warning()
			Audio.play("warning")
			m.dismiss()
			refresh()
			var gs := get_tree().current_scene
			if gs and "map" in gs and gs.map != null:
				gs.map.refresh_war_marks()
			WarRoom.open(get_tree().current_scene, i), chips)
	m.choice("Not now", "", &"GhostButton", m.dismiss)


## A state visit: pick what the trip is about; their personality decides.
func _visit(i: int) -> void:
	var ld := Leaders.leader(i)
	var per: Dictionary = Leaders.PERSONALITIES[ld.personality]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	var holder := CenterContainer.new()
	holder.add_child(Photo.portrait(str(ld.portrait), 120.0, Color(DS.GOLD, 0.6)))
	m.content.add_child(holder)
	m.header("plane-takeoff", DS.GOLD, "State visit to %s" % World.map.names[i], str(ld.name))
	var warn := " Your people distrust %s: expect criticism at home." % World.the_name(i) if Game.relations[i] < -20.0 else ""
	m.body("%s: %s. What is the trip about?%s" % [str(per.label), str(per.desc).to_lower(), warn])
	for agenda in ["trade", "security", "culture"]:
		var info: Dictionary = Visits.AGENDAS[agenda]
		m.choice(str(info.label), str(info.desc), &"", func() -> void:
			var r := Visits.visit(i, agenda)
			if float(r.taste) >= 1.0:
				Haptics.success()
			else:
				Haptics.select()
			m.dismiss()
			var gs := get_tree().current_scene
			if gs and "map" in gs and gs.map != null:
				if "sheet" in gs and gs.sheet != null:
					gs.sheet.snap_to(BottomSheet.Snap.PEEK)     # step aside so the flight shows
				gs.map.show_flight(Game.player, i)
			_status.text = str(r.line)
			_status.add_theme_color_override(&"font_color", DS.GREEN if float(r.taste) >= 1.0 else DS.ORANGE)
			Game.add_feed("State visit to %s: %s" % [World.map.names[i], str(r.line)], "plane-takeoff",
				"green" if float(r.taste) >= 1.0 else "orange")
			Game.feed[0]["face"] = str(ld.portrait)
			refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


## Side by side: you and another country.
func _compare(i: int) -> void:
	var me := Game.me()
	var them: CountryState = Game.state(i)
	if them == null:
		return
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("scale", DS.ACCENT, "Compare", "%s vs %s" % [World.map.names[Game.player], World.map.names[i]])
	var rows := [
		["GDP", me.gdp, them.gdp, true, func(v: float) -> String: return DS.money(v)],
		["Per person", me.gdp_per_capita(), them.gdp_per_capita(), true, func(v: float) -> String: return DS.money(v, 0)],
		["Growth", me.growth, them.growth, true, func(v: float) -> String: return DS.pct(v)],
		["Inflation", me.inflation, them.inflation, false, func(v: float) -> String: return DS.pct(v)],
		["Jobless", me.unemployment, them.unemployment, false, func(v: float) -> String: return DS.pct(v)],
		["Debt", me.debt_pct(), them.debt_pct(), false, func(v: float) -> String: return DS.pct(v, 0)],
		["Happiness", me.happiness, them.happiness, true, func(v: float) -> String: return String.num(v, 0)],
		["Stability", me.stability, them.stability, true, func(v: float) -> String: return String.num(v, 0)],
		["Military", me.military, them.military, true, func(v: float) -> String: return String.num(v, 0)],
		["CO₂ a person", Climate.co2_pc(me), Climate.co2_pc(them), false, func(v: float) -> String: return "%s t" % String.num(v, 1)],
		["People", me.population, them.population, true, func(v: float) -> String: return DS.compact(v)],
		["Test scores", Education.score_of(Game.player), Education.score_of(i), true, func(v: float) -> String: return str(roundi(v))],
		["Top university", float(Education.rank_of(Game.player)), float(Education.rank_of(i)), false, func(v: float) -> String: return "#%d" % roundi(v) if v < 1000.0 else "1000+"],
		["Water stress", Water.stress_of(Game.player), Water.stress_of(i), false, func(v: float) -> String: return String.num(v, 1)],
		["Air (PM2.5)", Air.pm_of(Game.player), Air.pm_of(i), false, func(v: float) -> String: return "%d µg" % roundi(v)],
	]
	var head := HBoxContainer.new()
	m.content.add_child(head)
	for t in ["", "You", World.map.names[i]]:
		var l := Label.new()
		l.theme_type_variation = &"Overline"
		l.text = t.to_upper()
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if t != "" else HORIZONTAL_ALIGNMENT_LEFT
		l.clip_text = true
		head.add_child(l)
	for r in rows:
		var line := HBoxContainer.new()
		m.content.add_child(line)
		var a := float(r[1])
		var b := float(r[2])
		var mine_better: bool = (a > b) == bool(r[3]) and absf(a - b) > absf(b) * 0.01
		var theirs_better: bool = (b > a) == bool(r[3]) and absf(a - b) > absf(a) * 0.01
		for k in 3:
			var l := Label.new()
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if k == 0:
				l.theme_type_variation = &"Body"
				l.text = str(r[0])
			else:
				l.theme_type_variation = &"StatSmall"
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				l.text = r[4].call(a if k == 1 else b)
				var better := mine_better if k == 1 else theirs_better
				l.add_theme_color_override(&"font_color", DS.GREEN if better else DS.TEXT)
			line.add_child(l)
	m.body("%s  ·  %s" % [Government.system_name(Game.player), Government.system_name(i)])
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _action(text: String, variant: StringName, icon_: String, cb: Callable, disabled: bool = false,
		hint: String = "") -> void:
	var b := AppButton.make(text, variant, icon_)
	b.disabled = disabled
	b.pressed.connect(cb)
	_actions.add_child(b)
	if hint != "":
		var l := Label.new()
		l.theme_type_variation = &"Caption"
		l.text = hint
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(60, 0)
		_actions.add_child(l)


func _done(msg: String, good: bool) -> void:
	if good:
		Haptics.success()
	else:
		Haptics.warning()
	refresh()
	_status.text = msg
	_status.add_theme_color_override(&"font_color", DS.GREEN if good else DS.TEXT_2)


func _draw_rel_bar() -> void:
	var w := _rel_bar.size.x
	var h := _rel_bar.size.y
	var track := get_theme_stylebox(&"track", &"AppSlider")
	_rel_bar.draw_style_box(track, Rect2(0, h * 0.5 - 3, w, 6))
	var r := Game.relations[country] if country >= 0 else 0.0
	var mid := w * 0.5
	var x := mid + w * 0.5 * r / 100.0
	var col := Diplomacy.relation_color(r)
	_rel_bar.draw_rect(Rect2(minf(mid, x), h * 0.5 - 3, absf(x - mid), 6), col)
	_rel_bar.draw_rect(Rect2(mid - 1, 0, 2, h), Color(1, 1, 1, 0.3))
	_rel_bar.draw_circle(Vector2(x, h * 0.5), 5.0, col, true, -1.0, true)


# ------------------------------------------------------------------- intel ---
func _covert(i: int) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("eye", DS.PURPLE, "Covert operations", World.map.names[i])
	m.body("Your agency %d vs their counter-intelligence %d. Exposure means expelled diplomats, angry neighbours and headlines at home." % [
		roundi(Intel.strength(Game.player)), roundi(Intel.strength(i))])
	for op in Intel.OPS:
		var info: Dictionary = Intel.OPS[op]
		var why := Intel.can_launch(str(op), i)
		var chips: Array = []
		if why == "":
			chips = [["Success %d%%" % roundi(Intel.success_chance(str(op), i) * 100.0), DS.GREEN],
				["Exposure %d%%" % roundi(Intel.exposure_chance(str(op), i) * 100.0), DS.RED],
				["%d months" % int(info.months), DS.TEXT_2]]
		var ch := m.choice(str(info.title), why if why != "" else str(info.desc), &"GhostButton", func() -> void:
			if Intel.launch(str(op), i):
				Haptics.success()
				_done("Operation under way: %s." % str(info.title).to_lower(), true)
			m.dismiss(), chips)
		if why != "":
			for b in ch.find_children("*", "Button", true, false):
				(b as Button).disabled = true
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _union(i: int) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("handshake", DS.GOLD, "Peaceful union", "Unite with %s?" % World.map.names[i])
	m.body("%s holds a referendum on joining %s. If they vote yes, the two countries become one: no war, little unrest, and the world shrugs. If no, relations cool." % [
		World.The_name(i), World.the_name(Game.player)])
	m.choice("Propose the union", "Chance of a yes: %d%%  ·  %d political capital" % [roundi(Annexation.union_chance(i) * 100.0), int(Economy.UNION_CAPITAL)],
		&"PrimaryButton", func() -> void:
			var r := Annexation.propose_union(i)
			m.dismiss()
			var gs := get_tree().current_scene
			if gs and gs.has_method("_notify"):
				gs._notify(str(r.text), "handshake", DS.GOLD if bool(r.ok) else DS.ORANGE, true)
				if bool(r.ok) and "map" in gs and gs.map != null:
					gs.map.celebrate("fireworks", Game.player)
					gs.map.focus_country(Game.player)
			if bool(r.ok):
				Haptics.success()
				Audio.play("fanfare", -5.0)
			else:
				Haptics.warning())
	m.choice("Not now", "", &"GhostButton", m.dismiss)
