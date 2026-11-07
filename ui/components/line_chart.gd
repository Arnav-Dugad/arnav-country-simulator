class_name LineChart
extends Control
## Smooth line chart drawn in _draw(): Catmull-Rom curve, rounded line, vertical
## gradient fill, faint grid with labels, glowing end dot, and a draw-in animation.

@export var color: Color = DS.ACCENT
@export var line_width := 2.6
var formatter: Callable = func(v: float) -> String: return String.num(v, 1)
## Show at most this many trailing points (months).
var window := 120

var _data := PackedFloat32Array()
var _progress := 1.0
var _tween: Tween
var _font: Font
## Index (into the visible window) of the point under the finger, or -1.
var _scrub := -1
var _pts := PackedVector2Array()
## Month label for a point: returns e.g. "Mar 2031" for the i-th visible value.
var date_of: Callable = Callable()


func _init() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	_font = get_theme_font(&"font", &"Caption")


## Sets the series. `animate` replays the draw-in.
func set_data(data: PackedFloat32Array, animate: bool = false) -> void:
	_data = data.slice(maxi(0, data.size() - window))
	if animate:
		if _tween:
			_tween.kill()
		_progress = 0.0
		_tween = create_tween()
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(func(p: float) -> void:
			_progress = p
			queue_redraw(), 0.0, 1.0, Settings.dur(0.8))
	queue_redraw()


func set_color(c: Color) -> void:
	color = c
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var label_w := 44.0
	var plot := Rect2(r.position + Vector2(0, 8), r.size - Vector2(label_w, 22))
	if plot.size.x < 10 or plot.size.y < 10:
		return
	var lo := INF
	var hi := -INF
	for v in _data:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if _data.is_empty():
		lo = 0.0
		hi = 1.0
	var pad := maxf((hi - lo) * 0.18, maxf(absf(hi) * 0.02, 0.5))
	lo -= pad
	hi += pad
	# Grid + labels
	var grid_col := Color(1, 1, 1, 0.07)
	var label_col := DS.TEXT_3
	for k in 3:
		var t := k / 2.0
		var y := plot.position.y + plot.size.y * t
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid_col, 1.0)
		var v := lerpf(hi, lo, t)
		if _font:
			draw_string(_font, Vector2(plot.end.x + 6, y + 4), formatter.call(v), HORIZONTAL_ALIGNMENT_LEFT,
				label_w - 6, 11, label_col)
	if _data.size() < 2:
		if _font:
			draw_string(_font, plot.get_center() - Vector2(60, 0), "History builds monthly",
				HORIZONTAL_ALIGNMENT_CENTER, 120, 12, DS.TEXT_3)
		return
	# Points
	var n := _data.size()
	var pts := PackedVector2Array()
	for i in n:
		var x := plot.position.x + plot.size.x * (float(i) / float(n - 1))
		var y := plot.position.y + plot.size.y * (1.0 - (_data[i] - lo) / (hi - lo))
		pts.append(Vector2(x, y))
	_pts = pts
	var curve := _smooth(pts, 6 if n < 40 else 3)
	var count := maxi(2, int(curve.size() * _progress))
	curve = curve.slice(0, count)
	# Gradient fill (triangle strip as quads with per-vertex colour)
	var top := Color(color, 0.28)
	var bottom := Color(color, 0.0)
	var base_y := plot.end.y
	for i in curve.size() - 1:
		var a := curve[i]
		var b := curve[i + 1]
		draw_polygon(PackedVector2Array([a, b, Vector2(b.x, base_y), Vector2(a.x, base_y)]),
			PackedColorArray([top, top, bottom, bottom]))
	# Line with rounded ends
	draw_polyline(curve, color, line_width, true)
	draw_circle(curve[0], line_width * 0.5, color, true, -1.0, true)
	var end := curve[curve.size() - 1]
	if _scrub < 0:
		draw_circle(end, 7.0, Color(color, 0.22), true, -1.0, true)
		draw_circle(end, 3.6, color, true, -1.0, true)
		draw_circle(end, 1.6, Color(1, 1, 1, 0.9), true, -1.0, true)
	else:
		_draw_scrub(plot)


func _draw_scrub(plot: Rect2) -> void:
	var p := _pts[_scrub]
	draw_line(Vector2(p.x, plot.position.y - 4), Vector2(p.x, plot.end.y), Color(1, 1, 1, 0.35), 1.0, true)
	draw_circle(p, 8.0, Color(color, 0.25), true, -1.0, true)
	draw_circle(p, 4.2, color, true, -1.0, true)
	draw_circle(p, 1.8, Color(1, 1, 1, 0.95), true, -1.0, true)
	if _font == null:
		return
	var val: String = formatter.call(_data[_scrub])
	var when: String = date_of.call(_scrub) if date_of.is_valid() else ""
	var fs_v := 14
	var fs_d := 11
	var w := maxf(_font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v).x,
		_font.get_string_size(when, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_d).x) + 20.0
	var h := 40.0 if when != "" else 26.0
	var bx := clampf(p.x - w * 0.5, 0.0, size.x - w)
	var by := plot.position.y - 6.0 if p.y > plot.position.y + h + 12.0 else plot.end.y - h
	by = minf(by, p.y - h - 10.0) if p.y - h - 10.0 > 0.0 else p.y + 12.0
	var bubble := get_theme_stylebox(&"panel", &"TooltipPanel")
	draw_style_box(bubble, Rect2(bx, by, w, h))
	draw_string(_font, Vector2(bx + 10, by + 18), val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_v, DS.TEXT)
	if when != "":
		draw_string(_font, Vector2(bx + 10, by + 33), when, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_d, DS.TEXT_2)


var _press := Vector2.ZERO
var _pending := false


func _gui_input(e: InputEvent) -> void:
	if _pts.size() < 2:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pending = true
			_press = e.position
		else:
			_pending = false
			if _scrub >= 0:
				_scrub = -1
				queue_redraw()
	elif e is InputEventMouseMotion:
		if _pending:
			var d: Vector2 = e.position - _press
			if absf(d.x) > 8.0 and absf(d.x) > absf(d.y):
				_pending = false
				_scrub_to(e.position.x)   # horizontal: scrub
			elif absf(d.y) > 8.0:
				_pending = false          # vertical: let the page scroll
		elif _scrub >= 0:
			_scrub_to(e.position.x)
			accept_event()


func _scrub_to(x: float) -> void:
	var best := 0
	var bd := INF
	for i in _pts.size():
		var d := absf(_pts[i].x - x)
		if d < bd:
			bd = d
			best = i
	if best != _scrub:
		var month_changed := _scrub >= 0
		_scrub = best
		if month_changed:
			if date_of.is_valid() and str(date_of.call(best)).begins_with("Jan"):
				Haptics.tick()
		queue_redraw()


static func _smooth(p: PackedVector2Array, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := p.size()
	for i in n - 1:
		var p0 := p[maxi(i - 1, 0)]
		var p1 := p[i]
		var p2 := p[i + 1]
		var p3 := p[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(p[n - 1])
	return out
