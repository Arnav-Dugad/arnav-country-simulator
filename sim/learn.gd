class_name Learn
extends RefCounted
## First-game checklist: five small steps that teach the basics, one at a time
## in the "next" pill. Progress is saved per player (Settings), not per game.

const STEPS := [
	{"id": "economy", "title": "Open Economy", "sub": "See how your country is doing", "icon": "chart", "page": "economy"},
	{"id": "budget", "title": "Adjust the budget", "sub": "Move any budget slider", "icon": "wallet", "page": "budget"},
	{"id": "build", "title": "Start a project", "sub": "Roads, power, hospitals…", "icon": "hammer", "page": "build"},
	{"id": "law", "title": "Pass a law", "sub": "Pick a reform in Laws", "icon": "gavel", "page": "laws"},
	{"id": "deal", "title": "Sign a trade deal", "sub": "Tap a friendly country", "icon": "handshake", "page": "diplomacy"},
]


static func done_ids() -> Array:
	return Settings.get_value("learn_done", [])


static func next_step() -> Dictionary:
	var d := done_ids()
	for s in STEPS:
		if not str(s.id) in d:
			return s
	return {}


## Marks a step done; returns true if it was new.
static func complete(id: String) -> bool:
	var d: Array = done_ids().duplicate()
	if id in d:
		return false
	d.append(id)
	Settings.set_value("learn_done", d)
	return true


static func finished() -> bool:
	return next_step().is_empty()
