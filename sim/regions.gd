class_name Regions
extends RefCounted
## Regions & separatism. Your country is made of 3-5 home regions, each with its
## own share of the people, its own wealth (relative to the national average)
## and its own loyalty to the centre. The capital pulls ahead unless you invest
## elsewhere; poor, neglected regions and regions with their own identity drift
## away. A region whose loyalty stays very low for a year demands an
## independence referendum: let the people vote, offer autonomy, or refuse.
## Lose a vote and the region leaves, with its people and its share of the economy.
##   Development fund  three years of investment: the region catches up
##   Autonomy          its own parliament: much more loyal, costs a little each year
##   Crackdown         silences separatists for a while, but loyalty falls
## State: Game.dip.reg {list: [...], seceded}. Constants in sim/economy.gd (REG_*).

const E = preload("res://sim/economy.gd")

## Countries with a well-known region of its own identity (language, history).
const DISTINCT := ["ESP", "GBR", "CAN", "BEL", "IRQ", "TUR", "IND", "CHN", "RUS", "ETH", "NGA", "MMR", "PHL",
	"IDN", "SRB", "GEO", "MDA", "UKR", "AZE", "CMR", "SDN", "SOM", "LKA", "PAK", "MAR", "FRA", "ITA", "DNK",
	"PNG", "BIH", "CYP", "IRN", "SYR", "MLI", "SEN", "COD", "BOL", "AFG", "YEM", "LBY"]

const ECON := {
	"capital": {"text": "government and finance", "icon": "landmark"},
	"industry": {"text": "factories and ports", "icon": "factory"},
	"farming": {"text": "farms and small towns", "icon": "wheat"},
	"mining": {"text": "mines and energy", "icon": "pickaxe"},
	"tourism": {"text": "tourism and fishing", "icon": "tree-palm"},
	"tech": {"text": "universities and tech", "icon": "cpu"},
}


static func st() -> Dictionary:
	if not Game.dip.has("reg"):
		Game.dip["reg"] = _fresh()
	return Game.dip.reg


static func list() -> Array:
	return st().list


static func _fresh() -> Dictionary:
	var c := Game.me()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.player, "regions"])
	var pop := c.population if c != null else 1e7
	var n := 3 if pop < 5e6 else (4 if pop < 40e6 else 5)
	var names: Array = ["The North", "The South", "The East", "The West"]
	if not World.landlocked(Game.player):
		names[r.randi() % names.size()] = "The Coast"
	for k in range(names.size() - 1, 0, -1):
		var j := r.randi() % (k + 1)
		var tmp: String = names[k]
		names[k] = names[j]
		names[j] = tmp
	var econs: Array = ["industry", "farming", "mining", "tourism" if not World.landlocked(Game.player) else "farming", "tech"]
	var out: Array = []
	var cap_share := r.randf_range(0.18, 0.34)
	var gini := c.gini if c != null else 35.0
	out.append(_make("Capital region", "capital", cap_share, 1.15 + gini / 100.0 * 0.8, false))
	var weights: Array = []
	var wsum := 0.0
	for k in n - 1:
		var w := r.randf_range(0.6, 1.4)
		weights.append(w)
		wsum += w
	var iso := World.iso(Game.player)
	var distinct_at := r.randi() % (n - 1) if iso in DISTINCT or r.randf() < E.REG_DISTINCT_CHANCE else -1
	for k in n - 1:
		var e := str(econs[(k + r.randi() % 2) % econs.size()])
		if str(names[k]) == "The Coast":
			e = "tourism" if r.randf() < 0.5 else "industry"
		out.append(_make(str(names[k]), e, (1.0 - cap_share) * float(weights[k]) / wsum, r.randf_range(0.6, 1.05), k == distinct_at))
	_normalise(out)
	for g in out:
		g.loyalty = clampf(74.0 + 25.0 * (float(g.wealth) - 1.0) - (24.0 if bool(g.distinct) else 0.0) + r.randf_range(-5.0, 5.0), 22.0, 95.0)
	var res := {"list": out, "seceded": 0}
	res["base"] = _raw(out)
	return res


static func _make(name: String, econ: String, share: float, wealth: float, distinct: bool) -> Dictionary:
	return {"name": name, "econ": econ, "share": share, "wealth": wealth, "loyalty": 70.0, "distinct": distinct,
		"autonomy": false, "fund": -99, "crack": -99, "tension": 0, "cool": -99, "refused": 0, "lost": false}


