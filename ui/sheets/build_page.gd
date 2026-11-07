class_name BuildPage
extends SheetPage
## Construction projects (see Projects): what's being built, what you could
## build next, and what your country already has.

var _summary: Label
var _speed: Label
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0


func _init() -> void:
	super._init()
	title = "Build"


func _build() -> void:
	_summary = Label.new()
	_summary.theme_type_variation = &"Subhead"
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_summary)
	_speed = note("")
	_filter = SegmentedControl.new().setup(["Can build", "Building", "Built"], [], 0)
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
