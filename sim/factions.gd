class_name Factions
extends RefCounted
## Power brokers: the groups that can make or break a government, whatever the
## voters think. Each has a loyalty (0..100) that drifts toward what your
## policies give it:
##   army          military budget, wars won or lost, budget cuts
##   business      business tax, the stock market, privatisation, wealth taxes
##   unions        jobs, minimum wage, pay, privatisation
##   faith         religious leaders: tradition, rights, family policy
##   civil service how you treat officials: crackdowns, budget cuts, reform pace
## Court a faction (political capital and favours: loyalty up, a cost
## elsewhere) or, outside free democracies, crack down (loyalty forced up for a
## while, others grow wary). Loyal factions help: the army deters coups,
## business invests, unions keep the peace, the faithful rally, officials make
## laws pass faster. Angry ones push back: strikes, capital flight, sermons,
## obstruction and, for the army, plots.
## State: Game.dip.fac {id: {loyalty, favour_m}, plot_m}. Constants in sim/economy.gd (FAC_*).

const E = preload("res://sim/economy.gd")

const INFO := {
	"army": {"title": "The army", "icon": "shield", "court": "Promotions and new equipment", "help": "Deters coups and unrest", "hurt": "Plots against you"},
	"business": {"title": "Big business", "icon": "briefcase", "court": "Tax breaks and contracts", "help": "Invests: faster growth", "hurt": "Moves money abroad"},
	"unions": {"title": "Trade unions", "icon": "hammer", "court": "Pay deals and job guarantees", "help": "Industrial peace", "hurt": "Strikes"},
	"faith": {"title": "Religious leaders", "icon": "landmark", "court": "Funding for faith schools and charities", "help": "Calls for calm and unity", "hurt": "Sermons against you"},
	"civil": {"title": "Civil service", "icon": "folder", "court": "Better pay and job security", "help": "Laws pass faster", "hurt": "Quiet obstruction"},
}


static func st() -> Dictionary:
	if not Game.dip.has("fac"):
		var d := {"plot_m": -99}
		for id in INFO:
			d[id] = {"loyalty": 60.0, "favour_m": -99}
		Game.dip["fac"] = d
	return Game.dip.fac


static func loyalty(id: String) -> float:
	return float(st()[id].loyalty)


## What pulls each faction's loyalty: [[label, points], …] (around 60 = content).
static func terms(id: String) -> Array:
	var c := Game.me()
	var b: Dictionary = c.base
	var t: Array = []
	match id:
		"army":
			t.append(["Military budget", 25.0 * c.share_delta("military") / 10.0])
			var won := 0.0
			for k in War.wars():
				var w: Dictionary = War.wars()[k]
				won += float(w.occ_them) - float(w.occ_me)
			if War.at_war():
				t.append(["The war", 40.0 * won])
			t.append(["Military strength", 0.2 * (c.military - 50.0)])
		"business":
			t.append(["Business tax", -2.0 * (c.corp_tax - float(b.corp_tax))])
			if Game.dip.has("ent"):
				t.append(["Stock market", 10.0 * log(maxf(float(Enterprise.st().index), 1.0) / 100.0) / log(2.0)])
			if Laws.is_active(c, "wealth_tax") and not c.laws_start.has("wealth_tax"):
				t.append(["Wealth tax", -12.0])
			if Laws.is_active(c, "privatisation") and not c.laws_start.has("privatisation"):
				t.append(["Privatisation", 8.0])
			if Game.dip.has("hlth") and str(Health.st().drugs) != "market":
				t.append(["Drug price controls", -6.0 if str(Health.st().drugs) == "negotiate" else -10.0])
			t.append(["Growth", 3.0 * (c.growth - c.growth_anchor)])
		"unions":
			t.append(["Jobs", -4.0 * (c.unemployment - float(b.unemployment))])
			if Laws.is_active(c, "min_wage") and not c.laws_start.has("min_wage"):
				t.append(["Minimum wage", 12.0])
			if Laws.is_active(c, "privatisation") and not c.laws_start.has("privatisation"):
				t.append(["Privatisation", -10.0])
			t.append(["Prices", -1.5 * maxf(c.inflation - float(b.inflation), 0.0)])
			if Game.dip.has("auto"):
				t.append(["Robots replacing jobs", -3.0 * float(Automation.st().displaced)])
		"faith":
			if Game.dip.has("pop"):
				t.append(["Family policy", {"support": 5.0, "generous": 10.0}.get(str(Population.st().family), 0.0)])
			if Game.dip.has("black"):
				t.append(["Legal vice", -5.0 * float((Smuggling.st().legal as Dictionary).size())])
			if Game.dip.has("const") and Constitution.choice("rights") == "strong":
				t.append(["Strong rights", -4.0])
			t.append(["Happiness", 0.3 * (c.happiness - float(b.happiness))])
		"civil":
			t.append(["Budget", 15.0 * (c.spending_pct - float(b.spending_pct)) / 10.0])
			var drives: Array = Corruption._st().drives if Game.dip.has("clean") else []
			var recent := 0
			for m in drives:
				if Game.months_played - int(m) < 36:
					recent += 1
			t.append(["Corruption crackdowns", -8.0 * float(recent)])
			var passing := 0
			for k in c.laws:
				if str(c.laws[k].get("state", "")) in ["passing", "repealing"]:
					passing += 1
			t.append(["Pace of reform", -3.0 * maxf(float(passing) - 2.0, 0.0)])
	var fav := int(st()[id].favour_m)
	if Game.months_played - fav < E.FAC_FAVOUR_MONTHS:
		t.append(["Your favours", E.FAC_COURT * (1.0 - float(Game.months_played - fav) / float(E.FAC_FAVOUR_MONTHS))])
	return t


