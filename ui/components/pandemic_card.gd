class_name PandemicCard
extends VBoxContainer
## Pandemic response (Economy page, only while a pandemic is on): the outbreak at
## home and abroad, hospitals, vaccines, and your measures.


func refresh() -> void:
	for ch in get_children():
		ch.queue_free()
	visible = Game.has_game() and Game.dip.has("pandemic") and Pandemic.active()
	if not visible:
		return
	add_theme_constant_override(&"separation", DS.S3)
	var s := Pandemic.st()
	var me := Game.me()
	var inf := Pandemic.infected()
	var cap := Pandemic.capacity(me)
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	card.add_child(v)
	# Header photo with the headline numbers.
	var ph := Photo.scene("pandemic", 116.0, true)
	ph.set(&"fade_bottom", 0.55)
	var over := VBoxContainer.new()
	over.alignment = BoxContainer.ALIGNMENT_END
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(over)
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.offset_left = DS.S4
	over.offset_right = -DS.S4
	over.offset_bottom = -DS.S3
	var t := Label.new()
	t.theme_type_variation = &"PhotoTitle"
	t.text = "The %s" % str(s.name)
	over.add_child(t)
	var c := Label.new()
	c.theme_type_variation = &"PhotoCaption"
	c.text = "Month %d of the pandemic  ·  %d countries affected" % [Game.months_played - int(s.start) + 1, (s.inf as Dictionary).size()]
	over.add_child(c)
	v.add_child(ph)
	# Numbers.
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", DS.S2)
	g.add_theme_constant_override(&"v_separation", DS.S2)
	v.add_child(g)
	_tile(g, "Infected now", _pct(inf), DS.RED if inf > cap else (DS.ORANGE if inf > 0.001 else DS.GREEN))
	_tile(g, "Deaths", DS.compact(float(s.deaths)), DS.TEXT)
	_tile(g, "Hospitals", ("Overwhelmed" if inf > cap else "%d%% full" % roundi(inf / maxf(cap, 0.0001) * 100.0)), DS.RED if inf > cap else DS.TEXT)
	var vac := Pandemic.share(Game.player, "vac")
	var vtext := "%d%% vaccinated" % roundi(vac * 100.0) if Pandemic.vaccine_ready() else ("%d%% ready" % roundi(maxf(float(s.vaccine_world), float(s.vaccine_own)) * 100.0))
	_tile(g, "Vaccine", vtext, DS.GREEN if Pandemic.vaccine_ready() else DS.ACCENT)
	var vnote := Label.new()
	vnote.theme_type_variation = &"Caption"
	vnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vnote.custom_minimum_size = Vector2(60, 0)
	if Pandemic.vaccine_ready():
		vnote.text = "Vaccination speed follows your clinics and hospitals (Build tab)."
	elif Pandemic.own_vaccine_possible():
		vnote.text = "Your mRNA scientists are racing to make your own vaccine: %d%% there." % roundi(maxf(float(s.vaccine_own), 0.0) * 100.0)
	else:
		vnote.text = "A world vaccine is %d%% of the way. Research mRNA vaccines to make your own, much sooner." % roundi(float(s.vaccine_world) * 100.0)
	v.add_child(vnote)
	# Lockdown.
	var lh := Label.new()
	lh.theme_type_variation = &"Overline"
	lh.text = "LOCKDOWN"
	v.add_child(lh)
	var seg := SegmentedControl.new().setup(PackedStringArray(Pandemic.LOCKDOWN), [], int(s.get("lockdown", 0)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Pandemic.set_policy("lockdown", k)
		Haptics.select()
		Simulation.update_finances(Game.me())
		_hint())
	v.add_child(seg)
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"Caption"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(60, 0)
	v.add_child(_hint_label)
	_hint()
	# Other measures.
	for row in [["masks", "Masks in public", "shield", "Cheap; slows spread a little"],
			["testing", "Mass testing and tracing", "scan-search", "Slows spread; costs %s of GDP a year" % DS.pct(Economy.PAN_TESTING_COST, 1)],
			["borders", "Close the borders", "plane-landing", "Keeps new cases out; hurts trade and tourism"]]:
		var tg := AppToggle.new().setup(str(row[1]), bool(s.get(str(row[0]), false)), str(row[2]))
		var key := str(row[0])
		tg.toggled.connect(func(on: bool) -> void:
			Pandemic.set_policy(key, on)
			Haptics.select()
			Simulation.update_finances(Game.me()))
		v.add_child(tg)
		var d := Label.new()
		d.theme_type_variation = &"Caption"
		d.text = str(row[3])
		v.add_child(d)


var _hint_label: Label


func _hint() -> void:
	if not is_instance_valid(_hint_label):
		return
	var lock := int(Pandemic.st().get("lockdown", 0))
	var months := int(Pandemic.st().get("lock_months", 0))
	_hint_label.text = ["Life goes on as normal. The disease spreads freely.",
		"Big gatherings banned, offices half empty: spread slows a lot, the economy dips.",
		"Everyone stays home: spread nearly stops, but jobs and patience suffer."][lock]
	if lock > 0 and months >= 6:
		_hint_label.text += " People are tiring of it after %d months." % months


static func _pct(x: float) -> String:
	if x <= 0.0:
		return "0%"
	if x < 0.001:
		return "<0.1%"
	return DS.pct(x * 100.0, 1)


func _tile(parent: Control, t: String, val: String, color: Color) -> void:
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
	c.text = val
	c.clip_text = true
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.custom_minimum_size = Vector2(30, 0)
	c.add_theme_color_override(&"font_color", color)
	b.add_child(c)
