class_name Climate
extends RefCounted
## Emissions and a warming world.
##
## Every country starts at its real CO2 per person and renewable energy share.
## Emissions then follow real income (Economy.CO2_INCOME_ELASTICITY), fall
## slowly as technology improves, and fall faster with the green laws and
## projects a country adds during play (CUTS). The world's total emissions set
## how fast the planet warms, and warming makes weather disasters more likely.
## Every other November (odd years; summits take the even ones) a UN climate
## conference asks for a pledge, which is judged when its deadline comes.
## State lives in Game.dip.climate: {warming, start_total, hist, pledge}.

## Laws and projects added during play -> share of a country's emissions they cut.
const CUTS := {"coal_phaseout": 0.15, "carbon_tax": 0.10, "nuclear": 0.12, "solar": 0.07, "wind": 0.07,
	"hydro": 0.06, "ev_subsidy": 0.04, "forests": 0.04, "rail": 0.03, "metro": 0.02}
## ... and points of renewable energy share they add.
const RENEW := {"solar": 7.0, "wind": 7.0, "hydro": 6.0, "coal_phaseout": 3.0, "ev_subsidy": 1.0}
## Clean energy and transport you add -> share of oil-price exposure it removes
## for an energy importer (IEA: oil-shock pass-through falls with oil's share
## of the energy mix; electric transport and rail replace oil directly).
const OIL_SHIELD := {"nuclear": 0.12, "solar": 0.08, "wind": 0.08, "hydro": 0.06, "ev_subsidy": 0.06,
	"rail": 0.04, "metro": 0.03}
## Events that a warmer world makes more likely.
const WEATHER := ["floods", "monsoon", "hurricane", "heatwave", "drought", "heat_grid"]


static func state() -> Dictionary:
	if not Game.dip.has("climate"):
		Game.dip["climate"] = {"warming": start_warming(), "start_total": world_total(), "hist": [start_warming()]}
	return Game.dip.climate


static func start_warming() -> float:
	return Economy.WARMING_2024 + Economy.WARMING_PER_YEAR * (Calendar.START_YEAR - 2024)


## Green laws and projects this country added after the start.
static func extras(c: CountryState) -> Array[String]:
	# Cached on the country until its laws or projects change (checked every tick).
	var key := Vector2i(c.laws_ver, c.projects_ver)
	if c.has_meta(&"climate_key") and c.get_meta(&"climate_key") == key:
		return c.get_meta(&"climate_extras")
	var out: Array[String] = []
	for id in CUTS:
		if Laws.is_active(c, id) and not c.laws_start.has(id):
			out.append(id)
		elif Projects.is_done(c, id) and not bool(c.projects[id].get("start", false)):
			out.append(id)
	c.set_meta(&"climate_key", key)
	c.set_meta(&"climate_extras", out)
	return out


## Tonnes of CO2 per person per year.
static func co2_pc(c: CountryState) -> float:
	if c == null:
		return 0.0
	var start := World.stat(c.idx, "co2_pc", 4.0)
	# Starting income from the data (c.base.gdp_pc adapts over time, see Simulation).
	var g0 := World.stat(c.idx, "gdp", c.gdp) / maxf(World.stat(c.idx, "population", c.population), 1000.0)
	var income := pow(maxf(c.real_gdp_per_capita(), 1.0) / maxf(g0, 1.0), Economy.CO2_INCOME_ELASTICITY)
	var tech := pow(1.0 - Economy.CO2_DECARB_PER_YEAR, Game.months_played / 12.0)
	var cut := 1.0
	for id in extras(c):
		cut *= 1.0 - float(CUTS[id])
	return start * income * tech * cut


## 0..1 multiplier on an importer's oil-price exposure (1 = nothing built yet).
static func oil_shield(c: CountryState) -> float:
	if c == null:
		return 1.0
	var s := 1.0
	for id in extras(c):
		s *= 1.0 - float(OIL_SHIELD.get(id, 0.0))
	return s


## Renewables, % of final energy use.
static func renewables(c: CountryState) -> float:
	if c == null:
		return 0.0
	var r := World.stat(c.idx, "renewables_pct", 20.0) + Economy.RENEWABLES_DRIFT_PER_YEAR * Game.months_played / 12.0
	for id in extras(c):
		r += float(RENEW.get(id, 0.0))
	return clampf(r, 0.0, 98.0)


## Change in emissions per person since the start, as a fraction (-0.12 = 12 % lower).
static func change(c: CountryState) -> float:
	var start := World.stat(c.idx, "co2_pc", 0.0)
	return co2_pc(c) / start - 1.0 if start > 0.0 else 0.0


