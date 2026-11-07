extends Node
## Local save slots (user://saves/slot_N.json) with an index of summaries.
## Auto-saves to the active slot every in-game year. Cloud sync (Firebase) hooks
## into `saved` / `load_slot` — see services/cloud_sync.gd.

signal saved(slot: int)
signal slots_changed

const DIR := "user://saves/"
const SLOTS := 3

var active_slot := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_index.load(INDEX_PATH)
	Game.month_passed.connect(_on_month)
	Game.started.connect(func() -> void: save_slot(active_slot))


func _on_month() -> void:
	if Game.month == 1 and Game.has_game():
		save_slot(active_slot)  # yearly autosave


func path(slot: int) -> String:
	return DIR + "slot_%d.json" % slot


## Saves the running game. The state is deep-copied on the main thread (~2 ms);
## JSON encoding and the file write (~20 ms) run on a worker thread so autosaves
## never cause a hitch. `saved` is emitted on the main thread when done.
func save_slot(slot: int, background: bool = true) -> bool:
	if not Game.has_game():
		return false
	var data: Dictionary = Game.to_dict().duplicate(true)
	data["saved_at"] = int(Time.get_unix_time_from_system())
	data["summary"] = summary_of(data)
	_set_summary(slot, data["summary"])
	active_slot = slot
	Settings.set_value("last_slot", slot)
	if not background:
		var ok := _write(slot, data)
		_finished(slot, ok)
		return ok
	if _busy.has(slot):
		_again[slot] = data          # newest wins; written right after the current one
		return true
	_busy[slot] = true
	WorkerThreadPool.add_task(func() -> void:
		var ok := _write(slot, data)
		_finished.call_deferred(slot, ok))
	return true


var _busy := {}
var _again := {}
var _index := ConfigFile.new()   # slot -> summary (so menus never parse full saves)
const INDEX_PATH := DIR + "index.cfg"


## Atomic write: temp file, then rename, so readers never see a half-written save.
func _write(slot: int, data: Dictionary) -> bool:
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))
	return DirAccess.rename_absolute(tmp, path(slot)) == OK


func is_busy(slot: int) -> bool:
	return _busy.has(slot)


func _finished(slot: int, ok: bool) -> void:
	_busy.erase(slot)
	if not ok:
		push_error("SaveManager: cannot write %s" % path(slot))
		return
	saved.emit(slot)
	slots_changed.emit()
	if _again.has(slot):
		var data: Dictionary = _again[slot]
		_again.erase(slot)
		_busy[slot] = true
		WorkerThreadPool.add_task(func() -> void:
			var ok2 := _write(slot, data)
			_finished.call_deferred(slot, ok2))


func read_slot(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path(slot)))
	return parsed if parsed is Dictionary else {}


func load_slot(slot: int) -> bool:
	var d := read_slot(slot)
	if d.is_empty() or not Game.load_dict(d):
		return false
	active_slot = slot
	Settings.set_value("last_slot", slot)
	return true


## Writes raw save data (e.g. pulled from the cloud) into a slot.
func write_raw(slot: int, data: Dictionary) -> void:
	if data.has("summary"):
		_set_summary(slot, data["summary"])
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		slots_changed.emit()


func delete_slot(slot: int) -> void:
	if _index.has_section_key("slots", str(slot)):
		_index.erase_section_key("slots", str(slot))
		_index.save(INDEX_PATH)
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))
		slots_changed.emit()


func has_any() -> bool:
	for s in range(1, SLOTS + 1):
		if FileAccess.file_exists(path(s)):
			return true
	return false


func summary(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var cached: Variant = _index.get_value("slots", str(slot), null)
	if cached is Dictionary:
		return cached
	var d := read_slot(slot)   # older saves: parse once, then remember
	var sm: Dictionary = d.get("summary", {}) if not d.is_empty() else {}
	if not sm.is_empty():
		_set_summary(slot, sm)
	return sm


func _set_summary(slot: int, sm: Dictionary) -> void:
	_index.set_value("slots", str(slot), sm)
	_index.save(INDEX_PATH)


static func summary_of(data: Dictionary) -> Dictionary:
	var iso: String = data.get("player", "")
	var c: Dictionary = data.get("countries", {}).get(iso, {})
	return {
		"country": iso,
		"name": World.name_of(World.index_of(iso)),
		"date": "%02d/%d" % [int(data.get("month", 1)), int(data.get("year", 0))],
		"approval": snappedf(float(c.get("approval", 0.0)), 0.1),
		"gdp": float(c.get("gdp", 0.0)),
		"saved_at": int(data.get("saved_at", 0)),
	}
