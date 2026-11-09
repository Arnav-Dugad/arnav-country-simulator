class_name Builds
extends RefCounted
## Countable builds: hospitals, schools, stadiums, power plants, roads, military
## units… You choose how many to build (and can demolish some), unlike the
## one-off national programmes in Projects.
##
## Each type has a NEED: the number of units per million people that gives full
## coverage. Coverage follows cov(n) = 1 - exp(-n / need), so the first units in
## an under-served country matter a lot and extra units in a saturated one
## little. Every country starts with a realistic stock for its income level;
## only coverage gained beyond that counts (fx = effect of going 0 -> 100 %).
## Unit prices follow local price levels (cheaper labour and land in poorer
## countries). State per country: c.builds {id: {n, n0, batches: [{n, left, price}]}}.

const E = preload("res://sim/economy.gd")

const GROUPS := ["Transport", "Energy", "Health & care", "Education", "Housing & cities", "Economy", "Culture & sport", "Defence"]

## id -> spec. usd: price per unit at US price levels. pm: units needed per
## million people for full coverage. rich/poor: starting coverage for the
## richest / poorest economies. upkeep: yearly running cost, share of price.
## fx: effect of going from 0 to full coverage (targets, like laws).
const ALL := {
	# ---- Transport
	"highway": {"group": "Transport", "icon": "route", "title": "Highway", "unit": "100 km of highway", "usd": 2.0e9, "months": 30,
		"pm": 1.2, "rich": 0.9, "poor": 0.25, "upkeep": 0.02, "fx": {"growth": 0.9, "unemployment": -0.3}},
	"rail": {"group": "Transport", "icon": "train-front", "title": "Rail line", "unit": "100 km of rail", "usd": 3.0e9, "months": 36,
		"pm": 0.5, "rich": 0.75, "poor": 0.15, "upkeep": 0.025, "fx": {"growth": 0.6, "happiness": 0.8}},
	"metro_line": {"group": "Transport", "icon": "tram-front", "title": "Metro line", "unit": "metro line", "usd": 6.0e9, "months": 48,
		"pm": 0.08, "rich": 0.6, "poor": 0.05, "upkeep": 0.03, "fx": {"growth": 0.3, "happiness": 1.5}},
	"bus_rapid": {"group": "Transport", "icon": "bus", "title": "Rapid bus line", "unit": "bus corridor", "usd": 3.0e8, "months": 12,
		"pm": 0.3, "rich": 0.6, "poor": 0.15, "upkeep": 0.05, "fx": {"happiness": 0.8, "growth": 0.1}},
	"airport": {"group": "Transport", "icon": "plane", "title": "Airport", "unit": "airport", "usd": 4.0e9, "months": 48,
		"pm": 0.03, "rich": 0.85, "poor": 0.3, "upkeep": 0.03, "fx": {"growth": 0.4, "relations_soft": 1.0}},
	"seaport": {"group": "Transport", "icon": "anchor", "title": "Container port", "unit": "port terminal", "usd": 2.5e9, "months": 42,
		"pm": 0.02, "rich": 0.85, "poor": 0.3, "upkeep": 0.03, "coast": true, "fx": {"growth": 0.5, "unemployment": -0.2}},
	"ev_chargers": {"group": "Transport", "icon": "plug-zap", "title": "EV chargers", "unit": "1,000 fast chargers", "usd": 1.5e8, "months": 6,
		"pm": 0.6, "rich": 0.3, "poor": 0.02, "upkeep": 0.06, "fx": {"happiness": 0.3}, "co2": 0.03},
	"logistics": {"group": "Transport", "icon": "truck", "title": "Logistics hub", "unit": "logistics hub", "usd": 6.0e8, "months": 18,
		"pm": 0.05, "rich": 0.8, "poor": 0.2, "upkeep": 0.04, "fx": {"growth": 0.3, "unemployment": -0.3}},
	"maglev": {"group": "Transport", "icon": "train-front", "title": "Maglev line", "unit": "300 km maglev line", "usd": 1.5e10, "months": 48,
		"pm": 0.01, "rich": 0.0, "poor": 0.0, "upkeep": 0.02, "big": true, "tech": "maglev", "fx": {"growth": 0.5, "happiness": 1.0}},
	# ---- Energy
	"solar_farm": {"group": "Energy", "icon": "sun", "title": "Solar farm", "unit": "100 MW solar farm", "usd": 1.0e8, "months": 9,
		"pm": 4.0, "rich": 0.25, "poor": 0.05, "upkeep": 0.015, "fx": {"inflation": -0.3, "happiness": 0.4}, "co2": 0.12},
	"wind_farm": {"group": "Energy", "icon": "wind", "title": "Wind farm", "unit": "100 MW wind farm", "usd": 1.4e8, "months": 14,
		"pm": 3.0, "rich": 0.25, "poor": 0.03, "upkeep": 0.02, "fx": {"inflation": -0.3, "happiness": 0.3}, "co2": 0.12},
	"gas_plant": {"group": "Energy", "icon": "flame", "title": "Gas power plant", "unit": "500 MW gas plant", "usd": 5.0e8, "months": 24,
		"pm": 0.6, "rich": 0.8, "poor": 0.3, "upkeep": 0.04, "fx": {"growth": 0.4, "inflation": -0.2}, "co2": -0.05},
	"nuclear_reactor": {"group": "Energy", "icon": "atom", "title": "Nuclear reactor", "unit": "1 GW reactor", "usd": 8.0e9, "months": 84,
		"pm": 0.25, "rich": 0.55, "poor": 0.0, "upkeep": 0.025, "big": true, "fx": {"growth": 0.4, "inflation": -0.4}, "co2": 0.15},
	"hydro_dam": {"group": "Energy", "icon": "droplets", "title": "Hydro dam", "unit": "hydro dam", "usd": 3.0e9, "months": 60,
		"pm": 0.03, "rich": 0.6, "poor": 0.2, "upkeep": 0.02, "fx": {"growth": 0.3, "inflation": -0.2, "happiness": -0.2}, "co2": 0.06},
	"battery": {"group": "Energy", "icon": "battery-charging", "title": "Grid battery", "unit": "200 MWh battery", "usd": 8.0e7, "months": 6,
		"pm": 1.0, "rich": 0.1, "poor": 0.0, "upkeep": 0.03, "fx": {"stability": 0.4, "inflation": -0.1}, "co2": 0.03},
	"geothermal": {"group": "Energy", "icon": "mountain", "title": "Geothermal plant", "unit": "50 MW geothermal plant", "usd": 2.5e8, "months": 30,
		"pm": 0.2, "rich": 0.2, "poor": 0.05, "upkeep": 0.03, "fx": {"inflation": -0.15}, "co2": 0.04},
	"fusion_plant": {"group": "Energy", "icon": "atom", "title": "Fusion plant", "unit": "2 GW fusion plant", "usd": 1.2e10, "months": 60,
		"pm": 0.1, "rich": 0.0, "poor": 0.0, "upkeep": 0.02, "big": true, "tech": "fusion", "fx": {"growth": 0.6, "inflation": -0.6}, "co2": 0.25},
	"grid_line": {"group": "Energy", "icon": "zap", "title": "Power lines", "unit": "500 km of power lines", "usd": 4.0e8, "months": 18,
		"pm": 0.8, "rich": 0.95, "poor": 0.35, "upkeep": 0.02, "fx": {"growth": 0.6, "happiness": 1.2}},
	# ---- Health & care
	"hospital": {"group": "Health & care", "icon": "hospital", "title": "Hospital", "unit": "500-bed hospital", "usd": 4.0e8, "months": 30,
		"pm": 4.0, "rich": 0.85, "poor": 0.25, "upkeep": 0.12, "fx": {"happiness": 4.0, "stability": 1.0}, "life": 4.0},
	"clinic": {"group": "Health & care", "icon": "stethoscope", "title": "Clinic", "unit": "community clinic", "usd": 6.0e6, "months": 8,
		"pm": 60.0, "rich": 0.85, "poor": 0.3, "upkeep": 0.15, "fx": {"happiness": 2.5}, "life": 3.0},
	"care_home": {"group": "Health & care", "icon": "heart", "title": "Care home", "unit": "120-bed care home", "usd": 2.5e7, "months": 12,
		"pm": 15.0, "rich": 0.7, "poor": 0.1, "upkeep": 0.15, "fx": {"happiness": 1.5}, "elderly": true},
	"water_plant": {"group": "Health & care", "icon": "glass-water", "title": "Water treatment plant", "unit": "water plant", "usd": 1.5e8, "months": 18,
		"pm": 2.0, "rich": 0.97, "poor": 0.35, "upkeep": 0.05, "fx": {"happiness": 2.0, "stability": 0.5}, "life": 3.0},
	# ---- Education
	"school": {"group": "Education", "icon": "school", "title": "School", "unit": "school for 1,000 pupils", "usd": 3.0e7, "months": 14,
		"pm": 140.0, "rich": 0.95, "poor": 0.45, "upkeep": 0.12, "fx": {"happiness": 1.5, "growth": 0.3}, "lit": 12.0},
	"university": {"group": "Education", "icon": "graduation-cap", "title": "University", "unit": "university campus", "usd": 1.2e9, "months": 36,
		"pm": 0.6, "rich": 0.85, "poor": 0.2, "upkeep": 0.1, "fx": {"growth": 0.5, "happiness": 0.5}},
	"library": {"group": "Education", "icon": "book-open", "title": "Library", "unit": "public library", "usd": 1.5e7, "months": 10,
		"pm": 10.0, "rich": 0.85, "poor": 0.15, "upkeep": 0.1, "fx": {"happiness": 0.6}, "lit": 2.0},
	"quantum_lab": {"group": "Education", "icon": "atom", "title": "Quantum lab", "unit": "quantum computing centre", "usd": 2.0e9, "months": 30,
		"pm": 0.02, "rich": 0.0, "poor": 0.0, "upkeep": 0.08, "big": true, "tech": "quantum", "fx": {"growth": 0.6}},
	"research_lab": {"group": "Education", "icon": "flask-conical", "title": "Research lab", "unit": "national research lab", "usd": 5.0e8, "months": 24,
		"pm": 0.3, "rich": 0.7, "poor": 0.05, "upkeep": 0.12, "fx": {"growth": 0.5}},
	# ---- Housing & cities
	"housing": {"group": "Housing & cities", "icon": "house", "title": "Affordable homes", "unit": "1,000 affordable homes", "usd": 2.5e8, "months": 20,
		"pm": 6.0, "rich": 0.7, "poor": 0.25, "upkeep": 0.01, "fx": {"happiness": 3.0, "stability": 1.0}, "gini": -2.0},
	"police": {"group": "Housing & cities", "icon": "siren", "title": "Police station", "unit": "police station", "usd": 2.0e7, "months": 10,
		"pm": 12.0, "rich": 0.85, "poor": 0.35, "upkeep": 0.3, "fx": {"stability": 3.0}},
	"fire_station": {"group": "Housing & cities", "icon": "fire-extinguisher", "title": "Fire station", "unit": "fire station", "usd": 1.2e7, "months": 9,
		"pm": 15.0, "rich": 0.9, "poor": 0.3, "upkeep": 0.2, "fx": {"stability": 1.0, "happiness": 0.6}, "disaster": 0.25},
	"park": {"group": "Housing & cities", "icon": "trees", "title": "City park", "unit": "city park", "usd": 3.0e7, "months": 10,
		"pm": 5.0, "rich": 0.75, "poor": 0.2, "upkeep": 0.04, "fx": {"happiness": 1.5}, "co2": 0.01},
	"recycling": {"group": "Housing & cities", "icon": "recycle", "title": "Recycling centre", "unit": "recycling centre", "usd": 6.0e7, "months": 10,
		"pm": 1.5, "rich": 0.6, "poor": 0.05, "upkeep": 0.08, "fx": {"happiness": 0.6}, "co2": 0.03},
	"prison": {"group": "Housing & cities", "icon": "lock", "title": "Prison", "unit": "prison", "usd": 2.0e8, "months": 24,
		"pm": 0.6, "rich": 0.85, "poor": 0.4, "upkeep": 0.15, "fx": {"stability": 1.2, "happiness": -0.3}},
	# ---- Economy
	"industrial_park": {"group": "Economy", "icon": "factory", "title": "Industrial park", "unit": "industrial park", "usd": 8.0e8, "months": 24,
		"pm": 0.4, "rich": 0.75, "poor": 0.15, "upkeep": 0.02, "fx": {"growth": 0.8, "unemployment": -0.8}, "co2": -0.04},
	"data_center": {"group": "Economy", "icon": "server", "title": "Data centre", "unit": "data centre", "usd": 1.0e9, "months": 18,
		"pm": 0.15, "rich": 0.5, "poor": 0.02, "upkeep": 0.06, "fx": {"growth": 0.5}},
	"chip_fab": {"group": "Economy", "icon": "cpu", "title": "Chip factory", "unit": "semiconductor fab", "usd": 2.0e10, "months": 48,
		"pm": 0.01, "rich": 0.2, "poor": 0.0, "upkeep": 0.05, "big": true, "fx": {"growth": 0.9, "unemployment": -0.2}},
	"tech_hub": {"group": "Economy", "icon": "lightbulb", "title": "Startup hub", "unit": "startup hub", "usd": 2.0e8, "months": 12,
		"pm": 0.2, "rich": 0.5, "poor": 0.03, "upkeep": 0.08, "fx": {"growth": 0.4, "happiness": 0.3}},
	"irrigation": {"group": "Economy", "icon": "sprout", "title": "Irrigation scheme", "unit": "irrigation scheme", "usd": 1.5e8, "months": 18,
		"pm": 0.8, "rich": 0.85, "poor": 0.3, "upkeep": 0.03, "fx": {"growth": 0.3, "inflation": -0.3, "stability": 0.4}},
	"market_hall": {"group": "Economy", "icon": "store", "title": "Market hall", "unit": "market hall", "usd": 2.0e7, "months": 8,
		"pm": 3.0, "rich": 0.7, "poor": 0.3, "upkeep": 0.05, "fx": {"unemployment": -0.3, "happiness": 0.3}},
	"refinery": {"group": "Economy", "icon": "fuel", "title": "Oil refinery", "unit": "refinery", "usd": 6.0e9, "months": 48,
		"pm": 0.01, "rich": 0.6, "poor": 0.15, "upkeep": 0.04, "big": true, "fx": {"growth": 0.4, "inflation": -0.3}, "co2": -0.06},
	"warehouse": {"group": "Economy", "icon": "warehouse", "title": "Strategic reserve", "unit": "grain & fuel reserve depot", "usd": 3.0e8, "months": 12,
		"pm": 0.15, "rich": 0.6, "poor": 0.1, "upkeep": 0.03, "fx": {"stability": 0.6, "inflation": -0.2}},
	# ---- Culture & sport
	"stadium": {"group": "Culture & sport", "icon": "trophy", "title": "Stadium", "unit": "40,000-seat stadium", "usd": 6.0e8, "months": 30,
		"pm": 0.15, "rich": 0.85, "poor": 0.25, "upkeep": 0.03, "fx": {"happiness": 1.5, "approval": 0.8}},
	"sports_centre": {"group": "Culture & sport", "icon": "dumbbell", "title": "Sports centre", "unit": "sports centre", "usd": 2.0e7, "months": 9,
		"pm": 12.0, "rich": 0.8, "poor": 0.15, "upkeep": 0.1, "fx": {"happiness": 1.5}, "life": 0.6},
	"museum": {"group": "Culture & sport", "icon": "landmark", "title": "Museum", "unit": "museum", "usd": 1.5e8, "months": 20,
		"pm": 0.6, "rich": 0.8, "poor": 0.15, "upkeep": 0.06, "fx": {"happiness": 0.8, "growth": 0.1}},
	"concert_hall": {"group": "Culture & sport", "icon": "music", "title": "Concert hall", "unit": "concert hall", "usd": 2.5e8, "months": 24,
		"pm": 0.15, "rich": 0.75, "poor": 0.1, "upkeep": 0.06, "fx": {"happiness": 0.8, "approval": 0.3}},
	# ---- Defence (military strength comes from these as well as the budget)
	"infantry": {"group": "Defence", "icon": "users", "title": "Infantry brigade", "unit": "brigade (4,000 troops)", "usd": 1.2e9, "months": 18,
		"pm": 0.25, "rich": 0.7, "poor": 0.5, "upkeep": 0.25, "fx": {"stability": 0.8}, "mil": 18.0},
	"armour": {"group": "Defence", "icon": "shield", "title": "Armoured brigade", "unit": "armoured brigade (120 tanks)", "usd": 3.5e9, "months": 30,
		"pm": 0.05, "rich": 0.6, "poor": 0.2, "upkeep": 0.15, "fx": {}, "mil": 14.0},
	"fighters": {"group": "Defence", "icon": "plane", "title": "Fighter squadron", "unit": "squadron (16 jets)", "usd": 1.6e9, "months": 36,
		"pm": 0.04, "rich": 0.6, "poor": 0.15, "upkeep": 0.1, "fx": {}, "mil": 16.0},
	"frigate": {"group": "Defence", "icon": "ship", "title": "Frigate", "unit": "frigate", "usd": 1.0e9, "months": 48,
		"pm": 0.04, "rich": 0.55, "poor": 0.1, "upkeep": 0.08, "coast": true, "fx": {}, "mil": 12.0},
	"submarine": {"group": "Defence", "icon": "anchor", "title": "Submarine", "unit": "attack submarine", "usd": 2.5e9, "months": 60,
		"pm": 0.01, "rich": 0.4, "poor": 0.0, "upkeep": 0.06, "coast": true, "big": true, "fx": {}, "mil": 10.0},
	"air_defence": {"group": "Defence", "icon": "radar", "title": "Air defence battery", "unit": "air defence battery", "usd": 1.0e9, "months": 24,
		"pm": 0.05, "rich": 0.5, "poor": 0.1, "upkeep": 0.08, "fx": {"stability": 0.5}, "mil": 10.0},
	"drones": {"group": "Defence", "icon": "crosshair", "title": "Drone squadron", "unit": "drone squadron", "usd": 2.0e8, "months": 9,
		"pm": 0.08, "rich": 0.3, "poor": 0.05, "upkeep": 0.12, "fx": {}, "mil": 8.0},
	"cyber": {"group": "Defence", "icon": "shield-check", "title": "Cyber command unit", "unit": "cyber unit", "usd": 1.5e8, "months": 12,
		"pm": 0.02, "rich": 0.4, "poor": 0.02, "upkeep": 0.2, "fx": {"stability": 0.6}, "mil": 6.0},
	"spaceport": {"group": "Defence", "icon": "rocket", "title": "Spaceport", "unit": "launch complex", "usd": 3.0e9, "months": 36,
		"pm": 0.01, "rich": 0.0, "poor": 0.0, "upkeep": 0.04, "big": true, "tech": "rockets", "fx": {"growth": 0.2, "happiness": 0.5}, "mil": 4.0},
	"satellite": {"group": "Defence", "icon": "satellite", "title": "Satellite", "unit": "observation satellite", "usd": 5.0e8, "months": 36,
		"pm": 0.01, "rich": 0.35, "poor": 0.0, "upkeep": 0.05, "big": true, "fx": {"growth": 0.05}, "mil": 6.0},
	"base": {"group": "Defence", "icon": "castle", "title": "Military base", "unit": "military base", "usd": 1.5e9, "months": 30,
		"pm": 0.04, "rich": 0.7, "poor": 0.35, "upkeep": 0.08, "fx": {"stability": 0.5, "unemployment": -0.1}, "mil": 8.0},
}


