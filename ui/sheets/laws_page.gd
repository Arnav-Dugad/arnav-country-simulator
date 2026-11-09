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
	collapsible = true
	open_sections = ["Your cabinet", "Health & society", "Economy", "Environment", "Security & governance"]


var _cabinet: VBoxContainer


var _clean: VBoxContainer
var _media: VBoxContainer
var _crime: VBoxContainer
var _black: VBoxContainer
var _hos: VBoxContainer
var _const: VBoxContainer
var _fac: VBoxContainer
var _glance_box: VBoxContainer
var _cult: VBoxContainer
var _capital: Control
var _cap_value: Label
var _cap_note: Label
var _cap_bar: Control


## "Political capital 42 / 100" with a bar and a one-line explanation.
func _capital_bar() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	box.add_child(row)
	var ic := TextureRect.new()
	ic.texture = DS.icon("landmark")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(18, 18)
	ic.modulate = DS.GOLD
	row.add_child(ic)
	var t := Label.new()
	t.theme_type_variation = &"Subhead"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text = "Political capital"
	row.add_child(t)
	var v := Label.new()
	v.theme_type_variation = &"StatSmall"
	v.add_theme_color_override(&"font_color", DS.GOLD)
	row.add_child(v)
	_cap_value = v
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, w, 6))
		var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		f.bg_color = DS.GOLD
		bar.draw_style_box(f, Rect2(0, 0, maxf(w * Capital.value() / Economy.CAPITAL_MAX, 6.0), 6)))
	box.add_child(bar)
	_cap_bar = bar
	var n := Label.new()
	n.theme_type_variation = &"Caption"
	_cap_note = n
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(60, 0)
	box.add_child(n)
	return box


func _fill_capital() -> void:
	_cap_value.text = "%s / %d" % [Capital.label(), int(Economy.CAPITAL_MAX)]
	_cap_note.text = "Goodwill you spend on reforms, reshuffles and crackdowns. +%s a month from your %s; elections and goals add more." % [
		String.num(Capital.income(), 1), Government.support_word(Game.player).to_lower()]
	_cap_bar.queue_redraw()


