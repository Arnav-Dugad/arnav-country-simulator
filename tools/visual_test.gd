extends Node
## Visual regression test: renders key screens at 390x844 with a fixed seed and
## compares them with golden images (tools/visual_golden/*.png). Fails when a
## screen differs by more than TOLERANCE of its pixels (per-channel diff > 24).
## Run in a real display (CI: xvfb, software OpenGL):
##   godot --rendering-driver opengl3 --path . res://tools/visual_test.tscn [-- --update]
## --update rewrites the goldens. Goldens are renderer-specific: CI makes its own
## on the first run (see .github/workflows/visual.yml).

const GOLDEN := "res://tools/visual_golden/"
const TOLERANCE := 0.02
const SCREENS := ["home", "economy", "budget", "laws", "world", "election"]

var _fails := 0
var _update := false
var _out := ""


func _ready() -> void:
	_update = "--update" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	Settings.tutorial_done = true
	Settings.reduce_motion = true          # no animation timing in the pictures
	Settings.set_value("coach_seen", ["economy", "budget", "build", "laws", "diplomacy"])
	Settings.set_value("seen_version", Updater.current_version())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN))
	get_window().size = Vector2i(390, 844)
	await get_tree().process_frame
	for s in SCREENS:
		await _shoot(s)
	print("VISUAL TEST %s (%d differ)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _shoot(screen: String) -> void:
	var scene_path := "res://ui/screens/home.tscn" if screen == "home" else "res://ui/screens/game.tscn"
	Game.new_game(World.index_of("FRA"), 3)
	var node: Node = load(scene_path).instantiate()
	get_tree().root.add_child(node)
	await _wait(1.2)
	if screen != "home":
		var page: String = {"world": "diplomacy"}.get(screen, screen)
		if screen == "election":
			Game.politics.months_to_election = 1
			Game.advance_month()
		else:
			node.open_page(page)
			node.sheet.snap_to(BottomSheet.Snap.FULL, false)
		await _wait(2.6)
	var img := get_viewport().get_texture().get_image()
	node.queue_free()
	await get_tree().process_frame
	var path := GOLDEN + screen + ".png"
	if _out != "":
		img.save_png(_out.path_join(screen + ".png"))
	if _update or not FileAccess.file_exists(path):
		img.save_png(ProjectSettings.globalize_path(path))
		print("SAVED  %s" % screen)
		return
	var gold := Image.load_from_file(ProjectSettings.globalize_path(path))
	var diff := _diff(img, gold)
	var ok := diff <= TOLERANCE
	if not ok:
		_fails += 1
	print("%s  %-9s %.2f%% of pixels differ" % ["PASS" if ok else "FAIL", screen, diff * 100.0])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Fraction of pixels whose largest channel difference is above 24/255.
static func _diff(a: Image, b: Image) -> float:
	if a.get_size() != b.get_size():
		return 1.0
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var da := a.get_data()
	var db := b.get_data()
	var bad := 0
	var n := da.size() / 3
	for k in range(0, da.size(), 3):
		if absi(da[k] - db[k]) > 24 or absi(da[k + 1] - db[k + 1]) > 24 or absi(da[k + 2] - db[k + 2]) > 24:
			bad += 1
	return float(bad) / float(maxi(n, 1))
