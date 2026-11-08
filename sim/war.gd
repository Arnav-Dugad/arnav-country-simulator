class_name War
extends RefCounted
## Wars between you and another country, fought month by month on their shared
## front. Each month brings one battle, decided by both sides' strength:
##   strength = military^1.3 x morale x supply x (1 + allies) x (1.25 if defending)
## The winner takes ground (a share of the loser's territory) or liberates its
## own first. Morale falls with defeats and long wars; casualties wear down
## military strength (it recovers slowly after peace). Wars cost money every
## month, rally the nation at first and then wear it out.
## A war ends with peace terms: status quo, reparations, or taking the ground
## you hold (annexed land moves a share of the loser's people and economy to
## the winner and stays striped on the map). Lose most of your land and your
## government falls.
## State: Game.dip.wars {idx: {...}}, Game.dip.annexed {idx: {by, frac}}.
## Constants: sim/economy.gd (WAR_*).

const E = preload("res://sim/economy.gd")


static func wars() -> Dictionary:
	if not Game.dip.has("wars"):
		Game.dip["wars"] = {}
	return Game.dip.wars


static func at_war() -> bool:
	return not wars().is_empty()


static func with(i: int) -> Dictionary:
	return wars().get(str(i), {})


static func is_at_war_with(i: int) -> bool:
	return wars().has(str(i))


## Countries you can fight: neighbours, or anyone if both have a coast and your
## military can project power (or you're allied with one of their neighbours).
static func can_reach(i: int) -> bool:
	var me := Game.player
	for j in World.neighbours_of(me):
		var s := World.sovereign_of(j)
		if j == i or s == i:
			return true
	return Game.me().military >= E.WAR_REACH_MIL and not World.landlocked(me) and not World.landlocked(i)


static func is_neighbour(i: int) -> bool:
	for j in World.neighbours_of(Game.player):
		if j == i or World.sovereign_of(j) == i:
			return true
	return false


## "" if you may declare war on i, else why not.
static func blocked(i: int) -> String:
	if i == Game.player or Game.state(i) == null:
		return "Not possible"
	if is_at_war_with(i):
		return "Already at war"
	if Diplomacy.has_alliance(i):
		return "They are your ally"
	if not can_reach(i):
		return "Too far away: they aren't a neighbour and your forces can't reach them"
	if not Capital.can(E.WAR_DECLARE_CAPITAL):
		return "Needs %d political capital" % int(E.WAR_DECLARE_CAPITAL)
	return ""


static func _allies_strength(side: int) -> float:
	## Share of allied military that joins (only allies who joined the war).
	var s := 0.0
	if side == Game.player:
		for k in Game.dip.get("alliances", {}):
			var a: CountryState = Game.state(int(k))
			if a != null and Game.relations[int(k)] >= E.WAR_ALLY_JOIN_RELATION:
				s += a.military
	return s


static func strength(side: int, enemy: int, w: Dictionary) -> float:
	var c: CountryState = Game.state(side)
	if c == null:
		return 1.0
	var mine := side == Game.player
	var morale := float(w.morale_me if mine else w.morale_them)
	var s := pow(maxf(c.military, 1.0), 1.3) * morale
	if mine:
		s *= 1.0 + (float(w.get("allies", 0.0)) + Annexation.vassal_strength()) * E.WAR_ALLY_SHARE / maxf(c.military, 1.0)
		s *= float({"offensive": E.WAR_OFFENSIVE_STRENGTH, "defensive": E.WAR_DEFENSIVE_STRENGTH}.get(_strat(w), 1.0))
		if Game.months_played < int(w.get("air_until", -1)):
			s *= 1.0 + float(w.get("air_power", 0.2))
		# Low support at home saps the army.
		s *= lerpf(0.85, 1.05, support(w) / 100.0)
		s *= Intel.war_edge(enemy)
		if Game.months_played < int(w.get("mobilized_until", -1)):
			s *= E.WAR_MOBILIZE_BOOST
	var defending := (mine and not bool(w.attacker_me)) or (not mine and bool(w.attacker_me))
	if defending:
		s *= E.WAR_DEFENDER_BONUS
	# Far from home without a shared border: supply lines thin.
	if not is_neighbour(enemy) and not defending:
		s *= E.WAR_FAR_PENALTY
	return s


