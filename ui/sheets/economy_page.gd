class_name EconomyPage
extends SheetPage
## Economy overview, history charts and the core policy levers.

const CHARTS := [
	["GDP", "gdp", DS.ACCENT], ["Approval", "approval", DS.GREEN],
	["Inflation", "inflation", DS.ORANGE], ["Debt", "debt_pct", DS.PURPLE],
]

var _tiles := {}
var _chart: LineChart
var _chart_tabs: SegmentedControl
var _chart_idx := 0
var _income: AppSlider
var _corp: AppSlider
var _rate: AppSlider
var _trade: AppSlider
var _balance_note: Label


func _init() -> void:
	super._init()
	title = "Economy"


func _build() -> void:
	var g := grid(self)
	_tiles.gdp = _tile(g, "GDP", func(v: float) -> String: return DS.money(v), true)
	_tiles.growth = _tile(g, "Growth", SheetPage.fmt_pct, true)
	_tiles.unemployment = _tile(g, "Unemployment", SheetPage.fmt_pct, false)
	_tiles.inflation = _tile(g, "Inflation", SheetPage.fmt_pct, false)
	_tiles.debt_pct = _tile(g, "Debt / GDP", SheetPage.fmt_pct, false)
	_tiles.approval = _tile(g, "Approval", SheetPage.fmt_pct, true)

	var chart_box := section("History")
	var labels: PackedStringArray = []
	for c in CHARTS:
		labels.append(c[0])
	_chart_tabs = SegmentedControl.new().setup(labels, [], 0)
	_chart_tabs.plain = true
	_chart_tabs.compact = false
	_chart_tabs.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_chart_tabs.changed.connect(func(i: int) -> void:
		_chart_idx = i
		_update_chart(true))
	chart_box.add_child(_chart_tabs)
	_chart = LineChart.new()
	chart_box.add_child(_chart)

	var c := Game.me()
	var b: Dictionary = c.base
	var tax := section("Taxes")
	_income = _slider(tax, "Income tax", 0, 60, 0.5, c.income_tax, b.income_tax, "Raises revenue · slows growth · unpopular")
	_income.value_changed.connect(func(v: float) -> void: _apply("income_tax", v))
	_corp = _slider(tax, "Corporate tax", 0, 50, 0.5, c.corp_tax, b.corp_tax, "Raises revenue · deters investment")
	_corp.value_changed.connect(func(v: float) -> void: _apply("corp_tax", v))
	_balance_note = note("", tax)

	var money := section("Central bank")
	_rate = _slider(money, "Interest rate", Economy.RATE_MIN, Economy.RATE_MAX, 0.25, c.interest_rate, NAN,
		"Higher: cools inflation · costs jobs and growth")
	_rate.formatter = func(v: float) -> String: return String.num(v, 2) + "%"
	_rate.value_changed.connect(func(v: float) -> void: _apply("interest_rate", v))

	var trade := section("Trade policy")
	_trade = _slider(trade, "Openness", 0, 100, 5, c.trade_openness * 100.0, float(b.trade) * 100.0, "",
		["Protectionist", "Open"])
	_trade.formatter = func(v: float) -> String:
		return "Open" if v >= 70 else ("Balanced" if v >= 35 else "Protectionist")
	_trade.value_changed.connect(func(v: float) -> void: _apply("trade_openness", v / 100.0))
	note("Openness lifts growth and lowers prices but exposes industry to competition.", trade)


func _tile(parent: Control, title_: String, fmt: Callable, good_up: bool) -> StatTile:
	var t := StatTile.new().setup(title_, fmt, good_up)
	parent.add_child(t)
	return t


func _slider(parent: Control, t: String, lo: float, hi: float, step: float, v: float, start: Variant,
		hint: String, hints: Array = []) -> AppSlider:
	var s := AppSlider.new().setup(t, lo, hi, step, v)
	s.marker = float(start) if start != null else NAN
	if hints.size() == 2:
		s.left_hint = hints[0]
		s.right_hint = hints[1]
	parent.add_child(s)
	if hint != "":
		var l := Label.new()
		l.theme_type_variation = &"Caption"
		l.text = hint
		parent.add_child(l)
	return s


func _apply(field: String, v: float) -> void:
	var c := Game.me()
	c.set(field, v)
	Simulation.update_finances(c)
	_update_balance()


func _update_balance() -> void:
	var c := Game.me()
	var bal := c.balance_pct()
	_balance_note.text = "Budget balance %s of GDP  ·  Revenue %s / yr" % [
		DS.pct(bal, 1, true), DS.money(c.revenue)]
	_balance_note.add_theme_color_override(&"font_color", DS.GREEN if bal >= 0 else (DS.ORANGE if bal > -5 else DS.RED))


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_tiles.gdp.show_value(c.gdp, year_ago("gdp"), func(d: float) -> String: return DS.money(absf(d)))
	_tiles.growth.show_value(c.growth, year_ago("growth"), SheetPage.fmt_pts)
	_tiles.unemployment.show_value(c.unemployment, year_ago("unemployment"), SheetPage.fmt_pts)
	_tiles.inflation.show_value(c.inflation, year_ago("inflation"), SheetPage.fmt_pts)
	_tiles.debt_pct.show_value(c.debt_pct(), year_ago("debt_pct"), SheetPage.fmt_pts)
	_tiles.approval.show_value(c.approval, year_ago("approval"), SheetPage.fmt_pts)
	_update_balance()
	_update_chart(false)


func on_open() -> void:
	var c := Game.me()
	_income.set_value(c.income_tax, false)
	_corp.set_value(c.corp_tax, false)
	_rate.set_value(c.interest_rate, false)
	_trade.set_value(c.trade_openness * 100.0, false)
	refresh()
	_update_chart(true)


func _update_chart(animate: bool) -> void:
	var spec: Array = CHARTS[_chart_idx]
	_chart.set_color(spec[2])
	match spec[1]:
		"gdp":
			_chart.formatter = func(v: float) -> String: return DS.money(v, 1)
		_:
			_chart.formatter = func(v: float) -> String: return String.num(v, 0) + "%"
	_chart.set_data(Game.history.get(spec[1], PackedFloat32Array()), animate)
