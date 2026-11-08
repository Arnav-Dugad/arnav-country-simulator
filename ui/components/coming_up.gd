class_name ComingUp
extends PanelContainer
## "Coming up": the next few things on the calendar, soonest first: the
## election, the cabinet meeting, projects and wonders finishing, plants and
## mines opening, world talks. Tap a row to go where it lives.

signal page_requested(page: String)

var _list: VBoxContainer


func _init() -> void:
	theme_type_variation = &"GroupPanel"
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", DS.S2)
	add_child(v)
	var h := Label.new()
	h.theme_type_variation = &"Headline"
	h.text = "Coming up"
	v.add_child(h)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	v.add_child(_list)


## [months away, title, icon, colour, page]
static func items() -> Array:
	var out: Array = []
	if not Game.has_game() or Game.me() == null:
		return out
	var c := Game.me()
	if Government.has_elections(Game.player):
		var ml := Game.politics.months_left()
		out.append([ml, "Election %d" % Game.politics.next_year(), "vote", DS.GOLD, "economy"])
	if Game.dip.has("meet"):
		var mm := maxi(Meeting.EVERY - (Game.months_played - int(Meeting.st().last)), 0)
		out.append([mm, "Cabinet meeting", "users", DS.ACCENT, "laws"])
	for id in c.projects:
		if Projects.is_building(c, str(id)):
			var p := Projects.by_id(str(id))
			var left := roundi((1.0 - Projects.progress(c, str(id))) * float(p.get("months", 12)))
			out.append([left, "%s finished" % str(p.get("title", id)), str(p.get("icon", "hammer")), DS.ORANGE, "build"])
	if Game.dip.has("won_me") and not Wonders.mine().is_empty():
		var w: Dictionary = Wonders.mine()
		out.append([roundi((1.0 - Wonders.progress()) * float(Wonders.ALL[str(w.id)].months)), "%s complete" % str(Wonders.ALL[str(w.id)].title), "landmark", DS.GOLD, "build"])
	if Game.dip.has("water"):
		var ws := Water.st()
		if int(ws.desal_build) >= 0:
			out.append([Economy.WAT_DESAL_MONTHS - (Game.months_played - int(ws.desal_build)), "Desalination plant opens", "droplets", DS.TEAL, "diplomacy"])
		if not (ws.my_dam as Dictionary).is_empty():
			out.append([Economy.WAT_DAM_MONTHS - (Game.months_played - int(ws.my_dam.start)), "Mega-dam opens", "waves", DS.TEAL, "diplomacy"])
	if Game.dip.has("min"):
		for m in Minerals.st().build:
			out.append([Economy.MIN_EXPAND_MONTHS - (Game.months_played - int(Minerals.st().build[m])), "New %s mines open" % str(Minerals.ALL[m].title).to_lower(), "pickaxe", DS.GOLD, "industries"])
	if Game.dip.has("nuke") and Nuclear.building():
		out.append([roundi((1.0 - Nuclear.progress()) * float(Nuclear.st().prog.months)), "Nuclear programme complete", "atom", DS.RED, "diplomacy"])
	# The world's calendar.
	var cop_year := Game.year if Game.year % 2 == 1 and Game.month <= 11 else (Game.year + (1 if Game.year % 2 == 0 else 2))
	out.append([(cop_year - Game.year) * 12 + (11 - Game.month), "UN climate summit (COP)", "leaf", DS.GREEN, "diplomacy"])
	var to_sep := posmod(9 - Game.month, 12)
	out.append([to_sep, "UN General Assembly", "landmark", DS.ACCENT, "diplomacy"])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return out


func refresh() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	var its := items()
	for it in its.slice(0, 5):
		var m := int(it[0])
		var when := "This month" if m <= 0 else ("Next month" if m == 1 else ("In %d months" % m if m < 24 else "In %d years" % (m / 12)))
		var row := ListRow.new().setup(str(it[1]), when)
		row.set_leading(ListRow.icon_tile(str(it[2]), it[3]))
		var page := str(it[4])
		row.tapped.connect(func() -> void: page_requested.emit(page))
		_list.add_child(row)
	visible = not its.is_empty()
