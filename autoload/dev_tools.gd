extends Node
## Developer hooks driven by user command-line args (after "--"). Inert otherwise.
##   --scene=res://path.tscn   open this scene instead of the main scene
##   --shot=C:/out.png         save a screenshot and quit
##   --shot-delay=2.5          seconds to wait before the screenshot
##   --size=390x844            resize the window (logical aspect test)

var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.is_empty():
		return
	if _args.has("size"):
		var wh: PackedStringArray = String(_args["size"]).split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	if _args.has("scene"):
		get_tree().change_scene_to_file.call_deferred(_args["scene"])
	if _args.has("shot"):
		_shoot()


func arg(key: String, default: Variant = null) -> Variant:
	return _args.get(key, default)


func _shoot() -> void:
	await get_tree().create_timer(float(_args.get("shot-delay", "2.0"))).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_args["shot"])
	print("dev_tools: screenshot -> ", _args["shot"])
	get_tree().quit()
