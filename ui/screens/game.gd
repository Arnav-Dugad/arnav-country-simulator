extends Control
## Main game screen: full-screen world map with floating glass chrome — top bar,
## map-mode control, dock — and one bottom sheet that hosts every panel.

const PAGES := {
	"economy": "res://ui/sheets/economy_page.gd", "budget": "res://ui/sheets/budget_page.gd",
	"diplomacy": "res://ui/sheets/diplomacy_page.gd", "events": "res://ui/sheets/events_page.gd",
	"settings": "res://ui/sheets/settings_page.gd", "country": "res://ui/sheets/country_page.gd",
	"store": "res://ui/sheets/store_page.gd",
}

var map: MapView
var modes: SegmentedControl
var top_bar: TopBar
var dock: Dock
var sheet: BottomSheet
var _sheet_title: Label
var _sheet_flag: Flag
var _scroll: ScrollContainer
var _pages_box: VBoxContainer   # every created page lives here; only one is visible
var _pages := {}
var _current := ""
var _mode := MapModes.Mode.POLITICAL
var _modal: ModalCard
var _dock_tween: Tween


func _ready() -> void:
	if not Game.has_game():  # e.g. launched directly via --scene
		Game.new_game(World.index_of("IND"))
	add_child(OceanBackground.new())
	map = MapView.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.country_tapped.connect(_on_country_tapped)
	map.set_player(Game.player)

	modes = SegmentedControl.new().setup(MapModes.SHORT, MapModes.ICONS, 0)
	modes.changed.connect(_on_mode_changed)
	add_child(modes)
	top_bar = TopBar.new()
	add_child(top_bar)
	dock = Dock.new()
	dock.opened.connect(open_page)
	add_child(dock)

	sheet = BottomSheet.new()
	sheet.stops = [BottomSheet.Snap.PEEK, BottomSheet.Snap.HALF, BottomSheet.Snap.FULL]
	sheet.peek_height = 190.0
	sheet.dismissed.connect(_on_sheet_closed)
	sheet.snapped.connect(func(_s: int) -> void: _update_insets())
	add_child(sheet)
	_build_sheet_header()

	Screen.insets_changed.connect(_layout)
	resized.connect(_layout)
	_layout.call_deferred()
	map.focus_country.call_deferred(Game.player, 0.01)

	Game.month_passed.connect(_on_month)
	Game.relations_changed.connect(_on_relations_changed)
	Game.event_started.connect(_show_event)
	Game.election_held.connect(_show_election)
	Game.game_over.connect(_on_game_over)
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if key == "map_theme" and _mode == MapModes.Mode.POLITICAL:
			map.set_colors(_colors_for(_mode)))
	if not Game.pending_event.is_empty():
		_show_event.call_deferred(Game.pending_event)
	get_tree().root.go_back_requested.connect(_on_back)
	_dev_open.call_deferred()


## DevTools: --open=<page> [--scroll=<px>] opens a sheet page at full height.
func _dev_open() -> void:
	var page: Variant = DevTools.arg("open")
	if page == null or not PAGES.has(str(page)):
		return
	open_page(str(page))
	sheet.snap_to(BottomSheet.Snap.FULL, false)
	await get_tree().process_frame
	await get_tree().process_frame
	_scroll.scroll_vertical = int(str(DevTools.arg("scroll", "0")))


func _build_sheet_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S3)
	sheet.header.add_child(row)
	_sheet_flag = Flag.new()
	_sheet_flag.visible = false
	row.add_child(_sheet_flag)
	_sheet_title = Label.new()
	_sheet_title.theme_type_variation = &"Title2"
	_sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sheet_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_sheet_title)
	var close := AppButton.make("", &"IconButton", "x")
	close.pressed.connect(sheet.close)
	row.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.body.add_child(_scroll)
	_pages_box = VBoxContainer.new()
	_pages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages_box)


func _layout() -> void:
	var w := size.x
	var side := DS.S3 + maxf(Screen.left, Screen.right)
	top_bar.size = Vector2(w - side * 2.0, 0)
	top_bar.position = Vector2(side, Screen.top + DS.S2)
	var top_h := top_bar.get_combined_minimum_size().y
	modes.reset_size()
	modes.position = Vector2((w - modes.get_combined_minimum_size().x) * 0.5, top_bar.position.y + top_h + DS.S2)
	dock.size = Vector2(w - side * 2.0, 0)
	var dock_h := dock.get_combined_minimum_size().y
	dock.position = Vector2(side, size.y - Screen.bottom - DS.S3 - dock_h)
	dock.set_meta(&"home_y", dock.position.y)
	if sheet.is_open():
		dock.position.y += 90.0
	_update_insets()


func _update_insets() -> void:
	var top := modes.position.y + 44.0 + DS.S2
	var bottom := size.y - (sheet.top_for(sheet.state) if sheet.is_open() else float(dock.get_meta(&"home_y", size.y))) + DS.S3
	map.frame_insets = Vector4(DS.S4, top, DS.S4, bottom)


# ------------------------------------------------------------------ pages ----
func open_page(page: String) -> void:
	if page == _current and sheet.is_open() and page != "country":
		sheet.close()
		return
	var p: SheetPage = _pages.get(page)
	if p == null:
		p = load(PAGES[page]).new()
		_pages[page] = p
		_wire_page(page, p)
	# Pages stay in the tree (hidden) so they are freed with the screen.
	if p.get_parent() == null:
		_pages_box.add_child(p)
	for k in _pages:
		_pages[k].visible = k == page
	_current = page
	_sheet_flag.visible = false
	p.on_open()
	_sheet_title.text = p.title
	_scroll.scroll_vertical = 0
	dock.set_active(page)
	var target := p.open_at
	if sheet.is_open() and sheet.state > target:
		target = sheet.state
	sheet.open(target)
	_hide_dock(true)
	Haptics.tap()


