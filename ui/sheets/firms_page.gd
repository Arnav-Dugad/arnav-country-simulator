class_name FirmsPage
extends SheetPage
## Wealth & state firms: the national stock index, the sovereign wealth fund and
## the companies the state owns (see Enterprise).

var _box: VBoxContainer
var _chart: LineChart


func _init() -> void:
	super._init()
	title = "Wealth & firms"


func _build() -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


func refresh() -> void:
	if Game.me() == null:
		return
	for ch in _box.get_children():
		ch.queue_free()
	var s := Enterprise.st()
	var idx := float(s.index)
	_box.add_child(photo_header("markets", "Wealth & state firms", "Stock index %s  ·  %s since you took office" % [
		String.num(idx, 0), _signed_pct(idx / 100.0 - 1.0)], 132.0))
	_market(s)
	_fund()
	_digital()
	_firms()


static func _signed_pct(v: float) -> String:
	return ("+" if v >= 0.0 else "−") + "%d%%" % roundi(absf(v) * 100.0)


# ------------------------------------------------------------------ market ---
func _market(s: Dictionary) -> void:
	var box := section("Stock market", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(row)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var v := Label.new()
	v.theme_type_variation = &"StatValue"
	v.text = String.num(float(s.index), 1)
	col.add_child(v)
	var hist: Array = s.hist
	var year_ago := float(hist[maxi(hist.size() - 13, 0)])
	var yr := float(s.index) / maxf(year_ago, 0.01) - 1.0
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.text = "%s over the past year  ·  100 = when you took office" % _signed_pct(yr)
	cap.add_theme_color_override(&"font_color", DS.GREEN if yr >= 0.0 else DS.RED)
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	col.add_child(cap)
	_chart = LineChart.new()
	_chart.custom_minimum_size = Vector2(0, 120)
	_chart.formatter = func(x: float) -> String: return String.num(x, 0)
	_chart.set_color(DS.GREEN if float(s.index) >= 100.0 else DS.RED)
	box.add_child(_chart)
	_chart.set_data(PackedFloat32Array(hist), false)
	note("Shares rise with growth and stability and fall when you raise interest rates. A strong market makes people feel richer and fetches better prices when you sell state firms.", box)


# -------------------------------------------------------------------- fund ---
func _fund() -> void:
	var c := Game.me()
	var f := Enterprise.fund()
	var box := section("Sovereign wealth fund", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(row)
	row.add_child(ListRow.icon_tile("piggy-bank", DS.GOLD))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"StatSmall"
	t.text = DS.money(float(f.value))
	col.add_child(t)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(40, 0)
	var ry := float(f.ret_year)
	cap.text = ("%s of GDP  ·  %s %s over the past year" % [DS.pct(float(f.value) / c.gdp * 100.0, 1), DS.money(absf(ry)),
		"earned" if ry >= 0.0 else "lost"]) \
		if float(f.value) > 0.0 else "Empty. Put money aside for the future."
	col.add_child(cap)
	var mix := AppSlider.new().setup("Global stocks", 0.0, 100.0, 5.0, float(f.stocks) * 100.0)
	mix.formatter = func(x: float) -> String: return "%d%%" % roundi(x)
	mix.left_hint = "Safe bonds"
	mix.right_hint = "Stocks"
	mix.info_text = "Stocks earn more on average but can fall hard in a bad year. Expected return now: %s a year." % DS.pct(Enterprise.expected_return() * 100.0, 1)
	mix.value_changed.connect(func(x: float) -> void: f.stocks = x / 100.0)
	mix.drag_ended.connect(func(_x: float) -> void: refresh())
	box.add_child(mix)
	var sp := AppToggle.new().setup("Spend the returns (%s of the fund a year goes to the budget)" % DS.pct(Economy.ENT_SPEND_RULE * 100.0, 0), bool(f.spend))
	sp.toggled.connect(func(on: bool) -> void:
		f.spend = on
		Haptics.select())
	box.add_child(sp)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override(&"separation", DS.S2)
	box.add_child(btns)
	var dep := AppButton.make("Deposit", &"", "plus")
	dep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dep.pressed.connect(_move_money.bind(true))
	btns.add_child(dep)
	var wd := AppButton.make("Withdraw", &"", "minus")
	wd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wd.disabled = float(f.value) <= 0.0
	wd.pressed.connect(_move_money.bind(false))
	btns.add_child(wd)


func _move_money(deposit: bool) -> void:
	var c := Game.me()
	var f := Enterprise.fund()
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("piggy-bank", DS.GOLD, "Wealth fund", "Deposit" if deposit else "Withdraw")
	var most := maxf(c.treasury, 0.0) if deposit else float(f.value)
	var cap_pct := (c.gdp * 0.1) if deposit and most <= 0.0 else most
	var top := maxf(cap_pct, c.gdp * 0.001)
	var amt := {"v": top * 0.25}
	var slider := AppSlider.new().setup("Amount", 0.0, top, top / 100.0, float(amt.v))
	slider.formatter = func(x: float) -> String: return DS.money(x)
	slider.value_changed.connect(func(x: float) -> void: amt.v = x)
	m.content.add_child(slider)
	if deposit:
		var b := m.body("Money saved abroad earns returns and cushions future crises." +
			(" Your treasury is empty, so this would be borrowed: only worth it if the fund earns more than your debt costs (%s)." % DS.pct(c.debt_rate, 1)
			if c.treasury <= 0.0 else ""))
		if c.treasury <= 0.0:
			b.add_theme_color_override(&"font_color", DS.ORANGE)
	else:
		m.body("The money goes straight to the treasury.")
	m.choice("Deposit" if deposit else "Withdraw", "", &"PrimaryButton", func() -> void:
		if deposit:
			Enterprise.deposit(float(amt.v))
		else:
			Enterprise.withdraw(float(amt.v))
		Simulation.update_finances(c)
		Haptics.success()
		m.dismiss()
		refresh())
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------------- firms ---
func _firms() -> void:
	var s := Enterprise.st()
	var d := Enterprise.dividend_change()
	var head := "The state owns %d of these companies." % _count_owned()
	if absf(d) > Game.me().gdp * 0.00001:
		head += " Dividends %s %s a year since you took office." % ["up" if d > 0.0 else "down", DS.money(absf(d))]
	var box := section("State firms", _box)
	note(head, box)
	for id in Enterprise.FIRMS:
		if not (s.firms as Dictionary).has(id):
			continue
		box.add_child(_firm_row(str(id)))


func _count_owned() -> int:
	var n := 0
	for id in Enterprise.st().firms:
		n += 1 if Enterprise.owned(str(id)) else 0
	return n


func _firm_row(id: String) -> Control:
	var info: Dictionary = Enterprise.FIRMS[id]
	var f: Dictionary = Enterprise.st().firms[id]
	var own := bool(f.own)
	var sub := ""
	if own:
		sub = "State-owned  ·  %s a year in dividends  ·  %d%% efficient" % [DS.money(Enterprise.dividend(id)), roundi(float(f.eff) * 100.0)]
	else:
		sub = "Private  ·  worth about %s" % DS.money(Enterprise.value(id))
	var row := ListRow.new().setup(str(info.title), sub, "›")
	row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
	row.set_leading(ListRow.icon_tile(str(info.icon), DS.GOLD if own else DS.TEXT_3))
	row.tapped.connect(_firm_card.bind(id))
	return row


func _firm_card(id: String) -> void:
	var c := Game.me()
	var info: Dictionary = Enterprise.FIRMS[id]
	var f: Dictionary = Enterprise.st().firms[id]
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header(str(info.icon), DS.GOLD, "State-owned" if bool(f.own) else "Private", str(info.title))
	if bool(f.own):
		m.body("Worth about %s. Pays %s a year in dividends; runs at %d%% of private-sector efficiency." % [
			DS.money(Enterprise.value(id)), DS.money(Enterprise.dividend(id)), roundi(float(f.eff) * 100.0)])
		var price := Enterprise.sale_price(id)
		m.choice("Privatise", "Raises %s now. Leaner and faster-growing, but layoffs and an angry public." % DS.money(price), &"PrimaryButton", func() -> void:
			Enterprise.privatise(id)
			Simulation.update_finances(c)
			Haptics.success()
			Audio.play("success", -8.0)
			m.dismiss()
			refresh(), [[DS.money(price), DS.GREEN], ["Approval −%s" % String.num(Economy.ENT_SELL_APPROVAL, 1), DS.RED]])
		if float(f.eff) < Economy.ENT_EFF_MAX - 0.01:
			var ok := Capital.can(Economy.CAPITAL_FIRM_REFORM)
			var ch := m.choice("Bring in professional managers", ("Efficiency +%d points  ·  %d political capital" % [roundi(Economy.ENT_REFORM_GAIN * 100.0), int(Economy.CAPITAL_FIRM_REFORM)])
				if ok else "Needs %d political capital" % int(Economy.CAPITAL_FIRM_REFORM), &"GhostButton", func() -> void:
				if Enterprise.reform(id):
					Haptics.success()
				m.dismiss()
				refresh())
			if not ok:
				for b in ch.find_children("*", "Button", true, false):
					(b as Button).disabled = true
	else:
		m.body("Worth about %s. Owned by private investors." % DS.money(Enterprise.value(id)))
		var cost := Enterprise.buy_price(id)
		m.choice("Buy it out", "Pay owners %s. Popular at home; dividends flow to the state." % DS.money(cost), &"PrimaryButton", func() -> void:
			Enterprise.nationalise(id, false)
			Simulation.update_finances(c)
			Haptics.success()
			m.dismiss()
			refresh(), [[DS.money(cost), DS.ORANGE]])
		m.choice("Seize it", "Free, but investors flee, shares crash and democracies protest.", &"DestructiveButton", func() -> void:
			Enterprise.nationalise(id, true)
			Simulation.update_finances(c)
			Haptics.warning()
			m.dismiss()
			refresh())
	m.choice("Close", "", &"GhostButton", m.dismiss)


# ------------------------------------------------------------- digital money ---
func _digital() -> void:
	var box := section("Digital money", _box)
	var s := DigitalMoney.st()
	var c := Game.me()
	var yc := DigitalMoney.year_change()
	var hl := ListRow.new().setup("Crypto market %d" % roundi(DigitalMoney.price()),
		("%s over the past year" % _signed_pct(yc)) if absf(yc) > 0.0001 else "Index: 100 when you took office")
	hl.set_leading(ListRow.icon_tile("bitcoin", DS.ORANGE))
	box.add_child(hl)
	var ch := LineChart.new()
	ch.custom_minimum_size = Vector2(0, 54)
	ch.minimal = true
	ch.line_width = 1.8
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.set_color(DS.GREEN if yc >= 0.0 else DS.RED)
	box.add_child(ch)
	ch.set_data(PackedFloat32Array(s.hist))
	var ml := PackedStringArray()
	for m in DigitalMoney.SHORT:
		ml.append(str(m))
	var seg := SegmentedControl.new().setup(ml, [], DigitalMoney.MODES.find(DigitalMoney.mode()))
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(k: int) -> void:
		var want := str(DigitalMoney.MODES[k])
		if not DigitalMoney.set_mode(want):
			Haptics.warning()
		else:
			Simulation.update_finances(Game.me())
			Haptics.select()
		refresh())
	box.add_child(seg)
	var mi: Dictionary = DigitalMoney.MODE_INFO[DigitalMoney.mode()]
	note("%s: %s" % [str(mi.title), str(mi.desc)] + "  A new policy costs political capital: 10, or 20 for legal tender (you have %d)." % roundi(Capital.value()), box)
	# Reserve.
	var units := float(s.units)
	if units > 0.0:
		var gain := DigitalMoney.holding() - float(s.cost)
		var rr := ListRow.new().setup("Crypto reserve: %s" % DS.money(DigitalMoney.holding()),
			"Bought for %s  ·  %s%s" % [DS.money(float(s.cost)), "+" if gain >= 0.0 else "−", DS.money(absf(gain))])
		rr.set_leading(ListRow.icon_tile("wallet", DS.GREEN if gain >= 0.0 else DS.RED))
		box.add_child(rr)
		var sb := AppButton.make("Sell the reserve", &"", "hand-coins")
		sb.pressed.connect(func() -> void:
			var v := DigitalMoney.sell_all()
			Simulation.update_finances(Game.me())
			Haptics.success()
			Game.add_feed("Crypto reserve sold for %s" % DS.money(v), "bitcoin", "accent")
			refresh())
		box.add_child(sb)
	var amt := c.gdp * 0.005
	var bb := AppButton.make("Buy crypto  ·  %s" % DS.money(amt), &"", "bitcoin")
	bb.disabled = c.treasury < amt
	bb.pressed.connect(func() -> void:
		DigitalMoney.buy(amt)
		Simulation.update_finances(Game.me())
		Haptics.select()
		refresh())
	box.add_child(bb)
	note("Half a percent of GDP from the treasury each tap. Prices can double or halve in a year; only gamble what you can lose.", box)