static func spec(id: String) -> Dictionary:
	return ALL.get(id, {})


static func ids_in(group: String) -> Array:
	var out: Array = []
	for id in ALL:
		if str(ALL[id].group) == group:
			out.append(id)
	return out


## Units for full coverage in this country.
static func need(c: CountryState, id: String) -> float:
	var s := spec(id)
	var pop_m := c.population / 1e6
	var n := float(s.pm) * pop_m
	# Big national assets: even small countries can use one if they can pay for it.
	if bool(s.get("big", false)):
		n = maxf(n, 0.6)
	return maxf(n, 0.3)


## Need measured against the population when you took office (a fixed yardstick).
static func need_at_start(c: CountryState, id: String) -> float:
	var s := spec(id)
	var n := float(s.pm) * World.stat(c.idx, "population", c.population) / 1e6
	if bool(s.get("big", false)):
		n = maxf(n, 0.6)
	return maxf(n, 0.3)


static func coverage_of(c: CountryState, id: String, n: float) -> float:
	return 1.0 - exp(-n / need(c, id))


## Units a country has at the start (its real stock, from income level).
static func start_units(c: CountryState, id: String) -> int:
	var s := spec(id)
	if not available(c, id).is_empty():
		return 0
	var lvl := Economy.income_level(c.gdp_per_capita())
	var cov := clampf(lerpf(float(s.poor), float(s.rich), lvl), 0.0, 0.97)
	if str(s.group) == "Defence":
		cov = clampf(cov * clampf(c.military / 55.0, 0.2, 1.6), 0.0, 0.97)
	return int(round(-need(c, id) * log(1.0 - cov)))


