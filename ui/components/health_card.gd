class_name HealthCard
extends PanelContainer
## "Nation health": overall status pill plus the top three things to do.
## Each suggestion is tappable and opens the page where it can be fixed.

signal page_requested(page: String)

var _status: Label
var _list: VBoxContainer
var _goal: ListRow


func _ready() -> void:
	theme_type_variation = &"GroupPanel"
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", DS.S3)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", DS.S2)
	col.add_child(head)
	var t := Label.new()
	t.theme_type_variation = &"Headline"
	t.text = "Nation health"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_status = Label.new()
	_status.theme_type_variation = &"Subhead"
	head.add_child(_status)
	_goal = ListRow.new()
	_goal.visible = false
	col.add_child(_goal)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 2)
	col.add_child(_list)
	refresh()


func refresh() -> void:
	var c := Game.me()
	if c == null or _list == null:
		return
	var h := Advisor.health(c)
	var color: Color = [DS.RED, DS.ORANGE, DS.GREEN][h]
	_status.text = Advisor.HEALTH_TEXT[h]
	_status.add_theme_color_override(&"font_color", color)
	var chg: Dictionary = Challenges.get_by_id(str(Game.challenge.get("id", "")))
	_goal.visible = not chg.is_empty()
	if not chg.is_empty():
		var st := str(Game.challenge.get("state", "active"))
		_goal.setup("Challenge: " + str(chg.title), Challenges.progress_text(chg) if st == "active"
			else ("Completed. Well done!" if st == "won" else "Missed this time. Keep governing."))
		_goal.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_goal.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_goal.set_leading(ListRow.icon_tile(str(chg.icon), DS.GOLD if st != "lost" else DS.TEXT_3))
	for ch in _list.get_children():
		ch.queue_free()
	for a in Advisor.advice(c).slice(0, 3):
		var row := ListRow.new().setup(str(a.title), str(a.detail))
		row.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		row.title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var tint: Color = [DS.ACCENT, DS.ORANGE, DS.RED][int(a.level)]
		row.set_leading(ListRow.icon_tile(str(a.icon), tint))
		row.tapped.connect(func() -> void: page_requested.emit(str(a.page)))
		_list.add_child(row)
