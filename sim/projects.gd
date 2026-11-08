class_name Projects
extends RefCounted
## Construction projects: roads, railways, ports, power, hospitals, schools …
##
## A project costs `cost` % of GDP in total, paid month by month while it's built
## (it shows up in your budget as spending), employs people while building
## ("build" effects), and once finished permanently shifts targets like a law
## ("fx", per year) and costs `upkeep` % of GDP per year to run.
##
## Building speed follows your Infrastructure budget (more money, faster crews),
## and corruption makes projects run over budget (the anti-corruption law helps).
## What a country can build depends on it: no ports for landlocked countries,
## power grids where people still lack electricity, metros only for big cities…

const E = preload("res://sim/economy.gd")
const GROUPS := ["Transport", "Energy", "People", "Economy", "Culture", "Nature"]

const ALL := [
	{"id": "highways", "group": "Transport", "icon": "route", "title": "Highway network",
		"desc": "Fast roads linking your biggest cities.", "cost": 1.2, "months": 24, "upkeep": 0.05,
		"fx": {"growth": 0.25, "unemployment": -0.1, "happiness": 0.5}},
	{"id": "rural_roads", "group": "Transport", "icon": "tractor", "title": "Rural roads",
		"desc": "All-weather roads so farms and villages reach markets.", "cost": 0.5, "months": 12, "upkeep": 0.03,
		"needs": "developing", "fx": {"growth": 0.2, "happiness": 1.2, "stability": 0.8}},
	{"id": "rail", "group": "Transport", "icon": "train-front", "title": "High-speed rail",
		"desc": "Trains at 300 km/h between major cities.", "cost": 2.0, "months": 48, "upkeep": 0.08,
		"needs": "big_middle", "fx": {"growth": 0.3, "happiness": 1.2}},
	{"id": "metro", "group": "Transport", "icon": "tram-front", "title": "City metro",
		"desc": "An underground railway for your largest city.", "cost": 0.6, "months": 30, "upkeep": 0.05,
		"needs": "big_city", "fx": {"happiness": 1.5, "growth": 0.1, "approval": 0.5}},
	{"id": "port", "group": "Transport", "icon": "anchor", "title": "Deep-water port",
		"desc": "A container port for the biggest ships.", "cost": 0.8, "months": 30, "upkeep": 0.04,
		"needs": "coast", "fx": {"growth": 0.25, "unemployment": -0.1}},
	{"id": "airport", "group": "Transport", "icon": "plane", "title": "International airport",
		"desc": "A modern hub for travellers and air cargo.", "cost": 0.5, "months": 24, "upkeep": 0.04,
		"fx": {"growth": 0.15, "happiness": 0.5}},
	{"id": "power_grid", "group": "Energy", "icon": "plug-zap", "title": "National power grid",
		"desc": "Bring reliable electricity to every home.", "cost": 0.8, "months": 24, "upkeep": 0.05,
		"needs": "no_power", "fx": {"growth": 0.35, "happiness": 2.0, "stability": 1.0}},
	{"id": "solar", "group": "Energy", "icon": "sun", "title": "Solar parks",
		"desc": "Fields of panels for cheap, clean power.", "cost": 0.4, "months": 12, "upkeep": 0.02,
		"fx": {"growth": 0.05, "inflation": -0.1, "happiness": 0.4}},
	{"id": "wind", "group": "Energy", "icon": "wind", "title": "Wind farms",
		"desc": "Turbines on hills and offshore.", "cost": 0.5, "months": 18, "upkeep": 0.02,
		"fx": {"growth": 0.05, "inflation": -0.1, "happiness": 0.4}},
	{"id": "nuclear", "group": "Energy", "icon": "atom", "title": "Nuclear power plant",
		"desc": "Huge, steady clean power. Slow and costly to build.", "cost": 1.6, "months": 72, "upkeep": 0.06,
		"needs": "nuclear", "politics": -1.5, "fx": {"growth": 0.15, "inflation": -0.25}},
	{"id": "hydro", "group": "Energy", "icon": "droplets", "title": "Hydroelectric dam",
		"desc": "A river dam for power and water storage. Some towns must move.", "cost": 1.0, "months": 48,
		"upkeep": 0.03, "politics": -1.0, "fx": {"growth": 0.15, "inflation": -0.1, "happiness": -0.3}},
	{"id": "hospitals", "group": "People", "icon": "hospital", "title": "Hospital network",
		"desc": "New hospitals so everyone is near good care.", "cost": 0.6, "months": 24, "upkeep": 0.12,
		"fx": {"happiness": 2.5, "stability": 0.5, "approval": 0.8}},
	{"id": "schools", "group": "People", "icon": "school", "title": "New schools",
		"desc": "Thousands of new classrooms and teachers.", "cost": 0.5, "months": 18, "upkeep": 0.1,
		"fx": {"unemployment": -0.25, "growth": 0.1, "happiness": 1.0}},
	{"id": "universities", "group": "People", "icon": "graduation-cap", "title": "Research universities",
		"desc": "World-class campuses for science and engineering.", "cost": 0.6, "months": 36, "upkeep": 0.08,
		"needs": "middle", "fx": {"growth": 0.2, "unemployment": -0.1}},
	{"id": "housing", "group": "People", "icon": "house", "title": "Affordable housing",
		"desc": "Hundreds of thousands of homes people can afford.", "cost": 0.8, "months": 24, "upkeep": 0.02,
		"fx": {"happiness": 2.0, "approval": 1.5, "inflation": -0.1}},
	{"id": "water", "group": "People", "icon": "glass-water", "title": "Clean water for all",
		"desc": "Safe drinking water and sanitation in every town.", "cost": 0.4, "months": 18, "upkeep": 0.03,
		"needs": "developing", "fx": {"happiness": 2.5, "stability": 1.0, "growth": 0.1}},
	{"id": "broadband", "group": "Economy", "icon": "wifi", "title": "Broadband for all",
		"desc": "Fast internet in every home and business.", "cost": 0.4, "months": 18, "upkeep": 0.02,
		"needs": "offline", "fx": {"growth": 0.15, "happiness": 0.8}},
	{"id": "tech_park", "group": "Economy", "icon": "cpu", "title": "Technology park",
		"desc": "Labs and offices to attract tech companies.", "cost": 0.4, "months": 24, "upkeep": 0.02,
		"fx": {"growth": 0.2, "unemployment": -0.1}},
	{"id": "industry", "group": "Economy", "icon": "factory", "title": "Industrial corridor",
		"desc": "Factories, power and roads along one fast corridor.", "cost": 0.8, "months": 30, "upkeep": 0.03,
		"fx": {"growth": 0.25, "unemployment": -0.35, "happiness": -0.3}},
	{"id": "tourism", "group": "Economy", "icon": "tree-palm", "title": "Tourism resorts",
		"desc": "Hotels, beaches and heritage trails for visitors.", "cost": 0.3, "months": 18, "upkeep": 0.01,
		"needs": "tourism", "fx": {"growth": 0.15, "unemployment": -0.15}},
	{"id": "space", "group": "Economy", "icon": "rocket", "title": "Space programme",
		"desc": "Rockets, satellites and national pride.", "cost": 0.8, "months": 60, "upkeep": 0.05,
		"needs": "space", "fx": {"approval": 2.0, "growth": 0.1, "happiness": 0.8}},
	{"id": "stadium", "group": "Culture", "icon": "trophy", "title": "National stadium",
		"desc": "A grand arena for finals, concerts and national pride.", "cost": 0.25, "months": 30, "upkeep": 0.01,
		"needs": "middle", "fx": {"happiness": 1.2, "approval": 0.6}},
	{"id": "museum", "group": "Culture", "icon": "landmark", "title": "Grand national museum",
		"desc": "Your history and art under one roof. Visitors love it.", "cost": 0.12, "months": 24, "upkeep": 0.01,
		"fx": {"happiness": 0.6, "growth": 0.03, "stability": 0.3}},
	{"id": "libraries", "group": "Culture", "icon": "book-open", "title": "Libraries and arts centres",
		"desc": "A library, theatre and studio in every town.", "cost": 0.15, "months": 18, "upkeep": 0.02,
		"fx": {"happiness": 0.9, "unemployment": -0.05}},
	{"id": "landmark", "group": "Culture", "icon": "building-2", "title": "Iconic landmark",
		"desc": "A daring tower or bridge that puts your capital on postcards.", "cost": 0.35, "months": 36,
		"upkeep": 0.01, "needs": "middle", "politics": -0.5, "fx": {"approval": 0.8, "growth": 0.04, "happiness": 0.4}},
	{"id": "flood_defences", "group": "Nature", "icon": "waves", "title": "Flood defences",
		"desc": "Sea walls and river barriers. Disasters hit softer.", "cost": 0.4, "months": 24, "upkeep": 0.02,
		"fx": {"stability": 0.8, "happiness": 0.5}},
	{"id": "forests", "group": "Nature", "icon": "trees", "title": "Plant a billion trees",
		"desc": "Restore forests for cleaner air and water.", "cost": 0.15, "months": 24, "upkeep": 0.01,
		"fx": {"happiness": 1.0, "stability": 0.3}},
]

