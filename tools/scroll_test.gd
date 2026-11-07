extends Control
## Scroll regression test: a vertical swipe that starts on any interactive control
## inside a scroll view must reach the ScrollContainer (so the page scrolls on a
## phone), while horizontal drags still move sliders and taps still press buttons.
## Run: godot --path . res://tools/scroll_test.tscn   (needs a window for GUI input)

var _fails := 0
var _motions := 0


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	_fails += 0 if ok else 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := TouchScroll.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	scroll.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			_motions += 1)
	# Like real pages: controls sit inside a grouped card (a PanelContainer,
	# which blocks touches by default unless TouchScroll lets them through).
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer)
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	outer.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	var slider := AppSlider.new().setup("Test", 0, 100, 1, 50)
	v.add_child(slider)
	var button := AppButton.make("Button")
	var pressed := [0]
	button.pressed.connect(func() -> void: pressed[0] += 1)
	v.add_child(button)
	var chart := LineChart.new()
	v.add_child(chart)
	var toggle := AppToggle.new().setup("Toggle", false)
	v.add_child(toggle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2000)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE   # like a Label: decoration
	v.add_child(spacer)
	await get_tree().process_frame
	await get_tree().process_frame
	chart.set_data(PackedFloat32Array([1, 2, 3, 2, 4]))
	await get_tree().process_frame

	for item in [["slider", slider._track], ["button", button], ["chart", chart], ["toggle", toggle._switch], ["label", spacer]]:
		scroll.set(&"_vel", 0.0)
		scroll.scroll_vertical = 0
		await get_tree().process_frame
		var c: Vector2 = (item[1] as Control).get_global_rect().get_center()
		if item[0] == "label":
			c = Vector2(100, 400)
		await _drag(c, c + Vector2(0, -120))
		_check(scroll.scroll_vertical >= 90, "swipe up starting on %s scrolls the page (by %d pt)" % [item[0], scroll.scroll_vertical])
	_check(is_equal_approx(slider.value, 50.0), "vertical swipe leaves slider value alone")
	_check(pressed[0] == 0, "vertical swipe on a button does not press it")

	scroll.set(&"_vel", 0.0)
	scroll.scroll_vertical = 0
	await get_tree().process_frame
	var t: Vector2 = slider._track.get_global_rect().get_center()
	await _drag(t, t + Vector2(80, 2))
	_check(scroll.scroll_vertical == 0, "horizontal slider drag does not scroll the page")
	_check(slider.value > 55.0, "horizontal drag still moves the slider (%.0f)" % slider.value)
	var bc := button.get_global_rect().get_center()
	await _drag(bc, bc)
	_check(pressed[0] == 1, "a tap still presses the button")

	# A bottom sheet's close (X) button in the draggable header must close it
	# (regression: the header drag used to re-snap the sheet on release).
	scroll.visible = false
	var sheet := BottomSheet.new()
	add_child(sheet)
	var x := AppButton.make("", &"IconButton", "x")
	x.custom_minimum_size = Vector2(44, 44)
	x.size_flags_horizontal = Control.SIZE_SHRINK_END
	x.pressed.connect(sheet.close)
	sheet.header.add_child(x)
	await get_tree().process_frame
	sheet.open(BottomSheet.Snap.HALF)
	await get_tree().create_timer(0.7).timeout
	var xc := x.get_global_rect().get_center()
	await _drag(xc, xc)
	await get_tree().create_timer(0.7).timeout
	_check(sheet.state == BottomSheet.Snap.HIDDEN, "tapping the sheet's X closes it (state %d)" % sheet.state)
	print("SCROLL TEST %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit()


func _drag(a: Vector2, b: Vector2) -> void:
	var vp := get_viewport()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = a
	down.global_position = a
	vp.push_input(down)
	var prev := a
	for k in range(1, 13):
		var p := a.lerp(b, k / 12.0)
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.global_position = p
		mm.relative = p - prev
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mm)
		prev = p
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = b
	up.global_position = b
	vp.push_input(up)
	await get_tree().process_frame
	await get_tree().process_frame
