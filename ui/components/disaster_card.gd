class_name DisasterCard
extends VBoxContainer
## The disaster response (Economy page, while an emergency or rebuild is on):
## what happened, people affected and lost, and your response actions.


func refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	visible = Game.has_game() and Game.dip.has("dis") and Disasters.active()
	if not visible:
		return
	add_theme_constant_override(&"separation", DS.S3)
	var d: Dictionary = Disasters.st().active
	var spec: Dictionary = Disasters.TYPES[str(d.kind)]
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(v)
	var ph := Photo.scene(str(spec.scene), 116.0, true)
	ph.set(&"fade_bottom", 0.55)
	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_END
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.offset_left = DS.S4
	over.offset_right = -DS.S4
	over.offset_bottom = -DS.S3
	var emergency := str(d.phase) == "emergency"
	var t := Label.new()
	t.theme_type_variation = &"PhotoTitle"
	t.text = str(spec.title) + (": emergency" if emergency else ": rebuild")
	over.add_child(t)
	var c := Label.new()
	c.theme_type_variation = &"PhotoCaption"
	c.text = "%s people affected  ·  %s lives lost" % [DS.compact(float(d.affected)), DS.compact(float(d.deaths))]
	over.add_child(c)
	v.add_child(ph)
	var relief := clampf(float(d.relief), 0.0, 0.9)
	var rh := HBoxContainer.new()
	v.add_child(rh)
	var rl := Label.new()
	rl.theme_type_variation = &"Subhead"
	rl.text = "Relief effort"
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rl)
	var rv := Label.new()
	rv.theme_type_variation = &"StatSmall"
	rv.text = "%d%%" % roundi(relief / 0.9 * 100.0)
	var col := DS.GREEN if relief >= 0.5 else (DS.ORANGE if relief >= 0.25 else DS.RED)
	rv.add_theme_color_override(&"font_color", col)
	rh.add_child(rv)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, bar.size.x, 6))
		var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		f.bg_color = col
		bar.draw_style_box(f, Rect2(0, 0, maxf(bar.size.x * relief / 0.9, 6.0), 6)))
	v.add_child(bar)
	if emergency:
		var note := Label.new()
		note.theme_type_variation = &"Caption"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(60, 0)
		note.text = "Every month of the emergency, people die who better help could have saved. %d %s left." % [
			maxi(0, Economy.DIS_EMERGENCY_MONTHS - (Game.months_played - int(d.start))), "month" if Economy.DIS_EMERGENCY_MONTHS - (Game.months_played - int(d.start)) == 1 else "months"]
		v.add_child(note)
		var g := GridContainer.new()
		g.columns = 2
		g.add_theme_constant_override(&"h_separation", DS.S2)
		g.add_theme_constant_override(&"v_separation", DS.S2)
		v.add_child(g)
		for a in [["army", "Send the army", "shield"], ["funds", "Emergency funds", "coins"], ["aid", "Ask for aid", "handshake"], ["visit", "Visit the area", "plane"]]:
			var b := AppButton.make(str(a[1]), &"Chip", str(a[2]))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = Disasters.act_done(str(a[0]))
			var key := str(a[0])
			b.pressed.connect(func() -> void:
				var text := Disasters.act(key)
				Simulation.update_finances(Game.me())
				Haptics.success()
				var gs := get_tree().current_scene
				if text != "" and gs and gs.has_method("_notify"):
					gs._notify(text, str(spec.icon), DS.ACCENT, false, false)
				refresh())
			g.add_child(b)
		var hint := Label.new()
		hint.theme_type_variation = &"Caption"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(60, 0)
		hint.text = "Emergency funds cost %s. Visiting only goes down well once help is flowing." % DS.money(Game.me().gdp * Economy.DIS_FUND_COST / 100.0)
		v.add_child(hint)
	else:
		for better in [true, false]:
			var b2 := AppButton.make(("Build back better  ·  %s" if better else "Quick rebuild  ·  %s") % DS.money(Disasters.rebuild_cost(better)),
				&"PrimaryButton" if better else &"", "hammer")
			var bb: bool = better
			b2.pressed.connect(func() -> void:
				var text := Disasters.rebuild(bb)
				Simulation.update_finances(Game.me())
				Haptics.success()
				var gs := get_tree().current_scene
				if gs and gs.has_method("_notify"):
					gs._notify(text, "hammer", DS.GREEN, false, false)
				refresh())
			v.add_child(b2)
		var n2 := Label.new()
		n2.theme_type_variation = &"Caption"
		n2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n2.custom_minimum_size = Vector2(60, 0)
		n2.text = "Building back better costs twice as much but softens every future %s. If you don't choose, your cabinet rebuilds quickly in a few months." % str(spec.title).to_lower()
		v.add_child(n2)
