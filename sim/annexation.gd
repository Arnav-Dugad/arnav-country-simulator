class_name Annexation
extends RefCounted
## Whole countries changing hands.
##   absorb     the loser disappears into the winner: its people, economy,
##              debt and part of its army join; on the map its border with the
##              winner vanishes and it takes the winner's colour. Newly absorbed
##              people resist at first (integration unrest that fades over
##              INTEGRATION_MONTHS), and the world is alarmed.
##   vassals    a beaten country keeps its flag but pays you tribute every year,
##              follows your lead (relations held warm) and fights beside you.
##              It may break away if your army weakens or it comes to hate you.
## State: Game.dip.owners {loser: winner}, Game.dip.integration {loser: {start, share}},
## Game.dip.vassals {i: {since}}. Constants in sim/economy.gd (ANNEX_*).

const E = preload("res://sim/economy.gd")


static func owners() -> Dictionary:
	if not Game.dip.has("owners"):
		Game.dip["owners"] = {}
	return Game.dip.owners


## Absorb `loser` into `winner`. Returns a one-line summary.
static func absorb(loser: int, winner: int) -> String:
	var a: CountryState = Game.state(loser)
	var b: CountryState = Game.state(winner)
	if a == null or b == null or loser == winner:
		return ""
	var share := a.population / maxf(a.population + b.population, 1.0)
	b.population += a.population
	b.gdp += a.gdp * E.ANNEX_GDP_KEEP
	b.debt += a.debt * E.ANNEX_DEBT_SHARE
	b.treasury += maxf(a.treasury, 0.0)
	b.military = clampf(b.military + a.military * E.ANNEX_ARMY_SHARE, 1.0, 100.0)
	# End everything the loser was part of.
	War.wars().erase(str(loser))
	for k in WorldWars.all().keys():
		var ww: Dictionary = WorldWars.all()[k]
		if int(ww.a) == loser or int(ww.b) == loser:
			WorldWars.all().erase(k)
	for key in ["alliances", "deals", "sanctions", "sanctioned_by"]:
		if Game.dip.has(key) and Game.dip[key] is Dictionary:
			(Game.dip[key] as Dictionary).erase(str(loser))
	vassals().erase(str(loser))
	if Game.dip.has("annexed"):
		Game.dip.annexed.erase(str(loser))
	owners()[str(loser)] = winner
	for k in owners().keys():                # earlier conquests of the loser pass on
		if int(owners()[k]) == loser:
			owners()[k] = winner
	Game.countries[loser] = null
	World.set_owners(owners())
	var text := ""
	if winner == Game.player:
		if not Game.dip.has("integration"):
			Game.dip["integration"] = {}
		Game.dip.integration[str(loser)] = {"start": Game.months_played, "share": share}
		for j in World.playable:
			if j != Game.player:
				var hit := E.ANNEX_WORLD_ANGER * (1.5 if Treaties.base_camp(j) == Treaties.base_camp(loser) else 1.0)
				Game.relations[j] = clampf(Game.relations[j] - hit, -100.0, 100.0)
		Game.relations_changed.emit()
		b.shocks.approval = float(b.shocks.approval) + E.ANNEX_APPROVAL
		text = "%s is now part of %s: %s new citizens" % [World.The_name(loser), World.the_name(winner), DS.compact(a.population)]
		Game.add_milestone("Annexed %s" % World.map.names[loser], "flag", "gold")
		Achievements.unlock("empire")
	else:
		text = "%s is swallowed by %s and ceases to exist" % [World.The_name(loser), World.the_name(winner)]
	Game.add_feed(text, "flag", "gold" if winner == Game.player else "red")
	Simulation.update_finances(b)
	return text


## Integration unrest on you (stability, approval points), fading out.
static func unrest() -> Dictionary:
	var out := {"stability": 0.0, "approval": 0.0, "growth": 0.0}
	if not Game.dip.has("integration"):
		return out
	for k in Game.dip.integration:
		var it: Dictionary = Game.dip.integration[k]
		var t := clampf(1.0 - float(Game.months_played - int(it.start)) / float(E.ANNEX_INTEGRATION_MONTHS), 0.0, 1.0)
		var s := clampf(float(it.share), 0.0, 0.8)
		out.stability -= E.ANNEX_UNREST_STABILITY * s * t
		out.approval -= E.ANNEX_UNREST_APPROVAL * s * t
		out.growth -= E.ANNEX_UNREST_GROWTH * s * t
	return out


# ------------------------------------------------------------------ vassals ---
static func vassals() -> Dictionary:
	if not Game.dip.has("vassals"):
		Game.dip["vassals"] = {}
	return Game.dip.vassals


static func is_vassal(i: int) -> bool:
	return vassals().has(str(i))


static func make_vassal(i: int) -> String:
	vassals()[str(i)] = {"since": Game.months_played}
	Game.relations[i] = maxf(Game.relations[i], E.ANNEX_VASSAL_RELATION)
	Game.relations_changed.emit()
	Game.add_milestone("%s became your vassal" % World.map.names[i], "crown", "gold")
	return "%s becomes your vassal: it keeps its flag but pays you tribute and follows your lead" % World.The_name(i)


## Yearly tribute from all vassals (dollars).
static func tribute() -> float:
	var t := 0.0
	for k in vassals():
		var v: CountryState = Game.state(int(k))
		if v != null:
			t += v.gdp * E.ANNEX_TRIBUTE
	return t


## Military of vassals that fights with you (added to allies in wars).
static func vassal_strength() -> float:
	var s := 0.0
	for k in vassals():
		var v: CountryState = Game.state(int(k))
		if v != null:
			s += v.military
	return s


## Monthly: tribute flows, vassals stay in line or break away. Headlines.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game():
		return out
	var me := Game.me()
	me.treasury += tribute() / 12.0
	for k in vassals().keys():
		var i := int(k)
		var v: CountryState = Game.state(i)
		if v == null:
			vassals().erase(k)
			continue
		Game.relations[i] = maxf(Game.relations[i] - 0.15, -100.0)     # resentment builds slowly
		var restless := v.military > me.military * 0.9 or Game.relations[i] < 0.0
		if restless and Game.rng.randf() < E.ANNEX_VASSAL_BREAK:
			vassals().erase(k)
			Game.relations[i] = -40.0
			out.append({"text": "%s breaks free and stops paying tribute" % World.The_name(i), "icon": "flag", "good": false})
	return out
