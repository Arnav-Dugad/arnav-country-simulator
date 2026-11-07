extends Node
## Firebase over REST (Spark plan: Authentication + Cloud Firestore only).
## - Auth: Identity Toolkit (anonymous, email/password, link anonymous → email,
##   password reset) + Secure Token refresh. Session persisted (encrypted) in user://.
## - Firestore: documents under users/{uid}/saves/{slot}. Save data is gzipped JSON
##   stored in a bytes field, so even long games stay far below the 1 MiB limit.
## Every call returns {ok: bool, code: int, data: Variant, error: String}.

signal auth_changed

const AUTH_URL := "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s"
const TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const FS_URL := "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/"
const SESSION_PATH := "user://session.cfg"
const TIMEOUT := 20.0

var uid := ""
var email := ""
var is_anonymous := true
var _id_token := ""
var _refresh_token := ""
var _expires_at := 0.0
var _refreshing := false
## Bumped on every sign-in/out so a slow, superseded auth call (e.g. the automatic
## guest sign-in at launch) can't overwrite a newer session.
var _gen := 0


func _ready() -> void:
	_load_session()


func enabled() -> bool:
	return FirebaseConfig.is_configured()


func signed_in() -> bool:
	return uid != "" and _refresh_token != ""


# ------------------------------------------------------------------ auth -----
func sign_in_anonymously() -> Dictionary:
	_gen += 1
	var gen := _gen
	var r := await _auth_call("signUp", {"returnSecureToken": true})
	if r.ok and gen == _gen:
		_take_session(r.data, true)
	return r


func sign_up_email(mail: String, password: String) -> Dictionary:
	# A guest keeps their uid (and cloud saves) by linking credentials instead.
	# (accounts:signUp with the guest's idToken links the credential; accounts:update
	# is blocked by email-enumeration protection on new projects.)
	_gen += 1
	var gen := _gen
	if signed_in() and is_anonymous:
		var tok := await id_token()
		var r := await _auth_call("signUp", {"idToken": tok, "email": mail, "password": password,
			"returnSecureToken": true})
		if r.ok and gen == _gen:
			_take_session(r.data, false)
		return r
	var r2 := await _auth_call("signUp", {"email": mail, "password": password, "returnSecureToken": true})
	if r2.ok and gen == _gen:
		_take_session(r2.data, false)
	return r2


func sign_in_email(mail: String, password: String) -> Dictionary:
	_gen += 1
	var gen := _gen
	var r := await _auth_call("signInWithPassword", {"email": mail, "password": password,
		"returnSecureToken": true})
	if r.ok and gen == _gen:
		_take_session(r.data, false)
	return r


func send_password_reset(mail: String) -> Dictionary:
	return await _auth_call("sendOobCode", {"requestType": "PASSWORD_RESET", "email": mail})


func sign_out() -> void:
	_gen += 1
	uid = ""
	email = ""
	is_anonymous = true
	_id_token = ""
	_refresh_token = ""
	_expires_at = 0.0
	DirAccess.remove_absolute(SESSION_PATH)
	auth_changed.emit()


## A valid ID token, refreshing it first if it expires within a minute.
func id_token() -> String:
	if _refresh_token == "":
		return ""
	if _id_token != "" and Time.get_unix_time_from_system() < _expires_at - 60.0:
		return _id_token
	while _refreshing:
		await get_tree().process_frame
	if Time.get_unix_time_from_system() < _expires_at - 60.0:
		return _id_token
	_refreshing = true
	var body := "grant_type=refresh_token&refresh_token=" + _refresh_token.uri_encode()
	var r := await _http(TOKEN_URL % FirebaseConfig.API_KEY, HTTPClient.METHOD_POST,
		["Content-Type: application/x-www-form-urlencoded"], body)
	_refreshing = false
	if not r.ok:
		if r.code == 400:  # refresh token revoked/expired -> sign out cleanly
			sign_out()
		return ""
	_id_token = r.data.get("id_token", "")
	_refresh_token = r.data.get("refresh_token", _refresh_token)
	_expires_at = Time.get_unix_time_from_system() + float(r.data.get("expires_in", "3600"))
	_save_session()
	return _id_token


func _auth_call(action: String, payload: Dictionary) -> Dictionary:
	if not enabled():
		return _fail(0, "Cloud is not configured")
	return await _http(AUTH_URL % [action, FirebaseConfig.API_KEY], HTTPClient.METHOD_POST,
		["Content-Type: application/json"], JSON.stringify(payload))


func _take_session(d: Dictionary, anonymous: bool) -> void:
	uid = d.get("localId", uid)
	email = d.get("email", email if not anonymous else "")
	is_anonymous = anonymous and email == ""
	_id_token = d.get("idToken", "")
	_refresh_token = d.get("refreshToken", _refresh_token)
	_expires_at = Time.get_unix_time_from_system() + float(d.get("expiresIn", "3600"))
	_save_session()
	auth_changed.emit()


func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("auth", "uid", uid)
	cfg.set_value("auth", "email", email)
	cfg.set_value("auth", "anonymous", is_anonymous)
	cfg.set_value("auth", "refresh", _refresh_token)
	cfg.save_encrypted_pass(SESSION_PATH, _device_key())


