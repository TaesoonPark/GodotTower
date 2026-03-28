extends RefCounted
class_name FriendlyPathing

const REPATH_INTERVAL_SEC: float = 0.6
const SEARCH_MARGIN_TILES: int = 14
const MAX_EXPANSIONS: int = 400
const GOAL_REPATH_DISTANCE_TILES: float = 1.4
const STUCK_REPATH_DISTANCE: float = 8.0
const STUCK_REPATH_TIME_SEC: float = 1.4
const MAX_REBUILDS_PER_FRAME: int = 1

static var _frame_id: int = -1
static var _frame_rebuilds: int = 0

var tile_size: float = 40.0
var _path_points: Array[Vector2] = []
var _path_index: int = 0
var _last_path_goal: Vector2 = Vector2.INF
var _repath_left: float = 0.0
var _last_obstacle_signature: int = 0
var _walkable_cache: Dictionary = {}
var _stuck_elapsed: float = 0.0
var _stuck_anchor: Vector2 = Vector2.INF
var _repath_interval_runtime: float = REPATH_INTERVAL_SEC
var _max_expansions_runtime: int = MAX_EXPANSIONS
var _move_result: Dictionary = {"position": Vector2.ZERO, "reached_goal": false, "blocked": false}

func setup(next_tile_size: float) -> void:
	tile_size = maxf(4.0, next_tile_size)

func set_budget_scale(scale: float) -> void:
	var s: float = clampf(scale, 1.0, 3.5)
	_repath_interval_runtime = REPATH_INTERVAL_SEC * s
	_max_expansions_runtime = maxi(50, int(round(float(MAX_EXPANSIONS) / s)))

func tick(delta: float) -> void:
	_repath_left = maxf(0.0, _repath_left - delta)

func clear() -> void:
	_path_points.clear()
	_path_index = 0
	_last_path_goal = Vector2.INF
	_stuck_elapsed = 0.0
	_stuck_anchor = Vector2.INF

func notify_obstacle_signature(signature: int) -> void:
	if signature == _last_obstacle_signature:
		return
	_last_obstacle_signature = signature
	_path_points.clear()
	_path_index = 0
	_repath_left = randf_range(0.0, 0.2)

func _set_result(pos: Vector2, reached: bool, blocked: bool) -> Dictionary:
	_move_result["position"] = pos
	_move_result["reached_goal"] = reached
	_move_result["blocked"] = blocked
	return _move_result

func _can_rebuild_this_frame() -> bool:
	var fid: int = Engine.get_process_frames()
	if _frame_id != fid:
		_frame_id = fid
		_frame_rebuilds = 0
	if _frame_rebuilds >= MAX_REBUILDS_PER_FRAME:
		return false
	_frame_rebuilds += 1
	return true

func move_step(current_pos: Vector2, goal_world: Vector2, speed: float, delta: float, is_blocked: Callable) -> Dictionary:
	var safe_delta: float = minf(delta, 0.05)
	var goal: Vector2 = _snap_to_tile(goal_world)
	if goal == Vector2.INF:
		clear()
		return _set_result(current_pos, true, false)
	if current_pos.distance_to(goal) <= 6.0:
		clear()
		return _set_result(current_pos, true, false)
	if _stuck_anchor == Vector2.INF:
		_stuck_anchor = current_pos
	if current_pos.distance_squared_to(_stuck_anchor) <= STUCK_REPATH_DISTANCE * STUCK_REPATH_DISTANCE:
		_stuck_elapsed += safe_delta
	else:
		_stuck_elapsed = 0.0
		_stuck_anchor = current_pos
	var goal_shifted: bool = _last_path_goal != Vector2.INF and goal.distance_squared_to(_last_path_goal) >= (tile_size * GOAL_REPATH_DISTANCE_TILES) * (tile_size * GOAL_REPATH_DISTANCE_TILES)
	var stuck_repath: bool = _stuck_elapsed >= STUCK_REPATH_TIME_SEC
	var path_empty: bool = _path_points.is_empty()
	var need_rebuild: bool = (_path_index >= _path_points.size()) or stuck_repath
	if path_empty and _repath_left <= 0.0:
		need_rebuild = true
	if _repath_left <= 0.0 and goal_shifted:
		need_rebuild = true
	var rebuilt_this_step: bool = false
	if need_rebuild and _can_rebuild_this_frame():
		_rebuild_path(current_pos, goal, is_blocked)
		rebuilt_this_step = true
	if _path_points.is_empty():
		var direct_dir: Vector2 = current_pos.direction_to(goal)
		if direct_dir != Vector2.ZERO:
			var direct_step: Vector2 = current_pos + direct_dir * speed * safe_delta
			if not bool(is_blocked.call(direct_step)):
				return _set_result(direct_step, false, false)
		return _set_result(current_pos, false, path_empty)
	var next_pos: Vector2 = _get_next_path_point(goal)
	var dir: Vector2 = current_pos.direction_to(next_pos)
	if dir == Vector2.ZERO:
		return _set_result(current_pos, false, false)
	var proposed: Vector2 = current_pos + dir * speed * safe_delta
	if bool(is_blocked.call(proposed)):
		if (_repath_left <= 0.0 or stuck_repath) and not rebuilt_this_step and _can_rebuild_this_frame():
			_rebuild_path(current_pos, goal, is_blocked)
			rebuilt_this_step = true
		next_pos = _get_next_path_point(goal)
		dir = current_pos.direction_to(next_pos)
		proposed = current_pos + dir * speed * safe_delta
		if bool(is_blocked.call(proposed)):
			return _set_result(current_pos, false, true)
	var out_pos: Vector2 = proposed
	if out_pos.distance_to(next_pos) <= 4.0 and not bool(is_blocked.call(next_pos)):
		out_pos = next_pos
		_path_index += 1
	return _set_result(out_pos, false, false)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / tile_size) * tile_size,
		round(world_pos.y / tile_size) * tile_size
	)

