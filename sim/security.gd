class_name Security
extends RefCounted
## National security, kept calm and abstract (no battles). Threat comes from
## countries that dislike you, weighted by their military strength and by how
## close they are (neighbours count most). Deterrence is your own military plus
## a share of your allies'. When threat outweighs deterrence, investors grow
## nervous and stability slips, and border standoffs become possible.
## Military strength is the 0-100 index from real military spending.
## Constants: sim/economy.gd (SEC_*). Cached once a month (Game.dip.security).

const E = preload("res://sim/economy.gd")


## Recomputes and caches {threat, deterrence, balance, top} for the player.
static func refresh() -> Dictionary:
	var me := Game.player
	var md := World.map
	var near := {}
	if me >= 0 and me < md.neighbours.size():
		for j in md.neighbours[me]:
			near[World.sovereign_of(j) if World.sovereign_of(j) >= 0 else j] = true
	var threat := 0.0
	var top := -1
	var top_v := 0.0
	for j in World.playable:
		if j == me:
			continue
		var c: CountryState = Game.state(j)
		if c == null:
			continue
		var r := Game.relations[j]
		if r >= E.SEC_HOSTILE:
			continue
		var hostility := clampf((E.SEC_HOSTILE - r) / 60.0, 0.0, 1.5)
		var reach := 1.0 if near.has(j) else (0.35 if c.military >= 70.0 else 0.08)   # big militaries project power
		var v := c.military * hostility * reach
		threat += v
		if v > top_v:
			top_v = v
			top = j
	var deter := Game.me().military + Nuclear.deter_bonus() + Bases.deter()
	for k in Game.dip.get("alliances", {}):
		var ally: CountryState = Game.state(int(k))
		if ally != null:
			deter += ally.military * E.SEC_ALLY_SHARE
	var out := {"threat": snappedf(threat, 0.1), "deterrence": snappedf(deter, 0.1),
		"balance": snappedf(deter - threat, 0.1), "top": top, "m": Game.months_played}
	Game.dip["security"] = out
	return out


static func get_state() -> Dictionary:
	var s: Dictionary = Game.dip.get("security", {})
	if s.is_empty() or int(s.get("m", -1)) != Game.months_played:
		s = refresh()
	return s


## 0 safe, 1 tense, 2 under threat.
static func level() -> int:
	var s := get_state()
	if float(s.threat) < 15.0 or float(s.balance) >= 10.0:
		return 0
	return 1 if float(s.balance) >= -15.0 else 2


const LEVEL_TEXT := ["Safe", "Tense", "Under threat"]


## Target offsets for the player: {growth, stability}.
static func effects() -> Dictionary:
	var s := get_state()
	var gap := maxf(-float(s.balance), 0.0) if float(s.threat) >= 15.0 else 0.0
	# The starting situation is already part of the country's real stability:
	# only a worse balance than at the start has an effect.
	if not Game.dip.has("security_start_gap"):
		Game.dip["security_start_gap"] = gap
	gap = maxf(gap - float(Game.dip.security_start_gap), 0.0)
	return {"growth": -E.SEC_GROWTH * gap / 10.0, "stability": -E.SEC_STABILITY * gap / 10.0}


static func describe() -> String:
	var s := get_state()
	match level():
		0:
			return "No country nearby threatens you, or your forces and allies deter them."
		1:
			return "Some hostile countries are watching. Your deterrence roughly matches the threat."
	var t := int(s.top)
	return "%s is the main danger. Strengthen your military, make allies, or mend relations." % (World.The_name(t) if t >= 0 else "A hostile neighbour")
