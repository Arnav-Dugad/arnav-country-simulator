class_name LawsPage
extends SheetPage
## Laws & reforms: what is in force, what is passing, and what you could change.

var _summary: Label
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0   # 0 all, 1 in force, 2 not yet


func _init() -> void:
	super._init()
	title = "Laws"


var _cabinet: VBoxContainer


func _build() -> void:
	add_child(Illustration.banner("parliament", "gavel", DS.ACCENT, 124.0))
	_cabinet = section("Your cabinet")
	_summary = note("")
	_filter = SegmentedControl.new().setup(["All", "In force", "Not yet"], [], 0)
	_filter.plain = true
	_filter.compact = false
	_filter.fill = true
	_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter.changed.connect(func(i: int) -> void:
		_mode = i
		refresh())
	add_child(_filter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S4)
	add_child(_list)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_fill_cabinet()
	var active := 0
	var passing := 0
	for l in Laws.ALL:
		active += 1 if Laws.is_active(c, l.id) else 0
		passing += 1 if Laws.pending_months(c, l.id) > 0 else 0
	_summary.text = "%d %s in force%s. New laws take months to pass, and you can change course while they do." % [
		active, "law" if active == 1 else "laws", "  ·  %d being debated" % passing if passing > 0 else ""]
	if Mandate.active():
		_summary.text = "Your first 100 days: for %d more %s, laws pass faster and voters forgive tough reforms. Use it!" % [
			Mandate.months_left(), "month" if Mandate.months_left() == 1 else "months"]
		_summary.add_theme_color_override(&"font_color", DS.GOLD)
	else:
		_summary.remove_theme_color_override(&"font_color")
	for ch in _list.get_children():
		ch.queue_free()
	for g in Laws.GROUPS:
		var items := Laws.ALL.filter(func(l: Dictionary) -> bool:
			if l.group != g or not Laws.available(c, l):
				return false
			var on := Laws.is_active(c, l.id)
			return _mode == 0 or (_mode == 1 and on) or (_mode == 2 and not on))
		if items.is_empty():
			continue
		var box := section(g, _list)
		for l in items:
			box.add_child(_card(c, l))


