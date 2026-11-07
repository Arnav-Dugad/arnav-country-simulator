class_name MapView
extends Control
## Interactive world map.
## - Rendering: one batched mesh each for fills, borders and the player glow
##   (see MapMeshes + map/shaders). Map-mode colours cross-fade on the GPU.
## - Camera: `center` (world point under view centre) + `zoom` (px per unit).
## - Gestures: pinch zoom, pan with inertia, double-tap zoom, tap to select;
##   mouse wheel / drag / double-click on desktop.

signal country_tapped(index: int)
signal selection_changed(index: int)
signal camera_changed
signal country_long_pressed(index: int)

const FILL_SHADER := preload("res://map/shaders/map_fill.gdshader")
const LINE_SHADER := preload("res://map/shaders/map_line.gdshader")
const GLOW_SHADER := preload("res://map/shaders/map_glow.gdshader")

const MAX_ZOOM_FACTOR := 48.0     # max zoom relative to "whole world fits"
const TAP_SLOP := 12.0            # px a finger may move and still count as a tap
const TAP_TIME := 0.35
const DOUBLE_TAP_TIME := 0.32
const FRICTION := 4.2             # inertia decay per second
const BORDER_PX := 0.9
const PLAYER_LINE_PX := 1.6
const GLOW_PX := 12.0
const SELECT_LINE_PX := 2.2

## false = decorative background map (no input, used on onboarding/picker).
var interactive := true
var data: MapData
var zoom := 1.0
var center := Vector2.ZERO
var min_zoom := 0.05
var max_zoom := 3.0
var selected := -1
var player := -1
## Extra screen-space padding (top/bottom) for UI chrome, used when framing countries.
var frame_insets := Vector4(0, 0, 0, 0)  # left, top, right, bottom
## Screen rects (map-local) covered by UI chrome: labels are not drawn there.
var label_blockers: Array[Rect2] = []

var _world: Node2D
var _fill: MeshInstance2D
var _borders: MeshInstance2D
var _glow: MeshInstance2D
var _player_line: MeshInstance2D
var _sel_root: Node2D
var _sel_shadow: MeshInstance2D
var _sel_fill: MeshInstance2D
var _sel_line: MeshInstance2D
var _labels: MapLabels

var _fill_mat: ShaderMaterial
var _border_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _player_line_mat: ShaderMaterial
var _sel_line_mat: ShaderMaterial
var _tex_w := 256
var _img_from: Image
var _img_to: Image
var _tex_from: ImageTexture
var _tex_to: ImageTexture
var _colors_now := PackedColorArray()
var _colors_target := PackedColorArray()
var _blend := 1.0
var _blend_tween: Tween
var _hit_order := PackedInt32Array()  # small countries first
var _by_country: Array[PackedInt32Array] = []

# gesture state
var _touches := {}             # index -> position
var _velocity := Vector2.ZERO
var _tap_start_pos := Vector2.ZERO
var _tap_start_time := 0.0
var _tap_candidate := false
var _last_tap_time := -10.0
var _last_tap_pos := Vector2.ZERO
var _last_drag_time := 0.0
var _mouse_down := false
var _cam_tween: Tween
var _sel_tween: Tween
var _glow_bucket := -999
var _graticule: Array[Line2D] = []
# Feel: rubber-band edges, zoom momentum, long-press
const LONG_PRESS := 0.45
const ZOOM_SOFT_MIN := 0.82     # pinch may undershoot min zoom by this factor, then springs back
const ZOOM_SOFT_MAX := 1.15
var _raw_center := Vector2.ZERO  # finger-driven centre before edge resistance
var _zoom_vel := 0.0            # log-zoom per second after a pinch
var _pinch_mid := Vector2.ZERO
var _last_pinch_time := 0.0
var _long_fired := false
var _focus_cache := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	data = World.map
	_tex_w = 256 if data.count() <= 256 else 512
	_by_country = MapMeshes.rings_by_country(data)
	_build_nodes()
	resized.connect(_on_resized)
	_on_resized()
	set_colors(MapModes.political(data), false)


