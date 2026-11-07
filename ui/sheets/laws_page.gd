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


func _build() -> void:
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
	var active := 0
	var passing := 0
	for l in Laws.ALL:
		active += 1 if Laws.is_active(c, l.id) else 0
		passing += 1 if Laws.pending_months(c, l.id) > 0 else 0
	_summary.text = "%d %s in force%s. New laws take months to pass, and you can change course while they do." % [
		active, "law" if active == 1 else "laws", "  ·  %d being debated" % passing if passing > 0 else ""]
	for ch in _list.get_children():
		ch.queue_free()
	for g in Laws.GROUPS:
		var items := Laws.ALL.filter(func(l: Dictionary) -> bool:
			if l.group != g:
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
	t.text = str(l.title)
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
	# Action
	var b: AppButton
	if pend > 0:
		b = AppButton.make("Stop " + ("passing" if st == "passing" else "repeal"), &"GhostButton", "x")
		b.pressed.connect(func() -> void:
			Laws.cancel(c, l.id)
			Haptics.tap()
			refresh())
	elif on:
		b = AppButton.make("Repeal", &"", "rotate-ccw")
		b.pressed.connect(_confirm.bind(l, true))
	else:
		b = AppButton.make("Pass this law", &"", "gavel")
		b.pressed.connect(_confirm.bind(l, false))
	v.add_child(b)
	return v


func _confirm(l: Dictionary, repeal: bool) -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(l.icon), DS.ACCENT, "Repeal law" if repeal else "New law", str(l.title))
	var months := maxi(3, int(l.months * (0.5 if repeal else 1.0)))
	var pol := float(l.politics) * (-0.6 if repeal else 1.0)
	var mood := "Voters will welcome it" if pol > 0.5 else ("Expect some backlash" if pol < -0.5 else "Voters are split")
	m.body("%s\n\nIt will take about %d months%s. %s." % [str(l.desc), months,
		" and its effects will reverse" if repeal else " before it takes effect", mood])
	m.choice("Repeal it" if repeal else "Start passing it", "", &"DestructiveButton" if repeal else &"PrimaryButton",
		func() -> void:
			Laws.start(c, l.id)
			Haptics.success()
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
