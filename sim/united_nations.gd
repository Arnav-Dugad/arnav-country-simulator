class_name UnitedNations
extends RefCounted
## The United Nations.
##   Standing     your reputation in the General Assembly (0..100): how you vote,
##                peacekeepers you send, aid, wars you start, annexations.
##   Security     five permanent members (USA, China, Russia, UK, France) with a
##   Council      veto; ten elected seats for two years. Campaign for a seat:
##                the vote is about standing and friends. Members get a say on
##                sanctions and peacekeeping, and prestige.
##   Resolutions  propose your own: condemn an aggressor (sanctions), a ceasefire
##                in a world war, a climate fund, a global health fund, a ban on
##                a weapon. Pass the Assembly by winning votes; anything with
##                teeth can be vetoed by a permanent member whose friend it hurts.
##   Peacekeepers send troops to a UN mission: standing and goodwill, a small
##                cost and a small risk to your soldiers.
## State: Game.dip.un {standing, council_until, campaign_m, resolutions: [...], keepers, last_res_m}.
## Constants in sim/economy.gd (UN_*).

const E = preload("res://sim/economy.gd")

const P5 := ["USA", "CHN", "RUS", "GBR", "FRA"]

const RESOLUTIONS := {
	"condemn": {"title": "Condemn an aggressor", "icon": "gavel", "needs_war": true, "veto": true,
		"desc": "Sanctions on a country that invaded another."},
	"ceasefire": {"title": "Demand a ceasefire", "icon": "flag", "needs_war": true, "veto": true,
		"desc": "Call for an end to a war between other countries."},
	"climate": {"title": "Global climate fund", "icon": "leaf", "veto": false,
		"desc": "Rich countries pay into a fund for climate damage."},
	"health": {"title": "Global health fund", "icon": "heart-pulse", "veto": false,
		"desc": "Vaccines and clinics for the poorest countries."},
	"arms": {"title": "Ban killer robots", "icon": "shield-off", "veto": true,
		"desc": "A treaty against fully autonomous weapons."},
}


static func st() -> Dictionary:
	if not Game.dip.has("un"):
		Game.dip["un"] = {"standing": start_standing(), "council_until": -1, "campaign_m": -99, "keepers": false,
			"keepers_m": -1, "last_res_m": -99, "log": []}
	return Game.dip.un


static func start_standing() -> float:
	var c := Game.me()
	var voice := World.stat(Game.player, "voice_wgi", 0.0)
	return clampf(52.0 + 8.0 * voice + (Corruption.value(c) - 50.0) * 0.15 if c != null else 50.0, 15.0, 85.0)


static func standing() -> float:
	return float(st().standing)


static func add_standing(v: float) -> void:
	st().standing = clampf(standing() + v, 0.0, 100.0)


static func permanent() -> bool:
	return World.iso(Game.player) in P5


static func on_council() -> bool:
	return permanent() or Game.months_played < int(st().council_until)


# --------------------------------------------------------------- council seat ---
static func seat_blocked() -> String:
	if on_council():
		return "Already on the Security Council"
	var wait := int(st().campaign_m) + 24 - Game.months_played
	if wait > 0:
		return "Next election in %d months" % wait
	if not Capital.can(E.UN_SEAT_CAPITAL):
		return "Needs %d political capital" % int(E.UN_SEAT_CAPITAL)
	return ""


static func seat_chance() -> float:
	var friends := 0
	for j in World.playable:
		if j != Game.player and Game.relations[j] >= 30.0:
			friends += 1
	var p := 0.15 + (standing() - 50.0) / 80.0 + float(friends) / float(maxi(World.playable.size(), 1)) * 0.8
	if War.at_war():
		p -= 0.25
	return clampf(p, 0.05, 0.9)


static func campaign() -> Dictionary:
	if seat_blocked() != "":
		return {}
	Capital.spend(E.UN_SEAT_CAPITAL)
	var s := st()
	s.campaign_m = Game.months_played
	if Game.rng.randf() < seat_chance():
		s.council_until = Game.months_played + 24
		add_standing(3.0)
		Game.me().shocks.approval = float(Game.me().shocks.approval) + 1.5
		Game.add_milestone("Elected to the UN Security Council", "landmark", "gold")
		return {"ok": true, "text": "%s wins a seat on the UN Security Council for two years" % World.The_name(Game.player)}
	return {"ok": false, "text": "The General Assembly chooses others for the Security Council this time"}


# ---------------------------------------------------------------- resolutions ---
## Wars between other countries you could target: [[key, aggressor, victim]].
static func world_wars() -> Array:
	var out: Array = []
	for k in WorldWars.all():
		var w: Dictionary = WorldWars.all()[k]
		out.append([str(k), int(w.a), int(w.b)])
	return out


static func res_blocked(id: String) -> String:
	if Game.months_played - int(st().last_res_m) < E.UN_RES_GAP:
		return "One resolution every %d months: next in %d" % [E.UN_RES_GAP, int(st().last_res_m) + E.UN_RES_GAP - Game.months_played]
	if bool(RESOLUTIONS[id].get("needs_war", false)) and world_wars().is_empty():
		return "No war between other countries right now"
	if not Capital.can(E.UN_RES_CAPITAL):
		return "Needs %d political capital" % int(E.UN_RES_CAPITAL)
	return ""


## Who would veto: a permanent member that is (or likes) the target.
static func veto_by(id: String, target: int) -> int:
	if not bool(RESOLUTIONS[id].veto):
		return -1
	for iso in P5:
		var p := World.index_of(iso)
		if p < 0 or p == Game.player or Game.state(p) == null:
			continue
		if id == "arms" and iso in ["USA", "CHN", "RUS"]:
			return p
		if target >= 0 and (p == target or Treaties.base_camp(p) == Treaties.base_camp(target)) and Treaties.base_camp(target) != "south":
			return p
	return -1


