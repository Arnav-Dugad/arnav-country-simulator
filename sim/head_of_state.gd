class_name HeadOfState
extends RefCounted
## The head of state.
##   Monarchies   a royal family: the monarch (age, popularity), an heir, a
##                royal wedding, births, a jubilee, scandals and, when the
##                monarch dies or abdicates, a succession: the heir takes the
##                throne (and the people rally) or, with no heir, a crisis.
##                Constitutional monarchies can hold a referendum on becoming a
##                republic; absolute monarchs can name a different heir.
##   Republics    your own family in public life: a spouse with a cause,
##                children, the occasional scandal, and your health as you age.
## The family's popularity (0..100) adds a little approval, stability and
## soft power, or costs them in a scandal.
## State: Game.dip.hos {kind, monarch: {name, born, female}, heir: {...} | {}, pop,
## last_ev, jubilee, wed}. Constants in sim/economy.gd (HOS_*).

const E = preload("res://sim/economy.gd")


static func is_monarchy() -> bool:
	return Government.kind(Game.player) in ["monarchy", "monarchy_parl"]


static func st() -> Dictionary:
	if not Game.dip.has("hos"):
		Game.dip["hos"] = _fresh()
	return Game.dip.hos


static func _person(seed_v: int, age: int, female: bool) -> Dictionary:
	return {"name": Names.full(Game.player, seed_v, seed_v / 7 if is_monarchy() else seed_v * 3), "born": Game.year - age, "female": female}


static func _fresh() -> Dictionary:
	var h := absi(hash(World.iso(Game.player) + "royal"))
	var royal := is_monarchy()
	var monarch := _person(h, 50 + h % 30, h % 3 == 0)
	var heir := _person(h + 11, 20 + h % 25, h % 2 == 0) if royal else {}
	if royal:
		heir["name"] = str(heir.name).split(" ")[0] + " " + str(monarch.name).split(" ")[-1]
	var spouse := _person(h + 5, 40 + h % 15, h % 2 == 1)
	return {"royal": royal, "monarch": monarch, "heir": heir, "spouse": spouse, "pop": 60.0 + float(h % 20),
		"last_ev": Game.months_played, "jubilee": -1, "wed": false, "children": 1 + h % 3, "cause": ["literacy", "mental health", "clean oceans", "children's hospitals", "the arts"][h % 5]}


static func age(p: Dictionary) -> int:
	return Game.year - int(p.get("born", Game.year))


static func pop() -> float:
	return float(st().pop)


static func title(p: Dictionary) -> String:
	if not bool(st().royal):
		return ""
	return "Queen" if bool(p.get("female", false)) else "King"


## Monthly: aging, rare family events, popularity drift. Returns event dicts for the inbox.
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	s.pop = float(s.pop) + (62.0 - float(s.pop)) * 0.02
	if Game.months_played - int(s.last_ev) < E.HOS_EVENT_GAP or Game.rng.randf() > E.HOS_EVENT_CHANCE:
		return out
	s.last_ev = Game.months_played
	var ev := _pick_event()
	if not ev.is_empty():
		out.append(ev)
	return out


static func _pick_event() -> Dictionary:
	var s := st()
	var m: Dictionary = s.monarch
	var heir: Dictionary = s.heir
	var royal := bool(s.royal)
	var options: Array = []
	if royal:
		var a := age(m)
		if a >= 70 and Game.rng.randf() < 0.25 + 0.04 * (a - 70):
			return _succession(a >= 82 and Game.rng.randf() < 0.6)
		if not heir.is_empty() and not bool(s.wed) and age(heir) >= 24:
			options.append("wedding")
		if bool(s.wed) and int(s.children) < 4:
			options.append("royal_baby")
		if a >= 60 and int(s.jubilee) < 0:
			options.append("jubilee")
		options.append_array(["royal_scandal", "royal_tour", "royal_charity"])
		if Government.kind(Game.player) == "monarchy_parl" and float(s.pop) < 45.0:
			options.append("republic_vote")
	else:
		options.append_array(["spouse_cause", "family_scandal", "health_scare", "family_charity"])
	return _event(str(options[Game.rng.randi() % options.size()]))


