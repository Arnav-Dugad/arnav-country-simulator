extends Node
## DEMO store: catalogue, simulated purchases and entitlements.
## Nothing is ever charged. Purchases are stored locally in user://store.cfg.
## Real billing would need Google Play Billing (or a payment provider) plus
## server-side receipt checks — see docs/MONETIZATION.md.

signal changed

const DEMO := true
const PATH := "user://store.cfg"
const THEME_IDS := ["theme_gold", "theme_aurora", "theme_graphite", "theme_ember"]

## kind: "pack" (one-time), "subscription", "tip". `grants` = entitlements given.
const CATALOG := [
	{"id": "complete", "section": "Featured", "kind": "pack", "price": 9.99, "icon": "crown", "tint": "gold",
		"title": "Complete Edition", "badge": "Best value",
		"desc": "Everything in the store, forever. Less than buying each item.",
		"includes": ["All 3 expansions", "All 4 map themes", "Sandbox Cheats", "Supporter badge"],
		"grants": ["scen_crossroads", "events_turbulent", "reformer", "theme_gold", "theme_aurora",
			"theme_graphite", "theme_ember", "supporter", "cheats"]},
	{"id": "cheats", "section": "Featured", "kind": "pack", "price": 2.99, "icon": "wand-sparkles", "tint": "purple",
		"title": "Sandbox Cheats", "badge": "New",
		"desc": "40 one-tap cheats across money, people, economy, building, research, war, spies, wealth, crises and time, plus exact sliders and lasting switches.",
		"includes": ["40 one-tap cheats", "Exact-value sliders", "Lasting switches"], "grants": ["cheats"]},
	{"id": "scen_crossroads", "section": "Expansions", "kind": "pack", "price": 2.99, "icon": "map", "tint": "accent",
		"title": "Crossroads Scenarios", "desc": "6 scenarios with clear goals, from taming inflation to winning three terms.",
		"includes": ["6 scenarios", "Goal tracking"], "grants": ["scen_crossroads"], "soon": true},
	{"id": "events_turbulent", "section": "Expansions", "kind": "pack", "price": 2.99, "icon": "zap", "tint": "orange",
		"title": "Turbulent Times Events", "desc": "40 new events and 5 multi-step story chains.",
		"includes": ["40 events", "5 story chains"], "grants": ["events_turbulent"], "soon": true},
	{"id": "reformer", "section": "Expansions", "kind": "pack", "price": 3.99, "icon": "gavel", "tint": "purple",
		"title": "Reformer Policy Pack", "desc": "15 extra laws and reforms with real tradeoffs.",
		"includes": ["15 laws", "Reform timelines"], "grants": ["reformer"], "soon": true},
	{"id": "theme_gold", "section": "Map themes", "kind": "pack", "price": 0.99, "icon": "sparkles", "tint": "gold",
		"title": "Gold Leaf", "desc": "Warm, gilded political map.", "grants": ["theme_gold"], "theme": "gold"},
	{"id": "theme_aurora", "section": "Map themes", "kind": "pack", "price": 0.99, "icon": "sparkles", "tint": "green",
		"title": "Aurora", "desc": "Teal and green, like northern lights.", "grants": ["theme_aurora"], "theme": "aurora"},
	{"id": "theme_graphite", "section": "Map themes", "kind": "pack", "price": 0.99, "icon": "sparkles", "tint": "gray",
		"title": "Graphite", "desc": "Elegant monochrome.", "grants": ["theme_graphite"], "theme": "graphite"},
	{"id": "theme_ember", "section": "Map themes", "kind": "pack", "price": 0.99, "icon": "sparkles", "tint": "red",
		"title": "Ember", "desc": "Terracotta and sand.", "grants": ["theme_ember"], "theme": "ember"},
	{"id": "themes_all", "section": "Map themes", "kind": "pack", "price": 2.49, "icon": "layers", "tint": "teal",
		"title": "All Themes Bundle", "desc": "All four map themes.", "badge": "Save 37%",
		"grants": ["theme_gold", "theme_aurora", "theme_graphite", "theme_ember"]},
	{"id": "pass_monthly", "section": "Statesman Pass", "kind": "subscription", "price": 1.99, "period": "month",
		"icon": "crown", "tint": "gold", "title": "Statesman Pass · Monthly",
		"desc": "A new map theme each month, early access to scenarios, Sandbox Cheats, 10 cloud save slots. Cancel any time.",
		"grants": ["pass"]},
	{"id": "pass_yearly", "section": "Statesman Pass", "kind": "subscription", "price": 14.99, "period": "year",
		"icon": "crown", "tint": "gold", "title": "Statesman Pass · Yearly", "badge": "Save 37%",
		"desc": "Everything in Monthly, billed once a year.", "grants": ["pass"]},
	{"id": "tip_coffee", "section": "Support the developer", "kind": "tip", "price": 1.99, "icon": "heart", "tint": "red",
		"title": "Coffee", "desc": "A small thank-you. Unlocks the supporter badge.", "grants": ["supporter"]},
	{"id": "tip_lunch", "section": "Support the developer", "kind": "tip", "price": 4.99, "icon": "heart", "tint": "red",
		"title": "Lunch", "desc": "Supporter badge and the gold app icon.", "grants": ["supporter", "icon_gold"]},
	{"id": "tip_patron", "section": "Support the developer", "kind": "tip", "price": 9.99, "icon": "heart", "tint": "red",
		"title": "Patron", "desc": "Everything above, plus your name in the credits.",
		"grants": ["supporter", "icon_gold", "credits"]},
]

