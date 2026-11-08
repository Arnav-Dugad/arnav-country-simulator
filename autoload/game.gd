extends Node
## The running game session. Thin by design: it owns the countries, the player,
## relations and history, and delegates the rest to modules:
##   calendar   Calendar        date, speed, time flow
##   world_ai   WorldAI         AI countries, spread across frames
##   director   EventDirector   events and the player's open decisions
##   politics   Politics        elections, reviews, unrest: holding on to power
## The old flat API (Game.year, Game.months_to_election, …) is kept as properties.

signal started
signal month_passed
signal speed_changed(speed: int)
signal relations_changed
signal debt_crisis(country: int)
signal event_started(event: Dictionary)          # a decision that pauses (critical / "ask" mode)
signal decision_added(event: Dictionary)         # a decision waiting in the inbox (no pause)
signal event_resolved(event: Dictionary, choice: int, by_cabinet: bool)
signal election_held(result: Dictionary)
signal review_held(result: Dictionary)
signal army_warning
signal game_over(summary: Dictionary)
signal law_finished(id: String, repealed: bool)
signal project_finished(id: String)
signal campaign_started
signal world_news(item: Dictionary)
signal challenge_ended(won: bool)
signal feed_added(item: Dictionary)
signal treaty_joined(id: String)
signal goal_reached(goal: Dictionary)

const START_YEAR := Calendar.START_YEAR
const HISTORY_MAX := 1200
const HISTORY_KEYS := ["gdp", "growth", "approval", "inflation", "debt_pct", "unemployment",
	"happiness", "stability", "treasury"]
const SPEEDS := Calendar.SPEEDS
const FEED_MAX := 60

## Real-world relationship seeds (symmetric). Everything else is derived from
## region and neighbourhood with a little noise.
const RELATION_SEEDS := {
	"USA-GBR": 75, "USA-CAN": 70, "USA-JPN": 65, "USA-KOR": 65, "USA-AUS": 70, "USA-ISR": 70,
	"USA-DEU": 55, "USA-FRA": 50, "USA-MEX": 35, "USA-IND": 40, "USA-RUS": -55, "USA-CHN": -35,
	"USA-IRN": -75, "USA-PRK": -85, "USA-CUB": -45, "USA-VEN": -50, "USA-TWN": 50, "USA-UKR": 50,
	"GBR-FRA": 50, "FRA-DEU": 70, "DEU-POL": 45, "AUS-NZL": 85, "CAN-GBR": 70, "JPN-KOR": 20,
	"JPN-CHN": -25, "KOR-PRK": -80, "CHN-TWN": -70, "CHN-PAK": 65, "CHN-RUS": 55, "CHN-IND": -25,
	"IND-PAK": -60, "IND-RUS": 45, "IND-BGD": 35, "IND-JPN": 45, "RUS-UKR": -95, "RUS-BLR": 75,
	"RUS-POL": -60, "RUS-GBR": -60, "RUS-IRN": 45, "ISR-IRN": -95, "SAU-IRN": -45, "SAU-ARE": 65,
	"SAU-USA": 45, "TUR-GRC": -15, "ARM-AZE": -70, "EGY-SAU": 50, "BRA-ARG": 35, "MAR-DZA": -35,
	"ETH-ERI": -40, "SRB-KOS": -65, "VNM-CHN": -10, "PHL-CHN": -30, "IRN-SYR": 55, "ISR-EGY": 15,
}

var calendar := Calendar.new()
var world_ai := WorldAI.new()
var director := EventDirector.new()
var politics := Politics.new()
var markets := WorldMarkets.new()
var cabinet := Cabinet.new()

var countries: Array = []           # CountryState or null (unsimulated territory)
var player := -1
var running := false
var difficulty := "standard"
var history := {}
var relations := PackedFloat32Array()   # with the player, -100..100
var dip: Dictionary = Diplomacy.fresh_state()
var start_snapshot: Dictionary = {}
var headlines_seen: Dictionary = {}
var last_rating := ""
var news: Array = []                # world news feed, newest first (see WorldNews)
## Updates for the inbox: headlines, laws, projects, achievements… newest first.
## [{date, text, icon, tint (DS colour name), read}]
var feed: Array = []
## Active challenge: {id, deadline (months_played), state: active|won|lost}
var challenge: Dictionary = {}
## Calm weather shown on the map: [{kind, country (iso3), until (months_played), len}]
var weather: Array = []
var cheats_used := false
var god_mode := false               # cheat: you never lose power
var sandbox := false                # started from the sandbox editor
var daily := ""                     # daily challenge date ("" = normal game)
var no_events := false              # sandbox option: no random events
var rng := RandomNumberGenerator.new()

