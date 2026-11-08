extends Control
## Home: the world drifts behind a resume card for your last game, your other
## saves, and a way to start fresh.

const GAME := "res://ui/screens/game.tscn"
const PICKER := "res://ui/screens/country_picker.tscn"

var _map: MapView
var _col: VBoxContainer
var _card: GlassPanel


func _ready() -> void:
	add_child(OceanBackground.new())
	_map = MapView.new()
	_map.interactive = false
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_map)
	add_child(_scrim())

	_card = GlassPanel.new()
	_card.theme_type_variation = &"GlassSheet"
	_card.tint = DS.GLASS_TINT_STRONG
	add_child(_card)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override(&"separation", DS.S4)
	_card.add_child(_col)
	_build()
	resized.connect(_layout)
	Screen.insets_changed.connect(_layout)
	_layout.call_deferred()
	get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	Audio.music_start("menu")
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_inside_tree():
			WhatsNew.maybe_show(self))


func _process(delta: float) -> void:
	_map.pan_by(Vector2(-7.0 * delta, 0))


func _build() -> void:
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override(&"separation", DS.S3)
	_col.add_child(brand)
	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(44, 44)
	brand.add_child(logo)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(titles)
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = "Arnav Country Simulator"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(80, 0)
	titles.add_child(t)
	var sub := Label.new()
	sub.theme_type_variation = &"Footnote"
	sub.text = "Welcome back, leader."
	titles.add_child(sub)
	var gear := AppButton.make("", &"IconButton", "settings")
	gear.custom_minimum_size = Vector2(DS.MIN_TOUCH, DS.MIN_TOUCH)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(_open_settings)
	brand.add_child(gear)

	var last := Settings.last_slot
	var sm := SaveManager.summary(last)
	if sm.is_empty():
		for s in range(1, SaveManager.SLOTS + 1):
			sm = SaveManager.summary(s)
			if not sm.is_empty():
				last = s
				break
	if not sm.is_empty():
		_col.add_child(_resume_card(last, sm))
	var others := VBoxContainer.new()
	others.add_theme_constant_override(&"separation", 2)
	for s in range(1, SaveManager.SLOTS + 1):
		if s == last:
			continue
		var o := SaveManager.summary(s)
		if o.is_empty():
			continue
		var row := ListRow.new().setup(str(o.get("name", "")), "%s  ·  approval %s%%" % [o.get("date", ""),
			String.num(float(o.get("approval", 0.0)), 0)], "Slot %d" % s)
		var idx := World.index_of(str(o.get("country", "")))
		row.set_leading(Flag.new().show_country(idx, 22.0))
		row.tapped.connect(_load.bind(s))
		others.add_child(row)
	if others.get_child_count() > 0:
		var h := Label.new()
		h.theme_type_variation = &"Overline"
		h.text = "OTHER SAVES"
		_col.add_child(h)
		_col.add_child(others)
	else:
		others.free()
	var career := Career.line()
	if career != "":
		var cl := ListRow.new().setup("Your career", career)
		cl.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		cl.set_leading(ListRow.icon_tile("crown", DS.GOLD))
		_col.add_child(cl)
	var new_game := AppButton.make("Lead a new nation", &"" if not sm.is_empty() else &"PrimaryButton", "globe")
	new_game.custom_minimum_size = Vector2(0, 50)
	new_game.pressed.connect(func() -> void:
		Game.end_session()
		SaveManager.active_slot = _free_slot()
		Router.goto(PICKER))
	_col.add_child(new_game)
	if not sm.is_empty():
		var manage := AppButton.make("Manage saves", &"GhostButton", "folder")
		manage.pressed.connect(_manage_saves)
		_col.add_child(manage)


