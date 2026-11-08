class_name DiplomacyPage
extends SheetPage
## Relations overview: allies, partners and rivals. Tap a country to open it.

signal country_requested(index: int)
signal page_requested(page: String)

var _summary: Label
var _ranks: GridContainer
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0


func _init() -> void:
	super._init()
	title = "World"


func _build() -> void:
	add_child(Illustration.banner("summit", "globe", DS.TEAL, 124.0))
	var rank_head := Label.new()
	rank_head.theme_type_variation = &"Overline"
	rank_head.text = "YOUR WORLD RANK"
	add_child(rank_head)
	_ranks = grid(self, 2)
	hub([
		["tourism", "plane-takeoff", DS.TEAL, "Tourism & fame", "Visitors, heritage, host the Games", func() -> void: page_requested.emit("tourism")],
		["intel", "eye", DS.PURPLE, "Intelligence", "Your spies and their operations", func() -> void: _scroll_to(_intel)],
	], self)
	_rival = section("Your rival")
	_markets = section("World markets")
	_war = section("At war")
	_wwars = section("Wars around the world")
	_empire = section("Your empire")
	_security = section("Security")
	_intel = section("Intelligence")
	_climate = section("Climate")
	_adapt = section("Climate adaptation")
	_treaties = section("Treaties & blocs")
	_summary = note("")
	_filter = SegmentedControl.new().setup(["Friends", "Rivals", "Neighbours", "Partners"], [], 0)
	_filter.plain = true
	_filter.compact = false
	_filter.fill = true
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.changed.connect(func(i: int) -> void:
		_mode = i
		refresh())
	add_child(_filter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	add_child(_list)


var _markets: VBoxContainer
var _climate: VBoxContainer
var _adapt: VBoxContainer
var _security: VBoxContainer
var _empire: VBoxContainer
var _intel: VBoxContainer
var _war: VBoxContainer
var _wwars: VBoxContainer
var _rival: VBoxContainer
var _treaties: VBoxContainer


func refresh() -> void:
	if not Game.has_game():
		return
	_fill_ranks()
	_fill_rival()
	_fill_markets()
	_fill_climate()
	_fill_adapt()
	_fill_empire()
	_fill_security()
	_fill_intel()
	_fill_war()
	_fill_world_wars()
	_fill_treaties()
	var d := Diplomacy.summary()
	var parts: PackedStringArray = ["%d %s" % [d.alliances, "ally" if d.alliances == 1 else "allies"],
		"%d trade %s" % [d.deals, "deal" if d.deals == 1 else "deals"]]
	if int(d.sanctioned_by) > 0:
		parts.append("%d %s on you" % [d.sanctioned_by, "sanction" if d.sanctioned_by == 1 else "sanctions"])
	if float(d.aid_total) > 0.0:
		parts.append("aid sent %s" % DS.money(d.aid_total))
	_summary.text = "  ·  ".join(parts) + ". Tap a country to talk trade, alliances or aid."
	for ch in _list.get_children():
		ch.queue_free()
	var idx: Array[int] = []
	var neigh := World.neighbours_of(Game.player)
	for i in World.playable:
		if i == Game.player:
			continue
		match _mode:
			0:
				if Game.relations[i] >= 25.0:
					idx.append(i)
			1:
				if Game.relations[i] <= -15.0:
					idx.append(i)
			2:
				if i in neigh:
					idx.append(i)
			3:
				if Diplomacy.has_deal(i) or Diplomacy.has_alliance(i):
					idx.append(i)
	var asc := _mode == 1
	idx.sort_custom(func(a: int, b: int) -> bool:
		return Game.relations[a] < Game.relations[b] if asc else Game.relations[a] > Game.relations[b])
	for i in idx.slice(0, 40):
		var row := ListRow.new().setup(World.map.names[i], Diplomacy.status_text(i),
			Diplomacy.relation_text(Game.relations[i]), "%+.0f" % Game.relations[i])
		row.trailing_label.add_theme_color_override(&"font_color", Diplomacy.relation_color(Game.relations[i]))
		row.set_leading(Flag.new().show_country(i, 22.0))
		row.tapped.connect(func() -> void: country_requested.emit(i))
		_list.add_child(row)
	if idx.is_empty():
		note("Nobody here yet.", _list)


func _fill_rival() -> void:
	for ch in _rival.get_children():
		ch.queue_free()
	var r := Rivalry.rival()
	if r < 0:
		return
	var ld := Leaders.leader(r)
	var head := ListRow.new().setup(World.map.names[r], "%s %s  ·  %s" % [str(ld.title), str(ld.name),
		Diplomacy.relation_text(Game.relations[r])])
	head.set_leading(Flag.new().show_country(r, 26.0))
	head.tapped.connect(func() -> void: country_requested.emit(r))
	_rival.add_child(head)
	var wins := 0
	for race in Rivalry.RACES:
		var a := Rivalry.value(Game.player, str(race[0]))
		var b := Rivalry.value(r, str(race[0]))
		var me_ahead := a > b
		wins += 1 if me_ahead else 0
		var row := HBoxContainer.new()
		_rival.add_child(row)
		var l := Label.new()
		l.theme_type_variation = &"Body"
		l.text = str(race[1])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.custom_minimum_size = Vector2(20, 0)
		row.add_child(l)
		var v := Label.new()
		v.theme_type_variation = &"StatSmall"
		v.text = "%s  vs  %s" % [Rivalry.fmt(str(race[2]), a), Rivalry.fmt(str(race[2]), b)]
		v.add_theme_color_override(&"font_color", DS.GREEN if me_ahead else DS.ORANGE)
		row.add_child(v)
	note("You lead in %d of %d. Tap them to talk." % [wins, Rivalry.RACES.size()], _rival)


func _fill_markets() -> void:
	for ch in _markets.get_children():
		ch.queue_free()
	var m := Game.markets
	var rows := [["Oil", "flame", "$%d a barrel" % roundi(m.oil_price()), m.oil_gap(), m.oil_hist, DS.ORANGE],
		["Food", "tractor", "Index %d" % roundi(m.food_index()), m.food_gap(), m.food_hist, DS.GREEN]]
	for r in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", DS.S3)
		_markets.add_child(line)
		line.add_child(ListRow.icon_tile(str(r[1]), r[5]))
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(col)
		var t := Label.new()
		t.theme_type_variation = &"Headline"
		t.text = "%s  %s" % [r[0], r[2]]
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.custom_minimum_size = Vector2(20, 0)
		col.add_child(t)
		var gap := float(r[3])
		var sub := Label.new()
		sub.theme_type_variation = &"Caption"
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sub.custom_minimum_size = Vector2(20, 0)
		sub.text = "Normal" if absf(gap) < 0.05 else ("%d%% above normal" % roundi(gap * 100.0) if gap > 0 else "%d%% below normal" % roundi(-gap * 100.0))
		col.add_child(sub)
		var ch := LineChart.new()
		ch.custom_minimum_size = Vector2(72, 40)
		ch.line_width = 1.8
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.minimal = true
		ch.set_color(r[5])
		line.add_child(ch)
		ch.set_data(r[4])
	var ox := WorldMarkets.oil_exposure(Game.player)
	var how := "You export oil: high prices fill your treasury." if ox > 0.1 else (
		"You import energy: high oil prices raise your prices and slow growth." if ox < -0.1 else "Oil prices barely touch your economy.")
	var shield := 1.0 - Climate.oil_shield(Game.me())
	if ox < -0.05 and shield >= 0.01:
		how += " Your clean energy softens that by %d%%." % roundi(shield * 100.0)
	if WorldMarkets.food_exposure(Game.player) > 0.5:
		how += " Food price spikes hit your people hard."
	var wc := Game.markets.world_cycle
	how += " The world economy is %s." % ("booming" if wc > 0.6 else ("slowing" if wc < -0.6 else "steady"))
	note(how, _markets)


## A line with an icon tile, a headline, a caption and an optional sparkline.
func _stat_line(parent: Control, icon: String, color: Color, head: String, caption: String,
		data: PackedFloat32Array = PackedFloat32Array()) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", DS.S3)
	parent.add_child(line)
	line.add_child(ListRow.icon_tile(icon, color))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(col)
	for k in 2:
		var l := Label.new()
		l.theme_type_variation = &"Headline" if k == 0 else &"Caption"
		l.text = head if k == 0 else caption
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size = Vector2(20, 0)
		col.add_child(l)
	if data.size() >= 2:
		var ch := LineChart.new()
		ch.custom_minimum_size = Vector2(72, 40)
		ch.line_width = 1.8
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.minimal = true
		ch.set_color(color)
		line.add_child(ch)
		ch.set_data(data)


func _fill_war() -> void:
	for ch in _war.get_children():
		ch.queue_free()
	_war.get_parent().get_parent().visible = War.at_war()          # header and card together
	for k in War.wars():
		var i := int(k)
		var w: Dictionary = War.wars()[k]
		var row := ListRow.new().setup("War with %s" % World.map.names[i],
			"You hold %d%%  ·  they hold %d%%  ·  win chance %d%%" % [roundi(float(w.occ_them) * 100.0), roundi(float(w.occ_me) * 100.0),
				roundi(War.odds(i) * 100.0)], "›")
		row.set_leading(ListRow.icon_tile("swords", DS.RED))
		row.tapped.connect(func() -> void: WarRoom.open(get_tree().current_scene, i))
		_war.add_child(row)


func _fill_world_wars() -> void:
	for ch in _wwars.get_children():
		ch.queue_free()
	var all := WorldWars.all()
	_wwars.get_parent().get_parent().visible = not all.is_empty()
	for k in all:
		var w: Dictionary = all[k]
		var a := int(w.a)
		var b := int(w.b)
		var lead := "%s holds %d%% of %s" % [World.map.names[a], roundi(float(w.occ_b) * 100.0), World.map.names[b]] if float(w.occ_b) > 0.005 			else ("%s holds %d%% of %s" % [World.map.names[b], roundi(float(w.occ_a) * 100.0), World.map.names[a]] if float(w.occ_a) > 0.005 else "Front unchanged")
		var row := ListRow.new().setup("%s vs %s" % [World.map.names[a], World.map.names[b]],
			"%s  ·  month %d" % [lead, Game.months_played - int(w.start) + 1], "›")
		row.set_leading(ListRow.icon_tile("swords", DS.ORANGE))
		row.tapped.connect(_world_war_actions.bind(str(k)))
		_wwars.add_child(row)


func _world_war_actions(k: String) -> void:
	var w: Dictionary = WorldWars.all().get(k, {})
	if w.is_empty():
		return
	var a := int(w.a)
	var b := int(w.b)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.content.add_child(Illustration.banner("war", "swords", DS.ORANGE, 96.0))
	m.header("swords", DS.ORANGE, "A war abroad", "%s vs %s" % [World.map.names[a], World.map.names[b]])
	m.body("%s attacked %s. You can stay out of it, try to broker peace, sell arms to one side, or join the fight." % [World.The_name(a), World.the_name(b)])
	if WorldWars.can_mediate(w):
		m.choice("Broker a peace", "Both sides are tiring · relations with both rise", &"PrimaryButton", func() -> void:
			var text := WorldWars.mediate(k)
			Haptics.success()
			m.dismiss()
			Game.add_feed(text, "flag", "gold")
			refresh())
	else:
		m.choice("Broker a peace", "Too soon: neither side is tired yet", &"GhostButton", func() -> void: pass)
	for side in [a, b]:
		m.choice("Sell arms to %s" % World.map.names[side], "Money for you · angers %s" % World.map.names[b if side == a else a], &"", func() -> void:
			var amt := WorldWars.sell_arms(k, side)
			Haptics.select()
			m.dismiss()
			refresh())
	for side in [a, b]:
		var foe := b if side == a else a
		var why := War.blocked(foe)
		if why == "":
			m.choice("Join on %s's side" % World.map.names[side], "Declare war on %s" % World.map.names[foe], &"DestructiveButton", func() -> void:
				War.declare(foe)
				var gs := get_tree().current_scene
				if gs and "map" in gs:
					gs.map.refresh_war_marks()
				m.dismiss()
				refresh())
	m.choice("Stay neutral", "", &"GhostButton", m.dismiss)


func _fill_security() -> void:
	for ch in _security.get_children():
		ch.queue_free()
	var s := Security.get_state()
	var lv := Security.level()
	var col: Color = [DS.GREEN, DS.ORANGE, DS.RED][lv]
	_stat_line(_security, "shield", col, Security.LEVEL_TEXT[lv],
		"Threat %d  ·  your deterrence %d" % [roundi(float(s.threat)), roundi(float(s.deterrence))])
	note(Security.describe(), _security)


func _fill_climate() -> void:
	for ch in _climate.get_children():
		ch.queue_free()
	var me := Game.me()
	var hist := PackedFloat32Array(Climate.state().get("hist", []))
	_stat_line(_climate, "thermometer-sun", DS.ORANGE, "World  +%s °C" % String.num(Climate.warming(), 2),
		"Warmer than before factories", hist)
	var chg := Climate.change(me)
	_stat_line(_climate, "leaf", DS.GREEN, "You  %s t CO₂ a person" % String.num(Climate.co2_pc(me), 1),
		"World average %s t  ·  %d%% renewable" % [String.num(Climate.world_average(), 1), roundi(Climate.renewables(me))])
	var p := Climate.pledge()
	var how := ("Your emissions since %d: %s. " % [Calendar.START_YEAR, Climate._pct(chg)]) if absf(chg) >= 0.005 else ""
	if not p.is_empty():
		how += "Your pledge: cut emissions %d%% by %d. So far: %s. " % [roundi(float(p.cut) * 100.0), int(p.year),
			Climate._pct(-Climate.pledge_done())]
	how += "Solar, wind, nuclear, a coal phase-out and a carbon tax cut emissions. Clean energy also shields you from oil shocks."
	var more := Climate.disaster_mult() - 1.0
	if more >= 0.05:
		how += " Floods, storms and heatwaves are now %d%% more likely than in %d." % [roundi(more * 100.0), Calendar.START_YEAR]
	note(how, _climate)


func _fill_treaties() -> void:
	for ch in _treaties.get_children():
		ch.queue_free()
	var mine: Array = []
	var others: Array = []
	for t in Treaties.ALL:
		if Treaties.is_member(Game.player, t.id) or Treaties.pending_months(t.id) > 0:
			mine.append(t)
		elif Treaties.join_blocker(t.id) == "" or str(t.get("open", "")) == "all":
			others.append(t)
	for t in mine + others:
		var member := Treaties.is_member(Game.player, t.id)
		var pend := Treaties.pending_months(t.id)
		var status := "Member" if member else ("Joining · %d mo" % pend if pend > 0 else "Can join")
		var row := ListRow.new().setup(str(t.title), "%s · %d members" % [t.kind, Treaties.members(t.id).size()], status)
		row.trailing_label.add_theme_color_override(&"font_color", DS.GREEN if member else (DS.ORANGE if pend > 0 else DS.ACCENT_SOFT))
		row.set_leading(ListRow.icon_tile(str(t.icon), DS.GOLD if member else DS.ACCENT))
		row.tapped.connect(_treaty_card.bind(t))
		_treaties.add_child(row)
	if mine.is_empty() and others.is_empty():
		note("No treaties are open to you right now.", _treaties)


func _treaty_card(t: Dictionary) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	var member := Treaties.is_member(Game.player, t.id)
	m.header(str(t.icon), DS.GOLD, str(t.kind), str(t.title))
	m.body("%s %d members, including %s." % [str(t.desc), Treaties.members(t.id).size(),
		", ".join(Treaties.members(t.id).slice(0, 4).map(func(i: int) -> String: return World.map.names[i]))])
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	for k in t.fx:
		var v := float(t.fx[k])
		var good: bool = (v > 0.0) == bool(Laws.FX_GOOD_UP.get(k, true))
		var p := PanelContainer.new()
		p.theme_type_variation = &"ForecastChip"
		var l := Label.new()
		l.theme_type_variation = &"ChipValue"
		l.add_theme_color_override(&"font_color", DS.GREEN if good else DS.RED)
		l.text = "%s %+.2f" % [Laws.FX_LABELS.get(k, k), v] if absf(v) < 1.0 else "%s %+.1f" % [Laws.FX_LABELS.get(k, k), v]
		p.add_child(l)
		chips.add_child(p)
	m.content.add_child(chips)
	var blocker := Treaties.join_blocker(t.id)
	if member:
		m.choice("Leave", "Members will be upset (relations %d)" % roundi(float(t.leave_rel)), &"DestructiveButton", func() -> void:
			Treaties.leave(t.id)
			Haptics.warning()
			m.dismiss()
			refresh())
	elif blocker == "":
		m.choice("Apply to join", "Takes %d months" % int(t.get("months", 6)), &"PrimaryButton", func() -> void:
			Treaties.start_join(t.id)
			Haptics.success()
			m.dismiss()
			refresh())
	else:
		m.body(blocker)
	m.choice("Close", "", &"GhostButton", m.dismiss)


## Your world rank in four measures (among countries with data).
func _fill_ranks() -> void:
	for ch in _ranks.get_children():
		ch.queue_free()
	var specs := [["GDP", func(c: CountryState) -> float: return c.gdp],
		["Per person", func(c: CountryState) -> float: return c.gdp_per_capita()],
		["Happiness", func(c: CountryState) -> float: return c.happiness],
		["Stability", func(c: CountryState) -> float: return c.stability]]
	var me := Game.me()
	for sp in specs:
		var mine: float = sp[1].call(me)
		var rank := 1
		var total := 0
		for i in World.playable:
			var c: CountryState = Game.state(i)
			if c == null:
				continue
			total += 1
			if i != Game.player and float(sp[1].call(c)) > mine:
				rank += 1
		var t := StatTile.new().setup(str(sp[0]), func(_v: float) -> String: return "#%d" % rank, true)
		t.number.theme_type_variation = &"StatSmall"
		t.number.set_instant(rank)
		t.number.add_theme_color_override(&"font_color", DS.GOLD if rank <= 10 else (DS.GREEN if rank <= 40 else (DS.TEXT if rank <= 100 else DS.ORANGE)))
		t.delta_label.text = ("Top 10  ·  of %d" % total) if rank <= 10 else "of %d" % total
		_ranks.add_child(t)


## Scroll the sheet so a section's card is at the top.
func _scroll_to(box: Control) -> void:
	var gs := get_tree().current_scene
	if gs == null or not ("_scroll" in gs) or box == null:
		return
	var card := box.get_parent().get_parent() as Control
	var sc: ScrollContainer = gs._scroll
	var y := card.global_position.y - sc.global_position.y + sc.scroll_vertical - 12.0
	var tw := sc.create_tween()
	DS.ease_out(tw)
	tw.tween_property(sc, "scroll_vertical", int(y), Settings.dur(0.4))


# ------------------------------------------------------------------- intel ---
func _fill_intel() -> void:
	for ch in _intel.get_children():
		ch.queue_free()
	var s := Intel.st()
	var lv := Intel.level()
	_intel.add_child(photo_header("intel", "Intelligence agency", "Strength %d  ·  %d spies caught  ·  %d operations exposed" % [
		roundi(Intel.strength(Game.player)), int(s.caught), int(s.lost)], 118.0))
	var seg := SegmentedControl.new().setup(PackedStringArray(Intel.LEVELS), [], lv)
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Intel.st().level = k
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	_intel.add_child(seg)
	var extra := Intel.spending_pct()
	note("Budget: %s a year%s. A bigger agency runs more operations at once, succeeds more often and catches more foreign spies." % [
		DS.money(Game.me().gdp * float(Economy.INTEL_COST[lv]) / 100.0),
		("  (%s more than usual)" % DS.money(Game.me().gdp * extra / 100.0)) if extra > 0.0 else ""], _intel)
	for o in s.ops:
		var info: Dictionary = Intel.OPS[str(o.op)]
		var row := ListRow.new().setup(str(info.title), "%s  ·  %d %s left" % [World.map.names[int(o.target)], Intel.months_left(o), "month" if Intel.months_left(o) == 1 else "months"])
		row.set_leading(ListRow.icon_tile(str(info.icon), DS.PURPLE))
		_intel.add_child(row)
		_intel.add_child(meter(1.0 - float(Intel.months_left(o)) / maxf(float(o.months), 1.0), 0.0, DS.PURPLE, 4.0))
	if (s.ops as Array).is_empty():
		note("No operations running. Open any country to plan one.", _intel)
	for e in (s.log as Array).slice(0, 3):
		var r := ListRow.new().setup(str(e.text), "This month" if Game.months_played - int(e.m) <= 0 else "%d months ago" % (Game.months_played - int(e.m)))
		r.title_label.theme_type_variation = &"Subhead"
		r.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		r.set_leading(ListRow.icon_tile("check" if bool(e.good) else "x", DS.GREEN if bool(e.good) else DS.RED))
		_intel.add_child(r)


# ------------------------------------------------------------------ empire ---
## Lands you've absorbed and vassals you rule. Hidden when you have neither.
func _fill_empire() -> void:
	for ch in _empire.get_children():
		ch.queue_free()
	var lands := Annexation.my_lands()
	var vas := Annexation.vassals()
	_empire.get_parent().get_parent().visible = not lands.is_empty() or not vas.is_empty()
	if lands.is_empty() and vas.is_empty():
		return
	for l in lands:
		var i := int(l.i)
		var t := float(l.integration)
		var sub := ("United peacefully" if bool(l.peaceful) else "Conquered") + "  ·  %s people" % DS.compact(float(l.pop))
		sub += "  ·  integrated" if t >= 1.0 else "  ·  %d%% integrated" % roundi(t * 100.0)
		var row := ListRow.new().setup(World.map.names[i], sub, "›")
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.set_leading(Flag.new().show_country(i, 22.0))
		row.tapped.connect(_land_card.bind(i))
		_empire.add_child(row)
		_empire.add_child(meter(t, 0.0, DS.GREEN if t >= 1.0 else DS.ORANGE, 3.0))
	for k in vas:
		var i2 := int(k)
		var v: CountryState = Game.state(i2)
		if v == null:
			continue
		var row2 := ListRow.new().setup(World.map.names[i2], "Vassal  ·  pays %s a year  ·  relations %d" % [
			DS.money(v.gdp * Economy.ANNEX_TRIBUTE), roundi(Game.relations[i2])], "›")
		row2.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row2.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row2.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row2.set_leading(Flag.new().show_country(i2, 22.0))
		row2.tapped.connect(_vassal_card.bind(i2))
		_empire.add_child(row2)
	note("Newly absorbed people resist for a few years; integration ends the unrest. Vassals pay tribute and fight beside you, but may break free if your army weakens.", _empire)


func _land_card(i: int) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("flag", DS.GOLD, "Your lands", World.map.names[i])
	var info: Dictionary = Game.dip.get("absorbed_info", {}).get(str(i), {})
	m.body("Part of %s since %d months ago. %s people." % [World.the_name(Game.player), Game.months_played - int(info.get("m", Game.months_played)),
		DS.compact(float(info.get("pop", 0.0)))])
	m.choice("Grant independence", "Its people and economy leave; the world and they will be grateful", &"DestructiveButton", func() -> void:
		var t := Annexation.release(i)
		m.dismiss()
		var gs := get_tree().current_scene
		if gs and gs.has_method("_notify"):
			gs._notify(t, "flag", DS.GREEN, true)
		Haptics.success()
		refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _vassal_card(i: int) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("crown", DS.GOLD, "Vassal", World.map.names[i])
	var wait := Annexation.vassal_annex_wait(i)
	m.body("Pays you tribute every year and adds its army to yours in war. Its people resent it slowly.")
	var ok := wait == 0 and Capital.can(Economy.VASSAL_ANNEX_CAPITAL)
	var ch := m.choice("Annex peacefully", ("A quiet union: little unrest, mild world concern  ·  %d capital" % int(Economy.VASSAL_ANNEX_CAPITAL)) if wait == 0
		else "Possible after %d more months as your vassal" % wait, &"PrimaryButton", func() -> void:
			var t := Annexation.annex_vassal(i)
			m.dismiss()
			var gs := get_tree().current_scene
			if t != "" and gs and gs.has_method("_notify"):
				gs._notify(t, "crown", DS.GOLD, true)
				if "map" in gs and gs.map != null:
					gs.map.celebrate("fireworks", Game.player)
			Haptics.success()
			refresh())
	if not ok:
		for b in ch.find_children("*", "Button", true, false):
			(b as Button).disabled = true
	m.choice("Set them free", "No more tribute; goodwill everywhere", &"", func() -> void:
		Annexation.free_vassal(i)
		m.dismiss()
		Haptics.tap()
		refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


# -------------------------------------------------------------- adaptation ---
func _fill_adapt() -> void:
	for ch in _adapt.get_children():
		ch.queue_free()
	var mult := Climate.disaster_mult()
	note("Warming has made disasters %d%% more frequent since records began. Protect your people before the next one: each project softens the disasters it guards against." % roundi((mult - 1.0) * 100.0)
		if mult > 1.01 else "Protect your people before the next disaster: each project softens the disasters it guards against.", _adapt)
	for id in Disasters.ADAPT:
		var a: Dictionary = Disasters.ADAPT[id]
		var done := Disasters.adapted(str(id))
		var bld := Disasters.building(str(id))
		var sub := ""
		if done:
			sub = "Built  ·  %d%% less harm" % roundi(float(a.cut) * 100.0)
		elif bld:
			var left := int(a.months) - (Game.months_played - int(Disasters.st().adapt[id].start))
			sub = "Under construction  ·  %d months left" % maxi(left, 0)
		else:
			sub = "%s  ·  %d months  ·  %s" % [DS.money(Disasters.adapt_cost(str(id))), int(a.months), str(a.desc)]
		var row := ListRow.new().setup(str(a.title), sub, "›" if not done and not bld else "")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(a.icon), DS.GREEN if done else (DS.ORANGE if bld else DS.TEAL)))
		if not done and not bld:
			var aid := str(id)
			row.tapped.connect(func() -> void:
				if Disasters.start_adapt(aid):
					Simulation.update_finances(Game.me())
					Haptics.success()
				refresh())
		_adapt.add_child(row)
	var lg: Array = Disasters.st().log
	if not lg.is_empty():
		var e: Dictionary = lg[0]
		note("Last disaster: %s, %d months ago  ·  %s lives lost" % [str(Disasters.TYPES[str(e.kind)].title).to_lower(),
			Game.months_played - int(e.m), DS.compact(float(e.deaths))], _adapt)
