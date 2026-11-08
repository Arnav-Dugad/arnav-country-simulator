class_name Illustration
extends Control
## Small animated line-art scenes drawn in code (no image files): calm, crisp at
## any size, tinted per scene. Used on event cards, page headers, empty states
## and big moments. Motion stops when "Reduce motion" is on.
##
##   var art := Illustration.make("storm", DS.TEAL)
##
## Scenes: storm, heat, quake, flood, drought, chart_up, chart_down, crowd, ballot,
## factory, ship, health, tech, crane, oil, crown, gavel, globe, city, rocket,
## people, money, farm, handshake, plane, shield

## Event id -> scene (anything not listed falls back by icon, then "globe").
const EVENT_ART := {
	"recession": "chart_down", "recovery_boom": "chart_up", "floods": "flood", "monsoon": "flood",
	"hurricane": "storm", "heatwave": "heat", "earthquake": "quake", "drought": "drought",
	"tech_boom": "tech", "protests": "crowd", "scandal": "gavel", "inquiry_result": "gavel",
	"pandemic": "health", "vaccine_race": "health", "oil_shock": "oil", "oil_windfall": "oil", "oil_crash": "oil",
	"strike": "factory", "resources": "factory", "investment": "money", "sports": "crown", "cyberattack": "tech",
	"refugees": "people", "trade_offer": "ship", "sanction_threat": "shield", "brain_drain": "plane",
	"housing": "city", "automation": "factory", "games_bid": "crown", "tourism": "plane", "debt_crisis": "chart_down",
	"coalition_crisis": "people", "budget_standoff": "gavel", "court_ruling": "gavel", "dissident": "crowd",
	"democracy_movement": "crowd", "succession": "crown", "generals": "shield", "party_purge": "gavel",
	"observers": "ballot", "royal_wedding": "crown", "pensions": "people", "blackout": "city", "youth_jobs": "people",
	"overrun": "crane", "summit": "handshake", "un_sanctions": "globe", "un_climate": "globe", "un_ceasefire": "globe",
	"un_rights": "globe", "un_ocean": "flood", "un_ai": "tech",
}
## Event id -> painted scene (assets/scenes, AI-generated, no real people).
const EVENT_SCENE := {
	"summit": "summit", "cop": "climate", "games_prep": "construction", "games_open": "celebration", "games_mess": "protest", "debate": "election", "term_limit": "parliament", "un_sanctions": "summit", "un_climate": "climate", "un_ceasefire": "summit", "un_rights": "summit",
	"protests": "protest", "strike": "protest", "democracy_movement": "protest", "dissident": "press",
	"floods": "flood", "monsoon": "flood", "un_ocean": "flood", "hurricane": "hurricane",
	"overrun": "construction", "investment": "construction", "housing": "construction",
	"recession": "markets", "debt_crisis": "markets", "recovery_boom": "markets",
	"observers": "election", "coalition_crisis": "parliament", "budget_standoff": "parliament",
	"court_ruling": "parliament", "scandal": "press", "inquiry_result": "press", "party_purge": "parliament",
	"pensions": "parliament", "succession": "parliament", "pandemic": "hospital", "vaccine_race": "hospital",
	"oil_shock": "oil", "oil_windfall": "oil", "oil_crash": "oil", "resources": "oil", "blackout": "oil",
	"drought": "drought", "heatwave": "drought", "tech_boom": "tech", "cyberattack": "tech", "automation": "tech",
	"brain_drain": "tech", "un_ai": "tech", "sports": "celebration", "games_bid": "celebration",
	"royal_wedding": "celebration", "tourism": "celebration", "trade_offer": "port", "sanction_threat": "port",
	"press": "press", "refugees": "aid", "bank_wobble": "markets", "bank_run": "bank_run", "aid_request": "aid", "earthquake": "quake", "bailout_vote": "parliament",
	"currency_slide": "markets", "currency_crisis": "markets", "imf_review": "summit", "heat_grid": "drought",
}


## A scene banner for an event (photo if we have one, else the line-art scene).
static func banner_for_event(ev: Dictionary, tint: Color, height: float = 116.0) -> Control:
	var key := str(EVENT_SCENE.get(str(ev.get("id", "")), ""))
	if Photo.has_scene(key):
		return Photo.scene(key, height)
	return make(for_event(ev), tint, height - 12.0)