## "" if this country can build it, else why not.
static func available(c: CountryState, id: String) -> String:
	var s := spec(id)
	if s.has("tech") and not (c.idx == Game.player and Tech.has(str(s.tech))):
		return "Needs research: %s" % str(Tech.ALL[str(s.tech)].title)
	if bool(s.get("coast", false)) and World.landlocked(c.idx):
		return "Your country has no coastline"
	if id == "nuclear_reactor" and (c.population < 4e6 or Economy.income_level(c.gdp_per_capita()) < 0.3):
		return "Needs a larger, industrial economy"
	if id == "chip_fab" and c.gdp < 1.5e11:
		return "Needs an economy above $150B"
	return ""


static func _st(c: CountryState, id: String) -> Dictionary:
	if not c.builds.has(id):
		var n0 := start_units(c, id)
		c.builds[id] = {"n": n0, "n0": n0, "batches": []}
	return c.builds[id]


static func count(c: CountryState, id: String) -> int:
	return int(_st(c, id).n)


static func building(c: CountryState, id: String) -> int:
	var q := 0
	for b in _st(c, id).batches:
		q += int(b.n)
	return q


## Price per unit in dollars (local price level, corruption overrun).
static func unit_price(c: CountryState, id: String) -> float:
	var level := clampf(pow(c.gdp_per_capita() / 60000.0, 0.5), 0.25, 1.25)
	return float(spec(id).usd) * level * (1.0 + Projects.overrun(c))


