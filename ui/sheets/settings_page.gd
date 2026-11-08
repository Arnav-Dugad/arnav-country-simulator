class_name SettingsPage
extends SheetPage
## Settings, iOS style: a short, calm list. Your profile card on top, then a few
## groups whose rows open their own sub-page (with a back row) instead of one
## endless scroll of switches.

signal new_game_requested
signal store_requested
signal tour_requested
signal achievements_requested

const DECISION_MODES := ["inbox", "ask", "cabinet"]
const DECISION_HINTS := [
	"Events wait above the dock without stopping time. If you don't answer in 6 months, your cabinet picks the recommended option.",
	"Every event pauses the game until you decide (the classic way).",
	"Your cabinet answers routine events for you and you get a short note. Critical ones still ask you.",
]

var _root: VBoxContainer
var _sub: VBoxContainer
var _profile: ListRow
var _ach_row: ListRow
var _slots_box: VBoxContainer
var _status: Label
var _cheat_box: VBoxContainer
var _account_box: VBoxContainer
var _about_box: VBoxContainer
const PRIVACY_URL := "https://github.com/Arnav-Dugad/arnav-country-simulator/blob/main/PRIVACY.md"
## Opened from the main menu: only app-wide settings (no saves, events, cheats…).
var menu_mode := false


func _init() -> void:
	super._init()
	title = "Settings"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	_root = VBoxContainer.new()
	_root.add_theme_constant_override(&"separation", DS.S4)
	add_child(_root)
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override(&"separation", DS.S4)
	_sub.visible = false
	add_child(_sub)

	var top := section("", _root)
	_profile = ListRow.new()
	_profile.tapped.connect(func() -> void: _open("Your profile", _build_profile))
	top.add_child(_profile)

	if not menu_mode:
		_build_game_section()

	var look := section("Look & feel", _root)
	_nav(look, "Display & accessibility", "Text size, rotation, colours, motion", "layers", DS.PURPLE, func() -> void: _open("Display & accessibility", _build_display))
	_nav(look, "Sound & haptics", "", "volume-2", DS.GREEN, func() -> void: _open("Sound & haptics", _build_sound))

	var more := section("More", _root)
	_nav(more, "Account & cloud", "Backups and your account", "cloud", DS.ACCENT, func() -> void: _open("Account & cloud", _build_account))
	if not menu_mode:
		_nav(more, "Cheats", "A sandbox for experiments", "wand-sparkles", DS.PURPLE, func() -> void: _open("Cheats", _build_cheats))
	_nav(more, "About & updates", "Version %s" % ProjectSettings.get_setting("application/config/version", "0.0.0"), "info", DS.TEXT_3,
		func() -> void: _open("About & updates", _build_about))
	_refresh_profile()


## In-game only: saves, notifications, achievements, store, tour.
func _build_game_section() -> void:
	var game := section("Game", _root)
	_nav(game, "Save & load", "Slots, main menu, new game", "download", DS.ACCENT, func() -> void: _open("Save & load", _build_saves))
	_nav(game, "Notifications", "How events and banners reach you", "bell", DS.RED, func() -> void: _open("Notifications", _build_notifications))
	_ach_row = _nav(game, "Achievements", "%d of %d unlocked" % [Achievements.count(), Achievements.ALL.size()], "crown", DS.GOLD,
		func() -> void: achievements_requested.emit())
	_nav(game, "Store", "Map themes, expansions (demo)", "sparkles", DS.ORANGE, func() -> void: store_requested.emit())
	_nav(game, "Replay the guided tour", "", "map", DS.TEAL, func() -> void: tour_requested.emit())


## A row that opens something (with a chevron).
func _nav(box: VBoxContainer, t: String, sub: String, icon_: String, tint: Color, cb: Callable) -> ListRow:
	var row := ListRow.new().setup(t, sub, "›")
	row.trailing_label.add_theme_color_override(&"font_color", DS.TEXT_3)
	row.set_leading(ListRow.icon_tile(icon_, tint))
	row.tapped.connect(cb)
	box.add_child(row)
	return row


