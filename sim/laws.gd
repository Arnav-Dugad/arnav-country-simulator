class_name Laws
extends RefCounted
## Laws & reforms. Each law shifts targets while active (per year, like the other
## effects in sim/economy.gd) and may cost or raise money (% of GDP per year).
## Laws a country already had at the start are part of its baseline, so only
## CHANGES from the starting set have an effect: repealing an existing law
## reverses its effects, enacting a new one applies them.
##
## Effect keys: growth, inflation, unemployment, happiness, approval, stability
## (target offsets) and cost / revenue (% of GDP per year). `politics` is a
## one-off approval shock when you start passing it (backlash or applause).

const GROUPS := ["Health & society", "Economy", "Environment", "Security & governance"]

const ALL := [
	{"id": "universal_health", "group": "Health & society", "icon": "stethoscope", "title": "Universal healthcare",
		"desc": "Everyone gets free basic care, paid for by the state.", "months": 12, "politics": 2.0,
		"fx": {"happiness": 6.0, "stability": 2.0, "approval": 1.5, "growth": -0.1, "cost": 2.0}},
	{"id": "free_university", "group": "Health & society", "icon": "graduation-cap", "title": "Free university",
		"desc": "No tuition fees at public universities.", "months": 9, "politics": 1.5,
		"fx": {"happiness": 2.5, "growth": 0.2, "unemployment": -0.2, "cost": 0.7}},
	{"id": "parental_leave", "group": "Health & society", "icon": "heart", "title": "Paid parental leave",
		"desc": "Six months of paid leave for new parents.", "months": 6, "politics": 1.0,
		"fx": {"happiness": 2.0, "approval": 1.0, "cost": 0.3}},
	{"id": "basic_income", "group": "Health & society", "icon": "hand-coins", "title": "Basic income pilot",
		"desc": "A small monthly payment to every adult, no strings attached.", "months": 12, "politics": 0.5,
		"fx": {"happiness": 4.0, "approval": 2.0, "unemployment": 0.3, "inflation": 0.4, "cost": 1.6}},
	{"id": "pension_age", "group": "Health & society", "icon": "users", "title": "Raise the pension age",
		"desc": "People retire two years later. Saves money, deeply unpopular.", "months": 9, "politics": -6.0,
		"fx": {"approval": -2.5, "happiness": -2.0, "unemployment": 0.1, "cost": -0.9}},
	{"id": "min_wage", "group": "Economy", "icon": "coins", "title": "Higher minimum wage",
		"desc": "Lifts pay for the lowest-paid workers.", "months": 6, "politics": 2.0,
		"fx": {"happiness": 2.0, "approval": 1.5, "unemployment": 0.4, "inflation": 0.2}},
	{"id": "wealth_tax", "group": "Economy", "icon": "landmark", "title": "Wealth tax",
		"desc": "A small yearly tax on the largest fortunes.", "months": 9, "politics": 1.0,
		"fx": {"revenue": 0.5, "growth": -0.15, "happiness": 1.0}},
	{"id": "privatisation", "group": "Economy", "icon": "building-2", "title": "Privatise state companies",
		"desc": "Sell government-run firms to private owners.", "months": 12, "politics": -3.0,
		"fx": {"growth": 0.3, "unemployment": 0.3, "happiness": -1.5, "cost": -0.3}},
	{"id": "skilled_visas", "group": "Economy", "icon": "plane-landing", "title": "Skilled-worker visas",
		"desc": "Points-based visas that bring in doctors, engineers and builders.", "months": 6, "politics": -0.5,
		"fx": {"growth": 0.1, "unemployment": 0.05}},
	{"id": "export_zones", "group": "Economy", "icon": "plane-takeoff", "title": "Special export zones",
		"desc": "Low-tax zones that attract foreign factories.", "months": 12, "politics": 0.0,
		"fx": {"growth": 0.4, "unemployment": -0.3, "revenue": -0.1, "stability": -0.5}},
	{"id": "carbon_tax", "group": "Environment", "icon": "flame", "title": "Carbon tax",
		"desc": "Polluters pay for every tonne of CO₂.", "months": 9, "politics": -1.5,
		"fx": {"revenue": 0.6, "growth": -0.15, "inflation": 0.2, "happiness": 1.0}},
	{"id": "coal_phaseout", "group": "Environment", "icon": "zap", "title": "Coal phase-out",
		"desc": "Close coal power plants within ten years.", "months": 12, "politics": 0.0,
		"fx": {"happiness": 2.0, "growth": -0.2, "unemployment": 0.2, "cost": 0.2}},
	{"id": "ev_subsidy", "group": "Environment", "icon": "sparkles", "title": "Electric-car subsidy",
		"desc": "Discounts for buying electric vehicles.", "months": 6, "politics": 1.0,
		"fx": {"happiness": 1.0, "growth": 0.1, "cost": 0.3}},
	{"id": "anti_corruption", "group": "Security & governance", "icon": "gavel", "title": "Anti-corruption agency",
		"desc": "An independent body that investigates officials.", "months": 9, "politics": 2.0,
		"fx": {"growth": 0.2, "approval": 2.0, "stability": 1.5, "cost": 0.05}},
	{"id": "press_freedom", "group": "Security & governance", "icon": "info", "title": "Press freedom guarantee",
		"desc": "Protects journalists from government pressure.", "months": 6, "politics": -1.0,
		"fx": {"happiness": 2.0, "stability": 1.0}},
	{"id": "border_control", "group": "Security & governance", "icon": "shield", "title": "Tougher border controls",
		"desc": "More guards and stricter entry rules.", "months": 6, "politics": 1.5,
		"fx": {"stability": 2.0, "approval": 1.0, "growth": -0.15, "cost": 0.15}},
	{"id": "police_reform", "group": "Security & governance", "icon": "users", "title": "Police reform",
		"desc": "Better training and independent oversight of police.", "months": 9, "politics": 0.5,
		"fx": {"stability": 2.0, "happiness": 1.5, "cost": 0.15}},
	# Only where elections aren't free (see Government). One way: it can't be repealed.
	{"id": "free_elections", "group": "Security & governance", "icon": "vote", "title": "Free elections",
		"desc": "Hold free, multi-party elections. You'll face the voters in a year.", "months": 18,
		"politics": 4.0, "gov": "closed", "oneway": true,
		"fx": {"happiness": 2.0, "approval": 2.0, "stability": -1.5, "growth": 0.1}},
]

