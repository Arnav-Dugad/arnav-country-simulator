class_name EventsPage
extends SheetPage
## Pending decision (if any) and a log of everything that has happened.

signal open_pending

var _pending_box: VBoxContainer
var _log: VBoxContainer
var _news: VBoxContainer


func _init() -> void:
	super._init()
	title = "Events"


func _build() -> void:
	_pending_box = VBoxContainer.new()
	add_child(_pending_box)
	_news = section("World news")
	_log = section("Your history")


func refresh() -> void:
	for ch in _pending_box.get_children():
		ch.queue_free()
	if not Game.pending_event.is_empty():
		var b := AppButton.make("Decide: " + str(Game.pending_event.title), &"PrimaryButton", "alert")
		b.pressed.connect(func() -> void: open_pending.emit())
		_pending_box.add_child(b)
	for ch in _news.get_children():
		ch.queue_free()
	if Game.news.is_empty():
		note("News from around the world will appear here.", _news)
	for item in Game.news.slice(0, 12):
		var row := ListRow.new().setup(str(item.text), "", str(item.date))
		row.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.title_label.theme_type_variation = &"Body"
		row.trailing_label.theme_type_variation = &"Caption"
		row.set_leading(Flag.new().show_country(World.index_of(str(item.country)), 20.0))
		_news.add_child(row)
	for ch in _log.get_children():
		ch.queue_free()
	var e_next := Game.months_to_election
	var nxt := ListRow.new().setup("Next election", "In %d years %d months" % [e_next / 12, e_next % 12],
		DS.pct(Game.me().approval, 0), "approval")
	nxt.set_leading(ListRow.icon_tile("vote", DS.GOLD))
	_log.add_child(nxt)
	if Game.event_log.is_empty():
		note("Nothing has happened yet. Events appear as months pass.", _log)
		return
	for e in Game.event_log:
		var ev := GameEvents.by_id(str(e.id))
		var row := ListRow.new().setup(str(e.title), "You chose: " + str(e.choice), str(e.date))
		row.trailing_label.theme_type_variation = &"Caption"
		var icon_name: String = str(ev.get("icon", "vote")) if not ev.is_empty() else "vote"
		var tint := GameEvents.tint(ev.get("tint", "gold")) if not ev.is_empty() else DS.GOLD
		row.set_leading(ListRow.icon_tile(icon_name, tint))
		_log.add_child(row)