static func months(c: CountryState, id: String) -> int:
	return int(ceil(float(spec(id).months) / Projects.speed(c)))


## Most units you could start now: limited by twice the need (no endless spam).
static func max_more(c: CountryState, id: String) -> int:
	var cap := need(c, id) * 2.5
	# Power plants: a bigger economy uses more electricity, so it can use more of them.
	if str(spec(id).group) == "Energy" and c.idx == Game.player and Game.has_game() and Game.dip.has("energy"):
		cap = maxf(cap, need_at_start(c, id) * 2.5 * Energy.demand())
	return maxi(0, int(ceil(cap)) - count(c, id) - building(c, id))


## Most construction work the builders can take on, % of GDP a year.
static func capacity_pct(c: CountryState) -> float:
	return E.BUILD_CAPACITY_PCT * Projects.speed(c)


## Work under way (builds and national projects) as a share of capacity (1 = full).
static func work_load(c: CountryState) -> float:
	if c.builds.is_empty():
		return 0.0
	return (building_pct(c) + Projects.building_pct(c)) / maxf(capacity_pct(c), 0.1)


## Pace multiplier: overloaded builders spread themselves thin.
static func pace(c: CountryState) -> float:
	return 1.0 / maxf(work_load(c), 1.0)


## Extra inflation from an overheated construction sector (points).
static func overheat(c: CountryState) -> float:
	return clampf((work_load(c) - 1.0) * E.BUILD_OVERHEAT_INFL, 0.0, E.BUILD_OVERHEAT_MAX)


