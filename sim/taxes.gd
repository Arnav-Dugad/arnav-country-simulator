class_name Taxes
extends RefCounted
## Six extra taxes beside income and corporate tax. Together with those two
## they are the 8 taxes on the Economy page. Each has a rate, a base (share of GDP it is
## levied on), and side effects per point above the country's starting rate.
## Starting rates come from income level and the real tax take; the revenue
## they raise at the start is carved out of the old catch-all "other revenue",
## so total revenue at the start is unchanged. State: c.taxes {id: rate}.
##
## Bases (share of GDP), rough OECD/IMF averages:
##   VAT: household consumption ~ 55 %; property: land and buildings ~ 2.2 %
##   (a 1 % rate on property value ~ 2.2 % of GDP of base); payroll: wages ~ 40 %;
##   fuel/carbon: ~ 2.5 %; tariffs: imports ~ 12-30 % (trade openness); sin: ~ 2 %.

## id -> {title, icon, desc, min, max, step, base (share of GDP), side effects per point}
const SPECS := {
	"vat": {"title": "Sales tax (VAT)", "icon": "store", "desc": "On everything people buy. Raises a lot; hits the poor hardest.",
		"min": 0.0, "max": 30.0, "step": 0.5, "base": 0.42,
		"fx": {"inflation": 0.08, "happiness": -0.18, "approval": -0.3, "growth": -0.02, "gini": 0.08}},
	"property": {"title": "Property tax", "icon": "house", "desc": "On land and buildings. Hard to dodge; homeowners grumble.",
		"min": 0.0, "max": 3.0, "step": 0.05, "base": 2.2,
		"fx": {"approval": -2.0, "happiness": -0.8, "gini": -0.6}},
	"payroll": {"title": "Payroll tax", "icon": "users", "desc": "On wages, paid by employers. Funds pensions; costs jobs.",
		"min": 0.0, "max": 25.0, "step": 0.5, "base": 0.35,
		"fx": {"unemployment": 0.08, "growth": -0.03, "approval": -0.1}},
	"fuel": {"title": "Fuel & carbon tax", "icon": "fuel", "desc": "Per litre of fuel. Cuts emissions; raises prices.",
		"min": 0.0, "max": 60.0, "step": 1.0, "base": 0.03,
		"fx": {"inflation": 0.02, "approval": -0.12, "happiness": -0.05}, "co2": 0.004},
	"tariff": {"title": "Import tariffs", "icon": "ship", "desc": "On all imports. Shields local firms; dearer goods.",
		"min": 0.0, "max": 40.0, "step": 0.5, "base": 0.12,
		"fx": {"inflation": 0.06, "growth": -0.04, "unemployment": -0.02}},
	"sin": {"title": "Tobacco & alcohol tax", "icon": "heart", "desc": "Discourages smoking and drinking. Healthier, but smuggling grows.",
		"min": 0.0, "max": 80.0, "step": 1.0, "base": 0.02,
		"fx": {"happiness": -0.01}, "life": 0.015},
}
const ORDER := ["vat", "property", "payroll", "fuel", "tariff", "sin"]
## Each point of a tax raises less than the last (avoidance and lost activity).
const DRAG := 0.012


## Realistic starting rate for a country (by income level and openness).
static func start_rate(c: CountryState, id: String) -> float:
	var lvl := Economy.income_level(c.gdp_per_capita())
	var trade := clampf(World.stat(c.idx, "trade_pct", 60.0), 15.0, 200.0)
	match id:
		"vat":
			return snappedf(lerpf(10.0, 20.0, lvl), 0.5)
		"property":
			return snappedf(lerpf(0.2, 1.0, lvl), 0.05)
		"payroll":
			return snappedf(lerpf(3.0, 14.0, lvl), 0.5)
		"fuel":
			return snappedf(lerpf(8.0, 35.0, lvl), 1.0)
		"tariff":
			return snappedf(lerpf(10.0, 3.0, lvl) * (1.0 if trade < 80.0 else 0.8), 0.5)
		"sin":
			return snappedf(lerpf(20.0, 45.0, lvl), 1.0)
	return 0.0


static func rate(c: CountryState, id: String) -> float:
	if not c.taxes.has(id):
		c.taxes[id] = start_rate(c, id)
	return float(c.taxes[id])


static func base_of(c: CountryState, id: String) -> float:
	var b := float(SPECS[id].base)
	if id == "tariff":
		b *= clampf(World.stat(c.idx, "trade_pct", 60.0) / 100.0 * 0.5, 0.06, 0.6) / 0.12 * 0.12
	return b


## Revenue from one tax, % of GDP. "_k" is this country's collection efficiency,
## set at the start so the six together match its real (non-income) tax take.
static func revenue_pct(c: CountryState, id: String) -> float:
	var r := rate(c, id)
	return r * base_of(c, id) * (1.0 - DRAG * r * (1.0 if id != "property" else 8.0)) * float(c.taxes.get("_k", 1.0))


## Revenue from all six, % of GDP.
static func total_pct(c: CountryState) -> float:
	var t := 0.0
	for id in ORDER:
		t += revenue_pct(c, id)
	return t


## Change in rate since the start (points).
static func delta(c: CountryState, id: String) -> float:
	return rate(c, id) - float(c.taxes_start.get(id, rate(c, id)))


## Called once when a country is set up (or a save without taxes loads).
static func init(c: CountryState) -> void:
	for id in ORDER:
		rate(c, id)
	# They can't raise more than the real "other revenue" they replace: keep 15 %
	# of it as fees and royalties and scale collection to fit the rest.
	var room := c.other_rev_pct * 0.85
	var raw := total_pct(c)
	c.taxes["_k"] = minf(room / maxf(raw, 0.01), 1.0)
	c.other_rev_pct = maxf(c.other_rev_pct - total_pct(c), 0.0)
	c.taxes_start = c.taxes.duplicate()


## Target offsets from tax changes (vs the start): {growth, inflation, ...}.
static func modifiers(c: CountryState) -> Dictionary:
	var out := {}
	if c.taxes.is_empty():
		return out
	for id in ORDER:
		var d := delta(c, id)
		if absf(d) < 0.001:
			continue
		var fx: Dictionary = SPECS[id].fx
		for k in fx:
			out[k] = float(out.get(k, 0.0)) + float(fx[k]) * d
		for k in ["co2", "life"]:
			if SPECS[id].has(k):
				out[k] = float(out.get(k, 0.0)) + float(SPECS[id][k]) * d
	return out


static func fmt(id: String, v: float) -> String:
	return ("%s%%" % String.num(v, 2)) if id == "property" else ("%s%%" % String.num(v, 1))
