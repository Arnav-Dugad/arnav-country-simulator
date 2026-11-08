class_name CheatsPanel
extends VBoxContainer
## The cheats sandbox: a hero card with your status, switches for lasting
## cheats, and a grid of one-tap cheats in categories. Any cheat turns off
## achievements for this game.

var _status: Label
var _grid_boxes: Array = []


func _ready() -> void:
	add_theme_constant_override(&"separation", DS.S4)
	_build()


func _build() -> void:
	for ch in get_children():
		ch.queue_free()
	if not Store.owns("cheats"):
		_paywall()
		return
	if not Settings.cheats:
		_locked()
		return
	if Game.me() == null:
		var n := Label.new()
		n.theme_type_variation = &"Footnote"
		n.text = "Start or continue a game to use cheats."
		add_child(n)
		return
	add_child(_hero())
	add_child(_section_title("Always on"))
	add_child(_switches())
	add_child(_section_title("Set exact values"))
	add_child(_sliders())
	for cat in CATEGORIES:
		add_child(_section_title(str(cat[0])))
		add_child(_grid(cat[1]))
	var off := AppButton.make("Hide cheats", &"GhostButton", "x")
	off.pressed.connect(func() -> void:
		Settings.set_value("cheats", false)
		_build())
	add_child(off)


# ------------------------------------------------------------------ pieces ---
func _locked() -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(v)
	var c := CenterContainer.new()
	c.add_child(ListRow.icon_tile("wand-sparkles", DS.PURPLE))
	v.add_child(c)
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = "Sandbox mode"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(60, 0)
	d.text = "Over 25 cheats to bend the world to your will: money, love, instant building, winning wars, stopping time's troubles. Games where you use them don't earn achievements."
	v.add_child(d)
	var b := AppButton.make("Turn on cheats", &"PrimaryButton", "wand-sparkles")
	b.pressed.connect(func() -> void:
		Settings.set_value("cheats", true)
		Haptics.success()
		_build())
	v.add_child(b)


func _hero() -> Control:
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(row)
	row.add_child(ListRow.icon_tile("wand-sparkles", DS.PURPLE))
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Sandbox"
	v.add_child(t)
	_status = Label.new()
	_status.theme_type_variation = &"Caption"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(40, 0)
	_status.text = ("%d cheats used this game: achievements are off." % int(Game.dip.get("cheats_count", 1))) if Game.cheats_used else "No cheats used yet: achievements still count."
	_status.add_theme_color_override(&"font_color", DS.ORANGE if Game.cheats_used else DS.GREEN)
	v.add_child(_status)
	return card


func _section_title(t: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"Overline"
	l.text = t.to_upper()
	return l


func _switches() -> Control:
	var box := PanelContainer.new()
	box.theme_type_variation = &"GroupPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S2)
	box.add_child(v)
	var add := func(label: String, icon_: String, on: bool, fn: Callable) -> void:
		var tg := AppToggle.new().setup(label, on, icon_)
		tg.toggled.connect(func(val: bool) -> void:
			if val:
				_used()
			fn.call(val))
		v.add_child(tg)
	add.call("Never lose power", "crown", Game.god_mode, func(val: bool) -> void: Game.god_mode = val)
	add.call("No random events", "calendar", Game.no_events, func(val: bool) -> void: Game.no_events = val)
	add.call("Unlimited political capital", "landmark", bool(Game.dip.get("cheat_capital", false)), func(val: bool) -> void:
		Game.dip["cheat_capital"] = val
		if val:
			Game.dip["capital"] = Economy.CAPITAL_MAX)
	add.call("Unlimited money", "coins", bool(Game.dip.get("cheat_money", false)), func(val: bool) -> void:
		Game.dip["cheat_money"] = val)
	return box


func _grid(items: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	for it in items:
		g.add_child(_tile(it))
	return g


func _tile(it: Array) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 4)
	p.add_child(v)
	var ic := TextureRect.new()
	ic.texture = DS.icon(str(it[1]))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(22, 22)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ic.modulate = it[3]
	v.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Subhead"
	t.text = str(it[0])
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(40, 0)
	v.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Caption"
	d.text = str(it[2])
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(40, 0)
	v.add_child(d)
	var st := {"p": Vector2.ZERO, "down": false}
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				st.p = e.global_position
				st.down = true
			elif st.down:
				st.down = false
				if e.global_position.distance_to(st.p) < 10.0:      # a tap, not a scroll
					_run(it, p, ic)
		elif e is InputEventMouseMotion and st.down and e.global_position.distance_to(st.p) >= 10.0:
			st.down = false)
	return p