## Chance you win the next battle.
static func odds(i: int) -> float:
	var w := with(i)
	if w.is_empty():
		w = _fresh(i, true)
	var a := strength(Game.player, i, w)
	var b := strength(i, i, w)
	return a / maxf(a + b, 0.001)


static func _fresh(i: int, attacker: bool, goal_id: String = "conquest") -> Dictionary:
	return {"start": Game.months_played, "attacker_me": attacker, "occ_me": 0.0, "occ_them": 0.0,
		"morale_me": 1.0, "morale_them": 1.0, "cas_me": 0, "cas_them": 0, "log": [], "allies": 0.0,
		"mobilized_until": -1, "goal": goal_id, "strategy": "balanced", "support": 75.0 if attacker else 90.0, "ops": {}}


static func declare(i: int, goal_id: String = "conquest") -> void:
	if blocked(i) != "":
		return
	Capital.spend(E.WAR_DECLARE_CAPITAL)
	var w := _fresh(i, true, goal_id)
	var anger_mult := float(GOALS[goal_id].anger)
	w.allies = _allies_strength(Game.player)
	wars()[str(i)] = w
	Game.relations[i] = -100.0
	if Diplomacy.has_deal(i):
		Diplomacy.cancel_deal(i)
	# The world condemns an attack, the victim's camp most of all.
	for j in World.playable:
		if j != Game.player and j != i:
			var hit := E.WAR_WORLD_ANGER * anger_mult
			if Treaties.base_camp(j) == Treaties.base_camp(i):
				hit *= 1.6
			Game.relations[j] = clampf(Game.relations[j] - hit, -100.0, 100.0)
	Game.relations_changed.emit()
	var me := Game.me()
	me.shocks.approval = float(me.shocks.approval) + E.WAR_RALLY * float(GOALS[goal_id].rally)
	Game.add_feed("%s declares war on %s (%s)" % [World.The_name(Game.player), World.the_name(i), str(GOALS[goal_id].title).to_lower()], "swords", "red")
	Game.add_milestone("Declared war on %s" % World.map.names[i], "swords", "red")


## An enemy attacks you.
static func attacked_by(i: int) -> void:
	if is_at_war_with(i):
		return
	var w := _fresh(i, false)
	w.allies = _allies_strength(Game.player)
	wars()[str(i)] = w
	Game.relations[i] = -100.0
	var me := Game.me()
	me.shocks.approval = float(me.shocks.approval) + E.WAR_RALLY * 1.5
	for j in World.playable:
		if j != Game.player and j != i and Game.relations[j] > -50.0:
			Game.relations[j] = clampf(Game.relations[j] + E.WAR_SYMPATHY, -100.0, 100.0)
	Game.relations_changed.emit()
	Game.add_feed("%s has invaded %s!" % [World.The_name(i), World.the_name(Game.player)], "swords", "red")
	Game.add_milestone("Invaded by %s" % World.map.names[i], "swords", "red")


