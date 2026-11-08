class_name Sports
extends RefCounted
## Sport: national pride on the world stage.
##   Teams        every country has a strength in eight sports, from its size,
##                wealth and real sporting tradition (Brazil's football, Kenya's
##                runners, Norway's skiers, India's cricket …). Yours also grows
##                with funding, an academy focus, stadiums and sports centres.
##   Calendar     World Cup (June-July, every 4 years: a 32-team knockout you can
##                follow round by round), Summer Games (August, every 4 years:
##                a medal table), Winter Games (February, every 4 years) and a
##                Cricket World Cup (October, every 4 years, cricket nations).
##   Pride        doing better than people expected lifts happiness and approval
##                for months; flops sting. Titles go in your trophy cabinet and
##                add soft power.
##   Doping       look the other way for a few extra medals … until a scandal
##                strips them and shames the country.
## State: Game.dip.sport {funding, focus, doping, events: {...}, cabinet: [...], last: {...}, hist}.
## Constants in sim/economy.gd (SPORT_*).

const E = preload("res://sim/economy.gd")

const SPORTS := {
	"football": {"title": "Football", "icon": "trophy"},
	"athletics": {"title": "Athletics", "icon": "footprints"},
	"swimming": {"title": "Swimming", "icon": "waves"},
	"basketball": {"title": "Basketball", "icon": "dribbble"},
	"tennis": {"title": "Tennis", "icon": "circle-dot"},
	"cycling": {"title": "Cycling", "icon": "bike"},
	"cricket": {"title": "Cricket", "icon": "target"},
	"winter": {"title": "Winter sports", "icon": "snowflake"},
}

## Real sporting traditions: iso -> bonus (0..30).
const TRADITION := {
	"football": {"BRA": 30, "ARG": 30, "FRA": 28, "DEU": 27, "ESP": 27, "GBR": 26, "ITA": 25, "NLD": 24, "PRT": 24, "BEL": 22,
		"URY": 22, "HRV": 22, "COL": 18, "MEX": 18, "USA": 15, "JPN": 16, "MAR": 18, "SEN": 16, "DNK": 18, "CHE": 17, "SRB": 15,
		"KOR": 14, "NGA": 14, "CMR": 13, "GHA": 12, "CIV": 13, "EGY": 11, "ECU": 13, "CHL": 12, "PER": 11, "POL": 13, "SWE": 13,
		"AUT": 13, "TUR": 12, "UKR": 12, "IRN": 11, "AUS": 11, "SAU": 9, "CZE": 11, "NOR": 11, "SCO": 10},
	"athletics": {"USA": 30, "KEN": 30, "ETH": 28, "JAM": 28, "GBR": 18, "CHN": 15, "NOR": 14, "UGA": 18, "ITA": 13, "DEU": 12,
		"CAN": 14, "NLD": 14, "BHS": 20, "BRA": 10, "POL": 11, "ESP": 10, "FRA": 11, "AUS": 13, "BWA": 14, "MAR": 12, "SWE": 12},
	"swimming": {"USA": 30, "AUS": 30, "CHN": 22, "GBR": 18, "CAN": 16, "JPN": 16, "FRA": 15, "ITA": 15, "HUN": 16, "NLD": 13,
		"SWE": 12, "DEU": 12, "BRA": 9, "KOR": 10, "NZL": 10, "IRL": 9, "RSA": 8},
	"basketball": {"USA": 30, "ESP": 22, "SRB": 22, "FRA": 22, "AUS": 20, "ARG": 18, "LTU": 20, "GRC": 18, "SVN": 18, "CAN": 18,
		"DEU": 17, "ITA": 15, "BRA": 13, "TUR": 15, "HRV": 13, "CHN": 10, "PRI": 12},
	"tennis": {"ESP": 26, "USA": 26, "SRB": 22, "ITA": 24, "RUS": 20, "AUS": 20, "FRA": 20, "GBR": 18, "DEU": 18, "CHE": 22,
		"ARG": 16, "CZE": 18, "POL": 16, "CAN": 14, "JPN": 12, "CHN": 12, "NOR": 12, "GRC": 12, "KAZ": 10},
	"cycling": {"FRA": 26, "BEL": 28, "NLD": 28, "ITA": 24, "ESP": 22, "GBR": 22, "DNK": 24, "SVN": 26, "COL": 18, "AUS": 16,
		"DEU": 18, "CHE": 16, "NOR": 14, "USA": 12, "PRT": 12, "ERI": 12},
	"cricket": {"IND": 30, "AUS": 30, "GBR": 26, "NZL": 24, "ZAF": 24, "PAK": 24, "LKA": 18, "BGD": 14, "AFG": 14, "IRL": 8,
		"ZWE": 10, "NLD": 6, "NPL": 6, "ARE": 5},
	"winter": {"NOR": 30, "DEU": 26, "USA": 22, "CAN": 25, "AUT": 25, "SWE": 22, "CHE": 22, "NLD": 20, "FIN": 18, "ITA": 18,
		"FRA": 18, "RUS": 22, "JPN": 16, "KOR": 16, "CHN": 16, "CZE": 12, "SVN": 12, "POL": 10},
}