## Construction work while building: per % of GDP spent per year.
const BUILD_GROWTH := 0.25        # growth points per 1 % of GDP/yr being built
const BUILD_JOBS := 0.35          # unemployment points removed per 1 % of GDP/yr
## Each finished project helps a little less than the one before (diminishing returns).
const DIMINISH := 0.1
## Cost overrun at the worst corruption (WGI −2.5): +60 %; none at +1.0 or better.
const OVERRUN_MAX := 0.6


static func by_id(id: String) -> Dictionary:
	for p in ALL:
		if p.id == id:
			return p
	return {}


## Why a country can't build something ("" = it can).
static func blocked_reason(c: CountryState, p: Dictionary) -> String:
	var i := c.idx
	var lvl := Economy.income_level(c.gdp_per_capita())
	match str(p.get("needs", "")):
		"coast":
			if World.landlocked(i):
				return "Your country has no coastline"
		"developing":
			if lvl > 0.55:
				return "Already done in a country this developed"
		"middle":
			if lvl < 0.25:
				return "Needs a stronger economy first"
		"big_middle":
			if c.population < 15e6 or lvl < 0.2:
				return "Needs a large, middle-income country"
		"big_city":
			if c.population * World.stat(i, "urban_pct", 50.0) / 100.0 < 2.5e6:
				return "Your cities are too small for a metro"
		"no_power":
			if World.stat(i, "electricity_pct", 100.0) >= 97.0:
				return "Almost every home already has power"
		"offline":
			if World.stat(i, "internet_pct", 80.0) >= 92.0:
				return "Almost everyone is already online"
		"nuclear":
			if c.population < 8e6 or lvl < 0.35:
				return "Needs a large, industrial economy"
		"tourism":
			if World.landlocked(i) and World.stat(i, "tourism_pct", 0.0) < 8.0:
				return "Few visitors come here yet"
		"space":
			if c.gdp < 4e11:
				return "Needs an economy above $400B"
	return ""


