class_name Rivalry
extends RefCounted
## Your rival: the country you're measured against. The researched rival from
## the country profile if there is one, else the playable country with the most
## similar economy size in your region. Headlines when either of you pulls ahead
## in a race (economy size, income per person, happiness), and a card on the
## World page.

const RACES := [
	["gdp", "Economy size", "money"],
	["pc", "Income per person", "money0"],
	["happiness", "Happiness", "num"],
	["growth", "Growth this year", "pct"],
]


static func rival() -> int:
	if not Game.dip.has("rival"):
		Game.dip["rival"] = World.iso(_pick())
	return World.index_of(str(Game.dip.rival))


static func _pick() -> int:
	var me := Game.player
	for iso in Profiles.rivals(me):
		var j := World.index_of(str(iso))
		if j >= 0 and World.is_playable(j) and Game.state(j) != null:
			return j
	var my_gdp := Game.me().gdp
	var best := -1
	var best_d := INF
	for j in World.playable:
		if j == me or Game.state(j) == null:
			continue
		var d := absf(log(Game.state(j).gdp / my_gdp))
		if World.group_of(j) != World.group_of(me):
			d += 1.2
		if d < best_d:
			best_d = d
			best = j
	return best


static func value(i: int, key: String) -> float:
	var c: CountryState = Game.state(i)
	if c == null:
		return 0.0
	match key:
		"gdp":
			return c.gdp
		"pc":
			return c.gdp_per_capita()
		"happiness":
			return c.happiness
		"growth":
			return c.growth
	return 0.0


static func fmt(key_fmt: String, v: float) -> String:
	match key_fmt:
		"money":
			return DS.money(v)
		"money0":
			return DS.money(v, 0)
		"pct":
			return DS.pct(v)
	return String.num(v, 0)


## Monthly: headline when the lead in the big two races changes hands.
static func monthly() -> void:
	var r := rival()
	if r < 0:
		return
	if not Game.dip.has("rival_lead"):
		Game.dip["rival_lead"] = {}
	var lead: Dictionary = Game.dip.rival_lead
	for race in RACES.slice(0, 2):
		var key: String = race[0]
		var ahead := value(Game.player, key) > value(r, key)
		if lead.has(key) and bool(lead[key]) != ahead:
			var name := World.map.names[r]
			if ahead:
				Game.add_feed("You overtake %s in %s" % [name, str(race[1]).to_lower()], "trending-up", "green")
				Game.add_milestone("Overtook %s in %s" % [name, str(race[1]).to_lower()], "trending-up", "green")
			else:
				Game.add_feed("%s pulls ahead of you in %s" % [name, str(race[1]).to_lower()], "trending-down", "orange")
		lead[key] = ahead
