class_name ElectionCard
extends PanelContainer
## The road to the next election (Economy page, free and managed elections):
## today's poll, your promises and whether they're on track, the campaign trail
## in the last three months, and your coalition partner's demand.


func _init() -> void:
	theme_type_variation = &"GroupPanel"


func refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	visible = Game.has_game() and Government.has_elections(Game.player)
	if not visible:
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	add_child(v)
	var p := Game.politics
	var poll := p.poll()
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Next election"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var m := Label.new()
	m.theme_type_variation = &"Subhead"
	m.text = "in %d %s" % [p.months_to_election, "month" if p.months_to_election == 1 else "months"]
	head.add_child(m)
	# Poll bar with the 50 % line.
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(pr)
	var pl := Label.new()
	pl.theme_type_variation = &"StatValue"
	pl.text = "%d%%" % roundi(poll)
	pl.add_theme_color_override(&"font_color", DS.GREEN if poll >= 52.0 else (DS.ORANGE if poll >= 48.0 else DS.RED))
	pr.add_child(pl)
	var pc := Label.new()
	pc.theme_type_variation = &"Caption"
	pc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.custom_minimum_size = Vector2(40, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.text = "would vote for you today. " + ("Comfortably ahead." if poll >= 55.0 else ("Neck and neck." if poll >= 47.0 else "Behind: you need to win people back."))
	pr.add_child(pc)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 2, w, 6))
		var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		f.bg_color = DS.GREEN if poll >= 50.0 else DS.ORANGE
		bar.draw_style_box(f, Rect2(0, 2, maxf(w * poll / 100.0, 6.0), 6))
		bar.draw_rect(Rect2(w * 0.5 - 1, 0, 2, 10), Color(1, 1, 1, 0.6)))
	v.add_child(bar)
	# Promises.
	var pledges: Array = Manifesto.st().pledges
	if not pledges.is_empty():
		var oh := Label.new()
		oh.theme_type_variation = &"Overline"
		oh.text = "YOUR PROMISES"
		v.add_child(oh)
		for pg in pledges:
			var info: Dictionary = Manifesto.PLEDGES[str(pg.id)]
			var stt: Array = Manifesto.status(pg)
			var ok := int(stt[0]) > 0
			var row := ListRow.new().setup(str(info.title), str(stt[1]), "On track" if ok else "Off track")
			row.trailing_label.theme_type_variation = &"Caption"
			row.trailing_label.add_theme_color_override(&"font_color", DS.GREEN if ok else DS.ORANGE)
			row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			row.set_leading(ListRow.icon_tile(str(info.icon), DS.GREEN if ok else DS.ORANGE))
			v.add_child(row)
	# Coalition.
	var co := Manifesto.coalition()
	if not co.is_empty():
		var met := Manifesto.demand_met()
		var left := maxi(0, int(co.since) + Economy.MANI_DEMAND_MONTHS - Game.months_played)
		var row2 := ListRow.new().setup("Coalition with the %s" % str(co.name), ("They wanted %s: done" % str(co.ask)) if met
			else "They want %s within %d months, or they walk out" % [str(co.ask), left])
		row2.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row2.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row2.set_leading(ListRow.icon_tile("handshake", DS.GREEN if met else DS.ORANGE))
		v.add_child(row2)
	# Campaign trail.
	if Manifesto.trail_open():
		var left2 := Manifesto.trail_left()
		var th := Label.new()
		th.theme_type_variation = &"Overline"
		th.text = "CAMPAIGN TRAIL  ·  %d %s LEFT" % [left2, "ACTION" if left2 == 1 else "ACTIONS"]
		v.add_child(th)
		if left2 > 0:
			var rl := Label.new()
			rl.theme_type_variation = &"Caption"
			rl.text = "Hold a rally with one group, run TV ads, or send volunteers door to door:"
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size = Vector2(60, 0)
			v.add_child(rl)
			var g := GridContainer.new()
			g.columns = 2
			g.add_theme_constant_override(&"h_separation", DS.S2)
			g.add_theme_constant_override(&"v_separation", DS.S2)
			v.add_child(g)
			var sup := Blocs.support(Game.me())
			var weakest := ""
			var low := 999.0
			for grp in Blocs.IDS:
				if float(sup[grp]) < low:
					low = float(sup[grp])
					weakest = str(grp)
			for grp in Blocs.IDS:
				var gid := str(grp)
				var b := AppButton.make(str(Blocs.INFO[gid].title).replace(" voters", "").replace("Young people", "Youth"), &"Chip", str(Blocs.INFO[gid].icon))
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.custom_minimum_size = Vector2(60, 0)
				b.clip_text = true
				b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				b.pressed.connect(_do.bind("rally", gid))
				g.add_child(b)
			var ads := AppButton.make("TV ads", &"Chip", "tv")
			ads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ads.custom_minimum_size = Vector2(60, 0)
			ads.clip_text = true
			ads.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			ads.pressed.connect(_do.bind("ads", ""))
			g.add_child(ads)
			var door := AppButton.make("Doorstep", &"Chip", "house")
			door.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			door.custom_minimum_size = Vector2(60, 0)
			door.clip_text = true
			door.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			door.pressed.connect(_do.bind("door", ""))
			g.add_child(door)
			var hint := Label.new()
			hint.theme_type_variation = &"Caption"
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.custom_minimum_size = Vector2(60, 0)
			hint.text = "Your weakest group: %s (%d%%). A rally there helps most." % [str(Blocs.INFO[weakest].title).to_lower(), roundi(low)]
			v.add_child(hint)


func _do(kind: String, group: String) -> void:
	var text := Manifesto.trail(kind, group)
	if text == "":
		return
	Simulation.update_finances(Game.me())
	Haptics.success()
	var gs := get_tree().current_scene
	if gs and gs.has_method("_notify"):
		gs._notify(text, str(Manifesto.TRAIL[kind].icon), DS.GOLD, false, false)
	refresh()
