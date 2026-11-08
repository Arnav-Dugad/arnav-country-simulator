extends Node
## Sound effects and music. Original, synthesized orchestral score and cues
## (tools/make_score.py). Separate SFX / Music buses; music ducks under modal
## cards. Two "places": the menu theme (splash, home, country picker) and the
## in-game pair (calm + tense, in sync, crossfaded by mood()). Toggles in Settings.

const SFX := ["tap", "select", "toggle_on", "toggle_off", "sheet_up", "sheet_down", "tick",
	"success", "warning", "event", "election", "fanfare"]
const POOL := 6
const MIN_GAP := 0.04              # seconds between repeats of the same sound
const MUSIC_DB := -14.0
const DUCK_DB := -8.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last := {}
var _music: AudioStreamPlayer
var _menu: AudioStreamPlayer
var _place := "menu"      # "menu" or "game"
var _place_tween: Tween
## Adaptive music: a tense loop of the same length plays in sync and crossfades in
## when your country is in trouble (see mood()).
var _tense: AudioStreamPlayer
var _mood := 0.0          # 0 calm .. 1 tense
var _mood_tween: Tween
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
	_music = _music_player("music_calm")
	_tense = _music_player("music_tense")
	_menu = _music_player("music_menu")
	Settings.changed.connect(_on_setting)


## Release the music streams on quit (a playing Ogg stream otherwise leaks at exit).
func _exit_tree() -> void:
	for t: Tween in [_place_tween, _mood_tween, _duck_tween]:
		if t:
			t.kill()
	for p: AudioStreamPlayer in [_music, _tense, _menu]:
		if p:
			p.stop()
			p.stream = null


func _music_player(track: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	var path := "res://assets/audio/%s.ogg" % track
	if ResourceLoader.exists(path):
		var s: AudioStream = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		p.stream = s
	p.volume_db = -60.0
	add_child(p)
	return p


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


## Starts the music for a place ("menu" or "game"), crossfading from whatever
## plays now. Calling it again for the same place does nothing.
func music_start(place: String = "menu") -> void:
	if not Settings.music_on:
		_place = place
		return
	var same := place == _place and (_menu.playing if place == "menu" else _music.playing)
	if same:
		return
	_place = place
	if _place_tween:
		_place_tween.kill()
	_place_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	if place == "menu":
		if not _menu.playing:
			_menu.volume_db = -40.0
			_menu.play()
		_place_tween.tween_property(_menu, "volume_db", MUSIC_DB, 3.0)
		_place_tween.tween_property(_music, "volume_db", -60.0, 2.5)
		_place_tween.tween_property(_tense, "volume_db", -60.0, 2.5)
		_place_tween.chain().tween_callback(func() -> void:
			_music.stop()
			_tense.stop())
	else:
		if not _music.playing:
			_music.volume_db = -40.0
			_music.play()
			if _tense.stream:
				_tense.volume_db = -60.0
				_tense.play()
		_place_tween.tween_property(_music, "volume_db", _calm_db(), 3.5)
		_place_tween.tween_property(_tense, "volume_db", _tense_db(), 3.5)
		_place_tween.tween_property(_menu, "volume_db", -60.0, 2.5)
		_place_tween.chain().tween_callback(_menu.stop)


func music_stop() -> void:
	var t := create_tween().set_parallel(true)
	for p in [_music, _tense, _menu]:
		t.tween_property(p, "volume_db", -60.0, 1.2)
	t.chain().tween_callback(func() -> void:
		for p in [_music, _tense, _menu]:
			p.stop())


## 0 = all is well, 1 = crisis. The two loops crossfade over a few seconds.
func mood(tension: float) -> void:
	tension = clampf(tension, 0.0, 1.0)
	if absf(tension - _mood) < 0.05 or not _music.playing:
		_mood = tension
		return
	_mood = tension
	if _mood_tween:
		_mood_tween.kill()
	_mood_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_mood_tween.tween_property(_music, "volume_db", _calm_db(), 5.0)
	_mood_tween.tween_property(_tense, "volume_db", _tense_db(), 5.0)


func _calm_db() -> float:
	return MUSIC_DB + linear_to_db(maxf(1.0 - _mood, 0.02))


func _tense_db() -> float:
	return MUSIC_DB + linear_to_db(maxf(_mood, 0.02)) if _tense.stream else -60.0


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
			var p := _place
			_place = ""
			music_start(p)
		else:
			music_stop()
