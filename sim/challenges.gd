class_name Challenges
extends RefCounted
## Challenges: a real country, one clear goal, a deadline. The game continues
## after success or failure; the result is recorded and celebrated.
## goal.metric: any CountryState field or "debt_pct" / "balance_pct" / "elections" /
## "co2_pc" (Climate) / "migration" (Migration, per 1,000 a year).

const ALL := [
	{"id": "arg_inflation", "country": "ARG", "icon": "flame", "title": "Tame the inflation",
		"desc": "Bring Argentina's inflation below 25% within 5 years.",
		"goal": {"metric": "inflation", "op": "<", "value": 25.0}, "years": 5},
	{"id": "ind_10t", "country": "IND", "icon": "trending-up", "title": "A $10 trillion India",
		"desc": "Grow India's economy to $10 trillion within 12 years.",
		"goal": {"metric": "gdp", "op": ">=", "value": 1e13}, "years": 12},
	{"id": "zaf_jobs", "country": "ZAF", "icon": "users", "title": "Jobs for South Africa",
		"desc": "Cut South Africa's unemployment below 29% within 6 years.",
		"goal": {"metric": "unemployment", "op": "<", "value": 29.0}, "years": 6},
	{"id": "ita_budget", "country": "ITA", "icon": "wallet", "title": "Balance the books",
		"desc": "Get Italy to a budget surplus within 6 years.",
		"goal": {"metric": "balance_pct", "op": ">", "value": 0.0}, "years": 6},
	{"id": "grc_debt", "country": "GRC", "icon": "piggy-bank", "title": "Escape the debt",
		"desc": "Bring Greece's debt below 120% of GDP within 8 years.",
		"goal": {"metric": "debt_pct", "op": "<", "value": 120.0}, "years": 8},
	{"id": "jpn_terms", "country": "JPN", "icon": "crown", "title": "Three terms in Tokyo",
		"desc": "Win three elections in a row in Japan.",
		"goal": {"metric": "elections", "op": ">=", "value": 3.0}, "years": 13},
	{"id": "nga_stability", "country": "NGA", "icon": "shield", "title": "A calmer Nigeria",
		"desc": "Raise Nigeria's stability above 22 within 8 years.",
		"goal": {"metric": "stability", "op": ">", "value": 22.0}, "years": 8},
	{"id": "pol_coal", "country": "POL", "icon": "leaf", "title": "Beyond coal",
		"desc": "Cut Poland's emissions below 5.5 tonnes of CO₂ a person within 8 years (from 7.6).",
		"goal": {"metric": "co2_pc", "op": "<", "value": 5.5}, "years": 8},
	{"id": "aus_green", "country": "AUS", "icon": "sun", "title": "Sunburnt country, clean power",
		"desc": "Cut Australia's emissions below 9 tonnes of CO₂ a person within 10 years (from 14.1).",
		"goal": {"metric": "co2_pc", "op": "<", "value": 9.0}, "years": 10},
	{"id": "bih_stay", "country": "BIH", "icon": "plane-landing", "title": "Stop the exodus",
		"desc": "Young Bosnians are leaving. Slow emigration to under 2.5 people per 1,000 a year within 8 years (from 5.2).",
		"goal": {"metric": "migration", "op": ">", "value": -2.5}, "years": 8},
	{"id": "ind_air", "country": "IND", "icon": "wind", "title": "Clear skies over India",
		"desc": "Cut India's fine-dust pollution below 34 µg/m³ within 8 years (from 54).",
		"goal": {"metric": "pm", "op": "<", "value": 34.0}, "years": 8},
	{"id": "esp_unity", "country": "ESP", "icon": "map-pin", "title": "Keep Spain together",
		"desc": "Win back Spain's restless region: national unity above 75 within 10 years.",
		"goal": {"metric": "unity", "op": ">", "value": 75.0}, "years": 10},
	{"id": "egy_water", "country": "EGY", "icon": "droplets", "title": "Water for Egypt",
		"desc": "Bring Egypt's water stress below 2.4 of 5 within 10 years (from 3.2).",
		"goal": {"metric": "water", "op": "<", "value": 2.4}, "years": 10},
]


static func get_by_id(id: String) -> Dictionary:
	for ch in ALL:
		if ch.id == id:
			return ch
	return {}


static func current_value(ch: Dictionary) -> float:
	var c := Game.me()
	match str(ch.goal.metric):
		"debt_pct":
			return c.debt_pct()
		"balance_pct":
			return c.balance_pct()
		"elections":
			return float(Game.elections_won)
		"co2_pc":
			return Climate.co2_pc(c)
		"migration":
			return Migration.rate(c)
		"pm":
			return Air.pm()
		"unity":
			return Regions.unity()
		"water":
			return Water.stress()
	return float(c.get(str(ch.goal.metric)))


static func met(ch: Dictionary) -> bool:
	var v := current_value(ch)
	var t := float(ch.goal.value)
	match str(ch.goal.op):
		"<":
			return v < t
		"<=":
			return v <= t
		">":
			return v > t
	return v >= t


static func format_value(ch: Dictionary, v: float) -> String:
	match str(ch.goal.metric):
		"gdp":
			return DS.money(v)
		"elections":
			return "%d won" % int(v)
		"stability":
			return String.num(v, 0)
		"co2_pc":
			return "%s t" % String.num(v, 1)
		"migration":
			return "%s%s per 1,000" % ["+" if v >= 0.0 else "−", String.num(absf(v), 1)]
		"pm":
			return "%d µg/m³" % roundi(v)
		"unity", "stability":
			return String.num(v, 0)
		"water":
			return "%s of 5" % String.num(v, 1)
	return DS.pct(v, 1)


## Progress text, e.g. "Now 194.7% · goal below 10% by Jan 2030".
static func progress_text(ch: Dictionary) -> String:
	var op: String = {"<": "below", "<=": "at most", ">": "above", ">=": "at least"}[str(ch.goal.op)]
	var deadline := int(Game.challenge.get("deadline", 0))
	var left := deadline - Game.months_played
	return "Now %s · goal %s %s · %s" % [format_value(ch, current_value(ch)), op,
		format_value(ch, float(ch.goal.value)),
		"%d months left" % left if left > 0 else "time's up"]
