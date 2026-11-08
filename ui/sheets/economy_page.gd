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
var _range: SegmentedControl
var _income: AppSlider
var _corp: AppSlider
var _rate: AppSlider
var _trade: AppSlider
var _balance_note: Label
var _cb: AppToggle
var _cb_note: Label
var _strips: Array[ForecastStrip] = []
const INFO_TEXT := {
	"Income tax": "The share of people's earnings the government takes. Higher taxes raise money for services but slow the economy a little, and voters dislike them.",
	"Corporate tax": "Tax on company profits. It raises money, but high rates make businesses invest and hire less.",
	"Interest rate": "Set by your central bank. Raise it to cool high prices (inflation); lower it to boost growth and jobs. It works slowly, over months.",
	"Openness": "How freely goods flow across your borders. Open trade brings growth and cheaper goods; closing it protects some jobs but raises prices.",
}
var _health: HealthCard
var _trend: TrendCard
var _goals: GoalsCard
var _people: PeopleCard
var _undo: AppButton
var _snapshot := {}

signal page_requested(page: String)


func _init() -> void:
	super._init()
	title = "Economy"


func _build() -> void:
	_health = HealthCard.new()
	_health.page_requested.connect(func(p: String) -> void: page_requested.emit(p))
	add_child(_health)
	_goals = GoalsCard.new()
	add_child(_goals)
	_trend = TrendCard.new()
	add_child(_trend)
	_people = PeopleCard.new()
	add_child(_people)
	var g := grid(self)
	_tiles.gdp = _tile(g, "GDP", func(v: float) -> String: return DS.money(v), true)
	_tiles.growth = _tile(g, "Growth", SheetPage.fmt_pct, true)
	_tiles.unemployment = _tile(g, "Unemployment", SheetPage.fmt_pct, false)
	_tiles.inflation = _tile(g, "Inflation", SheetPage.fmt_pct, false)
	_tiles.debt_pct = _tile(g, "Debt / GDP", SheetPage.fmt_pct, false)
	_tiles.approval = _tile(g, Government.support_word(Game.player), SheetPage.fmt_pct, true)
	_tiles.rating = _tile(g, "Credit rating", func(_v: float) -> String: return Game.me().rating(), true)
	_tiles.balance = _tile(g, "Budget", func(v: float) -> String: return DS.pct(v, 1, true) + " GDP", true)
	_tiles.rating.make_tappable().tapped.connect(_explain_rating)
	# Tap a tile to see why it is moving.
	for pair in [["gdp", "growth"], ["growth", "growth"], ["unemployment", "unemployment"],
			["inflation", "inflation"], ["approval", "approval"]]:
		(_tiles[pair[0]] as StatTile).make_tappable().tapped.connect(
			func() -> void: Explainer.open(get_tree().current_scene, pair[1]))
	var hint := Label.new()
	hint.theme_type_variation = &"Caption"
	hint.text = "Tap a number to see what's moving it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	move_child(hint, g.get_index() + 1)

	var chart_box := section("History")
	var labels: PackedStringArray = []
	for c in CHARTS:
		labels.append(c[0])
	_chart_tabs = SegmentedControl.new().setup(labels, [], 0)
	_chart_tabs.plain = true
	_chart_tabs.compact = false
	_chart_tabs.fill = true
	_chart_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chart_tabs.changed.connect(func(i: int) -> void:
		_chart_idx = i
		_update_chart(true))
	chart_box.add_child(_chart_tabs)
	_chart = LineChart.new()
	_chart.window = 60
	_chart.date_of = func(i: int) -> String:
		# i indexes the full history; it ends at the current month.
		var h: PackedFloat32Array = Game.history.get(CHARTS[_chart_idx][1], PackedFloat32Array())
		var back := h.size() - 1 - i
		var m := Game.month - 1 - back
		var y := Game.year + floori(m / 12.0)
		const N := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		return "%s %d" % [N[posmod(m, 12)], y]
	chart_box.add_child(_chart)
	_range = SegmentedControl.new().setup(["1 year", "5 years", "All"], [], 1)
	_range.plain = true
	_range.compact = true
	_range.changed.connect(func(i: int) -> void:
		_chart.window = [12, 60, 1200][i]
		_update_chart(true))
	chart_box.add_child(_range)
	var scrub_hint := Label.new()
	scrub_hint.theme_type_variation = &"Caption"
	scrub_hint.text = "Drag across the chart to see any month."
	scrub_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chart_box.add_child(scrub_hint)

	var c := Game.me()
	var b: Dictionary = c.base
	var tax := section("Taxes")
	_income = _slider(tax, "Income tax", 0, 60, 0.5, c.income_tax, b.income_tax, "Raises revenue · slows growth · unpopular")
	_income.value_changed.connect(func(v: float) -> void: _apply("income_tax", v))
	_corp = _slider(tax, "Corporate tax", 0, 50, 0.5, c.corp_tax, b.corp_tax, "Raises revenue · deters investment")
	_corp.value_changed.connect(func(v: float) -> void: _apply("corp_tax", v))
	_balance_note = note("", tax)
	_attach_forecast(tax, [_income, _corp])

	var money := section("Central bank")
	_cb = AppToggle.new().setup("Let the central bank decide", c.cb_auto, "landmark")
	_cb.toggled.connect(func(v: bool) -> void:
		Game.me().cb_auto = v
		Haptics.select()
		if not v:
			Press.apply_cred(Economy.CB_CAPTURE_CRED)
			Game.add_feed("Markets worry as the government takes control of interest rates", "landmark", "orange")
		else:
			Game.add_feed("The central bank is independent again. Markets relax.", "landmark", "green")
		_sync_cb())
	money.add_child(_cb)
	_cb_note = note("", money)
	_rate = _slider(money, "Interest rate", Economy.RATE_MIN, Economy.RATE_MAX, 0.25, c.interest_rate, NAN,
		"Higher: cools inflation · costs jobs and growth")
	_rate.formatter = func(v: float) -> String: return String.num(v, 2) + "%"
	_rate.value_changed.connect(func(v: float) -> void: _apply("interest_rate", v))
	_attach_forecast(money, [_rate])

	var trade := section("Trade policy")
	_trade = _slider(trade, "Openness", 0, 100, 5, c.trade_openness * 100.0, float(b.trade) * 100.0, "",
		["Protectionist", "Open"])
	_trade.formatter = func(v: float) -> String:
		return "Open" if v >= 70 else ("Balanced" if v >= 35 else "Protectionist")
	_trade.value_changed.connect(func(v: float) -> void: _apply("trade_openness", v / 100.0))
	note("Openness lifts growth and lowers prices but exposes industry to competition.", trade)
	_attach_forecast(trade, [_trade])
	_undo = AppButton.make("Undo my changes", &"GhostButton", "rotate-ccw")
	_undo.visible = false
	_undo.pressed.connect(func() -> void:
		var cs := Game.me()
		for k in _snapshot:
			cs.set(k, _snapshot[k])
		Simulation.update_finances(cs)
		on_open())
	add_child(_undo)


