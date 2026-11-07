class_name Mandate
extends RefCounted
## The first 100 days (research: new leaders get a honeymoon of political
## goodwill that fades over their first months; big reforms are easiest early).
## For the first 4 months: laws pass 30% faster and their political cost is
## halved. A "first 100 days" card in the Inbox tracks what you did with it.

const MONTHS := 4
const LAW_SPEED := 0.3        # fraction faster
const POLITICS_DISCOUNT := 0.5


static func active() -> bool:
	return Game.has_game() and Game.months_played < MONTHS


static func months_left() -> int:
	return maxi(MONTHS - Game.months_played, 0)


## What you achieved in your first 100 days (for the Inbox card).
static func summary() -> Array:
	var c := Game.me()
	var out: Array = []
	for id in c.laws:
		if not c.laws_start.has(id):
			out.append(Laws.title_of(c, Laws.law(id)))
	for id in c.projects:
		if not bool(c.projects[id].get("start", false)):
			out.append(str(Projects.by_id(id).get("title", id)))
	return out