func _open(t: String, builder: Callable) -> void:
	for ch in _sub.get_children():
		ch.queue_free()
	var back := AppButton.make("Settings", &"GhostButton", "chevron-left")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back)
	_sub.add_child(back)
	var h := Label.new()
	h.theme_type_variation = &"Title2"
	h.text = t
	_sub.add_child(h)
	builder.call()
	_root.visible = false
	_sub.visible = true
	_sub.modulate.a = 0.0
	var tw := create_tween()
	DS.ease_out(tw)
	tw.tween_property(_sub, "modulate:a", 1.0, Settings.dur(DS.DUR_FAST))
	var sc := get_parent().get_parent() as ScrollContainer
	if sc:
		sc.scroll_vertical = 0
	Haptics.tap()


func _back() -> void:
	_sub.visible = false
	_root.visible = true
	_refresh_profile()
	Haptics.tap()


func on_open() -> void:
	if _sub and _sub.visible:
		_back()
	refresh()


func refresh() -> void:
	_refresh_profile()
	if _ach_row:
		_ach_row.subtitle_label.text = "%d of %d unlocked" % [Achievements.count(), Achievements.ALL.size()]
	if _slots_box and is_instance_valid(_slots_box) and _slots_box.is_inside_tree():
		_refresh_slots()


# ---------------------------------------------------------------- profile ---
func _refresh_profile() -> void:
	if _profile == null:
		return
	var name := str(Settings.leader_name).strip_edges()
	var sub := Government.leader_title(Game.player) + " of " + World.map.names[Game.player] if Game.has_game() else ""
	if str(Settings.party_name).strip_edges() != "":
		sub += "  ·  " + str(Settings.party_name)
	_profile.setup(name if name != "" else "Add your name", sub, "›")
	var pk := Leaders.player_portrait()
	_profile.set_leading(Photo.portrait(pk, 48.0, Color(DS.GOLD, 0.6)) if pk != "" else
		Avatar.make(name if name != "" else "?", Settings.PARTY_COLORS[clampi(Settings.party_color, 0, 5)], 44.0))


func _build_profile() -> void:
	note("Your name and party appear in headlines, on election night and on your legacy card.", _sub)
	var box := section("", _sub)
	var nl := Label.new()
	nl.theme_type_variation = &"Footnote"
	nl.text = "Your name"
	box.add_child(nl)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "e.g. Arnav Dugad"
	name_edit.text = str(Settings.leader_name)
	name_edit.max_length = 28
	name_edit.text_changed.connect(func(t: String) -> void: Settings.set_value("leader_name", t.strip_edges()))
	box.add_child(name_edit)
	var pl := Label.new()
	pl.theme_type_variation = &"Footnote"
	pl.text = "Your party"
	box.add_child(pl)
	var party_edit := LineEdit.new()
	party_edit.placeholder_text = "e.g. Progress Party"
	party_edit.text = str(Settings.party_name)
	party_edit.max_length = 28
	party_edit.text_changed.connect(func(t: String) -> void: Settings.set_value("party_name", t.strip_edges()))
	box.add_child(party_edit)
	var pt := Label.new()
	pt.theme_type_variation = &"Footnote"
	pt.text = "Your portrait"
	box.add_child(pt)
	var faces := GridContainer.new()
	faces.columns = 5
	faces.add_theme_constant_override(&"h_separation", DS.S2)
	faces.add_theme_constant_override(&"v_separation", DS.S2)
	box.add_child(faces)
	var keys: Array = [""] + Leaders.all_portraits()
	for key in keys:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(54, 54)
		var face: Control = Photo.portrait(str(key), 50.0, Color(DS.GOLD, 0.9) if str(key) == Leaders.player_portrait() else Color(1, 1, 1, 0.15)) \
			if str(key) != "" else Avatar.make(str(Settings.leader_name) if str(Settings.leader_name) != "" else "?", Settings.PARTY_COLORS[clampi(Settings.party_color, 0, 5)], 50.0)
		face.position = Vector2(2, 2)
		b.add_child(face)
		b.pressed.connect(func() -> void:
			Settings.set_value("leader_portrait", str(key))
			Haptics.select()
			_open("Your profile", _build_profile))
		faces.add_child(b)
	note("Portraits are AI-generated, original fictional people.", box)
	var cl := Label.new()
	cl.theme_type_variation = &"Footnote"
	cl.text = "Party colour"
	box.add_child(cl)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override(&"separation", DS.S2)
	box.add_child(colors)
	for k in Settings.PARTY_COLORS.size():
		var sw := Button.new()
		sw.theme_type_variation = &"IconButton"
		sw.custom_minimum_size = Vector2(DS.MIN_TOUCH, DS.MIN_TOUCH)
		sw.focus_mode = Control.FOCUS_NONE
		sw.mouse_filter = Control.MOUSE_FILTER_PASS
		var col: Color = Settings.PARTY_COLORS[k]
		sw.draw.connect(func() -> void:
			var c := sw.size * 0.5
			sw.draw_circle(c, 15.0, col, true, -1.0, true)
			if Settings.party_color == k:
				sw.draw_circle(c, 19.0, Color(1, 1, 1, 0.9), false, 2.0, true))
		sw.pressed.connect(func() -> void:
			Settings.set_value("party_color", k)
			Haptics.select()
			for ch in colors.get_children():
				(ch as Control).queue_redraw())
		colors.add_child(sw)


