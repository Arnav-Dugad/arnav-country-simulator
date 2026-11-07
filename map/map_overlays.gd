class_name MapOverlays
extends Control
## Living layers drawn over the map in screen space (so lines stay crisp at any
## zoom):
##   trade flows   arcs from your partners' capitals to yours: thicker for bigger
##                 economies, with light particles travelling along them (gold for allies)
##   weather       calm, abstract signs of disasters: a slow swirl over a hurricane,
##                 a warm haze in a heatwave, rain over floods, ripples after a quake
##   projects      small pins around your capital for what you've built and are building
## Everything is decorative: it reads Game state and never takes input.

const ARC_SEGMENTS := 28
const PARTICLES := 3

var map: MapView
var _t := 0.0
var _ripples: Array = []    # [position, start time, on land]


## A soft ring expanding from a tap (300 ms).
func ripple(pos: Vector2, land: bool) -> void:
	if not Settings.reduce_motion:
		_ripples.append([pos, Time.get_ticks_msec() / 1000.0, land])
var _icons := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta * (0.0 if Settings.reduce_motion else 1.0)
	if visible and Game.has_game():
		queue_redraw()


func _draw() -> void:
	if map == null or not Game.has_game() or not map.interactive:
		return
	_draw_weather()
	_draw_trade()
	_draw_projects()
	_draw_ripples()


func _draw_ripples() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k in range(_ripples.size() - 1, -1, -1):
		var r: Array = _ripples[k]
		var u := (now - float(r[1])) / 0.45
		if u >= 1.0:
			_ripples.remove_at(k)
			continue
		var e := 1.0 - pow(1.0 - u, 3.0)
		var col := Color(1, 1, 1) if r[2] else DS.TEAL
		draw_arc(r[0], 6.0 + 30.0 * e, 0.0, TAU, 40, Color(col, 0.45 * (1.0 - u)), 2.0, true)


# ------------------------------------------------------------------ trade ----
func _anchor(i: int) -> Vector2:
	var md := map.data
	if i < md.capital_pos.size():
		var p := md.capital_pos[i]
		if p != Vector2.ZERO and not is_nan(p.x):
			return p
	return md.label_pos[i]


func _draw_trade() -> void:
	var me := Game.player
	var links: Array = []
	for k in Game.dip.get("deals", {}):
		links.append([int(k), false])
	for k in Game.dip.get("alliances", {}):
		var found := false
		for l in links:
			if l[0] == int(k):
				l[1] = true
				found = true
		if not found:
			links.append([int(k), true])
	if links.is_empty():
		return
	var to := map.world_to_screen(_anchor(me))
	var my_gdp := maxf(Game.me().gdp, 1.0)
	for l in links:
		var i: int = l[0]
		var ally: bool = l[1]
		var c: CountryState = Game.state(i)
		if c == null:
			continue
		var from := map.world_to_screen(_anchor(i))
		var d := from.distance_to(to)
		if d < 6.0:
			continue
		# Bigger partner (relative to you) = thicker flow.
		var weight := clampf(0.35 + 0.25 * log(c.gdp / my_gdp * 10.0 + 1.0), 0.3, 1.0)
		var col := DS.GOLD if ally else DS.TEAL
		var mid := (from + to) * 0.5
		var n := (to - from).orthogonal().normalized()
		if n.y > 0.0:
			n = -n   # always bow upward, like flight paths
		var ctrl := mid + n * minf(d * 0.28, 220.0)
		var pts := PackedVector2Array()
		for s in ARC_SEGMENTS + 1:
			pts.append(_bezier(from, ctrl, to, float(s) / ARC_SEGMENTS))
		var w := 1.0 + 2.2 * weight
		map_line(pts, Color(col, 0.12), w + 3.0)
		map_line(pts, Color(col, 0.5), w)
		draw_circle(from, 2.5 + weight * 1.5, Color(col, 0.8), true, -1.0, true)
		# Particles flow toward you (trade) or both ways (allies).
		for k in PARTICLES:
			var u := fposmod(_t * 0.18 + float(k) / PARTICLES + float(i % 7) * 0.13, 1.0)
			if ally and k % 2 == 1:
				u = 1.0 - u
			var p := _bezier(from, ctrl, to, u)
			var a := sin(u * PI)
			draw_circle(p, 3.2 * weight + 0.8, Color(col.lightened(0.35), 0.18 * a), true, -1.0, true)
			draw_circle(p, 1.5 * weight + 0.6, Color(1, 1, 1, 0.85 * a), true, -1.0, true)


func map_line(pts: PackedVector2Array, col: Color, w: float) -> void:
	draw_polyline(pts, col, w, true)


