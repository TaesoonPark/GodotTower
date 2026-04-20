extends Node
class_name EnemyFlowFieldService

const MAX_FIELDS: int = 8
const BASE_MAX_BUILDS_PER_FRAME: int = 1
const HASH_REFRESH_SEC: float = 0.15
const HASH_BUCKET_TILES: float = 2.0
const SEPARATION_RADIUS_TILES: float = 0.9
const SEPARATION_WEIGHT: float = 0.55
const FIELD_INF: float = 1.0e20

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
	"last_field_size": 0
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
	var goal_key: int = _tile_key(goal_tile)
	var costs: Dictionary = {goal_key: 0.0}
	var closed: Dictionary = {}
	var hf := PackedFloat64Array()
	var hk := PackedInt64Array()
	hf.append(0.0)
	hk.append(goal_key)
	var expansions: int = 0
	while hk.size() > 0:
		var best_key: int = _heap_pop_key(hf, hk)
		if closed.has(best_key):
			continue
		closed[best_key] = true
		expansions += 1
		var bx: int = _key_to_x(best_key)
		var by: int = _key_to_y(best_key)
		var best_cost: float = float(costs.get(best_key, FIELD_INF))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = bx + dx
				var ny: int = by + dy
				if not _in_bounds_tile(nx, ny):
					continue
				if not _tile_walkable(nx, ny, goal_tile.x, goal_tile.y):
					continue
				if dx != 0 and dy != 0:
					if not _tile_walkable(nx, by, goal_tile.x, goal_tile.y):
						continue
					if not _tile_walkable(bx, ny, goal_tile.x, goal_tile.y):
						continue
				var next_key: int = _tile_key(Vector2i(nx, ny))
				if closed.has(next_key):
					continue
				var step_cost: float = 1.41421356 if dx != 0 and dy != 0 else 1.0
				var next_cost: float = best_cost + step_cost
				if next_cost >= float(costs.get(next_key, FIELD_INF)):
					continue
				costs[next_key] = next_cost
				_heap_push(hf, hk, next_key, next_cost)
	_debug_stats["last_expansions"] = expansions
	_debug_stats["last_field_size"] = costs.size()
	if costs.size() <= 1:
		return {}
	return {
		"costs": costs,
		"goal": goal_tile,
		"last_used": _lru_tick
	}

func _direction_from_field(field: Dictionary, current_pos: Vector2) -> Vector2:
	var current_tile: Vector2i = _clamp_tile(_world_to_tile(current_pos))
	var goal_tile: Vector2i = field.get("goal", current_tile)
	if current_tile == goal_tile:
		return Vector2.ZERO
	var costs: Dictionary = field.get("costs", {})
	if costs.is_empty():
		return Vector2.ZERO
	var current_key: int = _tile_key(current_tile)
	var current_cost: float = float(costs.get(current_key, FIELD_INF))
	var best_cost: float = FIELD_INF
	var best_tile: Vector2i = current_tile
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = current_tile.x + dx
			var ny: int = current_tile.y + dy
			if not _in_bounds_tile(nx, ny):
				continue
			if not _tile_walkable(nx, ny, goal_tile.x, goal_tile.y):
				continue
			if dx != 0 and dy != 0:
				if not _tile_walkable(nx, current_tile.y, goal_tile.x, goal_tile.y):
					continue
				if not _tile_walkable(current_tile.x, ny, goal_tile.x, goal_tile.y):
					continue
			var next_key: int = _tile_key(Vector2i(nx, ny))
			if not costs.has(next_key):
				continue
			var next_cost: float = float(costs[next_key])
			if current_cost < FIELD_INF and next_cost >= current_cost - 0.001:
				continue
			if next_cost < best_cost:
				best_cost = next_cost
				best_tile = Vector2i(nx, ny)
	if best_tile == current_tile:
		return Vector2.ZERO
	return Vector2(float(best_tile.x - current_tile.x), float(best_tile.y - current_tile.y)).normalized()

func _refresh_unit_hash_if_due() -> void:
	if get_tree() == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_hash_refresh_ms:
		return
	_next_hash_refresh_ms = now_ms + int(round(HASH_REFRESH_SEC * 1000.0))
	_unit_buckets.clear()
	var count: int = 0
	for group_name in [&"raiders", &"zombies"]:
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

func _heap_push(hf: PackedFloat64Array, hk: PackedInt64Array, key: int, score: float) -> void:
	hf.append(score)
	hk.append(key)
	var pi: int = hf.size() - 1
	while pi > 0:
		var pp: int = (pi - 1) >> 1
		if hf[pp] <= score:
			break
		var ppf: float = hf[pp]
		var ppk: int = hk[pp]
		hf[pi] = ppf
		hk[pi] = ppk
		hf[pp] = score
		hk[pp] = key
		pi = pp

func _heap_pop_key(hf: PackedFloat64Array, hk: PackedInt64Array) -> int:
	var h_size: int = hf.size()
	var best_key: int = hk[0]
	if h_size == 1:
		hf.resize(0)
		hk.resize(0)
		return best_key
	h_size -= 1
	var lf: float = hf[h_size]
	var lk: int = hk[h_size]
	hf.resize(h_size)
	hk.resize(h_size)
	hf[0] = lf
	hk[0] = lk
	var si: int = 0
	while true:
		var sl: int = 2 * si + 1
		if sl >= h_size:
			break
		var sr: int = sl + 1
		var sm: int = si
		var sf: float = lf
		var clf: float = hf[sl]
		if clf < sf:
			sm = sl
			sf = clf
		if sr < h_size:
			var crf: float = hf[sr]
			if crf < sf:
				sm = sr
		if sm == si:
			break
		hf[si] = hf[sm]
		hk[si] = hk[sm]
		hf[sm] = lf
		hk[sm] = lk
		si = sm
	return best_key

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

func _tile_key(tile: Vector2i) -> int:
	return ((tile.x + 32768) & 0xFFFF) << 16 | ((tile.y + 32768) & 0xFFFF)

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