func _run(it: Array, tile: Control, ic: TextureRect) -> void:
	_used()
	(it[4] as Callable).call()
	var c := Game.me()
	Simulation.update_finances(c)
	c.refresh_explainer()
	Game.month_passed.emit()
	Haptics.success()
	# A quick glow on the tile that was tapped.
	tile.pivot_offset = tile.size * 0.5
	var tw := tile.create_tween()
	tw.tween_property(tile, "scale", Vector2.ONE * 0.95, 0.07)
	tw.tween_property(tile, "scale", Vector2.ONE, Settings.dur(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var col: Color = ic.modulate
	ic.modulate = Color.WHITE
	ic.create_tween().tween_property(ic, "modulate", col, Settings.dur(0.6))
	if _status:
		_status.text = "Done: %s. Achievements are off for this game." % str(it[0]).to_lower()
		_status.add_theme_color_override(&"font_color", DS.ORANGE)


func _used() -> void:
	Game.cheats_used = true
	Game.dip["cheats_count"] = int(Game.dip.get("cheats_count", 0)) + 1


## Not bought yet: what the pack contains and a buy button (demo store).
func _paywall() -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(v)
	if Photo.has_scene("store"):
		v.add_child(Photo.scene("store", 120.0))
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = "Sandbox Cheats"
	v.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(60, 0)
	var n := 0
	for cat in CATEGORIES:
		n += (cat[1] as Array).size()
	d.text = "%d one-tap cheats in %d categories, exact sliders for approval, stability, happiness and more, and lasting switches like never losing power. Bend the world to your will: games where you cheat don't earn achievements." % [n, CATEGORIES.size()]
	v.add_child(d)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	v.add_child(flow)
	for cat in CATEGORIES:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"ForecastChip"
		var l := Label.new()
		l.theme_type_variation = &"ChipValue"
		l.text = str(cat[0])
		l.add_theme_color_override(&"font_color", DS.PURPLE)
		chip.add_child(l)
		flow.add_child(chip)
	var b := AppButton.make("Unlock for %s" % Store.price_text("cheats"), &"PrimaryButton", "wand-sparkles")
	b.pressed.connect(func() -> void:
		b.disabled = true
		b.text = "Purchasing…"
		var r: Dictionary = await Store.purchase("cheats")
		if r.ok:
			Settings.set_value("cheats", true)
			Haptics.success()
			Audio.play("success", -6.0)
		else:
			Haptics.warning()
		_build())
	v.add_child(b)
	var note := Label.new()
	note.theme_type_variation = &"Caption"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(60, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.text = "Included in the Complete Edition and the Statesman Pass." + ("  Demo store: nothing is charged." if Store.DEMO else "")
	v.add_child(note)


## Sliders that set a number right now (policies then pull it gently back).
func _sliders() -> Control:
	var box := PanelContainer.new()
	box.theme_type_variation = &"GroupPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(v)
	var m := Game.me()
	var specs := [
		["Approval", "approval", 0.0, 100.0],
		["Happiness", "happiness", 0.0, 100.0],
		["Stability", "stability", 0.0, 100.0],
		["Military strength", "military", 1.0, 100.0],
		["Inflation", "inflation", -2.0, 30.0],
		["Unemployment", "unemployment", 1.0, 30.0],
	]
	for sp in specs:
		var key := str(sp[1])
		var sl := AppSlider.new().setup(str(sp[0]), float(sp[2]), float(sp[3]), 1.0, clampf(float(m.get(key)), float(sp[2]), float(sp[3])))
		sl.formatter = (func(x: float) -> String: return "%d%%" % roundi(x)) if key in ["inflation", "unemployment"] else (func(x: float) -> String: return str(roundi(x)))
		sl.drag_ended.connect(func(x: float) -> void:
			_used()
			var c := Game.me()
			var before := float(c.get(key))
			c.set(key, x)
			# Hold it for a while: a shock the size of the change, fading as usual.
			if c.shocks.has(key):
				c.shocks[key] = float(c.shocks[key]) + (x - before)
			if key == "inflation":
				c.core_inflation = x
			if key == "unemployment":
				c.u_natural = clampf(x, Economy.UNEMP_MIN, Economy.UNEMP_MAX)
			Simulation.update_finances(c)
			Game.month_passed.emit()
			Haptics.select())
		v.add_child(sl)
	var n := Label.new()
	n.theme_type_variation = &"Caption"
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(60, 0)
	n.text = "Your policies slowly pull these back toward what they support. Pair them with the switches above to make them last."
	v.add_child(n)
	return box


# --------------------------------------------------------------- catalogue ---
## [category, [[title, icon, subtitle, colour, action], …]]
static var CATEGORIES := [
	["Money", [
		["Small fortune", "coins", "+10% of GDP in cash", DS.GOLD, func() -> void: Game.me().treasury += Game.me().gdp * 0.1],
		["Vast fortune", "piggy-bank", "+50% of GDP in cash", DS.GOLD, func() -> void: Game.me().treasury += Game.me().gdp * 0.5],
		["Debt forgiven", "check", "The national debt is gone", DS.GREEN, func() -> void: Game.me().debt = 0.0],
		["AAA credit", "landmark", "Borrow at the best rates", DS.ACCENT, func() -> void:
			Game.me().debt_rate = 1.0
			Game.me().interest_rate = maxf(Game.me().interest_rate - 2.0, 0.0)],
	]],
	["People", [
		["Everyone loves you", "heart", "Approval and happiness soar", DS.RED, func() -> void:
			var m := Game.me()
			m.approval = minf(m.approval + 20.0, 95.0)
			m.happiness = minf(m.happiness + 15.0, 95.0)
			m.shocks.approval = float(m.shocks.approval) + 20.0
			m.shocks.happiness = float(m.shocks.happiness) + 15.0],
		["Restore order", "shield", "Stability +25", DS.TEAL, func() -> void:
			var m := Game.me()
			m.stability = minf(m.stability + 25.0, 95.0)
			m.shocks.stability = float(m.shocks.stability) + 25.0],
		["Full employment", "users", "Joblessness falls to 3%", DS.ACCENT, func() -> void:
			var m := Game.me()
			m.unemployment = 3.0
			m.u_natural = minf(m.u_natural, 3.5)],
		["Fair society", "scale", "Inequality falls 8 points", DS.GREEN, func() -> void:
			var m := Game.me()
			m.gini = maxf(m.gini - 8.0, 20.0)],
	]],
	["Economy", [
		["Economic miracle", "trending-up", "Growth +3 points for years", DS.GREEN, func() -> void:
			var m := Game.me()
			m.growth_anchor += 3.0
			m.trend += 1.0],
		["Stable prices", "flame", "Inflation back to 2%", DS.ORANGE, func() -> void:
			var m := Game.me()
			m.inflation = 2.0
			m.core_inflation = 2.0],
		["Oil boom", "fuel", "World oil prices jump", DS.ORANGE, func() -> void: Game.markets.oil = maxf(Game.markets.oil, 0.6)],
		["Clean air", "leaf", "Undo a decade of warming", DS.GREEN, func() -> void:
			var st := Climate.state()
			st.warming = maxf(float(st.warming) - 0.25, Climate.start_warming())],
	]],
	["Building", [
		["Finish everything", "hammer", "All construction completes now", DS.ORANGE, func() -> void:
			var m := Game.me()
			for id in m.projects.keys():
				if str(m.projects[id].state) == "building":
					m.projects[id].progress = float(Projects.by_id(id).months)
			for id in Projects.monthly(m):
				Game.project_finished.emit(str(id))
			for bid in m.builds:
				for b in m.builds[bid].batches:
					b.left = 0.0
			for done in Builds.monthly(m):
				Game.build_finished.emit(str(done[0]), int(done[1]))],
		["Modern nation", "building-2", "Every build type +25% coverage", DS.ACCENT, func() -> void:
			var m := Game.me()
			for bid in Builds.ALL:
				var st: Dictionary = m.builds.get(bid, {})
				if st.is_empty() or Builds.available(m, str(bid)) != "":
					continue
				st.n = int(st.n) + int(ceil(Builds.need(m, str(bid)) * 0.35))
			m.builds_ver += 1],
		["Pass all laws now", "gavel", "Every law being debated passes", DS.PURPLE, func() -> void:
			var m := Game.me()
			for id in m.laws.keys():
				if str(m.laws[id].get("state", "")) in ["passing", "repealing"]:
					m.laws[id].months_left = 1
			for done in Laws.monthly(m):
				if str(done.id) == "free_elections" and not bool(done.repealed):
					Game.politics.become_democracy()
				Game.law_finished.emit(str(done.id), bool(done.repealed))],
		["Political capital", "landmark", "Fill it to the top", DS.GOLD, func() -> void: Game.dip["capital"] = Economy.CAPITAL_MAX],
	]],
	["World", [
		["Friends everywhere", "globe", "Relations +30 with everyone", DS.TEAL, func() -> void:
			for i in Game.relations.size():
				if i != Game.player:
					Game.relations[i] = clampf(Game.relations[i] + 30.0, -100.0, 100.0)
					Game.dip.baseline[str(i)] = clampf(float(Game.dip.baseline.get(str(i), 0.0)) + 30.0, -100.0, 100.0)
			Game.relations_changed.emit()],
		["Superpower army", "shield-check", "Military strength to 100", DS.RED, func() -> void:
			Game.me().military = 100.0
			Game.me().shocks.stability = float(Game.me().shocks.stability) + 2.0],
		["Win every war", "swords", "Enemies cede the land you hold", DS.RED, func() -> void:
			for k in War.wars().keys():
				var w: Dictionary = War.wars()[k]
				w.occ_them = maxf(float(w.occ_them), 0.3)
				War.make_peace(int(k), "annex")],
		["Peace everywhere", "flag", "End all wars on the old borders", DS.GREEN, func() -> void:
			for k in War.wars().keys():
				War.make_peace(int(k), "status_quo")],
	]],
	["Research", [
		["Eureka", "flask-conical", "Finish the current research now", DS.PURPLE, func() -> void:
			var s := Tech.st()
			if str(s.current) != "":
				s.progress = float(Tech.ALL[str(s.current)].cost)
				for n in Tech.monthly():
					Game.tech_news.emit(n)],
		["Future tech", "atom", "Every technology researched", DS.PURPLE, func() -> void:
			var s := Tech.st()
			for id in Tech.ALL:
				if not (s.done as Array).has(id):
					(s.done as Array).append(id)
			s.current = ""
			s.progress = 0.0],
	]],
	["War & spies", [
		["They surrender", "flag", "Every enemy capitulates", DS.RED, func() -> void:
			for k in War.wars().keys():
				var w: Dictionary = War.wars()[k]
				w.capitulated = true
				w.occ_them = maxf(float(w.occ_them), 0.92)
				w.morale_them = 0.15],
		["Annex your enemies", "crown", "Absorb every country you're at war with", DS.GOLD, func() -> void:
			for k in War.wars().keys():
				War.with(int(k)).capitulated = true
				War.make_peace(int(k), "annex_all")],
		["Rally the nation", "megaphone", "War support to 100%", DS.ORANGE, func() -> void:
			for k in War.wars().keys():
				War.wars()[k].support = 100.0
				War.wars()[k].morale_me = 1.2],
		["Master spies", "eye", "Massive agency; operations finish now", DS.PURPLE, func() -> void:
			var s := Intel.st()
			s.level = 3
			for o in s.ops:
				o.start = Game.months_played - int(o.months)
				o.p = 1.0
				o.x = 0.0],
	]],
	["Wealth & fame", [
		["Bull market", "trending-up", "Share prices double", DS.GREEN, func() -> void:
			Enterprise.st().index = float(Enterprise.st().index) * 2.0
			(Enterprise.st().hist as Array).append(float(Enterprise.st().index))],
		["Sovereign riches", "piggy-bank", "+100% of GDP in your wealth fund", DS.GOLD, func() -> void:
			Enterprise.fund().value = float(Enterprise.fund().value) + Game.me().gdp],
		["Trusted voice", "newspaper", "Credibility to 100", DS.ACCENT, func() -> void:
			Game.dip["credibility"] = 100.0],
		["World heritage", "landmark", "Three new heritage sites listed", DS.GOLD, func() -> void:
			var s := Tourism.st()
			var kinds: Array = Tourism.SITES.keys()
			for k in 3:
				var kind := str(kinds[(k + (s.sites as Array).size()) % kinds.size()])
				var names: Array = Tourism.SITES[kind][2]
				(s.sites as Array).append({"kind": kind, "name": str(names[0]) % World.map.names[Game.player], "year": Game.year})],
		["Host the Games", "medal", "The Summer Games open in a year", DS.GOLD, func() -> void:
			var s := Tourism.st()
			s.bid = {}
			s.host = {"ev": "games", "year_m": Game.months_played + 12}],
		["Baby boom", "users", "Population +5%", DS.TEAL, func() -> void:
			Game.me().population *= 1.05],
	]],
	["Time", [
		["Fast-forward a year", "fast-forward", "Twelve months pass at once", DS.ACCENT, func() -> void:
			for k in 12:
				Game.advance_month()],
		["Skip to the election", "vote", "The next vote is next month", DS.GOLD, func() -> void:
			if Game.politics.months_to_election > 1:
				Game.politics.months_to_election = 1],
		["Clear the inbox", "bell", "Your cabinet answers everything", DS.ACCENT, func() -> void:
			while Game.director.has_open():
				var ev := Game.director.first()
				Game.director.resolve(ev, Game.director.recommended(ev), true)],
	]],
]
