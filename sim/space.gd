class_name Space
extends RefCounted
## Space colonies: what comes after the space race. Each outpost needs a
## technology, years of building and a yearly running cost, and gives back
## research, prestige (soft power, approval) and in time money.
##   Moon base        research and national pride
##   Orbital factory  space-made materials: a small industry
##   Mars colony      the great adventure: huge prestige, slow research
##   Asteroid mining  rare metals: once running, real income
## Colonies grow (population, output) the longer they run, and can suffer
## accidents. State: Game.dip.space {id: {start, done, pop}}. Constants in sim/economy.gd (SPACE_*).

const E = preload("res://sim/economy.gd")

## id -> {title, icon, tech, cost (% of GDP spread over the build), months, upkeep (% of GDP a year), rp, soft, income (% of GDP a year once grown)}
const OUTPOSTS := {
	"moon_base": {"title": "Moon base", "icon": "moon", "tech": "moon", "cost": 1.2, "months": 48, "upkeep": 0.08,
		"rp": 3.0, "soft": 5.0, "income": 0.0, "desc": "A permanent crewed base: labs, telescopes and national pride."},
	"orbital_factory": {"title": "Orbital factory", "icon": "satellite", "tech": "station", "cost": 0.8, "months": 36, "upkeep": 0.05,
		"rp": 1.0, "soft": 2.0, "income": 0.15, "desc": "Crystals, fibres and medicines made in zero gravity."},
	"mars_colony": {"title": "Mars colony", "icon": "rocket", "tech": "mars", "cost": 3.0, "months": 72, "upkeep": 0.2,
		"rp": 5.0, "soft": 12.0, "income": 0.0, "desc": "Humanity's first home on another world, under your flag."},
	"asteroid_mining": {"title": "Asteroid mining", "icon": "pickaxe", "tech": "mars", "cost": 2.0, "months": 60, "upkeep": 0.1,
		"rp": 1.0, "soft": 3.0, "income": 0.6, "desc": "Robot miners bring platinum and rare metals home."},
}


static func st() -> Dictionary:
	if not Game.dip.has("space"):
		Game.dip["space"] = {}
	return Game.dip.space


static func status(id: String) -> String:
	var o: Dictionary = st().get(id, {})
	if o.is_empty():
		return "none"
	return "done" if bool(o.get("done", false)) else "building"


static func blocked(id: String) -> String:
	var spec: Dictionary = OUTPOSTS[id]
	if status(id) != "none":
		return ""
	if not Tech.has(str(spec.tech)):
		return "Needs research: %s" % str(Tech.ALL[str(spec.tech)].title)
	var c := Game.me()
	if c.gdp < E.SPACE_MIN_GDP:
		return "Needs an economy above %s" % DS.money(E.SPACE_MIN_GDP)
	return ""


static func cost(id: String) -> float:
	return Game.me().gdp * float(OUTPOSTS[id].cost) / 100.0


static func start(id: String) -> bool:
	if blocked(id) != "" or status(id) != "none":
		return false
	st()[id] = {"start": Game.months_played, "done": false, "pop": 0.0, "price": cost(id)}
	Game.add_feed("Construction begins: %s" % str(OUTPOSTS[id].title).to_lower(), str(OUTPOSTS[id].icon), "accent")
	return true


static func progress(id: String) -> float:
	var o: Dictionary = st().get(id, {})
	if o.is_empty():
		return 0.0
	return clampf(float(Game.months_played - int(o.start)) / float(OUTPOSTS[id].months), 0.0, 1.0)


## Yearly spending, % of GDP: building cost spread over the build, then upkeep.
static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("space") or Game.me() == null:
		return 0.0
	var p := 0.0
	for id in st():
		var o: Dictionary = st()[id]
		var spec: Dictionary = OUTPOSTS[id]
		if bool(o.done):
			p += float(spec.upkeep)
		else:
			p += float(o.price) / maxf(Game.me().gdp, 1.0) * 100.0 / (float(spec.months) / 12.0)
	return p


## Research points a month from outposts.
static func research() -> float:
	var r := 0.0
	if not Game.dip.has("space"):
		return r
	for id in st():
		if bool(st()[id].done):
			r += float(OUTPOSTS[id].rp) * (0.5 + 0.5 * growth(id))
	return r


static func growth(id: String) -> float:
	return clampf(float(st().get(id, {}).get("pop", 0.0)) / 100.0, 0.0, 1.0)


static func prestige() -> float:
	var p := 0.0
	if not Game.dip.has("space"):
		return p
	for id in st():
		if bool(st()[id].done):
			p += float(OUTPOSTS[id].soft)
	return p


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or not Game.dip.has("space"):
		return out
	var c := Game.me()
	for id in st():
		var o: Dictionary = st()[id]
		var spec: Dictionary = OUTPOSTS[id]
		if not bool(o.done):
			if Game.months_played - int(o.start) >= int(spec.months):
				o.done = true
				c.shocks.approval = float(c.shocks.approval) + float(spec.soft) * 0.4
				c.shocks.happiness = float(c.shocks.happiness) + 2.0
				Game.add_milestone("Opened the %s" % str(spec.title).to_lower(), str(spec.icon), "gold")
				Achievements.unlock("spacefarer")
				out.append({"text": "%s opens: a new chapter in space for %s" % [str(spec.title), World.the_name(Game.player)],
					"icon": str(spec.icon), "good": true, "big": true, "celebrate": true})
		else:
			o.pop = minf(float(o.pop) + 100.0 / float(E.SPACE_GROW_MONTHS), 100.0)
			if Game.rng.randf() < E.SPACE_ACCIDENT:
				o.pop = maxf(float(o.pop) - 20.0, 0.0)
				c.shocks.approval = float(c.shocks.approval) - 2.0
				out.append({"text": "Accident at the %s: the crew is safe, but repairs set it back" % str(spec.title).to_lower(),
					"icon": str(spec.icon), "good": false, "big": false})
	return out


## Income (revenue, % of GDP) from grown outposts.
static func income_pct() -> float:
	var r := 0.0
	if not Game.has_game() or not Game.dip.has("space"):
		return r
	for id in st():
		if bool(st()[id].done):
			r += float(OUTPOSTS[id].income) * growth(str(id))
	return r
