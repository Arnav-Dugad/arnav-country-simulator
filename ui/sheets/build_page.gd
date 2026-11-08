class_name BuildPage
extends SheetPage
## Construction projects (see Projects): what's being built, what you could
## build next, and what your country already has.

var _summary: Label
var _speed: Label
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0
var _tab := 0               # 0 build, 1 defence, 2 research, 3 programmes
var _tabs: SegmentedControl
var _prog_box: VBoxContainer
var _units: VBoxContainer


func _init() -> void:
	super._init()
	title = "Build"


func _build() -> void:
	add_child(Illustration.banner("construction", "crane", DS.ORANGE, 124.0))
	_tabs = SegmentedControl.new().setup(["Build", "Defence", "Research", "Projects"], [], 0)
	_tabs.plain = true
	_tabs.compact = false
	_tabs.fill = true
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.changed.connect(func(i: int) -> void:
		_tab = i
		Haptics.select()
		refresh())
	add_child(_tabs)
	_units = VBoxContainer.new()
	_units.add_theme_constant_override(&"separation", DS.S4)
	add_child(_units)
	_prog_box = VBoxContainer.new()
	_prog_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_prog_box)
	_summary = Label.new()
	_summary.theme_type_variation = &"Subhead"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prog_box.add_child(_summary)
	_speed = note("", _prog_box)
	_filter = SegmentedControl.new().setup(["Can build", "Building", "Built"], [], 0)
	_filter.changed.connect(func(i: int) -> void:
		_mode = i
		refresh())
	_prog_box.add_child(_filter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", DS.S4)
	_prog_box.add_child(_list)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_prog_box.visible = _tab == 3
	_units.visible = _tab != 3
	if _tab == 2:
		_fill_research(c)
		return
	if _tab != 3:
		_fill_units(c)
		return
	var building := Projects.count_building(c)
	var spend := Projects.spending_pct(c)
	_summary.text = ("%d %s under construction · %s a year" % [building, "project" if building == 1 else "projects",
		DS.money(c.gdp * spend / 100.0)]) if building > 0 else "Nothing under construction. Projects create jobs now and growth for decades."
	var sp := Projects.speed(c)
	var over := Projects.overrun(c)
	var bits: Array[String] = []
	bits.append("Crews work at %d%% speed (more Infrastructure budget = faster)" % roundi(sp * 100.0))
	if over > 0.05:
		bits.append("Corruption adds about %d%% to costs" % roundi(over * 100.0))
	_speed.text = ". ".join(bits) + "."
	for ch in _list.get_children():
		ch.queue_free()
	var shown := 0
	for g in Projects.GROUPS:
		var items := Projects.ALL.filter(func(p: Dictionary) -> bool:
			if p.group != g:
				return false
			if _mode == 0:
				return not c.projects.has(p.id)
			if _mode == 1:
				return Projects.is_building(c, p.id)
			return Projects.is_done(c, p.id))
		if items.is_empty():
			continue
		var box := section(g, _list)
		for p in items:
			box.add_child(_card(c, p))
			shown += 1
	if shown == 0:
		note(["Everything on offer is built or under way.", "Nothing is being built right now. Pick a project under Can build.",
			"Nothing finished yet."][_mode], _list)


func _card(c: CountryState, p: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(top)
	var done := Projects.is_done(c, p.id)
	var building := Projects.is_building(c, p.id)
	var why := Projects.blocked_reason(c, p) if not done and not building else ""
	top.add_child(ListRow.icon_tile(str(p.icon), DS.GREEN if done else (DS.ORANGE if building else (DS.TEXT_3 if why != "" else DS.ACCENT))))
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override(&"separation", 1)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mid)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = str(p.title)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(t)
	var d := Label.new()
	d.theme_type_variation = &"Footnote"
	d.text = str(p.desc) if why == "" else why
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if why != "":
		d.add_theme_color_override(&"font_color", DS.TEXT_3)
	mid.add_child(d)
	if done:
		var st: Dictionary = c.projects[p.id]
		var badge := Label.new()
		badge.theme_type_variation = &"BadgeLabel"
		badge.text = "Since before you" if bool(st.get("start", false)) else ("Opened %d" % int(st.get("year", Game.year)))
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		top.add_child(badge)
	if building:
		var prog := Projects.progress(c, p.id)
		var left := int(ceil((float(p.months) - float(c.projects[p.id].progress)) / Projects.speed(c)))
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			var w := bar.size.x
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 1, w, 6))
			var fill: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			fill.bg_color = DS.ORANGE
			bar.draw_style_box(fill, Rect2(0, 1, maxf(w * prog, 6.0), 6)))
		v.add_child(bar)
		var cap := Label.new()
		cap.theme_type_variation = &"Caption"
		cap.text = "%d%% built · about %d %s to go" % [roundi(prog * 100.0), left, "month" if left == 1 else "months"]
		v.add_child(cap)
	if why != "":
		return v
	# What it does
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	v.add_child(chips)
	if not done and not building:
		chips.add_child(_chip("Costs %s" % DS.money(Projects.price(c, p)), DS.ORANGE))
		chips.add_child(_chip("%d months" % Projects.build_months(c, p), DS.TEXT_2))
	if not bool(c.projects.get(p.id, {}).get("start", false)):
		for k in p.fx:
			var val := float(p.fx[k])
			var good: bool = (val > 0.0) == bool(Laws.FX_GOOD_UP[k])
			chips.add_child(_chip("%s %s" % [Laws.FX_LABELS[k], _num(val)], DS.GREEN if good else DS.RED))
		if Climate.CUTS.has(p.id):
			chips.add_child(_chip("CO₂ −%d%%" % roundi(float(Climate.CUTS[p.id]) * 100.0), DS.GREEN))
		if float(p.upkeep) > 0.0:
			chips.add_child(_chip("Upkeep %s/yr" % DS.money(c.gdp * float(p.upkeep) / 100.0), DS.TEXT_2))
	if done:
		return v
	var b: AppButton
	if building:
		b = AppButton.make("Stop construction", &"GhostButton", "x")
		b.pressed.connect(_confirm_cancel.bind(p))
	else:
		b = AppButton.make("Build", &"PrimaryButton", "hammer")
		b.pressed.connect(_confirm_build.bind(p))
	v.add_child(b)
	return v


