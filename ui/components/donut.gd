class_name Donut
extends Control
## An animated donut chart: segments ease toward new shares (so dragging a budget
## slider visibly reshapes it), with a centre label. Pure drawing.

var colors: Array = []          # Color per segment
var center_title := ""
var center_value := ""
var _shown := PackedFloat32Array()
var _target := PackedFloat32Array()
var _font: Font
var _font_b: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 150)


func _ready() -> void:
	_font = get_theme_font(&"font", &"Caption")
	_font_b = get_theme_font(&"font", &"Headline")


## shares: any non-negative numbers (normalised here).
func set_shares(shares: Array, animate: bool = true) -> void:
	var tot := 0.0
	for s in shares:
		tot += maxf(float(s), 0.0)
	_target.resize(shares.size())
	for k in shares.size():
		_target[k] = maxf(float(shares[k]), 0.0) / maxf(tot, 0.0001)
	if _shown.size() != _target.size() or not animate or Settings.reduce_motion:
		_shown = _target.duplicate()
	queue_redraw()


func _process(delta: float) -> void:
	if _shown.size() != _target.size():
		return
	var moving := false
	var k := 1.0 - exp(-12.0 * delta)
	for i in _shown.size():
		var d := _target[i] - _shown[i]
		if absf(d) > 0.0005:
			_shown[i] += d * k
			moving = true
	if moving:
		queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var c := size * 0.5
	var w := r * 0.28
	draw_arc(c, r - w * 0.5, 0.0, TAU, 96, Color(1, 1, 1, 0.06), w, true)
	var a := -PI / 2.0
	var gap := 0.025
	for i in _shown.size():
		var sweep := TAU * _shown[i]
		if sweep > gap * 2.0:
			var col: Color = colors[i] if i < colors.size() else DS.ACCENT
			draw_arc(c, r - w * 0.5, a + gap, a + sweep - gap, maxi(8, int(64 * _shown[i])), col, w, true)
		a += sweep
	if _font_b and center_value != "":
		var fs := int(r * 0.32)
		var tw := _font_b.get_string_size(center_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font_b, Vector2(c.x - tw * 0.5, c.y + fs * 0.25), center_value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DS.TEXT)
	if _font and center_title != "":
		var fs2 := int(r * 0.16)
		var tw2 := _font.get_string_size(center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(_font, Vector2(c.x - tw2 * 0.5, c.y + fs2 * 1.9), center_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, DS.TEXT_3)
