class_name Tourism
extends RefCounted
## Tourism & soft power.
##   Tourism      starts from real data (international tourism receipts) and
##                moves with stability, war, heritage sites, culture builds,
##                world events you host and how the world feels about you.
##                Extra tourism adds growth and jobs.
##   Heritage     nominate places for the world heritage list (18 months; the
##                committee likes clean, well-run countries).
##   Mega events  bid for a World Expo, a Football World Cup or the Summer Games.
##                The vote comes a year later; winning means years of spending,
##                then a year in the spotlight: tourists, pride, prestige.
##   Soft power   0..100 for every country: economic weight, freedom, clean
##                government, tourism, and for you also heritage, hosting,
##                aid, alliances and wars. Higher soft power slowly warms the
##                world toward you. Ranked worldwide.
## State: Game.dip.tour {share0, share, sites: [{kind, name, year}], noms: [{kind, name, start}],
## bid: {ev, start}, host: {ev, year_m}, hosted: [ev], soft0}. Constants in sim/economy.gd (TOUR_*).

const E = preload("res://sim/economy.gd")

## Heritage kinds -> [title, icon, name templates]
const SITES := {
	"old_town": ["Old town", "landmark", ["The old town of %s", "Historic centre of %s"]],
	"park": ["National park", "trees", ["Highlands national park of %s", "The great forest of %s"]],
	"ruins": ["Ancient ruins", "castle", ["Ancient city of %s", "Royal ruins near %s"]],
	"coast": ["Coast & reefs", "waves", ["The coast and reefs of %s", "Islands off %s"]],
	"temple": ["Sacred sites", "sparkles", ["Sacred valley of %s", "Pilgrim route to %s"]],
	"modern": ["Modern landmark", "building-2", ["The new opera house of %s", "Garden city of %s"]],
}

## Mega events -> {title, icon, cost (% of GDP, spread over preparation), prep (months), boost, approval, soft, min_gdp}
const EVENTS := {
	"expo": {"title": "World Expo", "icon": "globe", "cost": 0.3, "prep": 36, "boost": 0.25, "approval": 2.0, "soft": 4.0, "min_gdp": 5.0e10},
	"cup": {"title": "Football World Cup", "icon": "trophy", "cost": 0.8, "prep": 48, "boost": 0.4, "approval": 4.0, "soft": 6.0, "min_gdp": 2.0e11},
	"games": {"title": "Summer Games", "icon": "medal", "cost": 1.4, "prep": 60, "boost": 0.5, "approval": 5.0, "soft": 9.0, "min_gdp": 4.0e11},
}


static func st() -> Dictionary:
	if not Game.dip.has("tour"):
		var s0 := start_share(Game.player)
		Game.dip["tour"] = {"share0": s0, "share": s0, "sites": [], "noms": [], "bid": {}, "host": {}, "hosted": [], "soft0": 0.0}
		Game.dip.tour.soft0 = soft_power(Game.player)
	return Game.dip.tour


## Tourism receipts as % of GDP at the start (receipts are reported as % of exports).
static func start_share(i: int) -> float:
	var t := World.stat(i, "tourism_pct", 5.0)
	var exports_pct := World.stat(i, "trade_pct", 50.0) * 0.5
	return clampf(t * exports_pct / 100.0, 0.1, 30.0)


static func share() -> float:
	return float(st().share)


## Visitors a year (millions): receipts / spending per visit (higher in rich places).
static func visitors() -> float:
	var c := Game.me()
	var per := 400.0 + 900.0 * Economy.income_level(c.gdp_per_capita())
	# Capped near the world's real total of trips (sandbox economies grow without limit).
	return minf(share() / 100.0 * c.gdp / per / 1e6, 2500.0)


## How appealing you are now (1 = as at the start).
static func appeal() -> float:
	var c := Game.me()
	var s := st()
	var a := 1.0
	a += E.TOUR_SITE * float((s.sites as Array).size())
	a += E.TOUR_STABILITY * (c.stability - float(c.base.get("stability", c.stability))) / 10.0
	if not c.builds.is_empty():
		var g := 0.0
		var ids := Builds.ids_in("Culture & sport")
		for id in ids:
			g += Builds.gain(c, str(id))
		a += E.TOUR_CULTURE * g / float(maxi(ids.size(), 1))
	if War.at_war():
		a -= E.TOUR_WAR
	if Game.dip.has("crime"):
		a -= 0.01 * Crime.change()
	if Game.dip.has("pandemic") and Pandemic.active():
		a -= 0.15 + (0.35 if bool(Pandemic.st().get("borders", false)) else 0.0)
	var host: Dictionary = s.host
	if not host.is_empty() and Game.months_played >= int(host.year_m) and Game.months_played < int(host.year_m) + 12:
		a += float(EVENTS[str(host.ev)].boost)
	a += E.TOUR_SOFT * (soft_power(Game.player) - float(s.soft0)) / 10.0
	var cp := Media.campaign() if Game.dip.has("media") else {}
	if not cp.is_empty() and str(cp.id) == "invest":
		a += 0.08
	return clampf(a, 0.3, 3.0)