static func state(c: CountryState, id: String) -> Dictionary:
	return c.projects.get(id, {})


static func is_done(c: CountryState, id: String) -> bool:
	return str(state(c, id).get("state", "")) == "done"


static func is_building(c: CountryState, id: String) -> bool:
	return str(state(c, id).get("state", "")) == "building"


## Total price in dollars, including expected overrun from corruption.
static func price(c: CountryState, p: Dictionary) -> float:
	return c.gdp * float(p.cost) / 100.0 * (1.0 + overrun(c))


static func overrun(c: CountryState) -> float:
	# Clean-government score (0..100) back on the WGI scale (-2.5 .. 2.5).
	var cc := (Corruption.value(c) - 50.0) / 20.0
	return clampf((1.0 - cc) / 3.5, 0.0, 1.0) * OVERRUN_MAX


## Months to build at today's pace.
static func build_months(c: CountryState, p: Dictionary) -> int:
	return int(ceil(float(p.months) / speed(c)))


## Crews work faster with a bigger infrastructure budget.
static func speed(c: CountryState) -> float:
	return clampf((1.0 + c.share_delta("infrastructure") / 20.0) * Profiles.mult(c.idx, "project_speed")
		* (1.0 + (Cabinet.bonus("project_speed") if c.idx == Game.player else 0.0)), 0.5, 1.8)


static func start(c: CountryState, id: String) -> bool:
	var p := by_id(id)
	if p.is_empty() or c.projects.has(id) or blocked_reason(c, p) != "":
		return false
	c.projects[id] = {"state": "building", "progress": 0.0, "price": price(c, p)}
	if p.has("politics"):
		c.shocks.approval = float(c.shocks.approval) + float(p.politics)
	c.projects_ver += 1
	return true


## Cancel a project under construction (money already spent is lost).
static func cancel(c: CountryState, id: String) -> void:
	if is_building(c, id):
		c.projects.erase(id)
		c.projects_ver += 1


## Advances construction. Returns the ids finished this month.
static func monthly(c: CountryState) -> Array:
	var done: Array = []
	var sp := speed(c)
	for id in c.projects.keys():
		var st: Dictionary = c.projects[id]
		if str(st.state) != "building":
			continue
		var p := by_id(id)
		st.progress = float(st.progress) + sp
		if float(st.progress) >= float(p.months):
			c.projects[id] = {"state": "done", "year": Game.year if c.idx == Game.player else 0}
			done.append(id)
	if not done.is_empty():
		c.projects_ver += 1
	return done


