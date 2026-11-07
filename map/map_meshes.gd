class_name MapMeshes
extends RefCounted
## Builds batched ArrayMeshes from MapData (one draw call per layer).


## Rings grouped per country: Array[PackedInt32Array] of ring indices.
static func rings_by_country(md: MapData) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	out.resize(md.count())
	for i in out.size():
		out[i] = PackedInt32Array()
	for r in md.ring_country.size():
		out[md.ring_country[r]].append(r)
	return out


## All country fills. `order` = draw order (large first so enclaves sit on top).
## UV.x = (country + 0.5) / tex_w so the shader can look up per-country colour.
static func fill_mesh(md: MapData, order: PackedInt32Array, tex_w: int) -> ArrayMesh:
	var by_c := rings_by_country(md)
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for c in order:
		var uv := Vector2((c + 0.5) / tex_w, 0.5)
		for r in by_c[c]:
			var base := verts.size()
			var pts: PackedVector2Array = md.ring_points[r]
			verts.append_array(pts)
			var fill := PackedVector2Array()
			fill.resize(pts.size())
			fill.fill(uv)
			uvs.append_array(fill)
			for t in md.ring_tris[r]:
				idx.append(base + t)
	return _mesh(verts, uvs, PackedColorArray(), idx)


## Fill of a single country (white; tint with modulate).
static func country_fill_mesh(md: MapData, c: int) -> ArrayMesh:
	var verts := PackedVector2Array()
	var idx := PackedInt32Array()
	for r in md.ring_country.size():
		if md.ring_country[r] != c:
			continue
		var base := verts.size()
		verts.append_array(md.ring_points[r])
		for t in md.ring_tris[r]:
			idx.append(base + t)
	if verts.is_empty():
		return null
	return _mesh(verts, PackedVector2Array(), PackedColorArray(), idx)


## Miter-joined closed outlines. Each ring point becomes two vertices with the
## miter offset in UV (extruded in the shader) and side in COLOR.r.
## use_miter=false keeps unit-length averaged normals (for wide, soft glows).
static func line_mesh(rings: Array[PackedVector2Array], use_miter: bool = true) -> ArrayMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var side_a := Color(1, 0, 0, 1)
	var side_b := Color(0, 0, 0, 1)
	for ring in rings:
		var n := ring.size()
		if n < 3:
			continue
		var base := verts.size()
		for i in n:
			var p0 := ring[(i - 1 + n) % n]
			var p1 := ring[i]
			var p2 := ring[(i + 1) % n]
			var d0 := (p1 - p0).normalized()
			var d1 := (p2 - p1).normalized()
			var n0 := Vector2(-d0.y, d0.x)
			var n1 := Vector2(-d1.y, d1.x)
			var m := n0 + n1
			if m.length_squared() < 1e-6:
				m = n1
			else:
				m = m.normalized()
			var miter := m / maxf(m.dot(n1), 0.5) if use_miter else m  # limit spikes
			verts.append(p1)
			uvs.append(miter)
			cols.append(side_a)
			verts.append(p1)
			uvs.append(-miter)
			cols.append(side_b)
		for i in n:
			var a := base + 2 * i
			var b := base + 2 * ((i + 1) % n)
			idx.append_array([a, a + 1, b, b, a + 1, b + 1])
	if verts.is_empty():
		return null
	return _mesh(verts, uvs, cols, idx)


static func _mesh(verts: PackedVector2Array, uvs: PackedVector2Array, cols: PackedColorArray,
		idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	if not uvs.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = uvs
	if not cols.is_empty():
		arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m