const FUNDING := ["None", "Basic", "Strong", "Elite"]
const FUNDING_COST := [0.0, 0.02, 0.06, 0.15]          # % of GDP a year
const FUNDING_BOOST := [0.0, 3.0, 7.0, 12.0]           # strength points at full ramp


static func st() -> Dictionary:
	if not Game.dip.has("sport"):
		Game.dip["sport"] = {"funding": 1, "focus": "", "focus_m": -99, "doping": false, "fund_m": 0,
			"cup": {}, "games": {}, "cabinet": [], "last": [], "pride": 0.0, "medals_hist": []}
	return Game.dip.sport


# ------------------------------------------------------------------ strength ---
static func base(i: int, sport: String) -> float:
	var c: CountryState = Game.state(i)
	if c == null:
		return 0.0
	var size := clampf(log(maxf(c.population, 1e5) / 1e5) / log(10.0) / 4.0, 0.0, 1.0)      # 100K .. 1B
	var rich := Economy.income_level(c.gdp_per_capita())
	var trad := float((TRADITION.get(sport, {}) as Dictionary).get(World.iso(i), 0))
	var b := 20.0 + 25.0 * size + 15.0 * rich + trad
	if sport == "cricket" and trad <= 0.0:
		return 0.0                                  # cricket is played by a handful of nations
	if sport == "winter" and trad <= 0.0:
		b *= 0.4 + 0.5 * rich                      # snow and money help
	return b


## Strength now (yours includes funding, focus, builds, doping, hosting).
static func strength(i: int, sport: String) -> float:
	var b := base(i, sport)
	if b <= 0.0 or i != Game.player:
		return b
	var s := st()
	var c := Game.me()
	var ramp := clampf((Game.months_played - int(s.fund_m)) / 36.0, 0.0, 1.0)
	b += float(FUNDING_BOOST[int(s.funding)]) * ramp
	if str(s.focus) == sport:
		b += E.SPORT_FOCUS * clampf((Game.months_played - int(s.focus_m)) / 48.0, 0.0, 1.0)
	if not c.builds.is_empty():
		b += E.SPORT_BUILDS * (Builds.gain(c, "stadium") + Builds.gain(c, "sports_centre"))
	if bool(s.doping):
		b += E.SPORT_DOPING
	return b


## World rank in a sport (1 = best), cached per month.
static func rank(sport: String) -> int:
	var s := st()
	var key := "%s@%d" % [sport, Game.months_played]
	var cache: Dictionary = s.get("_rank", {})
	if cache.has(key):
		return int(cache[key])
	var mine := strength(Game.player, sport)
	if mine <= 0.0:
		return 0
	var r := 1
	for j in World.playable:
		if j != Game.player and base(j, sport) > mine:
			r += 1
	if cache.size() > 32:
		cache.clear()
	cache[key] = r
	s["_rank"] = cache
	return r


