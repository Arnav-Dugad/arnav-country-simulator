class_name Photo
extends Control
## An image (AI-generated portrait or scene, see assets/portraits, assets/scenes)
## cover-cropped into a rounded rectangle or circle, with an optional slow
## "Ken Burns" drift and a thin rim. Pure drawing: never takes input.

const MASK := preload("res://ui/shaders/round_mask.gdshader")

var texture: Texture2D
var radius := 16.0
var drift := false           # slow pan + zoom (stops with Reduce motion)
var rim: Color = Color(1, 1, 1, 0.14)
var fade_bottom := 0.0
var _t := 0.0
var _mat: ShaderMaterial


static func scene(key: String, height: float = 120.0, drift_on: bool = true) -> Control:
	var p: Control = load("res://ui/components/photo.gd").new()
	p.set(&"texture", load("res://assets/scenes/%s.webp" % key) if ResourceLoader.exists("res://assets/scenes/%s.webp" % key) else null)
	p.set(&"drift", drift_on)
	p.set(&"radius", 18.0)
	p.custom_minimum_size = Vector2(0, height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


static func portrait(key: String, size_px: float, ring: Color = Color(1, 1, 1, 0.2)) -> Control:
	var p: Control = load("res://ui/components/photo.gd").new()
	var path := "res://assets/portraits/%s.webp" % key
	p.set(&"texture", load(path) if ResourceLoader.exists(path) else null)
	p.set(&"radius", size_px)
	p.set(&"rim", ring)
	p.custom_minimum_size = Vector2(size_px, size_px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER     # stays round inside rows
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


static func has_scene(key: String) -> bool:
	return key != "" and ResourceLoader.exists("res://assets/scenes/%s.webp" % key)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = MASK
	material = _mat


func _process(delta: float) -> void:
	if drift and not Settings.reduce_motion and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	_mat.set_shader_parameter(&"rect_size", size)
	_mat.set_shader_parameter(&"radius", radius)
	_mat.set_shader_parameter(&"fade_bottom", fade_bottom)
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.08))
		return
	var ts := texture.get_size()
	# Cover: the largest centred region of the texture with our aspect ratio.
	var aspect := size.x / maxf(size.y, 1.0)
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x / ts.y > aspect:
		src.size.x = ts.y * aspect
		src.position.x = (ts.x - src.size.x) * 0.5
	else:
		src.size.y = ts.x / aspect
		src.position.y = (ts.y - src.size.y) * 0.5
	if drift:
		# 14 s loop: zoom 1.0 -> 1.08 and back, panning gently.
		var k := 0.5 - 0.5 * cos(_t * TAU / 14.0)
		var z := 1.0 + 0.08 * k
		var shrink := src.size / z
		src.position += (src.size - shrink) * Vector2(0.5 + 0.4 * sin(_t * 0.21), 0.5 + 0.3 * cos(_t * 0.17)) * 0.9
		src.size = shrink
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), src)
	if rim.a > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = rim
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(int(minf(radius, minf(size.x, size.y) * 0.5)))
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
