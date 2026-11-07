class_name GameEvents
extends RefCounted
## Random events. Each has a condition, a weight, and 2–3 choices with real
## tradeoffs. Effects (applied by apply_effects):
##   growth / inflation / unemployment / happiness / approval / stability:
##       half applied immediately, full value as a decaying shock (see Economy.SHOCK_DECAY)
##   cost:      one-off spend, % of GDP (taken from the treasury)
##   gdp:       permanent change to GDP level, %
##   rate:      change to the interest rate, pts
##   corp_tax / income_tax / spending: policy changes, pts
##   share_research / share_health …: budget share change, pts
##   relation:  change in relations with the event's other country
##   deal / sanction_me: diplomacy outcomes with the other country

## Chance per month that a random event fires (if none is pending).
const MONTHLY_CHANCE := 0.16
const MIN_GAP_MONTHS := 3

const EVENTS := [
	{"id": "recession", "title": "Global slowdown", "icon": "trending-down", "tint": "orange", "weight": 3.0,
		"body": "Demand is falling across the world and {country}'s exporters are cutting jobs. Economists warn of a recession.",
		"choices": [
			{"label": "Stimulus package", "detail": "Costs 2% of GDP · supports growth and jobs",
				"effects": {"cost": 2.0, "growth": 1.6, "unemployment": -0.8, "approval": 2.0, "inflation": 0.6}},
			{"label": "Cut interest rates", "detail": "Rate −1 pt · cheaper money, some inflation",
				"effects": {"rate": -1.0, "growth": 0.8, "inflation": 0.8}},
			{"label": "Ride it out", "detail": "No cost · growth and jobs suffer",
				"effects": {"growth": -1.8, "unemployment": 1.2, "approval": -3.0}}]},
	{"id": "floods", "title": "Severe floods", "icon": "cloud", "tint": "teal", "weight": 2.0,
		"body": "Days of rain have flooded towns and farmland across {country}. Thousands are displaced.",
		"choices": [
			{"label": "Full relief effort", "detail": "Costs 0.8% of GDP · people feel protected",
				"effects": {"cost": 0.8, "happiness": 2.0, "approval": 4.0, "growth": -0.3}},
			{"label": "Limited aid", "detail": "Costs 0.2% of GDP · resentment grows",
				"effects": {"cost": 0.2, "happiness": -3.0, "approval": -4.0, "growth": -0.6}},
			{"label": "Ask allies for help", "detail": "Needs an ally · small cost, some pride lost",
				"needs": "ally", "effects": {"cost": 0.25, "approval": 1.0, "stability": -1.0, "growth": -0.4}}]},
	{"id": "tech_boom", "title": "Tech boom", "icon": "zap", "tint": "accent", "weight": 1.6,
		"body": "Start-ups in {country} are attracting record investment. Valuations are soaring.",
		"choices": [
			{"label": "Tax the windfall", "detail": "Corporate tax +2 pts · more revenue, slower boom",
				"effects": {"corp_tax": 2.0, "growth": 0.4, "approval": 1.0}},
			{"label": "Let it run", "detail": "Growth now · prices heat up",
				"effects": {"growth": 1.6, "inflation": 0.9, "happiness": 1.0}},
			{"label": "Fund research", "detail": "Research share +2 pts · lasting growth",
				"effects": {"share_research": 2.0, "growth": 0.8, "cost": 0.1}}]},
	{"id": "protests", "title": "Cost-of-living protests", "icon": "users", "tint": "red", "weight": 2.5,
		"cond": "unhappy",
		"body": "Crowds fill the streets of {country}'s cities, angry about prices and wages.",
		"choices": [
			{"label": "Offer concessions", "detail": "Costs 0.5% of GDP · calms the streets",
				"effects": {"cost": 0.5, "approval": 4.0, "stability": 4.0, "happiness": 2.0}},
			{"label": "Open talks", "detail": "No cost · slow to cool down",
				"effects": {"approval": 1.0, "stability": -2.0}},
			{"label": "Crack down", "detail": "Order restored · deep resentment, allies object",
				"effects": {"stability": 3.0, "approval": -7.0, "happiness": -4.0, "relations_all": -3.0}}]},
	{"id": "scandal", "title": "Corruption scandal", "icon": "gavel", "tint": "orange", "weight": 2.0,
		"body": "Leaked documents show a senior minister steering contracts to friends.",
		"choices": [
			{"label": "Fire the minister", "detail": "Short-term hit · shows integrity",
				"effects": {"approval": -1.5, "stability": 1.0}},
			{"label": "Independent inquiry", "detail": "Small cost · trust slowly returns",
				"effects": {"cost": 0.02, "approval": -0.5, "happiness": 1.0}},
			{"label": "Stand by them", "detail": "Loyalty kept · public trust falls",
				"effects": {"approval": -6.0, "stability": -2.0}}]},
	{"id": "pandemic", "title": "New virus spreading", "icon": "activity", "tint": "red", "weight": 0.6,
		"body": "A fast-spreading respiratory virus has reached {country}. Hospitals are filling.",
		"choices": [
			{"label": "Lockdown", "detail": "Saves lives · economy stalls",
				"effects": {"growth": -3.5, "unemployment": 2.2, "happiness": -3.0, "approval": 3.0}},
			{"label": "Targeted measures", "detail": "Balanced · some strain on hospitals",
				"effects": {"growth": -1.2, "happiness": -2.0, "approval": -1.0}},
			{"label": "Mass vaccination drive", "detail": "Costs 1% of GDP · fastest recovery",
				"effects": {"cost": 1.0, "growth": -0.6, "approval": 3.0, "share_health": 1.5}}]},
	{"id": "oil_shock", "title": "Oil price spike", "icon": "flame", "tint": "orange", "weight": 1.8,
		"body": "Conflict abroad has sent oil prices soaring. Fuel and food costs in {country} are climbing.",
		"choices": [
			{"label": "Subsidise fuel", "detail": "Costs 0.6% of GDP · keeps prices down",
				"effects": {"cost": 0.6, "inflation": 0.6, "approval": 2.0}},
			{"label": "Let prices rise", "detail": "No cost · inflation and anger",
				"effects": {"inflation": 2.4, "approval": -3.0, "happiness": -2.0}},
			{"label": "Raise rates", "detail": "Rate +1 pt · cools prices, slows growth",
				"effects": {"rate": 1.0, "inflation": 1.0, "growth": -0.6}}]},
	{"id": "strike", "title": "General strike", "icon": "construction", "tint": "orange", "weight": 1.5,
		"body": "Unions in {country} have called a nationwide strike over pay.",
		"choices": [
			{"label": "Raise wages", "detail": "Costs 0.3% of GDP · prices tick up",
				"effects": {"cost": 0.3, "inflation": 0.9, "approval": 2.0, "happiness": 1.5}},
			{"label": "Hold firm", "detail": "No cost · lost output and tension",
				"effects": {"growth": -0.9, "approval": -2.0, "stability": -2.0}}]},
	{"id": "resources", "title": "Major resource discovery", "icon": "sparkles", "tint": "gold", "weight": 0.7,
		"body": "Geologists have confirmed large mineral deposits in {country}'s interior.",
		"choices": [
			{"label": "State-owned mining", "detail": "GDP +1.5% · revenue for the treasury",
				"effects": {"gdp": 1.5, "approval": 2.0, "cost": -0.4}},
			{"label": "License private firms", "detail": "GDP +2.5% · faster growth, less control",
				"effects": {"gdp": 2.5, "growth": 0.6, "happiness": -0.5}},
			{"label": "Protect the land", "detail": "No gain · environmental goodwill",
				"effects": {"happiness": 2.0, "approval": 1.0}}]},
	{"id": "investment", "title": "Foreign investment offer", "icon": "building-2", "tint": "accent", "weight": 1.4,
		"body": "A global manufacturer wants to build a large factory in {country}, asking for tax breaks.",
		"choices": [
			{"label": "Offer tax breaks", "detail": "Corporate tax −1 pt · jobs and growth",
				"effects": {"corp_tax": -1.0, "growth": 0.9, "unemployment": -0.6}},
			{"label": "Decline", "detail": "No change",
				"effects": {}}]},
	{"id": "sports", "title": "Sporting triumph", "icon": "crown", "tint": "gold", "weight": 1.0,
		"body": "{country}'s national team has won a major international tournament. The country is celebrating.",
		"choices": [
			{"label": "Declare a holiday", "detail": "Small output cost · national pride",
				"effects": {"happiness": 3.0, "approval": 3.0, "growth": -0.2}},
			{"label": "Invest in youth sport", "detail": "Costs 0.05% of GDP · lasting goodwill",
				"effects": {"cost": 0.05, "happiness": 2.0, "approval": 1.5}}]},
	{"id": "cyberattack", "title": "Cyberattack", "icon": "lock", "tint": "red", "weight": 1.0,
		"body": "Hackers have disrupted banks and hospitals across {country}.",
		"choices": [
			{"label": "Build cyber defences", "detail": "Costs 0.2% of GDP · security up",
				"effects": {"cost": 0.2, "stability": 2.0, "approval": 1.0}},
			{"label": "Quiet clean-up", "detail": "No cost · risk of more attacks",
				"effects": {"stability": -2.0, "growth": -0.3}}]},
	{"id": "refugees", "title": "Refugees at the border", "icon": "users", "tint": "teal", "weight": 1.0,
		"body": "Thousands fleeing conflict nearby are seeking shelter in {country}.",
		"choices": [
			{"label": "Welcome them", "detail": "Costs 0.2% of GDP · praised abroad",
				"effects": {"cost": 0.2, "relations_all": 2.0, "approval": -1.5, "gdp": 0.2}},
			{"label": "Close the border", "detail": "Popular at home · criticised abroad",
				"effects": {"approval": 1.5, "relations_all": -2.0, "stability": 1.0}}]},
	{"id": "trade_offer", "title": "Trade deal offer", "icon": "handshake", "tint": "green", "weight": 1.6,
		"cond": "friend_without_deal",
		"body": "{other} proposes a free-trade agreement with {country}.",
		"choices": [
			{"label": "Sign the deal", "detail": "Growth up · some local industries object",
				"effects": {"deal": true, "relation": 6.0, "approval": -0.5}},
			{"label": "Decline politely", "detail": "Relations cool slightly",
				"effects": {"relation": -5.0}}]},
	{"id": "sanction_threat", "title": "Sanctions threatened", "icon": "ban", "tint": "red", "weight": 1.4,
		"cond": "hostile",
		"body": "{other} threatens to impose sanctions on {country} unless you change course.",
		"choices": [
			{"label": "Make concessions", "detail": "Relations improve · looks weak at home",
				"effects": {"relation": 15.0, "approval": -3.0}},
			{"label": "Stand firm", "detail": "They sanction you · a rally at home",
				"effects": {"sanction_me": true, "relation": -10.0, "approval": 2.5}}]},
	{"id": "debt_crisis", "title": "Bond markets panic", "icon": "alert", "tint": "red", "weight": 0.0,
		"body": "Investors are dumping {country}'s government bonds. Borrowing costs are spiking.",
		"choices": [
			{"label": "IMF programme", "detail": "Spending −3 pts · stability returns",
				"effects": {"spending": -3.0, "approval": -6.0, "growth": -1.0, "stability": 2.0, "debt_rate": -2.0}},
			{"label": "Austerity budget", "detail": "Spending −2, income tax +2 · deeply unpopular",
				"effects": {"spending": -2.0, "income_tax": 2.0, "approval": -8.0, "growth": -0.8}},
			{"label": "Print money", "detail": "Inflation erodes the debt · prices explode",
				"effects": {"inflation": 9.0, "debt_gdp": -8.0, "approval": -4.0, "stability": -4.0}}]},
]


