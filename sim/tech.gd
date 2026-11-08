class_name Tech
extends RefCounted
## Research and the space race. Research points (RP) come in every month from
## your research budget, universities and labs, and your wealth. Pick one
## technology at a time; when its points are in, it's yours for good:
## lasting effects, sometimes new things to build. Space technologies are a
## race: other big economies research them too, and being first counts.
## State: Game.dip.tech {done: [ids], current: id, progress: float, firsts: {id: iso}, ai: {iso: pts}}.

const E = preload("res://sim/economy.gd")

const BRANCHES := ["Economy", "Energy", "Health", "Transport", "Space", "Military"]

## id -> {branch, title, icon, desc, cost (RP), req: [ids], fx (targets), unlock (build id), space (race step)}
const ALL := {
	# Economy
	"automation": {"branch": "Economy", "title": "Industrial automation", "icon": "factory", "cost": 40, "req": [],
		"desc": "Robots on the factory floor.", "fx": {"growth": 0.3, "unemployment": 0.2}},
	"egov": {"branch": "Economy", "title": "Digital government", "icon": "server", "cost": 40, "req": [],
		"desc": "Services and taxes online. Less paperwork, less bribery.", "fx": {"stability": 0.8}, "clean": 6.0},
	"fintech": {"branch": "Economy", "title": "Digital payments", "icon": "coins", "cost": 60, "req": ["egov"],
		"desc": "Cheap, instant payments for everyone.", "fx": {"growth": 0.2, "happiness": 0.4}},
	"ai": {"branch": "Economy", "title": "Artificial intelligence", "icon": "cpu", "cost": 150, "req": ["automation"],
		"desc": "AI across the economy. Big gains; some jobs vanish.", "fx": {"growth": 0.6, "unemployment": 0.4}},
	"quantum": {"branch": "Economy", "title": "Quantum computing", "icon": "atom", "cost": 220, "req": ["ai"],
		"desc": "Computers that crack problems no others can.", "fx": {"growth": 0.4}, "unlock": "quantum_lab"},
	# Energy
	"smart_grid": {"branch": "Energy", "title": "Smart grid", "icon": "plug-zap", "cost": 40, "req": [],
		"desc": "A grid that balances itself. Fewer blackouts.", "fx": {"inflation": -0.1, "stability": 0.3}},
	"adv_solar": {"branch": "Energy", "title": "Next-gen solar", "icon": "sun", "cost": 60, "req": [],
		"desc": "Cheaper, more efficient panels.", "fx": {"inflation": -0.1}, "co2": 0.05},
	"storage": {"branch": "Energy", "title": "Solid-state batteries", "icon": "battery-charging", "cost": 90, "req": ["smart_grid"],
		"desc": "Store power for days, not hours.", "fx": {"inflation": -0.1}, "co2": 0.04},
	"fusion": {"branch": "Energy", "title": "Fusion power", "icon": "atom", "cost": 320, "req": ["storage", "adv_solar"],
		"desc": "Endless clean energy, at last.", "fx": {"growth": 0.4, "inflation": -0.3}, "co2": 0.12, "unlock": "fusion_plant"},
	# Health
	"telemed": {"branch": "Health", "title": "Telemedicine", "icon": "stethoscope", "cost": 40, "req": [],
		"desc": "See a doctor from home.", "fx": {"happiness": 0.6}, "life": 0.4},
	"mrna": {"branch": "Health", "title": "mRNA vaccines", "icon": "shield-check", "cost": 60, "req": [],
		"desc": "New vaccines in weeks, not years.", "fx": {"stability": 0.4}, "life": 0.5},
	"genomics": {"branch": "Health", "title": "Genomic medicine", "icon": "flask-conical", "cost": 90, "req": ["mrna"],
		"desc": "Treatments matched to your genes.", "fx": {"happiness": 0.6}, "life": 1.0},
	"longevity": {"branch": "Health", "title": "Longevity therapies", "icon": "heart", "cost": 260, "req": ["genomics"],
		"desc": "Slowing ageing itself.", "fx": {"happiness": 1.2}, "life": 2.5},
	# Transport
	"ev_tech": {"branch": "Transport", "title": "Cheap electric cars", "icon": "plug-zap", "cost": 50, "req": [],
		"desc": "EVs cheaper than petrol cars.", "fx": {"inflation": -0.05}, "co2": 0.05},
	"autonomy": {"branch": "Transport", "title": "Self-driving vehicles", "icon": "truck", "cost": 160, "req": ["ai", "ev_tech"],
		"desc": "Trucks and taxis drive themselves.", "fx": {"growth": 0.3, "unemployment": 0.2, "happiness": 0.3}},
	"maglev": {"branch": "Transport", "title": "Maglev trains", "icon": "train-front", "cost": 140, "req": ["ev_tech"],
		"desc": "600 km/h between cities.", "fx": {"growth": 0.1}, "unlock": "maglev"},
	# Space (the race)
	"satellites": {"branch": "Space", "title": "Own satellites", "icon": "satellite", "cost": 50, "req": [],
		"desc": "Launch your own satellites.", "fx": {"growth": 0.05}, "space": 1},
	"rockets": {"branch": "Space", "title": "Reusable rockets", "icon": "rocket", "cost": 90, "req": ["satellites"],
		"desc": "Rockets that land and fly again.", "fx": {"growth": 0.1}, "unlock": "spaceport", "space": 2},
	"orbit": {"branch": "Space", "title": "Crewed orbit", "icon": "users", "cost": 140, "req": ["rockets"],
		"desc": "Your astronauts circle the Earth.", "fx": {"happiness": 0.5}, "space": 3, "prestige": 3.0},
	"station": {"branch": "Space", "title": "Space station", "icon": "satellite", "cost": 220, "req": ["orbit"],
		"desc": "A permanent home in orbit.", "fx": {"growth": 0.1, "happiness": 0.5}, "space": 4, "prestige": 3.0},
	"moon": {"branch": "Space", "title": "Crewed Moon landing", "icon": "flag", "cost": 280, "req": ["orbit"],
		"desc": "Your astronauts walk on the Moon.", "fx": {"happiness": 1.0}, "space": 5, "prestige": 6.0},
	"mars": {"branch": "Space", "title": "Mars mission", "icon": "rocket", "cost": 480, "req": ["moon", "station"],
		"desc": "Humans on Mars, under your flag.", "fx": {"happiness": 1.5, "growth": 0.1}, "space": 6, "prestige": 10.0},
	# Military
	"cyberdef": {"branch": "Military", "title": "Cyber defence", "icon": "shield-check", "cost": 50, "req": [],
		"desc": "Shield banks, grids and elections from hackers.", "fx": {"stability": 0.8}, "mil": 3.0},
	"drones2": {"branch": "Military", "title": "Drone swarms", "icon": "crosshair", "cost": 90, "req": ["automation"],
		"desc": "Thousands of cheap, coordinated drones.", "fx": {}, "mil": 6.0},
	"hypersonic": {"branch": "Military", "title": "Hypersonic missiles", "icon": "rocket", "cost": 180, "req": ["rockets"],
		"desc": "Too fast to intercept. A strong deterrent.", "fx": {}, "mil": 8.0},
	"laser_def": {"branch": "Military", "title": "Laser air defence", "icon": "zap", "cost": 200, "req": ["fusion"],
		"desc": "Shoot down drones and missiles for pennies.", "fx": {"stability": 0.5}, "mil": 7.0},
}


