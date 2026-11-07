class_name Diplomacy
extends RefCounted
## Player diplomacy: trade deals, alliances, sanctions and foreign aid.
## State lives in Game.dip (saved with the game); relations in Game.relations.
## Tweakable numbers are grouped here, like sim/economy.gd.

const DEAL_MIN_RELATION := 20.0
const ALLIANCE_MIN_RELATION := 55.0
const DEAL_RELATION_GAIN := 8.0
const ALLIANCE_RELATION_GAIN := 10.0
const SANCTION_RELATION_LOSS := 35.0
const BREAK_DEAL_LOSS := 15.0
const BREAK_ALLIANCE_LOSS := 30.0
const LIFT_SANCTION_GAIN := 10.0
const AID_SHARE_OF_GDP := 0.001       # 0.1 % of your GDP per aid package
const AID_MIN := 5e7
const AID_COOLDOWN_MONTHS := 6
const RIVAL_PENALTY := 6.0           # allying with X upsets X's enemies
const RELATION_DRIFT := 0.01         # monthly pull back toward baseline
const DEAL_MONTHLY_GAIN := 0.12
const SANCTION_MONTHLY_LOSS := 0.25


static func fresh_state() -> Dictionary:
	return {"deals": {}, "alliances": {}, "sanctions": {}, "sanctioned_by": {}, "aid_total": 0.0,
		"last_aid": {}, "baseline": {}}


static func _d() -> Dictionary:
	return Game.dip


static func has_deal(i: int) -> bool:
	return _d().deals.has(str(i))


static func has_alliance(i: int) -> bool:
	return _d().alliances.has(str(i))


static func is_sanctioning(i: int) -> bool:
	return _d().sanctions.has(str(i))


static func sanctions_me(i: int) -> bool:
	return _d().sanctioned_by.has(str(i))


static func summary() -> Dictionary:
	var d := _d()
	return {"alliances": d.alliances.size(), "deals": d.deals.size(), "sanctions": d.sanctions.size(),
		"sanctioned_by": d.sanctioned_by.size(), "aid_total": float(d.aid_total)}


# ---------------------------------------------------------------- display ---
static func relation_text(r: float) -> String:
	if r >= 60.0:
		return "Excellent"
	if r >= 25.0:
		return "Friendly"
	if r > -15.0:
		return "Neutral"
	if r > -50.0:
		return "Tense"
	return "Hostile"


static func relation_color(r: float) -> Color:
	if r >= 25.0:
		return DS.GREEN
	if r > -15.0:
		return DS.TEXT_2
	if r > -50.0:
		return DS.ORANGE
	return DS.RED


static func status_text(i: int) -> String:
	var parts: PackedStringArray = []
	if has_alliance(i):
		parts.append("Ally")
	if has_deal(i):
		parts.append("Trade deal")
	if is_sanctioning(i):
		parts.append("Sanctioned by you")
	if sanctions_me(i):
		parts.append("Sanctions you")
	if parts.is_empty():
		parts.append(World.group_of(i))
	return "  ·  ".join(parts)


# ---------------------------------------------------------------- actions ---
## Chance (0..1) that the other side accepts a proposal.
static func acceptance(i: int, kind: String) -> float:
	var r := Game.relations[i]
	var them: CountryState = Game.state(i)
	var me := Game.me()
	var size_ratio := 1.0
	if them and me:
		size_ratio = clampf(me.gdp / maxf(them.gdp, 1.0), 0.1, 10.0)
	var size_bonus := clampf(log(size_ratio) / log(10.0) * 0.12, -0.15, 0.15)
	# Partners in the same bloc, and a diplomat at the foreign ministry, help.
	for t in Treaties.memberships(Game.player):
		if Treaties.is_member(i, str(t.id)) and str(t.id) != "climate":
			size_bonus += 0.08
			break
	size_bonus += Cabinet.bonus("deal_acceptance")
	match kind:
		"deal":
			return clampf((r - 5.0) / 55.0 + size_bonus, 0.0, 0.95)
		"alliance":
			return clampf((r - 40.0) / 45.0 + size_bonus, 0.0, 0.9)
	return 0.0


static func can_propose_deal(i: int) -> bool:
	return not has_deal(i) and not is_sanctioning(i) and Game.relations[i] >= DEAL_MIN_RELATION


static func can_propose_alliance(i: int) -> bool:
	return not has_alliance(i) and not is_sanctioning(i) and Game.relations[i] >= ALLIANCE_MIN_RELATION


## Returns true if accepted.
static func propose_deal(i: int) -> bool:
	if not can_propose_deal(i):
		return false
	if Game.rng.randf() > acceptance(i, "deal"):
		change_relation(i, -2.0)
		return false
	_d().deals[str(i)] = Game.months_played
	_apply_counts()
	change_relation(i, DEAL_RELATION_GAIN)
	return true


static func cancel_deal(i: int) -> void:
	_d().deals.erase(str(i))
	_apply_counts()
	change_relation(i, -BREAK_DEAL_LOSS)


