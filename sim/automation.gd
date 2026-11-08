class_name Automation
extends RefCounted
## The AI & automation era. Robots and AI spread through the economy year by
## year, faster in rich countries and with your research (industrial
## automation, AI, self-driving vehicles). More automation means higher
## productivity (growth) but also jobs that disappear. What happens to those
## workers is up to you:
##   retraining     a national programme that moves people into new work
##   robot tax      a levy on automation: revenue, but slower adoption
##   shorter week   a four-day week: happier people, shared work, a little less output
##   basic income   (the Basic income law) cushions the displaced
## Unhandled displacement shows up as unemployment, inequality and anger among
## workers; a well-handled transition is a boom.
## State: Game.dip.auto {level, level0, displaced, retraining, robot_tax, short_week}.
## Constants in sim/economy.gd (AUTO_*).

const E = preload("res://sim/economy.gd")


static func st() -> Dictionary:
	if not Game.dip.has("auto"):
		var c := Game.me()
		var lvl := Economy.income_level(c.gdp_per_capita()) if c != null else 0.5
		var a := clampf(8.0 + 30.0 * lvl, 2.0, 50.0)
		Game.dip["auto"] = {"level": a, "level0": a, "displaced": 0.0, "retraining": false, "robot_tax": false, "short_week": false, "news": -99}
	return Game.dip.auto


static func level() -> float:
	return float(st().level)


static func change() -> float:
	return level() - float(st().level0)


## Points of automation added per year now.
static func pace() -> float:
	var c := Game.me()
	var s := st()
	var p := E.AUTO_BASE_PACE * (0.5 + Economy.income_level(c.gdp_per_capita()))
	for t in ["automation", "ai", "autonomy"]:
		if Tech.has(t):
			p += E.AUTO_TECH_PACE
	if bool(s.robot_tax):
		p *= 1.0 - E.AUTO_ROBOT_TAX_SLOW
	return p * clampf(1.0 - level() / 100.0, 0.05, 1.0)          # slows as the economy fills up


## Share of displaced workers who find new work each year.
static func absorb_rate() -> float:
	var c := Game.me()
	var r := E.AUTO_ABSORB
	if bool(st().retraining):
		r += E.AUTO_RETRAIN_ABSORB
	r += 0.1 * clampf(c.share_delta("education") / 10.0, -1.0, 1.0)
	return clampf(r, 0.05, 0.9)


static func set_policy(key: String, on: bool) -> void:
	st()[key] = on
	if key == "short_week" and on:
		Game.add_milestone("Introduced a four-day working week", "calendar", "accent")


static func cost_pct() -> float:
	if not Game.has_game() or not Game.dip.has("auto"):
		return 0.0
	return E.AUTO_RETRAIN_COST if bool(st().retraining) else 0.0


static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var add := pace() / 12.0
	s.level = minf(level() + add, 98.0)
	# Each point of automation displaces some jobs; some find new work each year.
	var d := float(s.displaced) + add * E.AUTO_DISPLACE
	d -= d * absorb_rate() / 12.0
	s.displaced = maxf(d, 0.0)
	if float(s.displaced) > 2.0 and Game.months_played - int(s.news) > 30:
		s.news = Game.months_played
		out.append({"text": "Robots and AI have taken %s%% of jobs that haven't been replaced yet" % String.num(float(s.displaced), 1), "icon": "bot", "good": false})
	return out


## Target offsets: productivity, displaced workers, the four-day week, robot tax revenue.
static func modifiers() -> Dictionary:
	if not Game.has_game() or not Game.dip.has("auto") or Game.me() == null:
		return {}
	var s := st()
	var out := {"growth": E.AUTO_GROWTH * change() / 10.0, "unemployment": float(s.displaced),
		"gini": E.AUTO_GINI * float(s.displaced), "happiness": 0.0, "revenue": 0.0}
	if bool(s.robot_tax):
		out.revenue = E.AUTO_ROBOT_TAX_REV * level() / 50.0
		out.growth -= 0.1
	if bool(s.short_week):
		out.happiness += E.AUTO_SHORT_HAPPY
		out.growth -= E.AUTO_SHORT_GROWTH * clampf(1.0 - change() / 30.0, 0.2, 1.0)    # easier once robots carry the load
		out.unemployment -= minf(float(s.displaced) * 0.4, 1.5)
	return out
