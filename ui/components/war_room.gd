class_name WarRoom
extends RefCounted
## The war room for one war: the front, morale, home support, casualties, your
## strategy, military operations, recent battles and peace terms.


static func open(parent: Node, i: int) -> void:
	var w := War.with(i)
	if w.is_empty():
		return
	var m := ModalCard.new()
	parent.add_child(m)
	m.content.add_child(Illustration.banner("war", "swords", DS.RED, 104.0))
	var months := Game.months_played - int(w.start)
	var g: Dictionary = War.GOALS[War.goal(w)]
	m.header("swords", DS.RED, "%s · month %d" % [str(g.title), months + 1], "%s vs %s" % [World.map.names[Game.player], World.map.names[i]])
	if bool(w.get("capitulated", false)):
		var cap := m.body("%s has capitulated. Dictate the peace." % World.The_name(i))
		cap.add_theme_color_override(&"font_color", DS.GOLD)
	# Ground held: a two-sided bar (your gains right, their gains left), with your goal marked.
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var occ_me := float(w.occ_me)
	var occ_them := float(w.occ_them)
	var goal_occ := float(g.max_occ)
	bar.draw.connect(func() -> void:
		var wd := bar.size.x
		var mid := wd * 0.5
		bar.draw_rect(Rect2(0, 10, wd, 8), Color(1, 1, 1, 0.08))
		bar.draw_rect(Rect2(mid, 10, mid * minf(occ_them, 1.0), 8), DS.GREEN)
		bar.draw_rect(Rect2(mid - mid * minf(occ_me, 1.0), 10, mid * minf(occ_me, 1.0), 8), DS.RED)
		bar.draw_rect(Rect2(mid - 1, 4, 2, 20), Color(1, 1, 1, 0.7))
		var gx := mid + mid * minf(goal_occ, 1.0) - 1.0
		bar.draw_rect(Rect2(gx, 6, 2, 16), DS.GOLD))
	m.content.add_child(bar)
	var held := Label.new()
	held.theme_type_variation = &"Footnote"
	held.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	held.custom_minimum_size = Vector2(60, 0)
	var parts: PackedStringArray = []
	if occ_them > 0.005:
		parts.append("You hold %d%% of %s" % [roundi(occ_them * 100.0), World.the_name(i)])
	if occ_me > 0.005:
		parts.append("they hold %d%% of yours" % roundi(occ_me * 100.0))
	if parts.is_empty():
		parts.append("The front hasn't moved")
	held.text = ", ".join(parts) + ". Gold mark: your war goal (%d%%)." % roundi(goal_occ * 100.0)
	m.content.add_child(held)
	# The front over time (above the line: you're gaining ground).
	var hist: Array = w.get("hist", [])
	if hist.size() >= 2:
		var fh := Label.new()
		fh.theme_type_variation = &"Overline"
		fh.text = "THE FRONT, MONTH BY MONTH"
		m.content.add_child(fh)
		var ch := Control.new()
		ch.custom_minimum_size = Vector2(0, 64)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch.draw.connect(func() -> void:
			var wd := ch.size.x
			var hh := ch.size.y
			var mid := hh * 0.5
			ch.draw_line(Vector2(0, mid), Vector2(wd, mid), Color(1, 1, 1, 0.18), 1.0)
			var top := 0.05
			for v in hist:
				top = maxf(top, absf(float(v)))
			var pts := PackedVector2Array()
			for k in hist.size():
				pts.append(Vector2(wd * k / float(hist.size() - 1), mid - mid * 0.9 * float(hist[k]) / top))
			# Fill each segment to the midline (green where you're ahead, red behind),
			# split where it crosses so no polygon ever twists.
			for k in pts.size() - 1:
				var a := pts[k]
				var b := pts[k + 1]
				var da := a.y - mid
				var db := b.y - mid
				if da * db < 0.0:
					var x := a.x + (b.x - a.x) * da / (da - db)
					ch.draw_colored_polygon(PackedVector2Array([a, Vector2(x, mid), Vector2(a.x, mid)]), Color(DS.GREEN if da < 0.0 else DS.RED, 0.18))
					ch.draw_colored_polygon(PackedVector2Array([Vector2(x, mid), b, Vector2(b.x, mid)]), Color(DS.GREEN if db < 0.0 else DS.RED, 0.18))
				elif absf(da) + absf(db) > 0.5:
					ch.draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, mid), Vector2(a.x, mid)]),
						Color(DS.GREEN if (da + db) < 0.0 else DS.RED, 0.18))
			var last := float(hist[hist.size() - 1])
			var col := DS.GREEN if last >= 0.0 else DS.RED
			ch.draw_polyline(pts, Color(1, 1, 1, 0.75), 2.0, true)
			ch.draw_circle(pts[pts.size() - 1], 3.5, col))
		m.content.add_child(ch)
	# Numbers.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", DS.S2)
	grid.add_theme_constant_override(&"v_separation", DS.S2)
	m.content.add_child(grid)
	_tile(grid, "Battle odds", "%d%%" % roundi(War.odds(i) * 100.0))
	var sup := War.support(w)
	_tile(grid, "Support at home", "%d%%" % roundi(sup), DS.GREEN if sup >= 55.0 else (DS.ORANGE if sup >= 30.0 else DS.RED))
	_tile(grid, "Morale", "%d%% / %d%%" % [roundi(float(w.morale_me) * 100.0), roundi(float(w.morale_them) * 100.0)])
	_tile(grid, "Casualties", "%s / %s" % [DS.compact(float(w.cas_me)), DS.compact(float(w.cas_them))])
	# Strategy.
	var sh := Label.new()
	sh.theme_type_variation = &"Overline"
	sh.text = "STRATEGY"
	m.content.add_child(sh)
	var keys: Array = War.STRATEGIES.keys()
	var labels := PackedStringArray()
	for k in keys:
		labels.append(str(War.STRATEGIES[k].title))
	var seg := SegmentedControl.new().setup(labels, [], keys.find(str(w.get("strategy", "balanced"))))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sdesc := Label.new()
	sdesc.theme_type_variation = &"Caption"
	sdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sdesc.custom_minimum_size = Vector2(60, 0)
	sdesc.text = str(War.STRATEGIES[str(w.get("strategy", "balanced"))].desc)
	seg.changed.connect(func(k: int) -> void:
		War.set_strategy(i, str(keys[k]))
		sdesc.text = str(War.STRATEGIES[str(keys[k])].desc)
		Haptics.select())
	m.content.add_child(seg)
	m.content.add_child(sdesc)
	# Operations.
	var oh := Label.new()
	oh.theme_type_variation = &"Overline"
	oh.text = "OPERATIONS"
	m.content.add_child(oh)
	var ops := GridContainer.new()
	ops.columns = 2
	ops.add_theme_constant_override(&"h_separation", DS.S2)
	ops.add_theme_constant_override(&"v_separation", DS.S2)
	m.content.add_child(ops)
	for op in War.OPS:
		var why := War.op_blocked(i, str(op))
		var info: Dictionary = War.OPS[op]
		var b := AppButton.make(str(info.title), &"Chip", str(info.icon))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if why != "":
			b.modulate = Color(1, 1, 1, 0.45)        # still tappable: the card says why
		b.pressed.connect(func() -> void:
			m.dismiss()
			_confirm_op(parent, i, str(op)))
		ops.add_child(b)
	var hint := Label.new()
	hint.theme_type_variation = &"Caption"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(60, 0)
	hint.text = "Operations need the right forces: build fighters, frigates, drones or cyber units on the Defence tab."
	m.content.add_child(hint)
	# Recent battles.
	var log_: Array = w.get("log", [])
	if not log_.is_empty():
		var lh := Label.new()
		lh.theme_type_variation = &"Overline"
		lh.text = "RECENT"
		m.content.add_child(lh)
		for e in log_.slice(0, 3):
			var l := Label.new()
			l.theme_type_variation = &"Caption"
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(60, 0)
			l.text = "%s  ·  %s" % [str(e.date), str(e.text)]
			l.add_theme_color_override(&"font_color", DS.GREEN if bool(e.win) else DS.RED)
			m.content.add_child(l)
	# Actions.
	var mob_ready := Game.months_played >= int(w.get("mobilized_until", -1))
	if mob_ready and Capital.can(Economy.WAR_MOBILIZE_CAPITAL):
		m.choice("Mobilize the reserves", "+25%% strength for %d months · capital −%d · slows the economy" % [
			Economy.WAR_MOBILIZE_MONTHS, int(Economy.WAR_MOBILIZE_CAPITAL)], &"", func() -> void:
				War.mobilize(i)
				Haptics.success()
				m.dismiss()
				open(parent, i))
	if not bool(w.get("allies_called", false)) and not (Game.dip.get("alliances", {}) as Dictionary).is_empty():
		m.choice("Call on your allies", "Allies who like you enough will fight alongside you", &"", func() -> void:
			var n := War.call_allies(i)
			Haptics.select()
			Game.add_feed(("%d %s join the war on your side" % [n, "ally" if n == 1 else "allies"]) if n > 0 else "No ally answers the call", "users", "accent" if n > 0 else "orange")
			m.dismiss()
			open(parent, i))
	m.choice("Peace talks", "Propose terms; they'll say yes only if the war gives them reason to",
		&"PrimaryButton" if bool(w.get("capitulated", false)) else &"", func() -> void:
		m.dismiss()
		peace_terms(parent, i))
	m.choice("Close", "", &"GhostButton", m.dismiss)


