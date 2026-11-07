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

	var again := AppButton.make("Lead another nation", &"PrimaryButton", "globe")
	again.custom_minimum_size = Vector2(0, 52)
	again.pressed.connect(func() -> void:
		SaveManager.delete_slot(SaveManager.active_slot)
		Game.end_session()
		Router.goto("res://ui/screens/country_picker.tscn"))
	col.add_child(again)

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