## Keep wealth relative: the population-weighted average is 1.
static func _normalise(regs: Array) -> void:
	var tot := 0.0
	var sh := 0.0
	for g in regs:
		if not bool(g.lost):
			tot += float(g.share) * float(g.wealth)
			sh += float(g.share)
	if tot <= 0.0:
		return
	for g in regs:
		g.wealth = clampf(float(g.wealth) * sh / tot, 0.2, 3.0)


static func active() -> Array:
	var out: Array = []
	for g in list():
		if not bool(g.lost):
			out.append(g)
	return out


static func fund_active(g: Dictionary) -> bool:
	return Game.months_played - int(g.fund) < E.REG_FUND_MONTHS


static func funds_running() -> int:
	var n := 0
	for g in active():
		if fund_active(g):
			n += 1
	return n


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("reg"):
		return 0.0
	var p := 0.0
	for g in active():
		if fund_active(g):
			p += E.REG_FUND_COST
		if bool(g.autonomy):
			p += E.REG_AUTONOMY_COST
	return p


## Loyalty the region drifts towards.
static func target(g: Dictionary) -> float:
	var c := Game.me()
	var t := 70.0 + 25.0 * (float(g.wealth) - 1.0) + 0.25 * (c.approval - 50.0) + 0.1 * (c.stability - 60.0)
	if bool(g.distinct):
		t -= 24.0
	if bool(g.autonomy):
		t += E.REG_AUTONOMY_LOYALTY
	if fund_active(g):
		t += 8.0
	var since := Game.months_played - int(g.crack)
	if since < 36:
		t -= E.REG_CRACK_LOYALTY * (1.0 - since / 36.0)
	return clampf(t, 5.0, 98.0)


static func mood(g: Dictionary) -> String:
	var l := float(g.loyalty)
	if l >= 70.0:
		return "Loyal"
	if l >= 50.0:
		return "Content"
	if l >= 35.0:
		return "Restless"
	return "Separatist"


static func mood_color(g: Dictionary) -> Color:
	var l := float(g.loyalty)
	return DS.GREEN if l >= 70.0 else (DS.ACCENT if l >= 50.0 else (DS.ORANGE if l >= 35.0 else DS.RED))


## Expected "yes" share if a referendum were held now.
static func yes_share(g: Dictionary) -> float:
	return clampf(50.0 + (35.0 - float(g.loyalty)) * 0.9 + (4.0 if bool(g.distinct) else -6.0), 8.0, 92.0)


static func unity() -> float:
	var t := 0.0
	var sh := 0.0
	for g in active():
		t += float(g.share) * float(g.loyalty)
		sh += float(g.share)
	return t / maxf(sh, 0.0001)


# ------------------------------------------------------------------ actions ---
static func can_fund(g: Dictionary) -> bool:
	return not fund_active(g) and funds_running() < E.REG_FUND_MAX


static func fund(k: int) -> bool:
	var g: Dictionary = list()[k]
	if not can_fund(g):
		return false
	g.fund = Game.months_played
	Game.add_feed("A development fund for %s begins" % str(g.name).to_lower().trim_prefix("the "), "hand-coins", "accent")
	return true


static func grant_autonomy(k: int) -> bool:
	var g: Dictionary = list()[k]
	if bool(g.autonomy) or not Capital.spend(E.REG_AUTONOMY_CAPITAL):
		return false
	g.autonomy = true
	g.tension = 0
	g.loyalty = minf(float(g.loyalty) + 6.0, 100.0)
	Game.add_feed("%s gets its own parliament" % str(g.name), "landmark", "accent")
	return true


static func can_crack(g: Dictionary) -> bool:
	return Game.months_played - int(g.crack) >= 24 and (int(g.tension) > 0 or float(g.loyalty) < 40.0)


static func crack(k: int) -> bool:
	var g: Dictionary = list()[k]
	if not can_crack(g):
		return false
	var c := Game.me()
	g.crack = Game.months_played
	g.tension = 0
	g.cool = Game.months_played
	g.loyalty = maxf(float(g.loyalty) - 6.0, 0.0)
	c.shocks.approval = float(c.shocks.approval) - 2.0
	Press.apply_cred(-2.0)
	Game.add_feed("Police move against separatists in %s" % str(g.name).to_lower().trim_prefix("the "), "shield-alert", "orange")
	return true