func _fill_clean() -> void:
	for ch in _clean.get_children():
		ch.queue_free()
	var c := Game.me()
	var v := Corruption.value(c)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	_clean.add_child(row)
	row.add_child(ListRow.icon_tile("gavel", DS.GREEN if v >= 60.0 else (DS.ORANGE if v >= 35.0 else DS.RED)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "%d / 100  ·  %s" % [roundi(v), Corruption.label(v)]
	col.add_child(t)
	var d := Corruption.change(c)
	var sub := Label.new()
	sub.theme_type_variation = &"Caption"
	sub.text = ("%+d since you took office" % roundi(d)) if absf(d) >= 0.5 else "Where you started"
	col.add_child(sub)
	var wait := Corruption.drive_wait()
	var b := AppButton.make("Crack down on corruption", &"", "gavel")
	b.disabled = wait > 0 or not Capital.can(Economy.CAPITAL_CRACKDOWN)
	b.text = "Crack down on corruption  ·  %d" % int(Economy.CAPITAL_CRACKDOWN)
	b.pressed.connect(func() -> void:
		if not Capital.spend(Economy.CAPITAL_CRACKDOWN):
			return
		Corruption.launch_drive()
		Haptics.success()
		refresh())
	_clean.add_child(b)
	note(("Next drive possible in %d months. " % wait if wait > 0 else "") +
		"Officials push back at first (approval and stability dip), then government gets cleaner for years: faster growth, cheaper projects, fewer scandals.", _clean)


func _build() -> void:
	add_child(Illustration.banner("parliament", "gavel", DS.ACCENT, 124.0))
	_capital = _capital_bar()
	add_child(_capital)
	_glance_box = VBoxContainer.new()
	add_child(_glance_box)
	add_child(jump_bar(["Your cabinet", "Power brokers", "Culture & values", "Royal family", "Constitution", "Clean government", "Media & propaganda", "Crime & justice", "Black market & smuggling"]))
	_cabinet = section("Your cabinet")
	_fac = section("Power brokers")
	_cult = section("Culture & values")
	_hos = section("Royal family")
	_const = section("Constitution")
	_clean = section("Clean government")
	_media = section("Media & propaganda")
	_crime = section("Crime & justice")
	_black = section("Black market & smuggling")
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


func _fill_glance() -> void:
	for ch in _glance_box.get_children():
		ch.queue_free()
	var c := Game.me()
	var loy := 0.0
	for id in Factions.INFO:
		loy += Factions.loyalty(str(id))
	loy /= float(Factions.INFO.size())
	var cl := Corruption.value(c)
	var cr := Crime.value() if Game.dip.has("crime") else 0.0
	var cred := Press.credibility()
	var cv := Culture.value("progress")
	glance([
		["users", DS.GREEN if loy >= 60.0 else (DS.ORANGE if loy >= 40.0 else DS.RED), "Brokers", "%d" % roundi(loy), "Power brokers"],
		["sparkles", DS.ACCENT, "Values", "Modern" if cv > 15.0 else ("Classic" if cv < -15.0 else "Mixed"), "Culture & values"],
		["gavel", DS.GREEN if cl >= 65.0 else (DS.ORANGE if cl >= 40.0 else DS.RED), "Integrity", "%d" % roundi(cl), "Clean government"],
		["newspaper", DS.GREEN if cred >= 60.0 else (DS.ORANGE if cred >= 40.0 else DS.RED), "Trust", "%d" % roundi(cred), "Media & propaganda"],
		["siren", DS.GREEN if cr < 35.0 else (DS.ORANGE if cr < 55.0 else DS.RED), "Crime", "%d" % roundi(cr), "Crime & justice"],
		["scroll-text", DS.GOLD, "Charter", "%d articles" % Constitution.ARTICLES.size(), "Constitution"],
	], _glance_box)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_fill_capital()
	_fill_glance()
	_fill_cabinet()
	_fill_clean()
	_fill_media()
	_fill_crime()
	_fill_black()
	_fill_hos()
	_fill_const()
	_fill_fac()
	_fill_cult()
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
	if Climate.CUTS.has(l.id) and not c.laws_start.has(l.id):
		chips.add_child(_chip("CO₂ −%d%%" % roundi(float(Climate.CUTS[l.id]) * 100.0), DS.GREEN))
	if Inequality.LAW_GINI.has(l.id):
		var gv := float(Inequality.LAW_GINI[l.id])
		chips.add_child(_chip("Inequality %+.1f" % gv, DS.GREEN if gv < 0.0 else DS.RED))
	var cfit := Culture.fit_text(str(l.id))
	if cfit != "" and not Laws.is_active(c, l.id):
		chips.add_child(_chip(cfit, DS.GREEN if Culture.law_fit(str(l.id)) > 0.0 else DS.ORANGE))
	if l.id == "skilled_visas":
		chips.add_child(_chip("Migrants +%s per 1,000" % String.num(Economy.MIG_VISAS, 0), DS.TEXT_2))
	elif l.id == "border_control":
		chips.add_child(_chip("Migrants −%s per 1,000" % String.num(Economy.MIG_BORDER, 1), DS.TEXT_2))
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
		b = AppButton.make("Repeal  ·  %d" % int(Capital.law_cost(l, true)), &"", "rotate-ccw")
		b.pressed.connect(_confirm.bind(l, true))
	else:
		b = AppButton.make("Pass this law  ·  %d" % int(Capital.law_cost(l, false)), &"", "gavel")
		b.pressed.connect(_confirm.bind(l, false))
		if Government.is_free(c.idx) and Blocs.LAW_FX.has(l.id) and not bool(l.get("oneway", false)):
			v.add_child(b)
			var r := AppButton.make("Or hold a referendum", &"GhostButton", "vote")
			r.pressed.connect(_referendum.bind(l))
			v.add_child(r)
			return v
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
		head.text = "REPLACE WITH (APPROVAL −1 · CAPITAL −%d)" % int(Economy.CAPITAL_RESHUFFLE)
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
				if not Capital.spend(Economy.CAPITAL_RESHUFFLE):
					Haptics.warning()
					return
				cab.appoint(post, k)
				Simulation.update_finances(Game.me())
				Haptics.success()
				m.dismiss()
				refresh())
			m.content.add_child(row)
	m.choice("Close", "", &"GhostButton", m.dismiss)


## Ask the people directly: instant if they say yes, shelved if they say no.
func _referendum(l: Dictionary) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.content.add_child(Illustration.banner("election", "ballot", DS.GOLD, 96.0))
	m.header("vote", DS.GOLD, "Referendum", Laws.title_of(c, l))
	var why := Blocs.can_referendum(l.id)
	if why != "":
		m.body(why)
		m.choice("OK", "", &"PrimaryButton", m.dismiss)
		return
	var who := Blocs.law_chips(c, l.id, false)
	var likes: Array = who.filter(func(x: Array) -> bool: return x[1]).map(func(x: Array) -> String: return str(x[0]).to_lower())
	var hates: Array = who.filter(func(x: Array) -> bool: return not x[1]).map(func(x: Array) -> String: return str(x[0]).to_lower())
	m.body("Put it to the people. If they vote yes, it becomes law at once. If they vote no, it's shelved for %d months and you lose a little approval.

Likely for: %s. Likely against: %s." % [
		Blocs.REFERENDUM_BLOCK, ", ".join(likes) if not likes.is_empty() else "nobody in particular",
		", ".join(hates) if not hates.is_empty() else "nobody in particular"])
	m.choice("Call the referendum", "", &"PrimaryButton", func() -> void:
		var r := Blocs.hold_referendum(l.id)
		m.dismiss()
		_referendum_result(r)
		refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _referendum_result(r: Dictionary) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("vote", DS.GOLD, "Referendum result", "Counting…")
	var title: Label = m.content.get_child(0).get_child(1).get_child(1)
	var num := AnimatedNumber.new()
	num.theme_type_variation = &"LargeTitle"
	num.formatter = func(v: float) -> String: return String.num(v, 1) + "% yes"
	num.duration = 1.8
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.content.add_child(num)
	num.set_instant(0.0)
	num.value = float(r.yes)
	Audio.play("election", -4.0)
	await get_tree().create_timer(Settings.dur(1.9)).timeout
	if not is_instance_valid(m):
		return
	title.text = "The people said yes" if r.won else "The people said no"
	title.add_theme_color_override(&"font_color", DS.GOLD if r.won else DS.TEXT_2)
	m.body("%s is now law." % str(r.title) if r.won else "%s is shelved for now." % str(r.title))
	if r.won:
		Haptics.success()
		m.sweep(Color(DS.GOLD, 0.25))
	else:
		Haptics.warning()
	m.choice("OK", "", &"PrimaryButton", m.dismiss)


func _confirm(l: Dictionary, repeal: bool) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(l.icon), DS.ACCENT, "Repeal law" if repeal else "New law", Laws.title_of(c, l))
	var months := maxi(3, int(l.months * (0.5 if repeal else 1.0)))
	var pol := float(l.politics) * (-0.6 if repeal else 1.0)
	var people := "Voters" if Government.has_elections(c.idx) else "People"
	var mood := people + " will welcome it" if pol > 0.5 else ("Expect some backlash" if pol < -0.5 else people + " are split")
	var cost := Capital.law_cost(l, repeal)
	m.body("%s\n\nIt will take about %d months%s. %s. Costs %d political capital (you have %s)." % [str(l.desc), months,
		" and its effects will reverse" if repeal else " before it takes effect", mood, int(cost), Capital.label()])
	if not Capital.can(cost):
		m.choice("Not enough political capital", "Win support, reach goals or wait: it grows every month", &"GhostButton", m.dismiss)
		return
	m.choice("Repeal it" if repeal else "Start passing it", "", &"DestructiveButton" if repeal else &"PrimaryButton",
		func() -> void:
			Capital.spend(cost)
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


# ------------------------------------------------------------------- media ---
func _fill_media() -> void:
	for ch in _media.get_children():
		ch.queue_free()
	var cred := Press.credibility()
	var stance := Media.stance()
	_media.add_child(photo_header("press", "Media & press", "%s  ·  credibility %d / 100" % [
		str(Media.STANCE[stance].title), roundi(cred)], 118.0))
	# Stance.
	var labels := PackedStringArray()
	for sid in Media.STANCES:
		labels.append(str(Media.STANCE[sid].title))
	var seg := SegmentedControl.new().setup(labels, [], Media.rank(stance))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(i: int) -> void:
		seg.select(Media.rank(Media.stance()), false)
		_confirm_stance(str(Media.STANCES[i])))
	_media.add_child(seg)
	var sd := Label.new()
	sd.theme_type_variation = &"Footnote"
	sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sd.custom_minimum_size = Vector2(60, 0)
	sd.text = str(Media.STANCE[stance].desc)
	_media.add_child(sd)
	# Credibility.
	var cc := DS.GREEN if cred >= 60.0 else (DS.ORANGE if cred >= 35.0 else DS.RED)
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", DS.S3)
	_media.add_child(r)
	r.add_child(ListRow.icon_tile("newspaper", cc))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Credibility"
	col.add_child(t)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	cap.text = "How much people believe you" + (("  ·  capped at %d under a %s press" % [roundi(Media.cred_cap()), str(Media.STANCE[stance].title).to_lower()]) if Media.cred_cap() < 100.0 else "")
	col.add_child(cap)
	var v := Label.new()
	v.theme_type_variation = &"StatSmall"
	v.text = str(roundi(cred))
	v.add_theme_color_override(&"font_color", cc)
	r.add_child(v)
	_media.add_child(meter(cred / 100.0, Media.cred_cap() / 100.0 if Media.cred_cap() < 100.0 else 0.0, cc, 4.0))
	# Campaign.
	var cp := Media.campaign()
	if not cp.is_empty():
		var info: Dictionary = Media.CAMPAIGNS[str(cp.id)]
		var row := ListRow.new().setup(str(info.title), ("Leaked: no effect" if bool(cp.get("leaked", false))
			else "%d months left  ·  %d%% strength" % [Media.months_left(), roundi(float(cp.get("power", 1.0)) * 100.0)]))
		row.set_leading(ListRow.icon_tile(str(info.icon), DS.RED if bool(cp.get("leaked", false)) else DS.PURPLE))
		_media.add_child(row)
		var frac := 1.0 - float(Media.months_left()) / float(Economy.MEDIA_CAMPAIGN_MONTHS)
		_media.add_child(meter(frac, 0.0, DS.PURPLE, 4.0))
	else:
		var b := AppButton.make("Launch a media campaign", &"", "megaphone")
		b.pressed.connect(_campaigns)
		_media.add_child(b)
	note("Campaigns reach further when the state controls the media, but work best when people trust you. Repeating a message wears it out.", _media)


