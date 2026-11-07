extends Node
## Measures the cost of the month boundary vs the per-frame AI batches (dev tool).
## Run: godot --headless --path . res://tools/frame_probe.tscn


func _ready() -> void:
	Game.new_game(World.index_of("USA"), 1)
	var boundary: Array[float] = []
	var batches: Array[float] = []
	for m in 12:
		# Simulate the frames of one month at 4x speed (60 fps).
		var frames := int(Economy.SECONDS_PER_MONTH / 4.0 * 60.0)
		for f in frames - 1:
			Game.calendar.acc = Economy.SECONDS_PER_MONTH * f / frames
			var t := Time.get_ticks_usec()
			Game.world_ai.work(1.0 / 60.0 * 4.0 / 4.0, Game.calendar.acc, 4)
			batches.append((Time.get_ticks_usec() - t) / 1000.0)
		var t2 := Time.get_ticks_usec()
		Game.advance_month()
		boundary.append((Time.get_ticks_usec() - t2) / 1000.0)
	batches.sort()
	boundary.sort()
	print("month boundary: median %.2f ms, worst %.2f ms | per-frame AI batch: median %.2f ms, worst %.2f ms" % [
		boundary[boundary.size() / 2], boundary[-1], batches[batches.size() / 2], batches[-1]])
	get_tree().quit()
