class_name TopBar
extends GlassPanel
## Floating glass top bar: your flag and the date (tap to pause / resume), the
## next election or review, the treasury, and the Inbox and Settings buttons.
## A hairline along the bottom fills as the current month elapses.

signal inbox_requested
signal settings_requested
signal nation_requested
signal budget_requested

var _date: Label
var _flag: Flag
var _caption: Label
var _pause_icon: TextureRect
var _treasury: AnimatedNumber
var _inbox: AppButton
var _inbox_badge: Panel
var _progress: Control
var _left: Control
var _approval: Control
var _appr_value := 50.0


func _ready() -> void:
	theme_type_variation = &"GlassBar"
	super._ready()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S1)
	add_child(row)

	# Flag (opens your country) + date block (tap to pause).
	_flag = Flag.new()
	_flag.mouse_filter = Control.MOUSE_FILTER_STOP
	_flag.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Haptics.tap()
			nation_requested.emit())
	row.add_child(_flag)
	_left = VBoxContainer.new()
	_left.add_theme_constant_override(&"separation", 0)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.mouse_filter = Control.MOUSE_FILTER_STOP
	_left.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Haptics.select()
			Game.toggle_pause())
	row.add_child(_left)
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override(&"separation", 6)
	date_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(date_row)
	_date = Label.new()
	_date.theme_type_variation = &"Headline"
	_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_row.add_child(_date)
	_pause_icon = TextureRect.new()
	_pause_icon.texture = DS.icon("pause")
	_pause_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pause_icon.custom_minimum_size = Vector2(15, 15)
	_pause_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_icon.modulate = DS.ORANGE
	_pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_row.add_child(_pause_icon)
	_caption = Label.new()
	_caption.theme_type_variation = &"Caption"
	_caption.clip_text = true
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.custom_minimum_size = Vector2(20, 0)
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left.add_child(_caption)

	# Approval (or support): a ring with the number inside. Tap: what's moving it.
	_approval = Control.new()
	_approval.custom_minimum_size = Vector2(38, 38)
	_approval.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_approval.mouse_filter = Control.MOUSE_FILTER_STOP
	_approval.draw.connect(_draw_approval)
	_approval.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Haptics.tap()
			Explainer.open(get_tree().current_scene, "approval"))
	row.add_child(_approval)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	right.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			Haptics.tap()
			budget_requested.emit())
	row.add_child(right)
	var cap := Label.new()
	cap.theme_type_variation = &"Overline"
	cap.text = "TREASURY"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cap)
	_treasury = AnimatedNumber.new()
	_treasury.theme_type_variation = &"StatSmall"
	_treasury.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_treasury.custom_minimum_size = Vector2(58, 0)
	_treasury.formatter = func(v: float) -> String: return DS.money(v)
	right.add_child(_treasury)

	_inbox = AppButton.make("", &"IconButton", "bell")
	_inbox.pressed.connect(func() -> void: inbox_requested.emit())
	row.add_child(_inbox)
	_inbox_badge = Panel.new()
	_inbox_badge.theme_type_variation = &"Badge"
	_inbox_badge.size = Vector2(9, 9)
	_inbox_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inbox_badge.visible = false
	_inbox.add_child(_inbox_badge)
	_inbox.resized.connect(func() -> void: _inbox_badge.position = Vector2(_inbox.size.x - 13, 7))
	var gear := AppButton.make("", &"IconButton", "settings")
	gear.pressed.connect(func() -> void: settings_requested.emit())
	row.add_child(gear)

	_progress = Control.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	add_child(_progress, false, Node.INTERNAL_MODE_BACK)

	Game.month_passed.connect(refresh)
	Game.speed_changed.connect(func(_s: int) -> void: refresh())
	Game.feed_added.connect(func(_i: Dictionary) -> void: refresh_badge())
	Game.decision_added.connect(func(_e: Dictionary) -> void: refresh_badge())
	Game.event_resolved.connect(func(_e: Dictionary, _c: int, _b: bool) -> void: refresh_badge())
	refresh()


func _process(_delta: float) -> void:
	_progress.position = Vector2.ZERO
	_progress.size = size
	_progress.queue_redraw()


func _draw_progress() -> void:
	var r := corner_radius()
	var w := size.x - r * 2.0
	var y := size.y - 1.5
	_progress.draw_line(Vector2(r, y), Vector2(r + w, y), Color(1, 1, 1, 0.06), 1.5, true)
	_progress.draw_line(Vector2(r, y), Vector2(r + w * Game.month_progress(), y), Color(DS.ACCENT_SOFT, 0.7), 1.5, true)


## Where the pause control lives (for the tour).
func speed_rect() -> Rect2:
	return _left.get_global_rect()


func inbox_rect() -> Rect2:
	return _inbox.get_global_rect()


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_date.text = Game.date_text()
	_flag.show_country(Game.player, 18.0)
	var paused := Game.speed == 0
	_pause_icon.visible = paused
	_caption.text = "Paused · tap to resume" if paused else Game.politics.milestone_text()
	_caption.add_theme_color_override(&"font_color", DS.ORANGE if paused else DS.TEXT_2)
	_treasury.value = c.treasury
	_appr_value = clampf(c.approval, 0.0, 100.0)
	_approval.queue_redraw()
	refresh_badge()


func _draw_approval() -> void:
	var cx := _approval.size * 0.5
	var r := minf(_approval.size.x, _approval.size.y) * 0.5 - 2.5
	var v := clampf(_appr_value / 100.0, 0.0, 1.0)
	var col := DS.GREEN if _appr_value >= 50.0 else (DS.ORANGE if _appr_value >= 40.0 else DS.RED)
	_approval.draw_arc(cx, r, 0.0, TAU, 40, Color(1, 1, 1, 0.12), 3.0, true)
	_approval.draw_arc(cx, r, -PI * 0.5, -PI * 0.5 + TAU * v, 40, col, 3.0, true)
	var f := get_theme_font(&"font", &"StatSmall")
	var txt := "%d" % roundi(_appr_value)
	var fs := 13
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_approval.draw_string(f, cx + Vector2(-w * 0.5, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var f2 := get_theme_font(&"font", &"Caption")
	var cap := "%" 
	var w2 := f2.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_approval.draw_string(f2, cx + Vector2(-w2 * 0.5, 11.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.6))


func refresh_badge() -> void:
	if Game.has_game():
		_inbox_badge.visible = Game.unread_count() > 0 or Game.director.has_open()
