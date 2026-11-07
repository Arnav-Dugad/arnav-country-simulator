class_name Guide
extends Control
## Guided tour: a spotlight glides between targets while a glass card explains
## each one in plain words. Steps: {target: Callable -> Rect2 (global, or empty
## Rect2 for none), title, text}. Emits `finished` when done or skipped.

signal finished

const SPOT_SHADER := preload("res://ui/shaders/spotlight.gdshader")
const PAD := 8.0

var steps: Array = []
var _i := 0
var _shade: ColorRect
var _mat: ShaderMaterial
var _card: GlassPanel
var _count: Label
var _title: Label
var _text: Label
var _next: AppButton
var _hole := Vector4.ZERO
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = SPOT_SHADER
	_mat.set_shader_parameter(&"rim_color", DS.ACCENT_SOFT)
	_shade = ColorRect.new()
	_shade.material = _mat
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	_card = GlassPanel.new()
	_card.theme_type_variation = &"GlassCard"
	_card.tint = DS.GLASS_TINT_STRONG
	add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", DS.S2)
	_card.add_child(col)
	_count = Label.new()
	_count.theme_type_variation = &"Overline"
	col.add_child(_count)
	_title = Label.new()
	_title.theme_type_variation = &"Title2"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_text = Label.new()
	_text.theme_type_variation = &"BodySecondary"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	col.add_child(row)
	var skip := AppButton.make("Skip tour", &"GhostButton")
	skip.pressed.connect(_finish)
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next = AppButton.make("Next", &"PrimaryButton")
	_next.custom_minimum_size = Vector2(110, 44)
	_next.pressed.connect(_advance)
	row.add_child(_next)


func _ready() -> void:
	resized.connect(func() -> void: _show(_i, false))
	modulate.a = 0.0
	DS.ease_out(create_tween()).tween_property(self, "modulate:a", 1.0, Settings.dur(DS.DUR))
	_show.call_deferred(0, false)


func _advance() -> void:
	if _i < steps.size() - 1:
		_show(_i + 1, true)
	else:
		_finish()


func _finish() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	DS.ease_out(t)
	t.tween_property(self, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
	await t.finished
	finished.emit()
	queue_free()


func _show(i: int, animate: bool) -> void:
	if steps.is_empty():
		return
	_i = i
	var s: Dictionary = steps[i]
	_count.text = "%d OF %d" % [i + 1, steps.size()]
	_title.text = str(s.title)
	_text.text = str(s.text)
	_next.text = "Let's go" if i == steps.size() - 1 else "Next"
	var r: Rect2 = (s.target as Callable).call() if s.has("target") else Rect2()
	var target := Vector4.ZERO
	if r.size != Vector2.ZERO:
		var local := get_global_transform().affine_inverse() * r.position
		target = Vector4(local.x - PAD, local.y - PAD, r.size.x + PAD * 2.0, r.size.y + PAD * 2.0)
	_mat.set_shader_parameter(&"rect_size", size)
	if _tween:
		_tween.kill()
	if animate and _hole.z > 0.0 and target.z > 0.0:
		_tween = create_tween()
		DS.ease_out(_tween)
		_tween.tween_method(_set_hole, _hole, target, Settings.dur(DS.DUR_SLOW))
	else:
		_set_hole(target)
	_place_card(target)
	# Wrapped labels report their real height a frame later; re-place then.
	get_tree().process_frame.connect(_place_card.bind(target), CONNECT_ONE_SHOT)
	if animate:
		Haptics.tap()


func _set_hole(h: Vector4) -> void:
	_hole = h
	_mat.set_shader_parameter(&"hole", h)


func _place_card(h: Vector4) -> void:
	var w := minf(size.x - DS.S4 * 2.0, 380.0)
	_card.size = Vector2(w, 0)
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	var x := (size.x - w) * 0.5
	var y: float
	if h.z <= 0.0:
		y = (size.y - _card.size.y) * 0.5
	elif h.y + h.w * 0.5 > size.y * 0.5:
		y = h.y - _card.size.y - DS.S4          # target low: card above it
	else:
		y = h.y + h.w + DS.S4                    # target high: card below it
	y = clampf(y, Screen.top + DS.S3, size.y - Screen.bottom - _card.size.y - DS.S3)
	if _card.position == Vector2.ZERO:
		_card.position = Vector2(x, y)
	else:
		DS.ease_out(create_tween()).tween_property(_card, "position", Vector2(x, y), Settings.dur(DS.DUR))