static func set_funding(k: int) -> void:
	var s := st()
	if k != int(s.funding):
		s.funding = clampi(k, 0, 3)
		s.fund_m = Game.months_played - (12 if k < int(s.funding) else 0)


static func funding_cost_pct() -> float:
	if not Game.has_game() or not Game.dip.has("sport"):
		return 0.0
	return float(FUNDING_COST[int(st().funding)]) + (E.SPORT_FOCUS_COST if str(st().focus) != "" else 0.0)


static func set_focus(sport: String) -> void:
	var s := st()
	if str(s.focus) != sport:
		s.focus = sport
		s.focus_m = Game.months_played


# ------------------------------------------------------------------ calendar ---
## Upcoming events: [[title, months away, icon]].
static func upcoming() -> Array:
	var out: Array = []
	var m := int(Game.calendar.month)
	var y := Game.year
	for ev in [["World Cup", 2, 6, "trophy"], ["Summer Games", 0, 8, "medal"], ["Winter Games", 2, 2, "snowflake"], ["Cricket World Cup", 3, 10, "target"]]:
		if ev[0] == "Cricket World Cup" and base(Game.player, "cricket") <= 0.0:
			continue
		var yy := y
		while (yy % 4) != int(ev[1]) or (yy == y and int(ev[2]) < m):
			yy += 1
		out.append([str(ev[0]), (yy - y) * 12 + int(ev[2]) - m, str(ev[3])])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) < int(b[1]))
	return out


static func _month() -> int:
	return int(Game.calendar.month)


## Monthly: run whatever is on the calendar. Returns headlines [{text, icon, good, big, celebrate}].
static func monthly() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var s := st()
	var r := RandomNumberGenerator.new()
	r.seed = hash([Game.rng.seed, Game.months_played, "sport"])
	var m := _month()
	var y := Game.year
	if y % 4 == 2 and m == 6:
		_cup_start(r, "football", "World Cup", out)
	elif y % 4 == 2 and m == 7 and not (s.cup as Dictionary).is_empty():
		_cup_finish(r, out)
	elif y % 4 == 3 and m == 10 and base(Game.player, "cricket") > 0.0:
		_cup_start(r, "cricket", "Cricket World Cup", out)
		_cup_finish(r, out)
	if y % 4 == 0 and m == 8:
		_games(r, "Summer Games", ["athletics", "swimming", "cycling", "tennis", "basketball", "football"], 300, out)
	elif y % 4 == 2 and m == 2:
		_games(r, "Winter Games", ["winter"], 100, out)
	# Pride fades.
	s.pride = float(s.pride) * 0.85
	return out


static func _host_bonus(i: int) -> float:
	if i != Game.player or not Game.dip.has("tour"):
		return 0.0
	var h: Dictionary = Tourism.st().host
	return E.SPORT_HOST if not h.is_empty() and absi(Game.months_played - int(h.year_m)) <= 12 else 0.0


