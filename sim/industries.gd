class_name Industries
extends RefCounted
## Industries & trade. Your economy as eight sectors, each with a share of GDP
## (from real data: agriculture, manufacturing, tourism, fuel exports …) and a
## competitiveness score that drifts with what you do:
##   skills        education budget, schools and universities
##   technology    research done (AI, automation, chips …)
##   infrastructure  transport and energy coverage, blackouts
##   costs         wages (rich countries pay more), corruption
##   subsidies     you can back any sector (costs money, helps a lot, angers trade partners)
##   world demand  each sector has its own global cycle: boom, normal, slump
## A competitive sector grows its share; a struggling one shrinks. Their
## combined movement adds to (or drags on) growth and jobs, and booms and busts
## make headlines. Supply shocks (a chip shortage, a shipping crisis) hit the
## sectors that depend on them.
## State: Game.dip.ind {sec: {id: {share, share0, comp, sub}}, cycles: {id: x}, shock: {}}.
## Constants in sim/economy.gd (IND_*).

const E = preload("res://sim/economy.gd")

## id -> {title, icon, skill (how much skills matter), tech (research ids that help), infra, wage (sensitivity to wages), jobs (jobs per share)}
const SECTORS := {
	"farming": {"title": "Farming & food", "icon": "wheat", "skill": 0.2, "tech": ["automation"], "infra": "Transport", "wage": 0.6, "jobs": 2.0},
	"energy": {"title": "Energy & mining", "icon": "fuel", "skill": 0.3, "tech": ["smart_grid", "storage"], "infra": "Energy", "wage": 0.2, "jobs": 0.4},
	"factories": {"title": "Factories & cars", "icon": "factory", "skill": 0.5, "tech": ["automation", "ev_tech"], "infra": "Transport", "wage": 0.9, "jobs": 1.4},
	"tech": {"title": "Chips & electronics", "icon": "cpu", "skill": 1.0, "tech": ["ai", "quantum"], "infra": "Energy", "wage": 0.5, "jobs": 0.8},
	"pharma": {"title": "Medicine & biotech", "icon": "flask-conical", "skill": 1.0, "tech": ["mrna", "genomics"], "infra": "Health & care", "wage": 0.3, "jobs": 0.6},
	"finance": {"title": "Banking & finance", "icon": "landmark", "skill": 0.8, "tech": ["fintech", "egov"], "infra": "Economy", "wage": 0.2, "jobs": 0.6},
	"tourism": {"title": "Tourism & hotels", "icon": "plane-takeoff", "skill": 0.2, "tech": [], "infra": "Culture & sport", "wage": 0.7, "jobs": 1.8},
	"services": {"title": "Shops & services", "icon": "store", "skill": 0.4, "tech": ["egov"], "infra": "Housing & cities", "wage": 0.4, "jobs": 1.2},
}

const SHOCKS := [
	{"id": "chips", "text": "A global chip shortage halts car and electronics plants", "hits": {"factories": -0.25, "tech": -0.15}, "months": 8},
	{"id": "shipping", "text": "A shipping crisis jams the world's ports", "hits": {"factories": -0.15, "farming": -0.1, "services": -0.05}, "months": 6},
	{"id": "ai_boom", "text": "A worldwide AI boom: demand for chips and software soars", "hits": {"tech": 0.3, "finance": 0.1}, "months": 12},
	{"id": "travel", "text": "Cheap flights spark a world travel boom", "hits": {"tourism": 0.25}, "months": 12},
	{"id": "food", "text": "Droughts abroad lift world food prices: farmers cash in", "hits": {"farming": 0.2}, "months": 8},
	{"id": "bank", "text": "A banking scare rattles financial centres", "hits": {"finance": -0.25}, "months": 6},
]


static func st() -> Dictionary:
	if not Game.dip.has("ind"):
		Game.dip["ind"] = _fresh()
	return Game.dip.ind


