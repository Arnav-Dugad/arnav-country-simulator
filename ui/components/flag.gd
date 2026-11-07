class_name Flag
extends TextureRect
## Country flag (flag-icons, MIT) with rounded corners. Height in logical points;
## width follows the 4:3 artwork. Hidden automatically if no flag exists.

const FLAG_SHADER := preload("res://ui/shaders/flag.gdshader")

var _mat: ShaderMaterial


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_mat = ShaderMaterial.new()
	_mat.shader = FLAG_SHADER
	material = _mat
	resized.connect(func() -> void: _mat.set_shader_parameter(&"rect_size", size))


## Sets the country (map index) and size. Returns self for chaining.
func show_country(index: int, height: float = 20.0) -> Flag:
	texture = World.flag_of(index)
	visible = texture != null
	custom_minimum_size = Vector2(height * 4.0 / 3.0, height)
	_mat.set_shader_parameter(&"radius", clampf(height * 0.18, 2.0, 6.0))
	_mat.set_shader_parameter(&"rect_size", custom_minimum_size)
	return self
