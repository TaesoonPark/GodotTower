extends RefCounted
class_name GameText

const TEXT_FILE_PATH := "res://data/text/ui_texts_ko.json"

static var _loaded: bool = false
static var _table: Dictionary = {}

static func get_text(key: String, params: Dictionary = {}, fallback: String = "") -> String:
	_ensure_loaded()
	var template_any: Variant = _table.get(key, fallback if not fallback.is_empty() else key)
	var template: String = str(template_any)
	if params.is_empty():
		return template
	return _format_template(template, params)


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(TEXT_FILE_PATH):
		printerr("[GameText] missing text file: %s" % TEXT_FILE_PATH)
		return
	var raw: String = FileAccess.get_file_as_string(TEXT_FILE_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_table = parsed
		return
	printerr("[GameText] invalid json format: %s" % TEXT_FILE_PATH)


static func _format_template(template: String, params: Dictionary) -> String:
	var out: String = template
	for key_any in params.keys():
		var key: String = str(key_any)
		out = out.replace("{%s}" % key, str(params[key_any]))
	return out