static func _confirm_op(parent: Node, i: int, op: String) -> void:
	var info: Dictionary = War.OPS[op]
	var m := ModalCard.new()
	parent.add_child(m)
	m.header(str(info.icon), DS.RED, "Operation", str(info.title))
	m.body(str(info.desc))
	var why := War.op_blocked(i, op)
	if why != "":
		var l := m.body(why + ".")
		l.add_theme_color_override(&"font_color", DS.ORANGE)
		m.choice("Back", "", &"GhostButton", func() -> void:
			m.dismiss()
			open(parent, i))
		return
	m.choice("Launch", "Costs %s" % DS.money(War.op_cost(op)), &"DestructiveButton", func() -> void:
		var r := War.run_op(i, op)
		Simulation.update_finances(Game.me())
		if not r.is_empty():
			if bool(r.good):
				Haptics.success()
			else:
				Haptics.warning()
			if parent.has_method("_notify"):
				parent._notify(str(r.text), str(info.icon), DS.GREEN if bool(r.good) else DS.RED, false)
			if "map" in parent and parent.map != null:
				parent.map.battle_flash(i)
		m.dismiss()
		open(parent, i))
	m.choice("Back", "", &"GhostButton", func() -> void:
		m.dismiss()
		open(parent, i))


static func _tile(parent: Control, t: String, v: String, color: Color = Color(0, 0, 0, 0)) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var b := VBoxContainer.new()
	b.add_theme_constant_override(&"separation", 2)
	p.add_child(b)
	var a := Label.new()
	a.theme_type_variation = &"Overline"
	a.text = t.to_upper()
	a.clip_text = true
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	a.custom_minimum_size = Vector2(20, 0)
	b.add_child(a)
	var c := Label.new()
	c.theme_type_variation = &"StatSmall"
	c.text = v
	if color.a > 0.0:
		c.add_theme_color_override(&"font_color", color)
	b.add_child(c)


