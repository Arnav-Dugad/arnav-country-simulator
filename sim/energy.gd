class_name Energy
extends RefCounted
## Energy & resources.
##   Reserves     oil, gas, coal and minerals, from your country's real export
##                profile. Each pays "rents" (a share of GDP) while it lasts.
##                Production policy: expand (more money now, runs out sooner,
##                more emissions), steady, or wind down (less money, lasts longer).
##                When a reserve runs dry its income stops: the resource cliff.
##                Saving the rents in the wealth fund softens it.
##   Exploration  spend to look for new deposits: a chance of decades more.
##   Power        electricity demand grows with your economy (less with
##                efficiency); supply grows a little on its own and with every
##                power plant, solar and wind farm, dam or grid line you build.
##                Fall short and rolling blackouts hit growth and happiness.
## State: Game.dip.energy {res: {id: {level, years, years0, policy}}, gdp0, last_blackout,
## explored}. Constants in sim/economy.gd (EN_*).

const E = preload("res://sim/economy.gd")

const RESOURCES := {
	"oil": {"title": "Oil", "icon": "fuel", "co2": 0.03},
	"gas": {"title": "Natural gas", "icon": "flame", "co2": 0.02},
	"coal": {"title": "Coal", "icon": "mountain", "co2": 0.06},
	"minerals": {"title": "Critical minerals", "icon": "gem", "co2": 0.0},
}
const POLICIES := ["wind_down", "steady", "expand"]
const POLICY_TITLE := {"wind_down": "Wind down", "steady": "Steady", "expand": "Expand"}

## Big producers by resource (beyond what export data shows): iso -> level 1..3.
const GAS := {"QAT": 3, "RUS": 3, "IRN": 2, "NOR": 2, "DZA": 2, "TKM": 3, "AUS": 1, "USA": 1, "TTO": 2, "MOZ": 1, "AZE": 1}
const COAL := {"CHN": 3, "IND": 3, "IDN": 3, "AUS": 3, "USA": 2, "RUS": 2, "ZAF": 3, "KAZ": 2, "COL": 2, "MNG": 3, "POL": 2, "DEU": 1, "TUR": 1, "VNM": 1, "UKR": 1}
const MINERALS := {"CHL": 3, "COD": 3, "PER": 2, "AUS": 3, "ZMB": 3, "BOL": 2, "ARG": 1, "CHN": 2, "BRA": 2, "ZAF": 2, "GIN": 2, "IDN": 2, "CAN": 1, "MNG": 1, "PHL": 1, "ZWE": 1, "MAR": 2}


static func st() -> Dictionary:
	if not Game.dip.has("energy"):
		Game.dip["energy"] = _fresh()
	return Game.dip.energy


static func _fresh() -> Dictionary:
	var i := Game.player
	var iso := World.iso(i)
	var fuel := World.stat(i, "fuel_exports_pct", 0.0)
	var res := {}
	var oil_lvl := 3 if fuel >= 60.0 else (2 if fuel >= 30.0 else (1 if fuel >= 10.0 else 0))
	var levels := {"oil": oil_lvl, "gas": int(GAS.get(iso, 1 if oil_lvl >= 2 else 0)),
		"coal": int(COAL.get(iso, 0)), "minerals": int(MINERALS.get(iso, 0))}
	for id in RESOURCES:
		var lvl := int(levels[id])
		if lvl <= 0:
			continue
		var yrs := float(25 + absi(hash(iso + id)) % 45)          # 25..70 years at today's pace
		res[id] = {"level": lvl, "years": yrs, "years0": yrs, "policy": "steady"}
	var c := Game.me()
	return {"res": res, "gdp0": c.gdp if c != null else 1.0, "last_blackout": -99, "explored": -99}


