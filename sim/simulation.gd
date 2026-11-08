class_name Simulation
extends RefCounted
## One monthly tick of a country. Pure functions over CountryState; all numbers
## and their meaning live in sim/economy.gd (constants prefixed E.).
##
## Each target (growth, inflation, …) is built as a list of named terms and then
## summed, so the "Why?" explainer can show the player exactly the maths that ran.
## Terms are stored in CountryState.why[metric] = [[label, value], …] and
## CountryState.targets[metric] = the value the metric is moving toward.

const E = preload("res://sim/economy.gd")
const M := 1.0 / 12.0


## Advances a country by one month. Returns true if a debt crisis was triggered.
## `record` keeps the per-term breakdown (only needed for the player).
static func tick(c: CountryState, rng: RandomNumberGenerator, record: bool = false) -> bool:
	var b: Dictionary = c.base
	var d_inc := c.income_tax - float(b.income_tax)
	var d_corp := c.corp_tax - float(b.corp_tax)
	var d_spend := c.spending_pct - float(b.spending_pct)
	var d_trade := c.trade_openness - float(b.trade)
	var neutral := E.neutral_rate(c.core_inflation)
	var gap := clampf(c.interest_rate - neutral, -E.RATE_GAP_CAP, E.RATE_GAP_CAP)
	var debt_pct := c.debt_pct()
	var lx := Laws.modifiers(c)
	var px := Projects.modifiers(c)
	var mx := Game.markets.effects(c)
	var tx := Treaties.modifiers(c) if c.idx == Game.player else {}
	var mig := Migration.delta(c)
	var tf := Tariffs.modifiers(c)
	var cx := Cabinet.modifiers(c) if c.idx == Game.player else {}
	var i := c.idx
	var autocracy := not Government.has_elections(c.idx)

	# --- Growth ---------------------------------------------------------------
	c.growth_anchor += (c.trend - c.growth_anchor) * E.TREND_PULL
	var g_terms := [
		["Underlying growth", c.growth_anchor],
		["Income tax", -E.INCOME_TAX_DRAG * d_inc],
		["Business tax", -E.CORP_TAX_DRAG * d_corp],
		["Interest rates", -E.RATE_GROWTH_DRAG * gap],
		["Government spending", E.FISCAL_MULTIPLIER * d_spend],
		["Infrastructure", E.INFRA_GROWTH * c.share_delta("infrastructure") / 10.0],
		["Research", E.RESEARCH_GROWTH * Profiles.mult(i, "research_growth") * c.share_delta("research") / 10.0],
		["Education", E.EDUCATION_GROWTH * Profiles.mult(i, "education_growth") * c.share_delta("education") / 10.0],
		["Trade openness", E.TRADE_GROWTH * Profiles.mult(i, "trade_growth") * d_trade * 2.0 * 0.5],
		["Trade deals", E.TRADE_DEAL_GROWTH * Profiles.mult(i, "deal_growth") * c.trade_deals],
		["Migration", Migration.growth_effect(c, mig)],
		["Ageing workforce", Ageing.growth_drag(c)],
		["Clean government", Corruption.growth_effect(c)],
		["Trade war", float(tf.growth)],
		["World oil prices", float(mx.growth)],
		["Treaties & blocs", float(tx.get("growth", 0.0))],
		["Your ministers", float(cx.get("growth", 0.0))],
		["World economy", float(mx.world)],
		["Sanctions on you", -E.SANCTION_GROWTH * c.sanctioned_by],
		["Debt burden", -E.DEBT_GROWTH_DRAG * maxf(0.0, debt_pct - maxf(E.DEBT_SAFE, float(b.debt_pct)))],
		["Instability", -E.STABILITY_GROWTH_DRAG * Profiles.mult(i, "instability_drag")
			* maxf(0.0, minf(float(b.stability), E.STABILITY_FLOOR) - c.stability)],
		["Recent events", float(c.shocks.growth)],
		["Laws & reforms", float(lx.get("growth", 0.0))],
		["Projects you built", float(px.get("growth", 0.0))],
		["Construction work", float(px.get("build_growth", 0.0))],
	]
	var g := clampf(_sum(g_terms), -25.0, 20.0)
	c.growth += (g - c.growth) * E.GROWTH_ADJUST
	# Fiscal stimulus fades: the economy gets used to the new spending level.
	b.spending_pct = float(b.spending_pct) + d_spend * 0.01

	# --- Inflation ------------------------------------------------------------
	if gap > 0.0:
		c.core_inflation -= (c.core_inflation - E.INFLATION_TARGET) * (E.CORE_DECAY + E.CORE_TIGHT_DECAY * gap) * Profiles.mult(i, "core_inflation_decay")
	else:
		c.core_inflation -= (c.core_inflation - E.INFLATION_TARGET) * E.CORE_DECAY * Profiles.mult(i, "core_inflation_decay")
		c.core_inflation += E.CORE_LOOSE_RISE * -gap * (1.0 if c.cb_auto else E.CB_CAPTURE_EXPECT)
	c.core_inflation = clampf(c.core_inflation, -3.0, 400.0)
	var deficit := -c.balance_pct()
	var pi_terms := [
		["Expected inflation", c.core_inflation],
		["Economy running hot" if c.growth >= c.growth_anchor else "Economy running cool",
			E.DEMAND_INFLATION * (c.growth - c.growth_anchor)],
		["Budget deficit", E.DEFICIT_INFLATION * maxf(0.0, deficit - maxf(E.DEFICIT_SAFE, float(b.deficit_pct)))],
		["Trade barriers", E.PROTECTION_INFLATION * maxf(0.0, -d_trade) * 2.0],
		["Interest rates", -E.RATE_INFLATION_EFFECT * gap],
		["World oil & food prices", float(mx.inflation)],
		["Tariffs", float(tf.inflation)],
		["Treaties & blocs", float(tx.get("inflation", 0.0))],
		["Your ministers", float(cx.get("inflation", 0.0))],
		["Recent events", float(c.shocks.inflation)],
		["Laws & reforms", float(lx.get("inflation", 0.0))],
		["Projects you built", float(px.get("inflation", 0.0))],
	]
	var pi := clampf(_sum(pi_terms), -5.0, 500.0)
	c.inflation += (pi - c.inflation) * E.INFLATION_ADJUST

	# --- Jobs -----------------------------------------------------------------
	c.u_natural -= E.EDUCATION_UNEMP * c.share_delta("education") / 10.0 / 12.0
	c.u_natural += (c.unemployment - c.u_natural) * E.UNEMP_HYSTERESIS
	c.u_natural = clampf(c.u_natural, E.UNEMP_MIN, E.UNEMP_MAX)
	var u_terms := [
		["Normal level for your country", c.u_natural],
		["Economic momentum", -E.OKUN * (c.growth - c.growth_anchor)],
		["New arrivals", Migration.jobs_effect(mig)],
		["Tariffs", float(tf.unemployment)],
		["Interest rates", E.RATE_UNEMP * gap],
		["Recent events", float(c.shocks.unemployment)],
		["Laws & reforms", float(lx.get("unemployment", 0.0))],
		["Projects you built", float(px.get("unemployment", 0.0))],
		["Construction work", float(px.get("build_jobs", 0.0))],
	]
	var u := clampf(_sum(u_terms), E.UNEMP_MIN, E.UNEMP_MAX)
	c.unemployment += (u - c.unemployment) * E.UNEMP_ADJUST

	# --- Output & people ------------------------------------------------------
	# USD GDP grows with real growth plus up to 3 % inflation (beyond that the
	# currency depreciates, so dollar GDP doesn't balloon with hyperinflation).
	var usd_inflation := clampf(c.inflation, -2.0, 3.0)
	c.gdp = maxf(c.gdp * pow(1.0 + (c.growth + usd_inflation) / 100.0, M), 1e6)
	c.price_index *= pow(1.0 + usd_inflation / 100.0, M)
	c.population *= pow(1.0 + (c.pop_growth + Migration.pop_effect(mig)) / 100.0, M)

	# --- Public finances ------------------------------------------------------
	# Markets judge debt against what they already trust this country with: the
	# premium starts above the higher of DEBT_SAFE and the starting debt (Japan
	# borrows cheaply at 200%+, as it really does); instability only counts
	# below the country's own starting level.
	var debt_ok := maxf(E.DEBT_SAFE, float(b.debt_pct) + E.DEBT_TOLERANCE)
	var stab_ok := minf(40.0, float(b.stability) - 5.0)
	var premium := minf(E.RISK_PREMIUM_PER_DEBT * maxf(0.0, debt_pct - debt_ok) \
		+ E.RISK_PREMIUM_INSTABILITY * maxf(0.0, stab_ok - c.stability), E.RISK_PREMIUM_CAP)
	premium *= Profiles.mult(i, "risk_premium")
	if not c.cb_auto:
		premium += E.CB_CAPTURE_PREMIUM
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
	Inequality.tick(c)
	var d_gini := Inequality.change(c)
	var real_pc := c.real_gdp_per_capita()
	var h_terms := [
		["Starting mood", float(b.happiness)],
		["Healthcare", E.HEALTH_HAPPY * _log2_ratio(c.effort("health"), b.get("health_effort", 0.0))],
		["Welfare", E.WELFARE_HAPPY * _gini_weight(c.idx) * _log2_ratio(c.effort("welfare"), b.get("welfare_effort", 0.0))],
		["Education", E.EDUCATION_HAPPY * _log2_ratio(c.effort("education"), b.get("education_effort", 0.0))],
		["Living standards", E.INCOME_HAPPY * _log2_ratio(real_pc, b.gdp_pc)],
		["Jobs", -E.UNEMP_HAPPY * (c.unemployment - float(b.unemployment))],
		["Prices", -E.INFLATION_HAPPY * (minf(c.inflation, 60.0) - minf(float(b.inflation), 60.0))],
		["Income tax", -E.TAX_HAPPY * d_inc],
		["Inequality", -E.INEQ_HAPPY * d_gini],
		["Food prices", float(mx.happiness)],
		["Treaties & blocs", float(tx.get("happiness", 0.0))],
		["Recent events", float(c.shocks.happiness)],
		["Laws & reforms", float(lx.get("happiness", 0.0))],
		["Projects you built", float(px.get("happiness", 0.0))],
	]
	b.gdp_pc = float(b.gdp_pc) + (real_pc - float(b.gdp_pc)) * E.INCOME_ADAPTATION
	var h := clampf(_sum(h_terms), 0.0, E.HAPPY_MAX)
	c.happiness += (h - c.happiness) * E.HAPPY_ADJUST

	var a_terms := [
		["Starting support", float(b.approval)],
		["Happiness", E.APPROVAL_FROM_HAPPY * (c.happiness - float(b.happiness))],
		["Economic momentum", E.APPROVAL_GROWTH * (c.growth - c.growth_anchor)],
		["Income tax", -E.APPROVAL_INCOME_TAX * d_inc],
		["Business tax", -E.APPROVAL_CORP_TAX * d_corp],
		["Prices", -E.APPROVAL_INFLATION * clampf(c.inflation - float(b.inflation), -10.0, 40.0)],
		["Diplomacy", c.alliances * 0.6 + c.trade_deals * 0.3 - c.sanctioned_by * 1.0],
		["Recent events", float(c.shocks.approval)],
		["Laws & reforms", float(lx.get("approval", 0.0))],
		["Projects you built", float(px.get("approval", 0.0))],
		["Your ministers", float(cx.get("approval", 0.0))],
	]
	var a := clampf(_sum(a_terms), 0.0, 100.0)
	c.approval += (a - c.approval) * E.APPROVAL_ADJUST

	var st_terms := [
		["Starting stability", float(b.stability)],
		["Support" if autocracy else "Approval", E.STABILITY_FROM_APPROVAL * (E.AUTOCRACY_APPROVAL_WEIGHT if autocracy else 1.0)
			* (c.approval - float(b.approval))],
		["Happiness", E.STABILITY_FROM_HAPPY * (c.happiness - float(b.happiness))],
		["Security forces" if autocracy else "Military spending", E.STABILITY_MILITARY
			* (E.AUTOCRACY_MILITARY_WEIGHT if autocracy else 1.0) * c.share_delta("military") / 10.0],
		["Jobs", -0.3 * (c.unemployment - float(b.unemployment))],
		["Inequality", -E.INEQ_STABILITY * d_gini],
		["Recent events", float(c.shocks.stability)],
		["Laws & reforms", float(lx.get("stability", 0.0))],
		["Projects you built", float(px.get("stability", 0.0))],
		["Treaties & blocs", float(tx.get("stability", 0.0))],
		["Your ministers", float(cx.get("stability", 0.0))],
	]
	var st := clampf(_sum(st_terms), 0.0, 100.0)
	c.stability += (st - c.stability) * E.STABILITY_ADJUST

	var mil := E.military_index(c.spending * c.budget.get("military", 0.0))
	c.military += (mil - c.military) * E.MILITARY_ADJUST

	if record:
		c.why = {"growth": g_terms, "inflation": pi_terms, "unemployment": u_terms,
			"happiness": h_terms, "approval": a_terms, "stability": st_terms}
		c.targets = {"growth": g, "inflation": pi, "unemployment": u, "happiness": h,
			"approval": a, "stability": st}

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


