class_name AchievementsPage
extends SheetPage
## Gallery of achievements (persist across games).

var _grid: VBoxContainer
var _summary: Label


func _init() -> void:
	super._init()
	title = "Achievements"
	open_at = BottomSheet.Snap.FULL


func _build() -> void:
	_summary = note("")
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override(&"separation", 2)
	add_child(_grid)


func refresh() -> void:
	_summary.text = "%d of %d unlocked. Achievements carry over between games." % [
		Achievements.count(), Achievements.ALL.size()]
	for ch in _grid.get_children():
		ch.queue_free()
	var items := Achievements.ALL.duplicate()
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(Achievements.has(a.id)) > int(Achievements.has(b.id)))
	for a in items:
		var got := Achievements.has(a.id)
		var row := ListRow.new().setup(str(a.title), str(a.desc), "Unlocked" if got else "")
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.trailing_label.theme_type_variation = &"BadgeLabel"
		var tile := ListRow.icon_tile(str(a.icon) if got else "lock", DS.GOLD if got else Color(1, 1, 1, 0.18))
		row.set_leading(tile)
		row.modulate.a = 1.0 if got else 0.62
		_grid.add_child(row)