static func tint(name: String) -> Color:
	return {"orange": DS.ORANGE, "teal": DS.TEAL, "accent": DS.ACCENT, "red": DS.RED, "gold": DS.GOLD,
		"green": DS.GREEN}.get(name, DS.ACCENT)


static func by_id(id: String) -> Dictionary:
	for e in EVENTS:
		if e.id == id:
			return e
	return {}


## Picks a random eligible event (or {} if none). Returns an instance with the
## "other" country resolved and the text filled in.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var me := Game.me()
	var pool: Array = []
	var weights: Array[float] = []
	for e in EVENTS:
		var w := float(e.weight)
		if w <= 0.0:
			continue
		var other := -1
		match e.get("cond", ""):
			"unhappy":
				if me.approval > 45.0 and me.inflation < float(me.base.inflation) + 3.0:
					w *= 0.2
			"friend_without_deal":
				other = _pick_country(rng, func(i: int) -> bool:
					return Game.relations[i] >= 35.0 and not Diplomacy.has_deal(i) and not Diplomacy.is_sanctioning(i))
				if other < 0:
					continue
			"hostile":
				other = _pick_country(rng, func(i: int) -> bool:
					return Game.relations[i] <= -50.0 and not Diplomacy.sanctions_me(i))
				if other < 0:
					continue
		pool.append([e, other])
		weights.append(w)
	if pool.is_empty():
		return {}
	var total := 0.0
	for w in weights:
		total += w
	var pick := rng.randf() * total
	for k in pool.size():
		pick -= weights[k]
		if pick <= 0.0:
			return instance(pool[k][0], pool[k][1])
	return instance(pool[0][0], pool[0][1])


