extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const ENEMY_COUNT: int = 64
const FRAME_BUDGET_USEC: int = 100000

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
		_finish(false, "ENEMY_TARGET_EXIT_PERF_FAIL: missing colonist")
		return
	var target: Node2D = colonists[0] as Node2D
	var inside: Vector2 = Vector2(3840.0, 2160.0)
	var outside: Vector2 = Vector2(3440.0, 2160.0)
	target.global_position = inside
	target.set("health", 100000.0)
	if target.has_method("cancel_current_job"):
		target.cancel_current_job()
	for i in range(1, colonists.size()):
		var colonist: Node2D = colonists[i] as Node2D
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.global_position = Vector2(4480.0, 1840.0 + float(i) * 80.0)
		colonist.set("health", 100000.0)
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()

	_place_wall_box(main, inside)
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	var enemies: Array[Node2D] = _spawn_enemies(main, target, outside + Vector2(-280.0, 0.0))
	main._raid_state = &"Active"
	main._cached_alive_enemies = enemies
	main._mark_combat_dirty()
	main._set_game_speed(4.0)
	for _i in range(30):
		await get_tree().process_frame

	target.global_position = outside
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.set("_target_colonist_id", target.get_instance_id())
		enemy.set("_target_refresh_left", 0.0)
		if enemy.has_method("_clear_melee_goal_cache"):
			enemy.call("_clear_melee_goal_cache")

	var max_frame_us: int = 0
	for _i in range(120):
		var frame_start_us: int = Time.get_ticks_usec()
		await get_tree().process_frame
		max_frame_us = maxi(max_frame_us, Time.get_ticks_usec() - frame_start_us)
	if max_frame_us > FRAME_BUDGET_USEC:
		_finish(false, "ENEMY_TARGET_EXIT_PERF_FAIL: max frame took %dus after target exit" % max_frame_us)
		return

	_finish(true, "ENEMY_TARGET_EXIT_PERF_PASS: target exit from wall enclosure stayed within frame budget")

func _place_wall_box(main: Node, center: Vector2) -> void:
	main.build_system.set_selected_building(&"Wall")
	for x in range(int(center.x - 80.0), int(center.x + 81.0), 40):
		main.build_system.place_building(Vector2(float(x), center.y - 80.0), false)
		main.build_system.place_building(Vector2(float(x), center.y + 80.0), false)
	for y in range(int(center.y - 40.0), int(center.y + 41.0), 40):
		main.build_system.place_building(Vector2(center.x - 80.0, float(y)), false)
		main.build_system.place_building(Vector2(center.x + 80.0, float(y)), false)

func _spawn_enemies(main: Node, target: Node2D, center: Vector2) -> Array[Node2D]:
	var enemies: Array[Node2D] = []
	var offsets: Array[Vector2] = _build_offsets(ENEMY_COUNT, 40.0)
	for i in range(ENEMY_COUNT):
		var enemy: Node2D = RAIDER_SCENE.instantiate()
		enemy.global_position = main._snap_to_tile(center + offsets[i])
		if enemy.has_method("set_tile_size"):
			enemy.set_tile_size(40.0)
		main.units_root.add_child(enemy)
		enemy.set("_target_colonist_id", target.get_instance_id())
		enemy.set("_target_refresh_left", 0.0)
		enemy.set("_spawn_unclip_left", 0.0)
		enemy.set("structure_attack_damage", 1.0)
		enemies.append(enemy)
	return enemies

func _build_offsets(count: int, tile_size: float) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	for y in range(-4, 5):
		for x in range(-4, 4):
			offsets.append(Vector2(float(x) * tile_size, float(y) * tile_size))
			if offsets.size() >= count:
				return offsets
	return offsets
