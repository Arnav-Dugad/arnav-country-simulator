extends Node
## Sound effects and ambient music. Original, synthesized assets (tools/make_audio.py).
## Separate SFX / Music buses; music ducks under modal cards. Toggles in Settings.

const SFX := ["tap", "select", "toggle_on", "toggle_off", "sheet_up", "sheet_down", "tick",
	"success", "warning", "event", "election"]
const POOL := 6
const MIN_GAP := 0.04              # seconds between repeats of the same sound
const MUSIC_DB := -14.0
const DUCK_DB := -8.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _duck_tween: Tween
var _sfx_bus := -1
var _music_bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_bus = _ensure_bus("SFX")
	_music_bus = _ensure_bus("Music")
	for n in SFX:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	_music.stream = load("res://assets/audio/music_calm.wav")
	_music.volume_db = -60.0
	add_child(_music)
	Settings.changed.connect(_on_setting)


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")
	return idx


## Plays a named sound effect (see SFX). Slight pitch variation keeps repeats natural.
func play(sound: String, volume_db: float = 0.0) -> void:
	if not Settings.sound_on or not _streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -1.0)) < MIN_GAP:
		return
	_last[sound] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.98, 1.02) if sound in ["tap", "tick", "select"] else 1.0
	p.play()


func music_start() -> void:
	if not Settings.music_on or _music.playing:
		return
	_music.volume_db = -40.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 3.0).set_trans(Tween.TRANS_SINE)


func music_stop() -> void:
	if not _music.playing:
		return
	var t := create_tween()
	t.tween_property(_music, "volume_db", -50.0, 1.2)
	t.tween_callback(_music.stop)


## Lowers the music while something important is on screen (events, elections).
func duck(on: bool) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(_music_bus, v),
		AudioServer.get_bus_volume_db(_music_bus), DUCK_DB if on else 0.0, 0.5)


func _on_setting(key: String, value: Variant) -> void:
	if key == "music_on":
		if value:
			music_start()
		else:
			music_stop()