## Monthly: one battle per war, morale and casualties. Returns notices
## [{text, big, win}] for the UI.
static func monthly() -> Array:
	var notes: Array = []
	_maybe_attacked()
	for k in wars().keys():
		var i := int(k)
		var w: Dictionary = wars()[k]
		var them: CountryState = Game.state(i)
		if them == null:
			wars().erase(k)
			continue
		var p := odds(i)
		var win := Game.rng.randf() < p
		var margin := absf(p - 0.5) * 2.0
		var swing := Game.rng.randf_range(E.WAR_SWING_MIN, E.WAR_SWING_MAX) * (1.0 + margin)
		var me := Game.me()
		var where := ""
		var strat := _strat(w)
		var max_occ := float(GOALS[goal(w)].max_occ)
		if win:
			swing *= float({"offensive": 1.3, "defensive": 0.6}.get(strat, 1.0))
		else:
			swing *= float({"offensive": 1.1, "defensive": 0.6}.get(strat, 1.0))
		if win:
			if float(w.occ_me) > 0.0:
				w.occ_me = maxf(float(w.occ_me) - swing, 0.0)
				where = "you take back ground"
			else:
				w.occ_them = minf(float(w.occ_them) + swing, max_occ)
				where = "your forces advance" if float(w.occ_them) < max_occ - 0.001 else "your forces hold the line you set out to take"
			w.morale_them = maxf(float(w.morale_them) - E.WAR_MORALE_HIT, 0.15)
			w.morale_me = minf(float(w.morale_me) + E.WAR_MORALE_GAIN, 1.2)
		else:
			if float(w.occ_them) > 0.0:
				w.occ_them = maxf(float(w.occ_them) - swing, 0.0)
				where = "the enemy pushes you back"
			else:
				w.occ_me = minf(float(w.occ_me) + swing, E.WAR_MAX_OCC)
				where = "the enemy advances into your land"
			w.morale_me = maxf(float(w.morale_me) - E.WAR_MORALE_HIT, 0.15)
			w.morale_them = minf(float(w.morale_them) + E.WAR_MORALE_GAIN, 1.2)
		# Weariness: morale slowly drains the longer it lasts.
		w.morale_me = maxf(float(w.morale_me) - E.WAR_WEARINESS, 0.15)
		w.morale_them = maxf(float(w.morale_them) - E.WAR_WEARINESS, 0.15)
		# Casualties: both armies wear down (recovers after peace).
		var loss_me: float = Game.rng.randf_range(0.4, 1.4) * (1.5 if not win else 0.8) * float({"offensive": 1.35, "defensive": 0.65}.get(strat, 1.0))
		var loss_them := Game.rng.randf_range(0.4, 1.4) * (1.5 if win else 0.8)
		me.military = maxf(me.military - loss_me, 1.0)
		them.military = maxf(them.military - loss_them, 1.0)
		var scale := clampf(sqrt(minf(me.population, them.population) / 1e6), 1.0, 40.0)
		w.cas_me = int(w.cas_me) + int(loss_me * 180.0 * scale)
		w.cas_them = int(w.cas_them) + int(loss_them * 180.0 * scale)
		them.shocks.growth = float(them.shocks.growth) - E.WAR_GROWTH * 0.5
		them.shocks.stability = float(them.shocks.stability) - 0.6
		if Game.months_played < int(w.get("blockade_until", -1)):
			them.shocks.growth = float(them.shocks.growth) - E.WAR_BLOCKADE_GROWTH
			w.morale_them = maxf(float(w.morale_them) - 0.02, 0.15)
		# Support at home: victories lift it, defeats, casualties and time wear it down.
		var sup := support(w) + (E.WAR_SUPPORT_WIN if win else -E.WAR_SUPPORT_LOSS) - E.WAR_SUPPORT_DRAIN
		sup -= loss_me * 0.6
		if Game.dip.has("media") and not Media.campaign().is_empty() and str(Media.campaign().id) == "troops":
			sup += 1.5
		if Game.dip.has("media"):
			sup += 0.3 * float(Media.steps())        # controlled media keeps doubts off the air
		var was := support(w)
		w.support = clampf(sup, 0.0, 100.0)
		if was >= 30.0 and float(w.support) < 30.0:
			Game.add_feed("Anti-war protests fill the streets of %s" % World.the_name(Game.player), "megaphone", "red")
			me.shocks.stability = float(me.shocks.stability) - 3.0
		var big := swing * (1.0 + margin) > E.WAR_BIG_BATTLE
		var line := "Battle on the %s front: %s" % [World.map.names[i], where]
		(w.log as Array).push_front({"date": Game.date_text(), "win": win, "text": where})
		if (w.log as Array).size() > 12:
			(w.log as Array).pop_back()
		w["last"] = {"win": win, "m": Game.months_played}
		if not w.has("hist"):
			w["hist"] = []
		(w.hist as Array).append(float(w.occ_them) - float(w.occ_me))
		if (w.hist as Array).size() > 72:
			(w.hist as Array).remove_at(0)
		Game.add_feed(line, "swords", "green" if win else "red")
		notes.append({"text": line, "big": big, "win": win, "enemy": i})
		# Endgames.
		if float(w.occ_them) >= E.WAR_SURRENDER_OCC or float(w.morale_them) <= 0.2:
			w["they_sue"] = true
		if float(w.occ_them) >= E.WAR_CAPITULATE_OCC or (float(w.occ_them) >= 0.6 and float(w.morale_them) <= 0.2):
			if not bool(w.get("capitulated", false)):
				w["capitulated"] = true
				notes.append({"text": "%s capitulates! Its government asks for terms" % World.The_name(i), "big": true, "win": true, "enemy": i})
		if float(w.occ_me) >= E.WAR_SURRENDER_OCC or float(w.morale_me) <= 0.2:
			w["we_lose"] = true
		# Stalemate: both armies spent, or years without a result. They offer a ceasefire.
		var age := Game.months_played - int(w.start)
		if not bool(w.get("stalemate", false)) and not bool(w.get("capitulated", false)) \
				and ((float(w.morale_me) <= 0.35 and float(w.morale_them) <= 0.35) or age >= E.WAR_STALEMATE_MONTHS):
			w["stalemate"] = true
	return notes


