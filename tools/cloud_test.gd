extends Node
## Live Firebase integration test (uses the real project in firebase_config.gd).
## Creates a throwaway account, exercises auth + Firestore + rules, then deletes it.
## Run: godot --headless --path . res://tools/cloud_test.tscn

const OTHER_UID := "someone-elses-uid"

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String, detail: String = "") -> void:
	print(("PASS  " if ok else "FAIL  ") + what + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1


func _run() -> void:
	# Let CloudSync's automatic guest sign-in finish before taking over the session.
	await get_tree().create_timer(2.0).timeout
	while CloudSync.busy:
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	Firebase.sign_out()
	_check(Firebase.enabled(), "config present")

	var r: Dictionary = await Firebase.sign_in_anonymously()
	_check(r.ok and Firebase.signed_in() and Firebase.is_anonymous, "anonymous sign-in", r.error)
	var guest_uid := Firebase.uid

	Game.new_game(World.index_of("JPN"), 5)
	for m in 14:
		Game.advance_month()
	# Deep copy: to_dict shares some live dictionaries, and the game keeps ticking while we wait.
	var data := Game.to_dict().duplicate(true)
	data["saved_at"] = int(Time.get_unix_time_from_system())
	data["summary"] = SaveManager.summary_of(data)
	var raw_size := JSON.stringify(data).length()
	r = await Firebase.put_save(9, data)
	_check(r.ok, "upload save (%d KB raw json)" % (raw_size / 1024), r.error)

	r = await Firebase.list_saves()
	_check(r.ok and r.data.has(9), "list saves", r.error)

	r = await Firebase.get_save(9)
	# JSON numbers come back as floats, so compare normalised JSON.
	var expected := JSON.stringify(JSON.parse_string(JSON.stringify(data)))
	_check(r.ok and JSON.stringify(r.data) == expected, "download save matches upload", r.error)

	# Security rules: another user's documents must be off-limits.
	var headers: PackedStringArray = await Firebase._auth_headers()
	r = await Firebase._http(Firebase._doc_url("users/%s/saves/slot_1" % OTHER_UID), HTTPClient.METHOD_GET, headers)
	_check(not r.ok and r.code == 403, "rules block reading another user", "code %d" % r.code)
	r = await Firebase._http(Firebase._doc_url("users/%s/saves/slot_1" % OTHER_UID), HTTPClient.METHOD_PATCH, headers,
		JSON.stringify({"fields": {"data": {"bytesValue": "AA=="}}}))
	_check(not r.ok and r.code == 403, "rules block writing another user", "code %d" % r.code)
	r = await Firebase._http(Firebase._doc_url("leaderboard/x"), HTTPClient.METHOD_GET, headers)
	_check(not r.ok and r.code == 403, "rules block other collections", "code %d" % r.code)

	# Upgrade guest -> email keeps the uid.
	var mail := "acs-test-%d@example.com" % (randi() % 1000000000)
	var pw := "T3st-" + str(randi()) + "-pw"
	r = await Firebase.sign_up_email(mail, pw)
	_check(r.ok and Firebase.uid == guest_uid and not Firebase.is_anonymous, "upgrade guest to email keeps uid", r.error)

	Firebase.sign_out()
	r = await Firebase.sign_in_email(mail, pw)
	_check(r.ok and Firebase.uid == guest_uid, "sign in with email", r.error)
	r = await Firebase.sign_in_email(mail, "wrong-password")
	_check(not r.ok, "wrong password rejected", r.error)
	r = await Firebase.sign_in_email(mail, pw)

	# Token refresh path.
	Firebase._expires_at = 0.0
	var tok := await Firebase.id_token()
	_check(tok != "", "token refresh")

	# Clean up: delete the save and the throwaway account.
	r = await Firebase.delete_save(9)
	_check(r.ok, "delete save", r.error)
	var del := await Firebase._auth_call("delete", {"idToken": await Firebase.id_token()})
	_check(del.ok, "delete test account", del.error)
	Firebase.sign_out()
	print("CLOUD TEST %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit()
