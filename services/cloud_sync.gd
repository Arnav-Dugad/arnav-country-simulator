extends Node
## Offline-first cloud sync. Local saves are always written first (SaveManager);
## this queues each saved slot for upload and retries until it succeeds, so play
## works offline and catches up when the connection returns. On sign-in it pulls
## any cloud slot that is newer than the local copy.

signal status_changed

const QUEUE_PATH := "user://sync_queue.cfg"
const RETRY_SECONDS := 45.0

var online := true
var last_sync := 0
var busy := false
var last_error := ""

var _dirty := {}  # slot -> true
## Slots with two different versions (this phone has unsynced changes AND the
## cloud copy is newer): never auto-overwritten; the player picks (conflict picker).
var _conflicts := {}  # slot -> cloud data
var _retry_timer: Timer


func _ready() -> void:
	_load_queue()
	SaveManager.saved.connect(_on_saved)
	Firebase.auth_changed.connect(_on_auth_changed)
	_retry_timer = Timer.new()
	_retry_timer.wait_time = RETRY_SECONDS
	_retry_timer.autostart = true
	_retry_timer.timeout.connect(flush)
	add_child(_retry_timer)
	if Firebase.enabled():
		_startup.call_deferred()


func _startup() -> void:
	if not Firebase.signed_in():
		await Firebase.sign_in_anonymously()  # guest play: silent anonymous account
	# Look before uploading: a newer cloud copy plus local changes is a conflict.
	await pull_newer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		flush()


func pending() -> int:
	return _dirty.size()


func _on_saved(slot: int) -> void:
	_dirty[slot] = true
	_save_queue()
	flush()


func _on_auth_changed() -> void:
	status_changed.emit()
	if Firebase.signed_in():
		pull_newer()


## Upload every queued slot.
func flush() -> void:
	if busy or not Firebase.enabled() or not Firebase.signed_in() or _dirty.is_empty():
		return
	busy = true
	status_changed.emit()
	for slot in _dirty.keys():
		if _conflicts.has(slot):
			continue   # waiting for the player to choose
		if SaveManager.is_busy(slot):
			continue   # still being written; uploaded when `saved` fires
		var data := SaveManager.read_slot(slot)
		if data.is_empty():
			_dirty.erase(slot)
			continue
		var r: Dictionary = await Firebase.put_save(slot, data)
		online = r.ok or r.code != 0
		if r.ok:
			_dirty.erase(slot)
			last_sync = int(Time.get_unix_time_from_system())
			last_error = ""
		else:
			last_error = r.error
			break
	_save_queue()
	busy = false
	status_changed.emit()


## Download cloud slots that are newer than the local ones (e.g. a new device).
func pull_newer() -> void:
	if not Firebase.signed_in():
		return
	var r: Dictionary = await Firebase.list_saves()
	online = r.ok or r.code != 0
	if not r.ok:
		last_error = r.error
		status_changed.emit()
		return
	for slot in r.data:
		if int(slot) < 1 or int(slot) > SaveManager.SLOTS:
			continue
		var local := SaveManager.read_slot(slot)
		var local_t := int(local.get("saved_at", 0))
		if int(r.data[slot]) > local_t:
			var g: Dictionary = await Firebase.get_save(slot)
			if not g.ok:
				continue
			if _dirty.has(slot) and not local.is_empty():
				_conflicts[int(slot)] = g.data     # both changed: ask
			else:
				SaveManager.write_raw(slot, g.data)
	last_sync = int(Time.get_unix_time_from_system())
	status_changed.emit()
	if not _conflicts.is_empty():
		_ask_conflict.call_deferred()
	flush()


# ------------------------------------------------------------- conflicts ----
func has_conflicts() -> bool:
	return not _conflicts.is_empty()


## Shows the picker for the next conflicting slot: "This phone" vs "Cloud".
func _ask_conflict() -> void:
	if _conflicts.is_empty():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var slot: int = _conflicts.keys()[0]
	var cloud: Dictionary = _conflicts[slot]
	var here := SaveManager.summary(slot)
	var there := SaveManager.summary_of(cloud)
	var m := ModalCard.new()
	scene.add_child(m)
	m.content.add_child(Illustration.make("globe", DS.ACCENT, 84.0))
	m.header("cloud", DS.ACCENT, "Slot %d" % slot, "Two versions of this game")
	m.body("This phone and your cloud backup both changed since they last synced. Which one do you want to keep?")
	m.choice("This phone: %s, %s" % [str(here.get("name", "?")), str(here.get("date", ""))],
		"Saved %s · approval %s%%" % [_ago(int(here.get("saved_at", 0))), String.num(float(here.get("approval", 0.0)), 0)],
		&"PrimaryButton", func() -> void:
			_conflicts.erase(slot)
			m.dismiss()
			flush()
			_ask_conflict.call_deferred())
	m.choice("Cloud: %s, %s" % [str(there.get("name", "?")), str(there.get("date", ""))],
		"Saved %s · approval %s%%" % [_ago(int(there.get("saved_at", 0))), String.num(float(there.get("approval", 0.0)), 0)],
		&"", func() -> void:
			_conflicts.erase(slot)
			_dirty.erase(slot)
			_save_queue()
			SaveManager.write_raw(slot, cloud)
			m.dismiss()
			_ask_conflict.call_deferred())
	var free := -1
	for s in range(1, SaveManager.SLOTS + 1):
		if SaveManager.summary(s).is_empty():
			free = s
			break
	if free > 0:
		m.choice("Keep both", "The cloud version goes to empty slot %d" % free, &"GhostButton", func() -> void:
			_conflicts.erase(slot)
			SaveManager.write_raw(free, cloud)
			m.dismiss()
			flush()
			_ask_conflict.call_deferred())


static func _ago(t: int) -> String:
	if t <= 0:
		return "a while ago"
	var mins := int((Time.get_unix_time_from_system() - t) / 60.0)
	if mins < 1:
		return "just now"
	if mins < 60:
		return "%d min ago" % mins
	if mins < 60 * 24:
		return "%d h ago" % int(mins / 60.0)
	return "%d days ago" % int(mins / 1440.0)


func status_text() -> String:
	if not Firebase.enabled():
		return "Cloud save is not set up in this build."
	if not Firebase.signed_in():
		return "Not signed in — saves stay on this device."
	if busy:
		return "Syncing…"
	if not online:
		return "Offline — %d save(s) will upload when you're back online." % pending()
	if has_conflicts():
		return "Two versions of a save: choose which to keep."
	if last_error != "":
		return "Sync issue: %s" % last_error
	if last_sync > 0:
		var mins := int((Time.get_unix_time_from_system() - last_sync) / 60.0)
		return "All saves backed up%s." % (" just now" if mins < 1 else " %d min ago" % mins)
	return "Ready to sync."


func _save_queue() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("queue", "slots", _dirty.keys())
	cfg.set_value("queue", "last_sync", last_sync)
	cfg.save(QUEUE_PATH)


func _load_queue() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(QUEUE_PATH) == OK:
		for s in cfg.get_value("queue", "slots", []):
			_dirty[int(s)] = true
		last_sync = int(cfg.get_value("queue", "last_sync", 0))
