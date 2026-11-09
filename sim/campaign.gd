class_name Campaign
extends RefCounted
## Election campaigns. Three months before an election the player picks two
## themes. A theme helps in proportion to your real record on it (and can
## backfire if your record is poor), so honest campaigning wins.

const THEMES := [
	{"id": "economy", "title": "A growing economy", "icon": "trending-up"},
	{"id": "jobs", "title": "Jobs for everyone", "icon": "users"},
	{"id": "health", "title": "Better healthcare", "icon": "stethoscope"},
	{"id": "prices", "title": "Stable prices", "icon": "coins"},
	{"id": "safety", "title": "Safety and order", "icon": "shield"},
	{"id": "change", "title": "Time for change", "icon": "sparkles"},
]
const BASE_BOOST := 2.0        # approval pts a neutral theme gives
const RECORD_WEIGHT := 3.0     # extra pts per unit of record (-1..1)
const MONTHS_BEFORE := 3


## Your record on a theme: -1 (weak) … +1 (strong).
static func record(c: CountryState, id: String) -> float:
	var b: Dictionary = c.base
	match id:
		"economy":
			return clampf((c.growth - c.trend_now()) / 2.0 + 0.2, -1.0, 1.0)
		"jobs":
			return clampf((float(b.unemployment) - c.unemployment) / 2.0 + 0.1, -1.0, 1.0)
		"health":
			var e := c.effort("health") / maxf(float(b.get("health_effort", 1.0)), 0.001)
			var r := clampf((e - 1.0) * 3.0, -1.0, 1.0)
			if Laws.is_active(c, "universal_health") and not c.laws_start.has("universal_health"):
				r = minf(r + 0.6, 1.0)
			return r
		"prices":
			return clampf((4.0 - c.inflation) / 4.0, -1.0, 1.0)
		"safety":
			return clampf((c.stability - 50.0) / 25.0, -1.0, 1.0)
		"change":
			# Works best for a fresh government with low expectations.
			return clampf((50.0 - c.approval) / 20.0, -0.3, 0.6)
	return 0.0


static func record_text(r: float) -> String:
	if r >= 0.4:
		return "Strong record"
	if r >= -0.1:
		return "Mixed record"
	return "Weak record"


static func boost(c: CountryState, id: String) -> float:
	return BASE_BOOST + RECORD_WEIGHT * record(c, id)


## Applies the chosen themes; returns the total approval change.
static func launch(c: CountryState, ids: Array) -> float:
	var total := 0.0
	for id in ids:
		total += boost(c, str(id))
	c.approval = clampf(c.approval + total * 0.5, 0.0, 100.0)
	c.shocks.approval = float(c.shocks.approval) + total
	return total


## The two themes with the biggest boost (what the cabinet runs on if you don't choose).
static func best_themes(c: CountryState) -> Array:
	var ids: Array = THEMES.map(func(t: Dictionary) -> String: return str(t.id))
	ids.sort_custom(func(a: String, b: String) -> bool: return boost(c, a) > boost(c, b))
	return ids.slice(0, 2)


static func title_of(id: String) -> String:
	for th in THEMES:
		if th.id == id:
			return str(th.title)
	return id
