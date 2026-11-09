class_name AI
extends RefCounted
## Simplified policy-making for computer-run countries, applied once a quarter.
## Central bank: a Taylor-style rule toward neutral. Treasury: trim deficits,
## sweeten unpopular governments. Small noise keeps the world from looking scripted.


static func quarterly(c: CountryState, rng: RandomNumberGenerator) -> void:
	central_bank(c)
	_treasury(c, rng)


## An independent central bank: a Taylor-style rule toward neutral. Also runs the
## player's rates while CountryState.cb_auto is on (the default).
static func central_bank(c: CountryState) -> void:
	var neutral := Economy.neutral_rate(c.core_inflation)
	var target := neutral + 0.5 * (c.inflation - Economy.INFLATION_TARGET) * 0.5 \
		- 0.25 * (c.unemployment - c.u_natural)
	target = clampf(target, Economy.RATE_MIN, Economy.RATE_MAX)
	var step := clampf(target - c.interest_rate, -0.75, 0.75)
	if absf(step) >= 0.25:
		c.interest_rate = clampf(snappedf(c.interest_rate + step, 0.25), Economy.RATE_MIN, Economy.RATE_MAX)


static func _treasury(c: CountryState, rng: RandomNumberGenerator) -> void:
	# Treasury: stay near the country's own starting fiscal stance.
	var deficit := -c.balance_pct()
	var allowed := maxf(Economy.DEFICIT_SAFE, float(c.base.get("deficit_pct", 3.0)))
	var debt_limit := maxf(120.0, float(c.base.get("debt_pct", 60.0)) + 10.0)
	if not c.base.has("spend0"):
		c.base["spend0"] = maxf(c.spending_pct, float(c.base.get("spending_pct", c.spending_pct)))
		c.base["tax0"] = c.income_tax
	var floor_sp := maxf(8.0, float(c.base.spend0) * Economy.AI_SPEND_FLOOR)
	var tax_top := minf(float(c.base.get("tax0", c.income_tax)) + Economy.AI_TAX_RAISE_MAX, 55.0)
	# The deficit that keeps debt steady as a share of GDP (nominal growth erodes it).
	var steady := c.debt_pct() * maxf(float(c.base.get("g_ema", c.growth_anchor)) + c.inflation, 0.0) / 100.0
	var slump := WorldMarkets.cycle_gap(c) < -1.5
	var too_high := deficit > minf(allowed + 2.0, 8.0) or (c.debt_pct() > debt_limit and deficit > steady - 1.0)
	if too_high and not slump:
		c.spending_pct = maxf(c.spending_pct - 0.25, minf(floor_sp, c.spending_pct))
		c.income_tax = maxf(minf(c.income_tax + 0.15, tax_top), c.income_tax)
	elif too_high:
		# No cuts into a recession (automatic stabilisers); lean on taxes a little instead.
		c.income_tax = maxf(minf(c.income_tax + 0.1, tax_top), c.income_tax)
	elif deficit < steady - 0.5 and c.spending_pct < float(c.base.spend0):
		# Debt is falling as a share of the economy: rebuild what was cut, slowly.
		c.spending_pct = minf(c.spending_pct + 0.15, float(c.base.spend0))
		if c.income_tax > float(c.base.get("tax0", c.income_tax)):
			c.income_tax -= 0.1
	elif deficit < -1.0 or (deficit < allowed - 3.0 and c.approval < 50.0):
		# Surplus or room to spare: spend a little more / ease taxes back.
		c.spending_pct = minf(c.spending_pct + 0.25, 60.0)
		if c.income_tax > float(c.base.income_tax):
			c.income_tax -= 0.15
	if c.approval < 35.0 and not too_high:
		c.income_tax = maxf(c.income_tax - 0.3, maxf(float(c.base.get("income_tax", 20.0)) - 5.0, 5.0))

	# Drift trade policy very slowly toward openness, with noise.
	c.trade_openness = clampf(c.trade_openness + rng.randf_range(-0.01, 0.012), 0.1, 0.95)
