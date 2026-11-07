extends SceneTree
## Rasterises assets/branding/icon.svg into every Android launcher size, including
## adaptive-icon layers (foreground / background / monochrome) and the store icon.
## Run:  godot --headless --path . --script res://tools/export_icons.gd

const SRC := "res://assets/branding/icon.svg"
const OUT := "res://assets/branding/"
const MIPMAP_OUT := "res://assets/branding/android_res/"  # .gdignore'd, full mipmap set
const DENSITIES := {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


func _init() -> void:
	var full := FileAccess.get_file_as_string(SRC)
	var lines := full.split("\n")
	var bg_lines: PackedStringArray = []
	var body_lines: PackedStringArray = []
	var defs_end := -1
	for i in lines.size():
		if lines[i].strip_edges() == "</defs>":
			defs_end = i
	var header := "\n".join(lines.slice(0, defs_end + 1))
	for i in range(defs_end + 1, lines.size()):
		var l := lines[i]
		if l.find("url(#bg)") >= 0 or l.find("url(#bgGlow)") >= 0:
			bg_lines.append(l)
		elif l.strip_edges() != "</svg>":
			body_lines.append(l)
	# Adaptive foreground: artwork scaled into the 66/108 safe zone.
	var fg := header + "\n<g transform=\"translate(512 512) scale(0.64) translate(-512 -530)\">\n" \
			+ "\n".join(body_lines) + "\n</g>\n</svg>\n"
	var bg := header + "\n" + "\n".join(bg_lines) + "\n</svg>\n"
	var mono := """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<g transform="translate(512 512) scale(0.64) translate(-512 -530)" fill="none" stroke="#FFFFFF" stroke-linecap="round">
<circle cx="512" cy="530" r="270" stroke-width="40"/>
<ellipse cx="512" cy="530" rx="120" ry="270" stroke-width="26"/>
<line x1="242" y1="530" x2="782" y2="530" stroke-width="26"/>
<g transform="translate(512 530) rotate(-16)"><path d="M 410 0 A 410 118 0 0 1 -410 0" stroke-width="30"/></g>
</g></svg>"""

	_save(full, 512, OUT + "icon_512.png")
	_save(full, 192, OUT + "icon_192.png")
	_save(full, 256, OUT + "logo.png")
	_save(fg, 432, OUT + "adaptive_foreground_432.png")
	_save(bg, 432, OUT + "adaptive_background_432.png")
	_save(mono, 432, OUT + "adaptive_monochrome_432.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MIPMAP_OUT))
	var f := FileAccess.open(MIPMAP_OUT + ".gdignore", FileAccess.WRITE)
	f.close()
	for d in DENSITIES:
		var dir := MIPMAP_OUT + "mipmap-%s/" % d
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var k: float = DENSITIES[d]
		_save(full, int(48 * k), dir + "ic_launcher.png")
		_save(fg, int(108 * k), dir + "ic_launcher_foreground.png")
		_save(bg, int(108 * k), dir + "ic_launcher_background.png")
		_save(mono, int(108 * k), dir + "ic_launcher_monochrome.png")
	_save(full, 512, MIPMAP_OUT + "playstore_512.png")
	print("export_icons: done")
	quit()


func _save(svg: String, px: int, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, px / 1024.0)
	if err != OK:
		push_error("SVG rasterise failed for %s" % path)
		return
	img.save_png(path)