# ------------------------------------------------------------------ build ----
func _build_nodes() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	var draw_order := range(data.count())
	draw_order.sort_custom(func(a: int, b: int) -> bool: return data.area[a] > data.area[b])
	_hit_order = PackedInt32Array(draw_order.duplicate())
	_hit_order.reverse()

	_img_from = Image.create(_tex_w, 1, false, Image.FORMAT_RGBA8)
	_img_to = Image.create(_tex_w, 1, false, Image.FORMAT_RGBA8)
	_tex_from = ImageTexture.create_from_image(_img_from)
	_tex_to = ImageTexture.create_from_image(_img_to)

	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = FILL_SHADER
	_fill_mat.set_shader_parameter(&"colors_from", _tex_from)
	_fill_mat.set_shader_parameter(&"colors_to", _tex_to)
	_fill_mat.set_shader_parameter(&"tex_width", float(_tex_w))
	_fill_mat.set_shader_parameter(&"player_tint", DS.GOLD)
	_fill_mat.set_shader_parameter(&"world_half_height", data.world_rect.size.y * 0.5)
	_build_graticule()
	_fill = MeshInstance2D.new()
	_fill.mesh = MapMeshes.fill_mesh(data, PackedInt32Array(draw_order), _tex_w)
	_fill.material = _fill_mat
	_world.add_child(_fill)

	_border_mat = _line_material(LINE_SHADER, DS.BORDER, 0.6)
	_borders = MeshInstance2D.new()
	_borders.mesh = MapMeshes.line_mesh(data.ring_points)
	_borders.material = _border_mat
	_world.add_child(_borders)

	_glow_mat = _line_material(GLOW_SHADER, Color(DS.GOLD, 0.22), 1.0)
	_glow_mat.set_shader_parameter(&"pulse", 0.35)
	_glow = MeshInstance2D.new()
	_glow.material = _glow_mat
	_world.add_child(_glow)
	_player_line_mat = _line_material(LINE_SHADER, Color(DS.GOLD, 0.85), 0.5)
	_player_line = MeshInstance2D.new()
	_player_line.material = _player_line_mat
	_world.add_child(_player_line)

	_sel_root = Node2D.new()
	_sel_root.visible = false
	_world.add_child(_sel_root)
	_sel_shadow = MeshInstance2D.new()
	_sel_shadow.modulate = Color(0, 0, 0, 0.45)
	_sel_root.add_child(_sel_shadow)
	_sel_fill = MeshInstance2D.new()
	_sel_root.add_child(_sel_fill)
	_sel_line_mat = _line_material(LINE_SHADER, Color(1, 1, 1, 0.95), 0.5)
	_sel_line_mat.set_shader_parameter(&"pulse", 0.25)
	_sel_line = MeshInstance2D.new()
	_sel_line.material = _sel_line_mat
	_sel_root.add_child(_sel_line)

	_labels = MapLabels.new()
	_labels.map = self
	add_child(_labels)


## Faint latitude/longitude lines every 30° (and the equator a touch brighter).
func _build_graticule() -> void:
	var lines: Array[PackedVector2Array] = []
	for lon in range(-180, 181, 30):
		var pts := PackedVector2Array()
		for lat in range(-84, 85, 3):
			pts.append(Geo.equal_earth(float(lon), float(lat)))
		lines.append(pts)
	for lat in range(-60, 61, 30):
		var pts2 := PackedVector2Array()
		for lon2 in range(-180, 181, 5):
			pts2.append(Geo.equal_earth(float(lon2), float(lat)))
		lines.append(pts2)
	for k in lines.size():
		var l := Line2D.new()
		l.points = lines[k]
		l.antialiased = true
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		var equator := k == lines.size() - 3   # lat 0 is the middle parallel
		l.default_color = Color(0.75, 0.85, 1.0, 0.085 if equator else 0.05)
		l.set_meta(&"w", 1.2 if equator else 0.9)
		_world.add_child(l)
		_graticule.append(l)


