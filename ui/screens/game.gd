extends Control
## Main game screen: full-screen world map with floating glass chrome.
##   top bar     flag · date (tap to pause) · treasury · Inbox (bell) · Settings
##   strip       play/pause + speed · "what needs you next" pill · map layers
##   dock        Economy · Budget · Build · Laws · World
##   sheet       one bottom sheet hosting every panel
## Calm by design: routine events wait in the pill and Inbox instead of popping up;
## only critical moments (elections, crises) pause the game.

const PAGES := {
	"economy": "res://ui/sheets/economy_page.gd", "budget": "res://ui/sheets/budget_page.gd",
	"diplomacy": "res://ui/sheets/diplomacy_page.gd", "events": "res://ui/sheets/events_page.gd",
	"settings": "res://ui/sheets/settings_page.gd", "country": "res://ui/sheets/country_page.gd",
	"store": "res://ui/sheets/store_page.gd", "laws": "res://ui/sheets/laws_page.gd",
	"achievements": "res://ui/sheets/achievements_page.gd", "build": "res://ui/sheets/build_page.gd",
}
## How long the "year in review" stays in the pill (months).
const REVIEW_MONTHS := 3

var map: MapView
var top_bar: TopBar
var strip: ControlStrip
var layers: LayersPopover
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
var _review: Dictionary = {}       # pending year in review (shown in the pill)
var _review_until := -1
var _paused_for_sheet := false
var _tip_snooze_until := -1


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

	top_bar = TopBar.new()
	top_bar.inbox_requested.connect(func() -> void: open_page("events"))
	top_bar.settings_requested.connect(func() -> void: open_page("settings"))
	top_bar.nation_requested.connect(func() -> void: _open_country(Game.player, true))
	top_bar.budget_requested.connect(func() -> void: open_page("budget"))
	add_child(top_bar)
	strip = ControlStrip.new()
	strip.next_tapped.connect(_on_next)
	strip.layers_tapped.connect(func() -> void:
		layers.set_globe_state(map.globe_on)
		layers.open(strip.layers_rect()))
	add_child(strip)
	dock = Dock.new()
	dock.opened.connect(open_page)
	add_child(dock)

	sheet = BottomSheet.new()
	sheet.stops = [BottomSheet.Snap.PEEK, BottomSheet.Snap.HALF, BottomSheet.Snap.FULL]
	sheet.peek_height = 190.0
	sheet.dismissed.connect(_on_sheet_closed)
	sheet.snapped.connect(_on_sheet_snapped)
	add_child(sheet)
	_build_sheet_header()
	layers = LayersPopover.new()
	layers.mode_selected.connect(_on_mode_changed)
	layers.globe_requested.connect(func() -> void:
		if map.globe_on:
			map.exit_globe()
			return
		if sheet.is_open():
			sheet.close()
		map.enter_globe())
	add_child(layers)

	Screen.insets_changed.connect(_layout)
	resized.connect(_layout)
	_layout.call_deferred()
	map.focus_country.call_deferred(Game.player, 0.01)

	Game.month_passed.connect(_on_month)
	Game.relations_changed.connect(_on_relations_changed)
	Game.event_started.connect(_show_event)
	Game.decision_added.connect(_on_decision_added)
	Game.event_resolved.connect(_on_event_resolved)
	Game.election_held.connect(_show_election)
	Game.review_held.connect(func(r: Dictionary) -> void:
		_notify("%s renews your mandate" % str(r.name), "landmark", DS.GOLD, true, false))
	Game.army_warning.connect(_show_army_warning)
	Game.campaign_started.connect(func() -> void:
		Game.add_feed("Election in 3 months: plan your campaign", "vote", "gold")
		Audio.play("select", -6.0)
		_refresh_next())
	Game.world_news.connect(_on_world_news)
	Game.challenge_ended.connect(_on_challenge_ended)
	Achievements.unlocked.connect(func(id: String) -> void:
		var a := Achievements.info(id)
		_notify("Achievement: " + str(a.title), "crown", DS.GOLD, true)
		Audio.play("success", -6.0))
	Achievements.bump("map_view", 0)
	Game.game_over.connect(_on_game_over)
	Game.law_finished.connect(func(id: String, repealed: bool) -> void:
		var l := Laws.law(id)
		var t := Laws.title_of(Game.me(), l)
		_notify(("%s repealed" if repealed else "%s is now law") % t, str(l.icon), DS.GREEN if not repealed else DS.ORANGE, true)
		if id == "free_elections" and not repealed:
			_notify("Free elections in 12 months", "vote", DS.GOLD, true)
		Haptics.success()
		if _current == "laws":
			_pages["laws"].refresh())
	Game.goal_reached.connect(func(g: Dictionary) -> void:
		_notify("Goal reached: %s" % Goals.title(g), str(Goals.SPECS[g.id].icon), DS.GOLD, true)
		Haptics.success()
		Audio.play("success", -4.0)
		_confetti())
	Game.project_finished.connect(func(id: String) -> void:
		var p := Projects.by_id(id)
		_notify("Now open: %s" % str(p.title).to_lower(), str(p.icon), DS.GREEN, true)
		Haptics.success()
		Audio.play("success", -8.0)
		map.queue_redraw()
		if _current == "build":
			_pages["build"].refresh())
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if (key == "map_theme" and _mode == MapModes.Mode.POLITICAL) or key == "colorblind":
			map.set_colors(_colors_for(_mode))
		if key == "text_scale":
			_layout.call_deferred())
	# A critical decision saved mid-way (or "ask" mode) reopens; routine ones wait in the pill.
	var first := Game.director.first()
	if not first.is_empty() and (bool(first.get("critical", false)) or Settings.decisions == "ask"):
		_show_event.call_deferred(first)
	_refresh_next.call_deferred()
	get_tree().root.go_back_requested.connect(_on_back)
	_dev_open.call_deferred()
	if not Settings.tutorial_done and Game.months_played == 0 and DevTools.arg("open") == null \
			and DevTools.arg("advance") == null and DevTools.arg("event") == null \
			and DevTools.arg("campaign") == null and DevTools.arg("election") == null \
			and DevTools.arg("challenge") == null:
		get_tree().create_timer(0.9).timeout.connect(start_tour)