static func _event(kind: String) -> Dictionary:
	var s := st()
	var m: Dictionary = s.monarch
	var heir: Dictionary = s.heir
	var sp: Dictionary = s.spouse
	var e := {}
	match kind:
		"wedding":
			e = {"id": "hos_wedding", "title": "A royal wedding", "icon": "heart", "tint": "gold",
				"body": "%s is to marry. The palace asks how grand the celebration should be." % str(heir.name),
				"choices": [
					{"label": "A grand state wedding", "detail": "A national holiday · costly · tourists flock", "effects": {"hos_pop": 10.0, "happiness": 2.5, "cost": 0.05, "hos": "wed"}},
					{"label": "A modest ceremony", "detail": "Thrifty and popular with some", "effects": {"hos_pop": 4.0, "happiness": 1.0, "hos": "wed"}}]}
		"royal_baby":
			e = {"id": "hos_baby", "title": "A royal baby", "icon": "baby", "tint": "gold",
				"body": "The palace announces the birth of a new prince or princess. Crowds gather outside the gates.",
				"choices": [{"label": "Celebrate", "detail": "Bells ring across the country", "effects": {"hos_pop": 6.0, "happiness": 1.5, "hos": "baby"}}]}
		"jubilee":
			e = {"id": "hos_jubilee", "title": "The %s's jubilee" % title(m).to_lower(), "icon": "crown", "tint": "gold",
				"body": "%s %s marks decades on the throne. Should the nation celebrate?" % [title(m), str(m.name)],
				"choices": [
					{"label": "Four-day national celebration", "detail": "Street parties and a holiday", "effects": {"hos_pop": 8.0, "happiness": 3.0, "growth": -0.2, "cost": 0.04, "hos": "jubilee"}},
					{"label": "A quiet service", "detail": "", "effects": {"hos_pop": 2.0, "hos": "jubilee"}}]}
		"royal_scandal":
			e = {"id": "hos_scandal", "title": "Palace scandal", "icon": "newspaper", "tint": "red",
				"body": "Newspapers reveal a royal's secret business deals with a foreign tycoon. The public is furious.",
				"choices": [
					{"label": "Strip them of their titles", "detail": "Firm and popular · the family is shaken", "effects": {"hos_pop": 4.0, "approval": 1.0}},
					{"label": "Let the palace handle it", "detail": "Quiet · the anger lingers", "effects": {"hos_pop": -10.0, "approval": -1.0}},
					{"label": "Defend the family", "detail": "Loyal · costly", "effects": {"hos_pop": -4.0, "approval": -2.5, "press_cred": -4.0}}]}
		"royal_tour":
			e = {"id": "hos_tour", "title": "A royal tour abroad", "icon": "plane", "tint": "accent",
				"body": "The palace offers to send %s on a world tour to promote trade and goodwill." % str(heir.name if not heir.is_empty() else m.name),
				"choices": [
					{"label": "Send them", "detail": "Friends abroad · a little costly", "effects": {"relations_all": 2.0, "hos_pop": 3.0, "cost": 0.02}},
					{"label": "Not now", "detail": "", "effects": {}}]}
		"royal_charity", "family_charity":
			e = {"id": "hos_charity", "title": "A cause close to the family", "icon": "heart-handshake", "tint": "green",
				"body": "%s wants to launch a national campaign for %s, and asks for government backing." % [str(sp.name) if kind == "family_charity" else str(heir.name if not heir.is_empty() else m.name), str(s.cause)],
				"choices": [
					{"label": "Back it with public money", "detail": "Popular · costs a little", "effects": {"hos_pop": 5.0, "happiness": 1.0, "cost": 0.03}},
					{"label": "Let them raise it privately", "detail": "", "effects": {"hos_pop": 1.0}}]}
		"republic_vote":
			e = {"id": "hos_republic", "title": "Calls for a republic", "icon": "vote", "tint": "orange",
				"body": "With the monarchy's popularity at %d%%, a movement demands a referendum on becoming a republic." % roundi(float(s.pop)),
				"choices": [
					{"label": "Hold the referendum", "detail": "The people decide · a big moment either way", "effects": {"hos": "referendum"}},
					{"label": "Reform the monarchy instead", "detail": "Cut the royal budget and slim the family", "effects": {"hos_pop": 8.0, "approval": 1.0}},
					{"label": "Refuse", "detail": "Republicans are angry", "effects": {"approval": -2.0, "stability": -1.0}}]}
		"spouse_cause":
			e = {"id": "hos_spouse", "title": "Your spouse's campaign", "icon": "heart-handshake", "tint": "accent",
				"body": "%s wants to use their profile to campaign for %s." % [str(sp.name), str(s.cause)],
				"choices": [
					{"label": "Encourage them", "detail": "A popular cause", "effects": {"approval": 1.5, "happiness": 0.5}},
					{"label": "Keep the family out of politics", "detail": "", "effects": {}}]}
		"family_scandal":
			e = {"id": "hos_fscandal", "title": "Family trouble", "icon": "newspaper", "tint": "red",
				"body": "Your adult child is photographed at a lavish party paid for by a company with government contracts.",
				"choices": [
					{"label": "Apologise and repay it", "detail": "Honest · a short sting", "effects": {"approval": -1.0, "press_cred": 3.0}},
					{"label": "Call it a private matter", "detail": "It drags on", "effects": {"approval": -3.0, "press_cred": -3.0}}]}
		"health_scare":
			e = {"id": "hos_health", "title": "A health scare", "icon": "heart-pulse", "tint": "orange",
				"body": "You collapse at an event and spend a night in hospital. Doctors say it was exhaustion.",
				"choices": [
					{"label": "Be open about it", "detail": "Sympathy · questions about your stamina", "effects": {"approval": 1.0, "press_cred": 3.0}},
					{"label": "Back to work tomorrow", "detail": "Looks strong · risky", "effects": {"approval": 0.5, "stability": -0.5}}]}
	if e.is_empty():
		return {}
	e["weight"] = 0.0
	return GameEvents.instance(e)


