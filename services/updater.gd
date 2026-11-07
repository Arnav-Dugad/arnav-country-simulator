extends CanvasLayer
## In-app updates from GitHub Releases.
## On launch (once a day) and from Settings → "Check for updates": fetch the latest
## release, compare its tag (vX.Y.Z) with application/config/version, and offer a
## glass update sheet with the release notes. "Update now" downloads the APK with a
## progress bar and hands it to the Android installer via the AcsUpdater plugin.
## Any failure falls back to opening the release page in the browser.

signal checked(result: Dictionary)

const REPO := "Arnav-Dugad/arnav-country-simulator"
const API := "https://api.github.com/repos/%s/releases/latest"
const DAY := 86400
const DOWNLOAD_DIR := "user://updates/"

var latest: Dictionary = {}
var _dl: HTTPRequest
var _modal: ModalCard
var _progress: ProgressBar
var _progress_label: Label
var _primary: AppButton


func _ready() -> void:
	layer = 110
	if OS.has_feature("editor") or OS.get_cmdline_user_args().size() > 0:
		return  # no automatic checks while developing
	if Time.get_unix_time_from_system() - Settings.last_update_check > DAY:
		_auto_check.call_deferred()


func _calm_screen() -> bool:
	var sc := get_tree().current_scene
	return sc != null and sc.scene_file_path in ["res://ui/screens/home.tscn", "res://ui/screens/game.tscn"]


func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _auto_check() -> void:
	await get_tree().create_timer(4.0).timeout  # let the app settle first
	# Never interrupt a first launch: wait until onboarding is done and the
	# player is on the home screen or in a game.
	while not Settings.onboarding_done or not _calm_screen():
		await get_tree().create_timer(3.0).timeout
	var r := await check()
	if r.get("update", false) and str(r.version) != Settings.skipped_version:
		show_sheet()


## Returns {ok, update: bool, version, notes, apk_url, page_url, error}.
func check() -> Dictionary:
	Settings.set_value("last_update_check", int(Time.get_unix_time_from_system()))
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers := ["Accept: application/vnd.github+json", "User-Agent: ArnavCountrySimulator/" + current_version()]
	if req.request(API % REPO, headers) != OK:
		req.queue_free()
		return _done({"ok": false, "error": "Could not start the request."})
	var res: Array = await req.request_completed
	req.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS:
		return _done({"ok": false, "error": "You appear to be offline."})
	if res[1] == 404:
		return _done({"ok": true, "update": false, "error": "No releases published yet."})
	if res[1] != 200:
		return _done({"ok": false, "error": "GitHub returned %d." % res[1]})
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not d is Dictionary:
		return _done({"ok": false, "error": "Unexpected response."})
	var tag := str(d.get("tag_name", ""))
	var apk_url := ""
	var apk_size := 0
	for a in d.get("assets", []):
		if str(a.get("name", "")).ends_with(".apk"):
			apk_url = str(a.get("browser_download_url", ""))
			apk_size = int(a.get("size", 0))
			break
	latest = {"ok": true, "version": tag.trim_prefix("v"), "notes": clean_notes(str(d.get("body", ""))),
		"apk_url": apk_url, "apk_size": apk_size, "page_url": str(d.get("html_url", "")),
		"update": is_newer(tag, current_version())}
	return _done(latest)


func _done(r: Dictionary) -> Dictionary:
	checked.emit(r)
	return r


## Semantic version compare: is `a` (e.g. "v1.2.0") newer than `b`?
static func is_newer(a: String, b: String) -> bool:
	var pa := _parts(a)
	var pb := _parts(b)
	for k in 3:
		if pa[k] != pb[k]:
			return pa[k] > pb[k]
	return false


static func _parts(v: String) -> Array[int]:
	var core := v.strip_edges().trim_prefix("v").get_slice("-", 0).get_slice("+", 0)
	var out: Array[int] = [0, 0, 0]
	var bits := core.split(".")
	for k in mini(3, bits.size()):
		out[k] = bits[k].to_int()
	return out


## Markdown release notes -> plain, readable text.
static func clean_notes(md: String) -> String:
	var lines: PackedStringArray = []
	for raw in md.replace("\r", "").split("\n"):
		var l := raw.strip_edges()
		if l.begins_with("#"):
			l = l.lstrip("# ")
		elif l.begins_with("- ") or l.begins_with("* "):
			l = "•  " + l.substr(2)
		l = l.replace("**", "").replace("`", "").replace("__", "")
		lines.append(l)
	var text := "\n".join(lines).strip_edges()
	while text.contains("\n\n\n"):
		text = text.replace("\n\n\n", "\n\n")
	return text if text != "" else "Improvements and fixes."


