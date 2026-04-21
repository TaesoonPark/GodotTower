extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

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
		_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: no colonists")
		return
	var target = colonists[0]
	target.global_position = main._snap_to_tile(Vector2(4800.0, 3000.0))
	main.camera.global_position = target.global_position
	if target.has_method("cancel_current_job"):
		target.cancel_current_job()
	target.set_work_enabled(&"Combat", false)
	target.set_selected(false)
	for i in range(1, colonists.size()):
		var other = colonists[i]
		if other == null or not is_instance_valid(other):
			continue
		other.global_position = main._snap_to_tile(Vector2(320.0 + float(i) * 80.0, 320.0))
		if other.has_method("cancel_current_job"):
			other.cancel_current_job()

	var starts: Array[Vector2] = [
		target.global_position + Vector2(-40.0, -40.0),
		target.global_position + Vector2(0.0, -40.0),
		target.global_position + Vector2(40.0, -40.0),
		target.global_position + Vector2(-40.0, 0.0)
	]
	var enemies: Array = []
	for pos in starts:
		var zombie = ZOMBIE_SCENE.instantiate()
		zombie.global_position = main._snap_to_tile(pos)
		if zombie.has_method("set_tile_size"):
			zombie.set_tile_size(40.0)
		main.units_root.add_child(zombie)
		await get_tree().process_frame
		zombie.health = 10000.0
		zombie.melee_attack = 0.0
		enemies.append(zombie)

	main._raid_state = &"Active"
	main._cached_alive_enemies = enemies
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(800):
		await get_tree().process_frame
		var all_settled: bool = true
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				all_settled = false
				break
			var enemy_cell: Vector2 = main._snap_to_tile(enemy.global_position)
			var target_cell: Vector2 = main._snap_to_tile(target.global_position)
			var cell_dx: int = absi(int(round((enemy_cell.x - target_cell.x) / 40.0)))
			var cell_dy: int = absi(int(round((enemy_cell.y - target_cell.y) / 40.0)))
			if enemy.global_position.distance_to(enemy_cell) > 0.01 or enemy_cell.distance_to(target_cell) <= 0.1 or maxi(cell_dx, cell_dy) > 1:
				all_settled = false
				break
		if all_settled:
			break

	var min_enemy_friendly: float = INF
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: enemy invalid")
			return
		var enemy_cell: Vector2 = main._snap_to_tile(enemy.global_position)
		var target_cell: Vector2 = main._snap_to_tile(target.global_position)
		if enemy.global_position.distance_to(enemy_cell) > 0.01:
			_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: enemy not centered pos=%s snap=%s" % [str(enemy.global_position), str(enemy_cell)])
			return
		var dist: float = enemy.global_position.distance_to(target.global_position)
		min_enemy_friendly = minf(min_enemy_friendly, dist)
		if enemy_cell.distance_to(target_cell) <= 0.1:
			_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: enemy overlapped colonist dist=%.2f" % dist)
			return
		var cell_dx: int = absi(int(round((enemy_cell.x - target_cell.x) / 40.0)))
		var cell_dy: int = absi(int(round((enemy_cell.y - target_cell.y) / 40.0)))
		if maxi(cell_dx, cell_dy) > 1:
			_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: enemy failed to engage adjacent cell dist=%.2f" % dist)
			return

	var min_enemy_pair: float = INF
	for a in range(enemies.size()):
		for b in range(a + 1, enemies.size()):
			min_enemy_pair = minf(min_enemy_pair, enemies[a].global_position.distance_to(enemies[b].global_position))
	if min_enemy_pair < 30.0:
		_finish(false, "ENEMY_FRIENDLY_SPACING_TEST_FAIL: enemies stacked pair_dist=%.2f" % min_enemy_pair)
		return

	_finish(true, "ENEMY_FRIENDLY_SPACING_TEST_PASS: enemies keep centered melee cells around friendly targets")