## Fraction built (0..1).
static func progress(c: CountryState, id: String) -> float:
	var st := state(c, id)
	if str(st.get("state", "")) == "done":
		return 1.0
	var p := by_id(id)
	return clampf(float(st.get("progress", 0.0)) / maxf(float(p.get("months", 1)), 1.0), 0.0, 1.0)


## Spending on projects this year, % of GDP: construction (spread over the build
## time) plus upkeep of finished ones.
static func spending_pct(c: CountryState) -> float:
	var s := 0.0
	for id in c.projects:
		var st: Dictionary = c.projects[id]
		var p := by_id(id)
		if p.is_empty():
			continue
		if str(st.state) == "building":
			var total_pct := float(st.get("price", 0.0)) / maxf(c.gdp, 1.0) * 100.0
			s += total_pct / float(p.months) * 12.0 * speed(c)
		elif not bool(st.get("start", false)):
			s += float(p.upkeep)
	return s


## Target offsets from projects: finished ones (fx, with diminishing returns) and
## the construction work going on now. Cached per projects_ver.
static func modifiers(c: CountryState) -> Dictionary:
	var out := {}
	var n := 0
	for id in c.projects:
		var st0: Dictionary = c.projects[id]
		# Infrastructure a country had at the start is its baseline, not a bonus.
		if str(st0.state) != "done" or bool(st0.get("start", false)):
			continue
		var p := by_id(id)
		if p.is_empty():
			continue
		var f := 1.0 / (1.0 + DIMINISH * n)
		n += 1
		for k in p.fx:
			out[k] = float(out.get(k, 0.0)) + float(p.fx[k]) * f
	var building := 0.0
	for id in c.projects:
		var st: Dictionary = c.projects[id]
		if str(st.state) == "building":
			var p := by_id(id)
			building += float(st.get("price", 0.0)) / maxf(c.gdp, 1.0) * 100.0 / float(p.months) * 12.0
	if building > 0.0:
		out["build_growth"] = building * BUILD_GROWTH
		out["build_jobs"] = -building * BUILD_JOBS
	return out


static func count_done(c: CountryState) -> int:
	var n := 0
	for id in c.projects:
		if str(c.projects[id].state) == "done":
			n += 1
	return n


static func count_building(c: CountryState) -> int:
	return c.projects.size() - count_done(c)


## Projects a country already has at the start (its real infrastructure): rich
## countries start with highways, hospitals, schools …; that's the baseline, so
## building them again isn't offered.
static func starting_set(c: CountryState) -> Dictionary:
	var i := c.idx
	var lvl := Economy.income_level(c.gdp_per_capita())
	var out := {}
	var have := func(id: String) -> void: out[id] = {"state": "done", "year": 0, "start": true}
	if lvl > 0.45:
		have.call("highways")
		have.call("airport")
		have.call("hospitals")
		have.call("schools")
	if lvl > 0.5:
		have.call("museum")
		have.call("stadium")
	if lvl > 0.65:
		have.call("libraries")
	if lvl > 0.6:
		have.call("universities")
		if c.population > 15e6:
			have.call("metro")
	if World.stat(i, "electricity_pct", 100.0) >= 97.0:
		have.call("power_grid")
	if lvl > 0.55:
		have.call("water")
	if World.stat(i, "internet_pct", 80.0) >= 92.0:
		have.call("broadband")
	if World.iso(i) in ["USA", "CHN", "RUS", "IND", "JPN", "FRA", "DEU", "GBR", "ITA", "ISR", "KOR", "IRN", "BRA"]:
		have.call("space")
	if World.iso(i) in ["CHN", "JPN", "FRA", "DEU", "ESP", "ITA", "KOR", "TWN", "GBR", "TUR", "SAU", "MAR", "IDN", "UZB", "BEL", "NLD", "CHE", "AUT", "SWE", "RUS", "POL", "CZE", "PRT", "FIN", "NOR", "DNK"]:
		have.call("rail")
	if World.iso(i) in ["USA", "FRA", "CHN", "RUS", "JPN", "KOR", "IND", "CAN", "UKR", "GBR", "ESP", "SWE", "BEL", "CZE", "FIN", "CHE", "SVK", "HUN", "PAK", "ARG", "BRA", "ZAF", "MEX", "ROU", "BGR", "SVN", "ARM", "IRN", "ARE", "BLR", "NLD", "TWN"]:
		have.call("nuclear")
	return out
