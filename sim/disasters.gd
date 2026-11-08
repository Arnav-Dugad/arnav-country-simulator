class_name Disasters
extends RefCounted
## Interactive disasters and climate adaptation.
##   Response   when a flood, storm, quake, heatwave, drought or wildfire strikes,
##              an emergency runs for a few months. People are affected and
##              some die each month; your response decides how many: send the
##              army, release emergency funds, ask the world for aid, visit the
##              area. Then you rebuild: quickly and cheaply, or "build back
##              better", which also protects you against the next one.
##   Adaptation one-off national projects (sea walls, early warning, earthquake
##              codes, firebreaks, drought-proof farming) that soften the
##              disasters they protect against. Warming makes disasters more
##              frequent (Climate.disaster_mult).
##   Refugees   as the world warms, people fleeing hard-hit countries ask you
##              for shelter.
## State: Game.dip.dis {active: {...} or {}, adapt: {id: {done, start}}, log: [...], refugees_m}.
## Constants in sim/economy.gd (DIS_*).

const E = preload("res://sim/economy.gd")

const TYPES := {
	"floods": {"title": "Floods", "icon": "waves", "scene": "flood", "people": 0.02, "damage": 0.6},
	"monsoon": {"title": "Monsoon floods", "icon": "cloud-rain", "scene": "flood", "people": 0.03, "damage": 0.5},
	"hurricane": {"title": "Hurricane", "icon": "tornado", "scene": "hurricane", "people": 0.015, "damage": 1.0},
	"heatwave": {"title": "Heatwave", "icon": "thermometer-sun", "scene": "drought", "people": 0.05, "damage": 0.3},
	"earthquake": {"title": "Earthquake", "icon": "activity", "scene": "quake", "people": 0.01, "damage": 1.2},
	"drought": {"title": "Drought", "icon": "sun", "scene": "drought", "people": 0.04, "damage": 0.5},
	"wildfires": {"title": "Wildfires", "icon": "flame", "scene": "drought", "people": 0.005, "damage": 0.3},
}

## id -> {title, icon, desc, cost (% of GDP), months, protects: [types], cut (0..1)}
const ADAPT := {
	"early_warning": {"title": "Early-warning system", "icon": "siren", "cost": 0.05, "months": 12, "cut": 0.25,
		"protects": ["floods", "monsoon", "hurricane", "heatwave", "wildfires", "earthquake", "drought"],
		"desc": "Sirens, phone alerts and evacuation plans for every hazard."},
	"sea_walls": {"title": "Sea walls & flood barriers", "icon": "waves", "cost": 0.4, "months": 36, "cut": 0.5,
		"protects": ["floods", "monsoon", "hurricane"], "desc": "Keep storm surges and swollen rivers out of the cities."},
	"quake_codes": {"title": "Earthquake-proof buildings", "icon": "building-2", "cost": 0.3, "months": 48, "cut": 0.55,
		"protects": ["earthquake"], "desc": "Strict building codes and retrofits for schools and hospitals."},
	"firebreaks": {"title": "Firebreaks & cooling centres", "icon": "trees", "cost": 0.1, "months": 18, "cut": 0.45,
		"protects": ["wildfires", "heatwave"], "desc": "Cleared firebreaks, water bombers and cool shelters in heatwaves."},
	"drought_farms": {"title": "Drought-proof farming", "icon": "sprout", "cost": 0.2, "months": 30, "cut": 0.5,
		"protects": ["drought", "heatwave"], "desc": "Irrigation, water storage and hardier crops."},
}


static func st() -> Dictionary:
	if not Game.dip.has("dis"):
		Game.dip["dis"] = {"active": {}, "adapt": {}, "log": [], "refugees_m": -99, "built_back": {}}
	return Game.dip.dis


static func active() -> bool:
	return not (st().active as Dictionary).is_empty()


# ------------------------------------------------------------------ adaptation ---
static func adapted(id: String) -> bool:
	return bool((st().adapt as Dictionary).get(id, {}).get("done", false))


static func building(id: String) -> bool:
	var a: Dictionary = (st().adapt as Dictionary).get(id, {})
	return not a.is_empty() and not bool(a.get("done", false))


