class_name Weekly
extends RefCounted
## The weekly challenge: one country and one twist per calendar week, the same
## for every player (it reuses Daily's scenarios, seeded by the week). Your
## legacy score goes to a shared leaderboard in Firestore
## (weekly/{week}/scores/{uid}; see firestore.rules) when the four years are up.
## Game.daily holds the week id ("W2026-45"), so Daily.over() ends the game.


## ISO-8601 week id, e.g. "W2026-45" (weeks start on Monday; week 1 holds Jan 4).
static func week_id(unix: float = -1.0) -> String:
	var t := unix if unix >= 0.0 else Time.get_unix_time_from_system()
	var d := Time.get_date_dict_from_unix_time(int(t))
	var wd := (int(d.weekday) + 6) % 7            # Monday = 0
	var thursday := t + (3 - wd) * 86400.0        # the week's Thursday decides its year
	var th := Time.get_date_dict_from_unix_time(int(thursday))
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": th.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var week := int((thursday - jan1) / 86400.0) / 7 + 1
	return "W%04d-%02d" % [int(th.year), week]


static func is_weekly(key: String) -> bool:
	return key.begins_with("W")


static func scenario() -> Dictionary:
	return Daily.scenario(week_id())


static func start() -> void:
	Daily.start(week_id())


## Days left in this week's challenge.
static func days_left() -> int:
	var d := Time.get_date_dict_from_system()
	return 7 - (int(d.weekday) + 6) % 7


## Name shown on the board: your leader name, or a friendly default.
static func board_name() -> String:
	var n := str(Settings.leader_name).strip_edges()
	return n.left(24) if n != "" else "A leader"


## Best score this week on this device (0 = none yet).
static func best(week: String = "") -> float:
	var c := ConfigFile.new()
	c.load(Career.PATH)
	return float(c.get_value("weekly", week if week != "" else week_id(), 0.0))


static func record(week: String, score: float) -> bool:
	var c := ConfigFile.new()
	c.load(Career.PATH)
	if score <= float(c.get_value("weekly", week, 0.0)):
		return false
	c.set_value("weekly", week, score)
	c.save(Career.PATH)
	return true
