extends RefCounted
class_name GameSprite

const UNIT_PATHS: Dictionary = {
	&"colonist": "res://assets/sprites/units/colonist.png",
	&"raider": "res://assets/sprites/units/raider.png",
	&"zombie": "res://assets/sprites/units/zombie.png"
}

const GATHERABLE_PATHS: Dictionary = {
	&"Wood": "res://assets/sprites/gatherables/wood_tree.png",
	&"Stone": "res://assets/sprites/gatherables/stone_ore.png",
	&"Steel": "res://assets/sprites/gatherables/steel_ore.png",
	&"FoodRaw": "res://assets/sprites/gatherables/berry_bush.png"
}

const HUNTABLE_PATHS: Dictionary = {
	&"boar": "res://assets/sprites/huntables/boar.png",
	&"deer": "res://assets/sprites/huntables/deer.png"
}

static var _texture_cache: Dictionary = {}

static func get_unit_texture(unit_id: StringName) -> Texture2D:
	var key: StringName = StringName(String(unit_id).to_lower())
	return _load_by_path(String(UNIT_PATHS.get(key, "")))

static func get_gatherable_texture(resource_type: StringName) -> Texture2D:
	return _load_by_path(String(GATHERABLE_PATHS.get(resource_type, "")))

static func get_huntable_texture(display_name: String) -> Texture2D:
	var key: StringName = StringName(display_name.to_lower())
	return _load_by_path(String(HUNTABLE_PATHS.get(key, "")))

static func get_drop_texture(resource_type: StringName) -> Texture2D:
	var key: String = _to_snake(String(resource_type))
	var path: String = "res://assets/sprites/drops/%s.png" % key
	if not _path_exists(path):
		return null
	return _load_by_path(path)

static func get_building_texture(building_id: StringName) -> Texture2D:
	var key: String = _to_snake(String(building_id))
	var path: String = "res://assets/sprites/buildings/%s.png" % key
	if not _path_exists(path):
		return null
	return _load_by_path(path)

static func get_crop_texture(crop_id: StringName, stage: StringName) -> Texture2D:
	var crop_key: String = _to_snake(String(crop_id))
	var stage_key: String = _to_snake(String(stage))
	if crop_key.is_empty() or stage_key.is_empty():
		return null
	var path: String = "res://assets/sprites/crops/%s_%s.png" % [crop_key, stage_key]
	if not _path_exists(path):
		return null
	return _load_by_path(path)

static func _load_by_path(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			tex = loaded as Texture2D
	if tex == null:
		var image_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(image_path):
			var image: Image = Image.load_from_file(image_path)
			if image != null and not image.is_empty():
				tex = ImageTexture.create_from_image(image)
	_texture_cache[path] = tex
	return tex

static func _path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(path))

static func _to_snake(value: String) -> String:
	var out: String = ""
	for i in range(value.length()):
		var ch: String = value[i]
		if ch == " " or ch == "-":
			out += "_"
			continue
		var lower: String = ch.to_lower()
		var upper: String = ch.to_upper()
		var is_letter: bool = lower != upper
		var is_upper: bool = is_letter and ch == upper
		if is_upper and i > 0:
			var prev: String = value[i - 1]
			var prev_lower: String = prev.to_lower()
			var prev_upper: String = prev.to_upper()
			var prev_is_letter: bool = prev_lower != prev_upper
			var prev_is_upper: bool = prev_is_letter and prev == prev_upper
			if not prev_is_upper and out.length() > 0 and out[out.length() - 1] != "_":
				out += "_"
		out += lower
	return out