func _confirm_build(p: Dictionary) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(p.icon), DS.ACCENT, "New project", str(p.title))
	var price := Projects.price(c, p)
	var months := Projects.build_months(c, p)
	var per_month := price / maxf(float(months), 1.0)
	m.body("%s\n\nIt will cost about %s over %d months (%s a month), employing thousands while it's built. Once open it keeps paying off every year." % [
		str(p.desc), DS.money(price), months, DS.money(per_month)])
	if c.treasury < per_month * 3.0:
		var warn := m.body("Your treasury is low: this will be paid with new borrowing.")
		warn.add_theme_color_override(&"font_color", DS.ORANGE)
	m.choice("Start building", "", &"PrimaryButton", func() -> void:
		if Projects.start(c, p.id):
			Simulation.update_finances(c)
			var gs := get_tree().current_scene
			if gs and gs.has_method("learned"):
				gs.learned("build")
			Haptics.success()
			Audio.play("success", -6.0)
		m.dismiss()
		_mode = 1
		_filter.select(1, false)
		refresh())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func _confirm_cancel(p: Dictionary) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("construction", DS.RED, "Stop construction", str(p.title))
	m.body("The money already spent is lost and the workers are laid off.")
	m.choice("Stop it", "", &"DestructiveButton", func() -> void:
		Projects.cancel(c, p.id)
		Simulation.update_finances(c)
		Haptics.warning()
		m.dismiss()
		refresh())
	m.choice("Keep building", "", &"GhostButton", m.dismiss)


## +0.25, +0.5, +1.2 (no trailing zeros).
static func _num(v: float) -> String:
	var t := String.num(absf(v), 2)
	return ("+" if v >= 0.0 else "−") + t