## Rents from a resource, % of GDP at the start (before your policy).
static func rent0(id: String) -> float:
	var r: Dictionary = st().res.get(id, {})
	if r.is_empty():
		return 0.0
	var lvl := int(r.level)
	if id == "oil":
		return clampf(World.stat(Game.player, "fuel_exports_pct", 0.0) * World.stat(Game.player, "trade_pct", 40.0) / 100.0 * 0.35, 0.5, 30.0)
	return [0.0, 0.8, 2.0, 4.5][lvl]


static func _pace(policy: String) -> float:
	return {"wind_down": E.EN_WIND_DOWN, "expand": E.EN_EXPAND}.get(policy, 1.0)


## Rents now, % of GDP (0 once a reserve is gone; follows world prices for oil and gas).
static func rent(id: String) -> float:
	var r: Dictionary = st().res.get(id, {})
	if r.is_empty() or float(r.years) <= 0.0:
		return 0.0
	# (Oil and gas price swings are already in world markets; only volume counts here.)
	var price := 1.0
	if id == "minerals":
		price = 1.0 + E.EN_MINERAL_BOOM * clampf(Game.months_played / 240.0, 0.0, 1.0)    # the battery age
	# Rents are a share of the economy you had: they don't grow with the rest of it.
	var scale := 1.0 / maxf(real_growth(), 0.01)
	return rent0(id) * _pace(str(r.policy)) * price * scale


static func set_policy(id: String, p: String) -> void:
	var r: Dictionary = st().res.get(id, {})
	if not r.is_empty() and POLICIES.has(p):
		r.policy = p


# --------------------------------------------------------------- exploration ---
static func explore_cost() -> float:
	return Game.me().gdp * E.EN_EXPLORE_COST / 100.0


static func explore_wait() -> int:
	return maxi(0, int(st().explored) + 24 - Game.months_played)


## Look for new deposits. Returns a headline.
static func explore() -> String:
	if explore_wait() > 0:
		return ""
	var s := st()
	Game.me().treasury -= explore_cost()
	s.explored = Game.months_played
	var res: Dictionary = s.res
	var chance := 0.25 + 0.1 * float(res.size())
	if Game.rng.randf() > chance:
		return "Exploration finds nothing worth drilling this time"
	var ids: Array = res.keys() if not res.is_empty() else ["minerals"]
	var id := str(ids[Game.rng.randi() % ids.size()])
	if not res.has(id):
		res[id] = {"level": 1, "years": 0.0, "years0": 0.0, "policy": "steady"}
	var more := Game.rng.randf_range(8.0, 30.0)
	res[id].years = float(res[id].years) + more
	res[id].years0 = maxf(float(res[id].years0), float(res[id].years))
	return "Discovery: new %s deposits add about %d years" % [str(RESOURCES[id].title).to_lower(), roundi(more)]


# ------------------------------------------------------------------- power ---
## Electricity demand index (1 = at the start): grows with the economy, less
## each year as appliances and factories get more efficient.
## Real economy now against the start (dollar inflation doesn't use more power
## or make a mine bigger).
static func real_growth() -> float:
	var c := Game.me()
	return c.gdp / maxf(c.price_index, 0.01) / maxf(float(st().gdp0), 1.0)


static func demand() -> float:
	var g := real_growth()
	# Rich economies use far less electricity per dollar (services, efficiency).
	var e := pow(minf(maxf(g, 0.1), E.RICH_SATURATION), E.EN_DEMAND_ELASTICITY)
	if g > E.RICH_SATURATION:
		e *= pow(g / E.RICH_SATURATION, E.EN_DEMAND_ELASTICITY * E.RICH_TAIL)
	return e * pow(1.0 - E.EN_EFFICIENCY, Game.months_played / 12.0)


