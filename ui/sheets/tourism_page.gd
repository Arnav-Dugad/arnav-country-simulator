class_name TourismPage
extends SheetPage
## Tourism & soft power: visitors, world heritage nominations, bids for world
## events and your soft power rank (see Tourism).

var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "Tourism"


func _build() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


func refresh() -> void:
	if Game.me() == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	var s := Tourism.st()
	var d := Tourism.share() / maxf(float(s.share0), 0.01) - 1.0
	_box.add_child(photo_header("tourism", "Tourism & soft power", "%s visitors a year  ·  %s since you took office" % [
		_visitors(Tourism.visitors()), ("+" if d >= 0.0 else "−") + "%d%%" % roundi(absf(d) * 100.0)], 140.0))
	_overview()
	_events()
	_heritage()


static func _visitors(m: float) -> String:
	if m >= 1000.0:
		return "%s billion" % String.num(m / 1000.0, 1)
	if m >= 1.0:
		return "%s million" % String.num(m, 1 if m < 10.0 else 0)
	return "%d thousand" % roundi(m * 1000.0)


func _overview() -> void:
	var g := grid(_box, 2)
	var sp := Tourism.soft_power(Game.player)
	g.add_child(_tile("sparkles", DS.PURPLE, "Soft power", "%d / 100" % roundi(sp), "Rank %d in the world" % Tourism.rank()))
	g.add_child(_tile("plane-takeoff", DS.TEAL, "Tourism", DS.pct(Tourism.share(), 1), "of GDP  ·  appeal %d%%" % roundi(Tourism.appeal() * 100.0)))
	note("Soft power is how much the world admires you: your economy, freedom, clean government, culture and what you do abroad. Gaining it slowly warms every country toward you; wars, crackdowns and exposed spies cost it.", _box)


func _tile(icon: String, color: Color, head: String, value: String, sub: String) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"TilePanel"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 6)
	v.add_child(h)
	var ic := TextureRect.new()
	ic.texture = DS.icon(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(16, 16)
	ic.modulate = color
	h.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Caption"
	t.text = head.to_upper()
	h.add_child(t)
	var val := Label.new()
	val.theme_type_variation = &"StatValue"
	val.text = value
	v.add_child(val)
	var c := Label.new()
	c.theme_type_variation = &"Caption"
	c.text = sub
	c.clip_text = true
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.custom_minimum_size = Vector2(30, 0)
	v.add_child(c)
	return p


# ------------------------------------------------------------- mega events ---
func _events() -> void:
	var s := Tourism.st()
	var box := section("World events", _box)
	var host: Dictionary = s.host
	var bid: Dictionary = s.bid
	if not host.is_empty():
		var ev: Dictionary = Tourism.EVENTS[str(host.ev)]
		var left := int(host.year_m) - Game.months_played
		box.add_child(photo_header("games", str(ev.title), ("Opens in %d months  ·  preparations cost %s a year" % [left, DS.money(Game.me().gdp * Tourism.spending_pct() / 100.0)])
			if left > 0 else "Happening now: the world is watching", 120.0))
		if left > 0:
			box.add_child(meter(1.0 - float(left) / float(ev.prep), 0.0, DS.GOLD, 4.0))
	elif not bid.is_empty():
		var ev2: Dictionary = Tourism.EVENTS[str(bid.ev)]
		var row := ListRow.new().setup("Bid for the %s" % str(ev2.title), "The vote is in %d months  ·  about %d%% chance" % [
			maxi(0, int(bid.start) + Economy.TOUR_BID_MONTHS - Game.months_played), roundi(float(bid.p) * 100.0)])
		row.set_leading(ListRow.icon_tile(str(ev2.icon), DS.GOLD))
		box.add_child(row)
	else:
		note("Bid to host a world event. The vote comes a year later; soft power and stability win votes.", box)
		for id in Tourism.EVENTS:
			box.add_child(_event_row(str(id)))
	if not (s.hosted as Array).is_empty():
		var names: PackedStringArray = []
		for e in s.hosted:
			names.append(str(Tourism.EVENTS[str(e)].title))
		note("Hosted: " + ", ".join(names), box)


func _event_row(id: String) -> Control:
	var ev: Dictionary = Tourism.EVENTS[id]
	var why := Tourism.can_bid(id)
	var sub := why if why != "" else "Costs %s over %d years  ·  win chance %d%%" % [
		DS.money(Game.me().gdp * float(ev.cost) / 100.0), int(ev.prep) / 12, roundi(Tourism.bid_chance(id) * 100.0)]
	var row := ListRow.new().setup(str(ev.title), sub, "›" if why == "" else "")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
	row.set_leading(ListRow.icon_tile(str(ev.icon), DS.GOLD if why == "" else DS.TEXT_3))
	if why == "":
		row.tapped.connect(_confirm_bid.bind(id))
	return row


func _confirm_bid(id: String) -> void:
	var ev: Dictionary = Tourism.EVENTS[id]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(ev.icon), DS.GOLD, "Bid to host", str(ev.title))
	m.body("If you win, you spend about %s over %d years on venues, transport and security. Then a year in the spotlight: tourists pour in, people are proud and the world admires you." % [
		DS.money(Game.me().gdp * float(ev.cost) / 100.0), int(ev.prep) / 12])
	m.choice("Submit the bid", "Bid campaign: %s  ·  win chance %d%%" % [DS.money(Tourism.bid_cost(id)), roundi(Tourism.bid_chance(id) * 100.0)], &"PrimaryButton", func() -> void:
		if Tourism.place_bid(id):
			Simulation.update_finances(Game.me())
			Haptics.success()
		m.dismiss()
		refresh(), [["Tourism +%d%% that year" % roundi(float(ev.boost) * 100.0), DS.GREEN], ["Soft power +%d" % int(ev.soft), DS.GREEN]])
	m.choice("Not now", "", &"GhostButton", m.dismiss)


# ---------------------------------------------------------------- heritage ---
func _heritage() -> void:
	var s := Tourism.st()
	var box := section("World heritage", _box)
	for site in s.sites:
		var r := ListRow.new().setup(str(site.name), "Listed %d" % int(site.year))
		r.set_leading(ListRow.icon_tile(str(Tourism.SITES[str(site.kind)][1]), DS.GOLD))
		box.add_child(r)
	for n in s.noms:
		var left := maxi(0, int(n.start) + Economy.TOUR_NOMINATE_MONTHS - Game.months_played)
		var r2 := ListRow.new().setup(str(n.name), "Under review  ·  decision in %d months" % left)
		r2.set_leading(ListRow.icon_tile(str(Tourism.SITES[str(n.kind)][1]), DS.ORANGE))
		box.add_child(r2)
	note("Nominate a place: %s each, decided in %d months (about %d%% are accepted). Every listed site brings visitors and prestige." % [
		DS.money(Tourism.nominate_cost()), Economy.TOUR_NOMINATE_MONTHS, roundi(Tourism.nomination_chance() * 100.0)], box)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", DS.S2)
	flow.add_theme_constant_override(&"v_separation", DS.S2)
	box.add_child(flow)
	for kind in Tourism.SITES:
		var why := Tourism.can_nominate(str(kind))
		var b := AppButton.make(str(Tourism.SITES[kind][0]), &"Chip", str(Tourism.SITES[kind][1]))
		b.disabled = why != ""
		b.pressed.connect(func() -> void:
			if Tourism.nominate(str(kind)):
				Simulation.update_finances(Game.me())
				Haptics.success()
			refresh())
		flow.add_child(b)
