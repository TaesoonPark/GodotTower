extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const ENEMY_COUNT: int = 64
const COMMAND_BUDGET_USEC: int = 25000
const FRAME_BUDGET_USEC: int = 80000

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
	for _i in range(24):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "RAID_MOVE_PERF_TEST_FAIL: colonists not spawned")
		return
	for colonist in colonists:
		if colonist != null and is_instance_valid(colonist):
			colonist.set("health", 100000.0)

	var focused: Node2D = colonists[0] as Node2D
	var focused_start: Vector2 = main._snap_to_tile(focused.global_position)
	main._set_selected([focused])
	main._raid_wave_size = ENEMY_COUNT
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	for _i in range(12):
		await get_tree().process_frame

	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	if enemies.size() < ENEMY_COUNT:
		_finish(false, "RAID_MOVE_PERF_TEST_FAIL: expected %d raiders, got %d" % [ENEMY_COUNT, enemies.size()])
		return
	_place_enemies_near_focus(main, focused, enemies)
	for _i in range(30):
		await get_tree().process_frame

	var move_target: Vector2 = main._snap_to_tile(focused_start + Vector2(360.0, 0.0))
	var command_start_us: int = Time.get_ticks_usec()
	main._on_command_move(move_target)
	var command_us: int = Time.get_ticks_usec() - command_start_us
	if command_us > COMMAND_BUDGET_USEC:
		_finish(false, "RAID_MOVE_PERF_TEST_FAIL: command took %dus" % command_us)
		return

	var max_frame_us: int = 0
	for _i in range(120):
		var frame_start_us: int = Time.get_ticks_usec()
		await get_tree().process_frame
		max_frame_us = maxi(max_frame_us, Time.get_ticks_usec() - frame_start_us)
		if focused.global_position.distance_to(focused_start) > 28.0 and _i >= 20:
			break
	if focused.global_position.distance_to(focused_start) <= 28.0:
		_finish(false, "RAID_MOVE_PERF_TEST_FAIL: selected colonist did not move during raid")
		return
	if max_frame_us > FRAME_BUDGET_USEC:
		_finish(false, "RAID_MOVE_PERF_TEST_FAIL: max frame took %dus after move" % max_frame_us)
		return

	_finish(true, "RAID_MOVE_PERF_TEST_PASS: raid move command stayed within frame budget")

func _place_enemies_near_focus(main: Node, focused: Node2D, enemies: Array) -> void:
	var focused_id: int = focused.get_instance_id()
	var offsets: Array[Vector2] = _build_ring_offsets(enemies.size(), 40.0)
	for i in range(enemies.size()):
		var enemy: Node2D = enemies[i] as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.global_position = main._snap_to_tile(focused.global_position + offsets[i])
		enemy.set("_target_colonist_id", focused_id)
		enemy.set("_target_refresh_left", 0.0)
		enemy.set("_melee_lock_target_id", 0)
		enemy.set("_spawn_unclip_left", 0.0)
		if enemy.has_method("_clear_melee_goal_cache"):
			enemy.call("_clear_melee_goal_cache")

func _build_ring_offsets(count: int, tile_size: float) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for ring in range(2, 12):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				offsets.append(Vector2(float(x) * tile_size, float(y) * tile_size))
				if offsets.size() >= count:
					return offsets
	return offsets