static func st() -> Dictionary:
	if not Game.dip.has("tech"):
		Game.dip["tech"] = {"done": [], "current": "", "progress": 0.0, "firsts": {}, "ai": {}}
	return Game.dip.tech


static func has(id: String) -> bool:
	return id in (st().done as Array)


static func can_research(id: String) -> bool:
	if has(id) or not ALL.has(id):
		return false
	for r in ALL[id].req:
		if not has(str(r)):
			return false
	return true


## Research points a month, with reasons: [[label, points], …].
static func income_terms(c: CountryState) -> Array:
	var out: Array = []
	out.append(["Research budget", E.RP_PER_RESEARCH * c.effort("research")])
	var labs := 0.0
	if not c.builds.is_empty():
		labs = (Builds.coverage_of(c, "university", float(Builds.count(c, "university")))
			+ Builds.coverage_of(c, "research_lab", float(Builds.count(c, "research_lab")))) * 0.5
	out.append(["Universities & labs", E.RP_LABS * labs])
	out.append(["Scale of the economy", E.RP_SCALE * clampf(log(maxf(c.gdp / 1e11, 0.1)) / log(10.0) + 1.0, 0.0, 3.0)])
	if c.idx == Game.player and Game.dip.has("space"):
		out.append(["Space outposts", Space.research()])
	if c.idx == Game.player and Game.dip.has("won"):
		out.append(["World wonders", float(Wonders.modifiers().get("rp", 0.0))])
	if c.idx == Game.player and Game.dip.has("edu"):
		out.append(["Top universities", Education.research()])
	if c.idx == Game.player and Game.dip.has("hlth") and Health.research() != 0.0:
		out.append(["Generic medicines", Health.research()])
	if Projects.is_done(c, "universities") and not bool(c.projects.get("universities", {}).get("start", false)):
		out.append(["Research universities", 1.0])
	if Projects.is_done(c, "tech_park"):
		out.append(["Technology park", 0.8])
	return out


