class_name AI
extends RefCounted
## Simplified policy-making for computer-run countries, applied once a quarter.
## Central bank: a Taylor-style rule toward neutral. Treasury: trim deficits,
## sweeten unpopular governments. Small noise keeps the world from looking scripted.


static func quarterly(c: CountryState, rng: RandomNumberGenerator) -> void:
	# Central bank
	var neutral := Economy.neutral_rate(c.core_inflation)
	var target := neutral + 0.5 * (c.inflation - Economy.INFLATION_TARGET) * 0.5 \
		- 0.25 * (c.unemployment - c.u_natural)
	target = clampf(target, Economy.RATE_MIN, Economy.RATE_MAX)
	var step := clampf(target - c.interest_rate, -0.75, 0.75)
	if absf(step) >= 0.25:
		c.interest_rate = clampf(snappedf(c.interest_rate + step, 0.25), Economy.RATE_MIN, Economy.RATE_MAX)

	# Treasury: stay near the country's own starting fiscal stance.
	var deficit := -c.balance_pct()
	var allowed := maxf(Economy.DEFICIT_SAFE, float(c.base.get("deficit_pct", 3.0)))
	var debt_limit := maxf(120.0, float(c.base.get("debt_pct", 60.0)) + 10.0)
	if deficit > minf(allowed + 2.0, 8.0) or c.debt_pct() > debt_limit:
		c.spending_pct = maxf(c.spending_pct - 0.25, 8.0)
		c.income_tax = minf(c.income_tax + 0.15, 55.0)
	elif deficit < -1.0 or (deficit < allowed - 3.0 and c.approval < 50.0):
		# Surplus or room to spare: spend a little more / ease taxes back.
		c.spending_pct = minf(c.spending_pct + 0.25, 60.0)
		if c.income_tax > float(c.base.income_tax):
			c.income_tax -= 0.15
	if c.approval < 35.0:
		c.income_tax = maxf(c.income_tax - 0.3, 5.0)

	# Drift trade policy very slowly toward openness, with noise.
	c.trade_openness = clampf(c.trade_openness + rng.randf_range(-0.01, 0.012), 0.1, 0.95)
