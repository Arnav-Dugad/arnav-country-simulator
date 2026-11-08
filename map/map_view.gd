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

var _overlays: MapOverlays

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
# Two-finger tap = zoom out (Apple/Google Maps)
var _two_tap := false
var _two_tap_time := 0.0
var _two_tap_zoom := 1.0


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
var _shelf: MeshInstance2D
var _shelf_mat: ShaderMaterial
const SHELF_PX := 9.0


func _build_nodes() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_globe_bg = Node2D.new()
	_globe_bg.draw.connect(_draw_globe_bg)
	_world.add_child(_globe_bg)

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
	# Shallow water along every coast, beneath the land (see MapMeshes.shelf_mesh).
	_shelf_mat = _line_material(GLOW_SHADER, Color(0.35, 0.62, 0.9, 0.10), 1.0)
	_shelf_mat.set_shader_parameter(&"pulse", 0.0)
	_shelf = MeshInstance2D.new()
	_shelf.mesh = _baked("res://data/map_shelf.res", func() -> ArrayMesh: return MapMeshes.shelf_mesh(data))
	_shelf.material = _shelf_mat
	_world.add_child(_shelf)
	_fill = MeshInstance2D.new()
	_fill.mesh = _baked("res://data/map_fill.res", func() -> ArrayMesh:
		return MapMeshes.fill_mesh(data, PackedInt32Array(draw_order), _tex_w))
	_fill.material = _fill_mat
	_world.add_child(_fill)

	_border_mat = _line_material(LINE_SHADER, DS.BORDER, 0.6)
	_borders = MeshInstance2D.new()
	_borders.mesh = _baked("res://data/map_borders.res", func() -> ArrayMesh:
		return MapMeshes.line_mesh(data.ring_points))
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

	_overlays = MapOverlays.new()
	_overlays.map = self
	add_child(_overlays)
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
	_grat_mat = ShaderMaterial.new()
	_grat_mat.shader = GRATICULE_SHADER
	for k in lines.size():
		var l := Line2D.new()
		l.material = _grat_mat
		l.points = lines[k]
		l.antialiased = true
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		var equator := k == lines.size() - 3   # lat 0 is the middle parallel
		l.default_color = Color(0.75, 0.85, 1.0, 0.085 if equator else 0.05)
		l.set_meta(&"w", 1.2 if equator else 0.9)
		_world.add_child(l)
		_graticule.append(l)


## A mesh baked offline by tools/bake_meshes.gd (faster startup on phones), or
## built now if the baked file is missing or doesn't match the map data.
func _baked(path: String, build: Callable) -> ArrayMesh:
	if ResourceLoader.exists(path):
		var m: ArrayMesh = load(path)
		if m and int(m.get_meta(&"count", -1)) == data.count():
			return m
	return build.call()


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
	_glow_bucket = -999       # _rebuild_glow also rebuilds the player outline
	_update_line_widths()


## A crisp outline for one country, simplified to the current zoom: sub-pixel
## zig-zags and hairpin inlets would otherwise fan the stroke into bright
## "hairs" along ragged coasts (Baja California, fjords, the Gulf coast).
const OUTLINE_SIMPLIFY_PX := 0.6
const OUTLINE_SPIKE_PX := 2.5
const OUTLINE_MIN_ISLAND_PX := 3.0


var _outline_cache := {}      # Vector2i(country, zoom bucket) -> ArrayMesh


func _outline_mesh(i: int) -> ArrayMesh:
	if i < 0:
		return null
	var bucket := int(round(log(zoom) / log(2.0) * 2.0))
	var key := Vector2i(i, bucket)
	if _outline_cache.has(key):
		return _outline_cache[key]
	if _outline_cache.size() > 48:
		_outline_cache.clear()
	_outline_cache[key] = _build_outline(i, bucket)
	return _outline_cache[key]


func _build_outline(i: int, bucket: int) -> ArrayMesh:
	var px := 1.0 / pow(2.0, bucket * 0.5)   # world units per pixel, half-octave steps
	var rings: Array[PackedVector2Array] = []
	for r in _by_country[i]:
		var pts := Geo.remove_spikes(Geo.simplify_ring(data.ring_points[r], OUTLINE_SIMPLIFY_PX * px),
			OUTLINE_SPIKE_PX * px, -0.5)
		# Islets smaller than a few pixels keep their fill but get no outline (no specks).
		if pts.size() >= 3 and absf(Geo.signed_area(pts)) > OUTLINE_MIN_ISLAND_PX * OUTLINE_MIN_ISLAND_PX * px * px:
			rings.append(pts)
	return MapMeshes.line_mesh(rings) if not rings.is_empty() else null


