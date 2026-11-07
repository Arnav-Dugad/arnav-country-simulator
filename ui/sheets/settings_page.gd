class_name SettingsPage
extends SheetPage
## Preferences, saves, account, updates and credits.

signal new_game_requested
signal store_requested
signal tour_requested
signal achievements_requested

var _slots_box: VBoxContainer
var _account_box: VBoxContainer
var _status: Label


func _init() -> void:
	super._init()
	title = "Settings"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	var store_row := ListRow.new().setup("Store", "Map themes, expansions and supporter items",
		"Demo", "")
	store_row.set_leading(ListRow.icon_tile("crown", DS.GOLD))
	store_row.trailing_label.add_theme_color_override(&"font_color", DS.ORANGE)
	store_row.tapped.connect(func() -> void: store_requested.emit())
	var top := section("")
	top.add_child(store_row)
	var ach_row := ListRow.new().setup("Achievements", "%d of %d unlocked" % [Achievements.count(), Achievements.ALL.size()])
	ach_row.set_leading(ListRow.icon_tile("crown", DS.ACCENT))
	ach_row.tapped.connect(func() -> void: achievements_requested.emit())
	top.add_child(ach_row)
	set_meta(&"ach_row", ach_row)

	var game := section("Game")
	var save := AppButton.make("Save now", &"PrimaryButton", "download")
	save.pressed.connect(func() -> void:
		if SaveManager.save_slot(SaveManager.active_slot):
			Haptics.success()
			_flash("Saved to slot %d" % SaveManager.active_slot))
	game.add_child(save)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override(&"separation", 2)
	game.add_child(_slots_box)
	_status = note("", game)
	var home := AppButton.make("Main menu (saves first)", &"", "chevron-left")
	home.pressed.connect(func() -> void:
		SaveManager.save_slot(SaveManager.active_slot, false)
		Game.end_session()
		Router.goto("res://ui/screens/home.tscn"))
	game.add_child(home)
	var ng := AppButton.make("New game", &"DestructiveButton", "rotate-ccw")
	ng.pressed.connect(func() -> void: new_game_requested.emit())
	game.add_child(ng)

	_build_notifications()

	_account_box = section("Account & cloud")
	_account_box.add_child(AccountSection.new())

	var prefs := section("Preferences")
	var snd := AppToggle.new().setup("Sound effects", Settings.sound_on, "volume-2")
	snd.toggled.connect(func(v: bool) -> void: Settings.set_value("sound_on", v))
	prefs.add_child(snd)
	var mus := AppToggle.new().setup("Music", Settings.music_on, "sparkles")
	mus.toggled.connect(func(v: bool) -> void: Settings.set_value("music_on", v))
	prefs.add_child(mus)
	var hap := AppToggle.new().setup("Haptic feedback", Settings.haptics, "vibrate")
	hap.toggled.connect(func(v: bool) -> void: Settings.set_value("haptics", v))
	prefs.add_child(hap)
	var tour := AppButton.make("Replay the guided tour", &"", "map")
	tour.pressed.connect(func() -> void: tour_requested.emit())
	prefs.add_child(tour)
	var rm := AppToggle.new().setup("Reduce motion", Settings.reduce_motion, "sparkles")
	rm.toggled.connect(func(v: bool) -> void: Settings.set_value("reduce_motion", v))
	prefs.add_child(rm)

	var acc := section("Accessibility")
	var ts_lab := Label.new()
	ts_lab.theme_type_variation = &"Body"
	ts_lab.text = "Text size"
	acc.add_child(ts_lab)
	var sizes := [0.9, 1.0, 1.15, 1.3]
	var ts := SegmentedControl.new().setup(["Small", "Default", "Large", "Larger"], [],
		maxi(0, sizes.find(Settings.text_scale)))
	ts.plain = true
	ts.compact = false
	ts.fill = true
	ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts.changed.connect(func(i: int) -> void: Settings.set_value("text_scale", sizes[i]))
	acc.add_child(ts)
	var cb := AppToggle.new().setup("Colour-blind friendly map", Settings.colorblind, "layers")
	cb.toggled.connect(func(v: bool) -> void: Settings.set_value("colorblind", v))
	acc.add_child(cb)
	var sp := AppToggle.new().setup("Reduce transparency", Settings.solid_panels, "layers")
	sp.toggled.connect(func(v: bool) -> void: Settings.set_value("solid_panels", v))
	acc.add_child(sp)
	note("Reduce transparency uses solid panels: easier to read, and faster on older phones.", acc)

	_build_cheats()

	var about := section("About")
	var ver := ListRow.new().setup("Arnav Country Simulator", "Version %s" % ProjectSettings.get_setting(
		"application/config/version", "0.0.0"))
	ver.set_leading(ListRow.icon_tile("globe", DS.ACCENT))
	about.add_child(ver)
	var upd := AppButton.make("Check for updates", &"", "refresh-cw")
	var upd_note := Label.new()
	upd_note.theme_type_variation = &"Caption"
	upd_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upd.pressed.connect(func() -> void:
		upd.disabled = true
		upd_note.text = "Checking…"
		var r: Dictionary = await Updater.check()
		upd.disabled = false
		if r.get("update", false):
			upd_note.text = "Version %s is available." % r.version
			Updater.show_sheet()
		elif r.get("ok", false):
			upd_note.text = str(r.get("error", "")) if str(r.get("error", "")) != "" else "You're on the latest version."
		else:
			upd_note.text = str(r.get("error", "Could not check.")))
	about.add_child(upd)
	about.add_child(upd_note)
	set_meta(&"about_box", about)
	note("Map: Natural Earth (public domain). Data: World Bank (CC BY 4.0), IMF. " +
		"Font: Inter (SIL OFL). Icons: Lucide (ISC). Starting values are real; " +
		"some small states use regional estimates (marked).", about)
	_refresh_slots()
	SaveManager.slots_changed.connect(_refresh_slots)