func _exit_tree() -> void:
	Toast.clear_queue()


# ------------------------------------------------------------------- tour ----
func start_tour() -> void:
	if not is_inside_tree() or is_instance_valid(_modal):
		return
	var prev := Game.speed
	Game.set_speed(0)
	var name := World.map.names[Game.player]
	var i := Game.player
	var goal := "Keep your people happy and the economy healthy. Elections come every %d years: stay above 50%% approval to keep your job." % Government.term_years(i)
	if Government.elections(i) == "managed":
		goal = "Elections every %d years lean your way, but only while people still back you. Keep support and stability up." % Government.term_years(i)
	elif not Government.has_elections(i):
		goal = "There are no elections here. Your rule rests on stability and public support: if both collapse, the streets (or the army) decide."
	var g := Guide.new()
	g.steps = [
		{"target": _player_rect, "title": "Welcome, %s" % (Government.leader_display(i) if str(Settings.leader_name) != "" else "%s of %s" % [Government.leader_title(i), name]),
			"text": "This is your country, a %s. Everything starts from real 2025 data." % Government.system_name(i).to_lower()},
		{"target": strip.time_rect, "title": "Time moves month by month",
			"text": "Pause or play here, and tap the speed to go faster. You can also tap the date at the top to pause."},
		{"target": strip.next_rect, "title": "What needs you",
			"text": "Decisions and tips appear here. They never stop the game: answer when you're ready, or your cabinet decides after a few months."},
		{"target": func() -> Rect2: return dock.button_rect("economy"), "title": "Economy",
			"text": "How your country is doing and what to fix first: taxes, interest rates and forecasts."},
		{"target": func() -> Rect2: return dock.button_rect("budget"), "title": "Budget",
			"text": "Decide how much the government spends, and on what."},
		{"target": func() -> Rect2: return dock.button_rect("build"), "title": "Build",
			"text": "Roads, railways, power, hospitals and more. Projects create jobs now and growth for decades."},
		{"target": func() -> Rect2: return dock.button_rect("laws"), "title": "Laws",
			"text": "Reforms like universal healthcare or a carbon tax. Each takes months to pass."},
		{"target": func() -> Rect2: return dock.button_rect("diplomacy"), "title": "The world",
			"text": "Trade deals, alliances and aid. You can also tap any country on the map."},
		{"target": top_bar.inbox_rect, "title": "Your inbox",
			"text": "Headlines, world news and everything you decided collect here, so nothing needs to pop up."},
		{"target": strip.layers_rect, "title": "Map views",
			"text": "Colour the world by wealth, relations with you, happiness or stability. Tip: pinch out past the whole world to spin a globe."},
		{"title": "Your goal", "text": goal + " Good luck!"},
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
			while Game.director.has_open():
				Game.resolve_event(0)
			if Game.speed == 0:
				Game.set_speed(1)
		_dev_fast = false
		_refresh_next()
	if DevTools.arg("campaign") != null:
		Settings.tutorial_done = true
		Game.politics.campaign_open = true
		Game.campaign_started.emit()
		_show_campaign()
	if DevTools.arg("election") != null:
		Settings.tutorial_done = true
		Game.months_to_election = 1
		Game.advance_month()
	var chal: Variant = DevTools.arg("challenge")
	if chal != null:
		Settings.tutorial_done = true
		Game.new_challenge(str(chal))
		map.set_player(Game.player)
		map.focus_country(Game.player, 0.01)
	var ev_id: Variant = DevTools.arg("event")
	if ev_id != null:
		Settings.tutorial_done = true
		Game.trigger_event(Climate.cop_event(Game.rng) if str(ev_id) == "cop"
			else GameEvents.instance(GameEvents.by_id(str(ev_id)), World.index_of("CHN")))
		_show_event(Game.director.first())
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
	close.custom_minimum_size = Vector2(DS.MIN_TOUCH, DS.MIN_TOUCH)
	close.pressed.connect(sheet.close)
	row.add_child(close)
	_scroll = TouchScroll.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.body.add_child(_scroll)
	_pages_box = VBoxContainer.new()
	_pages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_pages_box)