## The glow is wide, so it is built from an outline simplified to the current
## zoom (no coastline spikes). Rebuilt only when zoom crosses a half-octave.
func _rebuild_glow() -> void:
	var bucket := int(round(log(zoom) / log(2.0) * 2.0))
	if bucket == _glow_bucket:
		return
	_glow_bucket = bucket
	_player_line.mesh = _outline_mesh(player)
	if _sel_root.visible and selected >= 0:
		_sel_line.mesh = _outline_mesh(selected)
	if player < 0:
		_glow.mesh = null
		return
	var key := Vector2i(-1 - player, bucket)       # glow meshes share the outline cache
	if not _outline_cache.has(key):
		var tol := GLOW_PX * 0.45 / pow(2.0, bucket * 0.5)
		var rings: Array[PackedVector2Array] = []
		for r in _by_country[player]:
			var pts := Geo.remove_spikes(Geo.simplify_ring(data.ring_points[r], tol), tol * 2.5)
			if pts.size() >= 3 and absf(Geo.signed_area(pts)) > tol * tol * 4.0:
				rings.append(pts)
		_outline_cache[key] = MapMeshes.line_mesh(rings, false) if not rings.is_empty() else null
	_glow.mesh = _outline_cache[key]


## Election night: dim the world and let one country breathe (i < 0 / on=false: off).
var _spot_tween: Tween


## A celebration over a country ("skyline" or "fireworks").
func celebrate(kind: String, i: int) -> void:
	_overlays.celebrate(kind, i)


## A state visit: frame both countries and draw a flight from a to b.
func show_flight(a: int, b: int) -> void:
	_frame(focus_rect(a).merge(focus_rect(b)), 0.7)
	_overlays.flight(a, b)


func spotlight(i: int, on: bool, color: Color = DS.GOLD) -> void:
	if _spot_tween:
		_spot_tween.kill()
	_fill_mat.set_shader_parameter(&"spot_color", color)
	# Unset shader parameters read back as null: start from 0 then.
	var cur: Variant = _fill_mat.get_shader_parameter(&"spotlight")
	var from := float(cur) if cur != null else 0.0
	_spot_tween = create_tween()
	DS.ease_out(_spot_tween)
	_spot_tween.tween_method(func(v: float) -> void: _fill_mat.set_shader_parameter(&"spotlight", v),
		from, 1.0 if on and i >= 0 else 0.0, Settings.dur(0.9))


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
	_sel_shadow.mesh = fill
	_sel_fill.mesh = fill
	_sel_fill.modulate = country_color(i).lightened(0.12)
	_sel_line.mesh = _outline_mesh(i)
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
	# Long trips glide along an arc: rise (zoom out) mid-flight, then settle, the
	# way map apps fly between places. Short hops just slide.
	var travel := from_c.distance_to(target_center) * minf(zoom, target_zoom)
	var bump := clampf(log(maxf(travel / maxf(size.length(), 1.0), 1.0)) * 0.9, 0.0, 1.6)
	if bump > 0.05:
		duration *= 1.0 + bump * 0.35
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(t: float) -> void:
		var lz := lerpf(from_lz, to_lz, t) - bump * sin(PI * t)
		zoom = exp(lz)
		# Move the centre a bit faster than the zoom so the target stays in view.
		var tc := smoothstep(0.0, 1.0, clampf(t * 1.12, 0.0, 1.0))
		center = from_c.lerp(target_center, tc)
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
	_frame(focus_rect(i), duration)


## Frame a world rectangle in the free area between the UI chrome.
func _frame(bb: Rect2, duration: float) -> void:
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
	if _shelf_mat:
		_shelf_mat.set_shader_parameter(&"half_width", SHELF_PX * px)
	_rebuild_glow()
	_player_line_mat.set_shader_parameter(&"half_width", (PLAYER_LINE_PX * 0.5 + 0.5) * px)
	_player_line_mat.set_shader_parameter(&"aa", 1.0 / (PLAYER_LINE_PX * 0.5 + 0.5))
	if _sel_root.visible:
		var s := _sel_root.scale.x
		_sel_line_mat.set_shader_parameter(&"half_width", (SELECT_LINE_PX * 0.5 + 0.5) * px / s)
		_sel_line_mat.set_shader_parameter(&"aa", 1.0 / (SELECT_LINE_PX * 0.5 + 0.5))
		_sel_shadow.position = -_sel_root.position + Vector2(0, 5.0 * px / s)



