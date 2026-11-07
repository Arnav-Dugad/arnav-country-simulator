class_name TopBar
extends GlassPanel
## Floating glass top bar: date + election countdown, speed control, treasury.
## A hairline along the bottom fills as the current month elapses.

var _date: Label
var _flag: Flag
var _election: Label
var _speed: SegmentedControl
var _treasury: AnimatedNumber
var _progress: Control


func _ready() -> void:
	theme_type_variation = &"GlassBar"
	super._ready()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	add_child(row)

	var left_wrap := HBoxContainer.new()
	left_wrap.add_theme_constant_override(&"separation", DS.S2)
	left_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(left_wrap)
	_flag = Flag.new()
	left_wrap.add_child(_flag)
	var left := VBoxContainer.new()
	left.add_theme_constant_override(&"separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left_wrap.add_child(left)
	_date = Label.new()
	_date.theme_type_variation = &"Headline"
	left.add_child(_date)
	_election = Label.new()
	_election.theme_type_variation = &"Caption"
	left.add_child(_election)

	_speed = SegmentedControl.new().setup(["", "1×", "2×", "4×"], ["pause", "", "", ""], 1)
	_speed.plain = true
	_speed.compact = false
	_speed.segment_width = 30.0
	_speed.tight = true
	_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_speed.changed.connect(func(i: int) -> void: Game.set_speed(Game.SPEEDS[i]))
	row.add_child(_speed)

	var right := VBoxContainer.new()
	right.add_theme_constant_override(&"separation", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(right)
	var cap := Label.new()
	cap.theme_type_variation = &"Overline"
	cap.text = "TREASURY"
	cap.clip_text = true
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.custom_minimum_size = Vector2(20, 0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cap)
	_treasury = AnimatedNumber.new()
	_treasury.theme_type_variation = &"StatSmall"
	_treasury.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_treasury.clip_text = true
	_treasury.custom_minimum_size = Vector2(20, 0)
	_treasury.formatter = func(v: float) -> String: return DS.money(v)
	right.add_child(_treasury)

	_progress = Control.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.draw.connect(_draw_progress)
	add_child(_progress, false, Node.INTERNAL_MODE_BACK)

	Game.month_passed.connect(refresh)
	Game.speed_changed.connect(_on_speed)
	refresh()
	_on_speed(Game.speed)


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


func speed_rect() -> Rect2:
	return _speed.get_global_rect()


func refresh() -> void:
	var c := Game.me()
	if c == null:
		return
	_date.text = Game.date_text()
	_flag.show_country(Game.player, 18.0)
	var m := Game.months_to_election
	# Short and calm: the year of the next election (exact countdown lives in Events).
	var ey := Game.year + int((Game.month - 1 + m) / 12)
	_election.text = "Election %d" % ey if m > 0 else "Election this month"
	_treasury.value = c.treasury


func _on_speed(s: int) -> void:
	_speed.select(Game.SPEEDS.find(s), false)
