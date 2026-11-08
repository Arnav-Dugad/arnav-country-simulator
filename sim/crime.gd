class_name Crime
extends RefCounted
## Crime & justice. A crime index (0 = very safe, 100 = lawless) that starts
## from your country's real profile (political stability, inequality, income)
## and moves toward a target set by:
##   jobs and fairness   unemployment and inequality above where you started
##   police and prisons  stations and prisons you build (Build tab)
##   policing            community / balanced / tough on crime
##   programmes          gang crackdowns (fast, risky), youth programmes (slow,
##                       lasting), drug treatment (moderate, popular with doctors)
##   unrest and war      instability breeds crime
## More crime than at the start costs happiness, approval, stability, investment
## and tourists; less crime pays the same back. Tough policing is popular with
## some voters but costs civil liberties, and fills prisons fast.
## State: Game.dip.crime {value, start, policing, programs: {id: month}, scandal}.
## Constants in sim/economy.gd (CRIME_*).

const E = preload("res://sim/economy.gd")

const POLICING := ["community", "balanced", "tough"]
const POLICING_INFO := {
	"community": {"title": "Community", "desc": "Officers on the beat who know the neighbourhood. Trusted, slower to bite."},
	"balanced": {"title": "Balanced", "desc": "Standard policing."},
	"tough": {"title": "Tough", "desc": "Long sentences and stop-and-search. Fast results, angry neighbourhoods, full prisons."},
}

## id -> {title, icon, desc, cost (% of GDP, once), capital, months, effect, fade (months it lasts)}
const PROGRAMS := {
	"crackdown": {"title": "Crack down on gangs", "icon": "siren", "cost": 0.05, "capital": 10.0, "months": 6, "effect": 10.0,
		"desc": "Raids and special units for six months. Fast, but abuses can turn into a scandal."},
	"youth": {"title": "Youth programmes", "icon": "graduation-cap", "cost": 0.15, "capital": 0.0, "months": 120, "effect": 5.0,
		"desc": "Mentors, sport and jobs for teenagers. Takes two years to work, lasts ten."},
	"treatment": {"title": "Drug treatment", "icon": "heart-pulse", "cost": 0.1, "capital": 5.0, "months": 96, "effect": 4.0,
		"desc": "Treat addiction as a health problem. Less street crime, a little more trust."},
}


static func start_value(i: int) -> float:
	var c: CountryState = Game.state(i)
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	return clampf(48.0 - 14.0 * World.stat(i, "stability_wgi", 0.0) + 0.7 * (Inequality.start(i) - 35.0) - 14.0 * lvl, 5.0, 85.0)


static func st() -> Dictionary:
	if not Game.dip.has("crime"):
		var v := start_value(Game.player)
		Game.dip["crime"] = {"value": v, "start": v, "policing": "balanced", "programs": {}, "last_wave": -99}
	return Game.dip.crime


static func value() -> float:
	return float(st().value)


static func change() -> float:
	return value() - float(st().start)


static func label(v: float) -> String:
	if v < 15.0:
		return "Very safe"
	if v < 30.0:
		return "Safe"
	if v < 45.0:
		return "Some crime"
	if v < 60.0:
		return "High crime"
	return "Lawless"


## How far along a programme is: 0 not running, ramps up to 1, then fades out.
static func program_power(id: String) -> float:
	var started := int((st().programs as Dictionary).get(id, -9999))
	var age := Game.months_played - started
	var p: Dictionary = PROGRAMS[id]
	if age < 0 or age >= int(p.months):
		return 0.0
	if id == "youth":
		return clampf(age / 24.0, 0.0, 1.0)            # takes two years to work
	if id == "treatment":
		return clampf(age / 12.0, 0.0, 1.0)
	return 1.0


