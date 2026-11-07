class_name BottomSheet
extends Control
## iOS-style glass bottom sheet with a drag handle and snap points
## (PEEK / HALF / FULL). Drag the header to move it; flick to jump a stop.
## Add content to `header` (always visible) and `body` (scrolls with sheet).
## Full-rect overlay; only the panel itself takes input.

signal snapped(state: int)
signal dismissed

enum Snap { HIDDEN, PEEK, HALF, FULL }

const SIDE_INSET := 8.0
const FLICK_VELOCITY := 700.0
const DRAG_SLOP := 6.0

@export var peek_height := 132.0
@export_range(0.2, 0.9) var half_ratio := 0.52
@export var allow_dismiss := true
@export var stops: Array[int] = [Snap.PEEK, Snap.HALF, Snap.FULL]
@export var dim_when_full := true

var state := Snap.HIDDEN
var panel: GlassPanel
var header: VBoxContainer
var body: VBoxContainer
var handle: Panel

var _dim: ColorRect
var _col: VBoxContainer
var _pad: Control
var _y := 0.0                 # current top of the panel (viewport coords)
var _dragging := false
var _pressing := false        # finger down on the header, not yet moved past the slop
var _press_y := 0.0
var _drag_offset := 0.0
var _last_y := 0.0
var _last_t := 0.0
var _vel := 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		# Tapping the dimmed map closes the sheet (iOS behaviour).
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and allow_dismiss:
			close())
	add_child(_dim)
	# Refresh the screen copy so the sheet also blurs HUD elements beneath it.
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	panel = GlassPanel.new()
	panel.theme_type_variation = &"GlassSheet"
	panel.tint = DS.GLASS_TINT_STRONG
	add_child(panel)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override(&"separation", DS.S3)
	panel.add_child(_col)
	var handle_box := CenterContainer.new()
	handle_box.custom_minimum_size = Vector2(0, 6)
	handle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(handle_box)
	handle = Panel.new()
	handle.theme_type_variation = &"SheetHandle"
	handle.custom_minimum_size = Vector2(38, 5)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle_box.add_child(handle)
	header = VBoxContainer.new()
	header.add_theme_constant_override(&"separation", DS.S2)
	_col.add_child(header)
	body = VBoxContainer.new()
	body.add_theme_constant_override(&"separation", DS.S3)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_col.add_child(body)
	# The panel overhangs the screen bottom by 40 pt; this spacer keeps the body
	# above the edge and the gesture bar.
	_pad = Control.new()
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(_pad)
	panel.gui_input.connect(_on_panel_input)


func _ready() -> void:
	resized.connect(_relayout)
	Screen.insets_changed.connect(_relayout)
	_y = size.y + 40.0
	_relayout()


func open(to: int = Snap.HALF) -> void:
	visible = true
	snap_to(to)


func close() -> void:
	snap_to(Snap.HIDDEN)


func is_open() -> bool:
	return state != Snap.HIDDEN


## Wide screens: the sheet is a panel on the right instead of rising from the bottom.
func side() -> bool:
	return Screen.landscape


func side_width() -> float:
	return clampf(size.x * 0.46, 340.0, 440.0)


func top_for(s: int) -> float:
	if side():
		return size.y + 40.0 if s == Snap.HIDDEN else Screen.top + DS.S2
	var h := size.y
	match s:
		Snap.HIDDEN:
			return h + 40.0
		Snap.PEEK:
			return h - peek_height - Screen.bottom
		Snap.HALF:
			return h * (1.0 - half_ratio)
		_:
			return Screen.top + DS.S3


func snap_to(s: int, animate: bool = true) -> void:
	_dragging = false
	_pressing = false
	var prev := state
	state = s
	var target := top_for(s)
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween().set_parallel(true)
		DS.ease_out(_tween)
		_tween.tween_method(_set_y, _y, target, Settings.dur(DS.DUR_SLOW))
		var to_alpha := 0.0 if s == Snap.HIDDEN else 1.0
		if prev == Snap.HIDDEN and s != Snap.HIDDEN:
			panel.modulate.a = 0.0
		_tween.tween_property(panel, "modulate:a", to_alpha, Settings.dur(DS.DUR_FAST if s == Snap.HIDDEN else DS.DUR))
	else:
		_set_y(target)
		panel.modulate.a = 0.0 if s == Snap.HIDDEN else 1.0
	if s == Snap.HIDDEN and prev != Snap.HIDDEN:
		Audio.play("sheet_down")
		dismissed.emit()
	elif prev == Snap.HIDDEN and s != Snap.HIDDEN:
		Audio.play("sheet_up")
	snapped.emit(s)


