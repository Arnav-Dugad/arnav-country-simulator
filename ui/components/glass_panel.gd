@tool
class_name GlassPanel
extends PanelContainer
## Reusable frosted-glass surface.
## The theme stylebox (type variation GlassPanel / GlassSheet / GlassBar / GlassCard /
## GlassPill) supplies the soft drop shadow, corner radius and content padding. An
## internal ColorRect running ui/shaders/glass.gdshader draws the blurred body and
## rim on top of the shadow, underneath this container's children.

const GLASS_SHADER := preload("res://ui/shaders/glass.gdshader")

@export var tint: Color = DS.GLASS_TINT:
	set(v):
		tint = v
		if _mat:
			_mat.set_shader_parameter(&"tint", v)
@export_range(0.0, 2.0) var blur: float = 1.0:
	set(v):
		blur = v
		_sync()

var _glass: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = GLASS_SHADER
	_glass = ColorRect.new()
	_glass.name = "Glass"
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.material = _mat
	add_child(_glass, false, Node.INTERNAL_MODE_FRONT)
	resized.connect(_sync)


func _ready() -> void:
	if theme_type_variation == &"":
		theme_type_variation = &"GlassPanel"
	_mat.set_shader_parameter(&"tint", tint)
	_mat.set_shader_parameter(&"border_opacity", DS.GLASS_BORDER_OPACITY)
	if not Engine.is_editor_hint():
		get_viewport().size_changed.connect(_sync)
		Settings.changed.connect(func(k: String, _v: Variant) -> void:
			if k == "solid_panels":
				_sync())
	_sync()


func _notification(what: int) -> void:
	# PanelContainer also fits internal children into the padded content rect;
	# script notifications run after the native sort, so re-expand the glass here.
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_SORT_CHILDREN:
		_sync()


func corner_radius() -> float:
	var sb := get_theme_stylebox(&"panel")
	if sb is StyleBoxFlat:
		return float((sb as StyleBoxFlat).corner_radius_top_left)
	return float(DS.R_PANEL)


func _sync() -> void:
	if _glass == null or _mat == null:
		return
	_glass.position = Vector2.ZERO
	_glass.size = size
	_mat.set_shader_parameter(&"rect_size", size)
	_mat.set_shader_parameter(&"corner_radius", corner_radius())
	# Blur radius is in physical pixels; scale with the screen so it looks the
	# same on every density.
	var scale := 1.0
	if is_inside_tree():
		scale = get_viewport().get_final_transform().get_scale().x
	_mat.set_shader_parameter(&"blur_radius_px", 9.0 * scale * blur)
	# Reduce transparency: an opaque tint and no sampling (also faster).
	var solid := Settings.solid_panels if not Engine.is_editor_hint() else false
	var t := tint
	if solid:
		t = Color(tint.r * 0.9 + 0.02, tint.g * 0.9 + 0.025, tint.b * 0.9 + 0.04, 0.97)
	_mat.set_shader_parameter(&"tint", t)
	_mat.set_shader_parameter(&"solid", solid)
	_mat.set_shader_parameter(&"blur_lod", clampf(1.2 + log(maxf(scale, 1.0)) / log(2.0) + blur, 0.0, 5.0))
