class_name Intel
extends RefCounted
## Spies & intelligence. Your agency's budget (four levels, paid every year) sets
## its strength, along with the size of your economy and your technology.
## Covert operations target one country and take a few months:
##   gather    learn their plans: an edge in any war with them for two years
##   tech      steal research (points toward your current technology)
##   sabotage  hit their economy and armed forces
##   meddle    tilt their politics toward you (relations up when it works)
##   rebels    arm their rebels: their stability falls
## Each has a success chance (your strength against their counter-intelligence)
## and a separate risk of exposure: relations collapse, their friends cool on
## you, and the press at home has a field day. Hostile countries spy on you too;
## a stronger agency catches more of them.
## State: Game.dip.intel {level, ops: [{op, target, start, months}], edge: {i: until},
## caught, lost, log: [{text, good, m}]}. Constants in sim/economy.gd (INTEL_*).

const E = preload("res://sim/economy.gd")

const LEVELS := ["Small", "Standard", "Large", "Massive"]

## op -> {title, icon, desc, months, diff (how hard to succeed), risk (base exposure), hostile_only}
const OPS := {
	"gather": {"title": "Gather intelligence", "icon": "eye", "months": 3, "diff": 0.6, "risk": 0.08,
		"desc": "Agents map their forces and plans. You fight better against them for two years."},
	"tech": {"title": "Steal technology", "icon": "cpu", "months": 4, "diff": 1.0, "risk": 0.18,
		"desc": "Hackers and insiders lift research from their labs."},
	"sabotage": {"title": "Sabotage", "icon": "bomb", "months": 4, "diff": 1.3, "risk": 0.3,
		"desc": "Disrupt power grids, ports and arms factories."},
	"meddle": {"title": "Meddle in their politics", "icon": "vote", "months": 6, "diff": 1.5, "risk": 0.35,
		"desc": "Fund friendly politicians and flood their media. Relations warm if it works."},
	"rebels": {"title": "Arm their rebels", "icon": "swords", "months": 5, "diff": 1.4, "risk": 0.4, "hostile_only": true,
		"desc": "Weapons and money for armed opposition groups. Their stability falls."},
}


static func st() -> Dictionary:
	if not Game.dip.has("intel"):
		Game.dip["intel"] = {"level": 1, "ops": [], "edge": {}, "caught": 0, "lost": 0, "log": []}
	return Game.dip.intel


static func level() -> int:
	return int(st().level)


## Yearly agency cost, % of GDP (Standard is what a country spends anyway: baseline).
static func spending_pct() -> float:
	return float(E.INTEL_COST[level()]) - float(E.INTEL_COST[1])


## Agency strength of any country (0..~100): budget, economic weight, technology.
static func strength(i: int) -> float:
	var c: CountryState = Game.state(i)
	if c == null:
		return 10.0
	var lvl := float(E.INTEL_LEVEL_MULT[level()]) if i == Game.player else 1.0
	var size := clampf(log(maxf(c.gdp, 1e9) / 1e9) / log(10.0) / 4.0, 0.0, 1.0)     # $1B .. $10T
	var tech := 1.0
	if i == Game.player:
		for t in ["ai", "cyberdef", "quantum"]:
			if Tech.ALL.has(t) and Tech.has(t):
				tech += 0.12
	var clean := Corruption.value(c) / 100.0
	return clampf((25.0 + 55.0 * size + 10.0 * clean) * lvl * tech, 5.0, 150.0)


## Chance an operation succeeds against country i.
static func success_chance(op: String, i: int) -> float:
	var mine := strength(Game.player)
	var theirs := strength(i) * float(OPS[op].diff)
	return clampf(mine / (mine + theirs), 0.08, 0.92)


## Chance it is exposed (whether or not it works).
static func exposure_chance(op: String, i: int) -> float:
	var ratio := strength(i) / maxf(strength(Game.player), 1.0)
	return clampf(float(OPS[op].risk) * sqrt(ratio), 0.03, 0.8)


static func running_against(i: int) -> Dictionary:
	for o in st().ops:
		if int(o.target) == i:
			return o
	return {}


## "" if you can launch this op on country i, else why not.
static func can_launch(op: String, i: int) -> String:
	if i == Game.player or not World.is_playable(i):
		return "Not possible"
	if not running_against(i).is_empty():
		return "An operation is already under way there"
	if (st().ops as Array).size() >= int(E.INTEL_MAX_OPS[level()]):
		return "Your agency is stretched: %d operations at once at this budget" % int(E.INTEL_MAX_OPS[level()])
	if bool(OPS[op].get("hostile_only", false)) and Game.relations[i] > -15.0:
		return "Only against hostile countries"
	if op == "tech" and str(Tech.st().current) == "":
		return "Choose something to research first"
	return ""


static func launch(op: String, i: int) -> bool:
	if can_launch(op, i) != "":
		return false
	(st().ops as Array).append({"op": op, "target": i, "start": Game.months_played, "months": int(OPS[op].months),
		"p": success_chance(op, i), "x": exposure_chance(op, i)})
	return true


static func months_left(o: Dictionary) -> int:
	return maxi(0, int(o.start) + int(o.months) - Game.months_played)


