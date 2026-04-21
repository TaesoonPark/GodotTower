extends Node
class_name EnemyFlowFieldService

const MAX_FIELDS: int = 8
const BASE_MAX_BUILDS_PER_FRAME: int = 1
const HASH_REFRESH_SEC: float = 0.15
const HASH_BUCKET_TILES: float = 2.0
const SEPARATION_RADIUS_TILES: float = 0.9
const SEPARATION_WEIGHT: float = 0.55
const FIELD_INF_COST: int = 2147483647
const ORTH_COST: int = 10
const DIAG_COST: int = 14

var tile_size: float = 40.0
var world_size: Vector2 = Vector2(7680.0, 4320.0)

var _occupancy: Node = null
var _revision: int = 0
var _field_cache: Dictionary = {}
var _lru_tick: int = 0
var _frame_id: int = -1
var _frame_builds: int = 0
var _unit_buckets: Dictionary = {}
var _next_hash_refresh_ms: int = 0
var _debug_stats: Dictionary = {
	"cache_hits": 0,
	"cache_misses": 0,
	"field_builds": 0,
	"build_deferred": 0,
	"build_failed": 0,
	"cache_evictions": 0,
	"hash_units": 0,
	"last_expansions": 0,
	"last_field_size": 0,
	"last_build_ms": 0.0,
	"direct_clear": 0
}

func setup(next_tile_size: float, next_world_size: Vector2, occupancy: Node) -> void:
	tile_size = maxf(4.0, next_tile_size)
	world_size = next_world_size
	_occupancy = occupancy
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("get_revision"):
		_revision = int(_occupancy.get_revision())

func notify_obstacle_revision(revision: int) -> void:
	if revision == _revision:
		return
	_revision = revision
	_field_cache.clear()

func get_flow_direction(current_pos: Vector2, goal_pos: Vector2, self_id: int) -> Vector2:
	_refresh_unit_hash_if_due()
	var direct_dir: Vector2 = _direct_direction_if_clear(current_pos, goal_pos)
	if direct_dir != Vector2.ZERO:
		_debug_stats["direct_clear"] = int(_debug_stats.get("direct_clear", 0)) + 1
		return _apply_separation(direct_dir, current_pos, self_id)
	var goal_tile: Vector2i = _clamp_tile(_world_to_tile(goal_pos))
	var cache_key: String = _field_cache_key(goal_tile)
	var field: Dictionary = {}
	if _field_cache.has(cache_key):
		field = _field_cache[cache_key]
		_debug_stats["cache_hits"] = int(_debug_stats.get("cache_hits", 0)) + 1
	else:
		_debug_stats["cache_misses"] = int(_debug_stats.get("cache_misses", 0)) + 1
		if not _can_build_this_frame():
			_debug_stats["build_deferred"] = int(_debug_stats.get("build_deferred", 0)) + 1
			return Vector2.ZERO
		field = _build_field(goal_tile)
		if field.is_empty():
			_debug_stats["build_failed"] = int(_debug_stats.get("build_failed", 0)) + 1
			return Vector2.ZERO
		_field_cache[cache_key] = field
		_prune_field_cache()
		_debug_stats["field_builds"] = int(_debug_stats.get("field_builds", 0)) + 1
	_lru_tick += 1
	field["last_used"] = _lru_tick
	var flow_dir: Vector2 = _direction_from_field(field, current_pos)
	if flow_dir == Vector2.ZERO:
		return Vector2.ZERO
	return _apply_separation(flow_dir, current_pos, self_id)

func _apply_separation(flow_dir: Vector2, current_pos: Vector2, self_id: int) -> Vector2:
	var separation: Vector2 = _separation_for(current_pos, self_id)
	var combined: Vector2 = flow_dir + separation * SEPARATION_WEIGHT
	if combined.length_squared() <= 0.0001:
		return flow_dir
	return combined.normalized()

func get_debug_stats() -> Dictionary:
	return _debug_stats.duplicate(true)

func _field_cache_key(goal_tile: Vector2i) -> String:
	return "enemy:%d:%d:%d" % [_revision, goal_tile.x, goal_tile.y]

func _can_build_this_frame() -> bool:
	var fid: int = Engine.get_physics_frames()
	if _frame_id != fid:
		_frame_id = fid
		_frame_builds = 0
	if _frame_builds >= BASE_MAX_BUILDS_PER_FRAME:
		return false
	_frame_builds += 1
	return true

