extends Node
## The running game session: every simulated country, the player, the calendar,
## speed control, player history (for charts) and relations with the player.

signal started
signal month_passed
signal speed_changed(speed: int)
signal relations_changed
signal debt_crisis(country: int)
signal event_started(event: Dictionary)
signal event_resolved(event: Dictionary, choice: int)
signal election_held(result: Dictionary)
signal game_over(summary: Dictionary)
signal law_finished(id: String, repealed: bool)
signal campaign_started

const START_YEAR := 2026
const HISTORY_MAX := 1200
const HISTORY_KEYS := ["gdp", "growth", "approval", "inflation", "debt_pct", "unemployment",
	"happiness", "stability", "treasury"]
const SPEEDS := [0, 1, 2, 4]

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

var countries: Array = []           # CountryState or null (unsimulated territory)
var player := -1
var year := START_YEAR
var month := 1
var months_played := 0
var speed := 1
var running := false
var months_to_election := 12 * Economy.ELECTION_YEARS
var history := {}
var relations := PackedFloat32Array()   # with the player, -100..100
var dip: Dictionary = Diplomacy.fresh_state()
var pending_event: Dictionary = {}
var event_log: Array = []           # [{date, title, choice, id}]
var elections_won := 0
var start_snapshot: Dictionary = {}
var headlines_seen: Dictionary = {}
var scheduled: Array = []   # follow-up events: [{id, due (months_played), other}]
var last_rating := ""        # for upgrade/downgrade headlines
var campaign_year := 0      # absolute month (months_played) of the election already campaigned for

var _last_event_month := -10
var _speed_before_pause := 1
var _low_stability_months := 0
var rng := RandomNumberGenerator.new()

var _acc := 0.0
# AI countries are simulated a few per frame during the month (they are
# independent of each other), so the month boundary itself stays cheap.
var _ai_queue := PackedInt32Array()
var _ai_cursor := 0
var _ai_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------------ setup ----
func new_game(country_index: int, seed_value: int = -1) -> void:
	rng.seed = seed_value if seed_value >= 0 else int(Time.get_unix_time_from_system())
	countries.clear()
	countries.resize(World.count())
	for i in World.count():
		if World.stats[i].get("population", 0.0) > 0.0 and World.stats[i].has("gdp"):
			countries[i] = CountryState.new().init_from_stats(i, World.stats[i])
	player = country_index
	year = START_YEAR
	month = 1
	months_played = 0
	months_to_election = 12 * Economy.ELECTION_YEARS
	speed = 1
	_acc = 0.0
	_ai_ready = false
	history.clear()
	for k in HISTORY_KEYS:
		history[k] = PackedFloat32Array()
	_init_relations()
	dip = Diplomacy.fresh_state()
	for i in relations.size():
		dip.baseline[str(i)] = relations[i]
	pending_event = {}
	headlines_seen = {}
	scheduled = []
	campaign_year = 0
	last_rating = ""
	event_log.clear()
	elections_won = 0
	_last_event_month = 0  # a few quiet months to settle in
	_low_stability_months = 0
	var c := me()
	start_snapshot = {"year": year, "gdp": c.gdp, "debt_pct": c.debt_pct(), "approval": c.approval,
		"happiness": c.happiness}
	_record_history()
	me().refresh_explainer()
	running = true
	started.emit()


func has_game() -> bool:
	return player >= 0 and not countries.is_empty()


func me() -> CountryState:
	return countries[player] if has_game() else null


func state(i: int) -> CountryState:
	return countries[i] if i >= 0 and i < countries.size() else null


func _init_relations() -> void:
	relations.resize(World.count())
	var my_group := World.group_of(player)
	var neigh := World.map.neighbours[player]
	for i in World.count():
		var r := 8.0
		if World.group_of(i) == my_group:
			r += 12.0
		if i in neigh:
			r += float(absi(hash(World.map.iso3[i] + World.map.iso3[player])) % 45) - 20.0
		r += float(absi(hash(World.map.iso3[i] + "rel" + World.map.iso3[player])) % 21) - 10.0
		var key_a := "%s-%s" % [World.map.iso3[player], World.map.iso3[i]]
		var key_b := "%s-%s" % [World.map.iso3[i], World.map.iso3[player]]
		if RELATION_SEEDS.has(key_a):
			r = RELATION_SEEDS[key_a]
		elif RELATION_SEEDS.has(key_b):
			r = RELATION_SEEDS[key_b]
		relations[i] = clampf(r, -100.0, 100.0)
	relations[player] = 100.0