## Title for the free-elections reform, by the system it replaces.
const REFORM_TITLES := {"one_party": "Allow multi-party elections", "monarchy": "Constitutional monarchy",
	"military": "Hand power to elected civilians", "transitional": "Hold national elections",
	"theocracy": "Open elections to all parties", "managed": "Free and fair elections"}

const FX_LABELS := {"growth": "Growth", "inflation": "Inflation", "unemployment": "Jobless",
	"happiness": "Happiness", "approval": "Approval", "stability": "Stability", "cost": "Cost", "revenue": "Revenue"}
## For each key: does a positive number help the player?
const FX_GOOD_UP := {"growth": true, "inflation": false, "unemployment": false, "happiness": true,
	"approval": true, "stability": true, "cost": false, "revenue": true}


## Is this law on offer in the player's country?
static func available(c: CountryState, l: Dictionary) -> bool:
	if str(l.get("gov", "")) == "closed":
		return is_active(c, l.id) or pending_months(c, l.id) > 0 or not Government.is_free(c.idx)
	return true


static func title_of(c: CountryState, l: Dictionary) -> String:
	if l.id == "free_elections":
		return str(REFORM_TITLES.get(Government.kind(c.idx), l.title))
	return str(l.title)


static func law(id: String) -> Dictionary:
	for l in ALL:
		if l.id == id:
			return l
	return {}