static func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


# ---------------------------------------------------------------- weather ----
func _draw_weather() -> void:
	for w in Game.weather:
		var i := World.index_of(str(w.country))
		if i < 0:
			continue
		var r := map.focus_rect(i)
		var c := map.world_to_screen(r.get_center())
		var rad := clampf(r.size.length() * map.zoom * 0.35, 26.0, 150.0)
		# Fade in for the first month, out over the last.
		var left := float(w.until) - Game.months_played - Game.month_progress()
		var age := float(w.get("len", 3)) - left
		var a := clampf(minf(age, left), 0.0, 1.0)
		if a <= 0.0:
			continue
		match str(w.kind):
			"hurricane":
				_swirl(c + Vector2(rad * 0.35, rad * 0.1), rad * 0.9, a)
			"heatwave", "drought":
				var hot := DS.ORANGE if str(w.kind) == "heatwave" else Color("c9973a")
				var pulse := 0.85 + 0.15 * sin(_t * 1.7)
				_glow(c, rad * 1.1 * pulse, Color(hot, 0.22 * a))
			"floods", "monsoon":
				_glow(c, rad, Color(DS.TEAL, 0.16 * a))
				_rain(c, rad, a)
			"earthquake":
				for k in 3:
					var u := fposmod(_t * 0.45 + k / 3.0, 1.0)
					draw_arc(c, rad * (0.25 + u), 0.0, TAU, 48, Color(1, 0.92, 0.8, 0.35 * (1.0 - u) * a), 1.6, true)


func _glow(c: Vector2, r: float, col: Color) -> void:
	for k in 6:
		var f := 1.0 - k / 6.0
		draw_circle(c, r * f, Color(col, col.a * 0.35), true, -1.0, true)


func _swirl(c: Vector2, r: float, a: float) -> void:
	r = maxf(r, 40.0)
	_glow(c, r * 0.9, Color(0.85, 0.92, 1.0, 0.12 * a))
	var rot := -_t * 0.9
	for arm in 3:
		var pts := PackedVector2Array()
		for s in 26:
			var u := s / 25.0
			var ang := rot + arm * TAU / 3.0 + u * 3.4
			pts.append(c + Vector2(cos(ang), sin(ang)) * r * (0.12 + u * 0.88))
		draw_polyline(pts, Color(1, 1, 1, 0.12 * a), 10.0, true)
		draw_polyline(pts, Color(1, 1, 1, 0.42 * a), 3.0, true)
	draw_circle(c, r * 0.12, Color(1, 1, 1, 0.4 * a), true, -1.0, true)


func _rain(c: Vector2, r: float, a: float) -> void:
	for k in 18:
		var h := float(hash(k * 7919) % 1000) / 1000.0
		var x := c.x + (h - 0.5) * r * 1.6
		var y := c.y - r * 0.7 + fposmod(_t * 60.0 + h * 400.0, r * 1.4)
		draw_line(Vector2(x, y), Vector2(x - 2.0, y + 7.0), Color(0.75, 0.9, 1.0, 0.35 * a), 1.2, true)


# --------------------------------------------------------------- projects ----
func _draw_projects() -> void:
	var c := Game.me()
	if c == null or map.zoom < map.min_zoom * 2.6:
		return
	var ids: Array = []
	for id in c.projects:
		if not bool(c.projects[id].get("start", false)):
			ids.append(id)
	if ids.is_empty():
		return
	var cap := map.world_to_screen(_anchor(Game.player))
	var n := mini(ids.size(), 10)
	var ring := 30.0
	for k in n:
		var id: String = ids[k]
		var ang := -PI / 2.0 + TAU * k / maxf(n, 6.0)
		var p := cap + Vector2(cos(ang), sin(ang)) * ring
		var building := Projects.is_building(c, id)
		draw_circle(p, 10.5, Color(0.04, 0.06, 0.1, 0.82), true, -1.0, true)
		if building:
			var prog := Projects.progress(c, id)
			draw_arc(p, 10.5, -PI / 2.0, -PI / 2.0 + TAU * prog, 24, DS.ORANGE, 2.0, true)
		else:
			draw_arc(p, 10.5, 0.0, TAU, 24, Color(DS.GREEN, 0.8), 1.5, true)
		var tex: Texture2D = _icons.get(id)
		if tex == null:
			tex = DS.icon(str(Projects.by_id(id).get("icon", "hammer")))
			_icons[id] = tex
		if tex:
			draw_texture_rect(tex, Rect2(p - Vector2(6.5, 6.5), Vector2(13, 13)), false,
				Color(1, 1, 1, 0.95) if not building else Color(DS.ORANGE.lightened(0.3), 0.95))