# --- Compatibility properties (the flat API the UI and tools use) ------------
var year: int:
	get: return calendar.year
	set(v): calendar.year = v
var month: int:
	get: return calendar.month
	set(v): calendar.month = v
var months_played: int:
	get: return calendar.months_played
	set(v): calendar.months_played = v
var speed: int:
	get: return calendar.speed
var months_to_election: int:
	get: return politics.months_to_election
	set(v): politics.months_to_election = v
var campaign_year: int:
	get: return politics.campaign_year
var elections_won: int:
	get: return politics.elections_won
var event_log: Array:
	get: return director.log
## The first open decision ({} if none).
var pending_event: Dictionary:
	get: return director.first()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------------ setup ----
## Starts a challenge game (see Challenges).
func new_challenge(id: String, seed_value: int = -1) -> void:
	var ch := Challenges.get_by_id(id)
	new_game(World.index_of(str(ch.country)), seed_value)
	challenge = {"id": id, "deadline": int(ch.years) * 12, "state": "active"}


func new_game(country_index: int, seed_value: int = -1, level: String = "") -> void:
	rng.seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	difficulty = level if level in Difficulty.LEVELS else "standard"
	markets.reset(rng)
	countries.clear()
	countries.resize(World.count())
	player = country_index
	for i in World.count():
		if World.stats[i].get("population", 0.0) > 0.0 and World.stats[i].has("gdp"):
			countries[i] = CountryState.new().init_from_stats(i, World.stats[i])
	calendar.reset()
	world_ai.reset()
	director.reset()
	politics.kind_override = ""
	politics.reset(player)
	cabinet.reset(rng)
	history.clear()
	for k in HISTORY_KEYS:
		history[k] = PackedFloat32Array()
	_init_relations()
	dip = Diplomacy.fresh_state()
	for i in relations.size():
		dip.baseline[str(i)] = relations[i]
	headlines_seen = {}
	last_rating = ""
	news = []
	feed = []
	challenge = {}
	weather = []
	cheats_used = false
	god_mode = false
	sandbox = false
	no_events = false
	daily = ""
	var c := me()
	c.treasury *= Difficulty.treasury_mult()
	start_snapshot = {"year": year, "gdp": c.gdp, "debt_pct": c.debt_pct(), "approval": c.approval,
		"happiness": c.happiness, "inflation": c.inflation, "growth": c.growth,
		"unemployment": c.unemployment, "balance": c.balance, "rating": c.rating()}
	_record_history()
	me().refresh_explainer()
	Goals.refill()
	add_milestone("Took office as %s of %s" % [Government.leader_title(player).to_lower(), World.map.names[player]], "crown", "gold")
	running = true
	started.emit()


func has_game() -> bool:
	return player >= 0 and not countries.is_empty()


func me() -> CountryState:
	return countries[player] if has_game() and player < countries.size() else null


func state(i: int) -> CountryState:
	return countries[i] if i >= 0 and i < countries.size() else null


func _init_relations() -> void:
	relations.resize(World.count())
	var my_group := World.group_of(player)
	var neigh := World.map.neighbours[player]
	var shift := Difficulty.relation_shift()
	var democracy := Government.is_free(player)
	for i in World.count():
		var r := 8.0 + shift
		if World.group_of(i) == my_group:
			r += 12.0
		if i in neigh:
			r += float(absi(hash(World.map.iso3[i] + World.map.iso3[player])) % 45) - 20.0
		r += float(absi(hash(World.map.iso3[i] + "rel" + World.map.iso3[player])) % 21) - 10.0
		# Similar systems get along a little better.
		if Government.is_free(i) == democracy:
			r += 4.0
		var key_a := "%s-%s" % [World.map.iso3[player], World.map.iso3[i]]
		var key_b := "%s-%s" % [World.map.iso3[i], World.map.iso3[player]]
		if RELATION_SEEDS.has(key_a):
			r = RELATION_SEEDS[key_a] + shift
		elif RELATION_SEEDS.has(key_b):
			r = RELATION_SEEDS[key_b] + shift
		relations[i] = clampf(r, -100.0, 100.0)
	relations[player] = 100.0