func _line_material(shader: Shader, color: Color, aa: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter(&"line_color", color)
	m.set_shader_parameter(&"aa", aa)
	return m


# ----------------------------------------------------------------- colours ---
## Set per-country colours; cross-fades from what is currently shown.
func set_colors(colors: PackedColorArray, animate: bool = true) -> void:
	if colors.size() != data.count():
		push_error("MapView.set_colors: expected %d colours" % data.count())
		return
	_colors_now = _current_colors()
	_colors_target = colors
	if not animate or _colors_now.is_empty():
		_colors_now = colors
	for i in data.count():
		_img_from.set_pixel(i, 0, _colors_now[i])
		_img_to.set_pixel(i, 0, colors[i])
	_tex_from.update(_img_from)
	_tex_to.update(_img_to)
	if _blend_tween:
		_blend_tween.kill()
	if animate:
		_set_blend(0.0)
		_blend_tween = create_tween()
		DS.ease_out(_blend_tween)
		_blend_tween.tween_method(_set_blend, 0.0, 1.0, Settings.dur(0.55))
	else:
		_set_blend(1.0)
	if selected >= 0:
		_sel_fill.modulate = colors[selected].lightened(0.12)


func country_color(i: int) -> Color:
	return _colors_target[i] if i >= 0 and i < _colors_target.size() else DS.LAND


func _current_colors() -> PackedColorArray:
	if _colors_target.is_empty():
		return PackedColorArray()
	if _blend >= 1.0 or _colors_now.size() != _colors_target.size():
		return _colors_target.duplicate()
	var out := PackedColorArray()
	out.resize(_colors_target.size())
	for i in out.size():
		out[i] = _colors_now[i].lerp(_colors_target[i], _blend)
	return out


func _set_blend(v: float) -> void:
	_blend = v
	_fill_mat.set_shader_parameter(&"blend", v)


# ---------------------------------------------------------- player/select ----
func set_player(i: int) -> void:
	player = i
	_fill_mat.set_shader_parameter(&"player_index", float(i))
	var rings: Array[PackedVector2Array] = []
	if i >= 0:
		for r in _by_country[i]:
			rings.append(data.ring_points[r])
	_player_line.mesh = MapMeshes.line_mesh(rings) if not rings.is_empty() else null
	_glow_bucket = -999
	_update_line_widths()


## The glow is wide, so it is built from an outline simplified to the current
## zoom (no coastline spikes). Rebuilt only when zoom crosses a half-octave.
func _rebuild_glow() -> void:
	var bucket := int(round(log(zoom) / log(2.0) * 2.0))
	if bucket == _glow_bucket:
		return
	_glow_bucket = bucket
	if player < 0:
		_glow.mesh = null
		return
	var tol := GLOW_PX * 0.45 / pow(2.0, bucket * 0.5)
	var rings: Array[PackedVector2Array] = []
	for r in _by_country[player]:
		var pts := Geo.remove_spikes(Geo.simplify_ring(data.ring_points[r], tol), tol * 2.5)
		if pts.size() >= 3 and absf(Geo.signed_area(pts)) > tol * tol * 4.0:
			rings.append(pts)
	_glow.mesh = MapMeshes.line_mesh(rings, false) if not rings.is_empty() else null


func select(i: int, focus: bool = false) -> void:
	if i == selected:
		if focus and i >= 0:
			focus_country(i)
		return
	selected = i
	_fill_mat.set_shader_parameter(&"selected_index", float(i))
	if _sel_tween:
		_sel_tween.kill()
	if i < 0:
		_sel_root.visible = false
		selection_changed.emit(i)
		return
	var fill := MapMeshes.country_fill_mesh(data, i)
	var rings: Array[PackedVector2Array] = []
	for r in _by_country[i]:
		rings.append(data.ring_points[r])
	_sel_shadow.mesh = fill
	_sel_fill.mesh = fill
	_sel_fill.modulate = country_color(i).lightened(0.12)
	_sel_line.mesh = MapMeshes.line_mesh(rings)
	# Raise around the country's visual centre.
	var c := data.bbox(i).get_center()
	_sel_root.position = c
	for n in [_sel_shadow, _sel_fill, _sel_line]:
		(n as Node2D).position = -c
	_sel_root.visible = true
	_sel_root.scale = Vector2.ONE
	_sel_line_mat.set_shader_parameter(&"grow", 0.0)
	_sel_tween = create_tween().set_parallel(true)
	DS.spring(_sel_tween)
	var lift := 1.0 + clampf(10.0 / (data.bbox(i).size.length() * zoom + 1.0), 0.012, 0.06)
	_sel_tween.tween_property(_sel_root, "scale", Vector2.ONE * lift, Settings.dur(0.4))
	DS.ease_out(_sel_tween)
	_sel_tween.tween_method(func(v: float) -> void: _sel_line_mat.set_shader_parameter(&"grow", v),
			0.0, 1.0, Settings.dur(0.35))
	_update_line_widths()
	if focus:
		focus_country(i)
	selection_changed.emit(i)


# ------------------------------------------------------------------ camera ---
func _on_resized() -> void:
	if data == null or size.x <= 0:
		return
	var first := min_zoom == 0.05
	min_zoom = size.x / data.world_rect.size.x * 0.98
	max_zoom = min_zoom * MAX_ZOOM_FACTOR
	if first:
		zoom = min_zoom * 2.2
		center = data.world_rect.get_center() + Vector2(0, -data.world_rect.size.y * 0.12)
	_apply_camera()


func world_to_screen(p: Vector2) -> Vector2:
	return (p - center) * zoom + size * 0.5


func screen_to_world(p: Vector2) -> Vector2:
	return (p - size * 0.5) / zoom + center


func zoom_at(screen_pos: Vector2, factor: float, soft: bool = false) -> void:
	var anchor := screen_to_world(screen_pos)
	if soft:  # gesture: allow a little over/undershoot that springs back
		zoom = clampf(zoom * factor, min_zoom * ZOOM_SOFT_MIN, max_zoom * ZOOM_SOFT_MAX)
	else:
		zoom = clampf(zoom * factor, min_zoom, max_zoom)
	center = anchor - (screen_pos - size * 0.5) / zoom
	_raw_center = center
	_apply_camera(soft)


func pan_by(screen_delta: Vector2) -> void:
	center -= screen_delta / zoom
	_raw_center = center
	_apply_camera()


## Finger-driven pan with iOS-style resistance past the edges.
func pan_soft(screen_delta: Vector2) -> void:
	_raw_center -= screen_delta / zoom
	var lim := _center_limits()
	var cl := Vector2(clampf(_raw_center.x, lim.position.x, lim.end.x), clampf(_raw_center.y, lim.position.y, lim.end.y))
	var over := (_raw_center - cl) * zoom
	over = Vector2(_rubber(over.x, size.x), _rubber(over.y, size.y))
	center = cl + over / zoom
	_apply_camera(true)


static func _rubber(x: float, d: float) -> float:
	if absf(x) < 0.001:
		return 0.0
	return signf(x) * (1.0 - 1.0 / (absf(x) * 0.55 / maxf(d, 1.0) + 1.0)) * d


## Range the view centre may occupy at the current zoom.
func _center_limits() -> Rect2:
	var wr := data.world_rect
	var half := size * 0.5 / zoom
	var lo := Vector2.ZERO
	var hi := Vector2.ZERO
	if wr.size.x <= half.x * 2.0:
		lo.x = wr.get_center().x
		hi.x = lo.x
	else:
		lo.x = wr.position.x + half.x * 0.35
		hi.x = wr.end.x - half.x * 0.35
	if wr.size.y <= half.y * 2.0:
		lo.y = wr.end.y - half.y
		hi.y = wr.position.y + half.y
	else:
		lo.y = wr.position.y + half.y * 0.5
		hi.y = wr.end.y - half.y * 0.5
	return Rect2(lo, hi - lo)


func _out_of_bounds() -> bool:
	var lim := _center_limits().grow(0.01)
	return not lim.has_point(center) or zoom < min_zoom * 0.999 or zoom > max_zoom * 1.001


## Smoothly animate the camera to a world centre and zoom.
func fly_to(target_center: Vector2, target_zoom: float, duration: float = 0.6) -> void:
	_velocity = Vector2.ZERO
	if _cam_tween:
		_cam_tween.kill()
	target_zoom = clampf(target_zoom, min_zoom, max_zoom)
	var from_c := center
	var from_lz := log(zoom)
	var to_lz := log(target_zoom)
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(t: float) -> void:
		zoom = exp(lerpf(from_lz, to_lz, t))
		center = from_c.lerp(target_center, t)
		_apply_camera(), 0.0, 1.0, Settings.dur(duration))