func _prune_field_cache() -> void:
	while _field_cache.size() > MAX_FIELDS:
		var oldest_key: String = ""
		var oldest_used: int = 2147483647
		for key in _field_cache.keys():
			var field: Dictionary = _field_cache[key]
			var used: int = int(field.get("last_used", 0))
			if oldest_key == "" or used < oldest_used:
				oldest_key = String(key)
				oldest_used = used
		if oldest_key == "":
			return
		_field_cache.erase(oldest_key)
		_debug_stats["cache_evictions"] = int(_debug_stats.get("cache_evictions", 0)) + 1

func _build_field(goal_tile: Vector2i) -> Dictionary:
	var build_start_us: int = Time.get_ticks_usec()
	var width: int = _max_tile_x() + 1
	var height: int = _max_tile_y() + 1
	var cell_count: int = width * height
	if cell_count <= 0:
		return {}
	var walkable: PackedByteArray = _build_walkable_map(goal_tile, width, height)
	var costs := PackedInt32Array()
	costs.resize(cell_count)
	costs.fill(FIELD_INF_COST)
	var closed := PackedByteArray()
	closed.resize(cell_count)
	var goal_idx: int = _tile_index(goal_tile.x, goal_tile.y, width)
	costs[goal_idx] = 0
	var heap_costs := PackedInt32Array()
	var heap_indexes := PackedInt32Array()
	_heap_push_index(heap_costs, heap_indexes, goal_idx, 0)
	var expansions: int = 0
	var reachable: int = 0
	while heap_indexes.size() > 0:
		var best_idx: int = _heap_pop_index(heap_costs, heap_indexes)
		if closed[best_idx] != 0:
			continue
		closed[best_idx] = 1
		expansions += 1
		reachable += 1
		var bx: int = best_idx % width
		var by: int = int(best_idx / width)
		var best_cost: int = costs[best_idx]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = bx + dx
				var ny: int = by + dy
				if nx < 0 or nx >= width or ny < 0 or ny >= height:
					continue
				var next_idx: int = _tile_index(nx, ny, width)
				if walkable[next_idx] == 0:
					continue
				if dx != 0 and dy != 0:
					if walkable[_tile_index(nx, by, width)] == 0:
						continue
					if walkable[_tile_index(bx, ny, width)] == 0:
						continue
				if closed[next_idx] != 0:
					continue
				var step_cost: int = DIAG_COST if dx != 0 and dy != 0 else ORTH_COST
				var next_cost: int = best_cost + step_cost
				if next_cost >= costs[next_idx]:
					continue
				costs[next_idx] = next_cost
				_heap_push_index(heap_costs, heap_indexes, next_idx, next_cost)
	_debug_stats["last_expansions"] = expansions
	_debug_stats["last_field_size"] = reachable
	_debug_stats["last_build_ms"] = float(Time.get_ticks_usec() - build_start_us) / 1000.0
	if reachable <= 1:
		return {}
	return {
		"costs": costs,
		"walkable": walkable,
		"width": width,
		"height": height,
		"goal": goal_tile,
		"last_used": _lru_tick
	}

func _direction_from_field(field: Dictionary, current_pos: Vector2) -> Vector2:
	var current_tile: Vector2i = _clamp_tile(_world_to_tile(current_pos))
	var goal_tile: Vector2i = field.get("goal", current_tile)
	if current_tile == goal_tile:
		return Vector2.ZERO
	var costs: PackedInt32Array = field.get("costs", PackedInt32Array())
	var walkable: PackedByteArray = field.get("walkable", PackedByteArray())
	var width: int = int(field.get("width", 0))
	var height: int = int(field.get("height", 0))
	if costs.is_empty() or walkable.is_empty() or width <= 0 or height <= 0:
		return Vector2.ZERO
	if current_tile.x < 0 or current_tile.x >= width or current_tile.y < 0 or current_tile.y >= height:
		return Vector2.ZERO
	var current_idx: int = _tile_index(current_tile.x, current_tile.y, width)
	var current_cost: int = costs[current_idx]
	var best_cost: int = FIELD_INF_COST
	var best_tile: Vector2i = current_tile
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = current_tile.x + dx
			var ny: int = current_tile.y + dy
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			var next_idx: int = _tile_index(nx, ny, width)
			if walkable[next_idx] == 0:
				continue
			if dx != 0 and dy != 0:
				if walkable[_tile_index(nx, current_tile.y, width)] == 0:
					continue
				if walkable[_tile_index(current_tile.x, ny, width)] == 0:
					continue
			var next_cost: int = costs[next_idx]
			if next_cost >= FIELD_INF_COST:
				continue
			if current_cost < FIELD_INF_COST and next_cost >= current_cost:
				continue
			if next_cost < best_cost:
				best_cost = next_cost
				best_tile = Vector2i(nx, ny)
	if best_tile == current_tile:
		return Vector2.ZERO
	return Vector2(float(best_tile.x - current_tile.x), float(best_tile.y - current_tile.y)).normalized()