# ------------------------------------------------------------------- clock ---
func set_speed(s: int) -> void:
	calendar.speed = s
	speed_changed.emit(s)


func toggle_pause() -> void:
	if speed == 0:
		set_speed(maxi(calendar.speed_before_pause, 1))
	else:
		calendar.speed_before_pause = speed
		set_speed(0)


## Pauses for something that needs the player (critical decision, election…).
## resume_after_modal() restores the speed the player had chosen.
func pause_for_modal() -> void:
	if speed != 0:
		calendar.speed_before_pause = speed
	set_speed(0)


func resume_after_modal() -> void:
	set_speed(maxi(calendar.speed_before_pause, 1))


func _process(delta: float) -> void:
	if not running or speed == 0 or not has_game():
		return
	if calendar.step(delta):
		advance_month()
	else:
		world_ai.work(delta, calendar.acc, speed)


## Fraction of the current month elapsed (for smooth UI progress).
func month_progress() -> float:
	return calendar.progress()


func date_text() -> String:
	return calendar.date_text()


func advance_month() -> void:
	world_ai.finish_month()
	var market_news := markets.monthly(rng)
	if market_news != "":
		add_feed(market_news, "tractor" if markets.food_news else "flame", "orange")
	if me().cb_auto and month % 3 == 0:
		AI.central_bank(me())
	var my_crisis := Simulation.tick(me(), rng, true)
	if my_crisis:
		debt_crisis.emit(player)
	Diplomacy.monthly()
	relations_changed.emit()
	calendar.next_month()
	weather = weather.filter(func(w: Dictionary) -> bool: return int(w.until) > months_played)
	for done in Laws.monthly(me()):
		if str(done.id) == "free_elections" and not bool(done.repealed):
			politics.become_democracy()
		var lt := Laws.title_of(me(), Laws.law(str(done.id)))
		add_milestone(("%s repealed" if bool(done.repealed) else "%s became law") % lt, str(Laws.law(str(done.id)).icon),
			"orange" if bool(done.repealed) else "accent")
		if not bool(done.repealed) and Leaders.LAW_KIND.has(str(done.id)):
			Leaders.react(str(Leaders.LAW_KIND[done.id]))
		law_finished.emit(str(done.id), bool(done.repealed))
	for id in Projects.monthly(me()):
		add_milestone("Opened the %s" % str(Projects.by_id(id).title).to_lower(), str(Projects.by_id(id).icon), "green")
		project_finished.emit(str(id))
	for id in Treaties.monthly(rng):
		add_milestone("Joined the %s" % str(Treaties.by_id(id).title), str(Treaties.by_id(id).icon), "accent")
		Leaders.react("treaty_join")
		treaty_joined.emit(str(id))
	cabinet.monthly()
	Rivalry.monthly()
	Climate.monthly()
	Corruption.monthly()
	Opposition.monthly()
	if months_played == Mandate.MONTHS:
		var did := Mandate.summary()
		add_milestone("First 100 days: %s" % (", ".join(did.slice(0, 3)).to_lower() if not did.is_empty() else "a quiet start"),
			"calendar", "gold")
	for g in Goals.monthly():
		add_milestone("Goal reached: %s" % Goals.title(g).to_lower(), str(Goals.SPECS[g.id].icon), "gold")
		goal_reached.emit(g)
	_record_history()
	month_passed.emit()
	_after_month(my_crisis)


