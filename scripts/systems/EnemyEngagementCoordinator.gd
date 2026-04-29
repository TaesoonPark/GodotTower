extends Node
class_name EnemyEngagementCoordinator

const ACTIVE_MELEE_PURSUERS_PER_TARGET: int = 12
const ACTIVE_REFRESH_MS: int = 200
const MELEE_GOAL_CACHE_MS: int = 1600
const MELEE_SLOT_MAX_RING: int = 8
const STAGING_MIN_RING: int = 4

var tile_size: float = 64.0
var _occupancy: Node = null
var _frame_id: int = -1
var _occupied_ids_by_cell: Dictionary = {}
var _claim_ids_by_cell: Dictionary = {}
var _target_context_by_id: Dictionary = {}
var _active_cache_by_target_id: Dictionary = {}
var _slot_sort_origin: Vector2 = Vector2.ZERO
var _debug_stats: Dictionary = {
	"requests": 0,
	"target_context_builds": 0,
	"active_refreshes": 0,
	"cell_cache_builds": 0,
	"last_request_ms": 0.0,
	"total_request_ms": 0.0,
	"active_limit": ACTIVE_MELEE_PURSUERS_PER_TARGET
}

func setup(next_tile_size: float, occupancy: Node) -> void:
	tile_size = maxf(4.0, next_tile_size)
	_occupancy = occupancy

func request_melee_goal(enemy: Node2D, target: Node2D, attack_range: float) -> Vector2:
	var start_us: int = Time.get_ticks_usec()
	_debug_stats["requests"] = int(_debug_stats.get("requests", 0)) + 1
	if enemy == null or target == null or not is_instance_valid(enemy) or not is_instance_valid(target):
		return _finish_request(start_us, Vector2.INF)
	_refresh_frame_cache(Time.get_ticks_msec())
	var target_id: int = target.get_instance_id()
	var target_cell: Vector2 = _snap_to_tile(target.global_position)
	var enemy_id: int = enemy.get_instance_id()
	var context: Dictionary = _get_target_context(target)
	var active_ids: Array = context.get("active_ids", [])
	var is_locked: bool = _get_node_int(enemy, "_melee_lock_target_id") == target_id
	if not is_locked and active_ids.find(enemy_id) < 0:
		return _finish_request(start_us, _resolve_staging_goal(enemy, target_cell, attack_range))
	return _finish_request(start_us, _resolve_active_melee_goal(enemy, target_id, target_cell, attack_range, context))

func is_melee_cell_available(enemy: Node2D, cell: Vector2) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	_refresh_frame_cache(Time.get_ticks_msec())
	return _is_cell_available_for(enemy, cell, true)

func register_melee_claim(enemy: Node2D, cell: Vector2) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _frame_id != Engine.get_physics_frames():
		return
	_add_id_to_cell_cache(_claim_ids_by_cell, cell, enemy.get_instance_id())

func get_debug_stats() -> Dictionary:
	return _debug_stats.duplicate(true)

func _finish_request(start_us: int, goal: Vector2) -> Vector2:
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_us) / 1000.0
	_debug_stats["last_request_ms"] = elapsed_ms
	_debug_stats["total_request_ms"] = float(_debug_stats.get("total_request_ms", 0.0)) + elapsed_ms
	return goal