## A hostile, much stronger neighbour may attack (rare; never in the first year).
static func _maybe_attacked() -> void:
	if Game.months_played < 12 or Game.no_events or Game.sandbox:
		return
	var me := Game.me()
	for j in World.neighbours_of(Game.player):
		var i := World.sovereign_of(j) if World.sovereign_of(j) >= 0 else j
		if i == Game.player or is_at_war_with(i) or not World.is_playable(i):
			continue
		var them: CountryState = Game.state(i)
		if them == null or Game.relations[i] > E.WAR_AI_HOSTILITY:
			continue
		if them.military < me.military * E.WAR_AI_ADVANTAGE:
			continue
		if Game.rng.randf() < E.WAR_AI_CHANCE * Difficulty.severity():
			attacked_by(i)
			return


## Month-by-month effects on you: {growth, inflation, unemployment, approval, stability, happiness, cost}.
static func effects() -> Dictionary:
	var out := {"growth": 0.0, "inflation": 0.0, "unemployment": 0.0, "approval": 0.0, "stability": 0.0, "happiness": 0.0, "cost": 0.0}
	if Game.me() == null:
		return out
	for k in wars():
		var w: Dictionary = wars()[k]
		var them: CountryState = Game.state(int(k))
		var size := clampf((them.gdp if them != null else 1.0) / maxf(Game.me().gdp, 1.0), 0.3, 2.5)
		var months := float(Game.months_played - int(w.start))
		out.growth -= E.WAR_GROWTH * sqrt(size)
		out.inflation += E.WAR_INFLATION
		out.unemployment -= 0.3
		out.cost += E.WAR_COST_PCT * sqrt(size)
		out.approval -= E.WAR_WEARY_APPROVAL * maxf(months - 6.0, 0.0) * 0.6
		out.approval += (support(w) - 50.0) * E.WAR_SUPPORT_APPROVAL
		out.happiness -= 1.5 + 0.08 * months
		out.stability -= 1.0 + float(w.occ_me) * 20.0
	return out


## Peace terms: "status_quo", "reparations" or "annex". Returns true if accepted.
static func accepts(i: int, terms: String) -> bool:
	var w := with(i)
	if w.is_empty():
		return false
	var winning := float(w.occ_them) - float(w.occ_me)
	var their_morale := float(w.morale_them)
	match terms:
		"status_quo":
			return winning > -0.15 or their_morale < 0.8 or Game.months_played - int(w.start) > 18 or bool(w.get("stalemate", false))
		"reparations":
			return winning > 0.08 and their_morale < 0.75
		"annex":
			return float(w.occ_them) >= 0.1 and (their_morale < 0.6 or bool(w.get("they_sue", false)) or bool(w.get("capitulated", false)))
		"annex_all":
			return bool(w.get("capitulated", false))
		"vassal":
			return bool(w.get("capitulated", false)) or (float(w.occ_them) >= 0.3 and their_morale < 0.5)
	return false