static func adapt_cost(id: String) -> float:
	return Game.me().gdp * float(ADAPT[id].cost) / 100.0


static func start_adapt(id: String) -> bool:
	if adapted(id) or building(id):
		return false
	Game.me().treasury -= adapt_cost(id)
	(st().adapt as Dictionary)[id] = {"done": false, "start": Game.months_played}
	Game.add_feed("Work begins: %s" % str(ADAPT[id].title).to_lower(), str(ADAPT[id].icon), "accent")
	return true


## Share of a disaster's harm that still gets through (1 = unprotected).
static func harm_mult(kind: String) -> float:
	var m := 1.0
	for id in ADAPT:
		if adapted(str(id)) and kind in ADAPT[id].protects:
			m *= 1.0 - float(ADAPT[id].cut)
	if Game.dip.has("const"):
		m *= 1.0 - Constitution.fx("disaster")
	if int((st().built_back as Dictionary).get(kind, 0)) > 0:
		m *= 1.0 - E.DIS_BUILD_BACK_CUT
	return clampf(m, 0.15, 1.0)


# ------------------------------------------------------------------- response ---
## A disaster strikes you (called when a disaster event is answered).
static func start(kind: String) -> void:
	if not TYPES.has(kind) or active():
		return
	var c := Game.me()
	var spec: Dictionary = TYPES[kind]
	var sev := Game.rng.randf_range(0.6, 1.4) * Climate.disaster_mult() * harm_mult(kind)
	st().active = {"kind": kind, "start": Game.months_played, "sev": sev,
		"affected": c.population * float(spec.people) * sev, "deaths": 0.0, "relief": 0.0,
		"acts": {}, "phase": "emergency", "damage": float(spec.damage) * sev}


static func act_done(a: String) -> bool:
	return (st().active.get("acts", {}) as Dictionary).has(a)


## Response actions: army, funds, aid, visit.
static func act(a: String) -> String:
	var d: Dictionary = st().active
	if d.is_empty() or act_done(a) or str(d.phase) != "emergency":
		return ""
	var c := Game.me()
	var text := ""
	match a:
		"army":
			d.relief = float(d.relief) + 0.3
			c.military = maxf(c.military - 1.0, 1.0)
			c.shocks.approval = float(c.shocks.approval) + 1.0
			text = "Soldiers fill sandbags, clear roads and carry people to safety"
		"funds":
			c.treasury -= c.gdp * E.DIS_FUND_COST / 100.0
			d.relief = float(d.relief) + 0.35
			text = "Emergency funds release food, shelter and medicine"
		"aid":
			d.relief = float(d.relief) + 0.25
			c.shocks.approval = float(c.shocks.approval) - 0.5
			for j in World.playable:
				if j != Game.player and Game.relations[j] > 20.0:
					Game.relations[j] = clampf(Game.relations[j] + 1.0, -100.0, 100.0)
			text = "Rescue teams and aid planes arrive from friendly countries"
		"visit":
			var good := float(d.relief) >= 0.3
			c.shocks.approval = float(c.shocks.approval) + (2.0 if good else -2.0)
			text = "You tour the disaster zone: " + ("people thank you for the help" if good else "angry crowds ask where the help is")
	(d.acts as Dictionary)[a] = Game.months_played
	Game.add_feed(text, str(TYPES[str(d.kind)].icon), "accent")
	return text


static func rebuild_cost(better: bool) -> float:
	var d: Dictionary = st().active
	return Game.me().gdp * float(d.get("damage", 0.5)) * (E.DIS_BETTER_COST if better else E.DIS_QUICK_COST) / 100.0


static func rebuild(better: bool) -> String:
	var d: Dictionary = st().active
	if d.is_empty() or str(d.phase) != "rebuild":
		return ""
	var c := Game.me()
	c.treasury -= rebuild_cost(better)
	c.shocks.growth = float(c.shocks.growth) + float(d.damage) * 0.6       # rebuilding puts people to work
	if better:
		var bb: Dictionary = st().built_back
		bb[str(d.kind)] = int(bb.get(str(d.kind), 0)) + 1
		c.shocks.approval = float(c.shocks.approval) + 1.5
	_finish()
	return "Rebuilding %s: %s" % ["better than before" if better else "quickly", "towns will be safer next time" if better else "life goes back to normal"]


