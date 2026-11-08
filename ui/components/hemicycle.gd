class_name Hemicycle
extends Control
## A parliament as a half-circle of seats, filled left to right: your party, then
## smaller parties, then the opposition. `progress` (0..1) animates the count.
## Seats are laid out in concentric rows, like real chamber diagrams.

var seats := 151
var mine := 0
var others := 0
var mine_color: Color = DS.ACCENT
var opp_color: Color = DS.RED
var other_color := Color(1, 1, 1, 0.35)
var progress := 1.0:
	set(v):
		progress = v
		queue_redraw()
var _pos := PackedVector2Array()
var _row_r := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		_pos.clear()
		queue_redraw())


## Seats sorted by angle (left to right) so blocks of colour read as wedges.
func _layout() -> void:
	_pos.clear()
	var outer := minf(size.x * 0.5, size.y) - 4.0
	var inner := outer * 0.42
	var rows := 7
	var ring := (outer - inner) / rows
	var total_len := 0.0
	for k in rows:
		total_len += PI * (inner + ring * (k + 0.5))
	var placed: Array = []
	var left := seats
	for k in rows:
		var r := inner + ring * (k + 0.5)
		var n := roundi(seats * PI * r / total_len) if k < rows - 1 else left
		n = clampi(n, 1, left)
		left -= n
		for s in n:
			var a := PI - PI * (float(s) + 0.5) / n
			placed.append([a, Vector2(cos(a), -sin(a)) * r])
	placed.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	for p in placed:
		_pos.append(p[1])
	_row_r = ring * 0.36


func _draw() -> void:
	if _pos.size() != seats:
		_layout()
	var base := Vector2(size.x * 0.5, size.y - 2.0)
	var filled := int(round(seats * clampf(progress, 0.0, 1.0)))
	for k in _pos.size():
		var col := Color(1, 1, 1, 0.08)
		if k < filled:
			if k < mine:
				col = mine_color
			elif k < mine + others:
				col = other_color
			else:
				col = opp_color
		draw_circle(base + _pos[k], _row_r, col, true, -1.0, true)
	if _font_size() > 0:
		var f := get_theme_font(&"font", &"StatSmall")
		var shown := mini(filled, mine)
		var txt := "%d of %d seats" % [shown, seats]
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(f, base + Vector2(-w * 0.5, -6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.9))


func _font_size() -> int:
	return 13
