extends Control
## Launch screen: ocean backdrop, logo settles in with a soft glow, wordmark fades up.


var _logo: TextureRect
var _title: Label
var _subtitle: Label


func _ready() -> void:
	add_child(OceanBackground.new())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", DS.S4)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(col)

	_logo = TextureRect.new()
	_logo.texture = load("res://assets/branding/logo.png")
	_logo.custom_minimum_size = Vector2(124, 124)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_logo)

	_title = Label.new()
	_title.text = "Arnav Country Simulator"
	_title.theme_type_variation = &"Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = "Lead a nation. Shape the world."
	_subtitle.theme_type_variation = &"Subhead"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_subtitle)

	_animate_in()


func _animate_in() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2.ONE * 0.82
	_logo.modulate.a = 0.0
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	DS.spring(t)
	t.tween_property(_logo, "scale", Vector2.ONE, 0.7)
	DS.ease_out(t)
	t.tween_property(_logo, "modulate:a", 1.0, 0.45)
	t.tween_property(_title, "modulate:a", 1.0, 0.5).set_delay(0.25)
	t.tween_property(_subtitle, "modulate:a", 1.0, 0.5).set_delay(0.4)
	Audio.music_start()
	# Load the next screen in the background while the logo animates, and move on
	# as soon as it's ready (after a short minimum so the brand registers).
	var next := _next_scene()
	ResourceLoader.load_threaded_request(next)
	await get_tree().create_timer(0.9).timeout
	var waited := 0.0
	while ResourceLoader.load_threaded_get_status(next) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if ResourceLoader.load_threaded_get_status(next) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(next)   # now cached: the scene change is instant
	if is_inside_tree():
		Router.goto(next)


func _next_scene() -> String:
	if not Settings.onboarding_done:
		return "res://ui/screens/onboarding.tscn"
	if SaveManager.has_any():
		return "res://ui/screens/home.tscn"
	return "res://ui/screens/country_picker.tscn"
