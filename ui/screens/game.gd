extends Control
## Main game screen: full-screen world map with floating glass chrome — top bar,
## map-mode control, dock — and one bottom sheet that hosts every panel.

const PAGES := {
	"economy": "res://ui/sheets/economy_page.gd", "budget": "res://ui/sheets/budget_page.gd",
	"diplomacy": "res://ui/sheets/diplomacy_page.gd", "events": "res://ui/sheets/events_page.gd",
	"settings": "res://ui/sheets/settings_page.gd", "country": "res://ui/sheets/country_page.gd",
	"store": "res://ui/sheets/store_page.gd", "laws": "res://ui/sheets/laws_page.gd",
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
var _dev_fast := false   # DevTools fast-forward: skip modals


func _ready() -> void:
	if not Game.has_game():  # e.g. launched directly via --scene
		Game.new_game(World.index_of("IND"))
	add_child(OceanBackground.new())
	map = MapView.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.country_tapped.connect(_on_country_tapped)
	map.country_long_pressed.connect(func(i: int) -> void:
		_open_country(i, false)
		sheet.snap_to(BottomSheet.Snap.HALF))
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
	Game.campaign_started.connect(_show_campaign)
	Game.game_over.connect(_on_game_over)
	Game.law_finished.connect(func(id: String, repealed: bool) -> void:
		var l := Laws.law(id)
		Toast.show_headline(self, ("%s repealed" if repealed else "%s is now law") % str(l.title),
			str(l.icon), DS.GREEN if not repealed else DS.ORANGE, modes.position.y + 52.0)
		Haptics.success()
		if _current == "laws":
			_pages["laws"].refresh())
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if (key == "map_theme" and _mode == MapModes.Mode.POLITICAL) or key == "colorblind":
			map.set_colors(_colors_for(_mode))
		if key == "text_scale":
			_layout.call_deferred())
	if not Game.pending_event.is_empty():
		_show_event.call_deferred(Game.pending_event)
	get_tree().root.go_back_requested.connect(_on_back)
	_dev_open.call_deferred()
	if not Settings.tutorial_done and Game.months_played == 0 and DevTools.arg("open") == null 			and DevTools.arg("advance") == null and DevTools.arg("event") == null \
			and DevTools.arg("campaign") == null and DevTools.arg("election") == null:
		get_tree().create_timer(0.9).timeout.connect(start_tour)


# ------------------------------------------------------------------- tour ----
func start_tour() -> void:
	if not is_inside_tree() or is_instance_valid(_modal):
		return
	var prev := Game.speed
	Game.set_speed(0)
	var name := World.map.names[Game.player]
	var g := Guide.new()
	g.steps = [
		{"target": _player_rect, "title": "Welcome, leader of %s" % name,
			"text": "This is your country. Everything starts from real 2025 data: its people, money, debt and mood."},
		{"target": top_bar.speed_rect, "title": "Time moves month by month",
			"text": "One month passes every 2 seconds. Pause whenever you want to think, or speed up to 4×."},
		{"target": func() -> Rect2: return dock.button_rect("economy"), "title": "Economy",
			"text": "See how your country is doing and what to fix first. Set taxes and interest rates, with a forecast as you move each slider."},
		{"target": func() -> Rect2: return dock.button_rect("budget"), "title": "Budget",
			"text": "Decide how much the government spends, and on what: healthcare, schools, roads and more."},
		{"target": func() -> Rect2: return dock.button_rect("laws"), "title": "Laws",
			"text": "Pass reforms like universal healthcare or a carbon tax. Each takes months to pass and has clear tradeoffs."},
		{"target": func() -> Rect2: return dock.button_rect("diplomacy"), "title": "The world",
			"text": "Make friends abroad with trade deals, alliances and aid. You can also tap any country on the map."},
		{"target": modes.get_global_rect, "title": "Map views",
			"text": "Color the world by wealth, relations with you, happiness or stability."},
		{"title": "Your goal",
			"text": "Keep your people happy and the economy healthy. Elections come every 4 years: stay above 50% approval to keep your job. Good luck!"},
	]
	add_child(g)
	g.finished.connect(func() -> void:
		Settings.set_value("tutorial_done", true)
		Game.set_speed(maxi(prev, 1)))


func _player_rect() -> Rect2:
	var r := map.focus_rect(Game.player)
	var xf := map.get_global_transform()
	var a := xf * map.world_to_screen(r.position)
	var b := xf * map.world_to_screen(r.end)
	var view := map.get_global_rect().grow(-DS.S4)
	return Rect2(a, b - a).intersection(view)


