extends Node
## Persistent user preferences (user://settings.cfg).

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"

var haptics: bool = true
var sound_on: bool = true
var music_on: bool = true
var reduce_motion: bool = false
var onboarding_done: bool = false
var last_update_check: int = 0
var skipped_version: String = ""
var last_slot: int = 1
var map_theme: String = "default"
var tutorial_done: bool = false
## Text size steps (Settings > Text). The default is a little under the theme's
## base sizes: denser, calmer screens on phones.
const TEXT_SCALES := [0.8, 0.86, 0.92, 1.04, 1.18]
const TEXT_DEFAULT := 0.92
var text_scale: float = TEXT_DEFAULT
var colorblind: bool = false         # colour-blind friendly data map palettes
var solid_panels: bool = false       # "Reduce transparency": no glass blur
## Events: "inbox" (decisions wait above the dock; the cabinet answers when time
## runs out), "ask" (every event pauses, classic) or "cabinet" (auto-answer).
var decisions: String = "inbox"
## Banners: "calm" (only the important ones, spaced out) or "all".
var banners: String = "calm"
var pause_full_sheet: bool = false   # pause while a panel is open at full height
var cheats: bool = false             # Settings > Cheats unlocked (sandbox)
var last_difficulty: String = "standard"
## Leader profile: your name and party, used in titles, headlines and the legacy card.
var leader_name: String = ""
var party_name: String = ""
var party_color: int = 0
var landscape: bool = true          # follow the phone's rotation (landscape layout)
var leader_portrait: String = ""    # your portrait (assets/portraits key), "" = initials
var learn_done: Array = []          # first-game checklist steps done (see Learn)
var seen_version: String = ""       # app version last opened (WhatsNew)
var coach_seen: Array = []          # pages whose first-visit tip was shown (Game coach marks)

const EXTRA_KEYS := ["decisions", "banners", "pause_full_sheet", "cheats", "last_difficulty",
	"leader_name", "party_name", "party_color", "landscape", "leader_portrait", "learn_done", "seen_version", "coach_seen"]
const PARTY_COLORS := [Color("0a84ff"), Color("30d158"), Color("ff453a"), Color("ff9f0a"), Color("bf5af2"), Color("64d2ff")]

var _cfg := ConfigFile.new()


func _ready() -> void:
	if _cfg.load(PATH) == OK:
		haptics = _cfg.get_value("prefs", "haptics", haptics)
		sound_on = _cfg.get_value("prefs", "sound_on", true)
		music_on = _cfg.get_value("prefs", "music_on", true)
		reduce_motion = _cfg.get_value("prefs", "reduce_motion", reduce_motion)
		onboarding_done = _cfg.get_value("prefs", "onboarding_done", onboarding_done)
		last_update_check = _cfg.get_value("prefs", "last_update_check", 0)
		skipped_version = _cfg.get_value("prefs", "skipped_version", "")
		last_slot = _cfg.get_value("prefs", "last_slot", 1)
		map_theme = _cfg.get_value("prefs", "map_theme", "default")
		tutorial_done = _cfg.get_value("prefs", "tutorial_done", false)
		text_scale = _cfg.get_value("prefs", "text_scale", TEXT_DEFAULT)
		if not _cfg.get_value("prefs", "text_v2", false):
			# Older builds had 0.9 / 1.0 / 1.15 / 1.3: map each to its new step.
			text_scale = {0.9: 0.86, 1.0: TEXT_DEFAULT, 1.15: 1.04, 1.3: 1.18}.get(snappedf(text_scale, 0.01), text_scale)
			_cfg.set_value("prefs", "text_v2", true)
			_cfg.set_value("prefs", "text_scale", text_scale)
			_cfg.save(PATH)
		colorblind = _cfg.get_value("prefs", "colorblind", false)
		solid_panels = _cfg.get_value("prefs", "solid_panels", false)
		for k in EXTRA_KEYS:
			set(k, _cfg.get_value("prefs", k, get(k)))
	_apply_text_scale()
	_apply_orientation()


## Portrait only, or follow the phone's sensor (landscape layouts).
func _apply_orientation() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR if landscape else DisplayServer.SCREEN_PORTRAIT)


func get_value(key: String, fallback: Variant = null) -> Variant:
	var v: Variant = get(key)
	return fallback if v == null else v


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	_cfg.set_value("prefs", key, value)
	_cfg.save(PATH)
	if key == "text_scale":
		_apply_text_scale()
	if key == "landscape":
		_apply_orientation()
	changed.emit(key, value)


var _base_sizes := {}


## Scales every font size in the project theme (text only; layout follows).
func _apply_text_scale() -> void:
	var th := ThemeDB.get_project_theme()
	if th == null:
		return
	if _base_sizes.is_empty():
		for type in th.get_font_size_type_list():
			for n in th.get_font_size_list(type):
				_base_sizes[[type, n]] = th.get_font_size(n, type)
		_base_sizes[["", "default"]] = th.default_font_size
	for key in _base_sizes:
		var v := int(round(float(_base_sizes[key]) * text_scale))
		if key[0] == "":
			th.default_font_size = v
		else:
			th.set_font_size(key[1], key[0], v)


## Animation duration helper that honours "Reduce motion".
func dur(d: float) -> float:
	return 0.01 if reduce_motion else d
