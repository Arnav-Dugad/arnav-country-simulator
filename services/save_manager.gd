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
	Game.month_passed.connect(_on_month)
	Game.started.connect(func() -> void: save_slot(active_slot))


func _on_month() -> void:
	if Game.month == 1 and Game.has_game():
		save_slot(active_slot)  # yearly autosave


func path(slot: int) -> String:
	return DIR + "slot_%d.json" % slot


func save_slot(slot: int) -> bool:
	if not Game.has_game():
		return false
	var data := Game.to_dict()
	data["saved_at"] = int(Time.get_unix_time_from_system())
	data["summary"] = summary_of(data)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % path(slot))
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	active_slot = slot
	Settings.set_value("last_slot", slot)
	saved.emit(slot)
	slots_changed.emit()
	return true


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
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		slots_changed.emit()


func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(path(slot))
		slots_changed.emit()


func has_any() -> bool:
	for s in range(1, SLOTS + 1):
		if FileAccess.file_exists(path(s)):
			return true
	return false


func summary(slot: int) -> Dictionary:
	var d := read_slot(slot)
	return d.get("summary", {}) if not d.is_empty() else {}


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