func _confirm_stance(sid: String) -> void:
	var why := Media.blocked(sid)
	if why == "Current":
		return
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	var tighten := Media.rank(sid) > Media.rank(Media.stance())
	m.header(str(Media.STANCE[sid].icon), DS.ORANGE if tighten else DS.GREEN, "Media", str(Media.STANCE[sid].title))
	m.body(str(Media.STANCE[sid].desc))
	if tighten:
		m.body("Friendlier coverage lifts approval and calm, but people are less happy, government gets less clean, investors grow wary and democracies cool on you. Expect protests now%s." % (
			", loud ones in a free country" if Government.is_free(Game.player) else ""))
	else:
		m.body("Critical coverage returns: approval loses its cushion, but people are happier, credibility can climb again, graft gets exposed and investors like it.")
	if why != "":
		var w := m.body(why + ".")
		w.add_theme_color_override(&"font_color", DS.ORANGE)
	else:
		m.choice("Tighten control" if tighten else "Free the press", ("Costs %d political capital" % int(Economy.CAPITAL_MEDIA_CONTROL)) if tighten else "",
			&"DestructiveButton" if tighten else &"PrimaryButton", func() -> void:
				Media.set_stance(sid)
				Simulation.update_finances(Game.me())
				if tighten:
					Haptics.warning()
				else:
					Haptics.success()
				m.dismiss()
				refresh())
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


