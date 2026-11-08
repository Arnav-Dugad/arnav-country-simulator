class_name Capital
extends RefCounted
## Political capital (0..100): the goodwill a leader can spend on hard choices.
## Earned every month from public support (approval in democracies, a mix of
## support and stability elsewhere), with boosts for election wins, renewed
## mandates and national goals. Spent on passing or repealing laws (unpopular
## reforms cost more), cabinet reshuffles, corruption crackdowns, tariffs and
## changing the constitution. Only the player's UI enforces costs; simulations
## and bots are unaffected. Constants: sim/economy.gd (CAPITAL_*).
## State: Game.dip.capital (float).

const E = preload("res://sim/economy.gd")


static func value() -> float:
	if not Game.dip.has("capital"):
		Game.dip["capital"] = E.CAPITAL_START
	return float(Game.dip.capital)


static func add(points: float) -> void:
	Game.dip["capital"] = clampf(value() + points, 0.0, E.CAPITAL_MAX)


static func can(cost: float) -> bool:
	return value() + 0.001 >= cost


static func spend(cost: float) -> bool:
	if not can(cost):
		return false
	add(-cost)
	return true


## Monthly income: more when people back you.
static func income() -> float:
	var c := Game.me()
	var support := c.approval if Government.has_elections(Game.player) else (c.approval + c.stability) * 0.5
	var g := E.CAPITAL_BASE + E.CAPITAL_PER_SUPPORT * (support - 45.0)
	if Mandate.active():
		g += 1.0
	return clampf(g, E.CAPITAL_MIN_GAIN, E.CAPITAL_MAX_GAIN)


static func monthly() -> void:
	add(income())


## Cost to pass (or repeal) a law: popular reforms are cheap, painful ones dear.
static func law_cost(l: Dictionary, repeal: bool) -> float:
	var pol := float(l.get("politics", 0.0)) * (-0.6 if repeal else 1.0)
	return roundf(clampf(E.CAPITAL_LAW_BASE - E.CAPITAL_LAW_PER_POLITICS * pol, 4.0, 40.0))


static func label() -> String:
	return "%d" % roundi(value())
