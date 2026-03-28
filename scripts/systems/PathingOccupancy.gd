extends Node
class_name PathingOccupancy

@export var tile_size: float = 40.0

signal revision_changed(revision: int)

var _blocked_friendly: Dictionary = {}
var _blocked_enemy: Dictionary = {}
var _layout_signature: int = 0
var _revision: int = 1

func _ready() -> void:
	_rebuild_maps()

func setup(next_tile_size: float) -> void:
	tile_size = maxf(4.0, next_tile_size)
	if is_inside_tree():
		_rebuild_maps()

func notify_world_changed() -> void:
	if get_tree() == null:
		return
	_rebuild_maps()

func is_blocked_for_friendly(world_pos: Vector2) -> bool:
	return _blocked_friendly.has(_tile_key(_world_to_tile(world_pos)))

func is_blocked_for_enemy(world_pos: Vector2) -> bool:
	return _blocked_enemy.has(_tile_key(_world_to_tile(world_pos)))

func get_revision() -> int:
	return _revision

func _rebuild_maps() -> void:
	if get_tree() == null:
		return
	var blockers: Array = get_tree().get_nodes_in_group("blocking_structures")
	var build_sites: Array = get_tree().get_nodes_in_group("build_sites")
	var sig: int = _compute_layout_signature(blockers, build_sites)
	if sig == _layout_signature:
		return
	_blocked_friendly.clear()
	_blocked_enemy.clear()
	for node in blockers:
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(tile_size, tile_size)
		var passable_for_friendly: bool = bool(node.get_meta("passable_for_friendly"))
		_mark_footprint(node.global_position, footprint, _blocked_enemy)
		if not passable_for_friendly:
			_mark_footprint(node.global_position, footprint, _blocked_friendly)
	for site in build_sites:
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(tile_size, tile_size)
		_mark_footprint(site.global_position, footprint, _blocked_friendly)
	_layout_signature = sig
	_revision += 1
	revision_changed.emit(_revision)

func _mark_footprint(center: Vector2, footprint: Vector2, target_map: Dictionary) -> void:
	var half: Vector2 = footprint * 0.5
	var min_tile: Vector2i = _world_to_tile_ceil(center - half)
	var max_tile: Vector2i = _world_to_tile_floor(center + half)
	if min_tile.x > max_tile.x or min_tile.y > max_tile.y:
		var single: Vector2i = _world_to_tile(center)
		target_map[_tile_key(single)] = true
		return
	for ty in range(min_tile.y, max_tile.y + 1):
		for tx in range(min_tile.x, max_tile.x + 1):
			target_map[_tile_key(Vector2i(tx, ty))] = true

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _world_to_tile_floor(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / tile_size)),
		int(floor(world_pos.y / tile_size))
	)

func _world_to_tile_ceil(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(ceil(world_pos.x / tile_size)),
		int(ceil(world_pos.y / tile_size))
	)

func _tile_key(tile: Vector2i) -> int:
	var packed_x: int = (tile.x + 32768) & 0xFFFF
	var packed_y: int = (tile.y + 32768) & 0xFFFF
	return (packed_x << 16) | packed_y

func _compute_layout_signature(blockers: Array, build_sites: Array) -> int:
	var sig: int = 17
	for node in blockers:
		if node == null or not is_instance_valid(node):
			continue
		var blocks_movement: bool = bool(node.get_meta("blocks_movement"))
		if not blocks_movement:
			continue
		var tile: Vector2i = _world_to_tile(node.global_position)
		var passable_for_friendly: bool = bool(node.get_meta("passable_for_friendly"))
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(tile_size, tile_size)
		var footprint_sig: int = int(round(footprint.x)) * 73856093 + int(round(footprint.y)) * 19349663
		sig = int((sig * 131 + node.get_instance_id()) % 2147483647)
		sig = int((sig * 131 + _tile_key(tile)) % 2147483647)
		sig = int((sig * 131 + (1 if blocks_movement else 0)) % 2147483647)
		sig = int((sig * 131 + (1 if passable_for_friendly else 0)) % 2147483647)
		sig = int((sig * 131 + footprint_sig) % 2147483647)
	for site in build_sites:
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var tile_site: Vector2i = _world_to_tile(site.global_position)
		var site_footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(tile_size, tile_size)
		var site_footprint_sig: int = int(round(site_footprint.x)) * 83492791 + int(round(site_footprint.y)) * 2971215073
		sig = int((sig * 131 + site.get_instance_id()) % 2147483647)
		sig = int((sig * 131 + _tile_key(tile_site)) % 2147483647)
		sig = int((sig * 131 + site_footprint_sig) % 2147483647)
	return sig