## World emissions, tonnes per year.
static func world_total() -> float:
	var t := 0.0
	for c in Game.countries:
		if c != null:
			t += co2_pc(c) * c.population
	return t


static func world_average() -> float:
	var pop := 0.0
	for c in Game.countries:
		if c != null:
			pop += c.population
	return world_total() / maxf(pop, 1.0)


static func warming() -> float:
	return float(state().warming)


## Multiplier on weather-disaster odds.
static func disaster_mult() -> float:
	return 1.0 + maxf(warming() - start_warming(), 0.0) * Economy.CLIMATE_DISASTER_PER_DEG


static func pledge() -> Dictionary:
	return state().get("pledge", {})


static func make_pledge(cut: float) -> void:
	state()["pledge"] = {"cut": cut, "from": co2_pc(Game.me()), "due": Game.months_played + Economy.PLEDGE_YEARS * 12,
		"year": Game.year + Economy.PLEDGE_YEARS}


## Progress toward the pledge: fraction cut so far since it was made.
static func pledge_done() -> float:
	var p := pledge()
	if p.is_empty():
		return 0.0
	return 1.0 - co2_pc(Game.me()) / maxf(float(p.from), 0.0001)


## Monthly: warm the world each January, and judge a pledge when it's due.
static func monthly() -> void:
	var st := state()
	if Game.month == 1:
		var total := world_total()
		st.warming = float(st.warming) + Economy.WARMING_PER_YEAR * total / maxf(float(st.start_total), 1.0)
		(st.hist as Array).append(snappedf(float(st.warming), 0.001))
	var p := pledge()
	if p.is_empty():
		return
	var done := pledge_done()
	if Game.months_played == int(p.due) - 24:
		Game.add_feed("Two years left on your climate pledge: emissions %s so far, you promised −%d%%" % [
			_pct(-done), roundi(float(p.cut) * 100.0)], "leaf", "teal")
	if Game.months_played < int(p.due):
		return
	st.erase("pledge")
	if done >= float(p.cut) - 0.005:
		Game.add_feed("Climate pledge kept: emissions down %d%%. Partners are impressed." % roundi(done * 100.0), "leaf", "green")
		Game.add_milestone("Kept the climate pledge (−%d%%)" % roundi(done * 100.0), "leaf", "green")
		GameEvents.apply_effects({"relations_all": 3.0, "happiness": 1.5, "press_cred": 4.0}, -1)
		Achievements.unlock("promise_kept")
	else:
		Game.add_feed("Climate pledge missed: emissions %s, you promised −%d%%" % [_pct(-done), roundi(float(p.cut) * 100.0)],
			"leaf", "orange")
		GameEvents.apply_effects({"bloc_relations": {"west": -4.0, "south": -3.0}, "press_cred": -6.0}, -1)


## "+4%", "−12%" or "unchanged".
static func _pct(x: float) -> String:
	if absf(x) < 0.005:
		return "unchanged"
	return ("+%d%%" if x > 0.0 else "−%d%%") % roundi(absf(x) * 100.0)


## The UN climate conference: what will you promise?
static func cop_event(rng: RandomNumberGenerator) -> Dictionary:
	var me := Game.me()
	var by := Game.year + Economy.PLEDGE_YEARS
	var host := World.map.names[World.playable[rng.randi() % World.playable.size()]]
	var e := {"id": "cop", "title": "COP%d climate conference" % (30 + Game.year - 2025), "icon": "leaf", "tint": "green",
		"weight": 0.0,
		"body": "Leaders meet in %s and every country is asked for a new emissions pledge. {country} emits %s tonnes of CO₂ per person a year (world average %s)." % [
			host, String.num(co2_pc(me), 1), String.num(world_average(), 1)],
		"choices": [
			{"label": "Bold: cut emissions %d%% by %d" % [roundi(Economy.PLEDGE_BOLD * 100.0), by],
				"detail": "Partners cheer · you must deliver",
				"effects": {"pledge": Economy.PLEDGE_BOLD, "bloc_relations": {"west": 3.0, "south": 2.0}, "happiness": 0.8}},
			{"label": "Modest: cut %d%% by %d" % [roundi(Economy.PLEDGE_MODEST * 100.0), by],
				"detail": "Polite applause",
				"effects": {"pledge": Economy.PLEDGE_MODEST, "bloc_relations": {"west": 1.0, "south": 1.0}}},
			{"label": "No new promises", "detail": "Activists protest",
				"effects": {"bloc_relations": {"west": -2.0, "south": -1.5}, "happiness": -0.5}}]}
	return GameEvents.instance(e)
