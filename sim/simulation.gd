class_name Simulation
extends RefCounted
## One monthly tick of a country. Pure functions over CountryState; all numbers
## and their meaning live in sim/economy.gd (constants prefixed E.).

const E = preload("res://sim/economy.gd")
const M := 1.0 / 12.0


## Advances a country by one month. Returns true if a debt crisis was triggered.
static func tick(c: CountryState, rng: RandomNumberGenerator) -> bool:
	var b: Dictionary = c.base
	var d_inc := c.income_tax - float(b.income_tax)
	var d_corp := c.corp_tax - float(b.corp_tax)
	var d_spend := c.spending_pct - float(b.spending_pct)
	var d_trade := c.trade_openness - float(b.trade)
	var neutral := E.neutral_rate(c.core_inflation)
	var gap := clampf(c.interest_rate - neutral, -E.RATE_GAP_CAP, E.RATE_GAP_CAP)
	var debt_pct := c.debt_pct()

	# --- Growth ---------------------------------------------------------------
	c.growth_anchor += (c.trend - c.growth_anchor) * E.TREND_PULL
	var g := c.growth_anchor
	g -= E.INCOME_TAX_DRAG * d_inc + E.CORP_TAX_DRAG * d_corp
	g -= E.RATE_GROWTH_DRAG * gap
	g += E.FISCAL_MULTIPLIER * d_spend
	g += E.INFRA_GROWTH * c.share_delta("infrastructure") / 10.0
	g += E.RESEARCH_GROWTH * c.share_delta("research") / 10.0
	g += E.EDUCATION_GROWTH * c.share_delta("education") / 10.0
	g += E.TRADE_GROWTH * d_trade * 2.0 * 0.5
	g += E.TRADE_DEAL_GROWTH * c.trade_deals - E.SANCTION_GROWTH * c.sanctioned_by
	g -= E.DEBT_GROWTH_DRAG * maxf(0.0, debt_pct - maxf(E.DEBT_SAFE, float(b.debt_pct)))
	g -= E.STABILITY_GROWTH_DRAG * maxf(0.0, minf(float(b.stability), E.STABILITY_FLOOR) - c.stability)
	g += c.shocks.growth
	c.growth += (clampf(g, -25.0, 20.0) - c.growth) * E.GROWTH_ADJUST
	# Fiscal stimulus fades: the economy gets used to the new spending level.
	b.spending_pct = float(b.spending_pct) + d_spend * 0.01

	# --- Inflation ------------------------------------------------------------
	if gap > 0.0:
		c.core_inflation -= (c.core_inflation - E.INFLATION_TARGET) * (E.CORE_DECAY + E.CORE_TIGHT_DECAY * gap)
	else:
		c.core_inflation -= (c.core_inflation - E.INFLATION_TARGET) * E.CORE_DECAY
		c.core_inflation += E.CORE_LOOSE_RISE * -gap
	c.core_inflation = clampf(c.core_inflation, -3.0, 400.0)
	var deficit := -c.balance_pct()
	var pi := c.core_inflation
	pi += E.DEMAND_INFLATION * (c.growth - c.growth_anchor)
	pi += E.DEFICIT_INFLATION * maxf(0.0, deficit - maxf(E.DEFICIT_SAFE, float(b.deficit_pct)))
	pi += E.PROTECTION_INFLATION * maxf(0.0, -d_trade) * 2.0
	pi -= E.RATE_INFLATION_EFFECT * gap
	pi += c.shocks.inflation
	c.inflation += (clampf(pi, -5.0, 500.0) - c.inflation) * E.INFLATION_ADJUST

	# --- Jobs -----------------------------------------------------------------
	c.u_natural = clampf(c.u_natural - E.EDUCATION_UNEMP * c.share_delta("education") / 10.0 * 0.01,
		E.UNEMP_MIN, E.UNEMP_MAX)
	var u: float = c.u_natural - E.OKUN * (c.growth - c.growth_anchor) + E.RATE_UNEMP * gap + c.shocks.unemployment
	c.unemployment += (clampf(u, E.UNEMP_MIN, E.UNEMP_MAX) - c.unemployment) * E.UNEMP_ADJUST

	# --- Output & people ------------------------------------------------------
	# USD GDP grows with real growth plus up to 3 % inflation (beyond that the
	# currency depreciates, so dollar GDP doesn't balloon with hyperinflation).
	var usd_inflation := clampf(c.inflation, -2.0, 3.0)
	c.gdp = maxf(c.gdp * pow(1.0 + (c.growth + usd_inflation) / 100.0, M), 1e6)
	c.price_index *= pow(1.0 + usd_inflation / 100.0, M)
	c.population *= pow(1.0 + c.pop_growth / 100.0, M)

	# --- Public finances ------------------------------------------------------
	var premium := minf(E.RISK_PREMIUM_PER_DEBT * maxf(0.0, debt_pct - E.DEBT_SAFE) \
		+ E.RISK_PREMIUM_INSTABILITY * maxf(0.0, 40.0 - c.stability), E.RISK_PREMIUM_CAP)
	c.debt_rate += (maxf(c.interest_rate, 0.5) + premium - c.debt_rate) * E.DEBT_RATE_ADJUST
	update_finances(c)
	c.treasury += c.balance * M
	var buffer := c.spending * M * E.TREASURY_BUFFER_MONTHS
	if c.treasury < buffer:            # issue bonds to restore the buffer
		c.debt += buffer - c.treasury
		c.treasury = buffer
	elif c.treasury > buffer * 3.0 and c.debt > 0.0:  # repay with surpluses
		var repay := minf(c.treasury - buffer * 2.0, c.debt)
		c.debt -= repay
		c.treasury -= repay

	# --- Society & politics ---------------------------------------------------
	var h := float(b.happiness)
	h += E.HEALTH_HAPPY * _log2_ratio(c.effort("health"), b.get("health_effort", 0.0))
	h += E.WELFARE_HAPPY * _log2_ratio(c.effort("welfare"), b.get("welfare_effort", 0.0))
	h += E.EDUCATION_HAPPY * _log2_ratio(c.effort("education"), b.get("education_effort", 0.0))
	var real_pc := c.real_gdp_per_capita()
	h += E.INCOME_HAPPY * _log2_ratio(real_pc, b.gdp_pc)
	b.gdp_pc = float(b.gdp_pc) + (real_pc - float(b.gdp_pc)) * E.INCOME_ADAPTATION
	h -= E.UNEMP_HAPPY * (c.unemployment - float(b.unemployment))
	h -= E.INFLATION_HAPPY * (minf(c.inflation, 60.0) - minf(float(b.inflation), 60.0))
	h -= E.TAX_HAPPY * d_inc
	h += c.shocks.happiness
	c.happiness += (clampf(h, 0.0, E.HAPPY_MAX) - c.happiness) * E.HAPPY_ADJUST

	var a := float(b.approval)
	a += E.APPROVAL_FROM_HAPPY * (c.happiness - float(b.happiness))
	a += E.APPROVAL_GROWTH * (c.growth - c.growth_anchor)
	a -= E.APPROVAL_INCOME_TAX * d_inc + E.APPROVAL_CORP_TAX * d_corp
	a -= E.APPROVAL_INFLATION * clampf(c.inflation - float(b.inflation), -10.0, 40.0)
	a += c.alliances * 0.6 + c.trade_deals * 0.3 - c.sanctioned_by * 1.0
	a += c.shocks.approval
	c.approval += (clampf(a, 0.0, 100.0) - c.approval) * E.APPROVAL_ADJUST

	var st := float(b.stability)
	st += E.STABILITY_FROM_APPROVAL * (c.approval - float(b.approval))
	st += E.STABILITY_FROM_HAPPY * (c.happiness - float(b.happiness))
	st += E.STABILITY_MILITARY * c.share_delta("military") / 10.0
	st -= 0.3 * (c.unemployment - float(b.unemployment))
	st += c.shocks.stability
	c.stability += (clampf(st, 0.0, 100.0) - c.stability) * E.STABILITY_ADJUST

	var mil := E.military_index(c.spending * c.budget.get("military", 0.0))
	c.military += (mil - c.military) * E.MILITARY_ADJUST

	for k in c.shocks:
		c.shocks[k] *= 1.0 - E.SHOCK_DECAY

	_guard(c)

	# --- Sovereign default / debt crisis ---------------------------------------
	if c.debt_pct() > E.DEFAULT_THRESHOLD:
		c.debt *= 1.0 - E.DEFAULT_HAIRCUT
		c.shocks.growth -= 4.0
		c.shocks.stability -= 12.0
		c.shocks.approval -= 12.0
		c.debt_rate += 2.0
		return true
	var over := debt_pct - maxf(E.DEBT_CRISIS_START, float(b.debt_pct) + 15.0)
	return over > 0.0 and rng.randf() < over * E.DEBT_CRISIS_PROB