## DevTools: --open=<page> [--scroll=<px>] opens a sheet page at full height.
func _dev_open() -> void:
	var adv: Variant = DevTools.arg("advance")
	if adv != null:
		Settings.tutorial_done = true
		_dev_fast = true
		for _m in int(str(adv)):
			Game.advance_month()
			if not Game.pending_event.is_empty():
				Game.resolve_event(0)
		_dev_fast = false
		_narrate()
	if DevTools.arg("campaign") != null:
		Settings.tutorial_done = true
		Game.campaign_started.emit()
	if DevTools.arg("election") != null:
		Settings.tutorial_done = true
		Game.months_to_election = 1
		Game.advance_month()
	var ev_id: Variant = DevTools.arg("event")
	if ev_id != null:
		Settings.tutorial_done = true
		Game.trigger_event(GameEvents.instance(GameEvents.by_id(str(ev_id)), World.index_of("CHN")))
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
	var blockers: Array[Rect2] = [top_bar.get_rect().grow(4), modes.get_rect().grow(4)]
	if sheet.is_open():
		blockers.append(Rect2(0, sheet.top_for(sheet.state) - 6, size.x, size.y))
	else:
		blockers.append(Rect2(dock.position.x, float(dock.get_meta(&"home_y", dock.position.y)) - 6, dock.size.x, size.y))
	map.label_blockers = blockers
	map.queue_redraw()


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
		"economy":
			p.page_requested.connect(open_page)
		"country":
			p.page_requested.connect(open_page)
		"settings":
			p.new_game_requested.connect(_confirm_new_game)
			p.store_requested.connect(func() -> void: open_page("store"))
			p.tour_requested.connect(func() -> void:
				sheet.close()
				start_tour())
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
	_narrate.call_deferred()
	if _current != "" and _pages.has(_current):
		_pages[_current].refresh()
		_sheet_title.text = _pages[_current].title
	if _mode != MapModes.Mode.POLITICAL and Game.month % 3 == 1:
		map.set_colors(_colors_for(_mode))
	dock.set_badge(not Game.pending_event.is_empty())
	dock.set_badge(Advisor.health(Game.me()) == 0, "economy")


## Headlines and the yearly review (deferred so events/elections show first).
func _narrate() -> void:
	if not Game.running or is_instance_valid(_modal) or _dev_fast:
		return
	if Game.month == 1 and Game.months_played >= 12:
		var r := Briefing.year_review()
		if not r.is_empty():
			_show_year_review(r)
			return
	var h := Briefing.headline()
	if not h.is_empty():
		Toast.show_headline(self, str(h.text), str(h.icon), DS.GREEN if h.good else DS.ORANGE,
			modes.position.y + 52.0)
		Audio.play("select", -8.0)


func _show_year_review(r: Dictionary) -> void:
	var prev := Game.speed
	Game.set_speed(0)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("calendar", DS.GOLD, "%d in review" % int(r.year), str(r.title))
	for row in r.rows:
		var line := HBoxContainer.new()
		_modal.content.add_child(line)
		var l := Label.new()
		l.theme_type_variation = &"Body"
		l.text = str(row.label)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(l)
		var a := float(row.from)
		var b := float(row.to)
		var fmt := func(v: float) -> String: return DS.money(v) if row.kind == "money" else DS.pct(v)
		var v := Label.new()
		v.theme_type_variation = &"StatSmall"
		var up := b > a
		v.text = "%s  %s  %s" % [fmt.call(a), "→", fmt.call(b)]
		v.add_theme_color_override(&"font_color", DS.TEXT_2 if absf(b - a) < 0.05 else (DS.GREEN if up == bool(row.good_up) else DS.RED))
		line.add_child(v)
	_modal.choice("On to %d" % (int(r.year) + 1), "", &"PrimaryButton", func() -> void:
		_modal.dismiss()
		Game.set_speed(maxi(prev, 1))
		if not Game.pending_event.is_empty():
			get_tree().create_timer(0.4).timeout.connect(func() -> void: _show_event(Game.pending_event)))
	Haptics.success(false)
	Audio.play("success", -4.0)


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
	if ev.is_empty() or is_instance_valid(_modal) or _dev_fast:
		return
	dock.set_badge(true)
	Haptics.warning(false)
	Audio.play("event")
	_modal = ModalCard.new()
	add_child(_modal)
	var other := int(ev.get("other", -1))
	_modal.header(str(ev.icon), GameEvents.tint(str(ev.tint)),
		Game.date_text() + ("  ·  " + World.map.names[other] if other >= 0 else ""), str(ev.title))
	_modal.body(str(ev.body))
	for k in ev.choices.size():
		var ch: Dictionary = ev.choices[k]
		_modal.choice(str(ch.label), "", &"PrimaryButton" if k == 0 else &"", func() -> void:
			Game.resolve_event(k)
			Haptics.success()
			dock.set_badge(false)
			_modal.dismiss()
			if _current != "":
				_pages[_current].refresh(), GameEvents.effect_chips(ch.effects))


