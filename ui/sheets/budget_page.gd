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


func _init() -> void:
	super._init()
	title = "Budget"


func _build() -> void:
	var g := grid(self, 3)
	var money := func(v: float) -> String: return DS.money(v)
	_rev = StatTile.new().setup("Revenue", money, true)
	_spend = StatTile.new().setup("Spending", money, false)
	_bal = StatTile.new().setup("Balance", money, true)
	for t in [_rev, _spend, _bal]:
		g.add_child(t)
	_interest_note = note("")

	var c := Game.me()
	var total := section("Total spending")
	_total = AppSlider.new().setup("Public spending", 8, 60, 0.5, c.spending_pct)
	_total.formatter = func(v: float) -> String: return String.num(v, 1) + "% of GDP"
	_total.marker = float(c.base.spending_pct)
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


func _tint(k: String) -> Color:
	return {"health": DS.RED, "education": DS.YELLOW, "infrastructure": DS.ORANGE,
		"military": DS.TEAL, "welfare": DS.GREEN, "research": DS.PURPLE}[k]


func _share_fmt(v: float, k: String) -> String:
	var c := Game.me()
	return "%s%%  ·  %s" % [String.num(v, 1), DS.money(c.gdp * c.spending_pct / 100.0 * v / 100.0)]


func _on_share(v: float, k: String) -> void:
	if _syncing:
		return
	Game.me().set_budget_share(k, v / 100.0)
	_after_change()


func _after_change() -> void:
	var c := Game.me()
	Simulation.update_finances(c)
	_syncing = true
	for k in _shares:
		_shares[k].set_value(c.budget[k] * 100.0, false)
	_syncing = false
	refresh()


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


func on_open() -> void:
	for s in _strips:
		s.commit()
	_total.set_value(Game.me().spending_pct, false)
	refresh()