## A live 12-month forecast under a group of sliders.
func _attach_forecast(box: Control, sliders: Array) -> void:
	var strip := ForecastStrip.new()
	box.add_child(strip)
	_strips.append(strip)
	for s in sliders:
		(s as AppSlider).value_changed.connect(func(_v: float) -> void: strip.request())


func _explain_rating() -> void:
	var c := Game.me()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("landmark", DS.GOLD, "Credit rating", "%s  ·  score %d" % [c.rating(), int(c.rating_score())])
	m.body("Lenders grade your country from AAA (safest) to C. A better grade means cheaper borrowing and calmer markets.")
	var cap := Label.new()
	cap.theme_type_variation = &"Overline"
	cap.text = "WHAT GOES INTO IT"
	m.content.add_child(cap)
	for p in c.rating_parts():
		var row := HBoxContainer.new()
		m.content.add_child(row)
		var l := Label.new()
		l.theme_type_variation = &"Body"
		l.text = str(p[0])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var v := Label.new()
		v.theme_type_variation = &"StatSmall"
		var val := float(p[1])
		v.text = ("%+.0f" % val) if p[0] != "Starting point" else "%.0f" % val
		v.add_theme_color_override(&"font_color", DS.TEXT if p[0] == "Starting point" or p[0] == "Wealth" else
			(DS.TEXT_2 if absf(val) < 0.5 else (DS.GREEN if val > 0.0 else DS.RED)))
		row.add_child(v)
	var tip := Label.new()
	tip.theme_type_variation = &"Footnote"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "Grades: AAA 88+, AA 78+, A 68+, BBB 58+, BB 48+, B 38+, CCC 28+. Keep deficits small, inflation low and the country calm."
	m.content.add_child(tip)
	m.choice("Got it", "", &"PrimaryButton", m.dismiss)