var _owned := {}       # entitlement -> true
var _bought := {}      # product id -> unix time
var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		for k in _cfg.get_value("store", "owned", []):
			_owned[k] = true
		_bought = _cfg.get_value("store", "bought", {})


func item(id: String) -> Dictionary:
	for it in CATALOG:
		if it.id == id:
			return it
	return {}


func sections() -> PackedStringArray:
	var out: PackedStringArray = []
	for it in CATALOG:
		if not out.has(it.section):
			out.append(it.section)
	return out


func owns(entitlement: String) -> bool:
	if entitlement == "cheats" and _active_pass():
		return true
	return _owned.has(entitlement)


func _active_pass() -> bool:
	return _bought.has("pass_monthly") or _bought.has("pass_yearly")


## A product counts as owned when every entitlement it grants is owned
## (tips can always be bought again).
func owns_product(id: String) -> bool:
	var it := item(id)
	if it.is_empty() or it.kind == "tip":
		return false
	if it.kind == "subscription":
		return _bought.has(id)
	for g in it.grants:
		if not _owned.has(g):
			return false
	return true


func price_text(id: String) -> String:
	var it := item(id)
	var p := "$%.2f" % float(it.price)
	return p + (" / " + str(it.period) if it.has("period") else "")


## Simulated purchase (DEMO): waits like a real checkout, then grants.
func purchase(id: String) -> Dictionary:
	var it := item(id)
	if it.is_empty():
		return {"ok": false, "error": "Unknown item."}
	await get_tree().create_timer(0.9).timeout
	if it.kind == "subscription":
		for other in ["pass_monthly", "pass_yearly"]:
			_bought.erase(other)
	for g in it.grants:
		_owned[g] = true
	_bought[id] = int(Time.get_unix_time_from_system())
	_save()
	changed.emit()
	return {"ok": true}


func cancel_subscription() -> void:
	_bought.erase("pass_monthly")
	_bought.erase("pass_yearly")
	_owned.erase("pass")
	_save()
	changed.emit()


func reset_demo() -> void:
	_owned.clear()
	_bought.clear()
	if Settings.map_theme != "default":
		Settings.set_value("map_theme", "default")
	_save()
	changed.emit()


func _save() -> void:
	_cfg.set_value("store", "owned", _owned.keys())
	_cfg.set_value("store", "bought", _bought)
	_cfg.save(PATH)


static func tint(name: String) -> Color:
	return {"gold": DS.GOLD, "accent": DS.ACCENT, "orange": DS.ORANGE, "purple": DS.PURPLE,
		"green": DS.GREEN, "gray": Color("8e8e93"), "red": DS.RED, "teal": DS.TEAL}.get(name, DS.ACCENT)
