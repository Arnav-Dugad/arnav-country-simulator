class_name EventDirector
extends RefCounted
## Decides when events happen and keeps the player's open decisions.
##
## Calm by design (the way Stellaris/Frostpunk do it): a routine event never
## pauses the game. It waits as a decision (a pill above the dock) for
## DECISION_MONTHS; if the player doesn't answer, the cabinet picks the
## recommended choice and it's reported quietly. Only critical events pause, and
## the game resumes on its own once they're answered.
##
## Settings.decisions:  "inbox" (default) | "ask" (every event pauses, classic)
##                      | "cabinet" (the cabinet answers everything that isn't critical)

const DECISION_MONTHS := 6
const MAX_OPEN := 2
const CRITICAL := ["debt_crisis"]

var inbox: Array = []          # open decisions: event instances + {uid, due, critical}
var scheduled: Array = []      # follow-up events: [{id, due (months_played), other}]
var log: Array = []            # your history, newest first: [{date, title, choice, id, cabinet?}]
var last_event_month := -10
var _uid := 0


func reset() -> void:
	inbox.clear()
	scheduled.clear()
	log.clear()
	last_event_month = 0      # a few quiet months to settle in


## Monthly: let the cabinet answer overdue decisions, then maybe start a new event.
func monthly(my_crisis: bool) -> void:
	for ev in inbox.duplicate():
		if not bool(ev.get("critical", false)) and int(ev.get("due", 0)) <= Game.months_played:
			resolve(ev, recommended(ev), true)
	if my_crisis:
		add(GameEvents.instance(GameEvents.by_id("debt_crisis")), true)
		return
	if inbox.size() >= MAX_OPEN:
		return
	for k in scheduled.size():
		if int(scheduled[k].due) <= Game.months_played:
			var item: Dictionary = scheduled.pop_at(k)
			var e := GameEvents.by_id(str(item.id))
			if not e.is_empty():
				add(GameEvents.instance(e, int(item.get("other", -1))))
			return
	var gap := GameEvents.MIN_GAP_MONTHS
	if Game.months_played - last_event_month >= gap and Game.rng.randf() < Difficulty.event_chance():
		var ev := GameEvents.roll(Game.rng)
		if not ev.is_empty():
			add(ev)


func add(ev: Dictionary, critical: bool = false) -> void:
	_uid += 1
	ev["uid"] = "%d-%d" % [Game.months_played, _uid]
	ev["due"] = Game.months_played + DECISION_MONTHS
	ev["critical"] = critical or str(ev.get("id", "")) in CRITICAL
	ev["date"] = Game.date_text()
	last_event_month = Game.months_played
	if str(ev.get("id", "")) in GameEvents.DISASTERS:
		Game.add_weather(str(ev.id), Game.player, 3)
	var mode := str(Settings.get_value("decisions", "inbox"))
	if not ev.critical and mode == "cabinet":
		inbox.append(ev)
		resolve(ev, recommended(ev), true)
		return
	inbox.append(ev)
	if ev.critical or mode == "ask":
		Game.pause_for_modal()
		Game.event_started.emit(ev)
	else:
		Game.decision_added.emit(ev)


func has_open() -> bool:
	return not inbox.is_empty()


func first() -> Dictionary:
	return inbox[0] if not inbox.is_empty() else {}


func find(uid: String) -> Dictionary:
	for ev in inbox:
		if str(ev.uid) == uid:
			return ev
	return {}


## Months the player has left to answer (0 = due now).
func months_left(ev: Dictionary) -> int:
	return maxi(int(ev.get("due", 0)) - Game.months_played, 0)


func resolve(ev: Dictionary, choice: int, by_cabinet: bool = false) -> void:
	var at := inbox.find(ev)
	if at < 0:
		return
	inbox.remove_at(at)
	choice = clampi(choice, 0, ev.choices.size() - 1)
	var ch: Dictionary = ev.choices[choice]
	GameEvents.apply_effects(ch.effects, int(ev.other), str(ev.id))
	var nxt: Dictionary = ch.get("next", ev.get("next", {}))
	if not nxt.is_empty():
		scheduled.append({"id": str(nxt.id), "due": Game.months_played + int(nxt.get("in", 6)), "other": int(ev.other)})
	log.push_front({"date": Game.date_text(), "title": ev.title, "choice": ch.label, "id": ev.id, "cabinet": by_cabinet})
	if log.size() > 80:
		log.pop_back()
	if bool(ev.get("critical", false)) or str(Settings.get_value("decisions", "inbox")) == "ask":
		Game.resume_after_modal()
	Game.event_resolved.emit(ev, choice, by_cabinet)


## The cabinet's pick: the choice whose effects score best for this country right
## now (an empty treasury makes costly options less attractive, unrest makes
## stability worth more, and so on).
func recommended(ev: Dictionary) -> int:
	var best := 0
	var best_score := -INF
	for k in ev.choices.size():
		var s := score(ev.choices[k].effects)
		if s > best_score:
			best_score = s
			best = k
	return best


static func score(fx: Dictionary) -> float:
	var c := Game.me()
	var tight := c.treasury < c.spending / 12.0 * 2.0 or c.debt_pct() > 90.0
	var w := {"growth": 2.0, "inflation": -1.0, "unemployment": -1.4, "happiness": 0.8, "approval": 0.9,
		"stability": 0.8 if c.stability > 40.0 else 1.6, "relation": 0.08, "relations_all": 0.5, "gdp": 1.5}
	var s := 0.0
	for k in fx:
		var v := float(fx[k]) if fx[k] is float or fx[k] is int else 0.0
		if w.has(k):
			s += float(w[k]) * v
		elif k == "cost":
			s -= v * (3.0 if tight else 1.6)
		elif k == "debt_gdp":
			s -= v * 0.6
		elif k == "sanction_me":
			s -= 3.0
		elif k == "deal":
			s += 1.5
	return s


func to_dict() -> Dictionary:
	return {"inbox": inbox, "scheduled": scheduled, "log": log, "last_event_month": last_event_month, "uid": _uid}


func load_dict(d: Dictionary, legacy_pending: Dictionary = {}) -> void:
	inbox = d.get("inbox", [])
	scheduled = d.get("scheduled", [])
	log = d.get("log", [])
	last_event_month = int(d.get("last_event_month", 0))
	_uid = int(d.get("uid", 0))
	if not legacy_pending.is_empty() and inbox.is_empty():
		legacy_pending["uid"] = "legacy"
		legacy_pending["due"] = Game.months_played + DECISION_MONTHS
		legacy_pending["critical"] = false
		inbox.append(legacy_pending)