# ------------------------------------------------------------------- clock ---
func set_speed(s: int) -> void:
	speed = s
	speed_changed.emit(s)


func toggle_pause() -> void:
	set_speed(1 if speed == 0 else 0)


func _process(delta: float) -> void:
	if not running or speed == 0 or not has_game():
		return
	_acc += delta * speed
	var per := Economy.SECONDS_PER_MONTH
	if _acc >= per:
		_acc -= per
		advance_month()
	else:
		_work_ai(delta)


func _work_ai(delta: float) -> void:
	if not _ai_ready:
		_fill_ai_queue()
	var remaining := _ai_queue.size() - _ai_cursor
	if remaining <= 0:
		return
	# Finish with ~30 % of the month to spare.
	var frames_left := maxf(1.0, (Economy.SECONDS_PER_MONTH * 0.7 - _acc) / maxf(delta * speed, 0.0001))
	var batch := maxi(4, int(ceil(remaining / frames_left)))
	for _k in mini(batch, remaining):
		_tick_ai(_ai_queue[_ai_cursor])
		_ai_cursor += 1


func _fill_ai_queue() -> void:
	_ai_queue.clear()
	for i in countries.size():
		if countries[i] != null and i != player:
			_ai_queue.append(i)
	_ai_cursor = 0
	_ai_ready = true


func _tick_ai(i: int) -> void:
	var c: CountryState = countries[i]
	if Simulation.tick(c, rng, false):
		debt_crisis.emit(i)
	if month % 3 == 0:
		AI.quarterly(c, rng)


## Fraction of the current month elapsed (for smooth UI progress).
func month_progress() -> float:
	return clampf(_acc / Economy.SECONDS_PER_MONTH, 0.0, 1.0)


func advance_month() -> void:
	# Finish any AI countries not yet simulated this month, then the player.
	if not _ai_ready:
		_fill_ai_queue()
	while _ai_cursor < _ai_queue.size():
		_tick_ai(_ai_queue[_ai_cursor])
		_ai_cursor += 1
	var my_crisis := Simulation.tick(me(), rng, true)
	if my_crisis:
		debt_crisis.emit(player)
	_ai_ready = false
	_drift_relations()
	months_played += 1
	months_to_election -= 1
	month += 1
	if month > 12:
		month = 1
		year += 1
	for done in Laws.monthly(me()):
		law_finished.emit(str(done.id), bool(done.repealed))
	_record_history()
	month_passed.emit()
	_after_month(my_crisis)


# ------------------------------------------------------- events & elections ---
func _after_month(my_crisis: bool) -> void:
	if not running:
		return
	var c := me()
	_low_stability_months = _low_stability_months + 1 if c.stability < 8.0 else 0
	if _low_stability_months >= 6:
		finish("collapse")
		return
	if months_to_election <= 0:
		hold_election()
		return
	var election_at := months_played + months_to_election   # absolute month of the vote
	if months_to_election == Campaign.MONTHS_BEFORE and campaign_year != election_at:
		campaign_year = election_at
		_pause_for_modal()
		campaign_started.emit()
		return
	if not pending_event.is_empty():
		return
	var due := -1
	for k in scheduled.size():
		if int(scheduled[k].due) <= months_played:
			due = k
			break
	if my_crisis:
		trigger_event(GameEvents.instance(GameEvents.by_id("debt_crisis")))
	elif due >= 0:
		var item: Dictionary = scheduled.pop_at(due)
		trigger_event(GameEvents.instance(GameEvents.by_id(str(item.id)), int(item.get("other", -1))))
	elif months_played - _last_event_month >= GameEvents.MIN_GAP_MONTHS and rng.randf() < GameEvents.MONTHLY_CHANCE:
		var ev: Dictionary = GameEvents.roll(rng)
		if not ev.is_empty():
			trigger_event(ev)


func trigger_event(ev: Dictionary) -> void:
	pending_event = ev
	_last_event_month = months_played
	_pause_for_modal()
	event_started.emit(ev)


