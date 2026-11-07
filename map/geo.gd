class_name Geo
extends RefCounted
## Small geometry helpers shared by the map baker and runtime.


## Douglas-Peucker simplification of a closed ring (no repeated end point).
static func simplify_ring(pts: PackedVector2Array, tol: float) -> PackedVector2Array:
	var n := pts.size()
	if n <= 4 or tol <= 0.0:
		return pts
	var far := 0
	var best := -1.0
	for i in n:
		var d := pts[0].distance_squared_to(pts[i])
		if d > best:
			best = d
			far = i
	var ext := pts.duplicate()
	ext.append(pts[0])  # index n aliases vertex 0 so the second half can wrap
	var keep := PackedByteArray()
	keep.resize(n + 1)
	keep[0] = 1
	keep[far] = 1
	_dp(ext, 0, far, tol * tol, keep)
	_dp(ext, far, n, tol * tol, keep)
	var out := PackedVector2Array()
	for i in n:
		if keep[i] == 1:
			out.append(pts[i])
	return out


static func _dp(pts: PackedVector2Array, a: int, b: int, tol2: float, keep: PackedByteArray) -> void:
	var stack: Array[Vector2i] = [Vector2i(a, b)]
	while not stack.is_empty():
		var seg: Vector2i = stack.pop_back()
		if seg.y - seg.x < 2:
			continue
		var pa := pts[seg.x]
		var pb := pts[seg.y]
		var best := -1.0
		var idx := -1
		for i in range(seg.x + 1, seg.y):
			var q := Geometry2D.get_closest_point_to_segment(pts[i], pa, pb)
			var d := q.distance_squared_to(pts[i])
			if d > best:
				best = d
				idx = i
		if best > tol2:
			keep[idx] = 1
			stack.append(Vector2i(seg.x, idx))
			stack.append(Vector2i(idx, seg.y))


## Removes hairpin vertices (where the outline doubles back by more than
## acos(min_dot)) until none remain. Used for the soft player glow so narrow
## inlets and gulfs don't fold the halo into bright spikes.
## Only hairpins whose tip lies within `max_depth` of the shortcut are removed, so
## real peninsulas survive.
static func remove_spikes(pts: PackedVector2Array, max_depth: float, min_dot: float = -0.7) -> PackedVector2Array:
	var out := pts.duplicate()
	var changed := true
	while changed and out.size() > 4:
		changed = false
		var n := out.size()
		for i in n:
			var p0 := out[(i - 1 + n) % n]
			var p1 := out[i]
			var p2 := out[(i + 1) % n]
			var d0 := (p1 - p0).normalized()
			var d1 := (p2 - p1).normalized()
			var degenerate := d0.is_zero_approx() or d1.is_zero_approx()
			var depth := p1.distance_to(Geometry2D.get_closest_point_to_segment(p1, p0, p2))
			if degenerate or (d0.dot(d1) < min_dot and depth < max_depth):
				out.remove_at(i)
				changed = true
				break
	return out


static func signed_area(pts: PackedVector2Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p := pts[i]
		var q := pts[(i + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