func _world_to_tile_vec(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _get_next_path_point(goal: Vector2) -> Vector2:
	if _path_points.is_empty() or _path_index >= _path_points.size():
		return goal
	return _path_points[_path_index]

func _tile_walkable(tx: int, ty: int, gx: int, gy: int, is_blocked: Callable) -> bool:
	if tx == gx and ty == gy:
		return true
	var key: int = ((tx + 32768) & 0xFFFF) << 16 | ((ty + 32768) & 0xFFFF)
	if _walkable_cache.has(key):
		return bool(_walkable_cache[key])
	var walkable: bool = not bool(is_blocked.call(Vector2(float(tx) * tile_size, float(ty) * tile_size)))
	_walkable_cache[key] = walkable
	return walkable

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	return float(maxi(abs(a.x - b.x), abs(a.y - b.y)))

func _reconstruct_keys(came_from: Dictionary, current_key: int, start_key: int) -> Array[Vector2]:
	var rkeys := PackedInt64Array()
	rkeys.append(current_key)
	var key: int = current_key
	while came_from.has(key):
		key = int(came_from[key])
		rkeys.append(key)
	var out: Array[Vector2] = []
	var ts: float = tile_size
	for i in range(rkeys.size() - 1, -1, -1):
		var k: int = rkeys[i]
		if k == start_key:
			continue
		var tx: int = ((k >> 16) & 0xFFFF) - 32768
		var ty: int = (k & 0xFFFF) - 32768
		out.append(Vector2(float(tx) * ts, float(ty) * ts))
	return out

func _tile_key(tile: Vector2i) -> int:
	return ((tile.x + 32768) & 0xFFFF) << 16 | ((tile.y + 32768) & 0xFFFF)

func _rebuild_path(start_world: Vector2, goal_world: Vector2, is_blocked: Callable) -> void:
	var start_tile: Vector2i = _world_to_tile_vec(start_world)
	var goal_tile: Vector2i = _world_to_tile_vec(goal_world)
	_last_path_goal = _snap_to_tile(goal_world)
	_path_points.clear()
	_path_index = 0
	_repath_left = _repath_interval_runtime
	_walkable_cache.clear()
	_stuck_elapsed = 0.0
	_stuck_anchor = start_world
	if start_tile == goal_tile:
		return
	var min_x: int = mini(start_tile.x, goal_tile.x) - SEARCH_MARGIN_TILES
	var max_x: int = maxi(start_tile.x, goal_tile.x) + SEARCH_MARGIN_TILES
	var min_y: int = mini(start_tile.y, goal_tile.y) - SEARCH_MARGIN_TILES
	var max_y: int = maxi(start_tile.y, goal_tile.y) + SEARCH_MARGIN_TILES
	var gx: int = goal_tile.x
	var gy: int = goal_tile.y
	var start_key: int = _tile_key(start_tile)
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start_key: 0.0}
	var closed: Dictionary = {}
	var hf := PackedFloat64Array()
	var hk := PackedInt64Array()
	hf.append(_heuristic(start_tile, goal_tile))
	hk.append(start_key)
	var expansions: int = 0
	var max_exp: int = _max_expansions_runtime
	while hf.size() > 0 and expansions < max_exp:
		var h_size: int = hf.size()
		var best_key: int
		if h_size == 1:
			best_key = hk[0]
			hf.resize(0)
			hk.resize(0)
		else:
			best_key = hk[0]
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
		if closed.has(best_key):
			continue
		closed[best_key] = true
		expansions += 1
		var bx: int = ((best_key >> 16) & 0xFFFF) - 32768
		var by: int = (best_key & 0xFFFF) - 32768
		if bx == gx and by == gy:
			_path_points = _reconstruct_keys(came_from, best_key, start_key)
			return
		var best_g: float = float(g_score.get(best_key, INF))
		for _dy in range(-1, 2):
			for _dx in range(-1, 2):
				if _dx == 0 and _dy == 0:
					continue
				var nx: int = bx + _dx
				var ny: int = by + _dy
				if nx < min_x or nx > max_x or ny < min_y or ny > max_y:
					continue
				if not _tile_walkable(nx, ny, gx, gy, is_blocked):
					continue
				if _dx != 0 and _dy != 0:
					if not _tile_walkable(nx, by, gx, gy, is_blocked):
						continue
					if not _tile_walkable(bx, ny, gx, gy, is_blocked):
						continue
				var nk: int = ((nx + 32768) & 0xFFFF) << 16 | ((ny + 32768) & 0xFFFF)
				if closed.has(nk):
					continue
				var step_cost: float = 1.41421356 if (_dx != 0 and _dy != 0) else 1.0
				var tg: float = best_g + step_cost
				if tg >= float(g_score.get(nk, INF)):
					continue
				came_from[nk] = best_key
				g_score[nk] = tg
				var fv: float = tg + float(maxi(absi(nx - gx), absi(ny - gy)))
				hf.append(fv)
				hk.append(nk)
				var pi: int = hf.size() - 1
				while pi > 0:
					var pp: int = (pi - 1) >> 1
					if hf[pp] <= fv:
						break
					var ppf: float = hf[pp]
					var ppk: int = hk[pp]
					hf[pi] = ppf
					hk[pi] = ppk
					hf[pp] = fv
					hk[pp] = nk
					pi = pp