## Supply index: the grid you started with, private investment, and what you build.
## Every plant adds its own output: power adds up, it doesn't saturate the way
## "coverage" of hospitals or schools does (a booming economy can always build more).
static func supply() -> float:
	var c := Game.me()
	# Private investors build some plants on their own, more when demand booms.
	var priv := maxf(E.EN_PRIVATE_GROWTH * Game.months_played / 12.0, E.EN_PRIVATE_SHARE * (demand() - 1.0))
	var s := 1.0 + priv + float(st().get("bonus", 0.0))
	if not c.builds.is_empty():
		var cond := Builds.condition()
		for id in Builds.ids_in("Energy"):
			var b: Dictionary = c.builds.get(id, {})
			if b.is_empty():
				continue
			var power := float(Builds.spec(str(id)).get("power", 1.0))
			# New plants add their output (worn down by poor maintenance)...
			s += maxf(float(b.n) - float(b.n0), 0.0) * cond * unit_supply(str(id))
			# ...and neglect wears the grid you started with, gently, as before.
			s += E.EN_BUILD_SUPPLY * power * (Builds.coverage_of(c, str(id), minf(float(b.n), float(b.n0)) * cond) - Builds.coverage_of(c, str(id), float(b.n0)))
	return maxf(s, 0.2)


## Supply one more unit of an energy build adds.
static func unit_supply(id: String) -> float:
	return E.EN_BUILD_SUPPLY * float(Builds.spec(id).get("power", 1.0)) / Builds.need_at_start(Game.me(), id)


## About how many more of a build would end the shortfall (0 = none needed).
static func units_to_fix(id: String) -> int:
	var gap := demand() - supply() - E.EN_MARGIN
	if gap <= 0.0:
		return 0
	return int(ceil(gap / maxf(unit_supply(id), 1e-9)))


## Shortfall share (0 = enough power).
static func shortage() -> float:
	return maxf(demand() - supply() - E.EN_MARGIN, 0.0)


# ----------------------------------------------------------------- monthly ---
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var s := st()
	for id in s.res:
		var r: Dictionary = s.res[id]
		if float(r.years) <= 0.0:
			continue
		r.years = maxf(float(r.years) - _pace(str(r.policy)) / 12.0, 0.0)
		if float(r.years) <= 0.0:
			Game.me().shocks.growth = float(Game.me().shocks.growth) - minf(rent0(str(id)) * 0.4, 4.0)
			out.append({"text": "The last %s fields are exhausted: the income is gone" % str(RESOURCES[id].title).to_lower(),
				"icon": str(RESOURCES[id].icon), "good": false})
		elif float(r.years) <= 5.0 and float(r.years) + _pace(str(r.policy)) / 12.0 > 5.0:
			out.append({"text": "Only about 5 years of %s left. Explore, or save for life after it" % str(RESOURCES[id].title).to_lower(),
				"icon": str(RESOURCES[id].icon), "good": false})
	var sh := shortage()
	if sh > 0.0 and Game.months_played - int(s.last_blackout) > 18:
		s.last_blackout = Game.months_played
		out.append({"text": "Rolling blackouts: power demand has outgrown your grid. Build power plants", "icon": "zap-off", "good": false})
	return out


## Target offsets: rents beyond (or short of) the start, blackouts, policy side effects.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("energy") or Game.me() == null:
		return {}
	var out := {"revenue": 0.0, "growth": 0.0, "co2": 0.0, "happiness": 0.0, "unemployment": 0.0}
	var scale := 1.0 / maxf(real_growth(), 0.01)
	for id in st().res:
		var d := rent(str(id)) - rent0(str(id)) * scale
		out.revenue += E.EN_GOV_TAKE * d
		out.growth += E.EN_RENT_GROWTH * d
		out.unemployment -= E.EN_RENT_JOBS * d
		var p := str(st().res[id].policy)
		if p == "expand":
			out.co2 += float(RESOURCES[id].co2)
		elif p == "wind_down":
			out.co2 -= float(RESOURCES[id].co2) * 0.5
	var sh := shortage()
	if sh > 0.0:
		out.growth -= E.EN_BLACKOUT_GROWTH * minf(sh * 10.0, 1.5)
		out.happiness -= E.EN_BLACKOUT_HAPPY * minf(sh * 10.0, 1.5)
	return out
