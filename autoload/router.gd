extends CanvasLayer
## Scene navigation with a soft cross-fade through the ocean colour.

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 120
	_veil = ColorRect.new()
	_veil.color = DS.OCEAN_BOTTOM
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	add_child(_veil)


func goto(path: String, fade: float = 0.3) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	DS.ease_out(t)
	t.tween_property(_veil, "modulate:a", 1.0, Settings.dur(fade))
	await t.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	DS.ease_out(t2)
	t2.tween_property(_veil, "modulate:a", 0.0, Settings.dur(fade * 1.2))
	await t2.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
