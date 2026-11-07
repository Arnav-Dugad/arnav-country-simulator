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


func _init() -> void:
	custom_minimum_size = Vector2(0, 150)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	draw_circle(end, 7.0, Color(color, 0.22), true, -1.0, true)
	draw_circle(end, 3.6, color, true, -1.0, true)
	draw_circle(end, 1.6, Color(1, 1, 1, 0.9), true, -1.0, true)


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