## Ends the war with the given terms. Returns a one-line summary.
static func make_peace(i: int, terms: String) -> String:
	var w := with(i)
	if w.is_empty():
		return ""
	var me := Game.me()
	var them: CountryState = Game.state(i)
	var text := ""
	if terms == "annex" and float(w.occ_them) * E.WAR_ANNEX_SHARE >= E.WAR_FULL_ANNEX_SHARE:
		terms = "annex_all"         # what's left of them can't stand alone
	match terms:
		"annex_all":
			wars().erase(str(i))
			text = Annexation.absorb(i, Game.player)
			Achievements.unlock("victor")
			Game.add_feed(text, "flag", "gold")
			Simulation.update_finances(me)
			return text
		"vassal":
			text = Annexation.make_vassal(i)
			Achievements.unlock("victor")
			wars().erase(str(i))
			Game.add_feed(text, "crown", "gold")
			Simulation.update_finances(me)
			return text
		"annex":
			var frac := float(w.occ_them) * E.WAR_ANNEX_SHARE
			_transfer(them, me, frac)
			_mark_annexed(i, Game.player, frac)
			text = "%s cedes the land you hold: %s more people join %s" % [World.The_name(i),
				DS.compact(them.population * frac / (1.0 - frac)), World.the_name(Game.player)]
			for j in World.playable:
				if j != Game.player and j != i:
					Game.relations[j] = clampf(Game.relations[j] - E.WAR_ANNEX_ANGER, -100.0, 100.0)
			Achievements.unlock("victor")
		"reparations":
			var pay := them.gdp * E.WAR_REPARATIONS
			them.debt += pay
			me.treasury += pay
			text = "%s agrees to pay %s in reparations" % [World.The_name(i), DS.money(pay)]
			Achievements.unlock("victor")
		"surrender":
			var frac2 := float(w.occ_me) * E.WAR_ANNEX_SHARE
			_transfer(me, them, frac2)
			_mark_annexed(Game.player, i, frac2)
			me.shocks.stability = float(me.shocks.stability) - 8.0
			me.shocks.approval = float(me.shocks.approval) - 10.0
			text = "%s gives up the occupied land to %s" % [World.The_name(Game.player), World.the_name(i)]
		_:
			text = "Peace with %s on the old borders" % World.the_name(i)
			Achievements.unlock("peacemaker")
	wars().erase(str(i))
	Game.relations[i] = -40.0
	Game.relations_changed.emit()
	Game.add_feed(text, "flag", "green" if terms != "surrender" else "orange")
	Game.add_milestone(text, "flag", "accent")
	Simulation.update_finances(me)
	return text


static func _transfer(from: CountryState, to: CountryState, frac: float) -> void:
	frac = clampf(frac, 0.0, 0.6)
	var pop := from.population * frac
	var gdp := from.gdp * frac * 0.7          # war damage: the land comes ruined
	from.population -= pop
	from.gdp -= from.gdp * frac
	to.population += pop
	to.gdp += gdp


static func _mark_annexed(loser: int, winner: int, frac: float) -> void:
	if not Game.dip.has("annexed"):
		Game.dip["annexed"] = {}
	var prev := float(Game.dip.annexed.get(str(loser), {}).get("frac", 0.0))
	Game.dip.annexed[str(loser)] = {"by": winner, "frac": clampf(prev + frac, 0.0, 0.9)}


## Occupied (during war) or annexed (after) share of each country, and by whom:
## {idx: [frac, by]} for the map.
static func map_marks() -> Dictionary:
	var out := {}
	for k in Game.dip.get("annexed", {}):
		if World.is_absorbed(int(k)):
			continue
		var a: Dictionary = Game.dip.annexed[k]
		out[int(k)] = [float(a.frac), int(a.by)]
	for k in WorldWars.all():
		var ww: Dictionary = WorldWars.all()[k]
		if float(ww.occ_b) > 0.0:
			out[int(ww.b)] = [float(ww.occ_b), int(ww.a)]
		if float(ww.occ_a) > 0.0:
			out[int(ww.a)] = [float(ww.occ_a), int(ww.b)]
	for k in wars():
		var w: Dictionary = wars()[k]
		if float(w.occ_them) > 0.0:
			out[int(k)] = [float(w.occ_them), Game.player]
		if float(w.occ_me) > 0.0:
			out[Game.player] = [float(w.occ_me), int(k)]
	return out


