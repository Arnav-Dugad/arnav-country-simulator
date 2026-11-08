class_name AccountSection
extends VBoxContainer
## Account & cloud block for the Settings page: a live status card, who you are,
## which saves are safely in the cloud, and the account actions.

var _state_icon: Control
var _state_title: Label
var _state_caption: Label
var _who: ListRow
var _saves: VBoxContainer
var _buttons: VBoxContainer
var _status: Label


func _ready() -> void:
	add_theme_constant_override(&"separation", DS.S3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", DS.S3)
	add_child(head)
	_state_icon = ListRow.icon_tile("cloud", DS.ACCENT)
	head.add_child(_state_icon)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(col)
	_state_title = Label.new()
	_state_title.theme_type_variation = &"Headline"
	col.add_child(_state_title)
	_state_caption = Label.new()
	_state_caption.theme_type_variation = &"Caption"
	_state_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_caption.custom_minimum_size = Vector2(40, 0)
	col.add_child(_state_caption)
	_who = ListRow.new()
	add_child(_who)
	_saves = VBoxContainer.new()
	_saves.add_theme_constant_override(&"separation", 2)
	add_child(_saves)
	_status = Label.new()
	_status.theme_type_variation = &"Footnote"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	add_child(_status)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", DS.S2)
	add_child(_buttons)
	Firebase.auth_changed.connect(_rebuild)
	CloudSync.status_changed.connect(_update_status)
	SaveManager.slots_changed.connect(_update_status)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for ch in _buttons.get_children():
		ch.queue_free()
	_status.visible = false
	if not Firebase.enabled():
		_who.setup("This device only", "Cloud backup isn't available in this build")
		_who.set_leading(ListRow.icon_tile("smartphone", DS.TEXT_3))
		_update_status()
		return
	if not Firebase.signed_in():
		_who.setup("Not signed in", "Your saves live only on this phone")
		_who.set_leading(ListRow.icon_tile("user", DS.TEXT_3))
		_btn("Back up as a guest", &"PrimaryButton", "cloud-upload", func() -> void:
			_busy_msg("Setting up your backup…")
			var r: Dictionary = await Firebase.sign_in_anonymously()
			if not r.ok:
				_error(r.error))
		_btn("Sign in with email", &"", "mail", _email_form.bind(false))
	elif Firebase.is_anonymous:
		_who.setup("Playing as a guest", "Backed up to this phone's guest account. Add an email to keep it if you change phones.")
		_who.subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_who.subtitle_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_who.set_leading(ListRow.icon_tile("user", DS.ACCENT))
		_btn("Save to an email account", &"PrimaryButton", "mail", _email_form.bind(true))
		_btn("Sign in to an existing account", &"", "log-in", _email_form.bind(false))
		_btn("Sync now", &"GhostButton", "refresh-cw", _sync)
		_btn("Delete guest account", &"GhostButton", "trash-2", _confirm_delete)
	else:
		_who.setup(Firebase.email, "Your saves follow you to any device")
		_who.set_leading(ListRow.icon_tile("circle-user", DS.GREEN))
		_btn("Sync now", &"", "refresh-cw", _sync)
		_btn("Sign out", &"GhostButton", "log-out", _confirm_sign_out)
		_btn("Delete account", &"DestructiveButton", "trash-2", _confirm_delete)
	_update_status()


func _update_status() -> void:
	if not is_inside_tree():
		return
	var s := CloudSync.state()
	_state_title.text = str(s.title)
	_state_caption.text = str(s.caption)
	var tile := ListRow.icon_tile(str(s.icon), s.color)
	_state_icon.replace_by(tile)
	_state_icon.queue_free()
	_state_icon = tile
	# Which saves are safe?
	for ch in _saves.get_children():
		ch.queue_free()
	if not (Firebase.enabled() and Firebase.signed_in()):
		return
	for slot in range(1, SaveManager.SLOTS + 1):
		var o := SaveManager.summary(slot)
		if o.is_empty():
			continue
		var safe := CloudSync.is_backed_up(slot)
		var row := ListRow.new().setup(str(o.get("name", "?")), "Slot %d  ·  %s" % [slot, str(o.get("date", ""))],
			"In the cloud" if safe else "Waiting")
		row.trailing_label.theme_type_variation = &"Caption"
		row.trailing_label.add_theme_color_override(&"font_color", DS.GREEN if safe else DS.ORANGE)
		row.set_leading(Flag.new().show_country(World.index_of(str(o.get("country", ""))), 22.0))
		_saves.add_child(row)


func _confirm_sign_out() -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("log-out", DS.ACCENT, "Account", "Sign out?")
	m.body("Your saves stay on this phone and in your account. Sign in again any time to sync.%s" % (
		"" if CloudSync.pending() == 0 else "\n\n%d %s haven't uploaded yet." % [CloudSync.pending(), "save" if CloudSync.pending() == 1 else "saves"]))
	m.choice("Sign out", "", &"PrimaryButton", func() -> void:
		Firebase.sign_out()
		Haptics.tap()
		m.dismiss())
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


func _confirm_delete() -> void:
	var m := ModalCard.new()
	get_tree().current_scene.add_child(m)
	m.header("trash-2", DS.RED, "Delete account", "Delete your account?")
	m.body("This permanently deletes your account and every cloud save. It can't be undone. Saves on this phone stay.")
	m.choice("Delete permanently", "", &"DestructiveButton", func() -> void:
		m.dismiss()
		_busy_msg("Deleting…")
		var r: Dictionary = await Firebase.delete_account()
		if r.ok:
			Haptics.success()
			_busy_msg("Your account and cloud saves were deleted.")
		else:
			_error(str(r.get("error", "Couldn't delete the account."))))
	m.choice("Cancel", "", &"GhostButton", m.dismiss)


func _btn(text: String, variant: StringName, icon_: String, cb: Callable) -> void:
	var b := AppButton.make(text, variant, icon_)
	b.pressed.connect(cb)
	_buttons.add_child(b)


func _busy_msg(msg: String) -> void:
	_status.visible = true
	_status.text = msg
	_status.remove_theme_color_override(&"font_color")


func _error(msg: String) -> void:
	_status.visible = true
	_status.text = msg
	_status.add_theme_color_override(&"font_color", DS.RED)
	Haptics.warning()


func _sync() -> void:
	Haptics.tap()
	CloudSync.last_error = ""
	await CloudSync.flush()
	await CloudSync.pull_newer()
	if CloudSync.state().key == "ok":
		Haptics.success()


func _email_form(create: bool) -> void:
	AccountForm.open(get_tree().current_scene, create)
