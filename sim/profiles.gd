class_name Profiles
extends RefCounted
## Researched country profiles (data/country_profiles.json; see data/SOURCES.md):
## tagline, main exports, trading partners, friends and rivals, natural risks,
## strengths and challenges, food-import dependence and one fact.
## Countries not covered fall back to what the statistics say.
##
## Gameplay hooks:
##   strengths/challenges  small permanent target offsets (STRENGTH_FX / CHALLENGE_FX)
##                         and event weights (Events: cond, Profiles.event_weight)
##   partners/friends      warmer starting relations; partners pass on booms and busts
##   rivals                cooler starting relations
##   risks                 which disasters can strike (with the region lists in events)
##   food_importer         exposure to world food prices (WorldMarkets)

const PATH := "res://data/country_profiles.json"

const STRENGTH_LABELS := {"tech": "Tech hub", "manufacturing": "Manufacturing power", "oil_gas": "Oil & gas",
	"mining": "Mining", "agriculture": "Farming", "tourism": "Tourism", "finance": "Finance centre",
	"shipping": "Trade & shipping", "young_workforce": "Young workforce", "education": "Well educated",
	"stable_institutions": "Stable institutions", "renewables": "Clean energy", "remittances": "Remittances",
	"services": "Services"}
const CHALLENGE_LABELS := {"corruption": "Corruption", "inequality": "Inequality", "ageing": "Ageing",
	"unemployment": "Unemployment", "inflation": "Inflation", "debt": "Debt", "energy_imports": "Imports energy",
	"food_imports": "Imports food", "conflict_nearby": "Conflict nearby", "climate_risk": "Climate risk",
	"brain_drain": "Brain drain", "bureaucracy": "Red tape", "informal_economy": "Informal economy",
	"water_scarcity": "Water scarcity", "sanctions": "Under sanctions"}

## Strengths and challenges change how strongly things work here (multipliers),
## never the real starting numbers. key -> [[trait, factor], …]
const MULT := {
	"research_growth": [["tech", 1.5], ["education", 1.2]],
	"education_growth": [["young_workforce", 1.3], ["education", 1.15]],
	"trade_growth": [["manufacturing", 1.3], ["shipping", 1.3]],
	"deal_growth": [["shipping", 1.5], ["manufacturing", 1.2]],
	"instability_drag": [["stable_institutions", 0.7], ["conflict_nearby", 1.2]],
	"core_inflation_decay": [["inflation", 0.85]],
	"risk_premium": [["debt", 1.3], ["finance", 0.8]],
	"oil_import_exposure": [["renewables", 0.6]],
	"food_exposure": [["agriculture", 0.6]],
	"law_months": [["bureaucracy", 1.25]],
	"project_speed": [["bureaucracy", 0.85], ["corruption", 0.9]],
	"event_severity": [["stable_institutions", 0.9]],
}
## Events that happen more (or less) often here.
const EVENT_WEIGHT := {
	"tourism": [["tourism", 2.0]], "pandemic": [["tourism", 1.3]], "refugees": [["conflict_nearby", 2.0]],
	"brain_drain": [["brain_drain", 2.2]], "drought": [["water_scarcity", 2.0], ["agriculture", 1.3]],
	"heatwave": [["climate_risk", 1.5]], "floods": [["climate_risk", 1.5]], "hurricane": [["climate_risk", 1.3]],
	"scandal": [["corruption", 1.6]], "strike": [["unemployment", 1.4]], "tech_boom": [["tech", 2.0]],
	"investment": [["manufacturing", 1.4], ["finance", 1.3]], "automation": [["manufacturing", 1.5]],
	"housing": [["finance", 1.3]], "youth_jobs": [["young_workforce", 1.5], ["unemployment", 1.3]],
	"pensions": [["ageing", 1.6]], "resources": [["mining", 2.0]], "oil_windfall": [["oil_gas", 1.5]],
	"oil_crash": [["oil_gas", 1.5]], "blackout": [["energy_imports", 1.3]], "sanction_threat": [["sanctions", 2.0]],
}


static var _traits := {}


static func traits(i: int) -> Array:
	if not _traits.has(i):
		_traits[i] = strengths(i) + challenges(i)
	return _traits[i]


static func mult(i: int, key: String) -> float:
	var m := 1.0
	if i < 0:
		return m
	var traits := traits(i)
	for pair in MULT.get(key, []):
		if pair[0] in traits:
			m *= float(pair[1])
	return m


static func event_weight(i: int, event_id: String) -> float:
	var m := 1.0
	var traits := traits(i)
	for pair in EVENT_WEIGHT.get(event_id, []):
		if pair[0] in traits:
			m *= float(pair[1])
	return m


static var _data: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if FileAccess.file_exists(PATH):
		var v: Variant = JsonUtil.parse(FileAccess.get_file_as_string(PATH), "country_profiles.json")
		if v is Dictionary:
			_data = v


static func get_profile(i: int) -> Dictionary:
	_ensure()
	return _data.get(World.iso(i), {})


static func has(i: int) -> bool:
	return not get_profile(i).is_empty()


static func tagline(i: int) -> String:
	return str(get_profile(i).get("tagline", ""))


static func fact(i: int) -> String:
	return str(get_profile(i).get("fact", ""))


static func exports(i: int) -> Array:
	return get_profile(i).get("exports", [])


static func partners(i: int) -> Array:
	return get_profile(i).get("partners", [])


static func friends(i: int) -> Array:
	return get_profile(i).get("friends", [])


static func rivals(i: int) -> Array:
	return get_profile(i).get("rivals", [])


static func risks(i: int) -> Array:
	return get_profile(i).get("risks", [])


static func strengths(i: int) -> Array:
	var p := get_profile(i)
	if p.has("strengths"):
		return p.strengths
	var out: Array = []
	if World.stat(i, "fuel_exports_pct") >= 30.0:
		out.append("oil_gas")
	if World.stat(i, "tourism_pct") >= 15.0:
		out.append("tourism")
	if World.stat(i, "manufacturing_pct") >= 20.0:
		out.append("manufacturing")
	return out


static func challenges(i: int) -> Array:
	var p := get_profile(i)
	if p.has("challenges"):
		return p.challenges
	var out: Array = []
	if World.stat(i, "corruption_wgi") < -0.8:
		out.append("corruption")
	if World.stat(i, "gini") >= 45.0:
		out.append("inequality")
	if World.stat(i, "age65_pct") >= 18.0:
		out.append("ageing")
	return out


static func has_strength(i: int, k: String) -> bool:
	return k in strengths(i)


static func has_challenge(i: int, k: String) -> bool:
	return k in challenges(i)


static func food_importer(i: int) -> bool:
	var p := get_profile(i)
	if p.has("food_importer"):
		return bool(p.food_importer)
	return World.stat(i, "agriculture_pct", 10.0) < 6.0 or World.landlocked(i) == false and World.island(i)


## Does this natural risk apply here? (profile list, or [] = use the event's regions)
static func at_risk(i: int, risk: String) -> int:
	var r := risks(i)
	if r.is_empty():
		return -1          # unknown: let the event's region list decide
	return 1 if risk in r else 0


## Short labels for the UI: [[text, good], …]
static func trait_chips(i: int) -> Array:
	var out: Array = []
	for s in strengths(i):
		out.append([str(STRENGTH_LABELS.get(s, s)), true])
	for s in challenges(i):
		out.append([str(CHALLENGE_LABELS.get(s, s)), false])
	return out
