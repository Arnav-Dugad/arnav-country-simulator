extends Node
## Demo-store test: purchase flow, entitlements, theme activation, subscription, reset.
## Run: godot --headless --path . res://tools/store_test.tscn  (add -- --keep to leave Gold Leaf active)
var _fails := 0
func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	_fails += 0 if ok else 1
func _ready() -> void:
	Store.reset_demo()
	_check(not Store.owns_product("theme_gold") and MapModes.active_theme() == "default", "starts clean")
	Settings.set_value("map_theme", "gold")
	_check(MapModes.active_theme() == "default", "unowned theme is not applied")
	var r: Dictionary = await Store.purchase("theme_gold")
	_check(r.ok and Store.owns_product("theme_gold"), "buy Gold Leaf")
	_check(MapModes.active_theme() == "gold", "owned theme applies")
	r = await Store.purchase("themes_all")
	_check(Store.owns("theme_aurora") and Store.owns("theme_ember"), "bundle grants all themes")
	r = await Store.purchase("pass_monthly")
	_check(Store.owns_product("pass_monthly") and Store.owns("pass"), "subscribe monthly")
	r = await Store.purchase("pass_yearly")
	_check(Store.owns_product("pass_yearly") and not Store.owns_product("pass_monthly"), "switch to yearly")
	Store.cancel_subscription()
	_check(not Store.owns("pass"), "cancel subscription")
	r = await Store.purchase("tip_coffee")
	_check(Store.owns("supporter") and not Store.owns_product("tip_coffee"), "tips grant badge, stay buyable")
	_check(Store.price_text("pass_yearly") == "$14.99 / year", "price text")
	if "--keep" in OS.get_cmdline_user_args():
		Store.reset_demo()
		await Store.purchase("theme_gold")
		Settings.set_value("map_theme", "gold")
	else:
		Store.reset_demo()
		_check(MapModes.active_theme() == "default", "reset demo")
	print("STORE TEST %s (%d failures)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit()