func _layout() -> void:
	var w := size.x
	var side := DS.S3 + maxf(Screen.left, Screen.right)
	# Landscape: chrome keeps phone-like widths, centred, so the map gets the room.
	var bar_w := minf(w - side * 2.0, 560.0)
	if Screen.landscape:   # stays clear of the side panel
		bar_w = minf(w - sheet.side_width() - side * 3.0, 520.0)
	var dock_w := minf(w - side * 2.0, 520.0)
	top_bar.size = Vector2(bar_w, 0)
	top_bar.position = Vector2(side + Screen.left * 0.0, Screen.top + DS.S2)
	dock.size = Vector2(dock_w, 0)
	var dock_h := dock.get_combined_minimum_size().y
	dock.position = Vector2((w - dock_w) * 0.5, size.y - Screen.bottom - DS.S3 - dock_h)
	dock.set_meta(&"home_y", dock.position.y)
	strip.size = Vector2(dock_w, ControlStrip.H)
	strip.position = Vector2((w - dock_w) * 0.5, dock.position.y - DS.S2 - ControlStrip.H)
	strip.set_meta(&"home_y", strip.position.y)
	# Turning the phone: bring your country back into view.
	if get_meta(&"was_landscape", Screen.landscape) != Screen.landscape:
		map.focus_country.call_deferred(Game.player, 0.4)
	set_meta(&"was_landscape", Screen.landscape)
	if sheet.is_open():
		dock.position.y += 160.0
		strip.position.y += 160.0
	_update_insets()


func _toast_top() -> float:
	return top_bar.position.y + top_bar.get_combined_minimum_size().y + DS.S2


func _update_insets() -> void:
	var top := _toast_top()
	var chrome_top := float(strip.get_meta(&"home_y", size.y))
	if sheet.side():
		var right: float = (sheet.side_width() + DS.S4) if sheet.is_open() else float(DS.S4)
		map.frame_insets = Vector4(DS.S4, top, right, size.y - chrome_top + DS.S3 if not sheet.is_open() else DS.S4)
		var bl: Array[Rect2] = [top_bar.get_rect().grow(4)]
		if sheet.is_open():
			bl.append(Rect2(size.x - sheet.side_width() - 12.0, 0, size.x, size.y))
		else:
			bl.append(Rect2(strip.position.x, chrome_top - 6, strip.size.x, size.y))
		map.label_blockers = bl
		map.queue_redraw()
		return
	var bottom := size.y - (sheet.top_for(sheet.state) if sheet.is_open() else chrome_top) + DS.S3
	map.frame_insets = Vector4(DS.S4, top, DS.S4, bottom)
	var blockers: Array[Rect2] = [top_bar.get_rect().grow(4)]
	if sheet.is_open():
		blockers.append(Rect2(0, sheet.top_for(sheet.state) - 6, size.x, size.y))
	else:
		blockers.append(Rect2(0, chrome_top - 6, size.x, size.y))
	map.label_blockers = blockers
	map.queue_redraw()


# ------------------------------------------------------------------ pages ----
func open_page(page: String) -> void:
	if page == _current and sheet.is_open() and page != "country":
		sheet.close()
		return
	layers.close()
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
	# Landscape is short: page banners (photos / line art) give their room to content.
	for ch in p.get_children():
		if ch is Photo or ch is Illustration:
			(ch as Control).visible = not Screen.landscape
	p.on_open()
	_stagger(p)
	_sheet_title.text = p.title
	_scroll.scroll_vertical = 0
	dock.set_active(page)
	var target := p.open_at
	if sheet.is_open() and sheet.state > target:
		target = sheet.state
	sheet.open(target)
	_hide_chrome(true)
	if page == "events":
		top_bar.refresh_badge()
	if page == "economy":
		learned("economy")
	Haptics.tap()


