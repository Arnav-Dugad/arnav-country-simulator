extends SceneTree
## Step 3 of the map pipeline: bakes the render meshes (all country fills in one
## mesh, all borders in another) from data/world_map.res into data/map_fill.res and
## data/map_borders.res, so the phone doesn't build ~100k vertices at startup.
## MapView falls back to building them at runtime if these files are missing or stale.
## Run:  godot --headless --path . --script res://tools/bake_meshes.gd

const FILL_OUT := "res://data/map_fill.res"
const BORDERS_OUT := "res://data/map_borders.res"
const SHELF_OUT := "res://data/map_shelf.res"


func _init() -> void:
	var md: MapData = load("res://data/world_map.res")
	var order: Array = range(md.count())
	order.sort_custom(func(a: int, b: int) -> bool: return md.area[a] > md.area[b])
	var tex_w := 256 if md.count() <= 256 else 512
	var fill := MapMeshes.fill_mesh(md, PackedInt32Array(order), tex_w)
	fill.set_meta(&"count", md.count())
	var borders := MapMeshes.line_mesh(md.ring_points)
	borders.set_meta(&"count", md.count())
	var e1 := ResourceSaver.save(fill, FILL_OUT, ResourceSaver.FLAG_COMPRESS)
	var e2 := ResourceSaver.save(borders, BORDERS_OUT, ResourceSaver.FLAG_COMPRESS)
	var shelf := MapMeshes.shelf_mesh(md)
	shelf.set_meta(&"count", md.count())
	var e3 := ResourceSaver.save(shelf, SHELF_OUT, ResourceSaver.FLAG_COMPRESS)
	print("bake_meshes: fill err=%d borders err=%d shelf err=%d (%d countries)" % [e1, e2, e3, md.count()])
	quit(0 if e1 == OK and e2 == OK and e3 == OK else 1)
