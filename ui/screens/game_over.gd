extends Control
## End of term: a calm summary of the player's time in office.

var data: Dictionary = {}


func _ready() -> void:
	if not Game.has_game():
		Game.new_game(World.index_of("IND"))
	data = Game.summary(Game.get_meta(&"end_reason", "election"))
	add_child(OceanBackground.new())
	var map := MapView.new()
	map.interactive = false
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.modulate.a = 0.55
	add_child(map)
	map.set_player(Game.player)
	map.focus_country.call_deferred(Game.player, 0.01)

	var card := GlassPanel.new()
	card.theme_type_variation = &"GlassSheet"
	card.tint = DS.GLASS_TINT_STRONG
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", DS.S4)
	card.add_child(col)

	var reason := str(data.reason)
	var over := Label.new()
	over.theme_type_variation = &"Overline"
	over.text = "%d – %d" % [int(data.from), int(data.to)]
	col.add_child(over)
	var title := Label.new()
	title.theme_type_variation = &"LargeTitle"
	title.text = "Your term has ended"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var sub := Label.new()
	sub.theme_type_variation = &"BodySecondary"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.text = {
		"election": "The people of %s chose a new leader." % data.country,
		"collapse": "Unrest brought down your government in %s." % data.country,
	}.get(reason, "You led %s for %.1f years." % [data.country, float(data.years)])
	col.add_child(sub)

	# Legacy grade
	var parts := Economy.legacy_parts(data)
	var score := 50.0
	for p in parts:
		score += float(p[1])
	var grade := Economy.legacy_grade(score)
	var grade_row := HBoxContainer.new()
	grade_row.add_theme_constant_override(&"separation", DS.S4)
	col.add_child(grade_row)
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"GradeBadge"
	badge.custom_minimum_size = Vector2(76, 76)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grade_row.add_child(badge)
	var gl := Label.new()
	gl.theme_type_variation = &"LargeTitle"
	gl.text = grade
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.add_theme_color_override(&"font_color", DS.GOLD if grade.begins_with("A") else (DS.TEXT if grade in ["B", "C"] else DS.RED))
	badge.add_child(gl)
	var gv := VBoxContainer.new()
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_theme_constant_override(&"separation", 2)
	grade_row.add_child(gv)
	var go := Label.new()
	go.theme_type_variation = &"Overline"
	go.text = "YOUR LEGACY"
	gv.add_child(go)
	var gt := Label.new()
	gt.theme_type_variation = &"Title2"
	gt.text = str(Economy.LEGACY_TITLES[grade])
	gv.add_child(gt)
	var best: Array = parts[0]
	var worst: Array = parts[0]
	for p in parts:
		if float(p[1]) > float(best[1]):
			best = p
		if float(p[1]) < float(worst[1]):
			worst = p
	var gs := Label.new()
	gs.theme_type_variation = &"Footnote"
	gs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gs.text = "Strongest: %s%s" % [str(best[0]).to_lower(), "" if float(worst[1]) >= 0.0 else "
Weakest: %s" % str(worst[0]).to_lower()]
	gv.add_child(gs)
	badge.pivot_offset = Vector2(38, 38)
	badge.scale = Vector2.ONE * 0.6
	badge.modulate.a = 0.0
	var bt := create_tween().set_parallel(true)
	DS.spring(bt)
	bt.tween_property(badge, "scale", Vector2.ONE, 0.6).set_delay(0.5)
	bt.tween_property(badge, "modulate:a", 1.0, 0.3).set_delay(0.5)

	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	col.add_child(g)
	_stat(g, "Years in office", String.num(float(data.years), 1))
	_stat(g, "Elections won", str(int(data.elections_won)))
	_stat(g, "GDP", "%s → %s" % [DS.money(float(data.gdp_start)), DS.money(float(data.gdp_end))])
	_stat(g, "Real growth / yr", DS.pct(float(data.avg_growth), 1))
	_stat(g, "Debt / GDP", "%s → %s" % [DS.pct(float(data.debt_start), 0), DS.pct(float(data.debt_end), 0)])
	_stat(g, "Final approval", DS.pct(float(data.approval), 0))

	var share := AppButton.make("Share my legacy", &"", "arrow-up-right")
	share.custom_minimum_size = Vector2(0, 48)
	col.add_child(share)
	var again := AppButton.make("Lead another nation", &"PrimaryButton", "globe")
	again.custom_minimum_size = Vector2(0, 52)
	again.pressed.connect(func() -> void:
		SaveManager.delete_slot(SaveManager.active_slot)
		Game.end_session()
		Router.goto("res://ui/screens/country_picker.tscn"))
	col.add_child(again)
	share.pressed.connect(func() -> void:
		Haptics.tap()
		var msg: String = await Share.share_screen(get_tree(), "I led %s for %.1f years and earned a %s legacy." % [
			str(data.country), float(data.years), grade], [share, again])
		if msg != "":
			Toast.show_headline(self, msg, "info", DS.ACCENT, Screen.top + DS.S4))

	resized.connect(func() -> void: _place(card))
	_place.call_deferred(card)
	Haptics.warning()


func _stat(parent: Control, t: String, v: String) -> void:
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
	b.add_child(a)
	var c := Label.new()
	c.theme_type_variation = &"StatSmall"
	c.text = v
	b.add_child(c)


func _place(card: Control) -> void:
	var w := size.x - DS.S4 * 2.0
	card.size = Vector2(w, card.get_combined_minimum_size().y)
	card.position = Vector2(DS.S4, size.y - Screen.bottom - DS.S4 - card.size.y)