## Bounds of a country's major landmasses (ignores far-flung islands such as the
## Aleutians, which would otherwise make the USA span the whole map).
func focus_rect(i: int) -> Rect2:
	if _focus_cache.has(i):
		return _focus_cache[i]
	var largest := 0.0
	for r in _by_country[i]:
		largest = maxf(largest, absf(Geo.signed_area(data.ring_points[r])))
	var rect := Rect2()
	var first := true
	for r in _by_country[i]:
		if absf(Geo.signed_area(data.ring_points[r])) >= largest * 0.2:
			var b := Geo.bounds(data.ring_points[r])
			rect = b if first else rect.merge(b)
			first = false
	if first:
		rect = data.bbox(i)
	_focus_cache[i] = rect
	return rect


## Frame a country, leaving room for UI chrome (frame_insets).
func focus_country(i: int, duration: float = 0.7) -> void:
	var bb := focus_rect(i)
	var avail := size - Vector2(frame_insets.x + frame_insets.z, frame_insets.y + frame_insets.w)
	avail = avail.max(Vector2(80, 80))
	var z := minf(avail.x / maxf(bb.size.x, 1.0), avail.y / maxf(bb.size.y, 1.0)) * 0.72
	z = clampf(z, min_zoom * 1.5, max_zoom * 0.6)
	# Shift centre so the country sits in the middle of the free area.
	var free_center := Vector2(frame_insets.x + avail.x * 0.5, frame_insets.y + avail.y * 0.5)
	var c := bb.get_center() - (free_center - size * 0.5) / z
	fly_to(c, z, duration)


