class_name Nuclear
extends RefCounted
## Nuclear weapons, kept to deterrence and diplomacy (there is no button to use
## them). Nine countries start with real arsenals (SIPRI 2024 estimates). Others
## are bound by the Non-Proliferation Treaty; a secret programme takes years,
## costs money and risks discovery and sanctions. Nuclear powers can cut or give
## up their arsenals, and every few years arms-control talks come round.
## The Doomsday Clock (seconds to midnight, 89 in 2025) is the world's mood:
## programmes, tests and wars move it closer; disarmament moves it back.
## Effects only count change since you took office.
## State: Game.dip.nuke {w, w0, npt, prog {start, months, secret, found}, clock, cut (month), talks (month), gave}.
## Constants in sim/economy.gd (NUC_*).

const E = preload("res://sim/economy.gd")

const ARSENAL := {"RUS": 5580, "USA": 5044, "CHN": 500, "FRA": 290, "GBR": 225, "IND": 172, "PAK": 170, "ISR": 90, "PRK": 50}
## Threshold states that might build the bomb during a game (rare).
const THRESHOLD := ["IRN", "SAU", "TUR", "EGY", "KOR"]
## Never joined the NPT (or left it).
const OUTSIDE_NPT := ["IND", "PAK", "ISR", "PRK", "SSD"]


static func st() -> Dictionary:
	if not Game.dip.has("nuke"):
		var iso := World.iso(Game.player)
		var w := int(ARSENAL.get(iso, 0))
		Game.dip["nuke"] = {"w": w, "w0": w, "npt": not (iso in OUTSIDE_NPT), "prog": {}, "clock": E.NUC_CLOCK_START,
			"cut": -99, "talks": Game.months_played, "gave": 0}
	return Game.dip.nuke


static func warheads(i: int) -> int:
	if i == Game.player and Game.dip.has("nuke"):
		return int(st().w)
	if World.is_absorbed(i):
		return 0
	if Game.has_game() and Game.dip.has("nuke"):
		var ai: Dictionary = st().get("ai", {})
		if ai.has(World.iso(i)):
			return int(ai[World.iso(i)])
	return int(ARSENAL.get(World.iso(i), 0))


static func armed() -> bool:
	return Game.has_game() and Game.dip.has("nuke") and int(st().w) > 0


static func clock() -> float:
	return float(st().clock)


static func clock_text() -> String:
	var s := roundi(clock())
	return "%d seconds to midnight" % s if s < 120 else "%s minutes to midnight" % String.num(s / 60.0, 1)


static func move_clock(sec: float) -> void:
	st().clock = clampf(clock() + sec, 10.0, 600.0)


## Nuclear deterrence gained or lost since you took office (feeds Security).
static func deter_bonus() -> float:
	if not Game.has_game() or not Game.dip.has("nuke"):
		return 0.0
	var now := 1.0 if int(st().w) > 0 else 0.0
	var then := 1.0 if int(st().w0) > 0 else 0.0
	return E.NUC_DETER * (now - then)


## A hostile neighbour won't invade a nuclear power.
static func deters_invasion() -> bool:
	return armed()


# --------------------------------------------------------------- programme ---
static func building() -> bool:
	return not (st().prog as Dictionary).is_empty()


static func prog_months() -> int:
	var c := Game.me()
	var m := E.NUC_PROG_MONTHS
	if Projects.is_done(c, "nuclear") or (not c.builds.is_empty() and Builds.count(c, "nuclear_reactor") > 0):
		m -= 24
	return m


static func progress() -> float:
	var p: Dictionary = st().prog
	if p.is_empty():
		return 0.0
	return clampf(float(Game.months_played - int(p.start)) / float(p.months), 0.0, 1.0)


static func blocked() -> String:
	if armed():
		return "You already have nuclear weapons"
	if building():
		return "Your programme is under way"
	if Treaties.is_member(Game.player, "tpnw"):
		return "You signed the Nuclear Weapons Ban"
	if Game.me().gdp < E.NUC_MIN_GDP:
		return "Needs an economy above %s" % DS.money(E.NUC_MIN_GDP)
	if not Capital.can(E.NUC_CAPITAL):
		return "Needs %d political capital" % int(E.NUC_CAPITAL)
	return ""


