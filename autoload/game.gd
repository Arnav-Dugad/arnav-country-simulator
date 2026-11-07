extends Node
## The running game session: every simulated country, the player, the calendar,
## speed control, player history (for charts) and relations with the player.

signal started
signal month_passed
signal speed_changed(speed: int)
signal relations_changed
signal debt_crisis(country: int)

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
var rng := RandomNumberGenerator.new()

var _acc := 0.0


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
	history.clear()
	for k in HISTORY_KEYS:
		history[k] = PackedFloat32Array()
	_init_relations()
	_record_history()
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


## Fraction of the current month elapsed (for smooth UI progress).
func month_progress() -> float:
	return clampf(_acc / Economy.SECONDS_PER_MONTH, 0.0, 1.0)


func advance_month() -> void:
	var quarter := month % 3 == 0
	for i in countries.size():
		var c: CountryState = countries[i]
		if c == null:
			continue
		var crisis := Simulation.tick(c, rng)
		if i != player and quarter:
			AI.quarterly(c, rng)
		if crisis:
			debt_crisis.emit(i)
	_drift_relations()
	months_played += 1
	months_to_election -= 1
	month += 1
	if month > 12:
		month = 1
		year += 1
	_record_history()
	month_passed.emit()


func _drift_relations() -> void:
	# Relations slowly relax toward their seed; gives actions lasting but fading weight.
	pass


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
	speed = 1
	_acc = 0.0
	running = true
	started.emit()
	return true


func end_session() -> void:
	running = false
	player = -1
	countries.clear()