static func _fresh() -> Dictionary:
	var i := Game.player
	var c := Game.me()
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	var agri := World.stat(i, "agriculture_pct", 10.0)
	var manu := World.stat(i, "manufacturing_pct", 15.0)
	var fuel := World.stat(i, "fuel_exports_pct", 5.0)
	var tour := World.stat(i, "tourism_pct", 5.0)
	var raw := {
		"farming": agri,
		"energy": clampf(fuel * World.stat(i, "trade_pct", 40.0) / 200.0, 0.5, 40.0),
		"factories": manu * 0.65,
		"tech": manu * 0.2 * (0.4 + lvl) + 1.5 * lvl,
		"pharma": manu * 0.1 + 2.0 * lvl,
		"finance": 3.0 + 6.0 * lvl,
		"tourism": clampf(tour * World.stat(i, "trade_pct", 40.0) / 100.0, 0.5, 25.0),
		"services": 0.0,
	}
	var tot := 0.0
	for k in raw:
		tot += float(raw[k])
	raw.services = maxf(100.0 - tot, 15.0)       # everything else
	tot += float(raw.services)
	var sec := {}
	var cyc := {}
	for k in SECTORS:
		var sh := float(raw[k]) / tot * 100.0
		sec[k] = {"share": sh, "share0": sh, "comp": 50.0, "sub": false}
		cyc[k] = 0.0
	return {"sec": sec, "cycles": cyc, "shock": {}, "last_news": {}}


static func share(id: String) -> float:
	return float(st().sec[id].share)


## Competitiveness drivers for a sector: [[label, points], …] (around 50 = average).
static func drivers(c: CountryState, id: String) -> Array:
	var spec: Dictionary = SECTORS[id]
	var t: Array = []
	var edu := c.share_delta("education") / 10.0
	if not c.builds.is_empty():
		edu += (Builds.gain(c, "school") + Builds.gain(c, "university")) * 2.0
	t.append(["Skills", E.IND_SKILL * float(spec.skill) * edu])
	var tech := 0.0
	for tid in spec.tech:
		if Tech.ALL.has(tid) and Tech.has(str(tid)):
			tech += 1.0
	t.append(["Technology", E.IND_TECH * tech])
	var infra := 0.0
	if not c.builds.is_empty():
		infra = Builds.group_coverage(c, str(spec.infra)) - 0.5
	t.append(["Infrastructure", E.IND_INFRA * infra])
	if Game.dip.has("energy") and Energy.shortage() > 0.0 and id in ["factories", "tech", "energy"]:
		t.append(["Power cuts", -E.IND_BLACKOUT])
	t.append(["Costs", -E.IND_WAGE * float(spec.wage) * (Economy.income_level(c.gdp_per_capita()) - 0.5)])
	t.append(["Clean government", E.IND_CLEAN * (Corruption.value(c) - 50.0) / 50.0])
	if bool(st().sec[id].sub):
		t.append(["Your subsidies", E.IND_SUBSIDY])
	t.append(["World demand", E.IND_CYCLE * float(st().cycles.get(id, 0.0))])
	var sh: Dictionary = st().shock
	if not sh.is_empty() and (sh.hits as Dictionary).has(id):
		t.append(["World shock", 100.0 * float(sh.hits[id])])
	if id == "tourism" and Game.dip.has("tour"):
		t.append(["Your appeal", 20.0 * (Tourism.appeal() - 1.0)])
	if War.at_war() and id in ["tourism", "finance"]:
		t.append(["War", -8.0])
	return t


static func competitiveness(c: CountryState, id: String) -> float:
	var v := 50.0
	for d in drivers(c, id):
		v += float(d[1])
	return clampf(v, 0.0, 100.0)


static func set_subsidy(id: String, on: bool) -> void:
	st().sec[id].sub = on


## Yearly subsidy bill, % of GDP.
static func subsidy_pct() -> float:
	if not Game.has_game() or not Game.dip.has("ind"):
		return 0.0
	var p := 0.0
	for id in st().sec:
		if bool(st().sec[id].sub):
			p += E.IND_SUBSIDY_COST * maxf(float(st().sec[id].share), 2.0) / 10.0
	return p


static func subsidy_count() -> int:
	var n := 0
	for id in st().sec:
		n += 1 if bool(st().sec[id].sub) else 0
	return n