# ------------------------------------------------------------------ globe ----
## Pinch out past the whole world and the flat map curls into a slowly turning
## globe. Drag to spin it, tap a country, pinch in or double-tap to come back.
const GRATICULE_SHADER := preload("res://map/shaders/map_graticule.gdshader")
const GLOBE_ENTER := 0.9        # release a pinch below min_zoom x this to form the globe
const GLOBE_SPIN := 0.05        # rad per second of idle rotation
var globe := 0.0
var globe_rot := Vector2.ZERO   # lon, lat (radians) facing the viewer
var globe_on := false
var _globe_tween: Tween
var _globe_bg: Node2D
var _grat_mat: ShaderMaterial
var _globe_pinch := 1.0


func _globe_materials() -> Array:
	return [_fill_mat, _border_mat, _glow_mat, _player_line_mat, _sel_line_mat, _grat_mat, _shelf_mat]


## Points the globe at the current view and sizes it to the screen.
func _globe_frame() -> void:
	var ll := Geo.equal_earth_inverse(center)
	if not globe_on:
		globe_rot = Vector2(ll.x, clampf(ll.y, -1.1, 1.1))
	for m in _globe_materials():
		m.set_shader_parameter(&"globe_center", center)
		m.set_shader_parameter(&"globe_radius", minf(size.x, size.y) * 0.44 / zoom)
		m.set_shader_parameter(&"globe_rot", globe_rot)


func _set_globe(v: float) -> void:
	globe = v
	_globe_frame()
	for m in _globe_materials():
		m.set_shader_parameter(&"globe", v)
	var flat := v < 0.04
	_labels.visible = flat
	_overlays.visible = flat
	if not flat:
		_sel_root.visible = false
	elif selected >= 0:
		_sel_root.visible = true
	_globe_bg.queue_redraw()


func _animate_globe(to: float, dur: float) -> void:
	if _globe_tween:
		_globe_tween.kill()
	_globe_tween = create_tween()
	_globe_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_globe_tween.tween_method(_set_globe, globe, to, Settings.dur(dur))


func enter_globe() -> void:
	if globe_on:
		return
	_stop_motion()
	_globe_frame()
	globe_on = true
	select(-1)
	Haptics.success(false)
	# Turn to face your own country while the globe forms.
	var from_rot := globe_rot
	var to_rot := from_rot
	if player >= 0:
		var ll := Geo.equal_earth_inverse(focus_rect(player).get_center())
		to_rot = Vector2(from_rot.x + wrapf(ll.x - from_rot.x, -PI, PI), clampf(ll.y * 0.8, -1.0, 1.0))
	if _globe_tween:
		_globe_tween.kill()
	_globe_tween = create_tween()
	_globe_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_globe_tween.tween_method(func(t: float) -> void:
		globe_rot = from_rot.lerp(to_rot, smoothstep(0.2, 1.0, t))
		_set_globe(t), globe, 1.0, Settings.dur(1.2))


## Back to the flat map, looking at what faced you on the globe.
func exit_globe(focus_lonlat: Vector2 = Vector2.INF) -> void:
	if not globe_on:
		return
	globe_on = false
	var ll := globe_rot if focus_lonlat == Vector2.INF else focus_lonlat
	ll.x = wrapf(ll.x, -PI, PI)
	var target := Geo.equal_earth(rad_to_deg(ll.x), rad_to_deg(ll.y))
	var from_c := center
	var from_z := zoom
	var to_z := clampf(min_zoom * 1.8, min_zoom, max_zoom)
	if _globe_tween:
		_globe_tween.kill()
	Haptics.tap()
	_globe_tween = create_tween()
	_globe_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_globe_tween.tween_method(func(t: float) -> void:
		zoom = exp(lerpf(log(from_z), log(to_z), t))
		center = from_c.lerp(target, t)
		_raw_center = center
		_set_globe(1.0 - t)
		_apply_camera(true), 0.0, 1.0, Settings.dur(0.85))
	_globe_tween.tween_callback(func() -> void:
		_set_globe(0.0)
		_apply_camera())


