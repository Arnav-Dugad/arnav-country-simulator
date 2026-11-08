class_name WeeklyBoard
extends VBoxContainer
## The weekly challenge's top 10, loaded from Firestore (see Firebase.top_weekly).
## Shows a calm placeholder while loading and a short note when offline.

var week := ""


func _ready() -> void:
	add_theme_constant_override(&"separation", 2)
	_note("Loading the leaderboard…")
	_load()


func _note(t: String) -> void:
	for ch in get_children():
		ch.queue_free()
	var l := Label.new()
	l.theme_type_variation = &"Caption"
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	add_child(l)


func _load() -> void:
	if not Firebase.enabled():
		_note("The leaderboard needs an internet connection.")
		return
	var r: Dictionary = await Firebase.top_weekly(week if week != "" else Weekly.week_id(), 10)
	if not is_inside_tree():
		return
	if not r.ok:
		_note("The leaderboard isn't available right now.")
		return
	var rows: Array = r.data
	if rows.is_empty():
		_note("No scores yet this week. Be the first!")
		return
	for ch in get_children():
		ch.queue_free()
	for k in rows.size():
		var e: Dictionary = rows[k]
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S2)
		add_child(row)
		var rank := Label.new()
		rank.theme_type_variation = &"StatSmall"
		rank.text = "%d" % (k + 1)
		rank.custom_minimum_size = Vector2(22, 0)
		rank.add_theme_color_override(&"font_color", DS.GOLD if k < 3 else DS.TEXT_2)
		row.add_child(rank)
		var i := World.index_of(str(e.country))
		if i >= 0:
			row.add_child(Flag.new().show_country(i, 14.0))
		var n := Label.new()
		n.theme_type_variation = &"Subhead"
		n.text = str(e.name) + ("  (you)" if bool(e.me) else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		n.custom_minimum_size = Vector2(40, 0)
		if bool(e.me):
			n.add_theme_color_override(&"font_color", DS.ACCENT_SOFT)
		row.add_child(n)
		var s := Label.new()
		s.theme_type_variation = &"StatSmall"
		s.text = "%s  %d" % [str(e.grade), roundi(float(e.score))]
		row.add_child(s)
