class_name EventsPage
extends SheetPage
## Pending decision (if any) and a log of everything that has happened.

signal open_pending

var _pending_box: VBoxContainer
var _log: VBoxContainer


func _init() -> void:
	super._init()
	title = "Events"


func _build() -> void:
	_pending_box = VBoxContainer.new()
	add_child(_pending_box)
	_log = section("History")


func refresh() -> void:
	for ch in _pending_box.get_children():
		ch.queue_free()
	if not Game.pending_event.is_empty():
		var b := AppButton.make("Decide: " + str(Game.pending_event.title), &"PrimaryButton", "alert")
		b.pressed.connect(func() -> void: open_pending.emit())
		_pending_box.add_child(b)
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