func _chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ForecastChip"
	var lbl := Label.new()
	lbl.theme_type_variation = &"ChipValue"
	lbl.add_theme_color_override(&"font_color", color)
	lbl.text = text
	p.add_child(lbl)
	return p


# ------------------------------------------------------------ countable builds ---
static func _n(v: float) -> String:
	return DS.compact(roundf(v)).trim_suffix(".0").replace(".0K", "K").replace(".0M", "M")


func _fill_units(c: CountryState) -> void:
	for ch in _units.get_children():
		ch.queue_free()
	var defence := _tab == 1
	var head := Label.new()
	head.theme_type_variation = &"Subhead"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(60, 0)
	var spend := Builds.building_pct(c)
	if defence:
		head.text = "Military strength %d / 100. Forces you build add to it; your Military budget keeps them ready." % roundi(c.military)
	elif spend > 0.0:
		head.text = "Building now: %s a year." % DS.money(c.gdp * spend / 100.0)
	else:
		head.text = "Choose how many of anything to build. Countries that lack something gain the most from it."
	_units.add_child(head)
	for g in Builds.GROUPS:
		if (g == "Defence") != defence:
			continue
		var box := section(g, _units)
		for id in Builds.ids_in(g):
			box.add_child(_unit_row(c, str(id)))


func _unit_row(c: CountryState, id: String) -> Control:
	var s := Builds.spec(id)
	var n := Builds.count(c, id)
	var q := Builds.building(c, id)
	var cov := Builds.coverage_of(c, id, float(n))
	var why := Builds.available(c, id)
	var sub := "%s  ·  %d%% of need" % [_n(n), roundi(cov * 100.0)]
	if q > 0:
		sub += "  ·  +%s building" % _n(q)
	var row := ListRow.new().setup(str(s.title), sub if why == "" else why, "›")
	row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
	var tint := DS.RED if str(s.group) == "Defence" else DS.ACCENT
	if why != "":
		tint = DS.TEXT_3
	elif q > 0:
		tint = DS.ORANGE
	elif cov >= 0.8:
		tint = DS.GREEN
	row.set_leading(ListRow.icon_tile(str(s.icon), tint))
	if why == "":
		row.tapped.connect(_order.bind(id))
	return row


