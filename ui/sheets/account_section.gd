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
		_who.setup("Playing as guest", "Backed up. Add email for any device.")
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
	AccountForm.open(get_tree().current_scene, create)
