class_name WarRoom
extends RefCounted
## The war room for one war: who holds what, morale, casualties, recent battles,
## and what you can do (mobilize, call allies, offer peace).


static func open(parent: Node, i: int) -> void:
	var w := War.with(i)
	if w.is_empty():
		return
	var m := ModalCard.new()
	parent.add_child(m)
	m.content.add_child(Illustration.banner("war", "swords", DS.RED, 104.0))
	var months := Game.months_played - int(w.start)
	m.header("swords", DS.RED, "War · month %d" % (months + 1), "%s vs %s" % [World.map.names[Game.player], World.map.names[i]])
	# Ground held: a two-sided bar (your gains right, their gains left).
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var occ_me := float(w.occ_me)
	var occ_them := float(w.occ_them)
	bar.draw.connect(func() -> void:
		var wd := bar.size.x
		var mid := wd * 0.5
		bar.draw_rect(Rect2(0, 10, wd, 8), Color(1, 1, 1, 0.08))
		bar.draw_rect(Rect2(mid, 10, mid * minf(occ_them / 0.6, 1.0), 8), DS.GREEN)
		bar.draw_rect(Rect2(mid - mid * minf(occ_me / 0.6, 1.0), 10, mid * minf(occ_me / 0.6, 1.0), 8), DS.RED)
		bar.draw_rect(Rect2(mid - 1, 4, 2, 20), Color(1, 1, 1, 0.7)))
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
	held.text = ", ".join(parts) + "."
	m.content.add_child(held)
	# Numbers.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", DS.S2)
	grid.add_theme_constant_override(&"v_separation", DS.S2)
	m.content.add_child(grid)
	_tile(grid, "Battle odds", "%d%%" % roundi(War.odds(i) * 100.0))
	_tile(grid, "Morale", "%d%% / %d%%" % [roundi(float(w.morale_me) * 100.0), roundi(float(w.morale_them) * 100.0)])
	_tile(grid, "Casualties (you)", DS.compact(float(w.cas_me)))
	_tile(grid, "Casualties (them)", DS.compact(float(w.cas_them)))
	# Recent battles.
	var log_: Array = w.get("log", [])
	if not log_.is_empty():
		var lh := Label.new()
		lh.theme_type_variation = &"Overline"
		lh.text = "RECENT BATTLES"
		m.content.add_child(lh)
		for e in log_.slice(0, 3):
			var l := Label.new()
			l.theme_type_variation = &"Caption"
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
	m.choice("Offer peace", "Propose terms; they'll say yes only if the war gives them reason to", &"", func() -> void:
		m.dismiss()
		peace_terms(parent, i))
	m.choice("Close", "", &"GhostButton", m.dismiss)


static func _tile(parent: Control, t: String, v: String) -> void:
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
	b.add_child(c)


static func peace_terms(parent: Node, i: int) -> void:
	var w := War.with(i)
	var m := ModalCard.new()
	parent.add_child(m)
	m.header("flag", DS.GOLD, "Peace talks", "Terms for %s" % World.map.names[i])
	m.body("Choose what you ask for. Greedy terms only work when you're clearly winning.")
	var opts := [["annex", "Keep the land you hold", "They cede %d%% of their country" % roundi(float(w.occ_them) * Economy.WAR_ANNEX_SHARE * 100.0)],
		["reparations", "Demand reparations", "They pay %s of their GDP" % DS.pct(Economy.WAR_REPARATIONS * 100.0, 0)],
		["status_quo", "Return to the old borders", "Everyone goes home"]]
	for o in opts:
		if o[0] == "annex" and float(w.occ_them) < 0.02:
			continue
		var ok := War.accepts(i, str(o[0]))
		m.choice(str(o[1]), str(o[2]) + ("  ·  likely yes" if ok else "  ·  they'll refuse"), &"PrimaryButton" if ok else &"", func() -> void:
			if War.accepts(i, str(o[0])):
				var text := War.make_peace(i, str(o[0]))
				Haptics.success()
				m.dismiss()
				var gs := parent
				if gs.has_method("_notify"):
					gs._notify(text, "flag", DS.GREEN, true)
			else:
				Haptics.warning()
				m.dismiss()
				Game.add_feed("%s rejects your peace terms" % World.The_name(i), "flag", "orange"))
	m.choice("Keep fighting", "", &"GhostButton", m.dismiss)