## Starting set from the country's income level and region (a simplification;
## flagged as estimated in data/SOURCES.md).
static func starting_set(c: CountryState) -> Dictionary:
	var lvl := Economy.income_level(c.gdp_per_capita())
	var iso := World.map.iso3[c.idx] if c.idx >= 0 else ""
	var europe := c.idx >= 0 and World.group_of(c.idx) == "Europe"
	var out := {}
	if lvl > 0.62 and iso != "USA":
		out["universal_health"] = true
	if lvl > 0.15:
		out["min_wage"] = true
	if lvl > 0.6 and europe:
		out["parental_leave"] = true
		out["carbon_tax"] = true
		out["free_university"] = lvl > 0.7
		out["press_freedom"] = true
		out["anti_corruption"] = true
	elif lvl > 0.75:
		out["press_freedom"] = true
		out["anti_corruption"] = true
	if lvl > 0.5 and lvl < 0.75:
		out["export_zones"] = true
	# Points-based or skilled-visa systems already run where rich countries draw migrants (Canada, Australia, Germany…).
	if c.idx >= 0 and lvl > 0.7 and World.stat(c.idx, "net_migration_rate", 0.0) > 3.0:
		out["skilled_visas"] = true
	for k in out.keys():
		if not out[k]:
			out.erase(k)
	return out


static func is_active(c: CountryState, id: String) -> bool:
	return c.laws.get(id, {}).get("state", "") == "active"


static func pending_months(c: CountryState, id: String) -> int:
	var l: Dictionary = c.laws.get(id, {})
	return int(l.get("months_left", 0)) if l.get("state", "") in ["passing", "repealing"] else 0


## Sum of effects relative to the starting set.
static func modifiers(c: CountryState) -> Dictionary:
	if c.lx_ver == c.laws_ver:
		return c.lx_cache
	var out := {}
	for l in ALL:
		var now := 1 if is_active(c, l.id) else 0
		var then := 1 if c.laws_start.has(l.id) else 0
		var d := now - then
		if d == 0:
			continue
		for k in l.fx:
			out[k] = float(out.get(k, 0.0)) + float(l.fx[k]) * d
	c.lx_cache = out
	c.lx_ver = c.laws_ver
	return out


## Starts passing (or repealing) a law. Returns months it will take.
static func start(c: CountryState, id: String) -> int:
	var l := law(id)
	if l.is_empty() or not available(c, l):
		return 0
	var repeal := is_active(c, id)
	if repeal and bool(l.get("oneway", false)):
		return 0
	var months := maxi(3, int(l.months * (0.5 if repeal else 1.0) * Profiles.mult(c.idx, "law_months")
		* (1.0 - (Cabinet.bonus("law_speed") if c.idx == Game.player else 0.0))
		* (1.0 - (Mandate.LAW_SPEED if c.idx == Game.player and Mandate.active() else 0.0))))
	c.laws[id] = {"state": "repealing" if repeal else "passing", "months_left": months}
	c.laws_ver += 1
	var pol := float(l.politics) * (-0.6 if repeal else 1.0)
	if c.idx == Game.player and Mandate.active() and pol < 0.0:
		pol *= Mandate.POLITICS_DISCOUNT     # honeymoon: voters forgive early reforms
	c.shocks.approval = float(c.shocks.approval) + pol
	return months


static func cancel(c: CountryState, id: String) -> void:
	var cur: Dictionary = c.laws.get(id, {})
	if cur.get("state", "") == "passing":
		c.laws.erase(id)
	elif cur.get("state", "") == "repealing":
		c.laws[id] = {"state": "active"}
	c.laws_ver += 1


## Advances pending laws by one month. Returns titles of laws that just finished.
static func monthly(c: CountryState) -> Array:
	var done: Array = []
	for id in c.laws.keys():
		var l: Dictionary = c.laws[id]
		var st := str(l.get("state", ""))
		if st != "passing" and st != "repealing":
			continue
		l.months_left = int(l.months_left) - 1
		if int(l.months_left) <= 0:
			if st == "passing":
				c.laws[id] = {"state": "active"}
				done.append({"id": id, "repealed": false})
			else:
				c.laws.erase(id)
				done.append({"id": id, "repealed": true})
	if not done.is_empty():
		c.laws_ver += 1
	return done