## secret = keep it hidden while still in the treaty (risk of discovery);
## otherwise you leave the NPT openly first.
static func start(secret: bool) -> bool:
	if blocked() != "" or not Capital.spend(E.NUC_CAPITAL):
		return false
	var s := st()
	if not secret and bool(s.npt):
		s.npt = false
		_relations_all(-E.NUC_LEAVE_RELATIONS)
		move_clock(-5.0)
		Game.add_milestone("Left the Non-Proliferation Treaty", "atom", "red")
		Game.intel_news.emit({"text": "%s leaves the Non-Proliferation Treaty" % World.The_name(Game.player), "icon": "atom", "good": false, "big": true})
	s.prog = {"start": Game.months_played, "months": prog_months(), "secret": secret and bool(s.npt), "found": false}
	return true


static func abandon() -> void:
	st().prog = {}
	move_clock(3.0)


static func spending_pct() -> float:
	if not Game.has_game() or not Game.dip.has("nuke"):
		return 0.0
	var p := E.NUC_PROG_COST if building() else 0.0
	# Upkeep only for an arsenal you built; savings for one you cut.
	var w := int(st().w)
	var w0 := int(st().w0)
	if w0 == 0 and w > 0:
		p += E.NUC_UPKEEP
	elif w0 > 0 and w < w0:
		p -= E.NUC_UPKEEP * (1.0 - float(w) / float(w0)) * 0.6
	return p


# ----------------------------------------------------------------- arsenal ---
static func can_cut() -> bool:
	return armed() and Game.months_played - int(st().cut) >= 48 and Capital.can(E.NUC_CUT_CAPITAL)


## Halve the arsenal (or give it all up).
static func cut(all: bool) -> bool:
	if not can_cut() or not Capital.spend(E.NUC_CUT_CAPITAL * (2.0 if all else 1.0)):
		return false
	var s := st()
	s.cut = Game.months_played
	s.w = 0 if all or int(s.w) <= 20 else int(s.w) / 2
	s.gave = int(s.gave) + 1
	move_clock(15.0 if int(s.w) == 0 else 7.0)
	_relations_all(8.0 if int(s.w) == 0 else 3.0)
	if int(s.w) == 0:
		s.npt = true
		Achievements.unlock("ploughshares")
		Game.add_milestone("Gave up nuclear weapons", "handshake", "green")
		Game.intel_news.emit({"text": "%s gives up its nuclear weapons and rejoins the treaty" % World.The_name(Game.player), "icon": "handshake", "good": true, "big": true, "celebrate": true})
	else:
		Game.add_feed("Arsenal halved to %d warheads" % int(s.w), "atom", "green")
	return true


static func _relations_all(v: float) -> void:
	for i in Game.relations.size():
		if i != Game.player:
			Game.relations[i] = clampf(Game.relations[i] + v, -100.0, 100.0)
	Game.relations_changed.emit()


# -------------------------------------------------------------------- events ---
static func found_event() -> Dictionary:
	return {"id": "nuke_found", "title": "Inspectors find your programme", "icon": "atom", "tint": "red", "other": -1,
		"next": {}, "face": "", "scene_hint": "",
		"body": "International inspectors have found evidence of %s's secret nuclear weapons programme. The great powers threaten sanctions." % World.the_name(Game.player),
		"choices": [
			{"label": "Abandon it", "detail": "Inspectors verify · relations recover a little", "effects": {"nuke": "abandon", "approval": -1.0}},
			{"label": "Press on, openly", "detail": "Leave the treaty · sanctions from the West · relations fall", "effects": {"nuke": "press", "stability": 1.0}},
		]}


static func talks_event() -> Dictionary:
	return {"id": "arms_talks", "title": "Arms-control talks", "icon": "handshake", "tint": "accent", "other": -1,
		"next": {}, "face": "", "scene_hint": "",
		"body": "The nuclear powers meet in Geneva. A new treaty would cut every arsenal by a fifth, with inspections.",
		"choices": [
			{"label": "Sign the treaty", "detail": "Arsenal −20% · relations up · the clock moves back", "effects": {"nuke": "sign", "approval": 1.0}},
			{"label": "Walk away", "detail": "Keep every warhead · the clock moves closer", "effects": {"nuke": "walk"}},
		]}