func resolve_event(choice: int) -> void:
	if pending_event.is_empty():
		return
	var ev := pending_event
	var ch: Dictionary = ev.choices[choice]
	GameEvents.apply_effects(ch.effects, int(ev.other))
	var nxt: Dictionary = ch.get("next", ev.get("next", {}))
	if not nxt.is_empty():
		scheduled.append({"id": str(nxt.id), "due": months_played + int(nxt.get("in", 6)), "other": int(ev.other)})
	event_log.push_front({"date": date_text(), "title": ev.title, "choice": ch.label, "id": ev.id})
	if event_log.size() > 60:
		event_log.pop_back()
	pending_event = {}
	_resume_after_modal()
	event_resolved.emit(ev, choice)


func hold_election() -> void:
	var a := me().approval
	var p := clampf((a - Economy.WIN_NONE) / (Economy.WIN_SAFE - Economy.WIN_NONE), 0.0, 1.0)
	var won := rng.randf() < p
	var share := clampf(50.0 + (a - 42.5) * 0.9 + rng.randf_range(-2.5, 2.5), 22.0, 78.0)
	share = maxf(share, 50.6) if won else minf(share, 49.4)
	months_to_election = 12 * Economy.ELECTION_YEARS
	if won:
		elections_won += 1
		me().shocks.approval += 3.0  # post-election honeymoon
	event_log.push_front({"date": date_text(), "title": "Election " + ("won" if won else "lost"),
		"choice": "%.1f%% of the vote" % share, "id": "election"})
	_pause_for_modal()
	election_held.emit({"won": won, "share": share, "year": year, "approval": a})


## Call after the campaign card is closed.
func finish_campaign(themes: Array) -> float:
	var gain := Campaign.launch(me(), themes) if not themes.is_empty() else 0.0
	event_log.push_front({"date": date_text(), "title": "Campaign launched",
		"choice": ", ".join(themes.map(func(t: String) -> String:
			for th in Campaign.THEMES:
				if th.id == t:
					return str(th.title)
			return t)) if not themes.is_empty() else "No campaign", "id": "election"})
	_resume_after_modal()
	return gain


## Call after the election card is dismissed.
func continue_after_election(won: bool) -> void:
	if won:
		_resume_after_modal()
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
		"gdp_start": g0, "gdp_end": c.gdp, "avg_growth": avg_growth,
		"debt_start": float(start_snapshot.get("debt_pct", 0.0)), "debt_end": c.debt_pct(),
		"approval": c.approval, "happiness_start": float(start_snapshot.get("happiness", 0.0)),
		"happiness_end": c.happiness, "events": event_log.size(), "trend": c.trend,
		"laws": c.laws.keys().filter(func(k: String) -> bool:
			return Laws.is_active(c, k) and not c.laws_start.has(k)).size()}


func _pause_for_modal() -> void:
	if speed != 0:
		_speed_before_pause = speed
	set_speed(0)


func _resume_after_modal() -> void:
	set_speed(maxi(_speed_before_pause, 1))


func _drift_relations() -> void:
	Diplomacy.monthly()
	relations_changed.emit()


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


func date_text() -> String:
	const NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [NAMES[month - 1], year]


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
			_:
				out[i] = NAN
	return out


# ----------------------------------------------------------------- persist ---
const SAVE_VERSION := 1


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
		"months_played": months_played, "months_to_election": months_to_election,
		"countries": cs, "relations": rel, "history": hist, "rng_state": str(rng.state),
		"dip": dip, "event_log": event_log, "elections_won": elections_won,
		"start": start_snapshot, "pending_event": pending_event, "headlines_seen": headlines_seen, "scheduled": scheduled,
		"campaign_year": campaign_year, "last_rating": last_rating,
	}


func load_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION:
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
	year = int(d.year)
	month = int(d.month)
	months_played = int(d.get("months_played", 0))
	months_to_election = int(d.get("months_to_election", 48))
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
	event_log = d.get("event_log", [])
	elections_won = int(d.get("elections_won", 0))
	start_snapshot = d.get("start", {})
	pending_event = d.get("pending_event", {})
	headlines_seen = d.get("headlines_seen", {})
	scheduled = d.get("scheduled", [])
	campaign_year = int(d.get("campaign_year", 0))
	last_rating = str(d.get("last_rating", ""))
	_low_stability_months = 0
	speed = 1
	_acc = 0.0
	_ai_ready = false
	me().refresh_explainer()
	running = true
	started.emit()
	return true


func end_session() -> void:
	running = false
	player = -1
	countries.clear()
