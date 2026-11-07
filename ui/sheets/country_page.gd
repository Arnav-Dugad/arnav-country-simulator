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
		_gov.text = "\n".join(lines)
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
		["People", me.population, them.population, true, func(v: float) -> String: return DS.compact(v)],
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