static func peace_terms(parent: Node, i: int) -> void:
	var w := War.with(i)
	var m := ModalCard.new()
	parent.add_child(m)
	m.header("flag", DS.GOLD, "Peace talks", "Terms for %s" % World.map.names[i])
	m.body("Choose what you ask for. Greedy terms only work when you're clearly winning.")
	var them: CountryState = Game.state(i)
	var opts := [
		["annex_all", "Annex the whole country", "%s joins %s: %s people, its economy and its debt. Borders vanish; years of unrest follow" % [
			World.The_name(i), World.the_name(Game.player), DS.compact(them.population)]],
		["vassal", "Make them a vassal", "They keep their flag but pay %s of GDP a year in tribute and follow your lead" % DS.pct(Economy.ANNEX_TRIBUTE * 100.0, 0)],
		["annex", "Keep the land you hold", "They cede %d%% of their country" % roundi(float(w.occ_them) * Economy.WAR_ANNEX_SHARE * 100.0)],
		["reparations", "Demand reparations", "They pay %s of their GDP" % DS.pct(Economy.WAR_REPARATIONS * 100.0, 0)],
		["status_quo", "Return to the old borders", "Everyone goes home"]]
	for o in opts:
		if o[0] == "annex" and float(w.occ_them) < 0.02:
			continue
		if o[0] == "annex_all" and War.goal(w) != "total" and not bool(w.get("capitulated", false)):
			continue
		var ok := War.accepts(i, str(o[0]))
		var tail := "  ·  they accept" if ok else ("  ·  needs their capitulation" if o[0] == "annex_all" else "  ·  they'll refuse")
		m.choice(str(o[1]), str(o[2]) + tail, &"PrimaryButton" if ok else &"", func() -> void:
			if War.accepts(i, str(o[0])):
				var text := War.make_peace(i, str(o[0]))
				Haptics.success()
				m.dismiss()
				var gs := parent
				if gs.has_method("_notify"):
					gs._notify(text, "flag", DS.GOLD if o[0] == "annex_all" else DS.GREEN, true)
				if o[0] == "annex_all" and "map" in gs and gs.map != null:
					gs.map.celebrate("fireworks", Game.player)
					gs.map.focus_country(Game.player)
					Audio.play("fanfare", -5.0)
			else:
				Haptics.warning()
				m.dismiss()
				Game.add_feed("%s rejects your peace terms" % World.The_name(i), "flag", "orange"))
	m.choice("Keep fighting", "", &"GhostButton", m.dismiss)
