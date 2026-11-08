class_name MapOverlays
extends Control
## Living layers drawn over the map in screen space (so lines stay crisp at any
## zoom):
##   trade flows   arcs from your partners' capitals to yours: thicker for bigger
##                 economies, with light particles travelling along them (gold for allies)
##   weather       calm, abstract signs of disasters: a slow swirl over a hurricane,
##                 a warm haze in a heatwave, rain over floods, ripples after a quake
##   projects      small pins around your capital for what you've built and are building
##   flight        a state visit: a plane of light arcs from your capital to theirs
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
var _flight := {}           # {from, to, start} while a state-visit flight is shown
var _fx := {}               # {kind: "skyline"|"fireworks", country, start} celebration
var _battles: Array = []    # [a, b, start] recent battle flashes
const FX_TIME := 3.2
const FLIGHT_TIME := 1.8
const FLIGHT_FADE := 0.8


func battle(a: int, b: int) -> void:
	_battles.append([a, b, Time.get_ticks_msec() / 1000.0])


## A short celebration over a country: a rising skyline (project opened) or
## fireworks (election won). Purely decorative; skipped with Reduce motion.
func celebrate(kind: String, i: int) -> void:
	if Settings.reduce_motion:
		return
	_fx = {"kind": kind, "country": i, "start": Time.get_ticks_msec() / 1000.0}


## Shows a state-visit flight from country a to country b.
func flight(a: int, b: int) -> void:
	_flight = {"from": a, "to": b, "start": Time.get_ticks_msec() / 1000.0}


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
	_draw_night()
	_draw_weather()
	_draw_trade()
	_draw_tariffs()
	_draw_projects()
	_draw_flight()
	_draw_fx()
	_draw_fronts()
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


