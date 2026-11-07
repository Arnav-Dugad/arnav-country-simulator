extends SceneTree
## Step 2 of the map pipeline: tools/.cache/map_projected.json -> res://data/world_map.res
## Simplifies rings (Douglas-Peucker), drops specks, triangulates (with fallbacks),
## and stores everything in a binary MapData resource for fast loading on device.
## Run:  godot --headless --path . --script res://tools/bake_map.gd

const SRC := "res://tools/.cache/map_projected.json"
const OUT := "res://data/world_map.res"
const TOLERANCE := 0.85        # projected units (~2 px at max zoom)
const MIN_RING_AREA := 1.2     # drop islands smaller than this unless they're the main ring

var _stats := {"in": 0, "out": 0, "fallback": 0, "dropped": 0}


func _init() -> void:
	var text := FileAccess.get_file_as_string(SRC)
	if text.is_empty():
		push_error("Missing %s - run tools/fetch_map.py first" % SRC)
		quit(1)
		return
	var json: Dictionary = JSON.parse_string(text)
	var md := MapData.new()
	md.source = json.source
	var countries: Array = json.countries
	var world := Rect2()
	var first := true
	var neighbour_codes: Array = []
	for ci in countries.size():
		var c: Dictionary = countries[ci]
		md.iso3.append(c.iso3)
		md.iso2.append(str(c.get("iso2", "")))
		md.names.append(c.name)
		md.names_long.append(c.name_long)
		md.continents.append(str(c.continent))
		md.subregions.append(str(c.subregion))
		md.regions_wb.append(str(c.region_wb))
		md.types.append(str(c.type))
		md.label_pos.append(Vector2(c.label[0], c.label[1]))
		md.label_rank.append(int(c.label_rank))
		md.pop_est.append(float(c.pop_est))
		md.gdp_md.append(float(c.gdp_md))
		neighbour_codes.append(c.neighbours)
		if c.has("capital"):
			md.capital_pos.append(Vector2(c.capital.pos[0], c.capital.pos[1]))
			md.capital_name.append(str(c.capital.name))
		else:
			md.capital_pos.append(Vector2(NAN, NAN))
			md.capital_name.append("")

		var rings: Array[PackedVector2Array] = []
		var areas: Array[float] = []
		for flat in c.rings:
			var pts := PackedVector2Array()
			for k in range(0, flat.size(), 2):
				pts.append(Vector2(flat[k], flat[k + 1]))
			_stats.in += pts.size()
			rings.append(pts)
			areas.append(absf(Geo.signed_area(pts)))
		var largest := areas.find(areas.max()) if not areas.is_empty() else -1
		var total_area := 0.0
		var bb := Rect2()
		var bb_first := true
		for r in rings.size():
			if areas[r] < MIN_RING_AREA and r != largest:
				_stats.dropped += 1
				continue
			var result := _simplify_and_triangulate(rings[r])
			var pts: PackedVector2Array = result[0]
			var tris: PackedInt32Array = result[1]
			if tris.is_empty():
				_stats.dropped += 1
				continue
			md.ring_points.append(pts)
			md.ring_tris.append(tris)
			md.ring_country.append(ci)
			_stats.out += pts.size()
			total_area += areas[r]
			var rb := Geo.bounds(pts)
			bb = rb if bb_first else bb.merge(rb)
			bb_first = false
		md.area.append(total_area)
		md.bbox_pos.append(bb.position)
		md.bbox_size.append(bb.size)
		if not bb_first:
			world = bb if first else world.merge(bb)
			first = false

	md.world_rect = world
	for ci in countries.size():
		var n := PackedInt32Array()
		for code in neighbour_codes[ci]:
			var j := md.iso3.find(code)
			if j >= 0:
				n.append(j)
		md.neighbours.append(n)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data"))
	var err := ResourceSaver.save(md, OUT, ResourceSaver.FLAG_COMPRESS)
	print("bake_map: %d countries, %d rings, points %d -> %d, fallbacks %d, dropped %d, world %s, err=%d" % [
		md.count(), md.ring_points.size(), _stats.in, _stats.out, _stats.fallback, _stats.dropped, world, err])
	quit(err)


func _simplify_and_triangulate(raw: PackedVector2Array) -> Array:
	var raw_clean := _dedupe(raw)
	for tol in [TOLERANCE, TOLERANCE * 0.5, TOLERANCE * 0.25, 0.0]:
		var pts := raw_clean if tol == 0.0 else Geo.simplify_ring(raw_clean, tol)
		if pts.size() < 3:
			continue
		var tris := Geometry2D.triangulate_polygon(pts)
		if not tris.is_empty():
			if tol != TOLERANCE:
				_stats.fallback += 1
			return [pts, tris]
	# Last resort: Delaunay, keeping triangles whose centroid lies inside the ring.
	_stats.fallback += 1
	var d := Geometry2D.triangulate_delaunay(raw_clean)
	var keep := PackedInt32Array()
	for t in range(0, d.size(), 3):
		var cen := (raw_clean[d[t]] + raw_clean[d[t + 1]] + raw_clean[d[t + 2]]) / 3.0
		if Geometry2D.is_point_in_polygon(cen, raw_clean):
			keep.append_array([d[t], d[t + 1], d[t + 2]])
	return [raw_clean, keep]


func _dedupe(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 1e-6:
			out.append(p)
	if out.size() > 1 and out[0].distance_squared_to(out[out.size() - 1]) <= 1e-6:
		out.remove_at(out.size() - 1)
	return out