func _campaigns() -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("megaphone", DS.PURPLE, "State media", "Launch a campaign")
	m.body("Six months on every screen. Strength now: reach %d%% × trust %d%%." % [roundi(Media.reach() * 100.0), roundi((0.5 + Press.credibility() / 100.0) * 100.0)])
	for id in Media.CAMPAIGNS:
		var info: Dictionary = Media.CAMPAIGNS[id]
		var why := Media.can_launch(str(id))
		var pw := Media.power(str(id))
		var chips: Array = []
		for k in info.fx:
			var val := float(info.fx[k]) * pw
			match str(k):
				"co2":
					chips.append(["CO₂ −%s%%" % String.num(val * 100.0, 1), DS.GREEN])
				"life":
					chips.append(["Life +%s yrs" % String.num(val, 2), DS.GREEN])
				_:
					chips.append(["%s %+.1f" % [Laws.FX_LABELS.get(k, str(k).capitalize()), val], DS.GREEN])
		chips.append([DS.money(Media.cost(str(id))), DS.ORANGE])
		var detail := str(info.desc)
		if why != "":
			detail = why
		elif pw < Media.reach() * (0.5 + Press.credibility() / 100.0) - 0.01:
			detail += " Used recently: weaker."
		var ch := m.choice(str(info.title), detail, &"GhostButton", func() -> void:
			if Media.launch(str(id)):
				Simulation.update_finances(Game.me())
				Haptics.success()
				Audio.play("success", -8.0)
			m.dismiss()
			refresh(), chips if why == "" else [])
		if why != "":
			for b in ch.find_children("*", "Button", true, false):
				(b as Button).disabled = true
	m.choice("Close", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------------- crime ---
func _fill_crime() -> void:
	for ch in _crime.get_children():
		ch.queue_free()
	var c := Game.me()
	var v := Crime.value()
	var d := Crime.change()
	_crime.add_child(photo_header("justice", "Crime & justice", "%s  ·  %d / 100" % [Crime.label(v), roundi(v)], 118.0))
	var col := DS.GREEN if v < 30.0 else (DS.ORANGE if v < 55.0 else DS.RED)
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", DS.S3)
	_crime.add_child(r)
	r.add_child(ListRow.icon_tile("siren", col))
	var cc := VBoxContainer.new()
	cc.add_theme_constant_override(&"separation", 0)
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(cc)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Crime"
	cc.add_child(t)
	var tgt := Crime.target(c)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	cap.text = ("%+d since you took office" % roundi(d) if absf(d) >= 0.5 else "Where you started") + ("  ·  heading %s" % ("down" if tgt < v - 0.5 else "up") if absf(tgt - v) >= 0.5 else "")
	cc.add_child(cap)
	var val := Label.new()
	val.theme_type_variation = &"StatSmall"
	val.text = str(roundi(v))
	val.add_theme_color_override(&"font_color", col)
	r.add_child(val)
	_crime.add_child(meter(v / 100.0, tgt / 100.0 if tgt > v else 0.0, col, 4.0))
	# What drives it.
	var parts: PackedStringArray = []
	for term in Crime.terms(c):
		if absf(float(term[1])) >= 0.5:
			parts.append("%s %+d" % [str(term[0]).to_lower(), roundi(float(term[1]))])
	if not parts.is_empty():
		note("Pushing it: " + ", ".join(parts) + ".", _crime)
	# Policing.
	var oh := Label.new()
	oh.theme_type_variation = &"Overline"
	oh.text = "POLICING"
	_crime.add_child(oh)
	var labels := PackedStringArray()
	for p in Crime.POLICING:
		labels.append(str(Crime.POLICING_INFO[p].title))
	var seg := SegmentedControl.new().setup(labels, [], Crime.POLICING.find(str(Crime.st().policing)))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Crime.set_policing(str(Crime.POLICING[k]))
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	_crime.add_child(seg)
	note(str(Crime.POLICING_INFO[str(Crime.st().policing)].desc), _crime)
	# Programmes.
	for id in Crime.PROGRAMS:
		var p2: Dictionary = Crime.PROGRAMS[id]
		var pw := Crime.program_power(str(id))
		var why := Crime.can_start(str(id))
		var sub := ""
		if pw > 0.0 or why == "Already running":
			sub = "Running  ·  %d%% effect" % roundi(pw * 100.0)
		else:
			sub = "%s%s  ·  %s" % [DS.money(Crime.program_cost(str(id))), ("  ·  %d capital" % int(p2.capital)) if float(p2.capital) > 0.0 else "", str(p2.desc)]
		var row := ListRow.new().setup(str(p2.title), sub, "›" if why == "" else "")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(p2.icon), DS.GREEN if pw > 0.0 else (DS.ACCENT if why == "" else DS.TEXT_3)))
		if why == "":
			row.tapped.connect(func() -> void:
				if Crime.start_program(str(id)):
					Simulation.update_finances(Game.me())
					Haptics.success()
				refresh())
		_crime.add_child(row)