## Country under a screen point on the globe (-1 = ocean / space).
func globe_country_at(screen_pos: Vector2) -> int:
	var w := screen_to_world(screen_pos)
	var r := minf(size.x, size.y) * 0.44 / zoom
	var v := (w - center) / r
	var x := v.x
	var y := -v.y
	var r2 := x * x + y * y
	if r2 > 1.0:
		return -1
	var z := sqrt(1.0 - r2)
	var p0 := globe_rot.y
	var lat := asin(clampf(z * sin(p0) + y * cos(p0), -1.0, 1.0))
	var lon := wrapf(globe_rot.x + atan2(x, z * cos(p0) - y * sin(p0)), -PI, PI)
	return _country_at_world(Geo.equal_earth(rad_to_deg(lon), rad_to_deg(lat)))


func _globe_lonlat_at(screen_pos: Vector2) -> Vector2:
	var w := screen_to_world(screen_pos)
	var r := minf(size.x, size.y) * 0.44 / zoom
	var v := (w - center) / r
	var x := clampf(v.x, -1.0, 1.0)
	var y := clampf(-v.y, -1.0, 1.0)
	var z := sqrt(maxf(1.0 - x * x - y * y, 0.0))
	var p0 := globe_rot.y
	return Vector2(globe_rot.x + atan2(x, z * cos(p0) - y * sin(p0)), asin(clampf(z * sin(p0) + y * cos(p0), -1.0, 1.0)))


func _globe_drag(delta: Vector2) -> void:
	var r_px := minf(size.x, size.y) * 0.44
	globe_rot.x -= delta.x / r_px
	globe_rot.y = clampf(globe_rot.y + delta.y / r_px, -1.25, 1.25)
	_globe_frame()


## Ocean sphere + soft atmosphere, drawn behind the countries while in globe mode.
func _draw_globe_bg() -> void:
	if globe <= 0.0:
		return
	var r := minf(size.x, size.y) * 0.44 / zoom
	var c := center
	var a := smoothstep(0.15, 0.9, globe)
	for k in 8:
		var f := 1.0 + 0.012 * (8 - k)
		_globe_bg.draw_circle(c, r * f, Color(0.35, 0.6, 1.0, 0.035 * a), true, -1.0, true)
	_globe_bg.draw_circle(c, r, Color(DS.OCEAN_TOP.lightened(0.04), a), true, -1.0, true)
	# Gentle light from the upper left.
	for k in 6:
		var f := 1.0 - k * 0.14
		_globe_bg.draw_circle(c + Vector2(-0.22, -0.26) * r * (1.0 - f), r * f, Color(0.3, 0.5, 0.85, 0.05 * a), true, -1.0, true)
	_globe_bg.draw_arc(c, r, 0.0, TAU, 96, Color(0.6, 0.8, 1.0, 0.35 * a), 1.5 / zoom, true)


# --------------------------------------------------------------- hit test ----
func country_at(screen_pos: Vector2) -> int:
	if globe_on:
		return globe_country_at(screen_pos)
	var w := screen_to_world(screen_pos)
	var hit := _country_at_world(w)
	if hit >= 0:
		return hit
	return _tiny_near(screen_pos)


func _country_at_world(w: Vector2) -> int:
	for c in _hit_order:
		if not data.bbox(c).grow(0.5).has_point(w):
			continue
		for r in _by_country[c]:
			if Geometry2D.is_point_in_polygon(w, data.ring_points[r]):
				return c
	return -1


## Tiny states: accept taps near their label point.
func _tiny_near(screen_pos: Vector2) -> int:
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
	if globe_on or globe > 0.0:
		if globe_on and not gesturing and globe >= 1.0:
			globe_rot.x += GLOBE_SPIN * delta * (0.3 if Settings.reduce_motion else 1.0)
			_globe_frame()
		return
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
		if _mouse_down and globe_on:
			_globe_drag(event.relative)
			if event.position.distance_to(_tap_start_pos) > TAP_SLOP:
				_tap_candidate = false
		elif _mouse_down:
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
	if globe_on:
		_globe_touch(e)
		return
	if e.pressed:
		_touches[e.index] = e.position
		_stop_motion()
		if _touches.size() == 1:
			_begin_tap(e.position)
		else:
			_tap_candidate = false
			var now := Time.get_ticks_msec() / 1000.0
			# Second finger lands soon after the first: maybe a two-finger tap.
			_two_tap = _touches.size() == 2 and now - _tap_start_time < 0.2
			_two_tap_time = now
			_two_tap_zoom = zoom
	else:
		var lifted_mid := Vector2.ZERO
		for k in _touches:
			lifted_mid += _touches[k]
		lifted_mid /= maxf(_touches.size(), 1)
		_touches.erase(e.index)
		if _touches.is_empty():
			if _two_tap and Time.get_ticks_msec() / 1000.0 - _two_tap_time < TAP_TIME 					and absf(zoom / _two_tap_zoom - 1.0) < 0.04:
				_two_tap = false
				_zoom_vel = 0.0
				_velocity = Vector2.ZERO
				_zoom_step(lifted_mid, 0.5)
				return
			_two_tap = false
			if zoom < min_zoom * GLOBE_ENTER and interactive:
				enter_globe()
				return
			_end_tap(e.position)