## Condition of the nation's buildings (player only): 1 = as maintained when you took office.
static func condition() -> float:
	return float(Game.dip.get("build_cond", 1.0)) if Game.has_game() else 1.0


static func condition_target(c: CountryState) -> float:
	return clampf(1.0 + c.share_delta("infrastructure") / E.BUILD_COND_PER_POINT, E.BUILD_COND_MIN, E.BUILD_COND_MAX)


## Cost to rush batch k (pay again a share of what is left to build).
static func rush_cost(c: CountryState, id: String, k: int) -> float:
	var b: Array = _st(c, id).batches
	if k < 0 or k >= b.size() or bool(b[k].get("rush", false)):
		return 0.0
	var bd: Dictionary = b[k]
	return float(bd.price) * int(bd.n) * clampf(float(bd.left) / float(spec(id).months), 0.0, 1.0) * E.BUILD_RUSH_PREMIUM


static func rush(c: CountryState, id: String, k: int) -> bool:
	var cost := rush_cost(c, id, k)
	if cost <= 0.0:
		return false
	c.treasury -= cost
	_st(c, id).batches[k]["rush"] = true
	c.builds_ver += 1
	return true


## Months left for a batch at today's pace.
static func batch_months(c: CountryState, bd: Dictionary) -> int:
	var sp := Projects.speed(c) * pace(c) * (E.BUILD_RUSH_SPEED if bool(bd.get("rush", false)) else 1.0)
	return int(ceil(float(bd.left) / maxf(sp, 0.05)))