func _build_walkable_map(goal_tile: Vector2i, width: int, height: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(width * height)
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("get_enemy_blocked_tile_keys"):
		out.fill(1)
		for key_any in _occupancy.get_enemy_blocked_tile_keys():
			var key: int = int(key_any)
			var tx: int = _key_to_x(key)
			var ty: int = _key_to_y(key)
			if tx < 0 or tx >= width or ty < 0 or ty >= height:
				continue
			out[_tile_index(tx, ty, width)] = 0
		out[_tile_index(goal_tile.x, goal_tile.y, width)] = 1
	else:
		for ty in range(height):
			for tx in range(width):
				var idx: int = _tile_index(tx, ty, width)
				out[idx] = 1 if _tile_walkable(tx, ty, goal_tile.x, goal_tile.y) else 0
	return out

func _direct_direction_if_clear(current_pos: Vector2, goal_pos: Vector2) -> Vector2:
	if current_pos.distance_squared_to(goal_pos) <= 36.0:
		return Vector2.ZERO
	var current_tile: Vector2i = _clamp_tile(_world_to_tile(current_pos))
	var goal_tile: Vector2i = _clamp_tile(_world_to_tile(goal_pos))
	if current_tile == goal_tile:
		return Vector2.ZERO
	if _enemy_blocked_tile_count() <= 0:
		return current_pos.direction_to(goal_pos)
	if _tile_line_clear(current_tile, goal_tile):
		return current_pos.direction_to(goal_pos)
	return Vector2.ZERO

func _enemy_blocked_tile_count() -> int:
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("get_enemy_blocked_tile_count"):
		return int(_occupancy.get_enemy_blocked_tile_count())
	return 1

func _tile_line_clear(start: Vector2i, goal: Vector2i) -> bool:
	var x: int = start.x
	var y: int = start.y
	var dx: int = absi(goal.x - start.x)
	var dy: int = absi(goal.y - start.y)
	var sx: int = 1 if start.x < goal.x else -1
	var sy: int = 1 if start.y < goal.y else -1
	var err: int = dx - dy
	while true:
		if x == goal.x and y == goal.y:
			return true
		var prev_x: int = x
		var prev_y: int = y
		var e2: int = err * 2
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
		if _tile_blocked_for_enemy(Vector2i(x, y)):
			return false
		if x != prev_x and y != prev_y:
			if _tile_blocked_for_enemy(Vector2i(x, prev_y)):
				return false
			if _tile_blocked_for_enemy(Vector2i(prev_x, y)):
				return false
	return true

func _tile_blocked_for_enemy(tile: Vector2i) -> bool:
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("is_enemy_tile_blocked"):
		return bool(_occupancy.is_enemy_tile_blocked(tile))
	return not _tile_walkable(tile.x, tile.y, 999999, 999999)

func _refresh_unit_hash_if_due() -> void:
	if get_tree() == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_hash_refresh_ms:
		return
	_next_hash_refresh_ms = now_ms + int(round(HASH_REFRESH_SEC * 1000.0))
	_unit_buckets.clear()
	var count: int = 0
	for group_name in [&"raiders", &"zombies", &"colonists"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node):
				continue
			if not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			var pos: Vector2 = (node as Node2D).global_position
			var bucket_key: int = _bucket_key(_world_to_bucket(pos))
			if not _unit_buckets.has(bucket_key):
				_unit_buckets[bucket_key] = []
			_unit_buckets[bucket_key].append({
				"id": node.get_instance_id(),
				"pos": pos
			})
			count += 1
	_debug_stats["hash_units"] = count

func _separation_for(current_pos: Vector2, self_id: int) -> Vector2:
	var bucket: Vector2i = _world_to_bucket(current_pos)
	var radius: float = tile_size * SEPARATION_RADIUS_TILES
	var radius_sq: float = radius * radius
	var out: Vector2 = Vector2.ZERO
	for by in range(bucket.y - 1, bucket.y + 2):
		for bx in range(bucket.x - 1, bucket.x + 2):
			var key: int = _bucket_key(Vector2i(bx, by))
			if not _unit_buckets.has(key):
				continue
			for entry in _unit_buckets[key]:
				if int(entry.get("id", 0)) == self_id:
					continue
				var other_pos: Vector2 = entry.get("pos", current_pos)
				var offset: Vector2 = current_pos - other_pos
				var dist_sq: float = offset.length_squared()
				if dist_sq <= 0.0001 or dist_sq > radius_sq:
					continue
				var dist: float = sqrt(dist_sq)
				out += offset / dist * (1.0 - dist / radius)
	if out.length_squared() > 1.0:
		return out.normalized()
	return out

func _heap_push_index(heap_costs: PackedInt32Array, heap_indexes: PackedInt32Array, idx: int, score: int) -> void:
	heap_costs.append(score)
	heap_indexes.append(idx)
	var pi: int = heap_costs.size() - 1
	while pi > 0:
		var pp: int = (pi - 1) >> 1
		if heap_costs[pp] <= score:
			break
		var parent_cost: int = heap_costs[pp]
		var parent_idx: int = heap_indexes[pp]
		heap_costs[pi] = parent_cost
		heap_indexes[pi] = parent_idx
		heap_costs[pp] = score
		heap_indexes[pp] = idx
		pi = pp

func _heap_pop_index(heap_costs: PackedInt32Array, heap_indexes: PackedInt32Array) -> int:
	var h_size: int = heap_costs.size()
	var best_idx: int = heap_indexes[0]
	if h_size == 1:
		heap_costs.resize(0)
		heap_indexes.resize(0)
		return best_idx
	h_size -= 1
	var last_cost: int = heap_costs[h_size]
	var last_idx: int = heap_indexes[h_size]
	heap_costs.resize(h_size)
	heap_indexes.resize(h_size)
	heap_costs[0] = last_cost
	heap_indexes[0] = last_idx
	var si: int = 0
	while true:
		var sl: int = 2 * si + 1
		if sl >= h_size:
			break
		var sr: int = sl + 1
		var sm: int = si
		var smallest_cost: int = last_cost
		var left_cost: int = heap_costs[sl]
		if left_cost < smallest_cost:
			sm = sl
			smallest_cost = left_cost
		if sr < h_size:
			var right_cost: int = heap_costs[sr]
			if right_cost < smallest_cost:
				sm = sr
		if sm == si:
			break
		heap_costs[si] = heap_costs[sm]
		heap_indexes[si] = heap_indexes[sm]
		heap_costs[sm] = last_cost
		heap_indexes[sm] = last_idx
		si = sm
	return best_idx

func _tile_walkable(tx: int, ty: int, gx: int, gy: int) -> bool:
	if tx == gx and ty == gy:
		return true
	if not _in_bounds_tile(tx, ty):
		return false
	if _occupancy != null and is_instance_valid(_occupancy) and _occupancy.has_method("is_blocked_for_enemy"):
		return not bool(_occupancy.is_blocked_for_enemy(Vector2(float(tx) * tile_size, float(ty) * tile_size)))
	return true

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _clamp_tile(tile: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(tile.x, 0, _max_tile_x()),
		clampi(tile.y, 0, _max_tile_y())
	)

func _in_bounds_tile(tx: int, ty: int) -> bool:
	return tx >= 0 and tx <= _max_tile_x() and ty >= 0 and ty <= _max_tile_y()

func _max_tile_x() -> int:
	return maxi(0, int(round(world_size.x / tile_size)))

func _max_tile_y() -> int:
	return maxi(0, int(round(world_size.y / tile_size)))

func _tile_index(tx: int, ty: int, width: int) -> int:
	return ty * width + tx

func _key_to_x(key: int) -> int:
	return ((key >> 16) & 0xFFFF) - 32768

func _key_to_y(key: int) -> int:
	return (key & 0xFFFF) - 32768

func _world_to_bucket(world_pos: Vector2) -> Vector2i:
	var bucket_size: float = tile_size * HASH_BUCKET_TILES
	return Vector2i(
		int(floor(world_pos.x / bucket_size)),
		int(floor(world_pos.y / bucket_size))
	)

func _bucket_key(bucket: Vector2i) -> int:
	return ((bucket.x + 32768) & 0xFFFF) << 16 | ((bucket.y + 32768) & 0xFFFF)
