class_name Bases
extends RefCounted
## Foreign military bases: lease land to one great power (as Djibouti, Japan or
## Cuba's Guantánamo show, it happens everywhere). The tenant pays rent, guards
## you and becomes a friend; its rivals cool on you, and some of your own people
## resent foreign soldiers on home soil. Ending a lease angers the tenant.
## Strategic spots (near a sea lane, on a coast) earn more rent.
## State: Game.dip.bases {tenant (iso or ""), since}. Constants in sim/economy.gd (BASE_*).

const E = preload("res://sim/economy.gd")

const POWERS := ["USA", "CHN", "RUS", "FRA", "GBR", "IND", "TUR"]


static func st() -> Dictionary:
	if not Game.dip.has("bases"):
		Game.dip["bases"] = {"tenant": "", "since": -1}
	return Game.dip.bases


static func tenant() -> String:
	return str(st().tenant)


## Rent as % of GDP: bigger for small, strategic countries.
static func rent_pct() -> float:
	var c := Game.me()
	var r := E.BASE_RENT * clampf(1e11 / maxf(c.gdp, 1e9), 0.05, 4.0)
	if not World.landlocked(Game.player):
		r *= 1.5
	var iso := World.iso(Game.player)
	for id in SeaLanes.LANES:
		var l: Dictionary = SeaLanes.LANES[id]
		if str(l.owner) == iso or iso in ["DJI", "OMN", "YEM", "SGP", "MYS", "IDN", "TUR", "EGY", "PAN", "IRN", "ARE", "ERI"]:
			r *= 1.6
			break
	return clampf(r, 0.0, 3.0)


static func offers() -> Array:
	var out: Array = []
	for iso in POWERS:
		var i := World.index_of(str(iso))
		if i < 0 or i == Game.player or World.is_absorbed(i) or War.is_at_war_with(i):
			continue
		if Game.relations[i] >= E.BASE_MIN_RELATION:
			out.append(i)
	return out


static func blocked() -> String:
	if tenant() != "":
		return "You already host a base"
	if Nuclear.armed() and Game.me().military >= 70.0:
		return "A great power hosts nobody"
	if offers().is_empty():
		return "No great power is friendly enough to ask (relations %d+)" % int(E.BASE_MIN_RELATION)
	return ""


static func lease(i: int) -> bool:
	if blocked() != "" or not i in offers() or not Capital.spend(E.BASE_CAPITAL):
		return false
	var s := st()
	s.tenant = World.iso(i)
	s.since = Game.months_played
	Diplomacy.change_relation(i, E.BASE_FRIEND)
	var camp := Treaties.base_camp(i)
	if camp != "south":
		var other := "east" if camp == "west" else "west"
		for j in Treaties.camp(other):
			Game.relations[j] = clampf(Game.relations[j] - E.BASE_RIVAL, -100.0, 100.0)
	Game.relations_changed.emit()
	Game.me().shocks.approval = float(Game.me().shocks.approval) - 2.0
	Game.add_milestone("%s opened a military base here" % World.map.names[i], "shield", "accent")
	return true


static func evict() -> void:
	var s := st()
	var i := World.index_of(tenant())
	if i >= 0:
		Diplomacy.change_relation(i, -E.BASE_EVICT)
		Game.add_feed("%s's soldiers go home" % World.map.names[i], "shield", "orange")
	s.tenant = ""
	s.since = -1
	Game.me().shocks.approval = float(Game.me().shocks.approval) + 1.0
	Game.relations_changed.emit()


static func revenue_pct() -> float:
	if not Game.has_game() or not Game.dip.has("bases") or tenant() == "" or Game.me() == null:
		return 0.0
	return rent_pct()


## Security deterrence from a guardian.
static func deter() -> float:
	if not Game.has_game() or not Game.dip.has("bases") or tenant() == "":
		return 0.0
	var i := World.index_of(tenant())
	var c: CountryState = Game.state(i) if i >= 0 else null
	return (c.military if c != null else 50.0) * E.BASE_DETER


## Effects on the national targets.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("bases") or tenant() == "":
		return {}
	var yrs := float(Game.months_played - int(st().since)) / 12.0
	return {"stability": 0.8, "approval": -clampf(0.5 + yrs * 0.05, 0.5, 1.5)}