## Sections fade in one after another (25 ms apart) when a panel opens.
func _stagger(p: Control) -> void:
	if Settings.reduce_motion:
		return
	var k := 0
	for ch in p.get_children():
		if not (ch is CanvasItem) or not (ch as CanvasItem).visible:
			continue
		var c := ch as CanvasItem
		c.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.025 * mini(k, 10))
		DS.ease_out(t)
		t.tween_property(c, "modulate:a", 1.0, 0.28)
		k += 1


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
			p.achievements_requested.connect(func() -> void: open_page("achievements"))
			p.tour_requested.connect(func() -> void:
				sheet.close()
				start_tour())
		"events":
			p.decision_requested.connect(_show_event)
			p.review_requested.connect(func() -> void:
				if not _review.is_empty():
					_show_year_review(_review))


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
	_hide_chrome(false)
	_update_insets()
	if _paused_for_sheet:
		_paused_for_sheet = false
		Game.resume_after_modal()


func _on_sheet_snapped(s: int) -> void:
	_update_insets()
	if s == BottomSheet.Snap.FULL and Settings.pause_full_sheet and Game.speed != 0:
		_paused_for_sheet = true
		Game.pause_for_modal()
	elif s != BottomSheet.Snap.FULL and _paused_for_sheet:
		_paused_for_sheet = false
		Game.resume_after_modal()


func _hide_chrome(hide_it: bool) -> void:
	if _dock_tween:
		_dock_tween.kill()
	_dock_tween = create_tween().set_parallel(true)
	DS.ease_out(_dock_tween)
	for n: Control in [dock, strip]:
		var home: float = n.get_meta(&"home_y", n.position.y)
		_dock_tween.tween_property(n, "position:y", home + (160.0 if hide_it else 0.0), Settings.dur(DS.DUR))
		_dock_tween.tween_property(n, "modulate:a", 0.0 if hide_it else 1.0, Settings.dur(DS.DUR_FAST))


# --------------------------------------------------------- notifications ----
## Everything goes to the Inbox; only `important` items also show a banner
## (all items do in "Everything" banner mode). Banners queue one at a time.
func _notify(text: String, icon_name: String, tint: Color, important: bool, to_feed: bool = true) -> void:
	if to_feed:
		Game.add_feed(text, icon_name, _tint_name(tint))
	if _dev_fast:
		return
	if important or Settings.banners == "all":
		Toast.show_headline(self, text, icon_name, tint, _toast_top())


static func _tint_name(c: Color) -> String:
	if c == DS.GREEN:
		return "green"
	if c == DS.ORANGE:
		return "orange"
	if c == DS.RED:
		return "red"
	if c == DS.GOLD:
		return "gold"
	return "accent"


func _on_decision_added(_ev: Dictionary) -> void:
	if _dev_fast:
		return
	Haptics.select(false)
	Audio.play("event", -10.0)
	_refresh_next()
	if _current == "events":
		_pages["events"].refresh()


func _on_event_resolved(ev: Dictionary, choice: int, by_cabinet: bool) -> void:
	if by_cabinet and not _dev_fast:
		var label := str(ev.choices[clampi(choice, 0, ev.choices.size() - 1)].label)
		_notify("%s: your cabinet chose to %s" % [str(ev.title), label.left(1).to_lower() + label.substr(1)], str(ev.icon),
			GameEvents.tint(str(ev.tint)), Settings.decisions != "cabinet")
	_refresh_next()
	if _current != "" and _pages.has(_current):
		_pages[_current].refresh()