func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load_encrypted_pass(SESSION_PATH, _device_key()) != OK:
		return
	uid = cfg.get_value("auth", "uid", "")
	email = cfg.get_value("auth", "email", "")
	is_anonymous = cfg.get_value("auth", "anonymous", true)
	_refresh_token = cfg.get_value("auth", "refresh", "")


func _device_key() -> String:
	return "acs-" + OS.get_unique_id() + "-session"


# ------------------------------------------------------------- firestore -----
func _doc_url(path: String) -> String:
	return (FS_URL % FirebaseConfig.PROJECT_ID) + path


func _auth_headers() -> PackedStringArray:
	var tok := await id_token()
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + tok])


func put_save(slot: int, data: Dictionary) -> Dictionary:
	if not signed_in():
		return _fail(0, "Not signed in")
	var raw := JSON.stringify(data).to_utf8_buffer()
	var packed := raw.compress(FileAccess.COMPRESSION_GZIP)
	var sm: Dictionary = data.get("summary", {})
	var body := {"fields": {
		"data": {"bytesValue": Marshalls.raw_to_base64(packed)},
		"size": {"integerValue": str(raw.size())},
		"saved_at": {"integerValue": str(int(data.get("saved_at", 0)))},
		"country": {"stringValue": str(sm.get("country", ""))},
		"date": {"stringValue": str(sm.get("date", ""))},
		"version": {"integerValue": str(int(data.get("version", 1)))},
	}}
	var headers: PackedStringArray = await _auth_headers()
	return await _http(_doc_url("users/%s/saves/slot_%d" % [uid, slot]), HTTPClient.METHOD_PATCH,
		headers, JSON.stringify(body))


func get_save(slot: int) -> Dictionary:
	if not signed_in():
		return _fail(0, "Not signed in")
	var headers: PackedStringArray = await _auth_headers()
	var r := await _http(_doc_url("users/%s/saves/slot_%d" % [uid, slot]), HTTPClient.METHOD_GET, headers)
	if not r.ok:
		return r
	var f: Dictionary = r.data.get("fields", {})
	var packed := Marshalls.base64_to_raw(f.get("data", {}).get("bytesValue", ""))
	var size := int(f.get("size", {}).get("integerValue", "0"))
	var raw := packed.decompress(size, FileAccess.COMPRESSION_GZIP)
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not parsed is Dictionary:
		return _fail(0, "Cloud save is damaged")
	r.data = parsed
	return r


## {slot -> saved_at} for every cloud save of this user.
func list_saves() -> Dictionary:
	if not signed_in():
		return _fail(0, "Not signed in")
	var headers: PackedStringArray = await _auth_headers()
	var r := await _http(_doc_url("users/%s/saves?mask.fieldPaths=saved_at&mask.fieldPaths=country" % uid),
		HTTPClient.METHOD_GET, headers)
	if not r.ok:
		return r
	var out := {}
	for doc in r.data.get("documents", []):
		var name: String = doc.get("name", "")
		var slot := int(name.get_slice("slot_", 1))
		out[slot] = int(doc.get("fields", {}).get("saved_at", {}).get("integerValue", "0"))
	r.data = out
	return r


func delete_save(slot: int) -> Dictionary:
	if not signed_in():
		return _fail(0, "Not signed in")
	var headers: PackedStringArray = await _auth_headers()
	return await _http(_doc_url("users/%s/saves/slot_%d" % [uid, slot]), HTTPClient.METHOD_DELETE, headers)


# ------------------------------------------------------------------ http -----
func _http(url: String, method: int, headers: PackedStringArray, body: String = "") -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	req.use_threads = true
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return _fail(0, "Could not start request (%d)" % err)
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "You appear to be offline")
	var parsed: Variant = JSON.parse_string(text) if text != "" else {}
	if code >= 200 and code < 300:
		return {"ok": true, "code": code, "data": parsed if parsed != null else {}, "error": ""}
	var msg := "Request failed (%d)" % code
	if parsed is Dictionary and parsed.has("error"):
		msg = friendly_error(str(parsed.error.get("message", msg)))
	return _fail(code, msg)


func _fail(code: int, msg: String) -> Dictionary:
	return {"ok": false, "code": code, "data": {}, "error": msg}


static func friendly_error(raw: String) -> String:
	var key := raw.get_slice(" ", 0).get_slice(":", 0)
	return {
		"EMAIL_EXISTS": "An account with this email already exists.",
		"EMAIL_NOT_FOUND": "No account uses this email.",
		"INVALID_PASSWORD": "That password is incorrect.",
		"INVALID_LOGIN_CREDENTIALS": "Email or password is incorrect.",
		"INVALID_EMAIL": "Please enter a valid email address.",
		"WEAK_PASSWORD": "Use at least 6 characters for your password.",
		"MISSING_PASSWORD": "Please enter a password.",
		"TOO_MANY_ATTEMPTS_TRY_LATER": "Too many attempts. Please try again later.",
		"USER_DISABLED": "This account has been disabled.",
		"CREDENTIAL_TOO_OLD_LOGIN_AGAIN": "Please sign in again.",
		"OPERATION_NOT_ALLOWED": "This sign-in method is not enabled in Firebase.",
		"ADMIN_ONLY_OPERATION": "Anonymous sign-in is not enabled in Firebase.",
		"PERMISSION_DENIED": "Permission denied — check firestore.rules.",
	}.get(key, raw.capitalize())