# ------------------------------------------------------------------ night ----
## A soft night shadow that sweeps around the world once every in-game month
## (decorative: shows time passing). Columns of shade follow the terminator;
## the season tilts it (northern summer = longer days in the north).
func _draw_night() -> void:
	if Settings.reduce_motion or map.zoom > map.min_zoom * 6.0:
		return
	var phase := fposmod(Game.month_progress() + Game.month * 0.0, 1.0)
	var sun_lon := -PI + TAU * phase           # where it's noon
	var decl := 0.41 * sin(TAU * (float(Game.month) - 3.5) / 12.0)   # season
	# One continuous strip (shared vertices, no seams): alpha varies smoothly.
	var cols := 96
	var top := map.world_to_screen(Geo.equal_earth(0.0, 85.0)).y
	var bot := map.world_to_screen(Geo.equal_earth(0.0, -85.0)).y
	var pts := PackedVector2Array()
	var colors := PackedColorArray()
	for k in cols + 1:
		var x := size.x * float(k) / cols
		var world := map.screen_to_world(Vector2(x, size.y * 0.5))
		var lon := Geo.equal_earth_inverse(Vector2(world.x, 0.0)).x
		var d := wrapf(lon - sun_lon, -PI, PI)
		var a := 0.24 * smoothstep(PI * 0.4, PI * 0.65, absf(d))
		pts.append(Vector2(x, top))
		colors.append(Color(0.01, 0.02, 0.07, a * (1.0 - decl * 0.8)))
		pts.append(Vector2(x, bot))
		colors.append(Color(0.01, 0.02, 0.07, a * (1.0 + decl * 0.8)))
	var idx := PackedInt32Array()
	for k in cols:
		var i0 := k * 2
		idx.append_array([i0, i0 + 2, i0 + 1, i0 + 1, i0 + 2, i0 + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, colors)


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


func _draw_flight() -> void:
	if _flight.is_empty():
		return
	var el := Time.get_ticks_msec() / 1000.0 - float(_flight.start)
	var fly := FLIGHT_TIME * (0.4 if Settings.reduce_motion else 1.0)
	if el > fly + FLIGHT_FADE:
		_flight = {}
		return
	var from := map.world_to_screen(_anchor(int(_flight.from)))
	var to := map.world_to_screen(_anchor(int(_flight.to)))
	var d := from.distance_to(to)
	var n := (to - from).orthogonal().normalized()
	if n.y > 0.0:
		n = -n
	var ctrl := (from + to) * 0.5 + n * minf(d * 0.32, 240.0)
	var u := clampf(el / fly, 0.0, 1.0)
	u = 1.0 - pow(1.0 - u, 2.2)       # ease out: the plane slows into landing
	var fade := 1.0 - clampf((el - fly) / FLIGHT_FADE, 0.0, 1.0)
	var pts := PackedVector2Array()
	var steps := maxi(2, int(ARC_SEGMENTS * u))
	for s in steps + 1:
		pts.append(_bezier(from, ctrl, to, u * float(s) / steps))
	map_line(pts, Color(DS.GOLD, 0.16 * fade), 6.0)
	map_line(pts, Color(1, 1, 1, 0.75 * fade), 1.6)
	draw_circle(from, 3.5, Color(DS.GOLD, 0.9 * fade), true, -1.0, true)
	var head := _bezier(from, ctrl, to, u)
	draw_circle(head, 9.0, Color(DS.GOLD, 0.22 * fade), true, -1.0, true)
	draw_circle(head, 3.6, Color(1, 1, 1, fade), true, -1.0, true)
	if el > fly:
		# Arrival: a soft ring opens over their capital.
		var k := clampf((el - fly) / FLIGHT_FADE, 0.0, 1.0)
		draw_arc(to, 6.0 + 26.0 * k, 0.0, TAU, 40, Color(DS.GOLD, 0.8 * (1.0 - k)), 2.0, true)


## Trade wars: a thin red arc to each country you've put tariffs on (pulsing
## when they've hit back). No particles: trade has slowed to a trickle.
func _draw_tariffs() -> void:
	if not Game.dip.has("tariffs") or (Game.dip.tariffs as Dictionary).is_empty():
		return
	var to := map.world_to_screen(_anchor(Game.player))
	for k in Game.dip.tariffs:
		var i := int(k)
		var from := map.world_to_screen(_anchor(i))
		var d := from.distance_to(to)
		if d < 6.0:
			continue
		var n := (to - from).orthogonal().normalized()
		if n.y > 0.0:
			n = -n
		var ctrl := (from + to) * 0.5 + n * minf(d * 0.2, 160.0)
		var pts := PackedVector2Array()
		for s in ARC_SEGMENTS + 1:
			pts.append(_bezier(from, ctrl, to, float(s) / ARC_SEGMENTS))
		var a := 0.55
		if Tariffs.retaliating(i):
			a = 0.45 + 0.3 * (0.5 + 0.5 * sin(_t * 3.0))
		map_line(pts, Color(DS.RED, a), 1.6)
		draw_circle(from, 3.0, Color(DS.RED, 0.85), true, -1.0, true)


## War fronts: a pulsing red line between the capitals at war, with crossed
## sparks at the front (midpoint) and a flash after each battle.
func _draw_fronts() -> void:
	if not Game.dip.has("wars") or (Game.dip.wars as Dictionary).is_empty():
		_battles.clear()
		return
	var now := Time.get_ticks_msec() / 1000.0
	var me := map.world_to_screen(_anchor(Game.player))
	for k in Game.dip.wars:
		var them := map.world_to_screen(_anchor(int(k)))
		var mid := me.lerp(them, 0.5)
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_dashed_line(me, them, Color(DS.RED, 0.35 + 0.25 * pulse), 2.0, 8.0, true, true)
		draw_circle(mid, 10.0 + 4.0 * pulse, Color(DS.RED, 0.18), true, -1.0, true)
		for s in 2:
			var d := Vector2.RIGHT.rotated(PI * 0.25 + s * PI * 0.5) * 7.0
			draw_line(mid - d, mid + d, Color(1, 1, 1, 0.85), 2.0, true)
	var keep: Array = []
	for b in _battles:
		var el := now - float(b[2])
		if el > 1.2:
			continue
		keep.append(b)
		var p := map.world_to_screen(_anchor(int(b[0]))).lerp(map.world_to_screen(_anchor(int(b[1]))), 0.5)
		var k2 := el / 1.2
		draw_arc(p, 8.0 + 34.0 * k2, 0.0, TAU, 32, Color(DS.ORANGE, 0.9 * (1.0 - k2)), 2.5, true)
		draw_circle(p, 6.0 * (1.0 - k2), Color(1, 0.9, 0.6, 1.0 - k2), true, -1.0, true)
	_battles = keep


func _draw_fx() -> void:
	if _fx.is_empty():
		return
	var el := Time.get_ticks_msec() / 1000.0 - float(_fx.start)
	if el > FX_TIME:
		_fx = {}
		return
	var c := map.world_to_screen(_anchor(int(_fx.country)))
	var fade := 1.0 - clampf((el - (FX_TIME - 0.8)) / 0.8, 0.0, 1.0)
	if str(_fx.kind) == "skyline":
		# Seven towers rise one after another, lit windows twinkle, then fade.
		var heights := [22.0, 34.0, 18.0, 46.0, 28.0, 38.0, 16.0]
		var w := 7.0
		var x0 := c.x - heights.size() * (w + 2.0) * 0.5
		draw_circle(c, 46.0, Color(DS.GOLD, 0.10 * fade), true, -1.0, true)
		for k in heights.size():
			var t := clampf((el - k * 0.12) / 0.7, 0.0, 1.0)
			t = 1.0 - pow(1.0 - t, 3.0)
			var h: float = heights[k] * t
			var r := Rect2(x0 + k * (w + 2.0), c.y - h, w, h)
			draw_rect(r, Color(DS.GOLD.lerp(Color.WHITE, 0.25), 0.75 * fade))
			for wy in int(h / 6.0):
				if (k + wy + int(el * 3.0)) % 3 != 0:
					draw_rect(Rect2(r.position.x + 2.0, c.y - 4.0 - wy * 6.0, 3.0, 2.0), Color(1, 1, 1, 0.8 * fade))
		draw_line(Vector2(x0 - 4.0, c.y), Vector2(x0 + heights.size() * (w + 2.0) + 2.0, c.y), Color(DS.GOLD, 0.8 * fade), 1.5, true)
	else:
		# Five bursts at staggered times around the capital.
		var spots := [Vector2(0, -30), Vector2(-34, -10), Vector2(30, -18), Vector2(-14, -44), Vector2(18, -50)]
		var cols := [DS.GOLD, DS.ACCENT, DS.GREEN, DS.RED, DS.TEAL]
		for k in spots.size():
			var t := el - k * 0.35
			if t < 0.0 or t > 1.4:
				continue
			var p: Vector2 = c + spots[k]
			var rr := 26.0 * (1.0 - pow(1.0 - clampf(t / 0.9, 0.0, 1.0), 3.0))
			var a := (1.0 - clampf(t / 1.4, 0.0, 1.0)) * fade
			for s in 12:
				var dir := Vector2.RIGHT.rotated(TAU * s / 12.0 + k)
				draw_line(p + dir * rr * 0.55, p + dir * rr, Color(cols[k], a), 1.6, true)
				draw_circle(p + dir * rr, 1.6, Color(1, 1, 1, a), true, -1.0, true)


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