func _after_month(my_crisis: bool) -> void:
	if not running:
		return
	_check_challenge()
	if Daily.over():
		finish("daily")
		return
	var what := politics.monthly()
	if what.begins_with("end:") and god_mode:
		what = ""
	if what.begins_with("end:"):
		finish(what.trim_prefix("end:"))
		return
	match what:
		"election":
			hold_election()
			return
		"review":
			var r := politics.hold_review()
			director.log.push_front({"date": date_text(), "title": "%s %s" % [r.name, "renews your mandate" if r.kept else "removes you"],
				"choice": "Support %s · stability %s" % [DS.pct(float(r.approval), 0), String.num(float(r.stability), 0)], "id": "election", "m": months_played})
			if not r.kept and not god_mode:
				finish("review")
				return
			add_feed("%s renews your mandate" % r.name, "landmark", "gold")
			review_held.emit(r)
		"campaign":
			campaign_started.emit()
		"campaign_auto":
			var themes := Campaign.best_themes(me())
			var gain := finish_campaign(themes)
			add_feed("Your party campaigned on %s (approval %+.1f)" % [" and ".join(themes.map(
				func(t: String) -> String: return Campaign.title_of(t).to_lower())), gain], "vote", "gold")
		"army_warning":
			pause_for_modal()
			army_warning.emit()
			return
		"term_limit":
			director.add(GameEvents.term_limit_event(), true)
			return
		"debate":
			director.add(GameEvents.debate_event(), true)
			return
	director.monthly(my_crisis)


func _check_challenge() -> void:
	if challenge.get("state", "") != "active":
		return
	var ch := Challenges.get_by_id(str(challenge.id))
	if ch.is_empty():
		return
	if Challenges.met(ch):
		challenge.state = "won"
		director.log.push_front({"date": date_text(), "title": "Challenge complete", "choice": str(ch.title), "id": "election", "m": months_played})
		challenge_ended.emit(true)
	elif months_played >= int(challenge.deadline):
		challenge.state = "lost"
		director.log.push_front({"date": date_text(), "title": "Challenge missed", "choice": str(ch.title), "id": "election", "m": months_played})
		challenge_ended.emit(false)


# ------------------------------------------------------- events & elections ---
## Starts an event now (DevTools / tests).
func trigger_event(ev: Dictionary, critical: bool = false) -> void:
	director.add(ev, critical)


## Answers the first open decision (compat; the UI uses resolve_decision).
func resolve_event(choice: int) -> void:
	if director.has_open():
		director.resolve(director.first(), choice)


func resolve_decision(ev: Dictionary, choice: int) -> void:
	director.resolve(ev, choice)


func hold_election() -> void:
	var r := politics.hold_election()
	r["opponent"] = Opposition.leader()
	if bool(r.won):
		Opposition.replace()
	director.log.push_front({"date": date_text(), "title": "Election " + ("won" if r.won else "lost"),
		"choice": "%.1f%% of the vote" % float(r.share), "id": "election", "m": months_played})
	add_milestone("Election %s with %.1f%% of the vote" % ["won" if bool(r.won) else "lost", float(r.share)], "vote",
		"gold" if bool(r.won) else "red")
	if bool(r.won):
		Leaders.react("election")
	pause_for_modal()
	election_held.emit(r)


## Call after the campaign card is closed (or when the cabinet picks for you).
func finish_campaign(themes: Array) -> float:
	politics.campaign_open = false
	var gain := Campaign.launch(me(), themes) if not themes.is_empty() else 0.0
	director.log.push_front({"date": date_text(), "title": "Campaign launched",
		"choice": ", ".join(themes.map(func(t: String) -> String:
			return Campaign.title_of(t))) if not themes.is_empty() else "No campaign", "id": "election", "m": months_played})
	return gain


## Call after the election card is dismissed.
func continue_after_election(won: bool) -> void:
	if won or god_mode:
		resume_after_modal()
	else:
		finish("election")


func finish(reason: String) -> void:
	running = false
	game_over.emit(summary(reason))


func summary(reason: String = "") -> Dictionary:
	var c := me()
	var years := months_played / 12.0
	var g0 := float(start_snapshot.get("gdp", c.gdp))
	var avg_growth := (pow(c.real_gdp_per_capita() * c.population / maxf(g0, 1.0), 1.0 / maxf(years, 0.1)) - 1.0) * 100.0 \
		if years >= 1.0 else c.growth
	return {"reason": reason, "country": World.map.names_long[player], "years": years,
		"from": int(start_snapshot.get("year", START_YEAR)), "to": year, "elections_won": elections_won,
		"reviews_passed": politics.reviews_passed, "gov": Government.kind(player),
		"gdp_start": g0, "gdp_end": c.gdp, "avg_growth": avg_growth,
		"debt_start": float(start_snapshot.get("debt_pct", 0.0)), "debt_end": c.debt_pct(),
		"approval": c.approval, "happiness_start": float(start_snapshot.get("happiness", 0.0)),
		"happiness_end": c.happiness, "events": director.log.size(), "trend": c.trend,
		"projects": Projects.count_done(c) - c.projects.values().filter(func(p: Dictionary) -> bool:
			return bool(p.get("start", false))).size(),
		"cheats": cheats_used, "goals_done": Goals.done_count(), "daily": daily,
		"laws": c.laws.keys().filter(func(k: String) -> bool:
			return Laws.is_active(c, k) and not c.laws_start.has(k)).size()}