static func banner(scene_key: String, fallback: String, tint: Color, height: float = 104.0) -> Control:
	if Photo.has_scene(scene_key):
		return Photo.scene(scene_key, height)
	return make(fallback, tint, height)


const ICON_ART := {"vote": "ballot", "construction": "crane", "hammer": "crane", "globe": "globe", "handshake": "handshake",
	"trending-up": "chart_up", "trending-down": "chart_down", "flame": "oil", "users": "people", "crown": "crown",
	"gavel": "gavel", "shield": "shield", "stethoscope": "health", "zap": "tech", "calendar": "city", "heart": "people"}

var scene := "globe"
var tint: Color = DS.ACCENT
var _t := 0.0
var card := true      # draw the soft rounded backdrop


static func make(scene_name: String, color: Color = DS.ACCENT, height: float = 112.0) -> Control:
	var il: Control = load("res://ui/components/illustration.gd").new()
	il.set(&"scene", scene_name)
	il.set(&"tint", color)
	il.custom_minimum_size = Vector2(0, height)
	return il


static func for_event(ev: Dictionary) -> String:
	var id := str(ev.get("id", ""))
	if EVENT_ART.has(id):
		return EVENT_ART[id]
	return str(ICON_ART.get(str(ev.get("icon", "")), "globe"))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not Settings.reduce_motion:
		_t += delta
	queue_redraw()


# ------------------------------------------------------------------ helpers ---
func _ink(a: float = 0.9) -> Color:
	return Color(1, 1, 1, a)


func _fill(a: float = 0.22) -> Color:
	return Color(tint, a)


func _line(a: Vector2, b: Vector2, w: float = 2.0, c: Color = Color(1, 1, 1, 0.9)) -> void:
	draw_line(a, b, c, w, true)


func _poly(pts: PackedVector2Array, w: float = 2.0, c: Color = Color(1, 1, 1, 0.9), closed: bool = false) -> void:
	if closed:
		pts.append(pts[0])
	draw_polyline(pts, c, w, true)


func _round_rect(r: Rect2, rad: float, fill: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _cloud(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-s * 0.9, s * 0.2), s * 0.7, col, true, -1.0, true)
	draw_circle(c + Vector2(0, -s * 0.15), s, col, true, -1.0, true)
	draw_circle(c + Vector2(s * 0.95, s * 0.25), s * 0.65, col, true, -1.0, true)
	draw_rect(Rect2(c.x - s * 0.9, c.y + s * 0.1, s * 1.85, s * 0.8), col)