static func _sum(terms: Array) -> float:
	var s := 0.0
	for t in terms:
		s += float(t[1])
	return s


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
	var lx := Laws.modifiers(c)
	var market_rev := float(Game.markets.effects(c).revenue) if Game.has_game() else 0.0
	if Game.has_game():
		market_rev += float(Tariffs.modifiers(c).revenue)
	c.revenue = c.gdp * (rate + (c.other_rev_pct + float(lx.get("revenue", 0.0)) + market_rev) / 100.0) * cycle
	c.spending = c.gdp * (c.spending_pct + float(lx.get("cost", 0.0)) + Projects.spending_pct(c) + Ageing.pension_cost(c)) / 100.0
	# Inflation above the floor erodes local-currency debt, so only the real
	# part of the rate is a burden in dollar terms.
	var real_rate := maxf(c.debt_rate - maxf(0.0, c.inflation - Economy.DEBT_EROSION_FLOOR), 0.25)
	c.interest_cost = c.debt * real_rate / 100.0
	c.balance = c.revenue - c.spending - c.interest_cost


## Projects a country `months` ahead on a deep copy (no events, no AI) — used by
## the live forecast while the player drags a slider. Returns the projected copy.
static func project(c: CountryState, months: int) -> CountryState:
	var copy := c.clone()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for _m in months:
		tick(copy, rng)
	return copy


## Welfare matters more where incomes are unequal.
static func _gini_weight(i: int) -> float:
	return clampf(1.0 + (World.stat(i, "gini", 35.0) - 35.0) / E.GINI_SCALE, 0.7, 1.5)


static func _log2_ratio(now: float, start: Variant) -> float:
	var s := float(start)
	if s <= 0.0 or now <= 0.0:
		return 0.0
	return log(now / s) / log(2.0)