func _order(id: String) -> void:
	var c := Game.me()
	var s := Builds.spec(id)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(s.icon), DS.RED if str(s.group) == "Defence" else DS.ORANGE, str(s.group), str(s.title))
	var n := Builds.count(c, id)
	var price := Builds.unit_price(c, id)
	var months := Builds.months(c, id)
	m.body("You have %s (%d%% of what %s needs). Each %s costs %s and takes about %d months to build." % [
		_n(n), roundi(Builds.coverage_of(c, id, float(n)) * 100.0), World.the_name(c.idx),
		str(s.unit), DS.money(price, 0), months])
	var most := Builds.max_more(c, id)
	var info := Label.new()
	info.theme_type_variation = &"Footnote"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(60, 0)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 6)
	chips.add_theme_constant_override(&"v_separation", 6)
	var qty := {"v": clampi(int(ceil(Builds.need(c, id) * 0.1)), 1, maxi(most, 1))}
	var ui := {"confirm": null}
	var have := n + Builds.building(c, id)
	var update := func() -> void:
		var k := int(qty.v)
		var total := price * k
		var cov0 := Builds.coverage_of(c, id, float(have))
		var cov1 := Builds.coverage_of(c, id, float(have + k))
		info.text = "%s × %s = %s over %d months (%s of GDP a year). Coverage %d%% → %d%%. Upkeep afterwards: %s a year." % [
			_n(k), DS.money(price, 0), DS.money(total), months,
			DS.pct(total / float(maxi(months, 1)) * 12.0 / c.gdp * 100.0, 2), roundi(cov0 * 100.0), roundi(cov1 * 100.0),
			DS.money(total * float(s.upkeep), 0)]
		for ch in chips.get_children():
			ch.queue_free()
		var d := cov1 - cov0
		for key in s.fx:
			if key == "relations_soft":
				continue
			var v := float(s.fx[key]) * d * Economy.BUILD_FX_SCALE
			if absf(v) >= 0.01:
				var good: bool = (v > 0.0) == bool(Laws.FX_GOOD_UP.get(key, true))
				chips.add_child(_chip("%s %+.2f" % [Laws.FX_LABELS.get(key, key), v], DS.GREEN if good else DS.RED))
		if s.has("mil"):
			chips.add_child(_chip("Military %+.1f" % (float(s.mil) * d), DS.GREEN))
		if s.has("life"):
			chips.add_child(_chip("Life expectancy %+.2f yrs" % (float(s.life) * d * Economy.BUILD_FX_SCALE), DS.GREEN))
		if s.has("co2") and float(s.co2) > 0.0:
			chips.add_child(_chip("CO₂ −%s%%" % String.num(float(s.co2) * d * 100.0, 1), DS.GREEN))
		var cb: Control = ui.confirm
		if is_instance_valid(cb):
			for b in cb.find_children("*", "Button", true, false):
				(b as Button).text = "Build %s" % _n(k)
				break
	if most <= 0:
		m.body("You already have all the %s your country could use." % str(s.title).to_lower())
	else:
		var slider := AppSlider.new().setup("How many", 1, maxf(most, 1), 1, float(qty.v))
		slider.formatter = func(v: float) -> String: return _n(v)
		slider.value_changed.connect(func(v: float) -> void:
			qty.v = maxi(1, roundi(v))
			update.call())
		m.content.add_child(slider)
		var presets := HBoxContainer.new()
		presets.add_theme_constant_override(&"separation", DS.S2)
		m.content.add_child(presets)
		for p in [1, 10, 100, 1000]:
			if p > most:
				continue
			var b := AppButton.make(_n(p), &"Chip")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void:
				qty.v = p
				slider.set_value(float(p), false)
				update.call())
			presets.add_child(b)
		var full := mini(most, int(ceil(-Builds.need(c, id) * log(0.1))) - have)
		if full > 1:
			var fb := AppButton.make("To 90%", &"Chip")
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fb.pressed.connect(func() -> void:
				qty.v = full
				slider.set_value(float(full), false)
				update.call())
			presets.add_child(fb)
		m.content.add_child(info)
		m.content.add_child(chips)
		ui.confirm = m.choice("Build", "", &"PrimaryButton", func() -> void:
			if Builds.order(c, id, int(qty.v)):
				Haptics.success()
				Simulation.update_finances(c)
			m.dismiss()
			refresh())
		update.call()
	# Under construction, and demolition.
	var bt: Array = c.builds.get(id, {}).get("batches", [])
	for k in bt.size():
		var bd: Dictionary = bt[k]
		m.choice("Stop building %s (%d mo left)" % [_n(float(bd.n)), int(ceil(float(bd.left) / Projects.speed(c)))],
			"Money already spent is lost", &"GhostButton", func() -> void:
				Builds.cancel(c, id, k)
				Haptics.tap()
				Simulation.update_finances(c)
				m.dismiss()
				refresh())
	if n > 0:
		m.choice("Demolish some", "Saves upkeep; you lose their benefits", &"GhostButton", func() -> void:
			m.dismiss()
			_demolish(id))
	m.choice("Close", "", &"GhostButton", m.dismiss)