## Adds an update to the inbox feed (headlines, laws, projects, achievements…).
func add_feed(text: String, icon: String, tint: String = "accent") -> void:
	var item := {"date": date_text(), "text": text, "icon": icon, "tint": tint, "read": false}
	feed.push_front(item)
	if feed.size() > FEED_MAX:
		feed.pop_back()
	feed_added.emit(item)


## Shows a disaster on the map for a few months (purely visual).
func add_weather(kind: String, i: int, months: int = 3) -> void:
	weather.append({"kind": kind, "country": World.iso(i), "until": months_played + months, "len": months})


## The story of your rule (the Inbox timeline): only the big moments.
func add_milestone(text: String, icon: String, tint: String) -> void:
	if not dip.has("story"):
		dip["story"] = []
	dip.story.push_front({"date": date_text(), "text": text, "icon": icon, "tint": tint})
	if dip.story.size() > 80:
		dip.story.pop_back()


func unread_count() -> int:
	var n := 0
	for f in feed:
		if not bool(f.get("read", false)):
			n += 1
	return n


func mark_feed_read() -> void:
	for f in feed:
		f.read = true


func _record_history() -> void:
	var c := me()
	if c == null:
		return
	var vals := {"gdp": c.gdp, "growth": c.growth, "approval": c.approval, "inflation": c.inflation,
		"debt_pct": c.debt_pct(), "unemployment": c.unemployment, "happiness": c.happiness,
		"stability": c.stability, "treasury": c.treasury}
	for k in HISTORY_KEYS:
		var arr: PackedFloat32Array = history[k]
		arr.append(vals[k])
		if arr.size() > HISTORY_MAX:
			arr.remove_at(0)
		history[k] = arr