# ---------------------------------------------------------------- referendum ---
## The inbox decision a separatist region forces on you.
static func demand_event(k: int) -> Dictionary:
	var g: Dictionary = list()[k]
	var y := roundi(yes_share(g))
	var choices: Array = [
		{"label": "Allow a referendum", "detail": "The people decide · polls: %d%% for leaving" % y,
			"effects": {"region": "vote:%d" % k}},
	]
	if not bool(g.autonomy):
		choices.append({"label": "Offer autonomy instead", "detail": "Own parliament · %d political capital" % int(E.REG_AUTONOMY_CAPITAL),
			"effects": {"region": "autonomy:%d" % k, "approval": -1.0}})
	choices.append({"label": "Refuse", "detail": "Protests and unrest · the demand will return",
		"effects": {"region": "refuse:%d" % k, "stability": -4.0, "approval": 1.0}})
	return {"id": "secession", "title": "%s wants to leave" % str(g.name), "icon": "flag", "tint": "red", "other": -1,
		"next": {}, "face": "", "scene_hint": "",
		"body": "Separatists have won the regional election in %s and demand an independence referendum. %d%% of the country's people live there." % [
			str(g.name).to_lower().trim_prefix("the ") if str(g.name).begins_with("The ") else str(g.name), roundi(float(g.share) * 100.0)],
		"choices": choices}


## How the cabinet scores a region choice (avoids gambling a region away).
static func score(v: String) -> float:
	var p := v.split(":")
	if p.size() >= 2 and p[1] == "weak":
		p[1] = str(weakest())
	if p.size() < 2 or int(p[1]) < 0 or int(p[1]) >= list().size():
		return 0.0
	var g: Dictionary = list()[int(p[1])]
	match p[0]:
		"fund":
			return 1.0
		"talk":
			return 0.8
		"crack":
			return -0.5
		"vote":
			return -yes_share(g) / 10.0 + 1.0
		"autonomy":
			return 2.0 if Capital.can(E.REG_AUTONOMY_CAPITAL) else -9.0
		"refuse":
			return -1.0
	return 0.0


## The most disloyal region outside the capital (-1 if none).
static func weakest() -> int:
	var best := -1
	for k in list().size():
		var g: Dictionary = list()[k]
		if bool(g.lost) or str(g.econ) == "capital":
			continue
		if best < 0 or float(g.loyalty) < float(list()[best].loyalty):
			best = k
	return best


static func apply(v: String) -> void:
	var p := v.split(":")
	if p.size() >= 2 and p[1] == "weak":
		p[1] = str(weakest())
	if p.size() < 2 or int(p[1]) < 0 or int(p[1]) >= list().size():
		return
	var k := int(p[1])
	var g: Dictionary = list()[k]
	var c := Game.me()
	match p[0]:
		"vote":
			var r := RandomNumberGenerator.new()
			r.seed = hash([Game.rng.seed, Game.months_played, "referendum", k])
			var yes := clampf(yes_share(g) + r.randf_range(-7.0, 7.0), 3.0, 97.0)
			if yes > 50.0:
				_secede(k, yes)
			else:
				g.loyalty = minf(float(g.loyalty) + 15.0, 100.0)
				g.cool = Game.months_played + 84    # settled for a generation
				g.tension = 0
				c.shocks.approval = float(c.shocks.approval) + 3.0
				c.shocks.stability = float(c.shocks.stability) + 3.0
				Game.add_milestone("%s voted to stay (%d%% to leave)" % [str(g.name), roundi(yes)], "flag", "green")
				Game.intel_news.emit({"text": "%s votes to stay: %d%% to %d%%" % [str(g.name), roundi(100.0 - yes), roundi(yes)],
					"icon": "flag", "good": true, "big": true})
		"fund":
			var gg: Dictionary = list()[k]
			if not fund_active(gg):
				gg.fund = Game.months_played
				Game.add_feed("A development fund for %s begins" % str(gg.name).to_lower().trim_prefix("the "), "hand-coins", "accent")
		"talk":
			g.loyalty = minf(float(g.loyalty) + 6.0, 100.0)
			g.tension = 0
		"crack":
			g.crack = Game.months_played
			g.tension = 0
			g.loyalty = maxf(float(g.loyalty) - 6.0, 0.0)
		"autonomy":
			if not grant_autonomy(k):
				p[0] = "refuse"
				apply("refuse:%d" % k)
		"refuse":
			g.refused = int(g.refused) + 1
			g.cool = Game.months_played
			g.tension = 0
			g.loyalty = maxf(float(g.loyalty) - 8.0, 0.0)
			# Refused again and again, a desperate region declares independence.
			if int(g.refused) >= 3 and float(g.loyalty) < 22.0:
				if c.military >= 60.0:
					c.shocks.stability = float(c.shocks.stability) - 8.0
					c.shocks.approval = float(c.shocks.approval) - 4.0
					for i in Game.relations.size():
						if i != Game.player:
							Game.relations[i] = clampf(Game.relations[i] - 3.0, -100.0, 100.0)
					Game.intel_news.emit({"text": "%s declares independence; the army holds it, but the world condemns the crackdown" % str(g.name),
						"icon": "shield-alert", "good": false, "big": true})
				else:
					_secede(k, 0.0)