## Every batch under construction: [{id, k, n, left, frac, rush}], soonest first.
static func queue(c: CountryState) -> Array:
	var out: Array = []
	for id in c.builds:
		var sp: Dictionary = spec(id)
		if sp.is_empty():
			continue
		var bt: Array = c.builds[id].batches
		for k in bt.size():
			var bd: Dictionary = bt[k]
			out.append({"id": id, "k": k, "n": int(bd.n), "months": batch_months(c, bd),
				"frac": clampf(1.0 - float(bd.left) / float(sp.months), 0.0, 1.0), "rush": bool(bd.get("rush", false))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.months) < int(b.months))
	return out


## Value of building a tenth of the need now: target points gained per % of GDP.
static func value_of(c: CountryState, id: String) -> float:
	var s := spec(id)
	var q := maxi(1, mini(int(ceil(need(c, id) * 0.1)), max_more(c, id)))
	var have := float(count(c, id) + building(c, id))
	var d := coverage_of(c, id, have + q) - coverage_of(c, id, have)
	var pts := 0.0
	# During blackouts a power plant is worth the blackout it ends.
	if str(s.group) == "Energy" and c.idx == Game.player and Game.has_game() and Game.dip.has("energy"):
		var sh := Energy.shortage()
		if sh > 0.0:
			var add := q * Energy.unit_supply(id)
			# Credit for the share of the gap it closes (the blackout's full cost is growth and happiness).
			pts += (E.EN_BLACKOUT_GROWTH * 1.5 + 0.5 * E.EN_BLACKOUT_HAPPY) * minf(add / sh, 1.0) * 3.0
	for k in s.fx:
		if not Laws.FX_GOOD_UP.has(k):
			continue
		var v := float(s.fx[k]) * d * E.BUILD_FX_SCALE
		var w := 1.0 if k in ["growth", "unemployment", "inflation"] else 0.5
		pts += w * (v if bool(Laws.FX_GOOD_UP[k]) else -v)
	var cost := unit_price(c, id) * q / maxf(c.gdp, 1.0) * 100.0 * (1.0 + float(s.upkeep) * 10.0)
	return pts / maxf(cost, 0.0001)


