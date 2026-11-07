class_name Calendar
extends RefCounted
## In-game date and time flow. One month passes every Economy.SECONDS_PER_MONTH
## at 1×; speeds are 0 (paused), 1, 2 and 4.

const START_YEAR := 2026
const SPEEDS := [0, 1, 2, 4]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var year := START_YEAR
var month := 1
var months_played := 0
var speed := 1
var acc := 0.0                 # seconds into the current month (at 1×)
var speed_before_pause := 1


func reset() -> void:
	year = START_YEAR
	month = 1
	months_played = 0
	speed = 1
	acc = 0.0


## Advances real time; true when a month boundary has been reached.
func step(delta: float) -> bool:
	acc += delta * speed
	if acc >= Economy.SECONDS_PER_MONTH:
		acc -= Economy.SECONDS_PER_MONTH
		return true
	return false


func next_month() -> void:
	months_played += 1
	month += 1
	if month > 12:
		month = 1
		year += 1


func progress() -> float:
	return clampf(acc / Economy.SECONDS_PER_MONTH, 0.0, 1.0)


func date_text() -> String:
	return "%s %d" % [MONTHS[month - 1], year]


## "Jun 2027" for a month `ahead` months from now.
func date_in(ahead: int) -> String:
	var m := month - 1 + ahead
	return "%s %d" % [MONTHS[posmod(m, 12)], year + floori(m / 12.0)]