func _demolish(id: String) -> void:
	var c := Game.me()
	var s := Builds.spec(id)
	var n := Builds.count(c, id)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("x", DS.RED, "Demolish", str(s.title))
	var qty := {"v": maxi(1, n / 10)}
	var slider := AppSlider.new().setup("How many", 1, maxf(n, 1), 1, float(qty.v))
	slider.formatter = func(v: float) -> String: return _n(v)
	slider.value_changed.connect(func(v: float) -> void: qty.v = maxi(1, roundi(v)))
	m.content.add_child(slider)
	m.body("Coverage drops and the benefits go with it. Only upkeep for units built since you took office is saved.")
	m.choice("Demolish", "", &"DestructiveButton", func() -> void:
		Builds.demolish(c, id, int(qty.v))
		Haptics.warning()
		Simulation.update_finances(c)
		m.dismiss()
		refresh())
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------------ research ---
func _fill_research(c: CountryState) -> void:
	for ch in _units.get_children():
		ch.queue_free()
	var rp := Tech.income(c)
	var head := PanelContainer.new()
	head.theme_type_variation = &"GroupPanel"
	_units.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override(&"separation", DS.S2)
	head.add_child(hv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	hv.add_child(row)
	row.add_child(ListRow.icon_tile("flask-conical", DS.PURPLE))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	var cur := str(Tech.st().current)
	t.text = str(Tech.ALL[cur].title) if cur != "" else "Choose what to research"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(40, 0)
	col.add_child(t)
	var sub := Label.new()
	sub.theme_type_variation = &"Caption"
	sub.text = ("About %d months to go  ·  %s research points a month" % [Tech.months_left(cur), String.num(rp, 1)]) if cur != "" \
		else "%s research points a month. Tap any technology below." % String.num(rp, 1)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(40, 0)
	col.add_child(sub)
	if cur != "":
		var frac := float(Tech.st().progress) / float(Tech.ALL[cur].cost)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 6)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			bar.draw_style_box(get_theme_stylebox(&"track", &"AppSlider"), Rect2(0, 0, bar.size.x, 6))
			var f: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
			f.bg_color = DS.PURPLE
			bar.draw_style_box(f, Rect2(0, 0, maxf(bar.size.x * frac, 6.0), 6)))
		hv.add_child(bar)
	var why := Label.new()
	why.theme_type_variation = &"Caption"
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(40, 0)
	var parts: PackedStringArray = []
	for term in Tech.income_terms(c):
		if float(term[1]) >= 0.05:
			parts.append("%s %s" % [str(term[0]).to_lower(), String.num(float(term[1]), 1)])
	why.text = "From " + ", ".join(parts) + ". Raise the Research budget or build universities and labs for more."
	hv.add_child(why)
	# Space race standings.
	var firsts: Dictionary = Tech.st().firsts
	if not firsts.is_empty():
		var sr := section("Space race", _units)
		for id in Tech.ALL:
			if firsts.has(id):
				var i := World.index_of(str(firsts[id]))
				var r := ListRow.new().setup(str(Tech.ALL[id].title), "First: %s" % World.map.names[i])
				r.set_leading(ListRow.icon_tile(str(Tech.ALL[id].icon), DS.GOLD if i == Game.player else DS.TEXT_3))
				sr.add_child(r)
	for br in Tech.BRANCHES:
		var box := section(br, _units)
		for id in Tech.ALL:
			if str(Tech.ALL[id].branch) == br:
				box.add_child(_tech_row(str(id)))


func _tech_row(id: String) -> Control:
	var tt: Dictionary = Tech.ALL[id]
	var done := Tech.has(id)
	var can := Tech.can_research(id)
	var cur := str(Tech.st().current) == id
	var sub := str(tt.desc)
	if done:
		sub = "Researched  ·  " + sub
	elif cur:
		sub = "Researching  ·  about %d months" % Tech.months_left(id)
	elif not can:
		var need: PackedStringArray = []
		for r in tt.req:
			if not Tech.has(str(r)):
				need.append(str(Tech.ALL[str(r)].title))
		sub = "Needs " + " and ".join(need)
	else:
		sub = "%d points (about %d months)  ·  %s" % [int(tt.cost), Tech.months_left(id), sub]
	if tt.has("unlock") and not done:
		sub += "  ·  unlocks a new build"
	var row := ListRow.new().setup(str(tt.title), sub, "›" if can and not cur else "")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var tint := DS.GREEN if done else (DS.PURPLE if cur else (DS.ACCENT if can else DS.TEXT_3))
	row.set_leading(ListRow.icon_tile(str(tt.icon), tint))
	if can and not cur:
		row.tapped.connect(func() -> void:
			Tech.choose(id)
			Haptics.select()
			refresh())
	return row
