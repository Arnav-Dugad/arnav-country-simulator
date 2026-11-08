class_name AchievementsPage
extends SheetPage
## Hall of fame: your statesman rank, achievements by category and tier, and the
## online leaderboards (weekly challenge, all-time legends, your friends).

var _tab := 0          # 0 achievements, 1 leaderboards
var _cat := "All"
var _board := 0        # 0 all-time legacy, 1 achievement points, 2 friends, 3 weekly
var _box: VBoxContainer


func _init() -> void:
	super._init()
	title = "Hall of fame"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	var tabs := SegmentedControl.new().setup(["Achievements", "Leaderboards"], [], 0)
	tabs.plain = true
	tabs.compact = false
	tabs.fill = true
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.changed.connect(func(i: int) -> void:
		_tab = i
		Haptics.select()
		refresh())
	add_child(tabs)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", DS.S4)
	add_child(_box)


func refresh() -> void:
	for ch in _box.get_children():
		ch.queue_free()
	if _tab == 0:
		_achievements()
	else:
		_leaderboards()


# ------------------------------------------------------------- achievements ---
func _achievements() -> void:
	var rk: Array = Achievements.rank()
	var pts := Achievements.points()
	var card := PanelContainer.new()
	card.theme_type_variation = &"GroupPanel"
	_box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S2)
	card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", DS.S3)
	v.add_child(h)
	h.add_child(ListRow.icon_tile("crown", DS.GOLD))
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var t := Label.new()
	t.theme_type_variation = &"Title2"
	t.text = str(rk[0])
	col.add_child(t)
	var c := Label.new()
	c.theme_type_variation = &"Caption"
	c.text = "%d points  ·  %d of %d unlocked" % [pts, Achievements.count(), Achievements.total()]
	col.add_child(c)
	var nxt := int(rk[1])
	if nxt > 0:
		var frac := float(pts - int(rk[2])) / float(maxi(nxt - int(rk[2]), 1))
		v.add_child(meter(frac, 0.0, DS.GOLD, 6.0))
		note("%d points to the next rank." % (nxt - pts), v)
	else:
		note("The highest rank there is.", v)
	# Category filter.
	var cats := ["All"]
	for a in Achievements.all_list():
		if not cats.has(str(a.cat)):
			cats.append(str(a.cat))
	var sc := TouchScroll.make_horizontal()
	sc.custom_minimum_size = Vector2(0, 40)
	_box.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	sc.add_child(row)
	for k in cats:
		var cat := str(k)
		var b := AppButton.make(cat, &"ChipSelected" if cat == _cat else &"Chip")
		b.pressed.connect(func() -> void:
			_cat = cat
			Haptics.select()
			refresh())
		row.add_child(b)
	# The list: unlocked first, then by tier.
	var items: Array = Achievements.all_list().filter(func(a: Dictionary) -> bool: return _cat == "All" or str(a.cat) == _cat)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ga := Achievements.has(str(a.id))
		var gb := Achievements.has(str(b.id))
		if ga != gb:
			return ga
		return int(a.tier) < int(b.tier))
	var box := section("", _box)
	for a in items:
		var got := Achievements.has(str(a.id))
		var tier := int(a.tier)
		var tcol: Color = [DS.TEXT_3, Color("c98a4b"), Color("c7ccd6"), DS.GOLD, Color("a6e3ff")][tier]
		var rw := ListRow.new().setup(str(a.title), str(a.desc), "%s" % Achievements.TIER_NAMES[tier], "+%d" % int(Achievements.TIER_POINTS[tier]))
		rw.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rw.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		rw.trailing_label.theme_type_variation = &"Caption"
		rw.trailing_label.add_theme_color_override(&"font_color", tcol)
		rw.set_leading(ListRow.icon_tile(str(a.icon) if got else "lock", tcol if got else Color(1, 1, 1, 0.18)))
		rw.modulate.a = 1.0 if got else 0.6
		box.add_child(rw)