## The k best-value civilian builds right now (ids).
static func best_value(c: CountryState, k: int = 3) -> Array:
	var cands: Array = []
	for id in ALL:
		if str(ALL[id].group) == "Defence" or available(c, id) != "" or max_more(c, id) <= 0:
			continue
		var v := value_of(c, str(id))
		if v > 0.0:
			cands.append([v, id])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array = []
	for x in cands.slice(0, k):
		out.append(x[1])
	return out


## Average coverage of a group (0..1), for the dashboard.
static func group_coverage(c: CountryState, group: String) -> float:
	var s := 0.0
	var n := 0
	for id in ids_in(group):
		if available(c, id) != "":
			continue
		s += coverage_of(c, id, float(count(c, id)))
		n += 1
	return s / float(maxi(n, 1))


static func group_building(c: CountryState, group: String) -> int:
	var q := 0
	for id in ids_in(group):
		q += building(c, id)
	return q


static func order(c: CountryState, id: String, n: int) -> bool:
	if n <= 0 or available(c, id) != "" or n > max_more(c, id):
		return false
	(_st(c, id).batches as Array).append({"n": n, "left": float(spec(id).months), "price": unit_price(c, id)})
	c.builds_ver += 1
	return true


## Demolish finished units (saves upkeep; their effect goes too).
static func demolish(c: CountryState, id: String, n: int) -> void:
	var st := _st(c, id)
	st.n = maxi(0, int(st.n) - n)
	c.builds_ver += 1


