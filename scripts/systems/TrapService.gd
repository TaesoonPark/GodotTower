extends Node
class_name TrapService

var tile_size: float = 64.0
var max_per_update: int = 42
var _trap_update_cursor: int = 0

func setup(next_tile_size: float, next_max_per_update: int) -> void:
	tile_size = maxf(4.0, next_tile_size)
	max_per_update = maxi(1, next_max_per_update)

func update_defense_traps(
	delta: float,
	enemies: Array,
	trap_nodes: Array,
	trap_damage_bonus: float,
	trap_cooldown_bonus: float,
	game_paused: bool = false
) -> bool:
	if game_paused:
		return false
	if trap_nodes.is_empty():
		return false
	var enemy_buckets: Dictionary = _build_enemy_buckets(enemies)
	var traps_changed: bool = false
	var trap_count: int = trap_nodes.size()
	var process_count: int = mini(max_per_update, trap_count)
	var start_idx: int = posmod(_trap_update_cursor, trap_count)
	for i in range(process_count):
		var trap: Node = trap_nodes[(start_idx + i) % trap_count] as Node
		if trap == null or not is_instance_valid(trap):
			continue
		if not _process_trap(delta, trap, enemy_buckets, trap_damage_bonus, trap_cooldown_bonus):
			continue
		traps_changed = true
	_trap_update_cursor = (start_idx + process_count) % trap_count
	return traps_changed

func _process_trap(
	delta: float,
	trap: Node,
	enemy_buckets: Dictionary,
	trap_damage_bonus: float,
	trap_cooldown_bonus: float
) -> bool:
	var trap_damage: int = int(trap.get_meta("trap_damage")) if trap.has_meta("trap_damage") else 0
	if trap_damage <= 0:
		return false
	trap_damage = int(round(float(trap_damage) * trap_damage_bonus))
	var charges: int = int(trap.get_meta("trap_charges")) if trap.has_meta("trap_charges") else 0
	if charges <= 0:
		return false
	var cooldown_left: float = float(trap.get_meta("trap_cooldown_left")) if trap.has_meta("trap_cooldown_left") else 0.0
	var changed: bool = false
	if cooldown_left > 0.0:
		cooldown_left = maxf(0.0, cooldown_left - delta)
		trap.set_meta("trap_cooldown_left", cooldown_left)
		changed = true
	if cooldown_left > 0.0:
		return changed
	var target: Node = _find_enemy_inside_trap_footprint(trap, enemy_buckets)
	if target == null:
		return changed
	if target.has_method("apply_combat_damage"):
		target.apply_combat_damage(trap_damage)
	var cooldown: float = float(trap.get_meta("trap_cooldown_sec")) if trap.has_meta("trap_cooldown_sec") else 3.0
	trap.set_meta("trap_cooldown_left", maxf(0.3, cooldown / maxf(1.0, trap_cooldown_bonus)))
	trap.set_meta("trap_charges", charges - 1)
	return true

func _build_enemy_buckets(enemies: Array) -> Dictionary:
	var trap_cell_size: float = tile_size * 4.0
	var enemy_buckets: Dictionary = {}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_pos: Vector2 = (enemy as Node2D).global_position
		var bucket: Vector2i = Vector2i(
			int(floor(enemy_pos.x / trap_cell_size)),
			int(floor(enemy_pos.y / trap_cell_size))
		)
		var key: int = _pack_tile_key(bucket)
		if not enemy_buckets.has(key):
			enemy_buckets[key] = []
		var bucket_enemies: Array = enemy_buckets[key]
		bucket_enemies.append(enemy)
		enemy_buckets[key] = bucket_enemies
	return enemy_buckets

func _find_enemy_inside_trap_footprint(trap: Node, enemy_buckets: Dictionary) -> Node:
	if not (trap is Node2D):
		return null
	var trap_node: Node2D = trap as Node2D
	var trap_cell_size: float = tile_size * 4.0
	var footprint: Vector2 = trap.get_meta("footprint_size") if trap.has_meta("footprint_size") else Vector2(tile_size, tile_size)
	footprint.x = maxf(1.0, footprint.x)
	footprint.y = maxf(1.0, footprint.y)
	var occupied_rect := Rect2(trap_node.global_position - footprint * 0.5, footprint).grow(0.5)
	var min_bucket := Vector2i(
		int(floor(occupied_rect.position.x / trap_cell_size)),
		int(floor(occupied_rect.position.y / trap_cell_size))
	)
	var max_bucket := Vector2i(
		int(floor((occupied_rect.position.x + occupied_rect.size.x) / trap_cell_size)),
		int(floor((occupied_rect.position.y + occupied_rect.size.y) / trap_cell_size))
	)
	var target: Node = null
	var best_dist_sq: float = INF
	for by in range(min_bucket.y, max_bucket.y + 1):
		for bx in range(min_bucket.x, max_bucket.x + 1):
			var local_key: int = _pack_tile_key(Vector2i(bx, by))
			if not enemy_buckets.has(local_key):
				continue
			var bucket_enemies: Array = enemy_buckets[local_key]
			for enemy in bucket_enemies:
				if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
					continue
				var enemy_pos: Vector2 = (enemy as Node2D).global_position
				if not occupied_rect.has_point(enemy_pos):
					continue
				var dist_sq: float = trap_node.global_position.distance_squared_to(enemy_pos)
				if dist_sq < best_dist_sq:
					best_dist_sq = dist_sq
					target = enemy
	return target

func _pack_tile_key(tile: Vector2i) -> int:
	var packed_x: int = (tile.x + 32768) & 0xFFFF
	var packed_y: int = (tile.y + 32768) & 0xFFFF
	return (packed_x << 16) | packed_y
