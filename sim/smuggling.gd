class_name Smuggling
extends RefCounted
## The black market. High taxes on tobacco, alcohol and fuel, steep tariffs,
## trade wars and sanctions, prohibitions and weak borders all create money to
## be made by smugglers. The shadow economy (0..100) drifts toward a level set by
## those incentives against how hard you fight back:
##   customs     an agency with four funding levels (border posts, scanners, dogs)
##   crackdowns  six-month campaigns on smuggling gangs (political capital)
##   amnesty     legalise a banned trade: it comes into the open and can be taxed
## A big black market loses tax revenue (part of what the taxes should raise
## goes untaxed), funds organised crime, and corrupts officials.
## State: Game.dip.black {value, start, customs, crackdown_m, legal: {...}}.
## Constants in sim/economy.gd (BLACK_*).

const E = preload("res://sim/economy.gd")

const CUSTOMS := ["Minimal", "Standard", "Strong", "Iron-clad"]
const CUSTOMS_COST := [0.02, 0.06, 0.12, 0.22]       # % of GDP a year
const CUSTOMS_POWER := [0.0, 1.0, 2.0, 3.0]

## Banned or restricted goods you can legalise: id -> {title, icon, push (shadow points while banned), tax (% of GDP once legal), desc}
const GOODS := {
	"cannabis": {"title": "Cannabis", "icon": "leaf", "push": 4.0, "tax": 0.08, "approval": -1.0,
		"desc": "Legal shops replace street dealers. Some voters object."},
	"gambling": {"title": "Online gambling", "icon": "dices", "push": 2.0, "tax": 0.05, "approval": -0.5,
		"desc": "Licensed sites replace offshore ones."},
	"street_trade": {"title": "Street trade", "icon": "store", "push": 3.0, "tax": 0.03, "approval": 0.5,
		"desc": "License hawkers and market stalls instead of chasing them."},
}


static func start_value(i: int) -> float:
	var c: CountryState = Game.state(i)
	var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
	return clampf(42.0 - 30.0 * lvl - 6.0 * World.stat(i, "corruption_wgi", 0.0), 5.0, 70.0)


static func st() -> Dictionary:
	if not Game.dip.has("black"):
		var v := start_value(Game.player)
		Game.dip["black"] = {"value": v, "start": v, "customs": 1, "crackdown_m": -99, "legal": {}, "last_news": -99}
	return Game.dip.black


static func value() -> float:
	return float(st().value)


static func change() -> float:
	return value() - float(st().start)


## What pushes the black market (+) and what holds it back (-): [[label, points], …].
static func terms(c: CountryState) -> Array:
	var s := st()
	var t: Array = []
	if not c.taxes.is_empty():
		t.append(["Tobacco & alcohol tax", E.BLACK_SIN * Taxes.delta(c, "sin")])
		t.append(["Fuel tax", E.BLACK_FUEL * Taxes.delta(c, "fuel")])
		t.append(["Tariffs", E.BLACK_TARIFF * Taxes.delta(c, "tariff")])
	t.append(["Trade wars & sanctions", E.BLACK_TRADEWAR * float(Tariffs.count() + c.sanctioned_by)])
	var legal: Dictionary = s.legal
	var banned := 0.0
	for id in GOODS:
		if legal.has(id):
			banned -= float(GOODS[id].push)
	t.append(["Legalised trades", banned])
	t.append(["Customs", -E.BLACK_CUSTOMS * (float(CUSTOMS_POWER[int(s.customs)]) - 1.0)])
	if Game.months_played - int(s.crackdown_m) < 24:
		t.append(["Crackdown", -E.BLACK_CRACKDOWN * clampf(1.0 - (Game.months_played - int(s.crackdown_m)) / 24.0, 0.0, 1.0)])
	t.append(["Corruption", -0.15 * Corruption.change(c)])
	if Game.dip.has("crime"):
		t.append(["Crime", 0.15 * Crime.change()])
	return t


static func target(c: CountryState) -> float:
	var v := float(st().start)
	for x in terms(c):
		v += float(x[1])
	return clampf(v, 1.0, 95.0)


static func set_customs(k: int) -> void:
	st().customs = clampi(k, 0, 3)


static func customs_cost_pct() -> float:
	if not Game.has_game() or not Game.dip.has("black"):
		return 0.0
	return float(CUSTOMS_COST[int(st().customs)]) - float(CUSTOMS_COST[1])


static func crackdown_wait() -> int:
	return maxi(0, int(st().crackdown_m) + 24 - Game.months_played)


static func crackdown() -> bool:
	if crackdown_wait() > 0 or not Capital.spend(E.BLACK_CRACKDOWN_CAPITAL):
		return false
	st().crackdown_m = Game.months_played
	Game.add_feed("Customs and police launch a crackdown on smuggling gangs", "siren", "accent")
	return true


static func legalise(id: String) -> void:
	var legal: Dictionary = st().legal
	if legal.has(id):
		return
	legal[id] = Game.months_played
	var c := Game.me()
	c.shocks.approval = float(c.shocks.approval) + float(GOODS[id].approval)
	Game.add_milestone("Legalised %s" % str(GOODS[id].title).to_lower(), str(GOODS[id].icon), "accent")


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var c := Game.me()
	s.value = float(s.value) + (target(c) - float(s.value)) * E.BLACK_ADJUST
	if change() > 8.0 and Game.months_played - int(s.last_news) > 24:
		s.last_news = Game.months_played
		out.append({"text": "Smuggling booms: contraband cigarettes and fuel flood the markets", "icon": "package", "good": false})
	return out


## Offsets: lost revenue (% of GDP), legal trades' new revenue, crime and corruption knock-ons.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("black") or Game.me() == null:
		return {}
	var d := change()
	var rev := -E.BLACK_REVENUE * d
	for id in st().legal:
		rev += float(GOODS[id].tax)
	return {"revenue": rev, "stability": -E.BLACK_STAB * d, "growth": -E.BLACK_GROWTH * d}
