class_name BudgetPage
extends SheetPage
## Spending level and how it is split. Moving one share rescales the others so
## the budget always adds up to 100 %.

var _rev: StatTile
var _spend: StatTile
var _bal: StatTile
var _total: AppSlider
var _shares := {}
var _interest_note: Label
var _syncing := false
var _strips: Array[ForecastStrip] = []
const BUDGET_INFO := {
	"health": "Hospitals, doctors and medicine. More healthcare makes people happier and healthier.",
	"education": "Schools and universities. It slowly lowers unemployment and lifts long-term growth.",
	"infrastructure": "Roads, power, railways and internet. A strong driver of long-term growth.",
	"military": "Defence and security forces. Adds stability and makes the country stronger.",
	"welfare": "Pensions, unemployment support and help for families. People feel more secure and happier.",
	"research": "Science and new technology. The biggest long-term boost to growth, but it takes years.",
}
var _undo: AppButton
var _snapshot := {}


func _init() -> void:
	super._init()
	title = "Budget"


func _build() -> void:
	var g := grid(self, 3)
	# Whole numbers keep three tiles readable on a 390 pt screen ("-$296B").
	var money := func(v: float) -> String: return DS.money(v, 0 if absf(v) < 1e12 else 1)
	_rev = StatTile.new().setup("Revenue", money, true)
	_spend = StatTile.new().setup("Spending", money, false)
	_bal = StatTile.new().setup("Balance", money, true)
	for t in [_rev, _spend, _bal]:
		g.add_child(t)
	_interest_note = note("")

	_build_plans()
	var c := Game.me()
	var total := section("Total spending")
	_total = AppSlider.new().setup("Public spending", 8, 60, 0.5, c.spending_pct)
	_total.formatter = func(v: float) -> String: return String.num(v, 1) + "% of GDP"
	_total.marker = float(c.base.spending_pct)
	_total.info_text = "How much the government spends each year, as a share of the whole economy. More spending improves services and gives a short boost, but if it is more than you collect in taxes, the gap is borrowed."
	_total.value_changed.connect(func(v: float) -> void:
		Game.me().spending_pct = v
		_after_change())
	total.add_child(_total)
	note("More spending boosts services and short-term growth, but widens the deficit.", total)
	var s1 := ForecastStrip.new()
	total.add_child(s1)
	_strips.append(s1)
	_total.value_changed.connect(func(_v: float) -> void: s1.request())

	var split := section("Where the money goes")
	var donut_row := HBoxContainer.new()
	donut_row.add_theme_constant_override(&"separation", DS.S3)
	split.add_child(donut_row)
	_donut = Donut.new()
	_donut.colors = CountryState.BUDGET_KEYS.map(func(k: String) -> Color: return _tint(k))
	_donut.center_title = "a year"
	donut_row.add_child(_donut)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override(&"separation", 3)
	_legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_legend.alignment = BoxContainer.ALIGNMENT_CENTER
	donut_row.add_child(_legend)
	for k in CountryState.BUDGET_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		split.add_child(row)
		var tile := ListRow.icon_tile(CountryState.BUDGET_ICONS[k], _tint(k))
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tile)
		var s := AppSlider.new().setup(CountryState.BUDGET_LABELS[k], 0, 60, 0.5, c.budget[k] * 100.0)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.marker = float(c.base.budget[k]) * 100.0
		s.info_text = BUDGET_INFO[k]
		s.formatter = _share_fmt.bind(k)
		s.value_changed.connect(_on_share.bind(k))
		row.add_child(s)
		_shares[k] = s
	var s2 := ForecastStrip.new()
	_strips.append(s2)
	for k in _shares:
		(_shares[k] as AppSlider).value_changed.connect(func(_v: float) -> void: s2.request())
	split.add_child(s2)
	note("Healthcare, welfare and education lift happiness. Infrastructure, research and " +
		"education lift long-run growth. Military strengthens stability and security.", split)
	_undo = AppButton.make("Undo my changes", &"GhostButton", "rotate-ccw")
	_undo.visible = false
	_undo.pressed.connect(func() -> void:
		var cs := Game.me()
		cs.spending_pct = float(_snapshot.spending_pct)
		cs.budget = (_snapshot.budget as Dictionary).duplicate()
		Simulation.update_finances(cs)
		on_open())
	add_child(_undo)


func _tint(k: String) -> Color:
	return {"health": DS.RED, "education": DS.YELLOW, "infrastructure": DS.ORANGE,
		"military": DS.TEAL, "welfare": DS.GREEN, "research": DS.PURPLE}[k]


func _share_fmt(v: float, k: String) -> String:
	var c := Game.me()
	var amount := c.gdp * c.spending_pct / 100.0 * v / 100.0
	return "%s%% · %s" % [String.num(v, 1), DS.money(amount, 0 if absf(amount) < 1e12 else 1)]


func _on_share(v: float, k: String) -> void:
	if _syncing:
		return
	Game.me().set_budget_share(k, v / 100.0)
	_after_change()


func _after_change() -> void:
	var c := Game.me()
	var gs := get_tree().current_scene
	if gs and gs.has_method("learned"):
		gs.learned("budget")
	_undo.visible = true
	Simulation.update_finances(c)
	_syncing = true
	for k in _shares:
		_shares[k].set_value(c.budget[k] * 100.0, false)
	_syncing = false
	refresh()


