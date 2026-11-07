class_name MapLabels
extends Control
## Screen-space country labels. Only large countries are labelled at low zoom;
## more appear (by Natural Earth label rank) as you zoom in. Labels never
## overlap and fade with zoom. Drawn on top of the map, under the UI.

var map: MapView
var _font: Font
var _font_size := 11
var _order := PackedInt32Array()
var _width_cache := {}  # (country, size) -> text width


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = get_theme_font(&"font", &"MapLabel")
	_font_size = get_theme_font_size(&"font_size", &"MapLabel")
	var idx := range(map.data.count())
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ra := map.data.label_rank[a]
		var rb := map.data.label_rank[b]
		return ra < rb if ra != rb else map.data.area[a] > map.data.area[b])
	_order = PackedInt32Array(idx)


func _draw() -> void:
	if map == null or _font == null or size.x < 16.0:
		return
	var md := map.data
	var zf := map.zoom / map.min_zoom          # 1 = whole world
	var max_rank := clampi(int(1.5 + log(zf) / log(2.0) * 1.6), 1, 8)
	var placed: Array[Rect2] = map.label_blockers.duplicate()
	var outline_c := get_theme_color(&"font_outline_color", &"MapLabel")
	_draw_capital_dots(zf, outline_c)
	_draw_capital_name(Game.player, placed, zf, outline_c)  # your capital claims space first
	var view := Rect2(Vector2.ZERO, size).grow(-4)
	var outline := get_theme_color(&"font_outline_color", &"MapLabel")
	var base_color := get_theme_color(&"font_color", &"MapLabel")
	for i in _order:
		var rank := md.label_rank[i]
		if rank > max_rank or md.iso3[i] == "ATA":
			continue
		var p := map.world_to_screen(md.label_pos[i])
		if not view.has_point(p):
			continue
		var box_w := md.bbox_size[i].x * map.zoom
		var fs := int(clampf(_font_size + (zf - 2.0) * 0.18 - (rank - 2) * 0.5, 9.0, 15.0))
		var text := md.names[i].to_upper()
		var key := i * 64 + fs
		if not _width_cache.has(key):
			_width_cache[key] = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tw: float = _width_cache[key]
		if box_w < tw * 0.55:
			continue
		var r := Rect2(p - Vector2(tw * 0.5, fs * 0.6), Vector2(tw, fs * 1.2)).grow(3)
		var hit := false
		for q in placed:
			if q.intersects(r):
				hit = true
				break
		if hit:
			continue
		placed.append(r)
		# Fade in labels that only just qualified.
		var a := clampf((float(max_rank) - rank + 1.0) * 0.6, 0.35, 1.0)
		a *= clampf((box_w / maxf(tw, 1.0) - 0.55) * 2.5, 0.0, 1.0)
		var pos := p + Vector2(-tw * 0.5, fs * 0.35)
		draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(outline, outline.a * a))
		draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(base_color, base_color.a * a))
	for i in map.data.count():
		if i != Game.player:
			_draw_capital_name(i, placed, zf, outline)


## Capital dots from ~3.5x zoom, drawn beneath country labels.
func _draw_capital_dots(zf: float, outline: Color) -> void:
	var md := map.data
	if md.capital_pos.is_empty() or zf < 3.5:
		return
	var a := clampf((zf - 3.5) / 1.5, 0.0, 1.0)
	var view := Rect2(Vector2.ZERO, size).grow(-4)
	for i in md.count():
		var cp := md.capital_pos[i]
		if is_nan(cp.x):
			continue
		var p := map.world_to_screen(cp)
		if not view.has_point(p):
			continue
		var mine := i == Game.player
		var col := DS.GOLD if mine else Color(1, 1, 1, 0.85)
		draw_circle(p, 4.2, Color(outline, 0.55 * a), true, -1.0, true)
		draw_circle(p, 2.4 if not mine else 3.0, Color(col, a), true, -1.0, true)


## Capital names from ~5x zoom, only where they don't collide with other labels.
func _draw_capital_name(i: int, placed: Array[Rect2], zf: float, outline: Color) -> void:
	var md := map.data
	if i < 0 or md.capital_pos.is_empty() or zf < 5.0:
		return
	var cp := md.capital_pos[i]
	if is_nan(cp.x):
		return
	var p := map.world_to_screen(cp)
	if not Rect2(Vector2.ZERO, size).grow(-4).has_point(p):
		return
	var mine := i == Game.player
	var col := DS.GOLD if mine else Color(1, 1, 1, 0.85)
	var fs := 10
	var name := md.capital_name[i]
	var key := 100000 + i
	if not _width_cache.has(key):
		_width_cache[key] = _font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tw: float = _width_cache[key]
	var r := Rect2(p + Vector2(6, -fs * 0.6), Vector2(tw, fs * 1.2)).grow(2)
	var hit := false
	for q in placed:
		if q.intersects(r):
			hit = true
			break
	if hit:
		return
	placed.append(r)
	var la := clampf((zf - 5.0) / 1.5, 0.0, 1.0) * (1.0 if mine else 0.8)
	var pos := p + Vector2(6, fs * 0.35)
	draw_string_outline(_font, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(outline, outline.a * la))
	draw_string(_font, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, la))