# ------------------------------------------------------------- leaderboards ---
func _leaderboards() -> void:
	var seg := SegmentedControl.new().setup(["Legacy", "Points", "Friends", "Weekly"], [], _board)
	seg.fill = true
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seg.changed.connect(func(i: int) -> void:
		_board = i
		Haptics.select()
		refresh())
	_box.add_child(seg)
	if not Firebase.enabled():
		note("Leaderboards need an internet connection.", _box)
		return
	if not Firebase.signed_in():
		note("Sign in (or back up as a guest) in Settings › Account & cloud to appear on the leaderboards.", _box)
	if _board == 3:
		var wb := section("This week's challenge", _box)
		var board := WeeklyBoard.new()
		wb.add_child(board)
		note("Play the weekly challenge from the home screen to post a score.", wb)
		return
	# Your card.
	var me := section("You", _box)
	var st := Career.stats()
	var rk: Array = Achievements.rank()
	var you := ListRow.new().setup(Weekly.board_name(), "%s  ·  %d points  ·  best legacy %s" % [str(rk[0]), Achievements.points(),
		str(st.best_grade) if str(st.best_grade) != "" else "none yet"])
	you.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	you.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	you.set_leading(ListRow.icon_tile("user", DS.ACCENT))
	me.add_child(you)
	if Firebase.signed_in():
		var code := Firebase.friend_code()
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override(&"separation", DS.S2)
		me.add_child(cr)
		var cl := Label.new()
		cl.theme_type_variation = &"Footnote"
		cl.text = "Your friend code: %s" % code
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(cl)
		var copy := AppButton.make("Copy", &"Chip", "copy")
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(code)
			copy.text = "Copied"
			Haptics.success())
		cr.add_child(copy)
		var pub := AppButton.make("Update my entry", &"GhostButton", "cloud-upload")
		pub.pressed.connect(func() -> void:
			pub.disabled = true
			await Career.publish()
			Haptics.success()
			refresh())
		me.add_child(pub)
	if _board == 2:
		_friends_editor()
	var list := section(["All-time legacy", "Achievement points", "Friends", ""][_board], _box)
	var loading := note("Loading…", list)
	var codes: Array = []
	if _board == 2:
		codes = Settings.friends.duplicate()
		if Firebase.signed_in():
			codes.append(Firebase.friend_code())
		if codes.size() <= 1 and Settings.friends.is_empty():
			loading.text = "Add a friend's code above to compare your careers."
			return
	var r: Dictionary = await Firebase.top_legends("points" if _board == 1 else "score", 25, codes)
	if not is_instance_valid(list) or not is_inside_tree():
		return
	loading.queue_free()
	if not r.ok:
		note("The leaderboard isn't available right now.", list)
		return
	var rows: Array = r.data
	if rows.is_empty():
		note("No one here yet. Finish a game to be the first!", list)
		return
	for k in rows.size():
		var e: Dictionary = rows[k]
		var line := ListRow.new().setup("%d. %s%s" % [k + 1, str(e.name), "  (you)" if bool(e.me) else ""],
			"%s  ·  %s" % [str(e.rank) if str(e.rank) != "" else "Leader", World.map.names[World.index_of(str(e.country))] if World.index_of(str(e.country)) >= 0 else ""],
			(str(e.grade) if _board != 1 else str(int(e.points))), ("legacy" if _board != 1 else "points"))
		line.trailing_label.add_theme_color_override(&"font_color", DS.GOLD if k < 3 else DS.TEXT)
		var ci := World.index_of(str(e.country))
		if ci >= 0:
			line.set_leading(Flag.new().show_country(ci, 22.0))
		list.add_child(line)


func _friends_editor() -> void:
	var box := section("Friends", _box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", DS.S2)
	box.add_child(row)
	var input := LineEdit.new()
	input.placeholder_text = "Friend code (6 letters)"
	input.max_length = 8
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	var add := AppButton.make("Add", &"PrimaryButton", "user-plus")
	add.pressed.connect(func() -> void:
		var code := input.text.strip_edges().to_upper()
		if code.length() >= 4 and not Settings.friends.has(code) and code != Firebase.friend_code():
			var f: Array = Settings.friends.duplicate()
			f.append(code)
			Settings.set_value("friends", f.slice(-9))
			Haptics.success()
		refresh())
	row.add_child(add)
	for code in Settings.friends:
		var fr := HBoxContainer.new()
		box.add_child(fr)
		var l := Label.new()
		l.theme_type_variation = &"Footnote"
		l.text = str(code)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fr.add_child(l)
		var rm := AppButton.make("", &"IconButton", "x")
		var cc := str(code)
		rm.pressed.connect(func() -> void:
			var f: Array = Settings.friends.duplicate()
			f.erase(cc)
			Settings.set_value("friends", f)
			refresh())
		fr.add_child(rm)
	note("Share your code with friends; add theirs to see how your careers compare. Up to 9 friends.", box)
