class_name Share
extends RefCounted
## Captures the current screen (optionally hiding some controls) and opens the
## Android share sheet via the AcsUpdater plugin. On desktop the image is saved
## to user://share/ and its folder is opened.

const DIR := "user://share/"


## `hide` = controls (e.g. buttons) to hide for the capture. Returns a status string.
static func share_screen(tree: SceneTree, caption: String, hide: Array = []) -> String:
	for c in hide:
		if is_instance_valid(c):
			(c as CanvasItem).visible = false
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	for c in hide:
		if is_instance_valid(c):
			(c as CanvasItem).visible = true
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := DIR + "arnav-country-simulator.png"
	if img.save_png(path) != OK:
		return "Could not save the image."
	var full := ProjectSettings.globalize_path(path)
	var text := caption + "\nPlay Arnav Country Simulator: https://github.com/Arnav-Dugad/arnav-country-simulator/releases/latest"
	if OS.has_feature("android") and Engine.has_singleton("AcsUpdater"):
		var r := str(Engine.get_singleton("AcsUpdater").shareImage(full, text))
		return "" if r == "ok" else "Sharing failed (%s)." % r
	OS.shell_open(ProjectSettings.globalize_path(DIR))
	return "Saved the image to your computer."
