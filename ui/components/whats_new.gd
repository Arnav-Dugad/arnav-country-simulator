class_name WhatsNew
extends RefCounted
## "What's new" after an update: the highlights of every version since the one
## you last opened, read straight from the CHANGELOG (CI copies CHANGELOG.md to
## data/changelog.txt for the APK, since *.md files are not exported).

const MAX_ITEMS := 5
const MAX_CHARS := 150


static func _text() -> String:
	for p in ["res://data/changelog.txt", "res://CHANGELOG.md"]:
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_string(p)
	return ""


## [[version, [bullet, …]], …] newest first, for versions in (after, upto].
## after = "" means just the `upto` version itself.
static func sections(after: String, upto: String) -> Array:
	var out: Array = []
	var cur: Array = []
	for raw in _text().replace("\r", "").split("\n"):
		var l := raw.strip_edges(false, true)
		if l.begins_with("## ["):
			var v := l.get_slice("[", 1).get_slice("]", 0)
			var keep := not Updater.is_newer(v, upto) and (Updater.is_newer(v, after) if after != "" else v == upto)
			cur = [v, []] if keep else []
			if keep:
				out.append(cur)
		elif not cur.is_empty() and l.begins_with("- "):
			(cur[1] as Array).append(_clean(l.substr(2)))
	return out


static func _clean(s: String) -> String:
	s = s.replace("**", "").replace("`", "").replace("*", "").strip_edges()
	if s.length() > MAX_CHARS:
		var cut := s.left(MAX_CHARS)
		var stop := cut.rfind(". ")
		s = (cut.left(stop + 1) if stop > 60 else cut.left(cut.rfind(" ")) + "…")
	return s


## Shows the card when the app was updated since it was last opened. A fresh
## install just remembers the version.
static func maybe_show(parent: Node) -> void:
	var now := Updater.current_version()
	var seen := str(Settings.get_value("seen_version", ""))
	if seen == now:
		return
	Settings.set_value("seen_version", now)
	if seen == "" and not Settings.tutorial_done:
		return
	show(parent, seen, now)


static func show(parent: Node, after: String, upto: String) -> void:
	var secs := sections(after, upto)
	var items: Array = []
	for s in secs:
		for b in s[1]:
			if items.size() < MAX_ITEMS:
				items.append(b)
	if items.is_empty():
		return
	var m := ModalCard.new()
	parent.add_child(m)
	m.header("sparkles", DS.ACCENT, "Version %s" % upto, "What's new")
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", DS.S2)
	m.content.add_child(list)
	for t in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", DS.S2)
		var dot := Label.new()
		dot.theme_type_variation = &"Body"
		dot.text = "•"
		dot.add_theme_color_override(&"font_color", DS.ACCENT)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
		var l := Label.new()
		l.theme_type_variation = &"Footnote"
		l.text = str(t)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(60, 0)
		row.add_child(l)
		list.add_child(row)
	if secs.size() > 1:
		m.body("Plus more in %d earlier %s." % [secs.size() - 1, "update" if secs.size() == 2 else "updates"])
	m.choice("Let's go", "", &"PrimaryButton", m.dismiss)