func _show_campaign() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	Audio.play("event")
	Haptics.select(false)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("vote", DS.GOLD, "Election in 3 months", "Plan your campaign")
	_modal.body("Pick two themes. Campaigning on your strengths wins votes; a weak record can backfire.")
	var c := Game.me()
	var picked: Array = []
	var launch := AppButton.make("Choose 2 themes", &"PrimaryButton", "vote")
	launch.disabled = true
	var rows := {}
	for th in Campaign.THEMES:
		var rec := Campaign.record(c, th.id)
		var row := ListRow.new().setup(str(th.title), Campaign.record_text(rec),
			"%+.1f" % Campaign.boost(c, th.id), "approval")
		row.set_leading(ListRow.icon_tile(str(th.icon), DS.GREEN if rec >= 0.4 else (DS.ORANGE if rec >= -0.1 else DS.RED)))
		row.subtitle_label.add_theme_color_override(&"font_color",
			DS.GREEN if rec >= 0.4 else (DS.TEXT_2 if rec >= -0.1 else DS.RED))
		row.trailing_label.add_theme_color_override(&"font_color", DS.GREEN if Campaign.boost(c, th.id) >= 0.0 else DS.RED)
		row.tapped.connect(func() -> void:
			if th.id in picked:
				picked.erase(th.id)
			elif picked.size() < 2:
				picked.append(th.id)
			else:
				var old: String = picked.pop_front()
				rows[old].selected = false
				picked.append(th.id)
			row.selected = th.id in picked
			launch.disabled = picked.size() < 2
			launch.text = "Launch campaign" if picked.size() == 2 else "Choose %d more" % (2 - picked.size()))
		rows[th.id] = row
		_modal.content.add_child(row)
	launch.custom_minimum_size = Vector2(0, 50)
	launch.pressed.connect(func() -> void:
		var gain := Game.finish_campaign(picked)
		Haptics.success()
		_modal.dismiss()
		Toast.show_headline(self, "Campaign launched: approval %+.1f" % gain, "vote",
			DS.GREEN if gain >= 0.0 else DS.RED, modes.position.y + 52.0))
	_modal.content.add_child(launch)
	_modal.choice("Skip campaigning", "", &"GhostButton", func() -> void:
		Game.finish_campaign([])
		_modal.dismiss())


## Election night: votes count up live, then the result lands.
func _show_election(r: Dictionary) -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	var won: bool = r.won
	Audio.play("election")
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("vote", DS.GOLD, "Election night %d" % int(r.year), "Counting the votes…")
	var title: Label = _modal.content.get_child(0).get_child(1).get_child(1)
	var share := AnimatedNumber.new()
	share.theme_type_variation = &"LargeTitle"
	share.formatter = func(v: float) -> String: return String.num(v, 1) + "%"
	share.duration = 2.4
	share.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.content.add_child(share)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	var prog := {"v": 0.0}
	bar.draw.connect(func() -> void:
		var w := bar.size.x
		var track: StyleBox = get_theme_stylebox(&"track", &"AppSlider")
		bar.draw_style_box(track, Rect2(0, 4, w, 6))
		var fill: StyleBoxFlat = (get_theme_stylebox(&"fill", &"AppSlider") as StyleBoxFlat).duplicate()
		fill.bg_color = DS.GOLD if prog.v >= 50.0 else DS.ACCENT
		bar.draw_style_box(fill, Rect2(0, 4, maxf(w * prog.v / 100.0, 6.0), 6))
		bar.draw_rect(Rect2(w * 0.5 - 1, 0, 2, 14), Color(1, 1, 1, 0.55)))
	_modal.content.add_child(bar)
	var cap := Label.new()
	cap.theme_type_variation = &"Caption"
	cap.text = "50% to win"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.content.add_child(cap)
	var msg := _modal.body("")
	share.set_instant(0.0)
	share.value = float(r.share)
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		prog.v = v
		bar.queue_redraw()
		if int(v) % 5 == 0:
			Haptics.tick(), 0.0, float(r.share), Settings.dur(2.4)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	if not is_instance_valid(_modal):
		return
	title.text = "You won re-election" if won else "You lost the election"
	title.add_theme_color_override(&"font_color", DS.GOLD if won else DS.RED)
	msg.text = "Your approval stood at %s. %s" % [DS.pct(float(r.approval), 0),
		"Another four years to shape the nation." if won else "The opposition takes office."]
	if won:
		Haptics.success()
	else:
		Haptics.warning()
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