## The one thing that needs the player next, shown in the strip's pill.
func _refresh_next() -> void:
	if not is_inside_tree() or not Game.has_game():
		return
	var item := {}
	var open := Game.director.inbox
	if not open.is_empty():
		var ev: Dictionary = open[0]
		for e in open:
			if bool(e.get("critical", false)):
				ev = e
				break
		var left := Game.director.months_left(ev)
		item = {"kind": "decision", "key": str(ev.uid), "ev": ev, "title": str(ev.title), "icon": str(ev.icon),
			"tint": GameEvents.tint(str(ev.tint)), "due": int(ev.due), "count": open.size(),
			"sub": ("Decide now" if bool(ev.get("critical", false)) else
				("%s · %s" % ["Decide" if open.size() == 1 else "+%d more" % (open.size() - 1),
					"due now" if left <= 1 else "%d mo left" % left]))}
	elif Game.politics.campaign_open:
		item = {"kind": "campaign", "key": "campaign", "title": "Plan your campaign", "icon": "vote", "tint": DS.GOLD,
			"sub": "Election in %d months" % Game.politics.months_to_election}
	elif not _review.is_empty() and Game.months_played <= _review_until:
		item = {"kind": "review", "key": "review%d" % int(_review.year), "title": "%d in review" % int(_review.year),
			"icon": "calendar", "tint": DS.GOLD, "sub": str(_review.title)}
	elif not Learn.finished() and Game.months_played < 48:
		var st := Learn.next_step()
		var n := Learn.STEPS.find(st) + 1
		item = {"kind": "learn", "key": "learn" + str(st.id), "title": str(st.title), "icon": str(st.icon),
			"tint": DS.ACCENT, "sub": "Step %d of %d · tap to start" % [n, Learn.STEPS.size()], "step": st}
	elif Game.months_played >= _tip_snooze_until:
		var tips := Advisor.advice(Game.me())
		if not tips.is_empty() and int(tips[0].level) >= 1:
			var t: Dictionary = tips[0]
			item = {"kind": "tip", "key": "tip" + str(t.title), "title": str(t.title), "icon": str(t.icon),
				"tint": DS.RED if int(t.level) == 2 else DS.ORANGE, "sub": "Tap for what to do", "tip": t}
	strip.set_next(item)


func _on_next(item: Dictionary) -> void:
	match str(item.kind):
		"decision":
			_show_event(item.ev)
		"campaign":
			_show_campaign()
		"review":
			_show_year_review(_review)
		"tip":
			_show_tip(item.tip)
		"learn":
			open_page(str(item.step.page))


func _show_tip(t: Dictionary) -> void:
	if is_instance_valid(_modal):
		return
	_modal = ModalCard.new()
	add_child(_modal)
	var mn: Dictionary = Game.cabinet.minister_for_page(str(t.page))
	var who := "%s minister %s" % [Cabinet.POST_TITLES.get(str(mn.post), ""), str(mn.m.get("name", ""))] if not mn.m.is_empty() else "Advisor"
	var tip_scene: String = {"economy": "markets", "budget": "parliament", "build": "construction", "diplomacy": "summit", "laws": "parliament"}.get(str(t.page), "markets")
	_modal.content.add_child(Illustration.banner(tip_scene, str(Illustration.ICON_ART.get(str(t.icon), "city")), DS.RED if int(t.level) == 2 else DS.ORANGE, 96.0))
	_modal.header(str(t.icon), DS.RED if int(t.level) == 2 else DS.ORANGE, who, str(t.title))
	_modal.body(str(t.detail))
	var page := str(t.page)
	var names := {"economy": "Open Economy", "budget": "Open Budget", "build": "Open Build", "diplomacy": "Open World", "laws": "Open Laws"}
	_modal.choice(str(names.get(page, "Show me")), "", &"PrimaryButton", func() -> void:
		_modal.dismiss()
		if PAGES.has(page):
			open_page(page))
	_modal.choice("Not now", "", &"GhostButton", func() -> void:
		_tip_snooze_until = Game.months_played + 6
		_modal.dismiss()
		_refresh_next())


# ------------------------------------------------------------------ events ---
func _on_country_tapped(i: int) -> void:
	layers.close()
	if i < 0:
		if _current == "country":
			sheet.close()
		elif sheet.is_open() and sheet.state == BottomSheet.Snap.HALF:
			sheet.snap_to(BottomSheet.Snap.PEEK)
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
	var health := Advisor.health(Game.me())
	dock.set_badge(health == 0, "economy")
	_refresh_next()
	# Music follows the mood of the nation.
	var tension: float = [0.85, 0.35, 0.0][health]
	if Game.me().stability < 25.0 or Game.director.inbox.any(func(e: Dictionary) -> bool: return bool(e.get("critical", false))):
		tension = 1.0
	Audio.mood(tension)


## Headlines and the yearly review: quiet by default (Inbox + pill).
func _narrate() -> void:
	if not Game.running or _dev_fast:
		return
	if Game.month == 1 and Game.months_played >= 12:
		var r := Briefing.year_review()
		if not r.is_empty():
			_review = r
			_review_until = Game.months_played + REVIEW_MONTHS
			Game.feed.push_front({"date": Game.date_text(), "text": "%d in review: %s" % [int(r.year), str(r.title)],
				"icon": "calendar", "tint": "gold", "read": false, "kind": "review"})
			Game.feed_added.emit(Game.feed[0])
			_refresh_next()
			return
	var h := Briefing.headline()
	if not h.is_empty():
		_notify(str(h.text), str(h.icon), DS.GREEN if h.good else DS.ORANGE, false)