const DECISION_MODES := ["inbox", "ask", "cabinet"]
const DECISION_HINTS := [
	"Events wait above the dock without stopping time. If you don't answer in 6 months, your cabinet picks the recommended option.",
	"Every event pauses the game until you decide (the classic way).",
	"Your cabinet answers routine events for you and you get a short note. Critical ones still ask you.",
]


func _build_notifications() -> void:
	var box := section("Notifications")
	var l := Label.new()
	l.theme_type_variation = &"Body"
	l.text = "Events"
	box.add_child(l)
	var seg := SegmentedControl.new().setup(["Inbox", "Ask me", "Cabinet"], [],
		maxi(0, DECISION_MODES.find(Settings.decisions)))
	seg.plain = true
	seg.compact = false
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(seg)
	var hint := note(DECISION_HINTS[maxi(0, DECISION_MODES.find(Settings.decisions))], box)
	seg.changed.connect(func(i: int) -> void:
		Settings.set_value("decisions", DECISION_MODES[i])
		hint.text = DECISION_HINTS[i])
	var l2 := Label.new()
	l2.theme_type_variation = &"Body"
	l2.text = "Banners"
	box.add_child(l2)
	var ban := SegmentedControl.new().setup(["Calm", "Everything"], [], 0 if Settings.banners == "calm" else 1)
	ban.plain = true
	ban.compact = false
	ban.fill = true
	ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban.changed.connect(func(i: int) -> void: Settings.set_value("banners", "calm" if i == 0 else "all"))
	box.add_child(ban)
	note("Calm shows only important banners, spaced out. Everything else waits in the Inbox (the bell).", box)
	var pf := AppToggle.new().setup("Pause while a panel is full screen", Settings.pause_full_sheet, "pause")
	pf.toggled.connect(func(v: bool) -> void: Settings.set_value("pause_full_sheet", v))
	box.add_child(pf)


# ----------------------------------------------------------------- cheats ---
var _cheat_box: VBoxContainer


func _build_cheats() -> void:
	_cheat_box = section("Cheats")
	_fill_cheats()


