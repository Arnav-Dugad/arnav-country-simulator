class_name AccountForm
extends ModalCard
## Email account form (create or sign in) in a glass modal. Used by onboarding
## and Settings. Emits `succeeded` once the account is ready.

signal succeeded

var create := true
var _mail: LineEdit
var _pw: LineEdit
var _msg: Label
var _busy := false


## Opens the form. (Loaded by path rather than by class name: a static function
## naming its own class creates a script reference cycle that leaks at exit.)
static func open(parent: Node, create_account: bool) -> ModalCard:
	var f: ModalCard = load("res://ui/components/account_form.gd").new()
	f.set(&"create", create_account)
	parent.add_child(f)
	return f


func _ready() -> void:
	header("mail", DS.ACCENT, "Your account", "Create your free account" if create else "Welcome back")
	body("Back up your nation and continue on any device. Your current progress comes with you."
		if create else "Sign in to restore your saved games.")
	_mail = LineEdit.new()
	_mail.placeholder_text = "Email address"
	_mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	content.add_child(_mail)
	_pw = LineEdit.new()
	_pw.placeholder_text = "Password (at least 6 characters)"
	_pw.secret = true
	_pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
	_pw.text_submitted.connect(func(_t: String) -> void: _submit())
	content.add_child(_pw)
	_msg = Label.new()
	_msg.theme_type_variation = &"Footnote"
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_msg)
	choice("Create account" if create else "Sign in", "", &"PrimaryButton", _submit)
	if not create:
		choice("Forgot password?", "", &"GhostButton", _reset)
	choice("Cancel", "", &"GhostButton", dismiss)
	super._ready()


func _submit() -> void:
	if _busy:
		return
	var mail := _mail.text.strip_edges()
	if not mail.contains("@") or not mail.contains("."):
		_show("Please enter a valid email address.", false)
		return
	if _pw.text.length() < 6:
		_show("Use at least 6 characters for your password.", false)
		return
	_busy = true
	_show("Just a moment…", true)
	var r: Dictionary
	if create:
		r = await Firebase.sign_up_email(mail, _pw.text)
	else:
		r = await Firebase.sign_in_email(mail, _pw.text)
	_busy = false
	if r.ok:
		Haptics.success()
		succeeded.emit()
		dismiss()
	else:
		_show(str(r.error), false)
		Haptics.warning()


func _reset() -> void:
	var r: Dictionary = await Firebase.send_password_reset(_mail.text.strip_edges())
	_show("We sent a reset link to your email." if r.ok else str(r.error), r.ok)


func _show(text: String, neutral: bool) -> void:
	_msg.text = text
	_msg.add_theme_color_override(&"font_color", DS.TEXT_2 if neutral else DS.RED)
