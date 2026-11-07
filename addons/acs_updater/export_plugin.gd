@tool
extends EditorPlugin
## Registers the AcsUpdater Android AAR with Godot's Android (Gradle) export.
## Source: android/plugin (Kotlin). Rebuild with android/plugin/build_plugin.sh.

var _export_plugin: AcsUpdaterExportPlugin


func _enter_tree() -> void:
	_export_plugin = AcsUpdaterExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AcsUpdaterExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "AcsUpdater"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(["acs_updater/bin/acs_updater-%s.aar" % ("debug" if debug else "release")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.13.1"])

	func _get_name() -> String:
		return PLUGIN_NAME