static func _cup_start(r: RandomNumberGenerator, sport: String, title: String, out: Array) -> void:
	var s := st()
	var teams: Array = []
	for j in World.playable:
		var b := base(j, sport) if j != Game.player else strength(j, sport)
		if b > 0.0:
			teams.append([j, b + _host_bonus(j) + r.randfn(0.0, 3.0)])
	teams.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var n := 32 if sport == "football" else 10
	var field: Array = teams.slice(0, n)
	var me_in := false
	for t in field:
		me_in = me_in or int(t[0]) == Game.player
	if not me_in and _host_bonus(Game.player) > 0.0 and strength(Game.player, sport) > 0.0:
		field[field.size() - 1] = [Game.player, strength(Game.player, sport) + _host_bonus(Game.player)]
		me_in = true
	s.cup = {"title": title, "sport": sport, "year": Game.year, "alive": field.map(func(t: Array) -> int: return int(t[0])),
		"rounds": [], "me_in": me_in, "me_out": ""}
	var rank_me := rank(sport)
	if me_in:
		out.append({"text": "The %s %d kicks off: %s is in, ranked #%d" % [title, Game.year, World.the_name(Game.player), rank_me], "icon": str(SPORTS[sport].icon), "good": true, "big": true})
	else:
		out.append({"text": "The %s %d starts without %s: you didn't qualify" % [title, Game.year, World.the_name(Game.player)], "icon": str(SPORTS[sport].icon), "good": false, "big": false})
	# Early rounds now (football: round of 32 and 16 in June; cricket: all rounds at once).
	var rounds := 2 if sport == "football" else 99
	for k in rounds:
		if (s.cup.alive as Array).size() <= 1:
			break
		_play_round(r, out)


static func _cup_finish(r: RandomNumberGenerator, out: Array) -> void:
	var s := st()
	while (s.cup.alive as Array).size() > 1:
		_play_round(r, out)
	var champ := int(s.cup.alive[0])
	var title := str(s.cup.title)
	var sport := str(s.cup.sport)
	if champ == Game.player:
		(s.cabinet as Array).append({"title": title, "year": int(s.cup.year), "icon": str(SPORTS[sport].icon)})
		_pride(E.SPORT_TITLE_PRIDE)
		Game.add_milestone("Won the %s %d" % [title, int(s.cup.year)], "trophy", "gold")
		Achievements.unlock("champions")
		out.append({"text": "CHAMPIONS! %s wins the %s %d" % [World.The_name(Game.player), title, int(s.cup.year)], "icon": "trophy", "good": true, "big": true, "celebrate": true})
	else:
		out.append({"text": "%s wins the %s %d" % [World.The_name(champ), title, int(s.cup.year)], "icon": "trophy", "good": false, "big": bool(s.cup.me_in)})
	(s.last as Array).push_front({"title": "%s %d" % [title, int(s.cup.year)], "champ": champ, "rounds": s.cup.rounds, "me_out": s.cup.me_out})
	if (s.last as Array).size() > 4:
		(s.last as Array).resize(4)
	s.cup = {}


const ROUND_NAMES := {32: "Round of 32", 16: "Round of 16", 8: "Quarter-final", 4: "Semi-final", 2: "Final"}


static func _play_round(r: RandomNumberGenerator, out: Array) -> void:
	var s := st()
	var alive: Array = s.cup.alive
	var sport := str(s.cup.sport)
	var n := alive.size()
	var rname := str(ROUND_NAMES.get(n, "Round of %d" % n))
	var next: Array = []
	var results: Array = []
	# Pair best with worst so favourites meet late.
	var k := 0
	while k < n / 2:
		var a := int(alive[k])
		var b := int(alive[n - 1 - k])
		var sa := (strength(a, sport) if a == Game.player else base(a, sport)) + _host_bonus(a)
		var sb := (strength(b, sport) if b == Game.player else base(b, sport)) + _host_bonus(b)
		var pa := pow(sa, 5.0) / (pow(sa, 5.0) + pow(sb, 5.0))      # favourites usually win, upsets happen
		var a_wins := r.randf() < pa
		var win := a if a_wins else b
		var lose := b if a_wins else a
		var g1 := 1 + int(r.randf() * 3.0)
		var g2 := int(r.randf() * float(g1))
		var score := "%d–%d" % [g1, g2] if sport == "football" else ""
		results.append({"w": win, "l": lose, "score": score})
		next.append(win)
		if a == Game.player or b == Game.player:
			var won := win == Game.player
			var opp := lose if won else win
			out.append({"text": "%s: %s %s %s%s" % [rname, World.map.names[Game.player], "beat" if won else "lost to",
				World.map.names[opp], (" " + score) if score != "" else ""], "icon": str(SPORTS[sport].icon), "good": won, "big": true})
			if not won:
				s.cup.me_out = rname
				_pride(E.SPORT_EXIT_PRIDE * (1.0 if n >= 16 else 0.4))
			elif n <= 4:
				_pride(E.SPORT_TITLE_PRIDE * 0.25)
		k += 1
	(s.cup.rounds as Array).append({"name": rname, "results": results})
	s.cup.alive = next