static func mobilize(i: int) -> bool:
	var w := with(i)
	if w.is_empty() or Game.months_played < int(w.get("mobilized_until", -1)) or not Capital.spend(E.WAR_MOBILIZE_CAPITAL):
		return false
	w.mobilized_until = Game.months_played + E.WAR_MOBILIZE_MONTHS
	Game.me().shocks.growth = float(Game.me().shocks.growth) - 0.6
	Game.add_feed("Reserves mobilized for the %s front" % World.map.names[i], "users", "accent")
	return true


## Allies with good relations join; returns how many did.
static func call_allies(i: int) -> int:
	var w := with(i)
	if w.is_empty():
		return 0
	var n := 0
	var s := 0.0
	for k in Game.dip.get("alliances", {}):
		var a: CountryState = Game.state(int(k))
		if a != null and Game.relations[int(k)] >= E.WAR_ALLY_JOIN_RELATION:
			s += a.military
			n += 1
	w.allies = s
	w["allies_called"] = true
	return n


# ------------------------------------------------------- goals & strategy ---
## War goals, chosen when you declare. max_occ: most ground you will take;
## anger: how the world reacts; rally: approval at home.
const GOALS := {
	"border": {"title": "Border war", "icon": "map-pin", "desc": "Seize disputed border land. Limited aims, limited outrage.",
		"max_occ": 0.35, "anger": 0.6, "rally": 1.0},
	"conquest": {"title": "Conquest", "icon": "swords", "desc": "Take as much land as your armies can hold.",
		"max_occ": 0.8, "anger": 1.0, "rally": 1.0},
	"total": {"title": "Total war", "icon": "flag", "desc": "Fight until they capitulate, then annex the whole country.",
		"max_occ": 1.0, "anger": 1.8, "rally": 0.7},
}

const STRATEGIES := {
	"offensive": {"title": "Offensive", "icon": "chevrons-right", "desc": "Push hard: more ground, more casualties."},
	"balanced": {"title": "Balanced", "icon": "scale", "desc": "Steady pressure."},
	"defensive": {"title": "Dig in", "icon": "shield", "desc": "Hold the line: fewer losses, slower gains."},
}

## Military operations: needs (a build you must have), cooldown (months), cost (% of GDP).
const OPS := {
	"air": {"title": "Air campaign", "icon": "plane", "needs": "fighters", "cooldown": 6, "cost": 0.1,
		"desc": "Fighter squadrons win the skies: much stronger for three months."},
	"blockade": {"title": "Naval blockade", "icon": "anchor", "needs": "frigate", "cooldown": 8, "cost": 0.08, "coast": true,
		"desc": "Warships cut their sea trade for six months: their economy and morale suffer."},
	"drones": {"title": "Drone strikes", "icon": "radar", "needs": "drones", "cooldown": 3, "cost": 0.03,
		"desc": "Precise strikes on depots and artillery."},
	"missiles": {"title": "Missile strikes", "icon": "rocket", "needs": "tech:hypersonic", "cooldown": 6, "cost": 0.15,
		"desc": "Long-range missiles hit command centres. Devastating, and the world notices."},
	"special": {"title": "Special forces raid", "icon": "crosshair", "needs": "infantry", "cooldown": 4, "cost": 0.02,
		"desc": "Commandos behind the lines. Breaks morale if it works; costly if it fails."},
	"cyber": {"title": "Cyberattack", "icon": "cpu", "needs": "cyber", "cooldown": 5, "cost": 0.03,
		"desc": "Knock out their power grid, banks and communications."},
}


static func goal(w: Dictionary) -> String:
	return str(w.get("goal", "conquest"))


static func set_strategy(i: int, s: String) -> void:
	var w := with(i)
	if not w.is_empty() and STRATEGIES.has(s):
		w.strategy = s


