class_name SettingsPage
extends SheetPage
## Preferences, saves, account, updates and credits.

signal new_game_requested
signal store_requested
signal tour_requested

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
	section("").add_child(store_row)

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
	var ng := AppButton.make("New game", &"DestructiveButton", "rotate-ccw")
	ng.pressed.connect(func() -> void: new_game_requested.emit())
	game.add_child(ng)

	_account_box = section("Account & cloud")
	_account_box.add_child(AccountSection.new())

	var prefs := section("Preferences")
	var hap := AppToggle.new().setup("Haptic feedback", Settings.haptics, "vibrate")
	hap.toggled.connect(func(v: bool) -> void: Settings.set_value("haptics", v))
	prefs.add_child(hap)
	var tour := AppButton.make("Replay the guided tour", &"", "map")
	tour.pressed.connect(func() -> void: tour_requested.emit())
	prefs.add_child(tour)
	var rm := AppToggle.new().setup("Reduce motion", Settings.reduce_motion, "sparkles")
	rm.toggled.connect(func(v: bool) -> void: Settings.set_value("reduce_motion", v))
	prefs.add_child(rm)

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