func _card(c: CountryState, l: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(top)
	var on := Laws.is_active(c, l.id)
	var pend := Laws.pending_months(c, l.id)
	var tile := ListRow.icon_tile(str(l.icon), DS.GREEN if on else DS.ACCENT)
	top.add_child(tile)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = Laws.title_of(c, l)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.text = str(l.desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(d)
	var status := Label.new()
	status.theme_type_variation = &"BadgeLabel"
	status.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var st := str(c.laws.get(l.id, {}).get("state", ""))
	if st == "passing":
		status.text = "Passing · %d mo" % pend
	elif st == "repealing":
		status.text = "Repealing · %d mo" % pend
	elif on:
		status.text = "In force"
	else:
		status.text = ""
	status.visible = status.text != ""
	top.add_child(status)
	# Effects (what enacting it would do, or what it is doing)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	v.add_child(chips)
	for k in l.fx:
		var val := float(l.fx[k])
		var good: bool = (val > 0.0) == bool(Laws.FX_GOOD_UP[k])
		var text := ""
		if k == "cost" or k == "revenue":
			var money := c.gdp * absf(val) / 100.0
			text = "%s %s/yr" % ["Saves" if (k == "cost" and val < 0.0) else ("Costs" if k == "cost" else ("Raises" if val > 0.0 else "Loses")), DS.money(money)]
		else:
			text = "%s %+.1f" % [Laws.FX_LABELS[k], val]
		chips.add_child(_chip(text, DS.GREEN if good else DS.RED))
	# Who would cheer or boo (voter groups)
	var who := Blocs.law_chips(c, l.id, on and pend == 0)
	if not who.is_empty():
		var likes: Array = who.filter(func(x: Array) -> bool: return x[1]).map(func(x: Array) -> String: return str(x[0]))
		var hates: Array = who.filter(func(x: Array) -> bool: return not x[1]).map(func(x: Array) -> String: return str(x[0]))
		var wl := Label.new()
		wl.theme_type_variation = &"Caption"
		wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var parts: PackedStringArray = []
		if not likes.is_empty():
			parts.append("Popular with " + ", ".join(likes).to_lower())
		if not hates.is_empty():
			parts.append("opposed by " + ", ".join(hates).to_lower())
		wl.text = ("If repealed: " if on and pend == 0 else "") + "; ".join(parts).capitalize().left(1) + "; ".join(parts).substr(1) + "."
		v.add_child(wl)
	# Action
	var b: AppButton
	if pend > 0:
		b = AppButton.make("Stop " + ("passing" if st == "passing" else "repeal"), &"GhostButton", "x")
		b.pressed.connect(func() -> void:
			Laws.cancel(c, l.id)
			Haptics.tap()
			refresh())
	elif on and bool(l.get("oneway", false)):
		return v
	elif on:
		b = AppButton.make("Repeal", &"", "rotate-ccw")
		b.pressed.connect(_confirm.bind(l, true))
	else:
		b = AppButton.make("Pass this law", &"", "gavel")
		b.pressed.connect(_confirm.bind(l, false))
	v.add_child(b)
	return v


func _fill_cabinet() -> void:
	for ch in _cabinet.get_children():
		ch.queue_free()
	var faces := Leaders.cabinet_portraits()
	for post in Cabinet.POSTS:
		var mn: Dictionary = Game.cabinet.ministers.get(post, {})
		if mn.is_empty():
			continue
		var row := ListRow.new().setup(str(mn.name), "%s · %s" % [Cabinet.POST_TITLES[post],
			" & ".join(mn.traits.map(func(t: String) -> String: return str(Cabinet.TRAITS[t].label)))])
		row.set_leading(Photo.portrait(str(faces.get(post, "")), 40.0) if faces.has(post) else _avatar(str(mn.name), post))
		row.tapped.connect(_minister_card.bind(post))
		_cabinet.add_child(row)


static func _avatar(name: String, post: String) -> Control:
	var tint: Color = {"finance": DS.GREEN, "foreign": DS.ACCENT, "interior": DS.ORANGE, "social": DS.PURPLE}.get(post, DS.ACCENT)
	return Avatar.make(name, tint)


func _minister_card(post: String) -> void:
	var cab := Game.cabinet
	var mn: Dictionary = cab.ministers[post]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	var face := str(Leaders.cabinet_portraits().get(post, ""))
	if face != "":
		var holder := CenterContainer.new()
		holder.add_child(Photo.portrait(face, 112.0, Color(DS.ACCENT, 0.6)))
		m.content.add_child(holder)
	m.header(str(Cabinet.POST_ICONS[post]), DS.ACCENT, "%s minister" % Cabinet.POST_TITLES[post], str(mn.name))
	m.body("
".join(mn.traits.map(func(t: String) -> String:
		return "%s: %s" % [Cabinet.TRAITS[t].label, Cabinet.TRAITS[t].desc])))
	var wait := cab.can_change(post)
	if wait > 0:
		m.body("You can reshuffle this post again in %d months." % wait)
	else:
		var head := Label.new()
		head.theme_type_variation = &"Overline"
		head.text = "REPLACE WITH (APPROVAL −1)"
		m.content.add_child(head)
		var pool: Array = cab.candidates.get(post, [])
		for k in pool.size():
			var cand: Dictionary = pool[k]
			var row := ListRow.new().setup(str(cand.name), " & ".join(cand.traits.map(func(t: String) -> String:
				return "%s (%s)" % [Cabinet.TRAITS[t].label, Cabinet.TRAITS[t].desc])))
			row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
			var cf := Leaders.portrait_for(cand)
			row.set_leading(Photo.portrait(cf, 36.0) if cf != "" else _avatar(str(cand.name), post))
			row.tapped.connect(func() -> void:
				cab.appoint(post, k)
				Simulation.update_finances(Game.me())
				Haptics.success()
				m.dismiss()
				refresh())
			m.content.add_child(row)
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _confirm(l: Dictionary, repeal: bool) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(l.icon), DS.ACCENT, "Repeal law" if repeal else "New law", Laws.title_of(c, l))
	var months := maxi(3, int(l.months * (0.5 if repeal else 1.0)))
	var pol := float(l.politics) * (-0.6 if repeal else 1.0)
	var people := "Voters" if Government.has_elections(c.idx) else "People"
	var mood := people + " will welcome it" if pol > 0.5 else ("Expect some backlash" if pol < -0.5 else people + " are split")
	m.body("%s\n\nIt will take about %d months%s. %s." % [str(l.desc), months,
		" and its effects will reverse" if repeal else " before it takes effect", mood])
	m.choice("Repeal it" if repeal else "Start passing it", "", &"DestructiveButton" if repeal else &"PrimaryButton",
		func() -> void:
			Laws.start(c, l.id)
			Haptics.success()
			var gs := get_tree().current_scene
			if gs and gs.has_method("learned") and not repeal:
				gs.learned("law")
			m.dismiss()
			refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ForecastChip"
	var lbl := Label.new()
	lbl.theme_type_variation = &"ChipValue"
	lbl.add_theme_color_override(&"font_color", color)
	lbl.text = text
	p.add_child(lbl)
	return p