# ------------------------------------------------------------------ saves ---
func _build_saves() -> void:
	var box := section("", _sub)
	var save := AppButton.make("Save now", &"PrimaryButton", "download")
	save.pressed.connect(func() -> void:
		if SaveManager.save_slot(SaveManager.active_slot):
			Haptics.success()
			_flash("Saved to slot %d" % SaveManager.active_slot))
	box.add_child(save)
	_slots_box = VBoxContainer.new()
	_slots_box.add_theme_constant_override(&"separation", 2)
	box.add_child(_slots_box)
	_status = note("", box)
	_refresh_slots()
	var nav := section("", _sub)
	var home := AppButton.make("Main menu (saves first)", &"", "chevron-left")
	home.pressed.connect(func() -> void:
		SaveManager.save_slot(SaveManager.active_slot, false)
		Game.end_session()
		Router.goto("res://ui/screens/home.tscn"))
	nav.add_child(home)
	var ng := AppButton.make("New game", &"DestructiveButton", "rotate-ccw")
	ng.pressed.connect(func() -> void: new_game_requested.emit())
	nav.add_child(ng)
	if not SaveManager.slots_changed.is_connected(_refresh_slots):
		SaveManager.slots_changed.connect(_refresh_slots)


func _refresh_slots() -> void:
	if _slots_box == null or not is_instance_valid(_slots_box):
		return
	for ch in _slots_box.get_children():
		ch.queue_free()
	for slot in range(1, SaveManager.SLOTS + 1):
		var sm := SaveManager.summary(slot)
		var row := ListRow.new()
		if sm.is_empty():
			row.setup("Slot %d" % slot, "Empty · tap to save here")
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
	if _status == null or not is_instance_valid(_status):
		return
	_status.text = text
	_status.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_property(_status, "modulate:a", 0.0, 0.4)


# ---------------------------------------------------------- notifications ---
func _build_notifications() -> void:
	var box := section("Events", _sub)
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
	var bb := section("Banners", _sub)
	var ban := SegmentedControl.new().setup(["Calm", "Everything"], [], 0 if Settings.banners == "calm" else 1)
	ban.plain = true
	ban.compact = false
	ban.fill = true
	ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban.changed.connect(func(i: int) -> void: Settings.set_value("banners", "calm" if i == 0 else "all"))
	bb.add_child(ban)
	note("Calm shows only important banners, spaced out. Everything else waits in the Inbox (the bell).", bb)
	var tb := section("Time", _sub)
	var pf := AppToggle.new().setup("Pause while a panel is full screen", Settings.pause_full_sheet, "pause")
	pf.toggled.connect(func(v: bool) -> void: Settings.set_value("pause_full_sheet", v))
	tb.add_child(pf)