# ------------------------------------------------------------ black market ---
func _fill_black() -> void:
	for ch in _black.get_children():
		ch.queue_free()
	var c := Game.me()
	var s := Smuggling.st()
	var v := Smuggling.value()
	var d := Smuggling.change()
	var col := DS.GREEN if v < 20.0 else (DS.ORANGE if v < 40.0 else DS.RED)
	var r := HBoxContainer.new()
	r.add_theme_constant_override(&"separation", DS.S3)
	_black.add_child(r)
	r.add_child(ListRow.icon_tile("package", col))
	var cc := VBoxContainer.new()
	cc.add_theme_constant_override(&"separation", 0)
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(cc)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Shadow economy"
	cc.add_child(t)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	var lost := maxf(Smuggling.change(), 0.0) * Economy.BLACK_REVENUE
	cap.text = ("%+d since you took office" % roundi(d) if absf(d) >= 0.5 else "Where you started") + ("  ·  %s a year in lost taxes" % DS.money(c.gdp * lost / 100.0) if lost > 0.001 else "")
	cc.add_child(cap)
	var val := Label.new()
	val.theme_type_variation = &"StatSmall"
	val.text = str(roundi(v))
	val.add_theme_color_override(&"font_color", col)
	r.add_child(val)
	_black.add_child(meter(v / 100.0, 0.0, col, 4.0))
	var parts: PackedStringArray = []
	for term in Smuggling.terms(c):
		if absf(float(term[1])) >= 0.5:
			parts.append("%s %+d" % [str(term[0]).to_lower(), roundi(float(term[1]))])
	if not parts.is_empty():
		note("Pushing it: " + ", ".join(parts) + ".", _black)
	var oh := Label.new()
	oh.theme_type_variation = &"Overline"
	oh.text = "CUSTOMS AGENCY"
	_black.add_child(oh)
	var seg := SegmentedControl.new().setup(PackedStringArray(Smuggling.CUSTOMS), [], int(s.customs))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		Smuggling.set_customs(k)
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	_black.add_child(seg)
	note("Customs costs %s a year." % DS.money(c.gdp * float(Smuggling.CUSTOMS_COST[int(s.customs)]) / 100.0), _black)
	var wait := Smuggling.crackdown_wait()
	var b := AppButton.make("Crack down on smugglers  ·  %d" % int(Economy.BLACK_CRACKDOWN_CAPITAL), &"", "siren")
	b.disabled = wait > 0 or not Capital.can(Economy.BLACK_CRACKDOWN_CAPITAL)
	b.pressed.connect(func() -> void:
		if Smuggling.crackdown():
			Haptics.success()
		refresh())
	_black.add_child(b)
	if wait > 0:
		note("Next crackdown possible in %d months." % wait, _black)
	for id in Smuggling.GOODS:
		var g: Dictionary = Smuggling.GOODS[id]
		var legal := (s.legal as Dictionary).has(id)
		var row := ListRow.new().setup(("%s: legal" if legal else "Legalise %s") % str(g.title).to_lower().capitalize() if legal else "Legalise %s" % str(g.title).to_lower(),
			("Taxed in the open  ·  %s a year" % DS.money(c.gdp * float(g.tax) / 100.0)) if legal else str(g.desc), "" if legal else "›")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(g.icon), DS.GREEN if legal else DS.ACCENT))
		if not legal:
			var gid := str(id)
			row.tapped.connect(func() -> void:
				Smuggling.legalise(gid)
				Simulation.update_finances(Game.me())
				Haptics.success()
				refresh())
		_black.add_child(row)