func _show_year_review(r: Dictionary) -> void:
	if r.is_empty() or is_instance_valid(_modal):
		return
	var prev := Game.speed
	Game.set_speed(0)
	_review_until = -1
	_refresh_next()
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.content.add_child(FrontPage.new().build(r))
	var yr_share := AppButton.make("Share", &"GhostButton", "arrow-up-right")
	_modal.content.add_child(yr_share)
	var hide_list: Array = [yr_share]
	yr_share.pressed.connect(func() -> void:
		var msg: String = await Share.share_screen(get_tree(), "%s's %d: %s." % [
			World.map.names[Game.player], int(r.year), str(r.title).to_lower()], hide_list)
		if msg != "":
			Toast.show_headline(self, msg, "info", DS.ACCENT, _toast_top()))
	hide_list.append(_modal.choice("Back to %d" % (int(r.year) + 1), "", &"PrimaryButton", func() -> void:
		_modal.dismiss()
		Game.set_speed(maxi(prev, 1))))
	Haptics.success(false)
	Audio.play("success", -4.0)


func _on_challenge_ended(won: bool) -> void:
	var ch := Challenges.get_by_id(str(Game.challenge.get("id", "")))
	if ch.is_empty() or is_instance_valid(_modal):
		return
	var prev := Game.speed
	Game.set_speed(0)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header(str(ch.icon), DS.GOLD if won else DS.ORANGE, "Challenge", ("Complete! " if won else "Missed: ") + str(ch.title))
	_modal.body(("You did it: %s Your nation is yours to keep leading." if won else
		"Time ran out on the goal: %s But the country still needs you.") % str(ch.desc))
	if won:
		Audio.play("success")
		Haptics.success(false)
		Achievements.unlock("challenger")
		_modal.sweep(Color(DS.GOLD, 0.22))
	_modal.choice("Keep governing", "", &"PrimaryButton", func() -> void:
		_modal.dismiss()
		Game.set_speed(maxi(prev, 1)))


## World news lives in the Inbox; only big stories about your friends, neighbours
## and the giants get a banner, and only in "Everything" banner mode.
func _on_world_news(item: Dictionary) -> void:
	if _current == "events":
		_pages["events"].refresh()
	if _dev_fast or Settings.banners != "all":
		return
	var i := World.index_of(str(item.country))
	var big := Diplomacy.has_alliance(i) or Diplomacy.has_deal(i) or i in World.map.neighbours[Game.player] \
		or (Game.state(i) != null and Game.state(i).gdp > 3e12)
	if big:
		Toast.show_headline(self, str(item.text), str(item.icon), DS.GREEN if item.good else DS.ORANGE, _toast_top())


func _on_relations_changed() -> void:
	if _mode in [MapModes.Mode.RELATIONS, MapModes.Mode.BLOCS]:
		map.set_colors(_colors_for(_mode))


func _on_mode_changed(m: int) -> void:
	_mode = m
	Achievements.bump("map_view", m)
	map.set_colors(_colors_for(m))
	Haptics.select()


func _colors_for(m: int) -> PackedColorArray:
	if m == MapModes.Mode.POLITICAL:
		return MapModes.political(map.data)
	if m == MapModes.Mode.BLOCS:
		return MapModes.bloc_colors(map.data)
	return MapModes.data_colors(m, Game.map_values(m))