## soft = a gesture is in progress: overshoot is allowed (it springs back later).
func _apply_camera(soft: bool = false) -> void:
	if not soft:
		zoom = clampf(zoom, min_zoom, max_zoom)
		# Keep the view over the world; centre it when the world is smaller than the view.
		var lim := _center_limits()
		center = Vector2(clampf(center.x, lim.position.x, lim.end.x), clampf(center.y, lim.position.y, lim.end.y))
	_world.transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, size * 0.5 - center * zoom)
	_update_line_widths()
	_labels.queue_redraw()
	camera_changed.emit()


func _update_line_widths() -> void:
	var px := 1.0 / zoom
	for l in _graticule:
		l.width = float(l.get_meta(&"w")) * px
	# Thin borders fade out when zoomed far out to avoid a "wireframe" look.
	var zt := clampf((zoom / min_zoom - 1.0) / 3.0, 0.0, 1.0)
	_border_mat.set_shader_parameter(&"half_width", (BORDER_PX * 0.5 + 0.5) * px)
	_border_mat.set_shader_parameter(&"aa", 1.0 / (BORDER_PX * 0.5 + 0.5))
	_border_mat.set_shader_parameter(&"line_color", Color(DS.BORDER, DS.BORDER.a * lerpf(0.55, 1.0, zt)))
	_glow_mat.set_shader_parameter(&"half_width", GLOW_PX * px)
	_rebuild_glow()
	_player_line_mat.set_shader_parameter(&"half_width", (PLAYER_LINE_PX * 0.5 + 0.5) * px)
	_player_line_mat.set_shader_parameter(&"aa", 1.0 / (PLAYER_LINE_PX * 0.5 + 0.5))
	if _sel_root.visible:
		var s := _sel_root.scale.x
		_sel_line_mat.set_shader_parameter(&"half_width", (SELECT_LINE_PX * 0.5 + 0.5) * px / s)
		_sel_line_mat.set_shader_parameter(&"aa", 1.0 / (SELECT_LINE_PX * 0.5 + 0.5))
		_sel_shadow.position = -_sel_root.position + Vector2(0, 5.0 * px / s)


