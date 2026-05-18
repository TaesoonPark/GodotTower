extends RefCounted
class_name GameSprite

const UNIT_PATHS: Dictionary = {
	&"colonist": "res://assets/sprites/units/colonist.png",
	&"raider": "res://assets/sprites/units/raider.png",
	&"zombie": "res://assets/sprites/units/zombie.png"
}

const COLONIST_FRAME_PATHS: Dictionary = {
	&"idle_front": "res://assets/sprites/units/colonist_frames/idle_front.png",
	&"idle_left": "res://assets/sprites/units/colonist_frames/idle_left.png",
	&"idle_right": "res://assets/sprites/units/colonist_frames/idle_right.png",
	&"idle_back": "res://assets/sprites/units/colonist_frames/idle_back.png",
	&"walk_front_0": "res://assets/sprites/units/colonist_frames/walk_front_0.png",
	&"walk_front_1": "res://assets/sprites/units/colonist_frames/walk_front_1.png",
	&"walk_left_0": "res://assets/sprites/units/colonist_frames/walk_left_0.png",
	&"walk_left_1": "res://assets/sprites/units/colonist_frames/walk_left_1.png",
	&"walk_right_0": "res://assets/sprites/units/colonist_frames/walk_right_0.png",
	&"walk_right_1": "res://assets/sprites/units/colonist_frames/walk_right_1.png",
	&"walk_back_0": "res://assets/sprites/units/colonist_frames/walk_back_0.png",
	&"walk_back_1": "res://assets/sprites/units/colonist_frames/walk_back_1.png",
	&"walk_front_alt_0": "res://assets/sprites/units/colonist_frames/walk_front_alt_0.png",
	&"walk_front_alt_1": "res://assets/sprites/units/colonist_frames/walk_front_alt_1.png",
	&"walk_back_alt_0": "res://assets/sprites/units/colonist_frames/walk_back_alt_0.png",
	&"walk_back_alt_1": "res://assets/sprites/units/colonist_frames/walk_back_alt_1.png",
	&"aim_front": "res://assets/sprites/units/colonist_frames/aim_front.png",
	&"aim_left": "res://assets/sprites/units/colonist_frames/aim_left.png",
	&"aim_right": "res://assets/sprites/units/colonist_frames/aim_right.png",
	&"aim_back": "res://assets/sprites/units/colonist_frames/aim_back.png",
	&"hurt_0": "res://assets/sprites/units/colonist_frames/hurt_0.png",
	&"downed_0": "res://assets/sprites/units/colonist_frames/downed_0.png"
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

const FARM_PATHS: Dictionary = {
	&"field_empty": "res://assets/sprites/farm/field_empty.png"
}

const TERRAIN_PATHS: Dictionary = {
	&"asphalt_0": "res://assets/sprites/terrain/asphalt_0.png",
	&"asphalt_1": "res://assets/sprites/terrain/asphalt_1.png",
	&"asphalt_2": "res://assets/sprites/terrain/asphalt_2.png",
	&"asphalt_3": "res://assets/sprites/terrain/asphalt_3.png"
}

const WALL_VARIANT_PATHS: Dictionary = {
	&"horizontal": "res://assets/sprites/buildings/wall.png",
	&"vertical": "res://assets/sprites/buildings/wall_vertical.png",
	&"corner_up_right": "res://assets/sprites/buildings/wall_corner_up_right.png",
	&"corner_up_left": "res://assets/sprites/buildings/wall_corner_up_left.png",
	&"corner_down_right": "res://assets/sprites/buildings/wall_corner_down_right.png",
	&"corner_down_left": "res://assets/sprites/buildings/wall_corner_down_left.png"
}

const FIRING_WALL_VARIANT_PATHS: Dictionary = {
	&"horizontal": "res://assets/sprites/buildings/firing_wall.png",
	&"vertical": "res://assets/sprites/buildings/firing_wall_vertical.png",
	&"corner_up_right": "res://assets/sprites/buildings/firing_wall_corner_up_right.png",
	&"corner_up_left": "res://assets/sprites/buildings/firing_wall_corner_up_left.png",
	&"corner_down_right": "res://assets/sprites/buildings/firing_wall_corner_down_right.png",
	&"corner_down_left": "res://assets/sprites/buildings/firing_wall_corner_down_left.png"
}

static var _texture_cache: Dictionary = {}

static func get_unit_texture(unit_id: StringName) -> Texture2D:
	var key: StringName = StringName(String(unit_id).to_lower())
	return _load_by_path(String(UNIT_PATHS.get(key, "")))

static func get_unit_frame_texture(unit_id: StringName, frame_id: StringName) -> Texture2D:
	var unit_key: String = _to_snake(String(unit_id).to_lower())
	var frame_key: String = String(frame_id).to_lower()
	if unit_key.is_empty() or frame_key.is_empty():
		return get_unit_texture(unit_id)
	var path: String = "res://assets/sprites/units/%s_frames/%s.png" % [unit_key, frame_key]
	var tex: Texture2D = _load_by_path(path)
	if tex != null:
		return tex
	return get_unit_texture(unit_id)

static func get_colonist_frame_texture(frame_id: StringName) -> Texture2D:
	return _load_by_path(String(COLONIST_FRAME_PATHS.get(frame_id, "")))

static func get_gatherable_texture(resource_type: StringName) -> Texture2D:
	return _load_by_path(String(GATHERABLE_PATHS.get(resource_type, "")))

static func get_huntable_texture(display_name: String) -> Texture2D:
	var key: StringName = StringName(display_name.to_lower())
	return _load_by_path(String(HUNTABLE_PATHS.get(key, "")))

static func get_farm_texture(texture_id: StringName) -> Texture2D:
	return _load_by_path(String(FARM_PATHS.get(texture_id, "")))

static func get_terrain_texture(texture_id: StringName) -> Texture2D:
	return _load_by_path(String(TERRAIN_PATHS.get(texture_id, "")))

static func get_drop_texture(resource_type: StringName) -> Texture2D:
	var key: String = _to_snake(String(resource_type))
	var path: String = "res://assets/sprites/drops/%s.png" % key
	if not _path_exists(path):
		return null
	return _load_by_path(path)

static func get_building_texture(building_id: StringName, rotation_index: int = 0) -> Texture2D:
	if building_id == &"Wall":
		return get_wall_texture(&"horizontal", building_id)
	if building_id == &"FiringWall":
		return get_wall_texture(&"horizontal", building_id)
	var key: String = _to_snake(String(building_id))
	var variant_path: String = "res://assets/sprites/buildings/%s_%s.png" % [key, _building_rotation_suffix(rotation_index)]
	if _path_exists(variant_path):
		return _load_by_path(variant_path)
	var path: String = "res://assets/sprites/buildings/%s.png" % key
	if not _path_exists(path):
		return null
	return _load_by_path(path)

static func _building_rotation_suffix(rotation_index: int) -> String:
	match int(posmod(rotation_index, 4)):
		1:
			return "east"
		2:
			return "north"
		3:
			return "west"
		_:
			return "south"

static func get_wall_texture(variant: StringName, building_id: StringName = &"Wall") -> Texture2D:
	var paths: Dictionary = FIRING_WALL_VARIANT_PATHS if building_id == &"FiringWall" else WALL_VARIANT_PATHS
	var path: String = String(paths.get(variant, paths[&"horizontal"]))
	return _load_by_path(path)

static func refresh_all_wall_variants(tree: SceneTree, grid_size: float) -> void:
	if tree == null:
		return
	var cell: float = maxf(4.0, grid_size)
	var walls_by_tile: Dictionary = _collect_wall_nodes_by_tile(tree, cell)
	for key in walls_by_tile.keys():
		_apply_wall_variant_with_map(walls_by_tile[key], walls_by_tile, cell)

static func refresh_wall_variants_around(tree: SceneTree, center: Vector2, grid_size: float) -> void:
	if tree == null or center == Vector2.INF:
		return
	var cell: float = maxf(4.0, grid_size)
	var walls_by_tile: Dictionary = _collect_wall_nodes_by_tile(tree, cell)
	var center_tile: Vector2i = _wall_tile_for_pos(center, cell)
	var offsets: Array[Vector2i] = [
		Vector2i.ZERO,
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN
	]
	var updated: Dictionary = {}
	for offset in offsets:
		var key: String = _wall_tile_key(center_tile + offset)
		if not walls_by_tile.has(key):
			continue
		var node: Node = walls_by_tile[key]
		var instance_id: int = node.get_instance_id()
		if updated.has(instance_id):
			continue
		updated[instance_id] = true
		_apply_wall_variant_with_map(node, walls_by_tile, cell)

static func apply_wall_variant(node: Node, tree: SceneTree, grid_size: float) -> void:
	if node == null or tree == null:
		return
	var cell: float = maxf(4.0, grid_size)
	_apply_wall_variant_with_map(node, _collect_wall_nodes_by_tile(tree, cell), cell)

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

static func _collect_wall_nodes_by_tile(tree: SceneTree, grid_size: float) -> Dictionary:
	var out: Dictionary = {}
	var seen: Dictionary = {}
	for group_name in [&"build_sites", &"structures"]:
		for candidate in tree.get_nodes_in_group(group_name):
			if not (candidate is Node):
				continue
			var node: Node = candidate
			if not _is_wall_node(node):
				continue
			var instance_id: int = node.get_instance_id()
			if seen.has(instance_id):
				continue
			seen[instance_id] = true
			var pos: Vector2 = _node_global_position(node)
			if pos == Vector2.INF:
				continue
			out[_wall_tile_key(_wall_tile_for_pos(pos, grid_size))] = node
	return out

static func _apply_wall_variant_with_map(node: Node, walls_by_tile: Dictionary, grid_size: float) -> void:
	if not _is_wall_node(node):
		return
	var sprite: Sprite2D = _find_wall_sprite(node)
	if sprite == null:
		return
	var tile: Vector2i = _wall_tile_for_pos(_node_global_position(node), grid_size)
	var left: bool = walls_by_tile.has(_wall_tile_key(tile + Vector2i.LEFT))
	var right: bool = walls_by_tile.has(_wall_tile_key(tile + Vector2i.RIGHT))
	var up: bool = walls_by_tile.has(_wall_tile_key(tile + Vector2i.UP))
	var down: bool = walls_by_tile.has(_wall_tile_key(tile + Vector2i.DOWN))
	var variant: StringName = _wall_variant_for_connections(left, right, up, down)
	var tex: Texture2D = get_wall_texture(variant, _wall_building_id(node))
	if tex != null:
		sprite.texture = tex
	node.set_meta("wall_sprite_variant", variant)

static func _wall_variant_for_connections(left: bool, right: bool, up: bool, down: bool) -> StringName:
	var horizontal_count: int = int(left) + int(right)
	var vertical_count: int = int(up) + int(down)
	if horizontal_count == 1 and vertical_count == 1:
		if up and right:
			return &"corner_up_right"
		if up and left:
			return &"corner_up_left"
		if down and right:
			return &"corner_down_right"
		if down and left:
			return &"corner_down_left"
	if vertical_count > horizontal_count:
		return &"vertical"
	return &"horizontal"

static func _is_wall_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_queued_for_deletion() or not node.is_inside_tree():
		return false
	var building_id: StringName = &""
	if node.has_meta("building_id"):
		building_id = StringName(node.get_meta("building_id"))
	else:
		var property_value: Variant = node.get("building_id")
		if property_value != null:
			building_id = StringName(property_value)
	return building_id == &"Wall" or building_id == &"FiringWall"

static func _wall_building_id(node: Node) -> StringName:
	if node == null:
		return &""
	if node.has_meta("building_id"):
		return StringName(node.get_meta("building_id"))
	var property_value: Variant = node.get("building_id")
	if property_value == null:
		return &""
	return StringName(property_value)

static func _find_wall_sprite(node: Node) -> Sprite2D:
	var base_sprite: Node = node.get_node_or_null("BaseSprite")
	if base_sprite is Sprite2D:
		return base_sprite as Sprite2D
	for child in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null

static func _node_global_position(node: Node) -> Vector2:
	if node is Node2D:
		return (node as Node2D).global_position
	return Vector2.INF

static func _wall_tile_for_pos(pos: Vector2, grid_size: float) -> Vector2i:
	return Vector2i(int(round(pos.x / grid_size)), int(round(pos.y / grid_size)))

static func _wall_tile_key(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]

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