## Last line of defence against numeric blow-ups from extreme data.
static func _guard(c: CountryState) -> void:
	for f in ["growth", "inflation", "core_inflation", "unemployment", "approval", "happiness",
			"stability", "military", "debt", "treasury", "gdp", "interest_rate", "debt_rate"]:
		var v := float(c.get(f))
		if is_nan(v) or is_inf(v):
			push_warning("Simulation: %s of %d was %s; reset" % [f, c.idx, v])
			c.set(f, 0.0 if f != "gdp" else 1e9)


static func update_finances(c: CountryState) -> void:
	var cycle := 1.0 + (c.growth - c.growth_anchor) * 0.01
	var rate := Economy.tax_yield(c.income_tax, Economy.K_INCOME) + Economy.tax_yield(c.corp_tax, Economy.K_CORP)
	c.revenue = c.gdp * (rate + c.other_rev_pct / 100.0) * cycle
	c.spending = c.gdp * c.spending_pct / 100.0
	# Inflation above the floor erodes local-currency debt, so only the real
	# part of the rate is a burden in dollar terms.
	var real_rate := maxf(c.debt_rate - maxf(0.0, c.inflation - Economy.DEBT_EROSION_FLOOR), 0.25)
	c.interest_cost = c.debt * real_rate / 100.0
	c.balance = c.revenue - c.spending - c.interest_cost


static func _log2_ratio(now: float, start: Variant) -> float:
	var s := float(start)
	if s <= 0.0 or now <= 0.0:
		return 0.0
	return log(now / s) / log(2.0)