# --------------------------------------------------------------- hit test ----
func country_at(screen_pos: Vector2) -> int:
	var w := screen_to_world(screen_pos)
	for c in _hit_order:
		if not data.bbox(c).grow(0.5).has_point(w):
			continue
		for r in _by_country[c]:
			if Geometry2D.is_point_in_polygon(w, data.ring_points[r]):
				return c
	# Tiny states: accept taps near their label point.
	var best := -1
	var best_d := 22.0
	for c in _hit_order:
		if data.area[c] * zoom * zoom > 600.0:
			break
		var d := world_to_screen(data.label_pos[c]).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = c
	return best


# ------------------------------------------------------------------ input ----
func _process(delta: float) -> void:
	var gesturing := not _touches.is_empty() or _mouse_down
	if not gesturing:
		var flying := _cam_tween != null and _cam_tween.is_running()
		if _velocity.length_squared() > 4.0:
			pan_soft(_velocity * delta)
			# Fling into an edge: brake hard so it bounces softly instead of sliding on.
			_velocity *= exp(-(FRICTION if not _out_of_bounds() else 22.0) * delta)
		elif absf(_zoom_vel) > 0.02:
			zoom_at(_pinch_mid, exp(_zoom_vel * delta), true)
			_zoom_vel *= exp(-7.0 * delta)
		elif not flying and _out_of_bounds():
			_spring_back(delta)
	elif _tap_candidate and not _long_fired and Time.get_ticks_msec() / 1000.0 - _tap_start_time > LONG_PRESS:
		_long_fired = true
		_tap_candidate = false
		var c := country_at(_tap_start_pos)
		if c >= 0:
			Haptics.select(false)
			country_long_pressed.emit(c)
	if _sel_root.visible:
		_update_line_widths()


