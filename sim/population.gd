class_name Population
extends RefCounted
## Population & cities.
##   Births        a fertility rate (children per woman), estimated from income at
##                 the start and nudged by family policy: none / support /
##                 generous (child benefits, childcare, parental leave). More
##                 births add population and slow ageing, at a cost.
##   Cities        the urban share starts from real data and rises as the
##                 country develops; people keep moving to the cities.
##   Housing       demand grows with city growth and population; supply comes
##                 from private builders (more with zoning reform) and the
##                 affordable homes you build. Fall behind and housing gets
##                 unaffordable: rents climb, happiness and young voters suffer.
## State: Game.dip.pop {tfr0, tfr, family, urban0, urban, afford, zoning, pop0}.
## Constants in sim/economy.gd (POPC_*).

const E = preload("res://sim/economy.gd")

const FAMILY := ["none", "support", "generous"]
const FAMILY_INFO := {
	"none": {"title": "Basic", "desc": "No special help for families."},
	"support": {"title": "Support", "desc": "Child benefit and cheaper childcare."},
	"generous": {"title": "Generous", "desc": "Free childcare, long paid leave and big child benefits."},
}


static func st() -> Dictionary:
	if not Game.dip.has("pop"):
		Game.dip["pop"] = _fresh()
	return Game.dip.pop


static func _fresh() -> Dictionary:
	var c := Game.me()
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	var tfr := clampf(1.25 + 4.6 * pow(1.0 - lvl, 1.6), 1.0, 6.5)
	var urban := clampf(World.stat(Game.player, "urban_pct", 55.0), 10.0, 100.0)
	return {"tfr0": tfr, "tfr": tfr, "family": "none", "urban0": urban, "urban": urban,
		"afford": 100.0, "zoning": false, "pop0": c.population if c != null else 1.0, "last_news": -99}


static func fertility() -> float:
	return float(st().tfr)


static func urban() -> float:
	return float(st().urban)


static func afford() -> float:
	return float(st().afford)


static func family_cost_pct() -> float:
	if not Game.has_game() or not Game.dip.has("pop"):
		return 0.0
	return {"support": E.POPC_SUPPORT_COST, "generous": E.POPC_GENEROUS_COST}.get(str(st().family), 0.0)


static func set_family(f: String) -> void:
	if FAMILY.has(f):
		st().family = f


## Zoning reform: lets builders put up far more homes (costs political capital; some locals object).
static func reform_zoning() -> bool:
	if bool(st().zoning) or not Capital.spend(E.POPC_ZONING_CAPITAL):
		return false
	st().zoning = true
	Game.me().shocks.approval = float(Game.me().shocks.approval) - 1.0
	Game.add_feed("Zoning reform passed: builders can put up far more homes", "house", "accent")
	return true


## Age structure for the chart: shares of children (0-14), working age, 65+.
static func structure(c: CountryState) -> Array:
	var old := Ageing.share(c)
	var kids := clampf(8.0 + 9.0 * fertility() - 0.2 * old, 8.0, 50.0)
	return [kids, maxf(100.0 - kids - old, 20.0), old]


## Housing supply vs demand growth this year (points of affordability a year, + = easing).
static func housing_balance(c: CountryState) -> float:
	var s := st()
	var demand := E.POPC_URBAN_PRESSURE * float(s.get("urban_rate", 0.3)) \
		+ E.POPC_POP_PRESSURE * (c.pop_growth + Migration.pop_effect(Migration.delta(c)))
	var supply := E.POPC_PRIVATE_SUPPLY * (E.POPC_ZONING_MULT if bool(s.zoning) else 1.0)
	if Laws.is_active(c, "rent_control") and not c.laws_start.has("rent_control"):
		supply *= 0.75          # landlords and builders hold back
	if not c.builds.is_empty():
		supply += E.POPC_BUILD_SUPPLY * Builds.gain(c, "housing")
	# Only changes count: every country's builders already keep up with its normal pace.
	if not s.has("bal0"):
		s.bal0 = supply - demand
	return supply - demand - float(s.bal0)


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var c := Game.me()
	# Births drift toward the level your family policy supports.
	var target: float = float(s.tfr0) + {"support": E.POPC_SUPPORT_TFR, "generous": E.POPC_GENEROUS_TFR}.get(str(s.family), 0.0) \
		- E.POPC_TFR_DECLINE * Game.months_played / 12.0 * Economy.income_level(c.gdp_per_capita())
	s.tfr = float(s.tfr) + (clampf(target, 0.9, 7.0) - float(s.tfr)) / 36.0
	# Extra births (or fewer) beyond the start add to population growth.
	c.population *= 1.0 + E.POPC_TFR_POP * (float(s.tfr) - float(s.tfr0)) / 100.0 / 12.0
	# Below replacement (2.1), the population slowly shrinks unless migrants come.
	c.population *= 1.0 + E.POPC_LOW_TFR * (minf(float(s.tfr), 2.1) - 2.1) / 100.0 / 12.0
	# Cities grow as the country develops.
	var lvl := Economy.income_level(c.gdp_per_capita())
	var u_target := clampf(35.0 + 55.0 * lvl, float(s.urban0), 95.0)
	var u_before := float(s.urban)
	s.urban = minf(u_before + maxf(u_target - u_before, 0.0) * E.POPC_URBAN_SPEED / 12.0 + 0.02, 98.0)
	s.urban_rate = (float(s.urban) - u_before) * 12.0      # points a year
	# Housing affordability (100 = when you took office).
	var before := float(s.afford)
	s.afford = clampf(before + housing_balance(c) / 12.0, 30.0, 140.0)
	if float(s.afford) < 85.0 and Game.months_played - int(s.last_news) > 24:
		s.last_news = Game.months_played
		out.append({"text": "Housing crisis: rents hit a record and young people can't afford a home", "icon": "house", "good": false})
	return out


## Target offsets: housing on happiness and approval, the family policy bill and its warm glow.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("pop") or Game.me() == null:
		return {}
	var a := afford() - 100.0
	var out := {"happiness": E.POPC_AFFORD_HAPPY * a, "approval": E.POPC_AFFORD_APPROVAL * a,
		"gini": -E.POPC_AFFORD_GINI * a, "cost": family_cost_pct()}
	match str(st().family):
		"support":
			out.happiness += 0.8
		"generous":
			out.happiness += 2.0
			out.approval += 0.5
	return out
