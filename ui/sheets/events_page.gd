class_name EventsPage
extends SheetPage
## The Inbox: open decisions (with the time left before your cabinet decides),
## updates (headlines, laws, projects, achievements), world news and your history.
## Nothing here interrupts you; it waits until you look.

signal decision_requested(ev: Dictionary)
signal review_requested

var _decisions: VBoxContainer
var _updates: VBoxContainer
var _news: VBoxContainer
var _log: VBoxContainer
var _politics: VBoxContainer
var _story: VBoxContainer


func _init() -> void:
	super._init()
	title = "Inbox"


func _build() -> void:
	_decisions = section("Needs your decision")
	_politics = section("")
	_story = section("Your story")
	_updates = section("Updates")
	_news = section("World news")
	_log = section("Your history")


func on_open() -> void:
	refresh()
	Game.mark_feed_read()


func refresh() -> void:
	if not Game.has_game():
		return
	# Decisions
	for ch in _decisions.get_children():
		ch.queue_free()
	_decisions.get_parent().get_parent().visible = Game.director.has_open()
	for ev in Game.director.inbox:
		var left := Game.director.months_left(ev)
		var sub := "Critical: decide now" if bool(ev.get("critical", false)) else (
			"Your cabinet decides in %d %s" % [left, "month" if left == 1 else "months"] if left > 0 else "Your cabinet decides this month")
		var row := ListRow.new().setup(str(ev.title), sub, "Decide")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.add_theme_color_override(&"font_color", DS.ACCENT_SOFT)
		row.set_leading(ListRow.icon_tile(str(ev.icon), GameEvents.tint(str(ev.tint))))
		row.tapped.connect(func() -> void: decision_requested.emit(ev))
		_decisions.add_child(row)
	# Politics: next election / review
	for ch in _politics.get_children():
		ch.queue_free()
	var i := Game.player
	var gov := ListRow.new().setup(Government.system_name(i), Government.leader_display(i) + ("  ·  " + str(Settings.party_name) if str(Settings.party_name).strip_edges() != "" else ""), "")
	gov.set_leading(ListRow.icon_tile("landmark", DS.GOLD))
	_politics.add_child(gov)
	var m := Game.politics.months_left()
	if m > 0:
		var what := "Next election" if Government.has_elections(i) else "Next %s" % Government.review_name(i)
		var nxt := ListRow.new().setup(what, "In %d years %d months" % [m / 12, m % 12],
			DS.pct(Game.me().approval, 0), Government.support_word(i).to_lower())
		nxt.set_leading(ListRow.icon_tile("vote", DS.GOLD))
		_politics.add_child(nxt)
	# Story timeline
	for ch in _story.get_children():
		ch.queue_free()
	var story: Array = Game.dip.get("story", [])
	_story.get_parent().get_parent().visible = not story.is_empty()
	if not story.is_empty():
		_story.add_child(Timeline.new().build(story.slice(0, 8).map(func(it: Dictionary) -> Dictionary:
			var d := it.duplicate()
			d["tint"] = _tint(str(it.get("tint", "accent")))
			return d)))
	# Updates
	for ch in _updates.get_children():
		ch.queue_free()
	if Game.feed.is_empty():
		note("Headlines, new laws, finished projects and achievements will collect here.", _updates)
	for item in Game.feed.slice(0, 20):
		var row := ListRow.new().setup(str(item.text), "", str(item.date))
		_wrap(row)
		if str(item.get("face", "")) != "":
			row.set_leading(Photo.portrait(str(item.face), 36.0))
		else:
			row.set_leading(ListRow.icon_tile(str(item.icon), _tint(str(item.get("tint", "accent")))))
		if str(item.get("kind", "")) == "review":
			row.tapped.connect(func() -> void: review_requested.emit())
		if not bool(item.get("read", false)):
			row.title_label.add_theme_color_override(&"font_color", DS.TEXT)
			row.trailing_label.add_theme_color_override(&"font_color", DS.ACCENT_SOFT)
		_updates.add_child(row)
	# World news
	for ch in _news.get_children():
		ch.queue_free()
	if Game.news.is_empty():
		note("News about your neighbours, partners and the big economies will appear here.", _news)
	for item in Game.news.slice(0, 12):
		var row := ListRow.new().setup(str(item.text), "", str(item.date))
		_wrap(row)
		row.set_leading(Flag.new().show_country(World.index_of(str(item.country)), 20.0))
		_news.add_child(row)
	# History
	for ch in _log.get_children():
		ch.queue_free()
	if Game.event_log.is_empty():
		note("Nothing has happened yet. Your decisions will be listed here.", _log)
		return
	for e in Game.event_log.slice(0, 30):
		var ev := GameEvents.by_id(str(e.id))
		var who := "Cabinet chose: " if bool(e.get("cabinet", false)) else "You chose: "
		var row := ListRow.new().setup(str(e.title), who + str(e.choice), str(e.date))
		row.trailing_label.theme_type_variation = &"Caption"
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var icon_name: String = str(ev.get("icon", "vote")) if not ev.is_empty() else "vote"
		var tint := GameEvents.tint(ev.get("tint", "gold")) if not ev.is_empty() else DS.GOLD
		row.set_leading(ListRow.icon_tile(icon_name, tint))
		_log.add_child(row)


func _wrap(row: ListRow) -> void:
	row.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.title_label.theme_type_variation = &"Body"
	row.title_label.add_theme_color_override(&"font_color", DS.TEXT_2)
	row.trailing_label.theme_type_variation = &"Caption"


static func _tint(name: String) -> Color:
	return {"green": DS.GREEN, "orange": DS.ORANGE, "red": DS.RED, "gold": DS.GOLD, "teal": DS.TEAL,
		"purple": DS.PURPLE}.get(name, DS.ACCENT)
