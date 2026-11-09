class_name Air
extends RefCounted
## Air quality: fine dust (PM2.5) in the air people breathe, in µg/m³ a year
## (WHO guideline: 5). Starts from real measurements; follows your fossil-fuel
## emissions (power plants, traffic, industry) and the clean-air policies you
## choose. Dirty air shortens lives and sours the national mood.
## Effects count only the change since you took office.
## State: Game.dip.air {pm0, pm, pol: {id: month}}. Constants in sim/economy.gd (AIR_*).

const E = preload("res://sim/economy.gd")

## Annual mean PM2.5, µg/m³ (WHO / IQAir world air quality reports, recent years, rounded).
const PM := {"BGD": 80, "PAK": 73, "IND": 54, "TJK": 49, "BFA": 46, "IRQ": 43, "ARE": 43, "NPL": 42, "EGY": 42,
	"SAU": 41, "KWT": 40, "QAT": 38, "IDN": 37, "BHR": 37, "NGA": 33, "CHN": 30, "VNM": 30, "IRN": 30, "MNG": 30,
	"LAO": 28, "UZB": 28, "MMR": 27, "ZAF": 25, "THA": 23, "KHM": 22, "PER": 22, "TUR": 20, "MEX": 19, "KOR": 19,
	"KAZ": 18, "PHL": 17, "CHL": 18, "POL": 16, "ITA": 15, "COL": 14, "MYS": 15, "GRC": 14, "UKR": 13, "BRA": 12,
	"ISR": 18, "ARG": 13, "RUS": 10, "DEU": 9, "FRA": 9, "ESP": 9, "USA": 9, "JPN": 9, "GBR": 8, "NLD": 9, "BEL": 10,
	"CAN": 7, "SWE": 5, "NOR": 5, "FIN": 4, "AUS": 5, "NZL": 5, "ISL": 4, "IRL": 6, "PRT": 8, "CHE": 8, "SGP": 13}

## id -> {title, desc, cut (share of PM removed), cost (% GDP a year), approval (once), needs}
const POLICIES := {
	"vehicles": {"title": "Clean vehicle standards", "desc": "Strict exhaust limits and cleaner fuel.", "icon": "car", "cut": 0.1, "cost": 0.03, "approval": -0.5},
	"industry": {"title": "Filters on factories and plants", "desc": "Scrubbers and filters on chimneys. Business grumbles.", "icon": "factory", "cut": 0.12, "cost": 0.04, "approval": 0.0},
	"stoves": {"title": "Clean cooking for every home", "desc": "Gas and electric stoves instead of wood and coal fires.", "icon": "flame", "cut": 0.12, "cost": 0.05, "approval": 1.0, "needs": "developing"},
	"burning": {"title": "Stop crop burning", "desc": "Pay farmers to clear fields without fire.", "icon": "wheat", "cut": 0.08, "cost": 0.02, "approval": -0.5, "needs": "farming"},
}


static func st() -> Dictionary:
	if not Game.dip.has("air"):
		var iso := World.iso(Game.player)
		var c := Game.me()
		var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
		var pm := float(PM.get(iso, clampf(8.0 + 32.0 * (1.0 - lvl) + (12.0 if World.map.subregions[Game.player] in ["Southern Asia", "Western Asia", "Northern Africa"] else 0.0), 4.0, 90.0)))
		Game.dip["air"] = {"pm0": pm, "pm": pm, "pol": {}}
	return Game.dip.air


## PM2.5 of any country (yours live).
static func pm_of(i: int) -> float:
	if i == Game.player and Game.has_game() and Game.dip.has("air"):
		return pm()
	var iso := World.iso(i)
	if PM.has(iso):
		return float(PM[iso])
	var c: CountryState = Game.state(i)
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	return clampf(8.0 + 32.0 * (1.0 - lvl) + (12.0 if World.map.subregions[i] in ["Southern Asia", "Western Asia", "Northern Africa"] else 0.0), 4.0, 90.0)


static func pm() -> float:
	return float(st().pm)


static func label(v: float) -> String:
	if v <= 5.0:
		return "Clean (WHO guideline)"
	if v <= 15.0:
		return "Moderate"
	if v <= 35.0:
		return "Unhealthy for some"
	if v <= 55.0:
		return "Unhealthy"
	return "Hazardous"


static func color(v: float) -> Color:
	return DS.GREEN if v <= 10.0 else (DS.GOLD if v <= 25.0 else (DS.ORANGE if v <= 50.0 else DS.RED))


static func available(id: String) -> bool:
	var n := str(POLICIES[id].get("needs", ""))
	if n == "developing":
		return Economy.income_level(Game.me().gdp_per_capita()) < 0.55
	if n == "farming":
		return World.stat(Game.player, "agriculture_pct", 5.0) >= 5.0
	return true


static func has(id: String) -> bool:
	return (st().pol as Dictionary).has(id)


static func toggle(id: String) -> void:
	var pol: Dictionary = st().pol
	if pol.has(id):
		pol.erase(id)
	else:
		pol[id] = Game.months_played
		var given: Dictionary = st().get("given", {})
		if not given.has(id):
			given[id] = true
			st()["given"] = given
			var c := Game.me()
			c.shocks.approval = float(c.shocks.approval) + float(POLICIES[id].approval)
		Game.add_feed("Clean air: %s" % str(POLICIES[id].title).to_lower(), str(POLICIES[id].icon), "accent")


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("air"):
		return 0.0
	var p := 0.0
	for id in st().pol:
		p += float(POLICIES[id].cost)
	return p


static func target() -> float:
	var s := st()
	var t := float(s.pm0) * pow(maxf(1.0 + Climate.change(Game.me()), 0.2), E.AIR_EMISSION_LINK)
	for id in s.pol:
		t *= 1.0 - float(POLICIES[id].cut)
	return clampf(t, 2.0, 150.0)


static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	s.pm = float(s.pm) + (target() - float(s.pm)) * 0.05
	if pm() <= float(s.pm0) * 0.6 and float(s.pm0) >= 15.0:
		Achievements.unlock("blue_skies")


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("air"):
		return {}
	var d := pm() - float(st().pm0)
	return {"life": clampf(-d * E.AIR_LIFE, -3.0, 3.0), "happiness": clampf(-d * E.AIR_HAPPY, -2.0, 1.5),
		"growth": -0.03 if has("industry") else 0.0}