## The monarch dies or abdicates.
static func _succession(death: bool) -> Dictionary:
	var s := st()
	var m: Dictionary = s.monarch
	var heir: Dictionary = s.heir
	var body := ("%s %s has died at %d after a long reign. The nation mourns." if death else "%s %s, now %d, announces their abdication.") % [title(m), str(m.name), age(m)]
	var e := {"id": "hos_succession", "title": "The monarch has died" if death else "An abdication", "icon": "crown", "tint": "gold", "weight": 0.0,
		"body": body + (" %s will succeed to the throne." % str(heir.name) if not heir.is_empty() else " There is no clear heir."),
		"choices": [
			{"label": "A grand coronation", "detail": "The nation rallies · costly", "effects": {"hos": "succeed", "hos_pop": 12.0, "approval": 2.0, "happiness": 2.0, "cost": 0.06}},
			{"label": "A simple, modern ceremony", "detail": "Thrifty", "effects": {"hos": "succeed", "hos_pop": 5.0}}]}
	return GameEvents.instance(e)


## Effect keys used by the events above (called from GameEvents.apply_effects).
static func apply(key: String, v: Variant) -> void:
	var s := st()
	match key:
		"hos_pop":
			s.pop = clampf(float(s.pop) + float(v), 0.0, 100.0)
		"hos":
			match str(v):
				"wed":
					s.wed = true
				"baby":
					s.children = int(s.children) + 1
				"jubilee":
					s.jubilee = Game.year
				"succeed":
					var heir: Dictionary = s.heir
					if heir.is_empty():
						heir = _person(Game.rng.randi() % 9999, 40, Game.rng.randf() < 0.5)
					Game.add_milestone("%s %s takes the throne" % [title(heir), str(heir.name)], "crown", "gold")
					s.monarch = heir
					s.heir = _person(Game.rng.randi() % 9999, maxi(age(heir) - 28, 1), Game.rng.randf() < 0.5)
					s.heir["name"] = str(s.heir.name).split(" ")[0] + " " + str(heir.name).split(" ")[-1]
					s.wed = age(s.heir) >= 30
					s.jubilee = -1
				"referendum":
					var yes := 0.3 + (50.0 - float(s.pop)) / 80.0
					if Game.rng.randf() < yes:
						Game.politics.kind_override = "parliamentary"
						s.royal = false
						Game.add_milestone("Became a republic", "landmark", "gold")
						Game.add_feed("Referendum: the people vote to become a republic", "vote", "gold")
					else:
						s.pop = float(s.pop) + 10.0
						Game.add_feed("Referendum: the people vote to keep the monarchy", "crown", "gold")


## Target offsets from the family's popularity.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("hos"):
		return {}
	var d := pop() - 60.0
	return {"approval": E.HOS_APPROVAL * d, "stability": E.HOS_STAB * d * (1.5 if bool(st().royal) else 0.5)}