static func _finish() -> void:
	var d: Dictionary = st().active
	(st().log as Array).push_front({"kind": d.kind, "m": int(d.start), "deaths": float(d.deaths), "relief": float(d.relief)})
	if (st().log as Array).size() > 8:
		(st().log as Array).resize(8)
	Game.add_milestone("Came through the %s" % str(TYPES[str(d.kind)].title).to_lower(), str(TYPES[str(d.kind)].icon), "accent")
	st().active = {}


## Monthly: the emergency unfolds, then waits for a rebuild choice (or rebuilds by itself).
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var c := Game.me()
	for id in s.adapt:
		var a: Dictionary = s.adapt[id]
		if not bool(a.done) and Game.months_played - int(a.start) >= int(ADAPT[id].months):
			a.done = true
			out.append({"text": "Finished: %s" % str(ADAPT[id].title).to_lower(), "icon": str(ADAPT[id].icon), "good": true})
	var d: Dictionary = s.active
	if not d.is_empty():
		var age := Game.months_played - int(d.start)
		if str(d.phase) == "emergency":
			var relief := clampf(float(d.relief), 0.0, 0.9)
			var dead := float(d.affected) * E.DIS_DEATH_RATE * (1.0 - relief)
			d.deaths = float(d.deaths) + dead
			c.population = maxf(c.population - dead, 1.0)
			c.shocks.growth = float(c.shocks.growth) - float(d.damage) * (1.0 - relief * 0.5) * 0.5
			c.shocks.happiness = float(c.shocks.happiness) - 1.0 * (1.0 - relief)
			if relief < 0.2:
				c.shocks.approval = float(c.shocks.approval) - 1.0      # "where is the government?"
			if age >= E.DIS_EMERGENCY_MONTHS:
				d.phase = "rebuild"
				d.rebuild_m = Game.months_played
				out.append({"text": "The %s emergency is over: %s dead. Time to rebuild" % [str(TYPES[str(d.kind)].title).to_lower(),
					DS.compact(float(d.deaths))], "icon": str(TYPES[str(d.kind)].icon), "good": relief >= 0.5})
		elif Game.months_played - int(d.get("rebuild_m", Game.months_played)) >= 6:
			out.append({"text": rebuild(false), "icon": "hammer", "good": true})      # the cabinet decides
	# Climate refugees.
	if Climate.warming() - Climate.start_warming() > E.DIS_REFUGEE_WARMING and Game.months_played - int(s.refugees_m) > 36 \
			and Game.rng.randf() < E.DIS_REFUGEE_CHANCE:
		s.refugees_m = Game.months_played
		out.append({"text": "refugees", "icon": "users", "good": false, "refugees": true})
	return out


## Asylum for climate refugees: accept (people, a little strain, goodwill) or refuse.
static func refugee_event() -> Dictionary:
	var from := -1
	var tries := 0
	while from < 0 and tries < 30:
		tries += 1
		var j: int = World.playable[Game.rng.randi() % World.playable.size()]
		if j != Game.player and Game.state(j) != null and Economy.income_level(Game.state(j).gdp_per_capita()) < 0.35:
			from = j
	if from < 0:
		return {}
	var n := Game.me().population * E.DIS_REFUGEE_SHARE
	var e := {"id": "climate_refugees", "title": "Climate refugees", "icon": "users", "tint": "orange", "weight": 0.0,
		"body": "Crops have failed again in {other}. %s people fleeing the heat and floods ask %s for shelter." % [DS.compact(n), World.the_name(Game.player)],
		"choices": [
			{"label": "Welcome them", "detail": "More workers in time · some strain now · the world approves", "effects": {"refugees": E.DIS_REFUGEE_SHARE, "relations_all": 2.0, "happiness": -1.0}},
			{"label": "Take a few", "detail": "A smaller quota", "effects": {"refugees": E.DIS_REFUGEE_SHARE * 0.3, "relations_all": 0.5}},
			{"label": "Close the border", "detail": "Popular with some · the world frowns", "effects": {"approval": 1.0, "relations_all": -2.0}}]}
	return GameEvents.instance(e, from)
