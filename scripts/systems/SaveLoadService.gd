extends Node
class_name SaveLoadService

var _owner: Node = null
var _save_dir: String = "user://saves"
var _file_suffix: String = "_autosave.json"
var _default_slot_id: String = "slot_0"
var _save_version: int = 1
var _in_progress: bool = false

func setup(owner_node: Node, save_dir: String, file_suffix: String, default_slot_id: String, save_version: int) -> void:
	_owner = owner_node
	_save_dir = save_dir
	_file_suffix = file_suffix
	_default_slot_id = default_slot_id
	_save_version = save_version

func is_in_progress() -> bool:
	return _in_progress

func has_save_slot(slot_id: String = "") -> bool:
	return FileAccess.file_exists(save_slot_path(slot_id))

func delete_save_slot(slot_id: String = "") -> bool:
	if _in_progress:
		return false
	var path: String = save_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return true
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Autosave delete failed: %s" % error_string(err))
		return false
	return true

func save_game_to_slot(slot_id: String = "") -> bool:
	if _in_progress or _owner == null or not is_instance_valid(_owner):
		return false
	var safe_slot: String = sanitize_save_slot_id(slot_id)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_dir))
	if dir_error != OK:
		push_warning("Autosave directory create failed: %s" % error_string(dir_error))
		return false
	var path: String = save_slot_path(safe_slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Autosave open failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	_in_progress = true
	var payload: Dictionary = _owner._build_save_payload(safe_slot)
	file.store_string(JSON.stringify(payload, "\t"))
	_in_progress = false
	return true

func load_game_from_slot(slot_id: String = "") -> bool:
	if _in_progress or _owner == null or not is_instance_valid(_owner):
		return false
	var path: String = save_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("Autosave parse failed: %s" % path)
		return false
	var payload: Dictionary = parsed
	if int(payload.get("version", 0)) != _save_version:
		push_warning("Autosave version mismatch: %s" % path)
		return false
	_in_progress = true
	var ok: bool = bool(_owner._apply_save_payload(payload))
	_in_progress = false
	return ok

func save_slot_path(slot_id: String = "") -> String:
	return "%s/%s%s" % [_save_dir, sanitize_save_slot_id(slot_id), _file_suffix]

func sanitize_save_slot_id(slot_id: String = "") -> String:
	var safe: String = slot_id.strip_edges()
	safe = safe.replace("/", "_").replace("\\", "_").replace(":", "_").replace("..", "_")
	if safe.is_empty():
		return _default_slot_id
	return safe