func _resume_card(slot: int, sm: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.theme_type_variation = &"GroupPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S3)
	box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(top)
	var idx := World.index_of(str(sm.get("country", "")))
	top.add_child(Flag.new().show_country(idx, 34.0))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override(&"separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var o := Label.new()
	o.theme_type_variation = &"Overline"
	o.text = "CONTINUE"
	tv.add_child(o)
	var n := Label.new()
	n.theme_type_variation = &"Title2"
	n.text = str(sm.get("name", ""))
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(n)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", DS.S2)
	v.add_child(stats)
	for pair in [["DATE", _pretty_date(str(sm.get("date", "")))], ["APPROVAL", DS.pct(clampf(float(sm.get("approval", 0.0)), 0.0, 100.0), 0)],
			["GDP", DS.money(float(sm.get("gdp", 0.0)))]]:
		var tile := PanelContainer.new()
		tile.theme_type_variation = &"TilePanel"
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tvb := VBoxContainer.new()
		tvb.add_theme_constant_override(&"separation", 2)
		tile.add_child(tvb)
		var c := Label.new()
		c.theme_type_variation = &"Overline"
		c.text = pair[0]
		tvb.add_child(c)
		var val := Label.new()
		val.theme_type_variation = &"StatSmall"
		val.text = pair[1]
		val.clip_text = true                        # never widen the card
		val.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		val.custom_minimum_size = Vector2(30, 0)
		tvb.add_child(val)
		stats.add_child(tile)
	var go := AppButton.make("Continue", &"PrimaryButton", "play")
	go.custom_minimum_size = Vector2(0, 52)
	go.pressed.connect(_load.bind(slot))
	v.add_child(go)
	if idx >= 0:
		_map.set_player(idx)
		_map.frame_insets = Vector4(DS.S6, Screen.top + DS.S6, DS.S6, 470.0)
		_map.focus_country.call_deferred(idx, 0.01)
	return box


func _load(slot: int) -> void:
	if SaveManager.load_slot(slot):
		Haptics.success()
		Router.goto(GAME)
	else:
		Haptics.warning()


func _free_slot() -> int:
	for s in range(1, SaveManager.SLOTS + 1):
		if SaveManager.summary(s).is_empty():
			return s
	return Settings.last_slot


static func _pretty_date(mmyyyy: String) -> String:
	const NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var p := mmyyyy.split("/")
	if p.size() != 2:
		return mmyyyy
	return "%s %s" % [NAMES[clampi(int(p[0]) - 1, 0, 11)], p[1]]


func _scrim() -> Control:
	var g := Gradient.new()
	g.set_color(0, Color(DS.OCEAN_BOTTOM, 0.0))
	g.set_color(1, Color(DS.OCEAN_BOTTOM, 0.92))
	g.add_point(0.4, Color(DS.OCEAN_BOTTOM, 0.1))
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


## Settings from the main menu: the app-wide ones only (see SettingsPage.menu_mode),
## in the same glass bottom sheet the game uses.
var _sheet: BottomSheet


func _open_settings() -> void:
	Haptics.tap()
	if _sheet == null:
		_sheet = BottomSheet.new()
		_sheet.stops = [BottomSheet.Snap.HALF, BottomSheet.Snap.FULL]
		add_child(_sheet)
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S3)
		_sheet.header.add_child(row)
		var t := Label.new()
		t.theme_type_variation = &"Title2"
		t.text = "Settings"
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		var close := AppButton.make("", &"IconButton", "x")
		close.custom_minimum_size = Vector2(DS.MIN_TOUCH, DS.MIN_TOUCH)
		close.pressed.connect(_sheet.close)
		row.add_child(close)
		var scroll := TouchScroll.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_sheet.body.add_child(scroll)
		var page := SettingsPage.new()
		page.menu_mode = true
		scroll.add_child(page)
		_sheet.set_meta(&"page", page)
	(_sheet.get_meta(&"page") as SettingsPage).on_open()
	_sheet.open(BottomSheet.Snap.FULL)


func _layout() -> void:
	var w := minf(size.x - DS.S4 * 2.0, 440.0)
	_card.size = Vector2(w, 0)
	_card.size = Vector2(w, _card.get_combined_minimum_size().y)
	_card.position = Vector2((size.x - w) * 0.5, size.y - Screen.bottom - DS.S4 - _card.size.y)
	Screen.fit_card(_card, self)


# ------------------------------------------------------------- manage saves ---
func _manage_saves() -> void:
	var m := ModalCard.new()
	add_child(m)
	m.header("folder", DS.ACCENT, "Saves", "Your games")
	m.body("Tap a game to delete it%s." % (" from this phone and your cloud backup" if Firebase.enabled() and Firebase.signed_in() else ""))
	for s in range(1, SaveManager.SLOTS + 1):
		var o := SaveManager.summary(s)
		if o.is_empty():
			continue
		var detail := "Slot %d  ·  %s  ·  approval %s%%" % [s, _pretty_date(str(o.get("date", ""))),
			String.num(clampf(float(o.get("approval", 0.0)), 0.0, 100.0), 0)]
		if CloudSync.is_backed_up(s):
			detail += "  ·  backed up"
		m.choice("Delete %s" % str(o.get("name", "?")), detail, &"GhostButton", func() -> void:
			m.dismiss()
			_confirm_delete(s, o))
	m.choice("Done", "", &"GhostButton", m.dismiss)


func _confirm_delete(slot: int, o: Dictionary) -> void:
	var m := ModalCard.new()
	add_child(m)
	m.header("trash-2", DS.RED, "Delete save", "%s, %s" % [str(o.get("name", "?")), _pretty_date(str(o.get("date", "")))])
	m.body("This game will be gone for good%s. It can't be undone." % (", including its cloud backup" if Firebase.enabled() and Firebase.signed_in() else ""))
	m.choice("Delete", "", &"DestructiveButton", func() -> void:
		SaveManager.delete_slot(slot)
		if Settings.last_slot == slot:
			Settings.set_value("last_slot", 1)
		Haptics.warning()
		m.dismiss()
		_rebuild())
	m.choice("Keep it", "", &"GhostButton", m.dismiss)


func _rebuild() -> void:
	for ch in _col.get_children():
		ch.queue_free()
	await get_tree().process_frame
	_build()
	_layout()