static func _strat(w: Dictionary) -> String:
	return str(w.get("strategy", "balanced"))


## "" if you can run this operation now, else why not.
static func op_blocked(i: int, op: String) -> String:
	var w := with(i)
	if w.is_empty():
		return "Not at war"
	var o: Dictionary = OPS[op]
	var need := str(o.needs)
	if need.begins_with("tech:"):
		if not Tech.has(need.substr(5)):
			return "Needs research: %s" % str(Tech.ALL[need.substr(5)].title)
	elif Builds.count(Game.me(), need) <= 0:
		return "Needs %s (build them on the Defence tab)" % str(Builds.spec(need).title).to_lower()
	if bool(o.get("coast", false)) and (World.landlocked(i) or World.landlocked(Game.player)):
		return "Needs a coastline on both sides"
	var last := int((w.get("ops", {}) as Dictionary).get(op, -100))
	var wait := last + int(o.cooldown) - Game.months_played
	if wait > 0:
		return "Ready again in %d %s" % [wait, "month" if wait == 1 else "months"]
	return ""


static func op_cost(op: String) -> float:
	return Game.me().gdp * float(OPS[op].cost) / 100.0


## Coverage (0..1) of a unit type: how much of it you have.
static func _cov(id: String) -> float:
	var c := Game.me()
	return Builds.coverage_of(c, id, float(Builds.count(c, id)))


## Runs an operation. Returns {text, good}.
static func run_op(i: int, op: String) -> Dictionary:
	if op_blocked(i, op) != "":
		return {}
	var w := with(i)
	var me := Game.me()
	var them: CountryState = Game.state(i)
	me.treasury -= op_cost(op)
	if not w.has("ops"):
		w["ops"] = {}
	w.ops[op] = Game.months_played
	var text := ""
	var good := true
	match op:
		"air":
			w.air_until = Game.months_played + 3
			w.air_power = 0.15 + 0.35 * _cov("fighters")
			text = "Air campaign: your squadrons own the skies over %s" % World.map.names[i]
		"blockade":
			w.blockade_until = Game.months_played + 6
			text = "Naval blockade: %s's ports are cut off" % World.map.names[i]
		"drones":
			them.military = maxf(them.military - (1.0 + 3.0 * _cov("drones")), 1.0)
			w.morale_them = maxf(float(w.morale_them) - 0.03, 0.15)
			text = "Drone strikes destroy depots and artillery across the front"
		"missiles":
			them.military = maxf(them.military - 5.0, 1.0)
			w.morale_them = maxf(float(w.morale_them) - 0.1, 0.15)
			them.shocks.growth = float(them.shocks.growth) - 1.0
			for j in World.playable:
				if j != Game.player and j != i:
					Game.relations[j] = clampf(Game.relations[j] - 2.0, -100.0, 100.0)
			text = "Missile strikes hit command centres in %s" % World.map.names[i]
		"special":
			if Game.rng.randf() < 0.45 + 0.35 * _cov("infantry"):
				w.morale_them = maxf(float(w.morale_them) - 0.1, 0.15)
				text = "Special forces raid succeeds: a key bridge and headquarters destroyed"
			else:
				w.cas_me = int(w.cas_me) + 200
				w.support = maxf(float(w.get("support", 60.0)) - 4.0, 0.0)
				text = "Special forces raid goes wrong: commandos lost behind enemy lines"
				good = false
		"cyber":
			them.shocks.growth = float(them.shocks.growth) - 1.5
			w.morale_them = maxf(float(w.morale_them) - 0.03, 0.15)
			text = "Cyberattack blacks out power and banks in %s" % World.map.names[i]
	(w.log as Array).push_front({"date": Game.date_text(), "win": good, "text": text.to_lower()})
	if (w.log as Array).size() > 12:
		(w.log as Array).pop_back()
	Game.add_feed(text, str(OPS[op].icon), "green" if good else "red")
	return {"text": text, "good": good}


## Home-front support for the war (0..100).
static func support(w: Dictionary) -> float:
	return float(w.get("support", 60.0))