func _fill_cheats() -> void:
	for ch in _cheat_box.get_children():
		ch.queue_free()
	if not Settings.cheats:
		note("A sandbox for experimenting: money, instant building, never losing power and more. Games where you use cheats don't earn achievements.", _cheat_box)
		var unlock := AppButton.make("Turn on cheats", &"", "wand-sparkles")
		unlock.pressed.connect(func() -> void:
			Settings.set_value("cheats", true)
			Haptics.success()
			_fill_cheats())
		_cheat_box.add_child(unlock)
		return
	if Game.me() == null:
		return
	var status := note("Cheats used in this game: %s" % ("yes, achievements are off" if Game.cheats_used else "not yet"), _cheat_box)
	var cheat := func(text: String, icon_: String, fn: Callable) -> void:
		var b := AppButton.make(text, &"", icon_)
		b.pressed.connect(func() -> void:
			Game.cheats_used = true
			fn.call()
			Simulation.update_finances(Game.me())
			Game.me().refresh_explainer()
			Game.month_passed.emit()   # refresh every panel
			Haptics.success()
			status.text = "Done: %s. Achievements are off for this game." % text.to_lower())
		_cheat_box.add_child(b)
	cheat.call("Add 10% of GDP to the treasury", "coins", func() -> void:
		Game.me().treasury += Game.me().gdp * 0.1)
	cheat.call("Wipe out the national debt", "piggy-bank", func() -> void:
		Game.me().debt = 0.0)
	cheat.call("Everyone loves you", "heart", func() -> void:
		var m := Game.me()
		m.approval = minf(m.approval + 20.0, 95.0)
		m.happiness = minf(m.happiness + 15.0, 95.0)
		m.shocks.approval = float(m.shocks.approval) + 20.0
		m.shocks.happiness = float(m.shocks.happiness) + 15.0)
	cheat.call("Restore order", "shield", func() -> void:
		var m := Game.me()
		m.stability = minf(m.stability + 25.0, 95.0)
		m.shocks.stability = float(m.shocks.stability) + 25.0)
	cheat.call("Finish all construction now", "hammer", func() -> void:
		var m := Game.me()
		for id in m.projects.keys():
			if str(m.projects[id].state) == "building":
				m.projects[id].progress = float(Projects.by_id(id).months)
		for id in Projects.monthly(m):
			Game.project_finished.emit(str(id)))
	cheat.call("Pass all laws being debated", "gavel", func() -> void:
		var m := Game.me()
		for id in m.laws.keys():
			if str(m.laws[id].get("state", "")) in ["passing", "repealing"]:
				m.laws[id].months_left = 1
		for done in Laws.monthly(m):
			if str(done.id) == "free_elections" and not bool(done.repealed):
				Game.politics.become_democracy()
			Game.law_finished.emit(str(done.id), bool(done.repealed)))
	cheat.call("Make friends with the whole world", "globe", func() -> void:
		for i in Game.relations.size():
			if i != Game.player:
				Game.relations[i] = clampf(Game.relations[i] + 30.0, -100.0, 100.0)
				Game.dip.baseline[str(i)] = clampf(float(Game.dip.baseline.get(str(i), 0.0)) + 30.0, -100.0, 100.0)
		Game.relations_changed.emit())
	var god := AppToggle.new().setup("Never lose power", Game.god_mode, "crown")
	god.toggled.connect(func(v: bool) -> void:
		Game.god_mode = v
		if v:
			Game.cheats_used = true
			status.text = "You can't lose power. Achievements are off for this game.")
	_cheat_box.add_child(god)
	var off := AppButton.make("Hide cheats", &"GhostButton", "x")
	off.pressed.connect(func() -> void:
		Settings.set_value("cheats", false)
		_fill_cheats())
	_cheat_box.add_child(off)


## Box that later phases (account, updates) fill in.
func account_box() -> VBoxContainer:
	return _account_box


func about_box() -> VBoxContainer:
	return get_meta(&"about_box")


func _refresh_slots() -> void:
	for ch in _slots_box.get_children():
		ch.queue_free()
	for slot in range(1, SaveManager.SLOTS + 1):
		var sm := SaveManager.summary(slot)
		var row := ListRow.new()
		if sm.is_empty():
			row.setup("Slot %d" % slot, "Empty — tap to save here")
		else:
			row.setup("Slot %d  ·  %s" % [slot, sm.get("name", "")], "%s  ·  approval %s%%" % [
				sm.get("date", ""), String.num(float(sm.get("approval", 0.0)), 0)],
				"Active" if slot == SaveManager.active_slot else "Load")
		row.selected = slot == SaveManager.active_slot
		row.tapped.connect(_on_slot.bind(slot, sm.is_empty()))
		_slots_box.add_child(row)


func _on_slot(slot: int, empty: bool) -> void:
	if empty or slot == SaveManager.active_slot:
		SaveManager.save_slot(slot)
		_flash("Saved to slot %d" % slot)
	elif SaveManager.load_slot(slot):
		_flash("Loaded slot %d" % slot)
		Router.goto("res://ui/screens/game.tscn")


func _flash(text: String) -> void:
	_status.text = text
	_status.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_property(_status, "modulate:a", 0.0, 0.4)


func refresh() -> void:
	_refresh_slots()
	if Settings.cheats and _cheat_box and _cheat_box.get_child_count() <= 2:
		_fill_cheats()
	var ar: ListRow = get_meta(&"ach_row", null)
	if ar:
		ar.subtitle_label.text = "%d of %d unlocked" % [Achievements.count(), Achievements.ALL.size()]