# -------------------------------------------------------------------- draw ----
func _draw() -> void:
	var w := size.x
	var h := size.y
	if card:
		_round_rect(Rect2(Vector2.ZERO, size), 18.0, Color(tint, 0.10))
		# Soft glow behind the scene.
		for k in 5:
			draw_circle(Vector2(w * 0.5, h * 0.55), h * (0.55 - k * 0.08), Color(tint, 0.035), true, -1.0, true)
	var c := Vector2(w * 0.5, h * 0.55)
	var s := minf(h * 0.42, w * 0.2)
	var t := _t
	match scene:
		"storm":
			# Solid colours: overlapping translucent shapes would show seams.
			_cloud(c + Vector2(s * 0.25, -s * 0.3), s * 0.5, tint.lerp(Color("1a2233"), 0.55))
			_cloud(c + Vector2(-s * 0.2, -s * 0.42), s * 0.52, Color("8e9bb0").lerp(tint, 0.15))
			for k in 9:
				var x := c.x - s * 0.9 + k * s * 0.22
				var y := c.y + fposmod(t * 70.0 + k * 13.0, s * 0.9)
				_line(Vector2(x, y), Vector2(x - 3, y + 8), 1.6, _ink(0.6))
			if fposmod(t, 3.2) < 0.12:
				_poly(PackedVector2Array([c + Vector2(s * 0.1, 0), c + Vector2(-s * 0.05, s * 0.35), c + Vector2(s * 0.12, s * 0.35), c + Vector2(-s * 0.08, s * 0.8)]), 2.5, Color(1, 0.95, 0.6, 0.95))
		"heat":
			var sun := c + Vector2(0, -s * 0.15)
			draw_circle(sun, s * 0.38, _fill(0.55), true, -1.0, true)
			for k in 12:
				var ang := TAU * k / 12.0 + t * 0.2
				_line(sun + Vector2(cos(ang), sin(ang)) * s * 0.52, sun + Vector2(cos(ang), sin(ang)) * s * 0.7, 2.0, _ink(0.7))
			for k in 3:
				var pts := PackedVector2Array()
				for x in 24:
					var xx := c.x - s * 1.2 + x * s * 0.1
					pts.append(Vector2(xx, c.y + s * (0.55 + k * 0.18) + sin(xx * 0.08 + t * 3.0 + k) * 3.0))
				_poly(pts, 1.6, _ink(0.45))
		"quake":
			var ground := c.y + s * 0.35
			_line(Vector2(c.x - s * 1.6, ground), Vector2(c.x + s * 1.6, ground), 2.0, _ink(0.6))
			_poly(PackedVector2Array([Vector2(c.x - s * 0.2, ground), Vector2(c.x, ground + s * 0.25), Vector2(c.x - s * 0.1, ground + s * 0.45), Vector2(c.x + s * 0.12, ground + s * 0.7)]), 2.2, _ink(0.85))
			for k in 3:
				var u := fposmod(t * 0.5 + k / 3.0, 1.0)
				draw_arc(Vector2(c.x, ground), s * (0.3 + u * 1.2), PI, TAU, 40, Color(tint, 0.6 * (1.0 - u)), 2.0, true)
			var shake := sin(t * 30.0) * 1.5
			_round_rect(Rect2(c.x - s * 0.9 + shake, ground - s * 0.7, s * 0.45, s * 0.7), 3, _fill(0.4))
			_round_rect(Rect2(c.x + s * 0.45 - shake, ground - s * 0.95, s * 0.5, s * 0.95), 3, _fill(0.3))
		"flood", "drought":
			var dry := scene == "drought"
			if dry:
				draw_circle(c + Vector2(s * 0.9, -s * 0.45), s * 0.28, _fill(0.6), true, -1.0, true)
				var ground2 := c.y + s * 0.3
				_line(Vector2(c.x - s * 1.6, ground2), Vector2(c.x + s * 1.6, ground2), 2.0, _ink(0.6))
				for k in 5:
					var x0 := c.x - s * 1.2 + k * s * 0.55
					_poly(PackedVector2Array([Vector2(x0, ground2), Vector2(x0 + s * 0.1, ground2 + s * 0.2), Vector2(x0 - s * 0.05, ground2 + s * 0.4)]), 1.5, _ink(0.55))
				_line(Vector2(c.x - s * 0.3, ground2), Vector2(c.x - s * 0.3, ground2 - s * 0.6), 2.0, _ink(0.8))
				_line(Vector2(c.x - s * 0.3, ground2 - s * 0.4), Vector2(c.x - s * 0.55, ground2 - s * 0.6), 2.0, _ink(0.8))
			else:
				_round_rect(Rect2(c.x - s * 0.6, c.y - s * 0.55, s * 0.5, s * 0.6), 3, _fill(0.35))
				_poly(PackedVector2Array([Vector2(c.x - s * 0.7, c.y - s * 0.55), Vector2(c.x - s * 0.35, c.y - s * 0.85), Vector2(c.x, c.y - s * 0.55)]), 2.0, _ink(0.8))
				var level := c.y + sin(t * 0.8) * 3.0
				for k in 3:
					var pts2 := PackedVector2Array()
					for x in 30:
						var xx2 := c.x - s * 1.6 + x * s * 0.11
						pts2.append(Vector2(xx2, level + k * s * 0.22 + sin(xx2 * 0.07 + t * 2.0 + k * 1.3) * 3.5))
					_poly(pts2, 2.0, Color(tint.lightened(0.3), 0.8 - k * 0.2))
		"chart_up", "chart_down":
			var up := scene == "chart_up"
			var base := c.y + s * 0.6
			for k in 5:
				var bh := s * (0.3 + (k if up else 4 - k) * 0.22) * (0.9 + 0.1 * sin(t * 2.0 + k))
				_round_rect(Rect2(c.x - s * 1.2 + k * s * 0.5, base - bh, s * 0.32, bh), 3, _fill(0.35))
			var a := c + Vector2(-s * 1.2, s * (0.1 if up else -0.5))
			var b := c + Vector2(s * 1.3, s * (-0.7 if up else 0.4))
			var u := fposmod(t * 0.4, 1.2)
			var e := a.lerp(b, clampf(u, 0.0, 1.0))
			_line(a, e, 3.0, (DS.GREEN if up else DS.RED).lightened(0.2))
			var dir := (b - a).normalized()
			_line(e, e - dir.rotated(0.5) * 10.0, 3.0, (DS.GREEN if up else DS.RED).lightened(0.2))
			_line(e, e - dir.rotated(-0.5) * 10.0, 3.0, (DS.GREEN if up else DS.RED).lightened(0.2))
		"crowd", "people":
			var many := scene == "crowd"
			var n := 7 if many else 4
			for k in n:
				var x := c.x - s * (1.3 if many else 0.8) + k * s * (0.42 if many else 0.52)
				var bob := sin(t * 2.0 + k) * (2.5 if many else 1.0)
				var y := c.y + s * 0.2 + bob
				var sc := 0.85 + 0.15 * float(k % 2)
				draw_circle(Vector2(x, y - s * 0.42 * sc), s * 0.14 * sc, _ink(0.85), true, -1.0, true)
				_round_rect(Rect2(x - s * 0.15 * sc, y - s * 0.26 * sc, s * 0.3 * sc, s * 0.5 * sc), 6, _fill(0.55))
				if many and k % 3 == 1:
					_line(Vector2(x + s * 0.12, y - s * 0.2), Vector2(x + s * 0.12, y - s * 0.85), 1.6, _ink(0.7))
					_round_rect(Rect2(x - s * 0.1, y - s * 1.05, s * 0.45, s * 0.25), 2, _ink(0.85))
		"ballot":
			var box := Rect2(c.x - s * 0.55, c.y - s * 0.15, s * 1.1, s * 0.8)
			_round_rect(box, 6, _fill(0.45))
			_line(Vector2(box.position.x + s * 0.3, box.position.y), Vector2(box.end.x - s * 0.3, box.position.y), 3.0, _ink(0.9))
			var drop := fposmod(t * 0.6, 1.0)
			var py := lerpf(c.y - s * 1.0, c.y - s * 0.15, minf(drop * 1.4, 1.0))
			_round_rect(Rect2(c.x - s * 0.22, py - s * 0.3, s * 0.44, s * 0.32), 2, _ink(0.92))
			_poly(PackedVector2Array([Vector2(c.x - s * 0.1, py - s * 0.15), Vector2(c.x - s * 0.02, py - s * 0.07), Vector2(c.x + s * 0.12, py - s * 0.24)]), 2.0, tint)
		"factory":
			var g := c.y + s * 0.6
			_poly(PackedVector2Array([Vector2(c.x - s * 1.3, g), Vector2(c.x - s * 1.3, g - s * 0.6), Vector2(c.x - s * 0.8, g - s * 0.9), Vector2(c.x - s * 0.8, g - s * 0.6), Vector2(c.x - s * 0.3, g - s * 0.9), Vector2(c.x - s * 0.3, g - s * 0.6), Vector2(c.x + s * 0.2, g - s * 0.9), Vector2(c.x + s * 0.2, g), Vector2(c.x - s * 1.3, g)]), 2.0, _ink(0.85))
			draw_rect(Rect2(c.x + s * 0.4, g - s * 1.2, s * 0.25, s * 1.2), _fill(0.5))
			for k in 4:
				var u2 := fposmod(t * 0.35 + k / 4.0, 1.0)
				draw_circle(Vector2(c.x + s * 0.52 + u2 * s * 0.5, g - s * 1.25 - u2 * s * 0.6), s * (0.08 + u2 * 0.15), Color(1, 1, 1, 0.3 * (1.0 - u2)), true, -1.0, true)
		"ship":
			var sea := c.y + s * 0.4
			var rock := sin(t * 1.5) * 2.0
			_poly(PackedVector2Array([Vector2(c.x - s * 1.0, sea - s * 0.25 + rock), Vector2(c.x + s * 1.1, sea - s * 0.25 - rock), Vector2(c.x + s * 0.85, sea + s * 0.05), Vector2(c.x - s * 0.8, sea + s * 0.05)]), 2.2, _ink(0.9), true)
			for k in 4:
				_round_rect(Rect2(c.x - s * 0.7 + k * s * 0.38, sea - s * 0.55 + rock * 0.5, s * 0.32, s * 0.28), 2, Color([DS.ORANGE, DS.ACCENT, DS.GREEN, DS.RED][k], 0.7))
			var pts3 := PackedVector2Array()
			for x in 30:
				var xx3 := c.x - s * 1.6 + x * s * 0.11
				pts3.append(Vector2(xx3, sea + s * 0.15 + sin(xx3 * 0.09 + t * 2.0) * 2.5))
			_poly(pts3, 2.0, Color(tint.lightened(0.3), 0.7))
		"health":
			var pts4 := PackedVector2Array()
			for x in 60:
				var xx4 := c.x - s * 1.5 + x * s * 0.05
				var ph := fposmod(x * 0.05 - t * 0.6, 1.0)
				var yy := 0.0
				if ph > 0.45 and ph < 0.5:
					yy = -s * 0.6
				elif ph >= 0.5 and ph < 0.55:
					yy = s * 0.35
				pts4.append(Vector2(xx4, c.y + yy))
			_poly(pts4, 2.4, Color(tint.lightened(0.3), 0.95))
			_round_rect(Rect2(c.x + s * 0.95, c.y - s * 0.95, s * 0.16, s * 0.48), 2, _ink(0.85))
			_round_rect(Rect2(c.x + s * 0.79, c.y - s * 0.79, s * 0.48, s * 0.16), 2, _ink(0.85))
		"tech":
			var chip := Rect2(c.x - s * 0.45, c.y - s * 0.45, s * 0.9, s * 0.9)
			_round_rect(chip, 8, _fill(0.45))
			for k in 4:
				for side in 4:
					var off := -s * 0.3 + k * s * 0.2
					var p := chip.get_center()
					var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
					var d: Vector2 = dirs[side]
					var start := p + d * s * 0.45 + d.orthogonal() * off
					_line(start, start + d * s * 0.3, 1.6, _ink(0.6))
					var lit := fposmod(t * 1.5 + k * 0.7 + side * 1.1, 2.0) < 0.3
					draw_circle(start + d * s * 0.34, 2.5, DS.TEAL if lit else _ink(0.4), true, -1.0, true)
		"crane":
			var g2 := c.y + s * 0.7
			_line(Vector2(c.x - s * 0.6, g2), Vector2(c.x - s * 0.6, g2 - s * 1.5), 3.0, _ink(0.85))
			var swing := sin(t * 0.7) * 0.15
			var arm_end := Vector2(c.x - s * 0.6, g2 - s * 1.45) + Vector2(cos(swing), sin(swing)) * s * 1.6
			_line(Vector2(c.x - s * 0.9, g2 - s * 1.45), arm_end, 3.0, _ink(0.85))
			var hook := arm_end + Vector2(0, s * (0.6 + 0.1 * sin(t * 1.3)))
			_line(arm_end, hook, 1.4, _ink(0.6))
			_round_rect(Rect2(hook.x - s * 0.2, hook.y, s * 0.4, s * 0.25), 2, _fill(0.7))
			for k in 3:
				_round_rect(Rect2(c.x + s * 0.1 + k * s * 0.32, g2 - s * (0.3 + k * 0.2), s * 0.3, s * (0.3 + k * 0.2)), 2, _fill(0.35))
		"oil":
			var barrel := Rect2(c.x - s * 1.1, c.y - s * 0.4, s * 0.7, s * 0.95)
			_round_rect(barrel, 6, _fill(0.5))
			_line(Vector2(barrel.position.x, barrel.position.y + s * 0.3), Vector2(barrel.end.x, barrel.position.y + s * 0.3), 2.0, _ink(0.6))
			_line(Vector2(barrel.position.x, barrel.end.y - s * 0.3), Vector2(barrel.end.x, barrel.end.y - s * 0.3), 2.0, _ink(0.6))
			var pts5 := PackedVector2Array()
			for x in 20:
				pts5.append(Vector2(c.x - s * 0.1 + x * s * 0.07, c.y - s * 0.1 + sin(x * 0.6 + t * 1.5) * s * 0.25 - x * s * 0.015))
			_poly(pts5, 2.6, DS.ORANGE.lightened(0.2))
		"crown":
			var base2 := c.y + s * 0.35
			_poly(PackedVector2Array([Vector2(c.x - s * 0.8, base2), Vector2(c.x - s * 0.9, c.y - s * 0.45), Vector2(c.x - s * 0.4, c.y - s * 0.05), Vector2(c.x, c.y - s * 0.65), Vector2(c.x + s * 0.4, c.y - s * 0.05), Vector2(c.x + s * 0.9, c.y - s * 0.45), Vector2(c.x + s * 0.8, base2)]), 2.6, DS.GOLD, true)
			for k in 6:
				var ang2 := t * 0.8 + k * TAU / 6.0
				var sp := c + Vector2(cos(ang2) * s * 1.3, sin(ang2) * s * 0.7 - s * 0.1)
				var tw := 0.5 + 0.5 * sin(t * 4.0 + k)
				draw_circle(sp, 2.0 + tw * 1.5, Color(DS.GOLD, 0.5 + 0.5 * tw), true, -1.0, true)
		"gavel":
			# A gavel taps its block: raise slowly, strike quickly, small impact lines.
			var ph := fposmod(t * 0.8, 1.0)
			var lift := (1.0 - ph / 0.85) if ph < 0.85 else (ph - 0.85) / 0.15
			lift = clampf(lift, 0.0, 1.0)
			var block := Rect2(c.x - s * 0.95, c.y + s * 0.42, s * 1.1, s * 0.26)
			_round_rect(block, 4, Color(tint, 0.55))
			_round_rect(Rect2(block.position.x - s * 0.1, block.end.y, block.size.x + s * 0.2, s * 0.1), 3, _ink(0.35))
			var piv := c + Vector2(s * 0.95, s * 0.05)
			var ang3 := -PI + 0.15 + lift * 0.7
			var head := piv + Vector2(cos(ang3), sin(ang3)) * s * 1.1
			_line(piv, head, 4.0, _ink(0.85))
			draw_set_transform(head, ang3 + PI / 2.0, Vector2.ONE)
			_round_rect(Rect2(-s * 0.42, -s * 0.2, s * 0.84, s * 0.4), 6, tint.lerp(Color.WHITE, 0.25))
			_round_rect(Rect2(-s * 0.42, -s * 0.2, s * 0.12, s * 0.4), 3, _ink(0.9))
			_round_rect(Rect2(s * 0.3, -s * 0.2, s * 0.12, s * 0.4), 3, _ink(0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if lift < 0.12:
				for k in 3:
					var a2 := -PI / 2.0 + (k - 1) * 0.6
					var o := Vector2(c.x - s * 0.45, c.y + s * 0.35)
					_line(o + Vector2(cos(a2), sin(a2)) * s * 0.3, o + Vector2(cos(a2), sin(a2)) * s * 0.5, 2.0, _ink(0.7))
		"globe", "plane":
			draw_circle(c, s * 0.75, _fill(0.25), true, -1.0, true)
			draw_arc(c, s * 0.75, 0, TAU, 48, _ink(0.85), 2.0, true)
			for k in 3:
				var rx := s * 0.75 * cos(t * 0.5 + k * 1.05)
				if absf(rx) > 2.0:
					draw_set_transform(c, 0.0, Vector2(absf(rx) / (s * 0.75), 1.0))
					draw_arc(Vector2.ZERO, s * 0.75, 0, TAU, 40, _ink(0.35), 1.4 / maxf(absf(rx) / (s * 0.75), 0.1), true)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_line(c + Vector2(-s * 0.75, 0), c + Vector2(s * 0.75, 0), 1.4, _ink(0.35))
			var orb := t * (1.2 if scene == "plane" else 0.8)
			var op := c + Vector2(cos(orb) * s * 1.15, sin(orb) * s * 0.45)
			draw_circle(op, 4.0, Color(tint.lightened(0.4), 1.0), true, -1.0, true)
		"handshake":
			var meet := sin(t * 1.4) * 3.0
			_round_rect(Rect2(c.x - s * 1.3, c.y - s * 0.1, s * 1.0 + meet, s * 0.32), 8, _fill(0.6))
			_round_rect(Rect2(c.x + s * 0.3 - meet, c.y - s * 0.1, s * 1.0, s * 0.32), 8, Color(DS.GOLD, 0.6))
			draw_circle(c + Vector2(0, s * 0.06), s * 0.24, _ink(0.85), true, -1.0, true)
		"shield":
			var pts6 := PackedVector2Array([c + Vector2(0, -s * 0.8), c + Vector2(s * 0.65, -s * 0.5), c + Vector2(s * 0.55, s * 0.3), c + Vector2(0, s * 0.8), c + Vector2(-s * 0.55, s * 0.3), c + Vector2(-s * 0.65, -s * 0.5)])
			draw_colored_polygon(pts6, _fill(0.35))
			_poly(pts6, 2.4, _ink(0.85), true)
			var glint := fposmod(t * 0.5, 1.6)
			if glint < 1.0:
				_line(c + Vector2(-s * 0.5 + glint * s, -s * 0.6), c + Vector2(-s * 0.7 + glint * s, s * 0.2), 3.0, Color(1, 1, 1, 0.35))
		"city", "money":
			var g3 := c.y + s * 0.7
			for k in 7:
				var bh2 := s * (0.5 + float((k * 7) % 5) * 0.22)
				var bx := c.x - s * 1.6 + k * s * 0.46
				_round_rect(Rect2(bx, g3 - bh2, s * 0.4, bh2), 2, _fill(0.3 + 0.05 * (k % 3)))
				for wy in int(bh2 / (s * 0.22)):
					var on := fposmod(sin(k * 3.1 + wy * 1.7) * 10.0 + t * 0.3, 1.0) > 0.45
					draw_rect(Rect2(bx + s * 0.08, g3 - bh2 + s * 0.08 + wy * s * 0.22, s * 0.08, s * 0.08), Color(1, 0.9, 0.6, 0.8) if on else Color(1, 1, 1, 0.12))
			if scene == "money":
				for k in 3:
					var u3 := fposmod(t * 0.4 + k / 3.0, 1.0)
					var cp := Vector2(c.x - s * 0.8 + k * s * 0.8, c.y - s * 0.4 - u3 * s * 0.6)
					draw_circle(cp, s * 0.16, Color(DS.GOLD, 0.9 * (1.0 - u3)), true, -1.0, true)
		"rocket":
			var lift := fposmod(t * 0.25, 1.0)
			var rp := Vector2(c.x, c.y + s * 0.6 - lift * s * 1.6)
			_poly(PackedVector2Array([rp + Vector2(0, -s * 0.6), rp + Vector2(s * 0.2, -s * 0.2), rp + Vector2(s * 0.2, s * 0.3), rp + Vector2(-s * 0.2, s * 0.3), rp + Vector2(-s * 0.2, -s * 0.2)]), 2.2, _ink(0.9), true)
			draw_circle(rp + Vector2(0, -s * 0.1), s * 0.08, _fill(0.9), true, -1.0, true)
			for k in 4:
				draw_circle(rp + Vector2(sin(t * 20.0 + k) * 3.0, s * (0.4 + k * 0.12)), s * (0.12 - k * 0.02), Color(DS.ORANGE, 0.8 - k * 0.18), true, -1.0, true)
		"farm":
			draw_circle(c + Vector2(s, -s * 0.5), s * 0.25, Color(DS.GOLD, 0.7), true, -1.0, true)
			for k in 4:
				var pts7 := PackedVector2Array()
				for x in 20:
					pts7.append(Vector2(c.x - s * 1.5 + x * s * 0.16, c.y + k * s * 0.18 + sin(x * 0.4 + k) * 2.0))
				_poly(pts7, 2.0, Color(DS.GREEN, 0.8 - k * 0.15))
		_:
			draw_circle(c, s * 0.6, _fill(0.3), true, -1.0, true)