static func instance(e: Dictionary, other: int = -1) -> Dictionary:
	var name := World.map.names[Game.player]
	var other_name := World.map.names[other] if other >= 0 else ""
	var choices: Array = []
	for ch in e.choices:
		if ch.get("needs", "") == "ally" and Diplomacy.summary().alliances == 0:
			continue
		choices.append(ch)
	return {"id": e.id, "title": e.title, "icon": e.icon, "tint": e.tint, "other": other,
		"body": String(e.body).format({"country": name, "other": other_name}), "choices": choices}


static func _pick_country(rng: RandomNumberGenerator, ok: Callable) -> int:
	var cands: Array[int] = []
	for i in World.playable:
		if i != Game.player and ok.call(i):
			cands.append(i)
	return cands[rng.randi() % cands.size()] if not cands.is_empty() else -1


static func apply_effects(fx: Dictionary, other: int) -> void:
	var c := Game.me()
	for k in fx:
		var v: Variant = fx[k]
		match k:
			"growth", "inflation", "unemployment", "happiness", "approval", "stability":
				c.set(k, float(c.get(k)) + float(v) * 0.5)
				c.shocks[k] = float(c.shocks[k]) + float(v)
			"cost":
				c.treasury -= c.gdp * float(v) / 100.0
			"gdp":
				c.gdp *= 1.0 + float(v) / 100.0
			"rate":
				c.interest_rate = clampf(c.interest_rate + float(v), Economy.RATE_MIN, Economy.RATE_MAX)
			"corp_tax", "income_tax":
				c.set(k, clampf(float(c.get(k)) + float(v), 0.0, 60.0))
			"spending":
				c.spending_pct = clampf(c.spending_pct + float(v), 8.0, 60.0)
			"debt_rate":
				c.debt_rate = maxf(c.debt_rate + float(v), 0.5)
			"debt_gdp":
				c.debt = maxf(c.debt + c.gdp * float(v) / 100.0, 0.0)
			"relation":
				if other >= 0:
					Diplomacy.change_relation(other, float(v))
			"relations_all":
				for i in Game.relations.size():
					if i != Game.player:
						Game.relations[i] = clampf(Game.relations[i] + float(v), -100.0, 100.0)
				Game.relations_changed.emit()
			"deal":
				if other >= 0 and not Diplomacy.has_deal(other):
					Game.dip.deals[str(other)] = Game.months_played
			"sanction_me":
				if other >= 0:
					Game.dip.sanctioned_by[str(other)] = Game.months_played
			_:
				if String(k).begins_with("share_"):
					var key := String(k).trim_prefix("share_")
					c.set_budget_share(key, float(c.budget[key]) + float(v) / 100.0)
	Diplomacy._apply_counts()
	Simulation.update_finances(c)
