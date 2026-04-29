extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const ENEMY_COUNT: int = 64
const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: missing colonist")
		return
	var target: Node2D = colonists[0] as Node2D
	target.global_position = main._snap_to_tile(Vector2(3840.0, 2160.0))
	target.set("health", 100000.0)
	if target.has_method("cancel_current_job"):
		target.cancel_current_job()

	var enemies: Array[Node2D] = _spawn_enemies(main, target)
	var coordinator: Node = get_tree().get_first_node_in_group("enemy_engagement_coordinator")
	if coordinator == null or not is_instance_valid(coordinator) or not coordinator.has_method("request_melee_goal"):
		_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: missing coordinator")
		return
	var stats_before: Dictionary = coordinator.get_debug_stats()
	var cells: Dictionary = {}
	var in_range_count: int = 0
	for enemy in enemies:
		var goal: Vector2 = coordinator.request_melee_goal(enemy, target, float(enemy.get("melee_range")))
		if goal == Vector2.INF:
			_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: empty goal")
			return
		var key: int = _cell_key(goal)
		if cells.has(key):
			_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: duplicate goal cell=%s" % str(goal))
			return
		cells[key] = true
		if _cell_ring(goal, target.global_position) <= 1:
			in_range_count += 1
	var stats_after: Dictionary = coordinator.get_debug_stats()
	var context_builds: int = int(stats_after.get("target_context_builds", 0)) - int(stats_before.get("target_context_builds", 0))
	var cell_cache_builds: int = int(stats_after.get("cell_cache_builds", 0)) - int(stats_before.get("cell_cache_builds", 0))
	if context_builds != 1:
		_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: target contexts built %d times" % context_builds)
		return
	if cell_cache_builds > 1:
		_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: cell cache built %d times" % cell_cache_builds)
		return
	if in_range_count > 12:
		_finish(false, "ENEMY_ENGAGEMENT_COORDINATOR_FAIL: active melee pursuers exceeded limit count=%d" % in_range_count)
		return

	_finish(true, "ENEMY_ENGAGEMENT_COORDINATOR_PASS: shared target context and unique melee goals")

func _spawn_enemies(main: Node, target: Node2D) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var offsets: Array[Vector2] = _build_offsets(ENEMY_COUNT)
	for i in range(ENEMY_COUNT):
		var enemy: Node2D = RAIDER_SCENE.instantiate()
		enemy.global_position = main._snap_to_tile(target.global_position + offsets[i])
		if enemy.has_method("set_tile_size"):
			enemy.set_tile_size(TILE_SIZE)
		main.units_root.add_child(enemy)
		enemy.set("_target_colonist_id", target.get_instance_id())
		enemy.set("_target_refresh_left", 0.0)
		enemy.set("_spawn_unclip_left", 0.0)
		enemies.append(enemy)
	return enemies

func _build_offsets(count: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for ring in range(3, 12):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				offsets.append(Vector2(float(x) * TILE_SIZE, float(y) * TILE_SIZE))
				if offsets.size() >= count:
					return offsets
	return offsets

func _cell_ring(cell: Vector2, target_pos: Vector2) -> int:
	var dx: int = absi(int(round((cell.x - target_pos.x) / TILE_SIZE)))
	var dy: int = absi(int(round((cell.y - target_pos.y) / TILE_SIZE)))
	return maxi(dx, dy)

func _cell_key(world_pos: Vector2) -> int:
	var tile := Vector2i(int(round(world_pos.x / TILE_SIZE)), int(round(world_pos.y / TILE_SIZE)))
	return (((tile.x + 32768) & 0xFFFF) << 16) | ((tile.y + 32768) & 0xFFFF)