# -------------------------------------------------------------- soft power ---
## Soft power 0..100. With details=true (player only) adds what you've done.
static func soft_power(i: int, details: bool = true) -> float:
	var c: CountryState = Game.state(i)
	if c == null:
		return 0.0
	var size := clampf(log(maxf(c.gdp, 1e9) / 1e9) / log(10.0) / 4.5, 0.0, 1.0)      # $1B .. $30T
	var voice := clampf((World.stat(i, "voice_wgi", 0.0) + 2.5) / 5.0, 0.0, 1.0)
	var tour := clampf(World.stat(i, "tourism_pct", 5.0) / 25.0, 0.0, 1.0)
	var clean := Corruption.value(c) / 100.0
	var sp := 40.0 * size + 25.0 * voice + 15.0 * tour + 20.0 * clean
	if details and i == Game.player and Game.dip.has("tour"):
		var s: Dictionary = Game.dip.tour
		sp += 2.0 * float((s.sites as Array).size())
		for ev in s.hosted:
			sp += float(EVENTS[str(ev)].soft)
		sp += 3.0 * (share() / maxf(float(s.share0), 0.1) - 1.0)
		sp += 0.5 * float(c.alliances) + 0.3 * float(c.trade_deals) - 1.5 * float(c.sanctioned_by)
		if War.at_war():
			sp -= 6.0
		if Game.dip.has("media"):
			sp -= 3.0 * float(Media.steps())
		if Game.dip.has("intel"):
			sp -= 2.0 * float(Intel.st().lost)
		if Game.dip.has("tech"):
			sp += 4.0 * float((Tech.st().firsts as Dictionary).values().count(World.map.iso3[Game.player]))
		if Game.dip.has("sport"):
			sp += Sports.prestige()
		if Game.dip.has("un"):
			sp += UnitedNations.prestige()
	return clampf(sp, 0.0, 100.0)


## Your rank among playable countries (1 = top). Cached per month.
static func rank() -> int:
	var key := Game.months_played
	var s := st()
	if int(s.get("rank_m", -1)) == key:
		return int(s.rank)
	var mine := soft_power(Game.player)
	var r := 1
	for j in World.playable:
		if j != Game.player and soft_power(j, false) > mine:
			r += 1
	s.rank = r
	s.rank_m = key
	return r


# ---------------------------------------------------------------- heritage ---
static func nominate_cost() -> float:
	return Game.me().gdp * E.TOUR_NOMINATE_COST / 100.0


static func nominated(kind: String) -> bool:
	for n in st().noms:
		if str(n.kind) == kind:
			return true
	return false


static func can_nominate(kind: String) -> String:
	if nominated(kind):
		return "Under review"
	var count := 0
	for s in st().sites:
		count += 1 if str(s.kind) == kind else 0
	if count >= 2:
		return "Two sites of this kind already listed"
	if (st().noms as Array).size() >= 2:
		return "Two nominations at a time"
	return ""


static func nominate(kind: String) -> bool:
	if can_nominate(kind) != "":
		return false
	var names: Array = SITES[kind][2]
	var place := World.map.names[Game.player]
	if kind == "old_town" or kind == "modern":
		if Game.player < World.map.capital_name.size() and str(World.map.capital_name[Game.player]) != "":
			place = str(World.map.capital_name[Game.player])
	var nm := str(names[Game.rng.randi() % names.size()]) % place
	Game.me().treasury -= nominate_cost()
	(st().noms as Array).append({"kind": kind, "name": nm, "start": Game.months_played})
	return true


static func nomination_chance() -> float:
	return clampf(0.45 + Corruption.value(Game.me()) / 250.0 + (0.1 if not War.at_war() else -0.2), 0.15, 0.9)


# ------------------------------------------------------------- mega events ---
static func can_bid(ev: String) -> String:
	var s := st()
	if not (s.bid as Dictionary).is_empty():
		return "A bid is already in"
	if not (s.host as Dictionary).is_empty():
		return "You're already hosting the %s" % str(EVENTS[str(s.host.ev)].title)
	if Game.me().gdp < float(EVENTS[ev].min_gdp):
		return "Needs an economy above %s" % DS.money(float(EVENTS[ev].min_gdp))
	if War.at_war():
		return "Not while at war"
	return ""


static func bid_cost(ev: String) -> float:
	return Game.me().gdp * float(EVENTS[ev].cost) * 0.02 / 100.0


