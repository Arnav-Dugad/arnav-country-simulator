class_name AccountSection
extends VBoxContainer
## Account & cloud block for the Settings page: guest status, upgrade to an
## email account, sign in/out, sync status and manual sync.

var _status: Label
var _who: ListRow
var _buttons: VBoxContainer


func _ready() -> void:
	add_theme_constant_override(&"separation", DS.S3)
	_who = ListRow.new()
	add_child(_who)
	_status = Label.new()
	_status.theme_type_variation = &"Footnote"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", DS.S2)
	add_child(_buttons)
	Firebase.auth_changed.connect(_rebuild)
	CloudSync.status_changed.connect(_update_status)
	_rebuild()


func _rebuild() -> void:
	for ch in _buttons.get_children():
		ch.queue_free()
	if not Firebase.enabled():
		_who.setup("Offline mode", "Saves stay on this device")
		_who.set_leading(ListRow.icon_tile("cloud-off", DS.TEXT_3))
		_update_status()
		return
	if not Firebase.signed_in():
		_who.setup("Not signed in", "Saves stay on this device")
		_who.set_leading(ListRow.icon_tile("cloud-off", DS.TEXT_3))
		_btn("Continue as guest", &"PrimaryButton", "user", func() -> void:
			var r: Dictionary = await Firebase.sign_in_anonymously()
			if not r.ok:
				_error(r.error))
		_btn("Sign in with email", &"", "mail", _email_form.bind(false))
	elif Firebase.is_anonymous:
		_who.setup("Playing as guest", "Cloud backup is on. Add an email to keep your saves on any device.")
		_who.set_leading(ListRow.icon_tile("user", DS.ACCENT))
		_btn("Create account", &"PrimaryButton", "mail", _email_form.bind(true))
		_btn("Sign in to existing account", &"", "log-out", _email_form.bind(false))
		_btn("Sync now", &"GhostButton", "refresh-cw", _sync)
	else:
		_who.setup(Firebase.email, "Signed in · saves sync across devices")
		_who.set_leading(ListRow.icon_tile("cloud", DS.GREEN))
		_btn("Sync now", &"", "refresh-cw", _sync)
		_btn("Sign out", &"GhostButton", "log-out", func() -> void:
			Firebase.sign_out()
			Haptics.tap())
	_update_status()


func _btn(text: String, variant: StringName, icon_: String, cb: Callable) -> void:
	var b := AppButton.make(text, variant, icon_)
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _update_status() -> void:
	_status.text = CloudSync.status_text()
	_status.remove_theme_color_override(&"font_color")


func _error(msg: String) -> void:
	_status.text = msg
	_status.add_theme_color_override(&"font_color", DS.RED)
	Haptics.warning()


func _sync() -> void:
	Haptics.tap()
	await CloudSync.flush()
	await CloudSync.pull_newer()


func _email_form(create: bool) -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("mail", DS.ACCENT, "Account", "Create your account" if create else "Welcome back")
	m.body("Your current progress stays with you." if create else "Sign in to restore your cloud saves.")
	var mail := LineEdit.new()
	mail.placeholder_text = "Email"
	mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	m.content.add_child(mail)
	var pw := LineEdit.new()
	pw.placeholder_text = "Password (6+ characters)"
	pw.secret = true
	pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	m.content.add_child(pw)
	var err := Label.new()
	err.theme_type_variation = &"Footnote"
	err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err.add_theme_color_override(&"font_color", DS.RED)
	m.content.add_child(err)
	m.choice("Create account" if create else "Sign in", "", &"PrimaryButton", func() -> void:
		err.text = "Working…"
		err.add_theme_color_override(&"font_color", DS.TEXT_2)
		var r: Dictionary
		if create:
			r = await Firebase.sign_up_email(mail.text.strip_edges(), pw.text)
		else:
			r = await Firebase.sign_in_email(mail.text.strip_edges(), pw.text)
		if r.ok:
			Haptics.success()
			m.dismiss()
		else:
			err.text = r.error
			err.add_theme_color_override(&"font_color", DS.RED)
			Haptics.warning())
	if not create:
		m.choice("Forgot password?", "", &"GhostButton", func() -> void:
			var r: Dictionary = await Firebase.send_password_reset(mail.text.strip_edges())
			err.text = "Reset email sent." if r.ok else r.error)
	m.choice("Cancel", "", &"GhostButton", m.dismiss)