func _set_y(y: float) -> void:
	_y = y
	if side():
		# Slide in from the right; y here is just the animated value (hidden..top).
		var w := side_width()
		var t := clampf(inverse_lerp(size.y + 40.0, Screen.top + DS.S2, y), 0.0, 1.0)
		panel.size = Vector2(w, size.y - Screen.top - Screen.bottom - DS.S2 * 2.0 + 40.0)
		panel.position = Vector2(lerpf(size.x + 10.0, size.x - w - SIDE_INSET - Screen.right, t), Screen.top + DS.S2)
		_dim.modulate.a = 0.0
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = t > 0.001
		return
	panel.position = Vector2(SIDE_INSET + Screen.left, y)
	# The visible part ends at the screen bottom; pad the body so scroll content
	# never hides under the edge or the gesture bar.
	var visible_h := size.y - y
	panel.size = Vector2(size.x - SIDE_INSET * 2.0 - Screen.left - Screen.right, maxf(visible_h + 40.0, 0.0))
	if dim_when_full:
		var full := top_for(Snap.FULL)
		var half := top_for(Snap.HALF)
		_dim.modulate.a = clampf((half - y) / maxf(half - full, 1.0), 0.0, 1.0)
		_dim.mouse_filter = Control.MOUSE_FILTER_STOP if _dim.modulate.a > 0.5 else Control.MOUSE_FILTER_IGNORE
	panel.visible = y < size.y + 20.0


func _relayout() -> void:
	if not is_inside_tree():
		return
	_pad.custom_minimum_size = Vector2(0, Screen.bottom + 40.0)
	_set_y(top_for(state) if not _dragging else _y)


func _on_panel_input(e: InputEvent) -> void:
	# Only the header region (handle + header) drags the sheet, and only after the
	# finger moves past a small slop: a plain tap (e.g. on the close button) must
	# never be turned into a drag that re-snaps the sheet.
	var in_header := false
	if e is InputEventMouse:
		in_header = e.position.y <= header.position.y + header.size.y + DS.S3 + _col.position.y
	if side():
		return     # side panel: no drag (close with X, Back or by tapping the map)
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressing = in_header
			_press_y = e.global_position.y
			_last_y = e.global_position.y
			_last_t = Time.get_ticks_msec() / 1000.0
			_vel = 0.0
		else:
			_pressing = false
			if _dragging:
				_dragging = false
				_release()
				panel.accept_event()
	elif e is InputEventMouseMotion:
		if _pressing and not _dragging and absf(e.global_position.y - _press_y) > DRAG_SLOP:
			_dragging = true
			_drag_offset = e.global_position.y - _y
			if _tween:
				_tween.kill()
		if not _dragging:
			return
		var now := Time.get_ticks_msec() / 1000.0
		var dt := maxf(now - _last_t, 0.001)
		_vel = lerpf(_vel, (e.global_position.y - _last_y) / dt, 0.4)
		_last_y = e.global_position.y
		_last_t = now
		var y: float = e.global_position.y - _drag_offset
		var top := top_for(Snap.FULL)
		if y < top:  # rubber band above the top stop
			y = top - (top - y) * 0.25
		_set_y(y)
		panel.accept_event()


func _release() -> void:
	var options: Array[int] = stops.duplicate()
	if allow_dismiss:
		options.append(Snap.HIDDEN)
	options.sort_custom(func(a: int, b: int) -> bool: return top_for(a) < top_for(b))
	var best := options[0]
	if absf(_vel) > FLICK_VELOCITY:
		# Next stop in the flick direction.
		var going_down := _vel > 0
		best = options[0] if not going_down else options[options.size() - 1]
		for s in options:
			var t := top_for(s)
			if going_down and t > _y + 4.0:
				best = s
				break
		if not going_down:
			for i in range(options.size() - 1, -1, -1):
				if top_for(options[i]) < _y - 4.0:
					best = options[i]
					break
	else:
		var bd := INF
		for s in options:
			var d := absf(top_for(s) - _y)
			if d < bd:
				bd = d
				best = s
	Haptics.tap()
	snap_to(best)