func _tile(parent: Control, title_: String, fmt: Callable, good_up: bool) -> StatTile:
	var t := StatTile.new().setup(title_, fmt, good_up)
	parent.add_child(t)
	return t


func _slider(parent: Control, t: String, lo: float, hi: float, step: float, v: float, start: Variant,
		hint: String, hints: Array = []) -> AppSlider:
	var s := AppSlider.new().setup(t, lo, hi, step, v)
	s.info_text = INFO_TEXT.get(t, "")
	s.marker = float(start) if start != null else NAN
	if hints.size() == 2:
		s.left_hint = hints[0]
		s.right_hint = hints[1]
	parent.add_child(s)
	if hint != "":
		var l := Label.new()
		l.theme_type_variation = &"Caption"
		l.text = hint
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)
	return s


func _apply(field: String, v: float) -> void:
	var c := Game.me()
	c.set(field, v)
	_undo.visible = true
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
	_tiles.rating.number.set_instant(c.rating_score())
	_tiles.rating.delta_label.text = "Tap for details"
	_tiles.balance.number.value = c.balance_pct()
	_tiles.balance.number.add_theme_color_override(&"font_color", DS.GREEN if c.balance >= 0.0 else DS.RED)
	_tiles.balance.delta_label.text = "Surplus" if c.balance >= 0.0 else "Deficit"
	_update_balance()
	_update_chart(false)
	_health.refresh()
	_trend.refresh()
	_goals.refresh()
	_people.refresh()
	if Game.me().cb_auto:
		_rate.set_value(Game.me().interest_rate, false)
		_sync_cb()


## An independent central bank sets rates itself (AI.central_bank); turn it off to
## set them by hand.
func _sync_cb() -> void:
	var c := Game.me()
	_rate.visible = not c.cb_auto
	_cb_note.text = ("Your central bank adjusts the interest rate every few months to keep inflation near 2%%. It's %s now." % (String.num(c.interest_rate, 2) + "%")) 		if c.cb_auto else "You set the interest rate yourself. Raise it when prices climb, cut it when jobs vanish. Markets charge you %s pts more to borrow while the bank isn't independent, and prices expect to rise faster if you keep rates low." % String.num(Economy.CB_CAPTURE_PREMIUM, 1)


func on_open() -> void:
	_sync_cb()
	for s in _strips:
		s.commit()
	var c0 := Game.me()
	_snapshot = {"income_tax": c0.income_tax, "corp_tax": c0.corp_tax, "interest_rate": c0.interest_rate,
		"trade_openness": c0.trade_openness}
	_undo.visible = false
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
	# Your decisions as dots on the line, and a dashed 12-month forecast.
	var marks: Array = []
	for e in Game.event_log:
		if e.has("m"):
			marks.append([int(e.m), DS.GOLD if str(e.id) == "election" else DS.ACCENT, str(e.title)])
	_chart.markers = marks
	_chart.forecast = _forecast(str(spec[1]))
	_chart.set_data(Game.history.get(spec[1], PackedFloat32Array()), animate)


## 12 months ahead on a copy of the country (no events), for the dashed line.
func _forecast(key: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var c := Game.me().clone()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for _m in 12:
		Simulation.tick(c, rng)
		match key:
			"gdp":
				out.append(c.gdp)
			"debt_pct":
				out.append(c.debt_pct())
			_:
				out.append(float(c.get(key)))
	return out