## Monthly: world cycles drift, shocks come and go, shares move with competitiveness.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var s := st()
	var c := Game.me()
	for id in s.cycles:
		var x := float(s.cycles[id])
		s.cycles[id] = clampf(x * 0.96 + Game.rng.randfn(0.0, 0.08), -1.0, 1.0)
	# Shocks.
	var sh: Dictionary = s.shock
	if not sh.is_empty() and Game.months_played >= int(sh.until):
		s.shock = {}
	elif sh.is_empty() and Game.rng.randf() < E.IND_SHOCK_CHANCE:
		var pick: Dictionary = SHOCKS[Game.rng.randi() % SHOCKS.size()]
		s.shock = {"id": pick.id, "hits": pick.hits, "until": Game.months_played + int(pick.months), "text": pick.text}
		var good := false
		for k in pick.hits:
			if float(pick.hits[k]) > 0.0 and share(str(k)) > 3.0:
				good = true
		out.append({"text": str(pick.text), "icon": "globe", "good": good})
	# Heavy subsidies sour trade partners a little every month.
	if subsidy_count() >= 3:
		for j in World.playable:
			if j != Game.player and Diplomacy.has_deal(j):
				Game.relations[j] = clampf(Game.relations[j] - 0.05 * subsidy_count(), -100.0, 100.0)
	# Shares follow competitiveness (above 50 grows, below shrinks).
	var tot := 0.0
	for id in s.sec:
		var sec: Dictionary = s.sec[id]
		var comp := competitiveness(c, str(id))
		sec.comp = comp
		if not sec.has("comp0"):
			sec.comp0 = comp          # where it started: only changes since count toward growth
		var g := E.IND_SHARE_SPEED * (comp - 50.0) / 50.0
		sec.share = maxf(float(sec.share) * (1.0 + g / 12.0), 0.2)
		tot += float(sec.share)
	for id in s.sec:
		s.sec[id].share = float(s.sec[id].share) / tot * 100.0
	# Headlines when a big sector is booming or in trouble (at most every two years each).
	for id in s.sec:
		var sec2: Dictionary = s.sec[id]
		if float(sec2.share) < 4.0 or Game.months_played - int(s.last_news.get(id, -99)) < 24:
			continue
		var comp2 := float(sec2.comp)
		if comp2 >= 75.0 or comp2 <= 25.0:
			s.last_news[id] = Game.months_played
			out.append({"text": ("Boom times for %s: firms are hiring" if comp2 >= 75.0 else "%s in trouble: plants closing, jobs at risk")
				% str(SECTORS[id].title).to_lower().capitalize(), "icon": str(SECTORS[id].icon), "good": comp2 >= 75.0})
	return out


## Target offsets: growth from the sector mix, jobs from labour-heavy sectors, the subsidy bill, trade friction.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("ind") or Game.me() == null:
		return {}
	var g := 0.0
	var u := 0.0
	for id in st().sec:
		var sec: Dictionary = st().sec[id]
		var w := float(sec.share) / 100.0
		var dev := (float(sec.get("comp", 50.0)) - float(sec.get("comp0", sec.get("comp", 50.0)))) / 50.0
		g += E.IND_GROWTH * w * dev
		u -= E.IND_JOBS * w * dev * float(SECTORS[id].jobs)
	var out := {"growth": g, "unemployment": u, "cost": subsidy_pct()}
	if subsidy_count() >= 3:
		out["relations"] = -0.05 * subsidy_count()        # partners grumble about unfair aid
	return out


## Your biggest trading partners: [[index, score], …] (size x relations x closeness).
static func partners(n: int = 5) -> Array:
	var me := Game.player
	var list: Array = []
	for j in World.playable:
		if j == me:
			continue
		var c: CountryState = Game.state(j)
		if c == null:
			continue
		var score := pow(c.gdp / 1e9, 0.7) * clampf(1.0 + Game.relations[j] / 100.0, 0.1, 2.0)
		if j in World.neighbours_of(me):
			score *= 3.0
		if Diplomacy.has_deal(j):
			score *= 1.8
		if Diplomacy.sanctions_me(j) or Diplomacy.is_sanctioning(j):
			score *= 0.1
		list.append([j, score])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	return list.slice(0, n)
