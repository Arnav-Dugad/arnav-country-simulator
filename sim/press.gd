class_name Press
extends RefCounted
## Press conferences. A few times a year reporters put a pointed question to you,
## built from your real numbers (the weakest thing about your record right now).
## You answer in one of three ways:
##   honest   own the problem: credibility up; a small dip now, steadier later
##   spin     talk up the positives: approval up now, but credibility falls
##   deflect  blame others / refuse: free if credibility is high, costly if not
## Credibility (0..100, starts 60) scales how well spin works and makes future
## honest answers count more. Free elections only? No: every leader faces the
## press, but in closed systems the reporters are fewer and gentler.

## Tuned with tools/balance_report: about one press conference a year.
const EVERY_MONTHS := 15
## topic id -> [question, honest line, spin line, deflect line, stat getter key]
const TOPICS := {
	"inflation": ["Prices are up %s this year. What do you say to families who can't keep up?",
		"\"It's too high and fixing it is my priority.\"", "\"Wages are rising too, and the worst is behind us.\"",
		"\"This is a global problem, not ours.\""],
	"jobs": ["%s of people are out of work. Where are the jobs?",
		"\"Too many people are struggling. We'll do more.\"", "\"Our plan has already created thousands of jobs.\"",
		"\"The numbers don't tell the whole story.\""],
	"debt": ["Debt has reached %s of the economy. Are you borrowing too much?",
		"\"Yes, and we will bring it down step by step.\"", "\"We're investing in the future; it will pay for itself.\"",
		"\"Every country borrows. Next question.\""],
	"growth": ["Growth is only %s. Is the economy stalling?",
		"\"It's slower than I want. We're working on it.\"", "\"Look at the new factories and projects opening.\"",
		"\"Blame the world economy, not us.\""],
	"unrest": ["Protests are growing. Are you losing control?",
		"\"People are angry for good reasons. I'm listening.\"", "\"Most people support us. A few are loud.\"",
		"\"Order will be maintained.\""],
	"scandal": ["Your government has had a rough few months. Can people still trust you?",
		"\"We made mistakes and we're fixing them.\"", "\"Look at what we've delivered.\"",
		"\"I won't comment on rumours.\""],
	"good": ["The economy is doing well. Will you cut taxes now?",
		"\"We'll save some of it for harder times.\"", "\"Yes: everyone should feel the good times.\"",
		"\"We have no plans to announce today.\""],
}


static func credibility() -> float:
	return float(Game.dip.get("credibility", 60.0))


static func _set_cred(v: float) -> void:
	Game.dip["credibility"] = clampf(v, 0.0, 100.0)


static func due() -> bool:
	var last := int(Game.dip.get("last_press", 0))
	return Game.months_played - last >= EVERY_MONTHS and Game.months_played >= 4


## The question for today: the weakest part of your record.
static func make_event() -> Dictionary:
	var c := Game.me()
	var b: Dictionary = c.base
	var topic := "good"
	var stat := ""
	if c.stability < 30.0:
		topic = "unrest"
	elif c.inflation > maxf(6.0, float(b.inflation) + 2.0):
		topic = "inflation"
		stat = DS.pct(c.inflation)
	elif c.unemployment > float(b.unemployment) + 1.5:
		topic = "jobs"
		stat = DS.pct(c.unemployment)
	elif c.debt_pct() > maxf(100.0, float(b.debt_pct) + 10.0):
		topic = "debt"
		stat = DS.pct(c.debt_pct(), 0)
	elif c.growth < c.trend_now() - 1.0:
		topic = "growth"
		stat = DS.pct(c.growth)
	elif c.approval < 40.0:
		topic = "scandal"
	var t: Array = TOPICS[topic]
	var q := str(t[0]) % stat if "%s" in str(t[0]) else str(t[0])
	var cred := credibility()
	var spin_gain := 2.0 * cred / 60.0
	var closed := not Government.is_free(Game.player)
	var choices := [
		{"label": "Be honest", "detail": str(t[1]), "effects": {"approval": -0.5 if topic != "good" else 0.5, "press_cred": 6.0}},
		{"label": "Spin it", "detail": str(t[2]), "effects": {"approval": snappedf(spin_gain, 0.1), "press_cred": -8.0}},
		{"label": "Deflect", "detail": str(t[3]), "effects": {"approval": -1.5 if cred < 50.0 and not closed else 0.0,
			"stability": 0.5 if topic == "unrest" else 0.0, "press_cred": -3.0}},
	]
	return {"id": "press", "title": "Press conference", "icon": "megaphone", "tint": "accent", "weight": 0.0,
		"body": "%s\n\nYour credibility with the press: %d / 100." % [q, roundi(cred)], "choices": choices, "other": -1,
		"next": {}}


static func held() -> void:
	Game.dip["last_press"] = Game.months_played


static func apply_cred(v: float) -> void:
	_set_cred(credibility() + v)
