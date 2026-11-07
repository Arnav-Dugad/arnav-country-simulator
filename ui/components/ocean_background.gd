class_name OceanBackground
extends ColorRect
## Full-screen deep-ocean gradient used behind the map and on menu screens.

const OCEAN_SHADER := preload("res://ui/shaders/ocean.gdshader")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = OCEAN_SHADER
	m.set_shader_parameter(&"top_color", DS.OCEAN_TOP)
	m.set_shader_parameter(&"bottom_color", DS.OCEAN_BOTTOM)
	material = m
