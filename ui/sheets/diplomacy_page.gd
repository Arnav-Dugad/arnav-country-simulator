class_name DiplomacyPage
extends SheetPage
## Relations overview: allies, partners and rivals. Tap a country to open it.

signal country_requested(index: int)

var _summary: Label
var _ranks: GridContainer
var _filter: SegmentedControl
var _list: VBoxContainer
var _mode := 0


func _init() -> void:
	super._init()
	title = "World"


func _build() -> void:
	var rank_head := Label.new()
	rank_head.theme_type_variation = &"Overline"
	rank_head.text = "YOUR WORLD RANK"
	add_child(rank_head)
	_ranks = grid(self, 2)
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
	_fill_ranks()
	var d := Diplomacy.summary()
	var parts: PackedStringArray = ["%d %s" % [d.alliances, "ally" if d.alliances == 1 else "allies"],
		"%d trade %s" % [d.deals, "deal" if d.deals == 1 else "deals"]]
	if int(d.sanctioned_by) > 0:
		parts.append("%d %s on you" % [d.sanctioned_by, "sanction" if d.sanctioned_by == 1 else "sanctions"])
	if float(d.aid_total) > 0.0:
		parts.append("aid sent %s" % DS.money(d.aid_total))
	_summary.text = "  ·  ".join(parts) + ". Tap a country to talk trade, alliances or aid."
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


## Your world rank in four measures (among countries with data).
func _fill_ranks() -> void:
	for ch in _ranks.get_children():
		ch.queue_free()
	var specs := [["GDP", func(c: CountryState) -> float: return c.gdp],
		["Per person", func(c: CountryState) -> float: return c.gdp_per_capita()],
		["Happiness", func(c: CountryState) -> float: return c.happiness],
		["Stability", func(c: CountryState) -> float: return c.stability]]
	var me := Game.me()
	for sp in specs:
		var mine: float = sp[1].call(me)
		var rank := 1
		var total := 0
		for i in World.playable:
			var c: CountryState = Game.state(i)
			if c == null:
				continue
			total += 1
			if i != Game.player and float(sp[1].call(c)) > mine:
				rank += 1
		var t := StatTile.new().setup(str(sp[0]), func(_v: float) -> String: return "#%d" % rank, true)
		t.number.theme_type_variation = &"StatSmall"
		t.number.set_instant(rank)
		t.delta_label.text = "of %d" % total
		_ranks.add_child(t)
