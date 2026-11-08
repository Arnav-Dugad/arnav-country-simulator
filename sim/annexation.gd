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
	# Its overseas territories go too (Greenland with Denmark).
	var terr: Array = []
	var liso := World.iso(loser)
	for t in World.count():
		if t != loser and str(World.stats[t].get("sovereign", "")) == liso and not owners().has(str(t)):
			owners()[str(t)] = winner
			terr.append(t)
	if not Game.dip.has("absorbed_info"):
		Game.dip["absorbed_info"] = {}
	Game.dip.absorbed_info[str(loser)] = {"pop": a.population, "gdp_share": a.gdp * E.ANNEX_GDP_KEEP / maxf(b.gdp, 1.0),
		"terr": terr, "m": Game.months_played, "peaceful": bool(Game.dip.get("_peaceful_absorb", false))}
	Game.countries[loser] = null
	World.set_owners(owners())
	var text := ""
	if winner == Game.player:
		if not Game.dip.has("integration"):
			Game.dip["integration"] = {}
		Game.dip.integration[str(loser)] = {"start": Game.months_played, "share": share}
		var peaceful := bool(Game.dip.get("_peaceful_absorb", false))
		if not peaceful:
			for j in World.playable:
				if j != Game.player:
					var hit := E.ANNEX_WORLD_ANGER * (1.5 if Treaties.base_camp(j) == Treaties.base_camp(loser) else 1.0)
					Game.relations[j] = clampf(Game.relations[j] - hit, -100.0, 100.0)
		else:
			Game.dip.integration[str(loser)].share = share * 0.3      # they chose this: far less unrest
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


## Your conquered or united lands: [{i, name, months, integration (0..1), peaceful}].
static func my_lands() -> Array:
	var out: Array = []
	for k in owners():
		if int(owners()[k]) != Game.player or not World.is_playable_raw(int(k)):
			continue
		var info: Dictionary = Game.dip.get("absorbed_info", {}).get(str(k), {})
		var it: Dictionary = Game.dip.get("integration", {}).get(str(k), {})
		var t := 1.0
		if not it.is_empty():
			t = clampf(float(Game.months_played - int(it.start)) / float(E.ANNEX_INTEGRATION_MONTHS), 0.0, 1.0)
		out.append({"i": int(k), "months": Game.months_played - int(info.get("m", Game.months_played)), "integration": t,
			"peaceful": bool(info.get("peaceful", false)), "pop": float(info.get("pop", 0.0))})
	return out


## Give a conquered country its independence back. Its people and a share of
## the economy leave; the world and the freed country are grateful.
static func release(i: int) -> String:
	if int(owners().get(str(i), -1)) != Game.player:
		return ""
	var me := Game.me()
	var info: Dictionary = Game.dip.get("absorbed_info", {}).get(str(i), {})
	var pop := minf(float(info.get("pop", me.population * 0.1)), me.population * 0.5)
	var gshare := clampf(float(info.get("gdp_share", 0.1)), 0.0, 0.5)
	var c := CountryState.new().init_from_stats(i, World.stats[i])
	var scale := pop / maxf(c.population, 1.0)
	c.population = pop
	c.gdp = me.gdp * gshare
	c.debt *= scale
	me.population = maxf(me.population - pop, 1.0)
	me.gdp = maxf(me.gdp - c.gdp, 1.0)
	Game.countries[i] = c
	owners().erase(str(i))
	for t in info.get("terr", []):
		owners().erase(str(t))
	Game.dip.get("integration", {}).erase(str(i))
	Game.dip.get("absorbed_info", {}).erase(str(i))
	World.set_owners(owners())
	Game.relations[i] = 45.0
	for j in World.playable:
		if j != Game.player and j != i:
			Game.relations[j] = clampf(Game.relations[j] + 4.0, -100.0, 100.0)
	Game.relations_changed.emit()
	me.shocks.approval = float(me.shocks.approval) - 2.0
	Simulation.update_finances(me)
	Simulation.update_finances(c)
	Game.add_milestone("Granted independence to %s" % World.map.names[i], "flag", "accent")
	var text := "%s is independent again. The world applauds" % World.The_name(i)
	Game.add_feed(text, "flag", "green")
	return text


## "" if you can propose a peaceful union with country i, else why not.
static func union_blocked(i: int) -> String:
	var me := Game.me()
	var c: CountryState = Game.state(i)
	if c == null or i == Game.player:
		return "Not possible"
	if not War.is_neighbour(i):
		return "Only with a neighbour"
	if Game.relations[i] < E.UNION_RELATION:
		return "Needs relations of %d+ (now %d)" % [int(E.UNION_RELATION), roundi(Game.relations[i])]
	if c.population > me.population * E.UNION_MAX_SIZE:
		return "They're too big to join you"
	if War.at_war():
		return "Not while you're at war"
	if not Capital.can(E.UNION_CAPITAL):
		return "Needs %d political capital" % int(E.UNION_CAPITAL)
	return ""


## Chance their people vote yes: relations, your wealth and stability vs theirs.
static func union_chance(i: int) -> float:
	var me := Game.me()
	var c: CountryState = Game.state(i)
	var richer := clampf(me.gdp_per_capita() / maxf(c.gdp_per_capita(), 1.0), 0.3, 3.0)
	var p := 0.25 + (Game.relations[i] - E.UNION_RELATION) / 30.0 + 0.15 * log(richer) / log(2.0) + (me.stability - c.stability) / 200.0
	if is_vassal(i):
		p += 0.25
	return clampf(p, 0.05, 0.9)


## Propose a union: they hold a referendum. Returns {ok, text}.
static func propose_union(i: int) -> Dictionary:
	if union_blocked(i) != "":
		return {"ok": false, "text": union_blocked(i)}
	Capital.spend(E.UNION_CAPITAL)
	if Game.rng.randf() < union_chance(i):
		Game.dip["_peaceful_absorb"] = true
		var t := absorb(i, Game.player)
		Game.dip.erase("_peaceful_absorb")
		Achievements.unlock("empire")
		return {"ok": true, "text": "Referendum passed! " + t}
	Game.relations[i] = Game.relations[i] - 15.0
	Game.relations_changed.emit()
	var text := "%s votes no to joining %s" % [World.The_name(i), World.the_name(Game.player)]
	Game.add_feed(text, "vote", "orange")
	return {"ok": false, "text": text}


static func vassal_annex_wait(i: int) -> int:
	var v: Dictionary = vassals().get(str(i), {})
	if v.is_empty():
		return -1
	return maxi(0, int(v.since) + E.VASSAL_ANNEX_MONTHS - Game.months_played)


## Absorb a long-time vassal without a war.
static func annex_vassal(i: int) -> String:
	if vassal_annex_wait(i) != 0 or not Capital.spend(E.VASSAL_ANNEX_CAPITAL):
		return ""
	Game.dip["_peaceful_absorb"] = true
	var t := absorb(i, Game.player)
	Game.dip.erase("_peaceful_absorb")
	for j in World.playable:
		if j != Game.player:
			Game.relations[j] = clampf(Game.relations[j] - E.ANNEX_WORLD_ANGER * 0.3, -100.0, 100.0)
	return t


static func free_vassal(i: int) -> void:
	vassals().erase(str(i))
	Game.relations[i] = clampf(Game.relations[i] + 25.0, -100.0, 100.0)
	for j in World.playable:
		if j != Game.player and j != i:
			Game.relations[j] = clampf(Game.relations[j] + 1.5, -100.0, 100.0)
	Game.relations_changed.emit()
	Game.add_feed("%s is free: no more tribute" % World.The_name(i), "flag", "green")


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