func _wire_page(page: String, p: SheetPage) -> void:
	match page:
		"diplomacy":
			p.country_requested.connect(func(i: int) -> void: _open_country(i, true))
		"country":
			p.page_requested.connect(open_page)
		"settings":
			p.new_game_requested.connect(_confirm_new_game)
			p.store_requested.connect(func() -> void: open_page("store"))
		"events":
			p.open_pending.connect(func() -> void: _show_event(Game.pending_event))


func _open_country(i: int, focus: bool) -> void:
	map.select(i)
	open_page("country")
	var cp: CountryPage = _pages["country"]
	cp.show_country(i)
	_sheet_title.text = cp.title
	_sheet_flag.show_country(i, 24.0)
	if focus:
		await get_tree().process_frame
		_update_insets()
		map.focus_country(i)


func _on_sheet_closed() -> void:
	_current = ""
	dock.set_active("")
	map.select(-1)
	_hide_dock(false)
	_update_insets()


func _hide_dock(hide_it: bool) -> void:
	if _dock_tween:
		_dock_tween.kill()
	_dock_tween = create_tween().set_parallel(true)
	DS.ease_out(_dock_tween)
	var home: float = dock.get_meta(&"home_y", dock.position.y)
	_dock_tween.tween_property(dock, "position:y", home + (90.0 if hide_it else 0.0), Settings.dur(DS.DUR))
	_dock_tween.tween_property(dock, "modulate:a", 0.0 if hide_it else 1.0, Settings.dur(DS.DUR_FAST))


# ------------------------------------------------------------------ events ---
func _on_country_tapped(i: int) -> void:
	if i < 0:
		if _current == "country":
			sheet.close()
		map.select(-1)
		return
	Haptics.select()
	_open_country(i, false)


func _on_month() -> void:
	if _current != "" and _pages.has(_current):
		_pages[_current].refresh()
		_sheet_title.text = _pages[_current].title
	if _mode != MapModes.Mode.POLITICAL and Game.month % 3 == 1:
		map.set_colors(_colors_for(_mode))
	dock.set_badge(not Game.pending_event.is_empty())


func _on_relations_changed() -> void:
	if _mode == MapModes.Mode.RELATIONS:
		map.set_colors(_colors_for(_mode))


func _on_mode_changed(m: int) -> void:
	_mode = m
	map.set_colors(_colors_for(m))


func _colors_for(m: int) -> PackedColorArray:
	if m == MapModes.Mode.POLITICAL:
		return MapModes.political(map.data)
	return MapModes.data_colors(m, Game.map_values(m))


func _show_event(ev: Dictionary) -> void:
	if ev.is_empty() or is_instance_valid(_modal):
		return
	dock.set_badge(true)
	Haptics.warning()
	_modal = ModalCard.new()
	add_child(_modal)
	var other := int(ev.get("other", -1))
	_modal.header(str(ev.icon), GameEvents.tint(str(ev.tint)),
		Game.date_text() + ("  ·  " + World.map.names[other] if other >= 0 else ""), str(ev.title))
	_modal.body(str(ev.body))
	for k in ev.choices.size():
		var ch: Dictionary = ev.choices[k]
		_modal.choice(str(ch.label), str(ch.detail), &"PrimaryButton" if k == 0 else &"", func() -> void:
			Game.resolve_event(k)
			Haptics.success()
			dock.set_badge(false)
			_modal.dismiss()
			if _current != "":
				_pages[_current].refresh())


func _show_election(r: Dictionary) -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	var won: bool = r.won
	if won:
		Haptics.success()
	else:
		Haptics.warning()
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("vote", DS.GOLD if won else DS.RED, "Election %d" % int(r.year),
		"You won re-election" if won else "You lost the election")
	var share := AnimatedNumber.new()
	share.theme_type_variation = &"LargeTitle"
	share.formatter = func(v: float) -> String: return String.num(v, 1) + "% of the vote"
	share.duration = 1.2
	_modal.content.add_child(share)
	share.set_instant(0.0)
	share.value = float(r.share)
	_modal.body("Your approval stood at %s. %s" % [DS.pct(float(r.approval), 0),
		"Another four years to shape the nation." if won else "The opposition takes office."])
	_modal.choice("Continue" if won else "See your legacy", "", &"PrimaryButton", func() -> void:
		_modal.dismiss()
		Game.continue_after_election(won))


func _on_game_over(s: Dictionary) -> void:
	Game.set_meta(&"end_reason", s.reason)
	Router.goto("res://ui/screens/game_over.tscn", 0.6)


func _confirm_new_game() -> void:
	if is_instance_valid(_modal):
		return
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("rotate-ccw", DS.RED, "New game", "Start over?")
	_modal.body("Your current game in slot %d will be replaced when you pick a new nation." % SaveManager.active_slot)
	_modal.choice("Choose a new nation", "", &"DestructiveButton", func() -> void:
		_modal.dismiss()
		Game.end_session()
		Router.goto("res://ui/screens/country_picker.tscn"))
	_modal.choice("Cancel", "", &"GhostButton", func() -> void: _modal.dismiss())


func _on_back() -> void:
	if is_instance_valid(_modal):
		return
	if sheet.is_open():
		sheet.close()