# ------------------------------------------------------------------- sheet ---
func show_sheet() -> void:
	if latest.is_empty() or is_instance_valid(_modal):
		return
	_modal = ModalCard.new()
	add_child(_modal)
	_modal.header("download", DS.ACCENT, "Update available", "Version %s" % latest.version)
	var sub := Label.new()
	sub.theme_type_variation = &"Caption"
	sub.text = "You have %s%s" % [current_version(),
		"  ·  %s download" % _mb(int(latest.apk_size)) if int(latest.apk_size) > 0 else ""]
	_modal.content.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_modal.content.add_child(scroll)
	var notes := Label.new()
	notes.theme_type_variation = &"BodySecondary"
	notes.text = str(latest.notes)
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(notes)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.show_percentage = false
	_progress.visible = false
	_modal.content.add_child(_progress)
	_progress_label = Label.new()
	_progress_label.theme_type_variation = &"Caption"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.visible = false
	_modal.content.add_child(_progress_label)
	_primary = AppButton.make("Update now", &"PrimaryButton", "download")
	_primary.custom_minimum_size = Vector2(0, 50)
	_primary.pressed.connect(_update_now)
	_modal.content.add_child(_primary)
	_modal.choice("Later", "", &"GhostButton", func() -> void:
		if is_instance_valid(_dl):
			_dl.cancel_request()
		_modal.dismiss())
	_modal.choice("Skip this version", "", &"GhostButton", func() -> void:
		Settings.set_value("skipped_version", str(latest.version))
		_modal.dismiss())


func _update_now() -> void:
	Haptics.tap()
	if not OS.has_feature("android") or str(latest.apk_url) == "" or not Engine.has_singleton("AcsUpdater"):
		_open_page()
		return
	var plugin := Engine.get_singleton("AcsUpdater")
	if not plugin.canRequestInstalls():
		_explain_permission(plugin)
		return
	_download()


func _explain_permission(plugin: Object) -> void:
	_progress_label.visible = true
	_progress_label.text = "Allow \"Install unknown apps\" for Arnav Country Simulator, then come back and tap Update now."
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_primary.text = "Open settings"
	for c in _primary.pressed.get_connections():
		_primary.pressed.disconnect(c.callable)
	_primary.pressed.connect(func() -> void:
		plugin.openInstallPermissionSettings()
		_primary.text = "Update now"
		for c in _primary.pressed.get_connections():
			_primary.pressed.disconnect(c.callable)
		_primary.pressed.connect(_update_now))


func _download() -> void:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_DIR)
	var path := DOWNLOAD_DIR + "ArnavCountrySimulator-%s.apk" % latest.version
	_dl = HTTPRequest.new()
	_dl.download_file = path
	_dl.use_threads = true
	_dl.download_chunk_size = 262144
	add_child(_dl)
	_primary.disabled = true
	_primary.text = "Downloading…"
	_progress.visible = true
	_progress_label.visible = true
	_progress.value = 0
	if _dl.request(str(latest.apk_url), ["User-Agent: ArnavCountrySimulator"]) != OK:
		_fail("Download could not start.")
		return
	var res: Array = await _dl.request_completed
	_dl.queue_free()
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		_fail("Download failed.")
		return
	_progress.value = 100
	_progress_label.text = "Opening installer…"
	var plugin := Engine.get_singleton("AcsUpdater")
	var out := str(plugin.installApk(ProjectSettings.globalize_path(path)))
	if out != "ok":
		_fail("Installer could not open (%s)." % out)
		return
	Haptics.success()
	_modal.dismiss()


func _process(_delta: float) -> void:
	if is_instance_valid(_dl) and _progress and _progress.visible:
		var total := _dl.get_body_size()
		var got := _dl.get_downloaded_bytes()
		if total > 0:
			_progress.value = got * 100.0 / total
			_progress_label.text = "%s of %s" % [_mb(got), _mb(total)]


func _fail(msg: String) -> void:
	Haptics.warning()
	_progress_label.text = msg + " Opening the release page instead."
	await get_tree().create_timer(1.2).timeout
	_open_page()
	if is_instance_valid(_modal):
		_modal.dismiss()


func _open_page() -> void:
	var url := str(latest.get("page_url", ""))
	OS.shell_open(url if url != "" else "https://github.com/%s/releases/latest" % REPO)


static func _mb(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0)
