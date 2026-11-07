class_name WorldAI
extends RefCounted
## Simulates every AI country once a month, a few per frame while the month runs
## (they're independent of each other), so the month boundary itself stays cheap.

var _queue := PackedInt32Array()
var _cursor := 0
var _ready := false


func reset() -> void:
	_ready = false
	_queue.clear()
	_cursor = 0


func _fill() -> void:
	_queue.clear()
	for i in Game.countries.size():
		if Game.countries[i] != null and i != Game.player:
			_queue.append(i)
	_cursor = 0
	_ready = true


## Spread the work over the month: finish with ~30 % of the month to spare.
func work(delta: float, acc: float, speed: int) -> void:
	if not _ready:
		_fill()
	var remaining := _queue.size() - _cursor
	if remaining <= 0:
		return
	var frames_left := maxf(1.0, (Economy.SECONDS_PER_MONTH * 0.7 - acc) / maxf(delta * speed, 0.0001))
	var batch := maxi(4, int(ceil(remaining / frames_left)))
	for _k in mini(batch, remaining):
		_tick(_queue[_cursor])
		_cursor += 1


## Month boundary: simulate whoever is left, then start a fresh queue next month.
func finish_month() -> void:
	if not _ready:
		_fill()
	while _cursor < _queue.size():
		_tick(_queue[_cursor])
		_cursor += 1
	_ready = false


func _tick(i: int) -> void:
	var c: CountryState = Game.countries[i]
	var prev_growth := c.growth
	if Simulation.tick(c, Game.rng, false):
		Game.debt_crisis.emit(i)
		WorldNews.defaulted(i)
	if Game.month % 3 == 0:
		AI.quarterly(c, Game.rng)
	WorldNews.monthly(i, c, prev_growth, Game.rng)