## War edge against country i (strength multiplier).
static func war_edge(i: int) -> float:
	return E.INTEL_WAR_EDGE if Game.months_played < int((st().edge as Dictionary).get(str(i), -1)) else 1.0


static func _log(text: String, good: bool) -> void:
	var lg: Array = st().log
	lg.push_front({"text": text, "good": good, "m": Game.months_played})
	if lg.size() > 8:
		lg.resize(8)


## Monthly: finish operations, foreign spies try their luck. Returns headlines
## [{text, icon, good, big}] (big ones also show a banner).
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var keep: Array = []
	for o in st().ops:
		if months_left(o) > 0:
			keep.append(o)
			continue
		out.append(_resolve(o))
	st().ops = keep
	_foreign_spies(out)
	return out


static func _resolve(o: Dictionary) -> Dictionary:
	var op := str(o.op)
	var i := int(o.target)
	var t: CountryState = Game.state(i)
	var ok := Game.rng.randf() < float(o.p)
	var exposed := Game.rng.randf() < float(o.x)
	var me := Game.me()
	var text := ""
	if ok and t != null:
		match op:
			"gather":
				(st().edge as Dictionary)[str(i)] = Game.months_played + 24
				text = "Intelligence: a full picture of %s's forces and plans" % World.the_name(i)
			"tech":
				var pts := E.INTEL_TECH_POINTS * clampf(t.gdp_per_capita() / maxf(me.gdp_per_capita(), 1.0), 0.3, 3.0)
				Tech.st().progress = float(Tech.st().progress) + pts
				text = "Stolen research from %s: %d points toward your current technology" % [World.the_name(i), roundi(pts)]
			"sabotage":
				t.shocks.growth = float(t.shocks.growth) - E.INTEL_SABOTAGE_GROWTH
				t.military = maxf(t.military - E.INTEL_SABOTAGE_MIL, 1.0)
				text = "Sabotage in %s: power cuts, a port fire and a damaged arms plant" % World.the_name(i)
			"meddle":
				if not exposed:
					Diplomacy.change_relation(i, E.INTEL_MEDDLE_REL)
				text = "Your friends gain ground in %s's politics" % World.the_name(i)
			"rebels":
				t.shocks.stability = float(t.shocks.stability) - E.INTEL_REBELS_STAB
				text = "Rebels armed by your agents shake %s" % World.the_name(i)
	else:
		text = "Operation in %s fails: %s" % [World.the_name(i), str(OPS[op].title).to_lower()]
	if exposed:
		Diplomacy.change_relation(i, -E.INTEL_EXPOSED_REL)
		for j in World.playable:
			if j != Game.player and j != i and Game.relations[j] > 0.0 and Game.state(j) != null:
				# Their friendly neighbours cool on you too.
				if World.sovereign_of(j) == j and World.map.neighbours[i].has(j) and not Diplomacy._pair_hostile(i, j):
					Game.relations[j] = clampf(Game.relations[j] - E.INTEL_EXPOSED_FRIENDS, -100.0, 100.0)
		Game.relations_changed.emit()
		me.shocks.approval = float(me.shocks.approval) - E.INTEL_EXPOSED_APPROVAL
		Press.apply_cred(-5.0)
		st().lost = int(st().lost) + 1
		text += ". Exposed! %s expels your diplomats" % World.The_name(i)
	_log(text, ok and not exposed)
	return {"text": text, "icon": "eye-off" if exposed else str(OPS[op].icon), "good": ok and not exposed, "big": true}


## Hostile countries spy on you; your agency catches some.
static func _foreign_spies(out: Array) -> void:
	if Game.months_played < 6:
		return
	var cands: Array = []
	for j in World.playable:
		if j != Game.player and Game.relations[j] <= -30.0:
			cands.append(j)
	if cands.is_empty() or Game.rng.randf() > E.INTEL_FOREIGN_CHANCE:
		return
	var j: int = cands[Game.rng.randi() % cands.size()]
	var mine := strength(Game.player)
	var catch := mine / (mine + strength(j))
	var me := Game.me()
	if Game.rng.randf() < catch:
		st().caught = int(st().caught) + 1
		Diplomacy.change_relation(j, -8.0)
		me.shocks.approval = float(me.shocks.approval) + 1.0
		var text := "Spy ring caught: agents working for %s arrested" % World.the_name(j)
		_log(text, true)
		out.append({"text": text, "icon": "shield-check", "good": true, "big": true})
	else:
		var text2 := ""
		if str(Tech.st().current) != "" and Game.rng.randf() < 0.5:
			Tech.st().progress = maxf(float(Tech.st().progress) - E.INTEL_TECH_POINTS * 0.5, 0.0)
			text2 = "Hackers linked to %s steal research from your labs" % World.the_name(j)
		else:
			me.shocks.growth = float(me.shocks.growth) - E.INTEL_SABOTAGE_GROWTH * 0.5
			text2 = "Suspected sabotage by %s: a refinery fire and a cyberattack on banks" % World.the_name(j)
		_log(text2, false)
		out.append({"text": text2, "icon": "shield-alert", "good": false, "big": false})