func _on_drag(e: InputEventScreenDrag) -> void:
	if globe_on:
		_globe_drag_event(e)
		return
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
			if e.pressed and globe_on:
				exit_globe()
			elif e.pressed:
				_stop_motion()
				zoom_at(e.position, 1.0 + 0.12 * e.factor if e.factor > 0 else 1.12)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed and not globe_on and zoom <= min_zoom * 1.001 and interactive:
				enter_globe()
			elif e.pressed and not globe_on:
				_stop_motion()
				zoom_at(e.position, 1.0 / (1.0 + 0.12 * e.factor if e.factor > 0 else 1.12))
		MOUSE_BUTTON_LEFT:
			if e.pressed and globe_on:
				_mouse_down = true
				if e.double_click:
					exit_globe(_globe_lonlat_at(e.position))
				else:
					_begin_tap(e.position)
			elif not e.pressed and globe_on:
				_mouse_down = false
				if _tap_candidate and Time.get_ticks_msec() / 1000.0 - _tap_start_time < TAP_TIME:
					_tap_candidate = false
					country_tapped.emit(globe_country_at(e.position))
			elif e.pressed:
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


func _globe_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_touches[e.index] = e.position
		if _touches.size() == 1:
			_begin_tap(e.position)
			_globe_pinch = 1.0
		else:
			_tap_candidate = false
		return
	_touches.erase(e.index)
	if not _touches.is_empty():
		return
	if _globe_pinch > 1.25:
		exit_globe()
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _tap_candidate and now - _tap_start_time < TAP_TIME:
		_tap_candidate = false
		if now - _last_tap_time < DOUBLE_TAP_TIME and e.position.distance_to(_last_tap_pos) < 40.0:
			_last_tap_time = -10.0
			exit_globe(_globe_lonlat_at(e.position))
			return
		_last_tap_time = now
		_last_tap_pos = e.position
		country_tapped.emit(globe_country_at(e.position))


func _globe_drag_event(e: InputEventScreenDrag) -> void:
	var prev: Vector2 = _touches.get(e.index, e.position)
	if _touches.size() >= 2:
		var keys := _touches.keys()
		var other: Vector2 = _touches[keys[1] if keys[0] == e.index else keys[0]]
		var old_d := prev.distance_to(other)
		if old_d > 1.0:
			_globe_pinch *= e.position.distance_to(other) / old_d
	else:
		_globe_drag(e.position - prev)
	_touches[e.index] = e.position
	if e.position.distance_to(_tap_start_pos) > TAP_SLOP:
		_tap_candidate = false


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
	_overlays.ripple(pos, c >= 0)
	country_tapped.emit(c)


func _double_tap(pos: Vector2) -> void:
	_zoom_step(pos, 2.0)


## Animated zoom by `factor` around a screen point, with a haptic tick.
func _zoom_step(pos: Vector2, factor: float) -> void:
	var anchor := screen_to_world(pos)
	var z := clampf(zoom * factor, min_zoom, max_zoom)
	if absf(z - zoom) < zoom * 0.01:
		Haptics.warning(false)   # already at the limit: a soft "bump"
		return
	_stop_motion()
	var from_c := center
	var from_lz := log(zoom)
	var to_lz := log(z)
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_method(func(t: float) -> void:
		zoom = exp(lerpf(from_lz, to_lz, t))
		center = anchor - (pos - size * 0.5) / zoom
		_apply_camera(), 0.0, 1.0, Settings.dur(0.36))
	Haptics.tick()
