class_name ControlStrip
extends Control
## The thumb zone above the dock: time controls on the left, the one thing that
## needs you next in the middle (a decision with its countdown ring, a campaign,
## the year in review, an advisor tip…), and the map layers on the right.
## Research: Civ VI's "next action" button, Frostpunk's timed event icons,
## Google Maps' layers button; Hoober's thumb-reach studies.

signal next_tapped(item: Dictionary)
signal layers_tapped
signal find_tapped

const H := 52.0

var _time: GlassPanel
var _play: AppButton
var _speed: AppButton
var _next: GlassPanel
var _next_icon: Control
var _next_title: Label
var _next_sub: Label
var _ring: Control
var _ring_icon: TextureRect
var _layers: GlassPanel
var _find: GlassPanel
var _item: Dictionary = {}
var _shown := false
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time = _pill()
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override(&"separation", 0)
	_time.add_child(trow)
	_play = AppButton.make("", &"FloatButton", "pause")
	_play.custom_minimum_size = Vector2(H - 8, H - 8)
	_play.pressed.connect(func() -> void: Game.toggle_pause())
	trow.add_child(_play)
	_speed = AppButton.make("1×", &"FloatButton")
	_speed.custom_minimum_size = Vector2(40, H - 8)
	_speed.pressed.connect(_cycle_speed)
	trow.add_child(_speed)

	_next = _pill()
	_next.mouse_filter = Control.MOUSE_FILTER_STOP
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override(&"separation", DS.S2)
	nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next.add_child(nrow)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(34, 34)
	_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	nrow.add_child(_ring)
	_ring_icon = TextureRect.new()
	_ring_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ring_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_icon.position = Vector2(8, 8)
	_ring_icon.size = Vector2(18, 18)
	_ring.add_child(_ring_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", -2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nrow.add_child(col)
	_next_title = Label.new()
	_next_title.theme_type_variation = &"Subhead"
	_next_title.clip_text = true
	_next_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_title.custom_minimum_size = Vector2(20, 0)
	col.add_child(_next_title)
	_next_sub = Label.new()
	_next_sub.theme_type_variation = &"Caption"
	_next_sub.clip_text = true
	_next_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_sub.custom_minimum_size = Vector2(20, 0)
	col.add_child(_next_sub)
	_next.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			var t := create_tween()
			if e.pressed:
				DS.ease_out(t)
			else:
				DS.spring(t)
			t.tween_property(_next, "scale", Vector2.ONE * (DS.PRESS_SCALE if e.pressed else 1.0), 0.15 if e.pressed else DS.DUR)
			if not e.pressed and not _item.is_empty():
				Haptics.tap()
				next_tapped.emit(_item))
	_next.visible = false

	_layers = _pill()
	var lb := AppButton.make("", &"FloatButton", "layers")
	lb.custom_minimum_size = Vector2(H - 8, H - 8)
	lb.pressed.connect(func() -> void: layers_tapped.emit())
	_layers.add_child(lb)
	_find = _pill()
	var fb := AppButton.make("", &"FloatButton", "search")
	fb.custom_minimum_size = Vector2(H - 8, H - 8)
	fb.pressed.connect(func() -> void: find_tapped.emit())
	_find.add_child(fb)

	Game.speed_changed.connect(_on_speed)
	_on_speed(Game.speed)
	resized.connect(_relayout)


func _pill() -> GlassPanel:
	var p := GlassPanel.new()
	p.theme_type_variation = &"GlassPill"
	p.tint = DS.GLASS_TINT_STRONG
	add_child(p)
	return p


func _relayout() -> void:
	var t := _time.get_combined_minimum_size()
	_time.size = Vector2(t.x, H)
	_time.position = Vector2(0, 0)
	_layers.size = Vector2(H, H)
	_layers.position = Vector2(size.x - H, 0)
	_find.size = Vector2(H, H)
	_find.position = Vector2(size.x - H * 2.0 - DS.S2, 0)
	var x0 := t.x + DS.S2
	var w := size.x - x0 - H * 2.0 - DS.S2 * 2.0
	_next.size = Vector2(w, H)
	_next.position = Vector2(x0, 0)
	_next.pivot_offset = _next.size * 0.5