static func score(v: String) -> float:
	match v:
		"abandon", "sign":
			return 2.0
		"press":
			return -3.0
	return 0.0


static func apply(v: String) -> void:
	var s := st()
	match v:
		"abandon":
			abandon()
			_relations_all(3.0)
			Game.add_feed("Nuclear programme abandoned under inspection", "atom", "accent")
		"press":
			s.npt = false
			(s.prog as Dictionary)["secret"] = false
			_relations_all(-E.NUC_LEAVE_RELATIONS)
			move_clock(-8.0)
			for iso in ["USA", "GBR", "FRA", "DEU", "JPN"]:
				var i := World.index_of(iso)
				if i >= 0 and i != Game.player and not Diplomacy.has_alliance(i):
					Game.dip.sanctioned_by[str(i)] = Game.months_played
			Game.add_milestone("Sanctioned over nuclear weapons", "atom", "red")
		"sign":
			s.w = int(int(s.w) * 0.8)
			move_clock(5.0)
			_relations_all(2.0)
			Game.add_feed("Arms-control treaty signed: %d warheads left" % int(s.w), "handshake", "green")
		"walk":
			move_clock(-4.0)
			Game.add_feed("Arms-control talks collapse", "atom", "orange")


# ------------------------------------------------------------------- monthly ---
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "nuke"])
	# The world's mood: wars push the clock forward, peace lets it ease back.
	var wars := WorldWars.all().size()
	move_clock(-0.15 * maxf(wars - 1, 0) + (0.08 if wars == 0 else 0.0))
	if clock() >= 150.0:
		Achievements.unlock("midnight")
	var p: Dictionary = s.prog
	if not p.is_empty():
		if bool(p.secret) and not bool(p.found) and r.randf() < E.NUC_DETECT:
			p.found = true
			Game.director.add(found_event())
			out.append({"text": "Inspectors uncover %s's secret nuclear programme" % World.the_name(Game.player), "icon": "atom", "good": false, "big": true})
		elif progress() >= 1.0:
			s.prog = {}
			s.w = E.NUC_FIRST_ARSENAL
			s.npt = false
			move_clock(-10.0)
			_relations_all(-6.0)
			var c := Game.me()
			c.shocks.approval = float(c.shocks.approval) + 3.0
			Game.add_milestone("Became a nuclear power", "atom", "orange")
			out.append({"text": "%s tests its first nuclear weapon. The world condemns it; no neighbour will dare attack." % World.The_name(Game.player),
				"icon": "atom", "good": false, "big": true})
	# Proliferation: a threshold state may test its first weapon (rare).
	if Game.months_played >= 36 and r.randf() < E.NUC_AI_PROLIF:
		var ai: Dictionary = s.get("ai", {})
		var cand: Array = []
		for iso in THRESHOLD:
			var j := World.index_of(str(iso))
			if j >= 0 and j != Game.player and not ai.has(iso) and not World.is_absorbed(j):
				cand.append(iso)
		if not cand.is_empty():
			var iso2: String = cand[r.randi() % cand.size()]
			ai[iso2] = E.NUC_FIRST_ARSENAL
			s["ai"] = ai
			move_clock(-10.0)
			var j2 := World.index_of(iso2)
			if Game.relations[j2] < -20.0:
				Game.me().shocks.stability = float(Game.me().shocks.stability) - 1.0
			out.append({"text": "%s tests its first nuclear weapon. The Doomsday Clock moves closer to midnight." % World.The_name(j2),
				"icon": "atom", "good": false, "big": true})
	# Arms-control talks about every five years for nuclear powers.
	if armed() and Game.months_played - int(s.talks) >= 60 and Game.month == 6:
		s.talks = Game.months_played
		var open := false
		for ev in Game.director.inbox:
			open = open or str(ev.get("id", "")) == "arms_talks"
		if not open:
			Game.director.add(talks_event())
	return out


## Effects on the national targets (change since you took office only).
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("nuke"):
		return {}
	var d := clock() - E.NUC_CLOCK_START
	# A world closer to midnight is an anxious one.
	return {"happiness": clampf(d / 60.0, -1.0, 0.6), "growth": clampf(d / 400.0, -0.2, 0.1)}


static func prestige() -> float:
	if not Game.dip.has("nuke"):
		return 0.0
	return float(st().gave) * 3.0