# ---------------------------------------------------------- head of state ---
func _fill_hos() -> void:
	for ch in _hos.get_children():
		ch.queue_free()
	var s := HeadOfState.st()
	var royal := bool(s.royal)
	var hh: Node = _hos.get_parent().get_parent().get_child(0)
	(hh.get_child(0) if hh is HBoxContainer else hh).set(&"text", ("ROYAL FAMILY" if royal else "FIRST FAMILY"))
	var m: Dictionary = s.monarch
	var pop := HeadOfState.pop()
	var col := DS.GREEN if pop >= 60.0 else (DS.ORANGE if pop >= 40.0 else DS.RED)
	if royal:
		var r := ListRow.new().setup("%s %s" % [HeadOfState.title(m), str(m.name)], "Age %d  ·  popularity %d%%" % [HeadOfState.age(m), roundi(pop)])
		r.set_leading(Photo.portrait(_face(m), 40.0, DS.GOLD))
		_hos.add_child(r)
		var heir: Dictionary = s.heir
		if not heir.is_empty():
			var r2 := ListRow.new().setup(str(heir.name), "Heir to the throne  ·  age %d%s" % [HeadOfState.age(heir), "  ·  married" if bool(s.wed) else ""])
			r2.set_leading(Photo.portrait(_face(heir), 40.0))
			_hos.add_child(r2)
	else:
		var sp: Dictionary = s.spouse
		var r3 := ListRow.new().setup(str(sp.name), "Your spouse  ·  champions %s" % str(s.cause))
		r3.set_leading(Photo.portrait(_face(sp), 40.0))
		_hos.add_child(r3)
	_hos.add_child(meter(pop / 100.0, 0.0, col, 4.0))
	note(("The royal family's popularity steadies the country. Weddings, births and jubilees lift it; scandals sink it. A deeply unpopular monarchy may face calls for a republic." if royal
		else "Your family is in the public eye too. Their causes and scandals reflect on you."), _hos)


static func _face(p: Dictionary) -> String:
	var key := Leaders.portrait_key(Leaders.group_of(Game.player), bool(p.get("female", false)), Leaders.variant_for(str(p.get("name", ""))))
	return Leaders.aged(key) if HeadOfState.age(p) >= 60 else key


# ------------------------------------------------------------ constitution ---
func _fill_const() -> void:
	for ch in _const.get_children():
		ch.queue_free()
	var why := Constitution.amend_blocked()
	note(("Amendments go to a referendum: the people can say no." if Government.is_free(Game.player)
		else "Amendments pass by decree, but democracies abroad frown.") + " Each costs %d political capital." % int(Economy.CONST_CAPITAL), _const)
	for a in Constitution.ARTICLES:
		var art: Dictionary = Constitution.ARTICLES[a]
		var cur := Constitution.option(str(a), Constitution.choice(str(a)))
		var row := ListRow.new().setup(str(art.title), str(cur[1]) if not cur.is_empty() else "", "›")
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(art.icon), DS.ACCENT))
		var aid := str(a)
		row.tapped.connect(func() -> void: _article(aid))
		_const.add_child(row)
	if why != "":
		note(why + ".", _const)