static func _games(r: RandomNumberGenerator, title: String, events: Array, medals: int, out: Array) -> void:
	var s := st()
	var table := {}
	var total_w := 0.0
	var weights := {}
	for j in World.playable:
		var w := 0.0
		for sp in events:
			var b := (strength(j, str(sp)) if j == Game.player else base(j, str(sp))) + _host_bonus(j)
			w += pow(maxf(b - 25.0, 0.0), 2.6)
		if w > 0.0:
			weights[j] = w
			total_w += w
	for j in weights:
		var expect := float(medals) * float(weights[j]) / total_w
		var got := maxi(0, roundi(expect * r.randf_range(0.7, 1.3) + r.randfn(0.0, 0.6)))
		if got > 0:
			table[j] = got
	var list: Array = []
	for j in table:
		list.append([int(j), int(table[j])])
	list.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var mine := int(table.get(Game.player, 0))
	var expected := float(medals) * float(weights.get(Game.player, 0.0)) / maxf(total_w, 1.0)
	var place := 0
	for k in list.size():
		if int(list[k][0]) == Game.player:
			place = k + 1
	# Doping: a scandal can strip medals.
	if bool(s.doping) and mine > 0 and r.randf() < E.SPORT_DOPING_RISK:
		var lost := maxi(1, mine / 3)
		mine -= lost
		_pride(-E.SPORT_TITLE_PRIDE)
		Press.apply_cred(-8.0)
		out.append({"text": "Doping scandal: %d %s stripped from %s's athletes" % [lost, "medal" if lost == 1 else "medals", World.the_name(Game.player)], "icon": "syringe", "good": false, "big": true})
	var golds := roundi(mine * 0.33)
	var text := ""
	if mine > 0:
		text = "%s %d: %s wins %d %s (%d gold), %s in the medal table" % [title, Game.year, World.The_name(Game.player), mine,
			"medal" if mine == 1 else "medals", golds, _ordinal(place)]
	else:
		text = "%s %d: no medals for %s this time" % [title, Game.year, World.the_name(Game.player)]
	var joy := clampf((float(mine) - expected) / maxf(expected, 2.0), -1.0, 1.5)
	_pride(E.SPORT_MEDAL_PRIDE * joy + (E.SPORT_TITLE_PRIDE * 0.5 if place == 1 else 0.0))
	if place == 1:
		(s.cabinet as Array).append({"title": "Top of the %s medal table" % title, "year": Game.year, "icon": "medal"})
		Achievements.unlock("champions")
	(s.medals_hist as Array).append({"title": title, "year": Game.year, "medals": mine, "place": place})
	(s.last as Array).push_front({"title": "%s %d" % [title, Game.year], "table": list.slice(0, 8), "mine": mine, "place": place})
	if (s.last as Array).size() > 4:
		(s.last as Array).resize(4)
	out.append({"text": text, "icon": "medal", "good": joy >= 0.0, "big": true, "celebrate": place >= 1 and place <= 3})


static func _ordinal(n: int) -> String:
	if n <= 0:
		return "unplaced"
	var suf := "th"
	if n % 100 < 11 or n % 100 > 13:
		suf = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suf]


static func _pride(v: float) -> void:
	var c := Game.me()
	st().pride = float(st().pride) + v
	c.shocks.happiness = float(c.shocks.happiness) + v
	c.shocks.approval = float(c.shocks.approval) + v * 0.6


## Soft power from titles (Tourism adds it in).
static func prestige() -> float:
	return minf(2.0 * float((st().cabinet as Array).size()), 12.0)
