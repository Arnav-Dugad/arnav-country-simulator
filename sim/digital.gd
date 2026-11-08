class_name Digital
extends RefCounted
## Digital nation.
##   Online        share of people using the internet (World Bank data). It
##                 climbs on its own, faster with the "Broadband for all" project.
##   Digital ID    one number for every citizen (like India's Aadhaar): tax and
##                 benefits leak less and officials steal less; privacy worries.
##   E-government  public services online: less queueing and paperwork.
##   Cyber defence an agency that guards networks. The more you put online, the
##                 more ransomware gangs and hostile states will try their luck.
## Effects count only the change since you took office.
## State: Game.dip.dig_n {net0, net, id (month or -1), egov, cyber, attack (month)}.
## Constants in sim/economy.gd (DGT_*).

const E = preload("res://sim/economy.gd")


static func st() -> Dictionary:
	if not Game.dip.has("dig_n"):
		var net := clampf(World.stat(Game.player, "internet_pct", 60.0), 5.0, 99.0)
		Game.dip["dig_n"] = {"net0": net, "net": net, "id": -1, "egov": false, "cyber": false, "attack": -99}
	return Game.dip.dig_n


static func online() -> float:
	return float(st().net)


static func has_id() -> bool:
	return int(st().id) >= 0


static func launch_id() -> bool:
	if has_id() or not Capital.spend(E.DGT_ID_CAPITAL):
		return false
	st().id = Game.months_played
	Corruption.boost(E.DGT_ID_CLEAN)
	var c := Game.me()
	c.shocks.approval = float(c.shocks.approval) - 1.0
	Game.add_feed("A digital ID for every citizen launches", "fingerprint", "accent")
	return true


static func set_egov(on: bool) -> void:
	var s := st()
	if on and not bool(s.egov):
		Corruption.boost(E.DGT_EGOV_CLEAN)
	s.egov = on


static func set_cyber(on: bool) -> void:
	st().cyber = on


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("dig_n"):
		return 0.0
	var s := st()
	return (E.DGT_EGOV_COST if bool(s.egov) else 0.0) + (E.DGT_CYBER_COST if bool(s.cyber) else 0.0)


## Extra tax collected thanks to a digital ID (% of GDP).
static func revenue_pct() -> float:
	if not Game.has_game() or not Game.dip.has("dig_n") or not has_id():
		return 0.0
	return E.DGT_ID_REVENUE * online() / 100.0


static func attack_chance() -> float:
	var s := st()
	var p := E.DGT_ATTACK * online() / 100.0
	if has_id() or bool(s.egov):
		p *= 1.6
	if bool(s.cyber):
		p *= 0.3
	return p


static func attack_event() -> Dictionary:
	return {"id": "ransomware", "title": "Ransomware attack", "icon": "shield-alert", "tint": "red", "other": -1,
		"next": {}, "face": "", "scene_hint": "",
		"body": "Hackers have locked the computers of %s's hospitals and tax office and demand millions in crypto to unlock them." % World.the_name(Game.player),
		"choices": [
			{"label": "Pay the ransom", "detail": "Systems back in days · it invites the next attack",
				"effects": {"cost": 0.03, "approval": -1.0}},
			{"label": "Refuse and rebuild", "detail": "Weeks of chaos · then a cyber agency",
				"effects": {"growth": -0.3, "happiness": -1.0, "digital": "cyber"}},
		]}


static func monthly() -> void:
	if not Game.has_game() or Game.me() == null:
		return
	var s := st()
	var top := 96.0
	var speed := E.DGT_NET_GROWTH
	if Projects.is_done(Game.me(), "broadband"):
		speed *= 3.0
	s.net = minf(float(s.net) + (top - float(s.net)) * speed, top)
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "cyber"])
	if Game.months_played >= 12 and Game.months_played - int(s.attack) >= 36 and r.randf() < attack_chance():
		var open := false
		for ev in Game.director.inbox:
			open = open or str(ev.get("id", "")) == "ransomware"
		if not open:
			s.attack = Game.months_played
			Game.director.add(attack_event())


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("dig_n"):
		return {}
	var s := st()
	var g := (online() - float(s.net0)) / 100.0 * E.DGT_NET_GROWTH_FX
	var h := 0.0
	if bool(s.egov):
		g += 0.05
		h += 0.4 * online() / 100.0
	return {"growth": g, "happiness": h}
