extends Control
## Gesture physics test: rubber-band edges, spring back, zoom undershoot recovery,
## long-press. Run: godot --headless --path . res://tools/gesture_test.tscn
var map: MapView
var _fails := 0
var _long := -1


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	_fails += 0 if ok else 1


func _ready() -> void:
	size = Vector2(390, 844)
	map = MapView.new()
	map.size = size
	add_child(map)
	map.country_long_pressed.connect(func(i: int) -> void: _long = i)
	await _frames(3)
	map.fly_to(Vector2.ZERO, map.min_zoom * 3.0, 0.01)
	await _frames(5)
	# 1) Drag far past the right edge: overshoot must be bounded by the rubber band.
	_press(Vector2(200, 400), true)
	var lim := map._center_limits()
	for i in 60:
		_motion(Vector2(-60, 0))        # dragging left moves the view right
	var over_px := (map.center.x - lim.end.x) * map.zoom
	_check(over_px > 5.0 and over_px < map.size.x, "rubber band overshoot bounded (%.0f px)" % over_px)
	_press(Vector2(200, 400), false)
	await get_tree().create_timer(1.5).timeout
	lim = map._center_limits()
	_check(map.center.x <= lim.end.x + 0.01, "springs back inside the world")
	# 2) Pinch-like undershoot of min zoom recovers.
	map.zoom_at(map.size * 0.5, 0.2, true)
	_check(map.zoom < map.min_zoom, "soft zoom may undershoot min")
	await get_tree().create_timer(1.5).timeout
	_check(absf(map.zoom - map.min_zoom) < map.min_zoom * 0.01, "zoom springs back to min")
	# 3) Long press on the player's country area.
	map.focus_country(World.index_of("BRA"), 0.01)
	await _frames(5)
	var p := map.world_to_screen(map.focus_rect(World.index_of("BRA")).get_center())
	_press(p, true)
	await get_tree().create_timer(0.6).timeout
	_check(_long == World.index_of("BRA"), "long-press selects the country")
	_press(p, false)
	print("GESTURE TEST %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _press(pos: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = pos
	map._gui_input(e)


func _motion(rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.position = Vector2(200, 400) + rel
	map._gui_input(e)