func _refresh_frame_cache(now_ms: int) -> void:
	var next_frame_id: int = Engine.get_physics_frames()
	if _frame_id == next_frame_id:
		return
	_frame_id = next_frame_id
	_occupied_ids_by_cell.clear()
	_claim_ids_by_cell.clear()
	_target_context_by_id.clear()
	_debug_stats["cell_cache_builds"] = int(_debug_stats.get("cell_cache_builds", 0)) + 1
	for group_name in [&"colonists", &"raiders", &"zombies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node) or not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			var node_id: int = node.get_instance_id()
			_add_id_to_cell_cache(_occupied_ids_by_cell, (node as Node2D).global_position, node_id)
			_add_node_claims(node, node_id, now_ms)

func _get_target_context(target: Node2D) -> Dictionary:
	var target_id: int = target.get_instance_id()
	if _target_context_by_id.has(target_id):
		return _target_context_by_id[target_id]
	var active_ids: Array = _get_active_pursuer_ids(target)
	var context: Dictionary = {
		"active_ids": active_ids
	}
	_target_context_by_id[target_id] = context
	_debug_stats["target_context_builds"] = int(_debug_stats.get("target_context_builds", 0)) + 1
	return context

func _get_active_pursuer_ids(target: Node2D) -> Array:
	var target_id: int = target.get_instance_id()
	var now_ms: int = Time.get_ticks_msec()
	var cached: Dictionary = _active_cache_by_target_id.get(target_id, {})
	if not cached.is_empty() and now_ms < int(cached.get("next_ms", 0)):
		return Array(cached.get("ids", []))
	var locked_ids: Array[int] = []
	var candidates: Array = []
	for group_name in [&"raiders", &"zombies"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node) or not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			if node.has_method("get_current_weapon_mode") and StringName(node.get_current_weapon_mode()) == &"Ranged":
				continue
			var node_target_id: int = _get_node_int(node, "_melee_lock_target_id")
			var locked: bool = node_target_id == target_id
			if node_target_id == 0:
				node_target_id = _get_node_int(node, "_target_colonist_id")
			if node_target_id != target_id:
				continue
			var node_id: int = node.get_instance_id()
			if locked:
				locked_ids.append(node_id)
				continue
			candidates.append({
				"id": node_id,
				"dist_sq": (node as Node2D).global_position.distance_squared_to(target.global_position)
			})
	candidates.sort_custom(Callable(self, "_compare_attacker_entry"))
	var active_ids: Array[int] = locked_ids.duplicate()
	for entry_any in candidates:
		if active_ids.size() >= ACTIVE_MELEE_PURSUERS_PER_TARGET:
			break
		var entry: Dictionary = entry_any
		active_ids.append(int(entry.get("id", 0)))
	active_ids.sort()
	_active_cache_by_target_id[target_id] = {
		"ids": active_ids,
		"next_ms": now_ms + ACTIVE_REFRESH_MS
	}
	_debug_stats["active_refreshes"] = int(_debug_stats.get("active_refreshes", 0)) + 1
	return active_ids

func _compare_attacker_entry(a: Dictionary, b: Dictionary) -> bool:
	var dist_a: float = float(a.get("dist_sq", 0.0))
	var dist_b: float = float(b.get("dist_sq", 0.0))
	if not is_equal_approx(dist_a, dist_b):
		return dist_a < dist_b
	return int(a.get("id", 0)) < int(b.get("id", 0))

func _resolve_active_melee_goal(enemy: Node2D, target_id: int, target_cell: Vector2, attack_range: float, context: Dictionary) -> Vector2:
	var own_cell: Vector2 = _snap_to_tile(enemy.global_position)
	var own_ring: int = _cell_ring(own_cell, target_cell)
	var engagement_ring: int = _engagement_ring(attack_range)
	var active_ids: Array = context.get("active_ids", [])
	var allowed_ring: int = maxi(_allowed_ring(active_ids.size()), engagement_ring)
	var require_step_available: bool = own_ring <= allowed_ring + 2
	if own_ring >= 1 and own_ring <= engagement_ring and _cell_in_weapon_range(own_cell, target_cell, attack_range) and _is_cell_available_for(enemy, own_cell, true):
		_register_goal_claim(enemy, target_id, own_cell)
		return own_cell
	var cached_goal: Vector2 = _valid_cached_goal(enemy, target_id, target_cell, attack_range, allowed_ring, require_step_available)
	if cached_goal != Vector2.INF:
		_register_goal_claim(enemy, target_id, cached_goal)
		return cached_goal
	var slots: Array[Vector2] = _sort_slots_by_distance(_build_slot_cells(target_cell, allowed_ring), enemy.global_position)
	var start_idx: int = active_ids.find(enemy.get_instance_id())
	if start_idx < 0:
		start_idx = absi(enemy.get_instance_id() + target_id) % maxi(1, slots.size())
	var in_range_goal: Vector2 = _select_goal_from_slots(enemy, slots, start_idx, target_cell, engagement_ring, attack_range, require_step_available, true)
	if in_range_goal != Vector2.INF:
		_register_goal_claim(enemy, target_id, in_range_goal)
		return in_range_goal
	if own_ring >= 1 and own_ring <= allowed_ring and _is_cell_available_for(enemy, own_cell, true):
		_register_goal_claim(enemy, target_id, own_cell)
		return own_cell
	var allowed_goal: Vector2 = _select_goal_from_slots(enemy, slots, start_idx, target_cell, allowed_ring, attack_range, require_step_available, false)
	if allowed_goal != Vector2.INF:
		_register_goal_claim(enemy, target_id, allowed_goal)
		return allowed_goal
	return own_cell

func _resolve_staging_goal(enemy: Node2D, target_cell: Vector2, attack_range: float) -> Vector2:
	var staging_ring: int = clampi(maxi(STAGING_MIN_RING, _engagement_ring(attack_range) + 3), 1, MELEE_SLOT_MAX_RING)
	var slots: Array[Vector2] = _build_single_ring_slots(target_cell, staging_ring)
	var start_idx: int = _closest_slot_index(slots, enemy.global_position)
	if not slots.is_empty():
		start_idx = (start_idx + absi(enemy.get_instance_id()) % mini(5, slots.size())) % slots.size()
	for offset in range(slots.size()):
		var idx: int = (start_idx + offset) % slots.size()
		var candidate: Vector2 = slots[idx]
		if _is_cell_available_for(enemy, candidate, false):
			_add_id_to_cell_cache(_claim_ids_by_cell, candidate, enemy.get_instance_id())
			return candidate
	return _snap_to_tile(enemy.global_position)

func _closest_slot_index(slots: Array[Vector2], origin: Vector2) -> int:
	var best_idx: int = 0
	var best_dist_sq: float = INF
	for i in range(slots.size()):
		var dist_sq: float = origin.distance_squared_to(slots[i])
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_idx = i
	return best_idx

func _valid_cached_goal(enemy: Node2D, target_id: int, target_cell: Vector2, attack_range: float, allowed_ring: int, require_step_available: bool) -> Vector2:
	if _get_node_int(enemy, "_melee_goal_cache_target_id") != target_id:
		return Vector2.INF
	if _get_node_int(enemy, "_melee_goal_cache_next_ms") <= Time.get_ticks_msec():
		return Vector2.INF
	var cache_cell_variant: Variant = enemy.get("_melee_goal_cache_cell")
	if not (cache_cell_variant is Vector2):
		return Vector2.INF
	var cached_cell: Vector2 = _snap_to_tile(cache_cell_variant)
	var cached_ring: int = _cell_ring(cached_cell, target_cell)
	var engagement_ring: int = _engagement_ring(attack_range)
	if cached_ring < 1 or cached_ring > allowed_ring:
		return Vector2.INF
	if cached_ring <= engagement_ring and not _cell_in_weapon_range(cached_cell, target_cell, attack_range):
		return Vector2.INF
	if require_step_available and not _is_goal_step_available(enemy, cached_cell):
		return Vector2.INF
	if not _is_cell_available_for(enemy, cached_cell, false):
		return Vector2.INF
	return cached_cell

func _select_goal_from_slots(enemy: Node2D, slots: Array[Vector2], start_idx: int, target_cell: Vector2, max_ring: int, attack_range: float, require_step_available: bool, must_be_in_weapon_range: bool) -> Vector2:
	for offset in range(slots.size()):
		var idx: int = (start_idx + offset) % slots.size()
		var candidate: Vector2 = slots[idx]
		var ring: int = _cell_ring(candidate, target_cell)
		if ring > max_ring:
			continue
		if must_be_in_weapon_range and not _cell_in_weapon_range(candidate, target_cell, attack_range):
			continue
		if require_step_available and not _is_goal_step_available(enemy, candidate):
			continue
		if _is_cell_available_for(enemy, candidate, false):
			return candidate
	return Vector2.INF

func _register_goal_claim(enemy: Node2D, target_id: int, cell: Vector2) -> void:
	_add_id_to_cell_cache(_claim_ids_by_cell, cell, enemy.get_instance_id())
	enemy.set("_melee_goal_cache_target_id", target_id)
	enemy.set("_melee_goal_cache_cell", _snap_to_tile(cell))
	enemy.set("_melee_goal_cache_next_ms", Time.get_ticks_msec() + MELEE_GOAL_CACHE_MS)

func _is_goal_step_available(enemy: Node2D, desired: Vector2) -> bool:
	var own_cell: Vector2 = _snap_to_tile(enemy.global_position)
	var desired_cell: Vector2 = _snap_to_tile(desired)
	var step_x: float = 0.0
	var step_y: float = 0.0
	if desired_cell.x > own_cell.x + 0.1:
		step_x = tile_size
	elif desired_cell.x < own_cell.x - 0.1:
		step_x = -tile_size
	if desired_cell.y > own_cell.y + 0.1:
		step_y = tile_size
	elif desired_cell.y < own_cell.y - 0.1:
		step_y = -tile_size
	var step_cell: Vector2 = _snap_to_tile(own_cell + Vector2(step_x, step_y))
	return step_cell.distance_to(own_cell) <= 0.1 or _is_cell_available_for(enemy, step_cell, false)

func _is_cell_available_for(enemy: Node2D, cell: Vector2, ignore_claim_if_self_on_cell: bool) -> bool:
	var snapped: Vector2 = _snap_to_tile(cell)
	var enemy_id: int = enemy.get_instance_id()
	var enemy_cell: Vector2 = _snap_to_tile(enemy.global_position)
	if snapped.distance_to(enemy_cell) > 0.1 and _is_static_blocked(snapped):
		return false
	var occupied_ids: Array = _occupied_ids_by_cell.get(_cell_key(snapped), [])
	for id_any in occupied_ids:
		if int(id_any) != enemy_id:
			return false
	if ignore_claim_if_self_on_cell and snapped.distance_to(enemy_cell) <= 0.1:
		return true
	var claim_ids: Array = _claim_ids_by_cell.get(_cell_key(snapped), [])
	for id_any in claim_ids:
		if int(id_any) != enemy_id:
			return false
	return true

func _is_static_blocked(cell: Vector2) -> bool:
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("is_blocked_for_enemy"):
		return bool(_occupancy.is_blocked_for_enemy(cell))
	return false

func _add_node_claims(node: Node, node_id: int, now_ms: int) -> void:
	if not _node_has_active_melee_goal(node):
		return
	var step_next_ms: int = _get_node_int(node, "_melee_step_claim_next_ms")
	if step_next_ms > now_ms:
		var step_cell_variant: Variant = node.get("_melee_step_claim_cell")
		if step_cell_variant is Vector2:
			_add_id_to_cell_cache(_claim_ids_by_cell, step_cell_variant, node_id)
	var cache_next_ms: int = _get_node_int(node, "_melee_goal_cache_next_ms")
	if cache_next_ms <= now_ms:
		return
	var cache_target_id: int = _get_node_int(node, "_melee_goal_cache_target_id")
	if cache_target_id == 0:
		return
	var cache_cell_variant: Variant = node.get("_melee_goal_cache_cell")
	if cache_cell_variant is Vector2:
		_add_id_to_cell_cache(_claim_ids_by_cell, cache_cell_variant, node_id)

func _node_has_active_melee_goal(node: Node) -> bool:
	var job_variant: Variant = node.get("current_job")
	if job_variant is Dictionary:
		var job: Dictionary = job_variant
		if StringName(job.get("type", &"")) == &"CombatMelee":
			return true
	if _get_node_int(node, "_melee_lock_target_id") != 0:
		return true
	var target_id: int = _get_node_int(node, "_target_colonist_id")
	if target_id == 0:
		return false
	if node.has_method("get_current_weapon_mode"):
		return StringName(node.get_current_weapon_mode()) != &"Ranged"
	return true

func _add_id_to_cell_cache(cache: Dictionary, cell: Vector2, node_id: int) -> void:
	var key: int = _cell_key(cell)
	var ids: Array = cache.get(key, [])
	if ids.find(node_id) < 0:
		ids.append(node_id)
	cache[key] = ids

func _build_slot_cells(target_cell: Vector2, max_ring: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	for ring in range(1, clampi(max_ring, 1, MELEE_SLOT_MAX_RING) + 1):
		slots.append_array(_build_single_ring_slots(target_cell, ring))
	return slots

func _build_single_ring_slots(target_cell: Vector2, ring: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	for y in range(-ring, ring + 1):
		for x in range(-ring, ring + 1):
			if maxi(absi(x), absi(y)) != ring:
				continue
			slots.append(_snap_to_tile(target_cell + Vector2(float(x) * tile_size, float(y) * tile_size)))
	return slots

func _sort_slots_by_distance(slots: Array[Vector2], origin: Vector2) -> Array[Vector2]:
	var ordered: Array[Vector2] = slots.duplicate()
	_slot_sort_origin = origin
	ordered.sort_custom(Callable(self, "_compare_slot_distance"))
	return ordered

func _compare_slot_distance(a: Vector2, b: Vector2) -> bool:
	var dist_a: float = _slot_sort_origin.distance_squared_to(a)
	var dist_b: float = _slot_sort_origin.distance_squared_to(b)
	if not is_equal_approx(dist_a, dist_b):
		return dist_a < dist_b
	if not is_equal_approx(a.y, b.y):
		return a.y < b.y
	return a.x < b.x

func _cell_in_weapon_range(cell: Vector2, target_cell: Vector2, attack_range: float) -> bool:
	var ring: int = _cell_ring(cell, target_cell)
	return ring >= 1 and ring <= _engagement_ring(attack_range)

func _cell_ring(cell: Vector2, target_cell: Vector2) -> int:
	if cell == Vector2.INF:
		return MELEE_SLOT_MAX_RING + 1
	var dx: int = absi(int(round((cell.x - target_cell.x) / tile_size)))
	var dy: int = absi(int(round((cell.y - target_cell.y) / tile_size)))
	return maxi(dx, dy)

func _allowed_ring(attacker_count: int) -> int:
	var required: int = MELEE_SLOT_MAX_RING
	for ring in range(1, MELEE_SLOT_MAX_RING + 1):
		if attacker_count <= 4 * ring * (ring + 1):
			required = ring
			break
	return mini(MELEE_SLOT_MAX_RING, required + 1)

func _engagement_ring(attack_range: float) -> int:
	return clampi(int(ceil(maxf(1.0, attack_range) / tile_size)), 1, MELEE_SLOT_MAX_RING)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / tile_size) * tile_size,
		round(world_pos.y / tile_size) * tile_size
	)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _cell_key(world_pos: Vector2) -> int:
	var tile: Vector2i = _world_to_tile(world_pos)
	var packed_x: int = (tile.x + 32768) & 0xFFFF
	var packed_y: int = (tile.y + 32768) & 0xFFFF
	return (packed_x << 16) | packed_y

func _get_node_int(node: Node, property_name: StringName, fallback: int = 0) -> int:
	var value: Variant = node.get(property_name)
	if value == null:
		return fallback
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback
