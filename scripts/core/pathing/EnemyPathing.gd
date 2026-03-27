extends RefCounted
class_name EnemyPathing

const REPATH_INTERVAL_SEC: float = 0.4
const SEARCH_MARGIN_TILES: int = 16
const MAX_EXPANSIONS: int = 5000

var tile_size: float = 40.0
var _path_points: Array[Vector2] = []
var _path_index: int = 0
var _last_path_goal: Vector2 = Vector2.INF
var _repath_left: float = 0.0
var _last_obstacle_signature: int = 0

func setup(next_tile_size: float) -> void:
	tile_size = maxf(4.0, next_tile_size)

func tick(delta: float) -> void:
	_repath_left = maxf(0.0, _repath_left - delta)

func clear() -> void:
	_path_points.clear()
	_path_index = 0
	_last_path_goal = Vector2.INF

func notify_obstacle_signature(signature: int) -> void:
	if signature == _last_obstacle_signature:
		return
	_last_obstacle_signature = signature
	# Rebuild only when local blockers changed near the mover.
	_path_points.clear()
	_path_index = 0
	_repath_left = 0.0

func move_step(current_pos: Vector2, goal_world: Vector2, speed: float, delta: float, is_blocked: Callable) -> Dictionary:
	var goal: Vector2 = _snap_to_tile(goal_world)
	if goal == Vector2.INF:
		clear()
		return {"position": current_pos, "reached_goal": true, "blocked": false}
	if current_pos.distance_to(goal) <= 6.0:
		clear()
		return {"position": current_pos, "reached_goal": true, "blocked": false}
	var need_rebuild: bool = _path_points.is_empty() or goal != _last_path_goal or _path_index >= _path_points.size()
	if need_rebuild and _repath_left <= 0.0:
		_rebuild_path(current_pos, goal, is_blocked)
	if _path_points.is_empty():
		var direct_dir: Vector2 = current_pos.direction_to(goal)
		if direct_dir != Vector2.ZERO:
			var direct_step: Vector2 = current_pos + direct_dir * speed * delta
			if not bool(is_blocked.call(direct_step)):
				return {"position": direct_step, "reached_goal": false, "blocked": false}
		return {"position": current_pos, "reached_goal": false, "blocked": true}
	var next_pos: Vector2 = _get_next_path_point(goal)
	var dir: Vector2 = current_pos.direction_to(next_pos)
	if dir == Vector2.ZERO:
		return {"position": current_pos, "reached_goal": false, "blocked": false}
	var proposed: Vector2 = current_pos + dir * speed * delta
	if bool(is_blocked.call(proposed)):
		if _repath_left <= 0.0:
			_rebuild_path(current_pos, goal, is_blocked)
		next_pos = _get_next_path_point(goal)
		dir = current_pos.direction_to(next_pos)
		proposed = current_pos + dir * speed * delta
		if bool(is_blocked.call(proposed)):
			return {"position": current_pos, "reached_goal": false, "blocked": true}
	var out_pos: Vector2 = proposed
	if out_pos.distance_to(next_pos) <= 4.0 and not bool(is_blocked.call(next_pos)):
		out_pos = next_pos
		_path_index += 1
	return {"position": out_pos, "reached_goal": false, "blocked": false}

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

func _tile_to_world_vec(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) * tile_size, float(tile.y) * tile_size)

func _get_next_path_point(goal: Vector2) -> Vector2:
	if _path_points.is_empty() or _path_index >= _path_points.size():
		return goal
	return _path_points[_path_index]

func _tile_is_walkable(tile: Vector2i, goal_tile: Vector2i, is_blocked: Callable) -> bool:
	if tile == goal_tile:
		return true
	return not bool(is_blocked.call(_tile_to_world_vec(tile)))

func _neighbor_tiles(tile: Vector2i, goal_tile: Vector2i, is_blocked: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var candidate := Vector2i(tile.x + dx, tile.y + dy)
			if not _tile_is_walkable(candidate, goal_tile, is_blocked):
				continue
			if dx != 0 and dy != 0:
				var side_a := Vector2i(tile.x + dx, tile.y)
				var side_b := Vector2i(tile.x, tile.y + dy)
				if not _tile_is_walkable(side_a, goal_tile, is_blocked):
					continue
				if not _tile_is_walkable(side_b, goal_tile, is_blocked):
					continue
			out.append(candidate)
	return out

func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return float(maxi(dx, dy))

func _reconstruct(came_from: Dictionary, current: Vector2i, start: Vector2i) -> Array[Vector2]:
	var reverse_tiles: Array[Vector2i] = [current]
	var key: String = "%d,%d" % [current.x, current.y]
	while came_from.has(key):
		var prev: Vector2i = came_from[key]
		reverse_tiles.append(prev)
		key = "%d,%d" % [prev.x, prev.y]
	var out: Array[Vector2] = []
	for i in range(reverse_tiles.size() - 1, -1, -1):
		var tile: Vector2i = reverse_tiles[i]
		if tile == start:
			continue
		out.append(_tile_to_world_vec(tile))
	return out

func _rebuild_path(start_world: Vector2, goal_world: Vector2, is_blocked: Callable) -> void:
	var start_tile: Vector2i = _world_to_tile_vec(start_world)
	var goal_tile: Vector2i = _world_to_tile_vec(goal_world)
	_last_path_goal = _snap_to_tile(goal_world)
	_path_points.clear()
	_path_index = 0
	_repath_left = REPATH_INTERVAL_SEC
	if start_tile == goal_tile:
		return
	var min_x: int = mini(start_tile.x, goal_tile.x) - SEARCH_MARGIN_TILES
	var max_x: int = maxi(start_tile.x, goal_tile.x) + SEARCH_MARGIN_TILES
	var min_y: int = mini(start_tile.y, goal_tile.y) - SEARCH_MARGIN_TILES
	var max_y: int = maxi(start_tile.y, goal_tile.y) + SEARCH_MARGIN_TILES
	var open_list: Array[Vector2i] = [start_tile]
	var open_lookup: Dictionary = {"%d,%d" % [start_tile.x, start_tile.y]: true}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {"%d,%d" % [start_tile.x, start_tile.y]: 0.0}
	var f_score: Dictionary = {"%d,%d" % [start_tile.x, start_tile.y]: _heuristic(start_tile, goal_tile)}
	var expansions: int = 0
	while not open_list.is_empty() and expansions < MAX_EXPANSIONS:
		expansions += 1
		var best_idx: int = 0
		var best_tile: Vector2i = open_list[0]
		var best_key: String = "%d,%d" % [best_tile.x, best_tile.y]
		var best_f: float = float(f_score.get(best_key, INF))
		for i in range(1, open_list.size()):
			var tile: Vector2i = open_list[i]
			var key_i: String = "%d,%d" % [tile.x, tile.y]
			var f_i: float = float(f_score.get(key_i, INF))
			if f_i < best_f:
				best_f = f_i
				best_idx = i
				best_tile = tile
				best_key = key_i
		open_list.remove_at(best_idx)
		open_lookup.erase(best_key)
		if best_tile == goal_tile:
			_path_points = _reconstruct(came_from, best_tile, start_tile)
			return
		for neighbor in _neighbor_tiles(best_tile, goal_tile, is_blocked):
			if neighbor.x < min_x or neighbor.x > max_x or neighbor.y < min_y or neighbor.y > max_y:
				continue
			var neighbor_key: String = "%d,%d" % [neighbor.x, neighbor.y]
			var step_cost: float = 1.41421356 if (neighbor.x != best_tile.x and neighbor.y != best_tile.y) else 1.0
			var tentative_g: float = float(g_score.get(best_key, INF)) + step_cost
			if tentative_g >= float(g_score.get(neighbor_key, INF)):
				continue
			came_from[neighbor_key] = best_tile
			g_score[neighbor_key] = tentative_g
			f_score[neighbor_key] = tentative_g + _heuristic(neighbor, goal_tile)
			if not open_lookup.has(neighbor_key):
				open_lookup[neighbor_key] = true
				open_list.append(neighbor)