## A decision card. Routine decisions can be put off ("Later") or handed to the
## cabinet; the recommended choice is marked.
func _show_event(ev: Dictionary) -> void:
	if ev.is_empty() or _dev_fast:
		return
	if is_instance_valid(_modal):
		return
	ev = Game.director.find(str(ev.get("uid", ""))) if ev.has("uid") else ev
	if ev.is_empty():
		return
	var critical := bool(ev.get("critical", false))
	var paused_here := false
	if not critical and Settings.decisions != "ask" and Game.speed != 0:
		# Reading a decision pauses time softly; it resumes when the card closes.
		Game.pause_for_modal()
		paused_here = true
	Haptics.warning(false)
	Audio.play("event")
	_modal = ModalCard.new()
	add_child(_modal)
	var other := int(ev.get("other", -1))
	if str(ev.get("face", "")) != "":
		# Scene with the leader's portrait overlapping its lower edge.
		var stack := Control.new()
		stack.custom_minimum_size = Vector2(0, 150)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sc := Photo.scene("aid", 110.0)
		sc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		sc.offset_bottom = 110.0
		stack.add_child(sc)
		var face := Photo.portrait(str(ev.face), 76.0, Color(DS.TEAL, 0.9))
		face.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		face.offset_left = -38.0
		face.offset_right = 38.0
		face.offset_top = -76.0
		face.offset_bottom = 0.0
		stack.add_child(face)
		_modal.content.add_child(stack)
	else:
		_modal.content.add_child(Illustration.banner_for_event(ev, GameEvents.tint(str(ev.tint))))
	_modal.header(str(ev.icon), GameEvents.tint(str(ev.tint)),
		str(ev.get("date", Game.date_text())) + ("  ·  " + World.map.names[other] if other >= 0 else ""), str(ev.title))
	_modal.body(str(ev.body))
	var rec := Game.director.recommended(ev)
	for k in ev.choices.size():
		var ch: Dictionary = ev.choices[k]
		var label := str(ch.label)
		var sub := str(ch.get("detail", "")) if str(ev.id) == "press" else ""
		if k == rec:
			sub = (sub + "  ·  " if sub != "" else "") + "Your cabinet recommends this"
		_modal.choice(label, sub, &"PrimaryButton" if k == rec else &"", func() -> void:
			Haptics.success()
			_modal.dismiss()
			Game.resolve_decision(ev, k)
			if paused_here:
				Game.resume_after_modal(), GameEvents.effect_chips(ch.effects) + ([["May escalate", false, 9.0]] if ch.has("next") and str(ch.next.get("id", "")) != "" and not str(ev.id) in ["recession", "scandal"] else []))
	if not critical and Settings.decisions != "ask":
		var left := Game.director.months_left(ev)
		_modal.choice("Decide later", "Your cabinet decides %s if you don't" % ("this month" if left <= 1 else "in %d months" % left),
			&"GhostButton", func() -> void:
				_modal.dismiss()
				if paused_here:
					Game.resume_after_modal())


func _show_campaign() -> void:
	if is_instance_valid(_modal):
		return
	if not Game.politics.campaign_open:
		return
	var prev := Game.speed
	Game.set_speed(0)
	Audio.play("event")
	Haptics.select(false)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.content.add_child(Illustration.banner("election", "ballot", DS.GOLD))
	_modal.header("vote", DS.GOLD, "Election in %d months" % Game.politics.months_to_election, "Plan your campaign")
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
		Game.set_speed(maxi(prev, 1))
		_refresh_next()
		_notify("Campaign launched: approval %+.1f" % gain, "vote", DS.GREEN if gain >= 0.0 else DS.RED, true))
	_modal.content.add_child(launch)
	_modal.choice("Let my party run it", "Your party picks its two strongest themes", &"GhostButton", func() -> void:
		var themes := Campaign.best_themes(c)
		var gain := Game.finish_campaign(themes)
		_modal.dismiss()
		Game.set_speed(maxi(prev, 1))
		_refresh_next()
		_notify("Campaign launched: approval %+.1f" % gain, "vote", DS.GREEN if gain >= 0.0 else DS.RED, true))