func _article(a: String) -> void:
	var art: Dictionary = Constitution.ARTICLES[a]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(art.icon), DS.ACCENT, "Constitution", str(art.title))
	var why := Constitution.amend_blocked()
	var free := Government.is_free(Game.player)
	for opt in art.options:
		var oid := str(opt[0])
		var current := Constitution.choice(a) == oid
		var chips: Array = []
		for k in opt[3]:
			var v := float(opt[3][k])
			var lbl: String = {"approval": "Approval", "stability": "Stability", "happiness": "Happiness", "clean": "Clean gov",
				"law_speed": "Laws pass faster", "coalition": "Coalitions", "youth": "Young voters", "relations": "Relations abroad",
				"disaster": "Crisis response", "cred": "Credibility", "term": ""}.get(str(k), str(k))
			if lbl == "" or v == 0.0:
				continue
			var good := v > 0.0 if str(k) != "coalition" else true
			chips.append(["%s %s" % [lbl, ("+" if v > 0 else "") + (String.num(v * 100.0, 0) + "%" if str(k) in ["law_speed", "disaster"] else String.num(v, 1))], DS.GREEN if good else DS.RED])
		var detail := str(opt[2])
		if not current and why == "" and free:
			detail += "  ·  referendum: about %d%% yes" % roundi(Constitution.yes_chance(a, oid) * 100.0)
		var ch := m.choice(str(opt[1]) + ("  (now)" if current else ""), detail, &"GhostButton" if current else &"", func() -> void:
			var r := Constitution.amend(a, oid)
			m.dismiss()
			var gs := get_tree().current_scene
			if gs and gs.has_method("_notify"):
				gs._notify(str(r.text), "scroll-text", DS.GOLD if bool(r.ok) else DS.ORANGE, true)
			if bool(r.ok):
				Haptics.success()
			else:
				Haptics.warning()
			refresh(), chips)
		if current or why != "":
			for b in ch.find_children("*", "Button", true, false):
				(b as Button).disabled = true
	if why != "":
		m.body(why + ".")
	m.choice("Close", "", &"GhostButton", m.dismiss)


# ----------------------------------------------------------- power brokers ---
func _fill_fac() -> void:
	for ch in _fac.get_children():
		ch.queue_free()
	note("Groups that can make or break you, whatever voters think. Tap one to see why it feels that way, or win it over.", _fac)
	for id in Factions.INFO:
		var info: Dictionary = Factions.INFO[id]
		var lv := Factions.loyalty(str(id))
		var tg := Factions.target(str(id))
		var col := DS.GREEN if lv >= 60.0 else (DS.ORANGE if lv >= Economy.FAC_ANGRY else DS.RED)
		var mood := "Loyal" if lv >= 70.0 else ("Content" if lv >= 50.0 else ("Uneasy" if lv >= Economy.FAC_ANGRY else "Angry"))
		var v := VBoxContainer.new()
		v.add_theme_constant_override(&"separation", 4)
		_fac.add_child(v)
		var row := ListRow.new().setup(str(info.title), "%s%s" % [mood, ("  ·  rising" if tg > lv + 2.0 else ("  ·  falling" if tg < lv - 2.0 else ""))], "%d" % roundi(lv), "loyalty")
		row.trailing_label.add_theme_color_override(&"font_color", col)
		row.set_leading(ListRow.icon_tile(str(info.icon), col))
		var fid := str(id)
		row.tapped.connect(func() -> void: _faction_card(fid))
		v.add_child(row)
		v.add_child(meter(lv / 100.0, 0.0, col, 3.0))