# ---------------------------------------------------------------- display ---
func _build_display() -> void:
	var box := section("Text", _sub)
	var sizes := [0.9, 1.0, 1.15, 1.3]
	var ts := SegmentedControl.new().setup(["Small", "Default", "Large", "Larger"], [],
		maxi(0, sizes.find(Settings.text_scale)))
	ts.plain = true
	ts.compact = false
	ts.fill = true
	ts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ts.changed.connect(func(i: int) -> void: Settings.set_value("text_scale", sizes[i]))
	box.add_child(ts)
	var rot := section("Screen", _sub)
	var r := AppToggle.new().setup("Rotate to landscape", Settings.landscape, "smartphone-nfc")
	r.toggled.connect(func(v: bool) -> void: Settings.set_value("landscape", v))
	rot.add_child(r)
	note("Turn your phone sideways for a wide map with panels on the side.", rot)
	var acc := section("Accessibility", _sub)
	var cb := AppToggle.new().setup("Colour-blind friendly map", Settings.colorblind, "layers")
	cb.toggled.connect(func(v: bool) -> void: Settings.set_value("colorblind", v))
	acc.add_child(cb)
	var sp := AppToggle.new().setup("Reduce transparency", Settings.solid_panels, "layers")
	sp.toggled.connect(func(v: bool) -> void: Settings.set_value("solid_panels", v))
	acc.add_child(sp)
	var rm := AppToggle.new().setup("Reduce motion", Settings.reduce_motion, "sparkles")
	rm.toggled.connect(func(v: bool) -> void: Settings.set_value("reduce_motion", v))
	acc.add_child(rm)
	note("Reduce transparency uses solid panels: easier to read, and faster on older phones.", acc)


func _build_sound() -> void:
	var box := section("", _sub)
	var snd := AppToggle.new().setup("Sound effects", Settings.sound_on, "volume-2")
	snd.toggled.connect(func(v: bool) -> void: Settings.set_value("sound_on", v))
	box.add_child(snd)
	var mus := AppToggle.new().setup("Music", Settings.music_on, "sparkles")
	mus.toggled.connect(func(v: bool) -> void: Settings.set_value("music_on", v))
	box.add_child(mus)
	var hap := AppToggle.new().setup("Haptic feedback", Settings.haptics, "vibrate")
	hap.toggled.connect(func(v: bool) -> void: Settings.set_value("haptics", v))
	box.add_child(hap)
	note("The music follows the mood of your country: calmer when things go well, tenser in a crisis.", box)


func _build_account() -> void:
	_account_box = section("", _sub)
	_account_box.add_child(AccountSection.new())


# ----------------------------------------------------------------- cheats ---
func _build_cheats() -> void:
	_cheat_box = VBoxContainer.new()
	_sub.add_child(_cheat_box)
	_fill_cheats()


func _fill_cheats() -> void:
	for ch in _cheat_box.get_children():
		ch.queue_free()
	_cheat_box.add_child(CheatsPanel.new())


# ------------------------------------------------------------------ about ---
func _build_about() -> void:
	_about_box = section("", _sub)
	var ver := ListRow.new().setup("Arnav Country Simulator", "Version %s" % ProjectSettings.get_setting(
		"application/config/version", "0.0.0"))
	ver.set_leading(ListRow.icon_tile("globe", DS.ACCENT))
	_about_box.add_child(ver)
	var upd := AppButton.make("Check for updates", &"", "refresh-cw")
	var upd_note := Label.new()
	upd_note.theme_type_variation = &"Caption"
	upd_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upd_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_about_box.add_child(upd)
	_about_box.add_child(upd_note)
	var priv := AppButton.make("Privacy policy", &"GhostButton", "shield")
	priv.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	_about_box.add_child(priv)
	note("Portraits and scene paintings are AI-generated images of fictional people and places. " +
		"Map: Natural Earth (public domain), borders as on India's official map. Data: World Bank (CC BY 4.0), IMF. " +
		"Font: Inter (SIL OFL). Icons: Lucide (ISC). Starting values are real; " +
		"some small states use regional estimates (marked).", _about_box)


## Compatibility for older callers.
func account_box() -> VBoxContainer:
	return _account_box


func about_box() -> VBoxContainer:
	return _about_box