## Election night: the map dims and your country breathes while the votes count
## up; a win ends in a gold sweep, a loss fades calmly to grey.
func _show_election(r: Dictionary) -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	var won: bool = r.won
	Audio.play("election")
	map.spotlight(Game.player, true)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.set_dim(0.25)
	_modal.content.add_child(Illustration.banner("election", "ballot", DS.GOLD))
	_modal.header("vote", DS.GOLD, "Election night %d" % int(r.year), "Counting the votes…")
	var title: Label = _modal.content.get_child(1).get_child(1).get_child(1)
	var share := AnimatedNumber.new()
	share.theme_type_variation = &"LargeTitle"
	share.formatter = func(v: float) -> String: return String.num(v, 1) + "%"
	share.duration = 2.4
	share.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal.content.add_child(share)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var card := _modal
	# Bound to the card: if this card is replaced (two votes in a row while
	# fast-forwarding), the count stops instead of touching freed nodes.
	var t := card.create_tween()
	t.tween_method(func(v: float) -> void:
		prog.v = v
		if is_instance_valid(bar):
			bar.queue_redraw()
		if int(v) % 5 == 0:
			Haptics.tick(), 0.0, float(r.share), Settings.dur(2.4)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished
	if not is_instance_valid(card) or card != _modal or not is_instance_valid(title):
		map.spotlight(-1, false)
		return
	var who := str(Settings.leader_name).strip_edges()
	title.text = ("%s wins again" % who if who != "" else "You won re-election") if won else ("%s loses" % who if who != "" else "You lost the election")
	title.add_theme_color_override(&"font_color", DS.GOLD if won else DS.TEXT_2)
	var managed := bool(r.get("managed", false))
	msg.text = "Your approval stood at %s. %s" % [DS.pct(float(r.approval), 0),
		("Another term to shape the nation." + (" Observers call the vote unfair." if managed and float(r.approval) < Economy.DISPUTED_BELOW else ""))
		if won else ((("After %d terms, many voters wanted a change. " % int(r.terms)) if int(r.get("terms", 0)) >= 2 else "")
			+ ("The opposition takes office." if not Game.god_mode else "Somehow, you stay in office anyway."))]
	_election_groups(r)
	if won:
		Haptics.success()
		_modal.sweep(Color(DS.GOLD, 0.28))
		map.spotlight(Game.player, true, DS.GOLD)
	else:
		Haptics.warning()
		_modal.set_dim(0.7)
		map.spotlight(Game.player, true, Color(0.6, 0.62, 0.68))
	_modal.choice("Continue" if won or Game.god_mode else "See your legacy", "", &"PrimaryButton", func() -> void:
		map.spotlight(-1, false)
		_modal.dismiss()
		Game.continue_after_election(won))


## A first-game checklist step is done (see Learn).
func learned(id: String) -> void:
	if not Learn.complete(id):
		return
	Haptics.success()
	if Learn.finished():
		_notify("You know the basics. Enjoy leading!", "crown", DS.GOLD, true)
		_confetti()
	else:
		var st := Learn.next_step()
		_notify("Done! Next: %s" % str(st.title).to_lower(), "circle-check", DS.GREEN, true, false)
	_refresh_next()


## A short, tasteful burst of gold sparks from the top bar (goals, big wins).
func _confetti() -> void:
	if Settings.reduce_motion or _dev_fast:
		return
	var p := CPUParticles2D.new()
	p.position = Vector2(size.x * 0.5, top_bar.position.y + 40.0)
	p.amount = 46
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 1.6
	p.direction = Vector2(0, 1)
	p.spread = 70.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 340)
	p.damping_min = 20.0
	p.damping_max = 40.0
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var grad := Gradient.new()
	grad.set_color(0, Color(DS.GOLD, 1.0))
	grad.set_color(1, Color(DS.GOLD.lightened(0.3), 0.0))
	p.color_ramp = grad
	p.color_initial_ramp = _confetti_colors()
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.2).timeout.connect(p.queue_free)


static func _confetti_colors() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	g.colors = PackedColorArray([DS.GOLD, DS.ACCENT_SOFT, DS.GREEN, Color.WHITE])
	return g


## Election night: how each voter group voted (support at election time).
func _election_groups(r: Dictionary) -> void:
	if not is_instance_valid(_modal) or Screen.landscape:
		return
	var sup := Blocs.support(Game.me())
	var shift := float(r.share) - Game.me().approval
	var grid_ := GridContainer.new()
	grid_.columns = 5
	grid_.add_theme_constant_override(&"h_separation", DS.S2)
	_modal.content.add_child(grid_)
	_modal.content.move_child(grid_, mini(_modal.content.get_child_count() - 1, 5))
	for g in Blocs.IDS:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override(&"separation", 0)
		grid_.add_child(col)
		var v := clampf(float(sup[g]) + shift, 0.0, 100.0)
		var pl := Label.new()
		pl.theme_type_variation = &"StatSmall"
		pl.text = "%d%%" % roundi(v)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.add_theme_color_override(&"font_color", DS.GOLD if v >= 50.0 else DS.TEXT_2)
		col.add_child(pl)
		var nl := Label.new()
		nl.theme_type_variation = &"Caption"
		nl.text = str(Blocs.INFO[g].title).split(" ")[0]
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.custom_minimum_size = Vector2(20, 0)
		col.add_child(nl)


## The army is restless (military governments): a calm, critical warning.
func _show_army_warning() -> void:
	if is_instance_valid(_modal):
		return
	Audio.play("event")
	Haptics.warning(false)
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.content.add_child(Illustration.make("shield", DS.RED, 96.0))
	_modal.header("shield", DS.RED, "Critical", "The generals are restless")
	_modal.body("Officers grumble about budget cuts and disorder. If nothing changes, they may remove you.")
	var c := Game.me()
	_modal.choice("Restore the military budget", "Military share back to where it started", &"PrimaryButton", func() -> void:
		c.set_budget_share("military", maxf(float(c.budget.military), Game.politics.start_military_share))
		Simulation.update_finances(c)
		c.shocks.stability = float(c.shocks.stability) + 2.0
		Haptics.success()
		_modal.dismiss()
		Game.resume_after_modal()
		if _current != "":
			_pages[_current].refresh())
	_modal.choice("Hold your nerve", "Risky: a coup becomes possible", &"GhostButton", func() -> void:
		_modal.dismiss()
		Game.resume_after_modal())


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
	if layers.visible:
		layers.close()
	elif sheet.is_open():
		sheet.close()