func layers_rect() -> Rect2:
	return _layers.get_global_rect()


func time_rect() -> Rect2:
	return _time.get_global_rect()


func next_rect() -> Rect2:
	return _next.get_global_rect()


func _cycle_speed() -> void:
	var order := [1, 2, 4]
	var cur := Game.speed if Game.speed > 0 else 0
	var nxt: int = order[(order.find(cur) + 1) % order.size()] if cur > 0 else 1
	Game.set_speed(nxt)


func _on_speed(s: int) -> void:
	_play.icon_name = "play" if s == 0 else "pause"
	_speed.text = "%d×" % maxi(s if s > 0 else Game.calendar.speed_before_pause, 1)
	_speed.modulate.a = 0.5 if s == 0 else 1.0


## item: {kind, title, sub, icon, tint (Color), progress (0..1, <0 = none), count}
## An empty dictionary hides the pill.
func set_next(item: Dictionary) -> void:
	var same := not item.is_empty() and not _item.is_empty() and str(item.get("key", "")) == str(_item.get("key", ""))
	_item = item
	if item.is_empty():
		_show(false)
		return
	_next_title.text = str(item.title)
	_next_sub.text = str(item.get("sub", ""))
	_next_sub.visible = _next_sub.text != ""
	var tint: Color = item.get("tint", DS.ACCENT)
	_ring_icon.texture = DS.icon(str(item.get("icon", "info")))
	_ring_icon.modulate = tint.lightened(0.35)
	_ring.queue_redraw()
	_show(true, not same)


func _show(on: bool, pop: bool = false) -> void:
	if on == _shown and not pop:
		return
	_shown = on
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if on:
		_next.visible = true
		_next.modulate.a = 0.0 if pop or _next.modulate.a < 0.01 else _next.modulate.a
		_next.scale = Vector2.ONE * 0.9
		DS.spring(_tween)
		_tween.tween_property(_next, "scale", Vector2.ONE, Settings.dur(DS.DUR_SLOW))
		DS.ease_out(_tween)
		_tween.tween_property(_next, "modulate:a", 1.0, Settings.dur(DS.DUR))
	else:
		DS.ease_out(_tween)
		_tween.tween_property(_next, "modulate:a", 0.0, Settings.dur(DS.DUR_FAST))
		_tween.tween_property(_next, "scale", Vector2.ONE * 0.94, Settings.dur(DS.DUR_FAST))
		_tween.chain().tween_callback(func() -> void: _next.visible = _shown)


func _process(_delta: float) -> void:
	if _shown and float(_item.get("progress", -1.0)) >= 0.0:
		_ring.queue_redraw()


## Icon in a tinted circle; decisions get a ring that empties as time runs out.
func _draw_ring() -> void:
	if _item.is_empty():
		return
	var c := _ring.size * 0.5
	var r := minf(c.x, c.y)
	var tint: Color = _item.get("tint", DS.ACCENT)
	_ring.draw_circle(c, r - 3.0, Color(tint, 0.2), true, -1.0, true)
	var p := float(_item.get("progress", -1.0))
	if _item.has("due"):   # live countdown for decisions
		p = clampf((float(_item.due) - Game.months_played - Game.month_progress()) / float(EventDirector.DECISION_MONTHS), 0.0, 1.0)
	if p >= 0.0:
		_ring.draw_arc(c, r - 1.5, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 2.5, true)
		var urgent := p < 0.34
		var col := DS.ORANGE if urgent else tint
		# Breathe gently when time is almost up.
		if urgent:
			col.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() / 220.0)
		_ring.draw_arc(c, r - 1.5, -PI / 2.0, -PI / 2.0 + TAU * p, 48, col, 2.5, true)