## Stop a batch under construction (money already spent is lost).
static func cancel(c: CountryState, id: String, k: int) -> void:
	var b: Array = _st(c, id).batches
	if k >= 0 and k < b.size():
		b.remove_at(k)
		c.builds_ver += 1


## Advances construction; returns [[id, n], …] finished this month.
static func monthly(c: CountryState) -> Array:
	var done: Array = []
	var sp := Projects.speed(c) * pace(c)
	if c.idx == Game.player and Game.has_game():
		var cond := condition()
		Game.dip["build_cond"] = cond + (condition_target(c) - cond) * E.BUILD_COND_ADJUST
	for id in c.builds:
		var st: Dictionary = c.builds[id]
		var keep: Array = []
		for b in st.batches:
			b.left = float(b.left) - sp * (E.BUILD_RUSH_SPEED if bool(b.get("rush", false)) else 1.0)
			if float(b.left) <= 0.0:
				st.n = int(st.n) + int(b.n)
				done.append([id, int(b.n)])
			else:
				keep.append(b)
		st.batches = keep
	if not done.is_empty():
		c.builds_ver += 1
	return done


## Yearly spending, % of GDP: construction (spread over build time) + upkeep of added units.
static func spending_pct(c: CountryState) -> float:
	var s := 0.0
	for id in c.builds:
		var st: Dictionary = c.builds[id]
		var sp: Dictionary = spec(id)
		if sp.is_empty():
			continue
		for b in st.batches:
			s += float(b.price) * int(b.n) / float(sp.months) * 12.0 / maxf(c.gdp, 1.0) * 100.0
		var extra := maxi(int(st.n) - int(st.n0), 0)
		s += extra * unit_price(c, id) * float(sp.upkeep) / maxf(c.gdp, 1.0) * 100.0
	return s


## Construction underway, % of GDP a year (for the "construction work" stimulus).
static func building_pct(c: CountryState) -> float:
	var s := 0.0
	for id in c.builds:
		var sp: Dictionary = spec(id)
		for b in c.builds[id].batches:
			s += float(b.price) * int(b.n) / float(sp.months) * 12.0 / maxf(c.gdp, 1.0) * 100.0
	return s


## Coverage gained since the start (can be negative after demolitions).
static func gain(c: CountryState, id: String) -> float:
	var st := _st(c, id)
	var cond := condition() if c.idx == Game.player else 1.0
	return coverage_of(c, id, float(st.n) * cond) - coverage_of(c, id, float(st.n0))


## Target offsets from all builds (cached per builds_ver and month).
static func modifiers(c: CountryState) -> Dictionary:
	var key := Vector2i(c.builds_ver, Game.months_played if Game.has_game() else 0)
	if c.has_meta(&"bx_key") and c.get_meta(&"bx_key") == key:
		return c.get_meta(&"bx")
	var out := {}
	for id in c.builds:
		var g := gain(c, id)
		if absf(g) < 0.0005:
			continue
		var sp: Dictionary = spec(id)
		for k in sp.fx:
			if k == "relations_soft":
				continue
			out[k] = float(out.get(k, 0.0)) + float(sp.fx[k]) * g * E.BUILD_FX_SCALE
		for k in ["life", "lit", "gini"]:
			if sp.has(k):
				out[k] = float(out.get(k, 0.0)) + float(sp[k]) * g * E.BUILD_FX_SCALE
		for k in ["mil", "co2", "disaster"]:
			if sp.has(k):
				out[k] = float(out.get(k, 0.0)) + float(sp[k]) * g
	var b := building_pct(c)
	if b > 0.0:
		out["build_growth"] = b * Projects.BUILD_GROWTH
		out["build_jobs"] = -b * Projects.BUILD_JOBS
	var oh := overheat(c)
	if oh > 0.0:
		out["boom"] = oh
	for k in E.BUILD_FX_CAPS:
		if out.has(k):
			var cap := float(E.BUILD_FX_CAPS[k])
			out[k] = cap * tanh(float(out[k]) / cap)
	c.set_meta(&"bx_key", key)
	c.set_meta(&"bx", out)
	return out


static func total_units(c: CountryState, group: String) -> int:
	var n := 0
	for id in ids_in(group):
		n += count(c, id)
	return n