func _faction_card(id: String) -> void:
	var info: Dictionary = Factions.INFO[id]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(info.icon), DS.ACCENT, "Power brokers", str(info.title))
	m.body("Loyalty %d / 100. When loyal: %s. When angry: %s." % [roundi(Factions.loyalty(id)), str(info.help).to_lower(), str(info.hurt).to_lower()])
	var chips: Array = []
	for t in Factions.terms(id):
		var val := float(t[1])
		if absf(val) >= 0.5:
			chips.append(["%s %+d" % [str(t[0]), roundi(val)], DS.GREEN if val > 0.0 else DS.RED])
	if not chips.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 6)
		flow.add_theme_constant_override(&"v_separation", 6)
		m.content.add_child(flow)
		for ch in chips:
			var p := PanelContainer.new()
			p.theme_type_variation = &"ForecastChip"
			var l := Label.new()
			l.theme_type_variation = &"ChipValue"
			l.text = str(ch[0])
			l.add_theme_color_override(&"font_color", ch[1])
			p.add_child(l)
			flow.add_child(p)
	var wait := Factions.court_wait(id)
	var ok := wait == 0 and Capital.can(Economy.FAC_COURT_CAPITAL)
	var c1 := m.choice("Win them over", ("%s  ·  %d political capital" % [str(info.court), int(Economy.FAC_COURT_CAPITAL)]) if wait == 0
		else "Again in %d months" % wait, &"PrimaryButton", func() -> void:
			var t := Factions.court(id)
			m.dismiss()
			if t != "":
				Simulation.update_finances(Game.me())
				Haptics.success()
				var gs := get_tree().current_scene
				if gs and gs.has_method("_notify"):
					gs._notify(t, str(info.icon), DS.GREEN, false)
			refresh())
	if not ok:
		for b in c1.find_children("*", "Button", true, false):
			(b as Button).disabled = true
	if Factions.can_purge():
		m.choice("Purge and replace with loyalists", "Fast, but others grow wary and democracies protest  ·  %d capital" % int(Economy.FAC_PURGE_CAPITAL), &"DestructiveButton", func() -> void:
			var t2 := Factions.purge(id)
			m.dismiss()
			if t2 != "":
				Haptics.warning()
				Game.add_feed(t2, str(info.icon), "orange")
			refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


# --------------------------------------------------------- culture & values ---
func _fill_cult() -> void:
	for ch in _cult.get_children():
		ch.queue_free()
	note("What your people believe. Laws that fit are popular; laws that clash cost approval. Values shift slowly with education, openness and the laws you keep.", _cult)
	for axis in Culture.AXES:
		var a: Dictionary = Culture.AXES[axis]
		var v := Culture.value(str(axis))
		var d := v - float(Culture.st().start[axis])
		var head := HBoxContainer.new()
		_cult.add_child(head)
		var t := Label.new()
		t.theme_type_variation = &"Subhead"
		t.text = Culture.label(str(axis))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if absf(d) >= 1.0:
			var dl := Label.new()
			dl.theme_type_variation = &"Caption"
			dl.text = "%+d since you took office" % roundi(d)
			head.add_child(dl)
		# A two-ended bar with a marker.
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 26)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var font := get_theme_font(&"font", &"Caption")
		var neg := str(a.neg)
		var pos := str(a.pos)
		bar.draw.connect(func() -> void:
			var w := bar.size.x
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 2, w, 6))
			bar.draw_rect(Rect2(w * 0.5 - 1, 0, 2, 10), Color(1, 1, 1, 0.3))
			var x := w * (0.5 + v / 200.0)
			bar.draw_circle(Vector2(x, 5), 6.0, DS.ACCENT)
			bar.draw_circle(Vector2(x, 5), 3.0, Color.WHITE)
			bar.draw_string(font, Vector2(0, 24), neg, HORIZONTAL_ALIGNMENT_LEFT, w * 0.5, 11, DS.TEXT_3)
			bar.draw_string(font, Vector2(w * 0.5, 24), pos, HORIZONTAL_ALIGNMENT_RIGHT, w * 0.5, 11, DS.TEXT_3))
		_cult.add_child(bar)
	var b := AppButton.make("Launch a culture campaign", &"", "megaphone")
	b.pressed.connect(_culture_campaign)
	_cult.add_child(b)


func _culture_campaign() -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("megaphone", DS.ACCENT, "Culture", "Shift the nation's values")
	m.body("Schools, broadcasting and public campaigns nudge one value for two years. Costs %d political capital and %s." % [
		int(Economy.CULT_CAMPAIGN_CAPITAL), DS.money(Game.me().gdp * Economy.CULT_CAMPAIGN_COST / 100.0)])
	for axis in Culture.AXES:
		var a: Dictionary = Culture.AXES[axis]
		var wait := Culture.campaign_wait(str(axis))
		for dir in [1, -1]:
			var ax := str(axis)
			var dd: int = dir
			var ch := m.choice("Towards %s" % str(a.pos if dir > 0 else a.neg).to_lower(), ("Again in %d months" % wait) if wait > 0 else "", &"GhostButton", func() -> void:
				if Culture.campaign(ax, dd):
					Simulation.update_finances(Game.me())
					Haptics.success()
				m.dismiss()
				refresh())
			if wait > 0 or not Capital.can(Economy.CULT_CAMPAIGN_CAPITAL):
				for bb in ch.find_children("*", "Button", true, false):
					(bb as Button).disabled = true
	m.choice("Close", "", &"GhostButton", m.dismiss)
