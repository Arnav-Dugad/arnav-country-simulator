class_name Avatar
extends Control
## A simple, friendly portrait: initials on a soft colour disc with a thin rim.
## Used for you (party colour) and your ministers.

var initials := "?"
var tint: Color = DS.ACCENT
var diameter := 36.0


static func make(name: String, color: Color, size_px: float = 36.0) -> Control:
	var a: Control = load("res://ui/components/avatar.gd").new()
	var parts := name.strip_edges().split(" ", false)
	var ini := "?"
	if parts.size() > 0:
		ini = (parts[0].left(1) + (parts[parts.size() - 1].left(1) if parts.size() > 1 else "")).to_upper()
	a.set(&"initials", ini)
	a.set(&"tint", color)
	a.set(&"diameter", size_px)
	a.custom_minimum_size = Vector2(size_px, size_px)
	return a


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := diameter * 0.5
	draw_circle(c, r, Color(tint, 0.28), true, -1.0, true)
	draw_circle(c, r - 0.6, Color(tint, 0.75), false, 1.2, true)
	var f := get_theme_font(&"font", &"Headline")
	var fs := int(diameter * 0.38)
	draw_string(f, Vector2(0, c.y + fs * 0.36), initials, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, tint.lightened(0.45))