# --------------------------------------------------------------- map modes ---
## Normalised 0..1 values per map index (NAN = no data) for a data map mode.
func map_values(mode: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(World.count())
	for i in World.count():
		var c: CountryState = countries[i] if not countries.is_empty() else null
		if c == null:
			var s := World.sovereign_of(i)
			c = countries[s] if s >= 0 and not countries.is_empty() else null
		if c == null or World.map.iso3[i] == "ATA":
			out[i] = NAN
			continue
		match mode:
			MapModes.Mode.WEALTH:
				out[i] = clampf((log(maxf(c.gdp_per_capita(), 1.0)) / log(10.0) - 2.7) / 2.3, 0.0, 1.0)
			MapModes.Mode.RELATIONS:
				var r := relations[i] if not relations.is_empty() else 0.0
				out[i] = 1.0 if i == player else (r + 100.0) / 200.0
			MapModes.Mode.HAPPINESS:
				out[i] = clampf((c.happiness - 20.0) / 65.0, 0.0, 1.0)
			MapModes.Mode.STABILITY:
				out[i] = clampf(c.stability / 100.0, 0.0, 1.0)
			MapModes.Mode.GROWTH:
				out[i] = clampf((c.growth + 4.0) / 12.0, 0.0, 1.0)     # -4 % .. +8 %
			MapModes.Mode.DEBT:
				out[i] = clampf(c.debt_pct() / 160.0, 0.0, 1.0)
			MapModes.Mode.EMISSIONS:     # log scale, 0.1 .. 30 t per person
				out[i] = clampf((log(maxf(Climate.co2_pc(c), 0.1)) / log(10.0) + 1.0) / 2.5, 0.0, 1.0)
			_:
				out[i] = NAN
	return out


# ----------------------------------------------------------------- persist ---
## v2: modules (calendar, director, politics), difficulty, feed. v1 saves load too.
const SAVE_VERSION := 2


func to_dict() -> Dictionary:
	var cs := {}
	for i in countries.size():
		if countries[i] != null:
			cs[World.map.iso3[i]] = countries[i].to_dict()
	var rel := {}
	for i in relations.size():
		rel[World.map.iso3[i]] = snappedf(relations[i], 0.01)
	var hist := {}
	for k in history:
		hist[k] = Array(history[k])
	return {
		"version": SAVE_VERSION, "player": World.map.iso3[player], "year": year, "month": month,
		"months_played": months_played, "countries": cs, "relations": rel, "history": hist,
		"rng_state": str(rng.state), "dip": dip, "start": start_snapshot, "headlines_seen": headlines_seen,
		"last_rating": last_rating, "news": news, "challenge": challenge, "feed": feed,
		"difficulty": difficulty, "weather": weather, "cheats_used": cheats_used, "god_mode": god_mode, "sandbox": sandbox, "no_events": no_events, "daily": daily,
		"director": director.to_dict(), "politics": politics.to_dict(), "markets": markets.to_dict(), "cabinet": cabinet.to_dict(),
	}


func load_dict(d: Dictionary) -> bool:
	var ver := int(d.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		return false
	var p := World.index_of(str(d.get("player", "")))
	if p < 0:
		return false
	countries.clear()
	countries.resize(World.count())
	var cs: Dictionary = d.get("countries", {})
	for code in cs:
		var i := World.index_of(code)
		if i >= 0:
			countries[i] = CountryState.from_dict(cs[code])
			countries[i].idx = i
	player = p
	calendar.reset()
	calendar.year = int(d.year)
	calendar.month = int(d.month)
	calendar.months_played = int(d.get("months_played", 0))
	relations.resize(World.count())
	relations.fill(0.0)
	var rel: Dictionary = d.get("relations", {})
	for code in rel:
		var i := World.index_of(code)
		if i >= 0:
			relations[i] = float(rel[code])
	history.clear()
	var hist: Dictionary = d.get("history", {})
	for k in HISTORY_KEYS:
		history[k] = PackedFloat32Array(hist.get(k, []))
	rng.state = int(str(d.get("rng_state", "0")))
	dip = Diplomacy.fresh_state()
	var saved_dip: Dictionary = d.get("dip", {})
	for k in saved_dip:
		dip[k] = saved_dip[k]
	start_snapshot = d.get("start", {})
	headlines_seen = d.get("headlines_seen", {})
	last_rating = str(d.get("last_rating", ""))
	news = d.get("news", [])
	challenge = d.get("challenge", {})
	feed = d.get("feed", [])
	difficulty = str(d.get("difficulty", "standard"))
	weather = d.get("weather", [])
	markets.load_dict(d.get("markets", {}))
	cabinet.load_dict(d.get("cabinet", {}), rng)
	cheats_used = bool(d.get("cheats_used", false))
	god_mode = bool(d.get("god_mode", false))
	sandbox = bool(d.get("sandbox", false))
	no_events = bool(d.get("no_events", false))
	daily = str(d.get("daily", ""))
	# Saves from before projects existed (v1, and v2 files written by 0.13.0 from
	# them): give each country its real starting infrastructure.
	for c in countries:
		if c != null and (c as CountryState).projects.is_empty():
			c.projects = Projects.starting_set(c)
	if ver == 1:
		# v1 kept these at the top level.
		politics.load_dict({"months_to_election": d.get("months_to_election", 48),
			"campaign_year": d.get("campaign_year", 0), "elections_won": d.get("elections_won", 0)})
		politics.start_military_share = float(me().budget.get("military", 0.0))
		director.load_dict({"scheduled": d.get("scheduled", []), "log": d.get("event_log", []),
			"last_event_month": months_played}, d.get("pending_event", {}))
		if Government.has_elections(player) and politics.months_to_election > 12 * Government.term_years(player):
			politics.months_to_election = 12 * Government.term_years(player)
	else:
		politics.load_dict(d.get("politics", {}))
		director.load_dict(d.get("director", {}))
	world_ai.reset()
	me().refresh_explainer()
	Goals.refill()
	running = true
	started.emit()
	return true


func end_session() -> void:
	running = false
	player = -1
	countries.clear()
