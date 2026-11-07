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
	await flush()


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
		if int(r.data[slot]) > local_t and not _dirty.has(slot):
			var g: Dictionary = await Firebase.get_save(slot)
			if g.ok:
				SaveManager.write_raw(slot, g.data)
	last_sync = int(Time.get_unix_time_from_system())
	status_changed.emit()
	flush()


func status_text() -> String:
	if not Firebase.enabled():
		return "Cloud save is not set up in this build."
	if not Firebase.signed_in():
		return "Not signed in — saves stay on this device."
	if busy:
		return "Syncing…"
	if not online:
		return "Offline — %d save(s) will upload when you're back online." % pending()
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