static func target(id: String) -> float:
	var v := 60.0
	for x in terms(id):
		v += float(x[1])
	return clampf(v, 0.0, 100.0)


static func court_wait(id: String) -> int:
	return maxi(0, int(st()[id].favour_m) + 12 - Game.months_played)


static func court(id: String) -> String:
	if court_wait(id) > 0 or not Capital.spend(E.FAC_COURT_CAPITAL):
		return ""
	var c := Game.me()
	st()[id].favour_m = Game.months_played
	match id:
		"army":
			c.treasury -= c.gdp * 0.05 / 100.0
		"business":
			c.treasury -= c.gdp * 0.08 / 100.0
			c.shocks.approval = float(c.shocks.approval) - 0.5
		"unions":
			c.shocks.inflation = float(c.shocks.inflation) + 0.3
		"faith":
			c.treasury -= c.gdp * 0.03 / 100.0
		"civil":
			c.treasury -= c.gdp * 0.06 / 100.0
	return "%s: %s" % [str(INFO[id].title), str(INFO[id].court).to_lower()]


static func can_purge() -> bool:
	return not Government.is_free(Game.player)


static func purge(id: String) -> String:
	if not can_purge() or not Capital.spend(E.FAC_PURGE_CAPITAL):
		return ""
	var s := st()
	s[id].loyalty = minf(float(s[id].loyalty) + 30.0, 95.0)
	for other in INFO:
		if other != id:
			s[other].loyalty = maxf(float(s[other].loyalty) - 6.0, 0.0)
	var c := Game.me()
	c.shocks.stability = float(c.shocks.stability) - 2.0
	Diplomacy.democracies_react(-2.0)
	return "Purge: disloyal %s are replaced with loyalists" % {"army": "generals", "business": "tycoons", "unions": "union bosses",
		"faith": "clerics", "civil": "officials"}[id]


## Monthly: loyalty drifts; angry factions act. Headlines [{text, icon, good}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var c := Game.me()
	for id in INFO:
		s[id].loyalty = loyalty(str(id)) + (target(str(id)) - loyalty(str(id))) * E.FAC_ADJUST
	# Trouble from the angriest faction, now and then.
	var worst := ""
	var low := 100.0
	for id in INFO:
		if loyalty(str(id)) < low:
			low = loyalty(str(id))
			worst = str(id)
	if low < E.FAC_ANGRY and Game.months_played - int(s.plot_m) > 18 and Game.rng.randf() < 0.12:
		s.plot_m = Game.months_played
		match worst:
			"army":
				if not Government.is_free(c.idx) or low < 15.0:
					c.shocks.stability = float(c.shocks.stability) - 6.0
					out.append({"text": "Plot uncovered: officers were planning to remove you. Loyal units stopped them", "icon": "shield", "good": false})
				else:
					c.shocks.approval = float(c.shocks.approval) - 2.0
					out.append({"text": "Retired generals publicly attack your defence policy", "icon": "shield", "good": false})
			"business":
				c.shocks.growth = float(c.shocks.growth) - 1.2
				out.append({"text": "Capital flight: big companies move money and jobs abroad", "icon": "briefcase", "good": false})
			"unions":
				c.shocks.growth = float(c.shocks.growth) - 0.8
				c.shocks.approval = float(c.shocks.approval) - 1.5
				out.append({"text": "General strike: trains, ports and factories stop for a week", "icon": "hammer", "good": false})
			"faith":
				c.shocks.approval = float(c.shocks.approval) - 2.5
				out.append({"text": "Religious leaders preach against your government from the pulpit", "icon": "landmark", "good": false})
			"civil":
				c.shocks.stability = float(c.shocks.stability) - 1.5
				out.append({"text": "Officials drag their feet: reforms stall in the ministries", "icon": "folder", "good": false})
	return out


## Target offsets from loyal (and disloyal) factions.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("fac"):
		return {}
	var d := func(id: String) -> float: return (loyalty(id) - 60.0) / 40.0      # -1.5 .. +1
	return {"stability": E.FAC_ARMY_STAB * d.call("army") + E.FAC_FAITH_STAB * d.call("faith"),
		"growth": E.FAC_BUSINESS_GROWTH * d.call("business"),
		"approval": E.FAC_FAITH_APPROVAL * d.call("faith"),
		"unemployment": -E.FAC_UNIONS_JOBS * d.call("unions")}


## How much faster laws pass (negative = slower) from the civil service.
static func law_speed() -> float:
	if not Game.has_game() or not Game.dip.has("fac"):
		return 0.0
	return clampf((loyalty("civil") - 60.0) / 40.0 * E.FAC_CIVIL_SPEED, -0.3, 0.2)


## Extra coup risk from an angry army (added in Politics.coup_risk).
static func coup_extra() -> float:
	if not Game.has_game() or not Game.dip.has("fac"):
		return 0.0
	return maxf(E.FAC_ANGRY - loyalty("army"), 0.0) * E.FAC_COUP_PER_POINT