## Why crime is where it's heading: [[label, points], …] (positive = more crime).
static func terms(c: CountryState) -> Array:
	var s := st()
	var t: Array = []
	t.append(["Joblessness", E.CRIME_UNEMP * (c.unemployment - float(c.base.get("unemployment", c.unemployment)))])
	t.append(["Inequality", E.CRIME_GINI * Inequality.change(c)])
	if not c.builds.is_empty():
		t.append(["Police stations", -E.CRIME_POLICE * Builds.gain(c, "police")])
		t.append(["Prisons", -E.CRIME_PRISON * Builds.gain(c, "prison")])
	t.append(["Policing", {"community": -E.CRIME_COMMUNITY, "tough": -E.CRIME_TOUGH}.get(str(s.policing), 0.0)])
	var prog := 0.0
	for id in PROGRAMS:
		prog -= float(PROGRAMS[id].effect) * program_power(str(id))
	t.append(["Programmes", prog])
	t.append(["Unrest", E.CRIME_STABILITY * (float(c.base.get("stability", c.stability)) - c.stability)])
	if Laws.is_active(c, "police_reform") and not c.laws_start.has("police_reform"):
		t.append(["Police reform", -2.0])
	if War.at_war():
		t.append(["War", 3.0])
	return t


static func target(c: CountryState) -> float:
	var v := float(st().start)
	for t in terms(c):
		v += float(t[1])
	return clampf(v, 2.0, 98.0)


static func set_policing(p: String) -> void:
	if POLICING.has(p):
		st().policing = p


static func can_start(id: String) -> String:
	if program_power(id) > 0.0 or (Game.months_played - int((st().programs as Dictionary).get(id, -9999))) < int(PROGRAMS[id].months):
		return "Already running"
	var cap := float(PROGRAMS[id].capital)
	if cap > 0.0 and not Capital.can(cap):
		return "Needs %d political capital" % int(cap)
	return ""


static func program_cost(id: String) -> float:
	return Game.me().gdp * float(PROGRAMS[id].cost) / 100.0


static func start_program(id: String) -> bool:
	if can_start(id) != "":
		return false
	var p: Dictionary = PROGRAMS[id]
	if float(p.capital) > 0.0:
		Capital.spend(float(p.capital))
	Game.me().treasury -= program_cost(id)
	(st().programs as Dictionary)[id] = Game.months_played
	Game.add_feed("Launched: %s" % str(p.title).to_lower(), str(p.icon), "accent")
	return true


## Monthly: crime drifts; crime waves, prison overcrowding and crackdown scandals.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var s := st()
	var c := Game.me()
	var before := float(s.value)
	s.value = before + (target(c) - before) * E.CRIME_ADJUST
	if change() > 6.0 and Game.months_played - int(s.last_wave) > 24:
		s.last_wave = Game.months_played
		out.append({"text": "Crime wave: robberies and gang violence are up in the big cities", "icon": "siren", "good": false})
	# A crackdown can go wrong.
	var cd := int((s.programs as Dictionary).get("crackdown", -9999))
	if Game.months_played - cd == 3 and Game.rng.randf() < E.CRIME_SCANDAL_CHANCE * (1.5 if str(s.policing) == "tough" else 1.0):
		c.shocks.approval = float(c.shocks.approval) - 3.0
		c.shocks.stability = float(c.shocks.stability) - 2.0
		Press.apply_cred(-4.0)
		out.append({"text": "Scandal: videos of police abuse during the gang crackdown spark protests", "icon": "megaphone", "good": false})
	# Tough policing without the prisons to match.
	if str(s.policing) == "tough" and not c.builds.is_empty() and Builds.gain(c, "prison") < 0.05 and Game.rng.randf() < 0.04:
		c.shocks.stability = float(c.shocks.stability) - 1.5
		out.append({"text": "Prisons overcrowded: riots in two jails. Build more prisons or ease off", "icon": "lock", "good": false})
	return out


## Target offsets from crime (relative to the start) and your policing style.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("crime"):
		return {}
	var d := change()
	var out := {
		"happiness": -E.CRIME_HAPPY * d,
		"approval": -E.CRIME_APPROVAL * d,
		"stability": -E.CRIME_STAB * d,
		"growth": -E.CRIME_GROWTH * d,
	}
	match str(st().policing):
		"tough":
			out.happiness -= 1.5
			out.approval += 1.0
			out["cost"] = 0.2
		"community":
			out.happiness += 0.5
			out["cost"] = 0.1
	return out