static func _secede(k: int, yes: float) -> void:
	var g: Dictionary = list()[k]
	var c := Game.me()
	g.lost = true
	st().seceded = int(st().seceded) + 1
	var gdp_share := float(g.share) * float(g.wealth)
	c.population *= 1.0 - float(g.share)
	c.gdp *= 1.0 - gdp_share
	c.shocks.approval = float(c.shocks.approval) - 10.0
	c.shocks.stability = float(c.shocks.stability) - 5.0
	_normalise(list())
	var text := "%s leaves after %s" % [str(g.name), ("a %d%% yes vote" % roundi(yes)) if yes > 0.0 else "declaring independence"]
	Game.add_milestone(text, "flag", "red")
	Game.intel_news.emit({"text": "%s: you lose %d%% of your people and %d%% of the economy" % [text, roundi(float(g.share) * 100.0), roundi(gdp_share * 100.0)],
		"icon": "flag", "good": false, "big": true})


# ------------------------------------------------------------------- monthly ---
static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var regs := list()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "regions"])
	for g in regs:
		if bool(g.lost):
			continue
		# The capital pulls ahead; funded regions catch up.
		if str(g.econ) == "capital":
			g.wealth = float(g.wealth) + E.REG_CAPITAL_PULL
		if fund_active(g):
			g.wealth = float(g.wealth) + E.REG_FUND_WEALTH
		g.loyalty = clampf(float(g.loyalty) + (target(g) - float(g.loyalty)) * E.REG_LOYALTY_SPEED + r.randf_range(-0.4, 0.4), 0.0, 100.0)
		if float(g.loyalty) < 40.0:
			g["was_low"] = true
		if float(g.loyalty) < 35.0:
			g.tension = int(g.tension) + 1
		else:
			g.tension = maxi(int(g.tension) - 1, 0)
	_normalise(regs)
	var all_loyal := true
	var won_back := false
	for g in regs:
		if not bool(g.lost):
			all_loyal = all_loyal and float(g.loyalty) >= 70.0
			won_back = won_back or bool(g.get("was_low", false))
	if all_loyal and won_back:
		Achievements.unlock("one_nation")
	# One demand at a time.
	for ev in Game.director.inbox:
		if str(ev.get("id", "")) == "secession":
			return
	for k in regs.size():
		var g: Dictionary = regs[k]
		if bool(g.lost) or str(g.econ) == "capital":
			continue
		if int(g.tension) >= E.REG_TENSION_MONTHS and Game.months_played - int(g.cool) >= 24:
			g.tension = 0
			g.cool = Game.months_played
			Game.director.add(demand_event(k))
			Game.intel_news.emit({"text": "%s demands an independence referendum" % str(g.name), "icon": "flag", "good": false, "big": true})
			return


## Raw stability and happiness terms for a set of regions.
static func _raw(regs: Array) -> Dictionary:
	var stab := 0.0
	var lo := 9.0
	var hi := 0.0
	for g in regs:
		if bool(g.lost):
			continue
		stab += float(g.share) * (float(g.loyalty) - 65.0) / 35.0 * 2.5
		lo = minf(lo, float(g.wealth))
		hi = maxf(hi, float(g.wealth))
	return {"stability": stab, "happiness": -(hi - lo) * 3.0}


## Effects on the national targets: only what changed since you took office
## (the starting regional picture is already in the country's real numbers).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("reg"):
		return {}
	var now := _raw(list())
	var base: Dictionary = st().get("base", now)
	return {"stability": clampf(float(now.stability) - float(base.stability), -4.0, 2.0),
		"happiness": clampf(float(now.happiness) - float(base.happiness), -3.0, 1.5),
		"growth": E.REG_FUND_GROWTH * funds_running()}
