class_name DiplomacyPage
extends SheetPage
## Relations overview: allies, partners and rivals. Tap a country to open it.

signal country_requested(index: int)

var _summary: Label
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0


func _init() -> void:
	super._init()
	title = "Diplomacy"


func _build() -> void:
	_summary = note("")
	_filter = SegmentedControl.new().setup(["Friends", "Rivals", "Neighbours", "Partners"], [], 0)
	_filter.plain = true
	_filter.compact = false
	_filter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_filter.changed.connect(func(i: int) -> void:
		_mode = i
		refresh())
	add_child(_filter)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	add_child(_list)


func refresh() -> void:
	if not Game.has_game():
		return
	var d := Diplomacy.summary()
	_summary.text = "%d alliances  ·  %d trade deals  ·  %d sanctions on you  ·  aid sent %s" % [
		d.alliances, d.deals, d.sanctioned_by, DS.money(d.aid_total)]
	for ch in _list.get_children():
		ch.queue_free()
	var idx: Array[int] = []
	var neigh := World.map.neighbours[Game.player]
	for i in World.playable:
		if i == Game.player:
			continue
		match _mode:
			0:
				if Game.relations[i] >= 25.0:
					idx.append(i)
			1:
				if Game.relations[i] <= -15.0:
					idx.append(i)
			2:
				if i in neigh:
					idx.append(i)
			3:
				if Diplomacy.has_deal(i) or Diplomacy.has_alliance(i):
					idx.append(i)
	var asc := _mode == 1
	idx.sort_custom(func(a: int, b: int) -> bool:
		return Game.relations[a] < Game.relations[b] if asc else Game.relations[a] > Game.relations[b])
	for i in idx.slice(0, 40):
		var row := ListRow.new().setup(World.map.names[i], Diplomacy.status_text(i),
			Diplomacy.relation_text(Game.relations[i]), "%+.0f" % Game.relations[i])
		row.trailing_label.add_theme_color_override(&"font_color", Diplomacy.relation_color(Game.relations[i]))
		row.set_leading(Flag.new().show_country(i, 22.0))
		row.tapped.connect(func() -> void: country_requested.emit(i))
		_list.add_child(row)
	if idx.is_empty():
		note("Nobody here yet.", _list)