static func propose_alliance(i: int) -> bool:
	if not can_propose_alliance(i):
		return false
	if Game.rng.randf() > acceptance(i, "alliance"):
		change_relation(i, -3.0)
		return false
	_d().alliances[str(i)] = Game.months_played
	_apply_counts()
	change_relation(i, ALLIANCE_RELATION_GAIN)
	# The ally's enemies take note.
	for j in World.playable:
		if j != Game.player and j != i and _pair_hostile(i, j):
			change_relation(j, -RIVAL_PENALTY)
	return true


static func break_alliance(i: int) -> void:
	_d().alliances.erase(str(i))
	_apply_counts()
	change_relation(i, -BREAK_ALLIANCE_LOSS)
	Game.me().shocks.approval -= 1.0


static func sanction(i: int) -> void:
	if is_sanctioning(i):
		return
	_d().sanctions[str(i)] = Game.months_played
	_d().deals.erase(str(i))
	_d().alliances.erase(str(i))
	change_relation(i, -SANCTION_RELATION_LOSS)
	var them: CountryState = Game.state(i)
	var me := Game.me()
	if them:
		them.sanctioned_by += 1
		# Sanctions cost the sanctioner too, in proportion to the trade lost.
		me.shocks.growth -= clampf(them.gdp / maxf(me.gdp, 1.0) * 0.6, 0.05, 1.2)
	_apply_counts()


static func lift_sanction(i: int) -> void:
	if not is_sanctioning(i):
		return
	_d().sanctions.erase(str(i))
	var them: CountryState = Game.state(i)
	if them:
		them.sanctioned_by = maxi(0, them.sanctioned_by - 1)
	change_relation(i, LIFT_SANCTION_GAIN)


static func aid_amount() -> float:
	var me := Game.me()
	return maxf(me.gdp * AID_SHARE_OF_GDP, AID_MIN) if me else AID_MIN


static func can_send_aid(i: int) -> bool:
	var last: int = int(_d().last_aid.get(str(i), -999))
	return Game.months_played - last >= AID_COOLDOWN_MONTHS and not is_sanctioning(i)


static func aid_cooldown(i: int) -> int:
	var last: int = int(_d().last_aid.get(str(i), -999))
	return maxi(0, AID_COOLDOWN_MONTHS - (Game.months_played - last))


static func send_aid(i: int) -> float:
	if not can_send_aid(i):
		return 0.0
	var amount := aid_amount()
	var me := Game.me()
	me.treasury -= amount
	var them: CountryState = Game.state(i)
	var weight := 1.0
	if them:
		weight = clampf(amount / maxf(them.gdp, 1.0) * 400.0, 0.5, 3.0)
		them.shocks.happiness += minf(weight, 2.0)
	var gain := 5.0 * weight
	change_relation(i, gain)
	_d().last_aid[str(i)] = Game.months_played
	_d().aid_total = float(_d().aid_total) + amount
	Achievements.bump("aid")
	return gain


static func change_relation(i: int, delta: float) -> void:
	Game.relations[i] = clampf(Game.relations[i] + delta, -100.0, 100.0)
	Game.relations_changed.emit()


# ---------------------------------------------------------------- monthly ---
static func monthly() -> void:
	var d := _d()
	var base: Dictionary = d.baseline
	for i in Game.relations.size():
		if i == Game.player:
			continue
		var b := float(base.get(str(i), Game.relations[i]))
		var r := Game.relations[i]
		r += (b - r) * RELATION_DRIFT
		if d.deals.has(str(i)):
			r += DEAL_MONTHLY_GAIN
		if d.alliances.has(str(i)):
			r += DEAL_MONTHLY_GAIN
		if d.sanctions.has(str(i)):
			r -= SANCTION_MONTHLY_LOSS
		Game.relations[i] = clampf(r, -100.0, 100.0)
	# Alliances that soured end on their own.
	for k in d.alliances.keys():
		if Game.relations[int(k)] < 20.0:
			d.alliances.erase(k)
	_apply_counts()


## Keeps CountryState aggregates in sync with the diplomacy state.
static func _apply_counts() -> void:
	var me := Game.me()
	if me == null:
		return
	var d := _d()
	me.trade_deals = d.deals.size()
	me.alliances = d.alliances.size()
	me.sanctioned_by = d.sanctioned_by.size()


static func _pair_hostile(a: int, b: int) -> bool:
	var ka := "%s-%s" % [World.map.iso3[a], World.map.iso3[b]]
	var kb := "%s-%s" % [World.map.iso3[b], World.map.iso3[a]]
	var v: int = Game.RELATION_SEEDS.get(ka, Game.RELATION_SEEDS.get(kb, 0))
	return v <= -40


## Free democracies react to something you did (a disputed election, a crackdown…).
static func democracies_react(delta: float) -> void:
	for i in Game.relations.size():
		if i != Game.player and Government.is_free(i):
			Game.relations[i] = clampf(Game.relations[i] + delta, -100.0, 100.0)
	Game.relations_changed.emit()
