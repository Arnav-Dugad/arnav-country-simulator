extends Control
## First-launch onboarding: three glass cards over a slowly drifting world map.
## Swipe or tap Continue; Skip jumps straight to the country picker.

const NEXT := "res://ui/screens/country_picker.tscn"
const PAGES := [
	{"icon": "globe", "tint": DS.ACCENT, "title": "Lead any nation",
		"body": "Choose from 185 real countries. Every one starts from real-world data: people, money, debt and mood.",
		"focus": Vector2(150, -650), "zoom": 3.2},
	{"icon": "landmark", "tint": DS.GREEN, "title": "Make the hard calls",
		"body": "Set taxes, budgets, interest rates and trade. Every choice has a tradeoff, and the economy answers month by month.",
		"focus": Vector2(-1500, -520), "zoom": 2.6},
	{"icon": "vote", "tint": DS.GOLD, "title": "Stay in power",
		"body": "Handle crises, win friends abroad, and keep your people on side. Elections come every four years.",
		"focus": Vector2(1350, -380), "zoom": 2.8},
]

var _map: MapView
var _card: GlassPanel
var _content: VBoxContainer
var _tile: Control
var _title: Label
var _body: Label
var _dots: HBoxContainer
var _next: AppButton
var _skip: AppButton
var _footer: HBoxContainer
var _account_step := false
var _page := 0
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	add_child(OceanBackground.new())
	_map = MapView.new()
	_map.interactive = false
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_map)
	add_child(_scrim())

	var skip := AppButton.make("Skip", &"GhostButton")
	skip.pressed.connect(_finish)
	add_child(skip)
	_skip = skip
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(size.x - 90, Screen.top + DS.S3)
	resized.connect(func() -> void: skip.position = Vector2(size.x - skip.size.x - DS.S3, Screen.top + DS.S3))

	_card = GlassPanel.new()
	_card.theme_type_variation = &"GlassSheet"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_card.gui_input.connect(_on_card_input)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", DS.S5)
	_card.add_child(col)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override(&"separation", DS.S3)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_content)
	_tile = Control.new()
	_content.add_child(_tile)
	_title = Label.new()
	_title.theme_type_variation = &"Title"
	_content.add_child(_title)
	_body = Label.new()
	_body.theme_type_variation = &"BodySecondary"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(10, 72)
	_content.add_child(_body)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(footer)
	_footer = footer
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override(&"separation", 6)
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_dots)
	for i in PAGES.size():
		var d := Panel.new()
		d.theme_type_variation = &"SheetHandle"
		d.custom_minimum_size = Vector2(8, 8)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(d)
	_next = AppButton.make("Continue", &"PrimaryButton")
	_next.custom_minimum_size = Vector2(150, 50)
	_next.pressed.connect(_advance)
	footer.add_child(_next)

	resized.connect(_layout)
	Screen.insets_changed.connect(_layout)
	_layout.call_deferred()
	_show_page(0, 0)
	# Wrapped labels report their final height a frame later.
	get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)


func _scrim() -> Control:
	# Fades the map toward the bottom so the card always reads cleanly.
	var g := Gradient.new()
	g.set_color(0, Color(DS.OCEAN_BOTTOM, 0.0))
	g.set_color(1, Color(DS.OCEAN_BOTTOM, 0.92))
	g.add_point(0.45, Color(DS.OCEAN_BOTTOM, 0.15))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return r


func _layout() -> void:
	var w := size.x - DS.S4 * 2.0
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	_card.position = Vector2(DS.S4, size.y - Screen.bottom - DS.S4 - _card.get_combined_minimum_size().y)


func _process(delta: float) -> void:
	# Gentle eastward drift of the background map.
	_map.pan_by(Vector2(-9.0 * delta, 0))


func _show_page(i: int, dir: int) -> void:
	_page = i
	var p: Dictionary = PAGES[i]
	var tile := ListRow.icon_tile(p.icon, p.tint)
	tile.custom_minimum_size = Vector2(52, 52)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(tile)
	_content.move_child(tile, 0)
	_tile.queue_free()
	_tile = tile
	_title.text = p.title
	_body.text = p.body
	_next.text = "Get started" if i == PAGES.size() - 1 else "Continue"
	for d in _dots.get_child_count():
		var dot := _dots.get_child(d) as Control
		var on := d == i
		var t := create_tween().set_parallel(true)
		DS.ease_out(t)
		t.tween_property(dot, "custom_minimum_size:x", 22.0 if on else 8.0, Settings.dur(DS.DUR))
		t.tween_property(dot, "modulate:a", 1.0 if on else 0.45, Settings.dur(DS.DUR))
	_map.fly_to(p.focus, _map.min_zoom * p.zoom, 1.4 if dir != 0 else 0.01)
	if dir != 0:
		_content.position.x = 40.0 * dir
		_content.modulate.a = 0.0
		var t2 := create_tween().set_parallel(true)
		DS.ease_out(t2)
		t2.tween_property(_content, "position:x", 0.0, Settings.dur(DS.DUR_SLOW))
		t2.tween_property(_content, "modulate:a", 1.0, Settings.dur(DS.DUR))


func _advance() -> void:
	if _account_step:
		return
	if _page < PAGES.size() - 1:
		_show_page(_page + 1, 1)
	else:
		_finish()


func _back() -> void:
	if _account_step:
		return
	if _page > 0:
		_show_page(_page - 1, -1)


## Pages done (or skipped): always ask to create an account on first launch.
func _finish() -> void:
	if Firebase.enabled() and not (Firebase.signed_in() and not Firebase.is_anonymous):
		_show_account_step()
	else:
		_complete()


func _complete() -> void:
	Settings.set_value("onboarding_done", true)
	Haptics.success()
	Router.goto(NEXT)


func _show_account_step() -> void:
	if _account_step:
		return
	_account_step = true
	_skip.visible = false
	_footer.visible = false
	var tile := ListRow.icon_tile("cloud", DS.ACCENT)
	tile.custom_minimum_size = Vector2(52, 52)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(tile)
	_content.move_child(tile, 0)
	_tile.queue_free()
	_tile = tile
	_title.text = "Save your progress"
	_body.text = "Create a free account to back up your nation and continue on any device. It takes 20 seconds."
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", DS.S2)
	_footer.get_parent().add_child(buttons)
	var create := AppButton.make("Create free account", &"PrimaryButton", "mail")
	create.custom_minimum_size = Vector2(0, 52)
	create.pressed.connect(func() -> void: AccountForm.open(self, true).succeeded.connect(_complete))
	buttons.add_child(create)
	var have := AppButton.make("I already have an account", &"", "log-out")
	have.custom_minimum_size = Vector2(0, 48)
	have.pressed.connect(func() -> void: AccountForm.open(self, false).succeeded.connect(_complete))
	buttons.add_child(have)
	var later := AppButton.make("Not now, play as guest", &"GhostButton")
	later.pressed.connect(_complete)
	buttons.add_child(later)
	var note := Label.new()
	note.theme_type_variation = &"Caption"
	note.text = "Guests are backed up on this device's account too. You can add an email any time in Settings."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(note)
	_map.fly_to(Vector2(0, -400), _map.min_zoom * 1.6, 1.4)
	_layout()
	get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)


func _on_card_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_swiping = true
			_swipe_start = e.global_position
		elif _swiping:
			_swiping = false
			var dx: float = e.global_position.x - _swipe_start.x
			if dx < -50.0:
				_advance()
			elif dx > 50.0:
				_back()
