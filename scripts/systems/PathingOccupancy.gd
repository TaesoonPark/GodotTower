extends Node
class_name PathingOccupancy

@export var tile_size: float = 64.0

signal revision_changed(revision: int)

var _blocked_friendly: Dictionary = {}
var _blocked_enemy: Dictionary = {}
var _combat_blocked_tiles: Dictionary = {}
var _combat_blocked_next_refresh_ms: int = 0
var _layout_signature: int = 0
var _revision: int = 1
var _debug_stats: Dictionary = {
	"dynamic_refreshes": 0,
	"dynamic_units": 0,
	"last_dynamic_ms": 0.0
}
const COMBAT_BLOCKED_REFRESH_MS: int = 50

func _ready() -> void:
	_rebuild_maps()

func setup(next_tile_size: float) -> void:
	tile_size = maxf(4.0, next_tile_size)
	if is_inside_tree():
		_rebuild_maps()

func notify_world_changed() -> void:
	if not is_inside_tree():
		return
	_rebuild_maps()

func is_blocked_for_friendly(world_pos: Vector2) -> bool:
	return _blocked_friendly.has(_tile_key(_world_to_tile(world_pos)))

func is_blocked_for_enemy(world_pos: Vector2) -> bool:
	return _blocked_enemy.has(_tile_key(_world_to_tile(world_pos)))

func is_dynamic_combat_blocked(world_pos: Vector2, self_id: int = 0) -> bool:
	_refresh_combat_blocked_tiles()
	var ids: Array = _combat_blocked_tiles.get(_tile_key(_world_to_tile(world_pos)), [])
	if ids.is_empty():
		return false
	for id_any in ids:
		if int(id_any) != self_id:
			return true
	return false

func invalidate_dynamic_combat_blockers() -> void:
	_combat_blocked_tiles.clear()
	_combat_blocked_next_refresh_ms = 0

func is_enemy_tile_blocked(tile: Vector2i) -> bool:
	return _blocked_enemy.has(_tile_key(tile))

func get_enemy_blocked_tile_count() -> int:
	return _blocked_enemy.size()

func get_enemy_blocked_tile_keys() -> Array:
	return _blocked_enemy.keys()

func get_revision() -> int:
	return _revision

func get_debug_stats() -> Dictionary:
	return _debug_stats.duplicate(true)

func _rebuild_maps() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	var blockers: Array = tree.get_nodes_in_group("blocking_structures")
	var build_sites: Array = tree.get_nodes_in_group("build_sites")
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

func _refresh_combat_blocked_tiles() -> void:
	if not is_inside_tree():
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _combat_blocked_next_refresh_ms:
		return
	var start_us: int = Time.get_ticks_usec()
	_combat_blocked_next_refresh_ms = now_ms + COMBAT_BLOCKED_REFRESH_MS
	_combat_blocked_tiles.clear()
	var unit_count: int = 0
	var tree: SceneTree = get_tree()
	var groups: Array[StringName] = [&"colonists", &"raiders", &"zombies"]
	for group_name in groups:
		for node in tree.get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node):
				continue
			if not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			if not _is_node_in_combat_blocking_state(node):
				continue
			var key: int = _tile_key(_world_to_tile((node as Node2D).global_position))
			var ids: Array = _combat_blocked_tiles.get(key, [])
			ids.append(node.get_instance_id())
			_combat_blocked_tiles[key] = ids
			unit_count += 1
	_debug_stats["dynamic_refreshes"] = int(_debug_stats.get("dynamic_refreshes", 0)) + 1
	_debug_stats["dynamic_units"] = unit_count
	_debug_stats["last_dynamic_ms"] = float(Time.get_ticks_usec() - start_us) / 1000.0

func _is_node_in_combat_blocking_state(node: Node) -> bool:
	if node.get("combat_ready") == true:
		return true
	if node.has_method("is_melee_combat_locked") and bool(node.is_melee_combat_locked()):
		return true
	var job_variant: Variant = node.get("current_job")
	if job_variant is Dictionary:
		var job: Dictionary = job_variant
		if StringName(job.get("type", &"")) == &"CombatRanged":
			return true
	var enemy_lock_variant: Variant = node.get("_melee_lock_target_id")
	if enemy_lock_variant != null and int(enemy_lock_variant) != 0:
		return true
	var enemy_target_variant: Variant = node.get("_target_colonist_id")
	if enemy_target_variant != null and int(enemy_target_variant) != 0 and node.has_method("get_current_weapon_mode") and StringName(node.get_current_weapon_mode()) == &"Ranged":
		return true
	return false

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
