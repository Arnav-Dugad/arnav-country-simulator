class_name JsonUtil
extends RefCounted
## Parses JSON quietly: on failure it returns `fallback` and logs which source
## failed (the engine's JSON.parse_string only prints an anonymous error).


static func parse(text: String, source: String, fallback: Variant = null) -> Variant:
	if text.strip_edges() == "":
		return fallback
	# A byte-order mark is checked by code point: an escaped "﻿" literal
	# can come out empty on some platforms, and begins_with("") is always true.
	if text.length() > 0 and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)
	var j := JSON.new()
	if j.parse(text) != OK:
		push_warning("JSON: could not parse %s (line %d: %s; starts %s)" % [source, j.get_error_line(),
			j.get_error_message(), text.left(24).c_escape()])
		return fallback
	return j.data
