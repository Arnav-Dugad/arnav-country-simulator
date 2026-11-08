class_name Career
extends RefCounted
## Your record across every game you finish (user://career.cfg): countries led,
## years in power, elections won, goals reached and your best legacy grade.

const PATH := "user://career.cfg"
const GRADE_ORDER := ["F", "D", "C", "C+", "B-", "B", "B+", "A-", "A", "A+"]


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c


static func record(summary: Dictionary, grade: String) -> void:
	var c := _cfg()
	if bool(summary.get("cheats", false)) or float(summary.get("years", 0.0)) < 1.0:
		return     # sandbox/cheat games and games under a year don't count
	c.set_value("career", "games", int(c.get_value("career", "games", 0)) + 1)
	var led: Array = c.get_value("career", "countries", [])
	if not str(summary.country) in led:
		led.append(str(summary.country))
	c.set_value("career", "countries", led)
	c.set_value("career", "years", float(c.get_value("career", "years", 0.0)) + float(summary.years))
	c.set_value("career", "elections", int(c.get_value("career", "elections", 0)) + int(summary.elections_won))
	c.set_value("career", "goals", int(c.get_value("career", "goals", 0)) + int(summary.get("goals_done", 0)))
	c.set_value("career", "best_score", maxf(float(c.get_value("career", "best_score", 0.0)), float(summary.get("score", 0.0))))
	var best := str(c.get_value("career", "best_grade", ""))
	if best == "" or GRADE_ORDER.find(grade) > GRADE_ORDER.find(best):
		c.set_value("career", "best_grade", grade)
		c.set_value("career", "best_country", str(summary.country))
	c.save(PATH)


static func stats() -> Dictionary:
	var c := _cfg()
	return {"games": int(c.get_value("career", "games", 0)), "countries": (c.get_value("career", "countries", []) as Array).size(),
		"years": float(c.get_value("career", "years", 0.0)), "elections": int(c.get_value("career", "elections", 0)),
		"goals": int(c.get_value("career", "goals", 0)), "best_grade": str(c.get_value("career", "best_grade", "")),
		"best_country": str(c.get_value("career", "best_country", "")),
		"best_score": float(c.get_value("career", "best_score", 0.0))}


## Push your best legacy and achievement points to the online hall of fame (if signed in).
static func publish() -> void:
	if not Firebase.enabled() or not Firebase.signed_in():
		return
	var s := stats()
	var rk: Array = Achievements.rank()
	await Firebase.submit_legend(Weekly.board_name(), str(s.best_country), float(s.best_score), str(s.best_grade),
		Achievements.points(), str(rk[0]))


## One line for the home screen ("" before the first finished game).
static func line() -> String:
	var s := stats()
	if int(s.games) == 0:
		return ""
	return "%d %s led · %d years in power · best grade %s" % [s.countries, "country" if int(s.countries) == 1 else "countries",
		roundi(float(s.years)), s.best_grade]