func _spring_back(delta: float) -> void:
	var k := 1.0 - exp(-14.0 * delta)
	var target_zoom := clampf(zoom, min_zoom, max_zoom)
	if absf(target_zoom - zoom) > 0.0001:
		zoom_at(size * 0.5, pow(target_zoom / zoom, k), true)
	var lim := _center_limits()
	var cl := Vector2(clampf(center.x, lim.position.x, lim.end.x), clampf(center.y, lim.position.y, lim.end.y))
	center = center.lerp(cl, k)
	_raw_center = center
	if center.distance_to(cl) * zoom < 0.4 and absf(target_zoom - zoom) < 0.0001:
		center = cl
		_apply_camera()
	else:
		_apply_camera(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if _mouse_down:
			_drag_pan(event.relative)
			if event.position.distance_to(_tap_start_pos) > TAP_SLOP:
				_tap_candidate = false
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, event.factor)
	elif event is InputEventPanGesture:
		pan_by(-event.delta * 12.0)
	else:
		return
	accept_event()


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		_stop_motion()
		if _touches.size() == 1:
			_begin_tap(e.position)
		else:
			_tap_candidate = false
	else:
		_touches.erase(e.index)
		if _touches.is_empty():
			_end_tap(e.position)


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		_touches[e.index] = e.position
	var prev: Vector2 = _touches[e.index]
	if _touches.size() >= 2:
		var keys := _touches.keys()
		var other_key = keys[1] if keys[0] == e.index else keys[0]
		var other: Vector2 = _touches[other_key]
		var old_d := prev.distance_to(other)
		var new_d := e.position.distance_to(other)
		var old_mid := (prev + other) * 0.5
		var new_mid := (e.position + other) * 0.5
		if old_d > 1.0:
			var f := new_d / old_d
			zoom_at(new_mid, f, true)
			var now := Time.get_ticks_msec() / 1000.0
			var dt := clampf(now - _last_pinch_time, 1.0 / 240.0, 0.1)
			_zoom_vel = lerpf(_zoom_vel, log(f) / dt, 0.3)
			_last_pinch_time = now
			_pinch_mid = new_mid
		pan_soft(new_mid - old_mid)
		_velocity = Vector2.ZERO
	else:
		_drag_pan(e.position - prev)
	_touches[e.index] = e.position
	if e.position.distance_to(_tap_start_pos) > TAP_SLOP:
		_tap_candidate = false


func _on_mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				_stop_motion()
				zoom_at(e.position, 1.0 + 0.12 * e.factor if e.factor > 0 else 1.12)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				_stop_motion()
				zoom_at(e.position, 1.0 / (1.0 + 0.12 * e.factor if e.factor > 0 else 1.12))
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				_mouse_down = true
				_stop_motion()
				if e.double_click:
					_double_tap(e.position)
					_tap_candidate = false
				else:
					_begin_tap(e.position)
			else:
				_mouse_down = false
				_end_tap(e.position, false)


func _drag_pan(delta: Vector2) -> void:
	pan_soft(delta)
	var now := Time.get_ticks_msec() / 1000.0
	var dt := maxf(now - _last_drag_time, 1.0 / 120.0)
	_last_drag_time = now
	var v := delta / dt
	_velocity = _velocity.lerp(v, 0.35) if dt < 0.1 else v * 0.5


func _stop_motion() -> void:
	_velocity = Vector2.ZERO
	_zoom_vel = 0.0
	_raw_center = center
	if _cam_tween and _cam_tween.is_running():
		_cam_tween.kill()


func _begin_tap(pos: Vector2) -> void:
	_tap_candidate = true
	_long_fired = false
	_tap_start_pos = pos
	_tap_start_time = Time.get_ticks_msec() / 1000.0
	_last_drag_time = _tap_start_time


func _end_tap(pos: Vector2, allow_double: bool = true) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Flicks: drop inertia if the finger rested before lifting.
	if now - _last_drag_time > 0.08:
		_velocity = Vector2.ZERO
	if now - _last_pinch_time > 0.08:
		_zoom_vel = 0.0
	if not _tap_candidate or now - _tap_start_time > TAP_TIME:
		return
	_tap_candidate = false
	if allow_double and now - _last_tap_time < DOUBLE_TAP_TIME and pos.distance_to(_last_tap_pos) < 40.0:
		_last_tap_time = -10.0
		_double_tap(pos)
		return
	_last_tap_time = now
	_last_tap_pos = pos
	var c := country_at(pos)
	country_tapped.emit(c)


func _double_tap(pos: Vector2) -> void:
	var anchor := screen_to_world(pos)
	var z := clampf(zoom * 2.0, min_zoom, max_zoom)
	fly_to(anchor - (pos - size * 0.5) / z, z, 0.38)
	Haptics.tap()
