extends Node
## Layout test: on the narrowest supported phone (390 pt wide, e.g. 1080x2400),
## no sheet page may need more width than the sheet offers. Played as the USA so
## money values are at their longest ("$1.6T").
## Run: godot --headless --path . res://tools/layout_test.tscn

const VIEW_W := 390.0


func _ready() -> void:
	get_window().size = Vector2i(390, 866)
	SheetPage.unfold_all = true
	Game.new_game(World.index_of("USA"), 1)
	var game: Node = load("res://ui/screens/game.tscn").instantiate()
	add_child(game)
	await get_tree().create_timer(0.5).timeout
	# Usable width inside a sheet: screen minus side insets and the glass padding.
	var sheet: BottomSheet = game.sheet
	var pad: StyleBox = sheet.panel.get_theme_stylebox(&"panel")
	var avail := VIEW_W - BottomSheet.SIDE_INSET * 2.0 - pad.content_margin_left - pad.content_margin_right
	var fails := 0
	for scale in [0.8, 0.92, 1.18]:
		Settings.text_scale = scale
		Settings._apply_text_scale()
		await get_tree().process_frame
		print("-- text size %d%%" % int(scale * 100))
		fails += await _check_pages(game, avail)
	Settings.text_scale = Settings.TEXT_DEFAULT
	Settings._apply_text_scale()
	var top_w: float = game.top_bar.get_combined_minimum_size().x
	var dock_w: float = game.dock.get_combined_minimum_size().x
	for pair in [["top bar", top_w], ["dock", dock_w]]:
		var ok2: bool = float(pair[1]) <= VIEW_W - 24.0
		fails += 0 if ok2 else 1
		print("%s  %-13s needs %.0f pt" % ["PASS" if ok2 else "FAIL", pair[0], pair[1]])
	print("LAYOUT TEST %s (%d failures)" % ["OK" if fails == 0 else "FAILED", fails])
	get_tree().quit()


func _check_pages(game: Node, avail: float) -> int:
	var fails := 0
	for page in ["economy", "budget", "laws", "diplomacy", "events", "settings", "store", "achievements", "country"]:
		if page == "country":
			game._open_country(World.index_of("CHN"), false)
		else:
			game.open_page(page)
		await get_tree().process_frame
		await get_tree().process_frame
		var w: float = game._pages[page].get_combined_minimum_size().x
		var ok := w <= avail + 0.5
		fails += 0 if ok else 1
		print("%s  %-13s needs %.0f pt (sheet offers %.0f)" % ["PASS" if ok else "FAIL", page, w, avail])
		if not ok:
			var leaves: Array = []
			_leaves(game._pages[page], leaves)
			leaves.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
			for l in leaves.slice(0, 4):
				print("        %d pt  %s  \"%s\"" % l)
	return fails


func _leaves(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			if c is Label or c is Button:
				out.append([int((c as Control).get_combined_minimum_size().x), c.get_class(), str(c.get("text")).substr(0, 36)])
			_leaves(c, out)