static func income(c: CountryState) -> float:
	var s := 0.0
	for t in income_terms(c):
		s += float(t[1])
	return maxf(s, 0.5)


static func months_left(id: String) -> int:
	var cost := float(ALL[id].cost)
	var done := float(st().progress) if str(st().current) == id else 0.0
	return int(ceil((cost - done) / income(Game.me())))


static func choose(id: String) -> void:
	if not can_research(id):
		return
	var s := st()
	if str(s.current) != id:
		s.current = id
		s.progress = 0.0


## Monthly: research progresses; AI powers race through the space steps.
## Returns notices [{text, icon, good, first}].
static func monthly() -> Array:
	var out: Array = []
	var s := st()
	var c := Game.me()
	if str(s.current) != "":
		s.progress = float(s.progress) + income(c)
		var id := str(s.current)
		if float(s.progress) >= float(ALL[id].cost):
			(s.done as Array).append(id)
			s.current = ""
			s.progress = 0.0
			var t: Dictionary = ALL[id]
			var first := false
			if t.has("space") and int(t.space) >= 3 and not (s.firsts as Dictionary).has(id):
				s.firsts[id] = World.iso(Game.player)
				first = true
				c.shocks.approval = float(c.shocks.approval) + float(t.get("prestige", 1.0))
				for j in World.playable:
					if j != Game.player:
						Game.relations[j] = clampf(Game.relations[j] + float(t.get("prestige", 1.0)) * 0.4, -100.0, 100.0)
				Game.relations_changed.emit()
				if id == "moon":
					Achievements.unlock("moonshot")
			elif t.has("prestige"):
				c.shocks.approval = float(c.shocks.approval) + float(t.prestige) * 0.4
			if t.has("clean"):
				Corruption.boost(float(t.clean))
			var text := ("%s wins the new space race to: %s!" % [World.The_name(Game.player), str(t.title).to_lower()]) if first \
				else "Breakthrough: %s" % str(t.title).to_lower()
			Game.add_milestone(text, str(t.icon), "gold" if first else "accent")
			out.append({"text": text, "icon": str(t.icon), "good": true, "first": first, "id": id})
	_ai_space(out)
	return out


## Big economies race through the space steps; announce firsts.
static func _ai_space(out: Array) -> void:
	var s := st()
	var steps: Array = []
	for id in ALL:
		if ALL[id].has("space"):
			steps.append(id)
	steps.sort_custom(func(a: String, b: String) -> bool: return int(ALL[a].space) < int(ALL[b].space))
	for i in World.playable:
		if i == Game.player:
			continue
		var cs: CountryState = Game.state(i)
		if cs == null or cs.gdp < 4e11:
			continue
		var iso := World.iso(i)
		var pts := float(s.ai.get(iso, 0.0)) + E.RP_AI_SPACE * pow(cs.gdp / 1e12, 0.6) * Game.rng.randf_range(0.5, 1.5)
		s.ai[iso] = pts
		var total := 0.0
		for id in steps:
			total += float(ALL[id].cost)
			if pts >= total and not (s.firsts as Dictionary).has(id) and int(ALL[id].space) >= 3:
				s.firsts[id] = iso
				out.append({"text": "Space race: %s gets there first (%s)" % [World.The_name(i), str(ALL[id].title).to_lower()],
					"icon": str(ALL[id].icon), "good": false, "first": false, "id": id})


## Lasting target offsets for the player from researched technology.
static func modifiers() -> Dictionary:
	var out := {}
	if not Game.dip.has("tech"):
		return out
	for id in st().done:
		var t: Dictionary = ALL.get(str(id), {})
		for k in t.get("fx", {}):
			out[k] = float(out.get(k, 0.0)) + float(t.fx[k])
		for k in ["co2", "life", "mil"]:
			if t.has(k):
				out[k] = float(out.get(k, 0.0)) + float(t[k])
	return out
