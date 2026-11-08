class_name WorldWars
extends RefCounted
## Wars between other countries. Hostile neighbours occasionally go to war;
## each month one battle on their front moves ground using the same rules as
## your wars (military^1.3 x morale, defender's edge). They end in a peace
## (often after outside mediation), with the winner sometimes keeping land.
## You can stay neutral, mediate, sell arms to one side, or join a war.
## State: Game.dip.world_wars {"a-b": {a, b, start, occ_a, occ_b, morale_a, morale_b, aided, last}}.

const E = preload("res://sim/economy.gd")


static func all() -> Dictionary:
	if not Game.dip.has("world_wars"):
		Game.dip["world_wars"] = {}
	return Game.dip.world_wars


static func key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


static func involving(i: int) -> Array:
	var out: Array = []
	for k in all():
		var w: Dictionary = all()[k]
		if int(w.a) == i or int(w.b) == i:
			out.append(w)
	return out


static func at_war(i: int) -> bool:
	return not involving(i).is_empty()


## Monthly: maybe start a war somewhere, fight battles, end wars.
## Returns headlines [{text, a, b, good}] for the feed.
static func monthly() -> Array:
	var out: Array = []
	_maybe_start(out)
	for k in all().keys():
		if not all().has(k):        # ended by an annexation earlier this month
			continue
		var w: Dictionary = all()[k]
		var a: CountryState = Game.state(int(w.a))
		var b: CountryState = Game.state(int(w.b))
		if a == null or b == null:
			all().erase(k)
			continue
		var sa := pow(maxf(a.military, 1.0), 1.3) * float(w.morale_a) * (1.0 + float(w.get("aid_a", 0.0)))
		var sb := pow(maxf(b.military, 1.0), 1.3) * float(w.morale_b) * E.WAR_DEFENDER_BONUS * (1.0 + float(w.get("aid_b", 0.0)))
		var a_wins := Game.rng.randf() < sa / maxf(sa + sb, 0.001)
		var swing := Game.rng.randf_range(E.WAR_SWING_MIN, E.WAR_SWING_MAX)
		if a_wins:
			if float(w.occ_a) > 0.0:
				w.occ_a = maxf(float(w.occ_a) - swing, 0.0)
			else:
				w.occ_b = minf(float(w.occ_b) + swing, E.WAR_MAX_OCC)
			w.morale_b = maxf(float(w.morale_b) - E.WAR_MORALE_HIT, 0.15)
		else:
			if float(w.occ_b) > 0.0:
				w.occ_b = maxf(float(w.occ_b) - swing, 0.0)
			else:
				w.occ_a = minf(float(w.occ_a) + swing, E.WAR_MAX_OCC)
			w.morale_a = maxf(float(w.morale_a) - E.WAR_MORALE_HIT, 0.15)
		w.morale_a = maxf(float(w.morale_a) - E.WAR_WEARINESS, 0.15)
		w.morale_b = maxf(float(w.morale_b) - E.WAR_WEARINESS, 0.15)
		a.military = maxf(a.military - Game.rng.randf_range(0.3, 1.0), 1.0)
		b.military = maxf(b.military - Game.rng.randf_range(0.3, 1.0), 1.0)
		a.shocks.growth = float(a.shocks.growth) - 0.6
		b.shocks.growth = float(b.shocks.growth) - 0.6
		a.shocks.stability = float(a.shocks.stability) - 0.5
		b.shocks.stability = float(b.shocks.stability) - 0.5
		w.last = {"m": Game.months_played, "a_wins": a_wins}
		# Ending: exhaustion, a clear win, or simply time.
		var months := Game.months_played - int(w.start)
		var done := float(w.occ_a) >= E.WAR_SURRENDER_OCC or float(w.occ_b) >= E.WAR_SURRENDER_OCC \
			or float(w.morale_a) <= 0.25 or float(w.morale_b) <= 0.25 or months > 30
		if done and Game.rng.randf() < 0.5:
			out.append(_end(k, w))
	return out


static func _maybe_start(out: Array) -> void:
	if Game.months_played < 6 or all().size() >= E.WORLD_WARS_MAX or Game.sandbox:
		return
	if Game.rng.randf() > E.WORLD_WAR_CHANCE * Difficulty.severity():
		return
	# Candidate pairs: neighbouring countries that already dislike each other
	# (rival camps), excluding the player.
	var best_a := -1
	var best_b := -1
	var tries := 0
	while tries < 40 and best_a < 0:
		tries += 1
		var a: int = World.playable[Game.rng.randi() % World.playable.size()]
		if a == Game.player or at_war(a):
			continue
		var nb := World.neighbours_of(a)
		if nb.is_empty():
			continue
		var b := World.sovereign_of(nb[Game.rng.randi() % nb.size()])
		if b < 0 or b == a or b == Game.player or not World.is_playable(b) or at_war(b):
			continue
		var ca := Treaties.base_camp(a)
		var cb := Treaties.base_camp(b)
		var hostile := (ca != cb and ca != "south" and cb != "south") or Game.rng.randf() < 0.15
		if not hostile:
			continue
		var sa: CountryState = Game.state(a)
		var sb: CountryState = Game.state(b)
		if sa == null or sb == null or sa.military < sb.military * 1.1:
			continue
		best_a = a
		best_b = b
	if best_a < 0:
		return
	all()[key(best_a, best_b)] = {"a": best_a, "b": best_b, "start": Game.months_played, "occ_a": 0.0, "occ_b": 0.0,
		"morale_a": 1.0, "morale_b": 1.0, "last": {}}
	out.append({"text": "War breaks out: %s invades %s" % [World.The_name(best_a), World.the_name(best_b)],
		"a": best_a, "b": best_b, "good": false, "start": true})