# ------------------------------------------------------------- quick plans ---
## One-tap plans: several sliders at once, previewed with a 12-month forecast.
const PLANS := [
	{"id": "balance", "title": "Balance the books", "icon": "piggy-bank", "tint": "green",
		"desc": "Spend a little less and nudge income tax up to shrink the deficit.",
		"spending": -2.0, "income_tax": 1.0, "shares": {}},
	{"id": "growth", "title": "Kickstart growth", "icon": "trending-up", "tint": "accent",
		"desc": "Spend a bit more, aimed at roads, research and schools.",
		"spending": 1.5, "income_tax": 0.0, "shares": {"infrastructure": 4.0, "research": 3.0, "education": 2.0}},
	{"id": "care", "title": "Care for people", "icon": "heart", "tint": "red",
		"desc": "Shift money toward healthcare and welfare.",
		"spending": 1.0, "income_tax": 0.0, "shares": {"health": 4.0, "welfare": 4.0}},
	{"id": "secure", "title": "Strong and secure", "icon": "shield", "tint": "teal",
		"desc": "A bigger military budget for stability and deterrence.",
		"spending": 0.5, "income_tax": 0.0, "shares": {"military": 5.0}},
]


static func _apply_plan(c: CountryState, p: Dictionary) -> void:
	c.spending_pct = clampf(c.spending_pct + float(p.spending), 8.0, 60.0)
	c.income_tax = clampf(c.income_tax + float(p.income_tax), 0.0, 60.0)
	for k in p.shares:
		c.set_budget_share(str(k), float(c.budget[k]) + float(p.shares[k]) / 100.0)
	Simulation.update_finances(c)


func _build_plans() -> void:
	var box := section("Quick plans")
	for p in PLANS:
		var row := ListRow.new().setup(str(p.title), str(p.desc), "›")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
		row.set_leading(ListRow.icon_tile(str(p.icon), {"green": DS.GREEN, "accent": DS.ACCENT, "red": DS.RED,
			"teal": DS.TEAL}.get(str(p.tint), DS.ACCENT)))
		row.tapped.connect(_preview_plan.bind(p))
		box.add_child(row)
	note("Each plan moves several sliders at once. You'll see what it changes before you commit.", box)


func _preview_plan(p: Dictionary) -> void:
	var c := Game.me()
	var now := Simulation.project(c, 12)
	var copy := c.clone()
	_apply_plan(copy, p)
	var then := Simulation.project(copy, 12)
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(p.icon), {"green": DS.GREEN, "accent": DS.ACCENT, "red": DS.RED, "teal": DS.TEAL}.get(str(p.tint), DS.ACCENT),
		"Quick plan", str(p.title))
	m.body(str(p.desc) + " In 12 months, compared with doing nothing:")
	var rows := [["Growth", then.growth - now.growth, true, "pts"], ["Inflation", then.inflation - now.inflation, false, "pts"],
		["Jobless", then.unemployment - now.unemployment, false, "pts"], ["Happiness", then.happiness - now.happiness, true, ""],
		["Approval", then.approval - now.approval, true, ""], ["Budget balance", then.balance_pct() - now.balance_pct(), true, "% GDP"]]
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 6)
	flow.add_theme_constant_override(&"v_separation", 6)
	m.content.add_child(flow)
	for r in rows:
		var d := float(r[1])
		if absf(d) < 0.05:
			continue
		var pc := PanelContainer.new()
		pc.theme_type_variation = &"ForecastChip"
		var l := Label.new()
		l.theme_type_variation = &"ChipValue"
		l.text = "%s %+.1f%s" % [r[0], d, (" " + str(r[3])) if str(r[3]) != "" else ""]
		l.add_theme_color_override(&"font_color", DS.GREEN if (d > 0.0) == bool(r[2]) else DS.RED)
		pc.add_child(l)
		flow.add_child(pc)
	m.choice("Apply this plan", "", &"PrimaryButton", func() -> void:
		_apply_plan(Game.me(), p)
		Haptics.success()
		m.dismiss()
		_total.set_value(Game.me().spending_pct, false)
		_after_change()
		for s in _strips:
			s.request())
	m.choice("Not now", "", &"GhostButton", m.dismiss)


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_rev.show_value(c.revenue)
	_spend.show_value(c.spending + c.interest_cost)
	_bal.show_value(c.balance)
	_bal.number.add_theme_color_override(&"font_color", DS.GREEN if c.balance >= 0.0 else DS.RED)
	_interest_note.text = "Debt %s (%s of GDP)  ·  Interest %s / yr" % [
		DS.money(c.debt), DS.pct(c.debt_pct(), 0), DS.money(c.interest_cost)]
	for k in _shares:
		_shares[k].set_value(c.budget[k] * 100.0, false)
	_update_donut()


var _donut: Donut
var _legend: VBoxContainer


func _update_donut() -> void:
	if _donut == null:
		return
	var c := Game.me()
	_donut.set_shares(CountryState.BUDGET_KEYS.map(func(k: String) -> float: return float(c.budget[k])))
	_donut.center_value = DS.money(c.gdp * c.spending_pct / 100.0, 1)
	_donut.queue_redraw()
	for ch in _legend.get_children():
		ch.queue_free()
	var keys: Array = CountryState.BUDGET_KEYS.duplicate()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(c.budget[a]) > float(c.budget[b]))
	for k in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 6)
		_legend.add_child(row)
		var dot := ColorRect.new()
		dot.color = _tint(k)
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var l := Label.new()
		l.theme_type_variation = &"Footnote"
		l.text = CountryState.BUDGET_LABELS[k]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		l.custom_minimum_size = Vector2(10, 0)
		row.add_child(l)
		var p := Label.new()
		p.theme_type_variation = &"StatSmall"
		p.text = "%d%%" % roundi(float(c.budget[k]) * 100.0)
		row.add_child(p)


func on_open() -> void:
	for s in _strips:
		s.commit()
	var c0 := Game.me()
	_snapshot = {"spending_pct": c0.spending_pct, "budget": c0.budget.duplicate()}
	_undo.visible = false
	_total.set_value(Game.me().spending_pct, false)
	refresh()