## Chance of winning the vote: soft power, stability, peace.
static func bid_chance(ev: String) -> float:
	var c := Game.me()
	var sp := soft_power(Game.player)
	var p := 0.15 + sp / 140.0 + (c.stability - 50.0) / 250.0
	if ev == "games":
		p -= 0.1
	return clampf(p, 0.05, 0.85)


static func place_bid(ev: String) -> bool:
	if can_bid(ev) != "":
		return false
	Game.me().treasury -= bid_cost(ev)
	st().bid = {"ev": ev, "start": Game.months_played, "p": bid_chance(ev)}
	return true


## Preparation spending, % of GDP a year (while preparing a won event).
static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("tour"):
		return 0.0
	var h: Dictionary = st().host
	if h.is_empty() or Game.months_played >= int(h.year_m):
		return 0.0
	var ev: Dictionary = EVENTS[str(h.ev)]
	return float(ev.cost) / (float(ev.prep) / 12.0)


# ----------------------------------------------------------------- monthly ---
## Returns headlines [{text, icon, good, big, celebrate}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var s := st()
	var c := Game.me()
	# Tourism drifts toward its target.
	var target := float(s.share0) * appeal()
	s.share = float(s.share) + (target - float(s.share)) * E.TOUR_ADJUST
	# Heritage decisions.
	var keep: Array = []
	for n in s.noms:
		if Game.months_played - int(n.start) < E.TOUR_NOMINATE_MONTHS:
			keep.append(n)
			continue
		if Game.rng.randf() < nomination_chance():
			(s.sites as Array).append({"kind": n.kind, "name": n.name, "year": Game.year})
			c.shocks.approval = float(c.shocks.approval) + 1.0
			out.append({"text": "World heritage: %s is listed" % str(n.name), "icon": str(SITES[str(n.kind)][1]), "good": true, "big": true})
			Game.add_milestone("World heritage site: %s" % str(n.name), str(SITES[str(n.kind)][1]), "gold")
		else:
			out.append({"text": "Heritage committee turns down %s, for now" % str(n.name), "icon": "x", "good": false, "big": false})
	s.noms = keep
	# The vote on your bid.
	var bid: Dictionary = s.bid
	if not bid.is_empty() and Game.months_played - int(bid.start) >= E.TOUR_BID_MONTHS:
		var ev := str(bid.ev)
		s.bid = {}
		if Game.rng.randf() < float(bid.p):
			s.host = {"ev": ev, "year_m": Game.months_played + int(EVENTS[ev].prep)}
			c.shocks.approval = float(c.shocks.approval) + 2.0
			c.shocks.happiness = float(c.shocks.happiness) + 2.0
			out.append({"text": "You won the vote: %s will host the %s!" % [World.the_name(Game.player), str(EVENTS[ev].title)],
				"icon": str(EVENTS[ev].icon), "good": true, "big": true, "celebrate": true})
			Game.add_milestone("Won the bid for the %s" % str(EVENTS[ev].title), str(EVENTS[ev].icon), "gold")
		else:
			var winner: int = World.playable[Game.rng.randi() % World.playable.size()]
			out.append({"text": "The %s goes to %s. Your bid falls short" % [str(EVENTS[ev].title), World.the_name(winner)],
				"icon": str(EVENTS[ev].icon), "good": false, "big": true})
	# Hosting: the big year.
	var host: Dictionary = s.host
	if not host.is_empty():
		if Game.months_played == int(host.year_m):
			var e2: Dictionary = EVENTS[str(host.ev)]
			c.shocks.approval = float(c.shocks.approval) + float(e2.approval)
			c.shocks.happiness = float(c.shocks.happiness) + 3.0
			(s.hosted as Array).append(str(host.ev))
			out.append({"text": "The %s opens in %s. The world is watching" % [str(e2.title), World.the_name(Game.player)],
				"icon": str(e2.icon), "good": true, "big": true, "celebrate": true})
			Game.add_milestone("Hosted the %s" % str(e2.title), str(e2.icon), "gold")
		elif Game.months_played >= int(host.year_m) + 12:
			s.host = {}
	# Soft power warms the world toward you, a little each month.
	var d := soft_power(Game.player) - float(s.soft0)
	if absf(d) >= 1.0:
		var nudge := clampf(d * E.TOUR_SOFT_RELATIONS, -0.3, 0.3)
		for j in World.playable:
			if j != Game.player:
				Game.relations[j] = clampf(Game.relations[j] + nudge, -100.0, 100.0)
	return out


## Target offsets from extra (or lost) tourism.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("tour"):
		return {}
	var d := share() - float(st().share0)
	if absf(d) < 0.01:
		return {}
	return {"growth": E.TOUR_GROWTH * d, "unemployment": -E.TOUR_JOBS * d}