static func _end(k: String, w: Dictionary) -> Dictionary:
	var a := int(w.a)
	var b := int(w.b)
	var text := ""
	var sb: CountryState = Game.state(b)
	var swallowed := int(Game.dip.get("ai_absorbed", 0))
	if float(w.occ_b) >= E.WORLD_ABSORB_SHARE and float(w.morale_b) < float(w.morale_a) and sb != null \
			and sb.population < 1.5e7 and swallowed < E.WORLD_ABSORB_MAX and not Annexation.is_vassal(b) and Game.rng.randf() < 0.5:
		all().erase(k)
		Game.dip["ai_absorbed"] = swallowed + 1
		text = Annexation.absorb(b, a)
		return {"text": text, "a": a, "b": b, "good": false, "end": true, "absorbed": true}
	if float(w.occ_b) > 0.05 and float(w.morale_b) < float(w.morale_a):
		var frac := float(w.occ_b) * E.WAR_ANNEX_SHARE
		War._transfer(Game.state(b), Game.state(a), frac)
		War._mark_annexed(b, a, frac)
		text = "%s and %s make peace; %s keeps %d%% of %s" % [World.The_name(a), World.the_name(b), World.the_name(a),
			roundi(frac * 100.0), World.the_name(b)]
	elif float(w.occ_a) > 0.05 and float(w.morale_a) < float(w.morale_b):
		var frac2 := float(w.occ_a) * E.WAR_ANNEX_SHARE * 0.4      # a defender keeps only a buffer zone
		War._transfer(Game.state(a), Game.state(b), frac2)
		War._mark_annexed(a, b, frac2)
		text = "%s repels %s and takes %d%% of its land" % [World.The_name(b), World.the_name(a), roundi(frac2 * 100.0)]
	else:
		text = "%s and %s agree a ceasefire on the old borders" % [World.The_name(a), World.the_name(b)]
	all().erase(k)
	return {"text": text, "a": a, "b": b, "good": true, "end": true}


## You broker peace: both sides must be tired; relations with both rise.
static func can_mediate(w: Dictionary) -> bool:
	return Game.months_played - int(w.start) >= 4 and (float(w.morale_a) < 0.8 or float(w.morale_b) < 0.8)


static func mediate(k: String) -> String:
	var w: Dictionary = all().get(k, {})
	if w.is_empty():
		return ""
	var r := _end(k, {"a": w.a, "b": w.b, "occ_a": 0.0, "occ_b": 0.0, "morale_a": 1.0, "morale_b": 1.0})
	for side in [int(w.a), int(w.b)]:
		Diplomacy.change_relation(side, 12.0)
	for j in World.playable:
		if j != Game.player:
			Game.relations[j] = clampf(Game.relations[j] + 2.0, -100.0, 100.0)
	Game.relations_changed.emit()
	Game.me().shocks.approval = float(Game.me().shocks.approval) + 2.0
	Achievements.unlock("ceasefire")
	Game.add_milestone("Brokered peace between %s and %s" % [World.map.names[int(w.a)], World.map.names[int(w.b)]], "flag", "gold")
	return "Thanks to your mediation, " + str(r.text).left(1).to_lower() + str(r.text).substr(1)


## Sell arms to one side: money for you, strength for them, anger from the other.
static func sell_arms(k: String, side: int) -> float:
	var w: Dictionary = all().get(k, {})
	if w.is_empty():
		return 0.0
	var buyer: CountryState = Game.state(side)
	var other := int(w.b) if side == int(w.a) else int(w.a)
	var deal := minf(buyer.gdp * 0.004, Game.me().gdp * 0.01)
	Game.me().treasury += deal
	var akey := "aid_a" if side == int(w.a) else "aid_b"
	w[akey] = float(w.get(akey, 0.0)) + 0.15
	Diplomacy.change_relation(side, 10.0)
	Diplomacy.change_relation(other, -25.0)
	Game.add_feed("You sell %s worth of arms to %s" % [DS.money(deal), World.the_name(side)], "shield", "accent")
	return deal