## Chance it passes the Assembly (before any veto).
static func pass_chance(id: String) -> float:
	var p := 0.35 + (standing() - 50.0) / 70.0
	if on_council():
		p += 0.1
	match id:
		"climate", "health":
			p += 0.15
		"arms":
			p += 0.05
	return clampf(p, 0.05, 0.92)


static func propose(id: String, target_key: String = "") -> Dictionary:
	var why := res_blocked(id)
	if why != "":
		return {"ok": false, "text": why}
	Capital.spend(E.UN_RES_CAPITAL)
	var s := st()
	s.last_res_m = Game.months_played
	var target := -1
	var victim := -1
	if target_key != "" and WorldWars.all().has(target_key):
		target = int(WorldWars.all()[target_key].a)
		victim = int(WorldWars.all()[target_key].b)
	var title := str(RESOLUTIONS[id].title)
	if Game.rng.randf() > pass_chance(id):
		add_standing(-1.0)
		return _log({"ok": false, "text": "The General Assembly votes down your resolution: %s" % title.to_lower()})
	var v := veto_by(id, target)
	if v >= 0:
		add_standing(1.0)
		Diplomacy.change_relation(v, -6.0)
		return _log({"ok": false, "text": "Passed by the Assembly, but %s vetoes it in the Security Council" % World.the_name(v)})
	var c := Game.me()
	match id:
		"condemn":
			var t: CountryState = Game.state(target)
			if t != null:
				t.shocks.growth = float(t.shocks.growth) - 2.0
				t.shocks.stability = float(t.shocks.stability) - 3.0
				if WorldWars.all().has(target_key):
					WorldWars.all()[target_key].morale_a = maxf(float(WorldWars.all()[target_key].morale_a) - 0.2, 0.15)
			Diplomacy.change_relation(target, -15.0)
			if victim >= 0:
				Diplomacy.change_relation(victim, 15.0)
		"ceasefire":
			if WorldWars.all().has(target_key):
				var w: Dictionary = WorldWars.all()[target_key]
				WorldWars.all().erase(target_key)
				Game.add_feed("UN ceasefire holds: %s and %s stop fighting" % [World.The_name(int(w.a)), World.the_name(int(w.b))], "flag", "green")
				for side in [int(w.a), int(w.b)]:
					Diplomacy.change_relation(side, 5.0)
		"climate":
			c.treasury -= c.gdp * E.UN_FUND_COST / 100.0
			for j in World.playable:
				if j != Game.player and Treaties.base_camp(j) == "south":
					Game.relations[j] = clampf(Game.relations[j] + 4.0, -100.0, 100.0)
		"health":
			c.treasury -= c.gdp * E.UN_FUND_COST / 100.0
			for j in World.playable:
				if j != Game.player and Economy.income_level(Game.state(j).gdp_per_capita() if Game.state(j) != null else 1.0) < 0.35:
					Game.relations[j] = clampf(Game.relations[j] + 4.0, -100.0, 100.0)
		"arms":
			c.shocks.happiness = float(c.shocks.happiness) + 1.0
	Game.relations_changed.emit()
	add_standing(E.UN_PASS_STANDING)
	c.shocks.approval = float(c.shocks.approval) + 1.0
	Game.add_milestone("UN resolution passed: %s" % title.to_lower(), str(RESOLUTIONS[id].icon), "gold")
	return _log({"ok": true, "text": "Your UN resolution passes: %s" % title.to_lower()})


static func _log(r: Dictionary) -> Dictionary:
	var lg: Array = st().log
	lg.push_front({"text": str(r.text), "ok": bool(r.ok), "m": Game.months_played})
	if lg.size() > 6:
		lg.resize(6)
	Game.add_feed(str(r.text), "landmark", "gold" if bool(r.ok) else "orange")
	return r


# ---------------------------------------------------------------- peacekeepers ---
static func set_keepers(on: bool) -> void:
	var s := st()
	s.keepers = on
	if on:
		s.keepers_m = Game.months_played
		Game.add_feed("Your soldiers join a UN peacekeeping mission", "shield", "accent")


static func keepers_cost_pct() -> float:
	if not Game.has_game() or not Game.dip.has("un"):
		return 0.0
	return E.UN_KEEPERS_COST if bool(st().keepers) else 0.0


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	# Standing drifts back toward where your conduct puts it.
	var target := start_standing()
	if bool(s.keepers):
		target += 8.0
	if War.at_war():
		for k in War.wars():
			if bool(War.wars()[k].attacker_me):
				target -= 12.0
	target -= 6.0 * float((Game.dip.get("owners", {}) as Dictionary).values().count(Game.player))
	if Game.dip.has("tour"):
		target += (Tourism.soft_power(Game.player) - 50.0) * 0.2
	s.standing = standing() + (clampf(target, 0.0, 100.0) - standing()) * 0.04
	if bool(s.keepers) and Game.rng.randf() < E.UN_KEEPERS_RISK:
		var c := Game.me()
		c.shocks.approval = float(c.shocks.approval) - 1.0
		out.append({"text": "Peacekeepers from %s killed in an ambush abroad" % World.the_name(Game.player), "icon": "shield", "good": false})
	if int(s.council_until) == Game.months_played and not permanent():
		out.append({"text": "Your two years on the Security Council come to an end", "icon": "landmark", "good": true})
	return out


## Soft power and relations nudge from standing (used by Tourism).
static func prestige() -> float:
	return (standing() - 50.0) * 0.1 + (3.0 if on_council() else 0.0)
