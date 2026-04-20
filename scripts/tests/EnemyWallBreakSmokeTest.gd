extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
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

	var wall_x: float = 3840.0
	var target_y: float = 2160.0
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.global_position = Vector2(4480.0, target_y)
		colonist.cancel_current_job()

	main.build_system.set_selected_building(&"Wall")
	var placed_walls: int = 0
	for y in range(0, 4321, 40):
		if main.build_system.place_building(Vector2(wall_x, float(y)), false):
			placed_walls += 1
	if placed_walls < 100:
		_finish(false, "ENEMY_WALL_BREAK_TEST_FAIL: wall setup incomplete placed=%d" % placed_walls)
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	if occupancy != null and is_instance_valid(occupancy) and occupancy.has_method("is_blocked_for_enemy"):
		if not bool(occupancy.is_blocked_for_enemy(Vector2(wall_x, target_y))):
			_finish(false, "ENEMY_WALL_BREAK_TEST_FAIL: target wall tile was not blocked")
			return

	var raider: Node2D = RAIDER_SCENE.instantiate()
	raider.global_position = Vector2(3200.0, target_y)
	if raider.has_method("set_tile_size"):
		raider.set_tile_size(40.0)
	main.units_root.add_child(raider)
	await get_tree().process_frame
	raider.structure_attack_damage = 400.0
	raider.attack_cooldown_sec = 0.2
	main._raid_state = &"Active"
	main._cached_alive_enemies = [raider]
	main._mark_combat_dirty()
	main._set_game_speed(4.0)

	var destroyed_wall: bool = false
	for _step in range(360):
		await get_tree().process_frame
		var wall_count: int = 0
		for structure in get_tree().get_nodes_in_group("structures"):
			if structure == null or not is_instance_valid(structure):
				continue
			if structure.has_meta("building_id") and StringName(structure.get_meta("building_id")) == &"Wall":
				wall_count += 1
		if wall_count < placed_walls:
			destroyed_wall = true
			break

	if not destroyed_wall:
		_finish(false, "ENEMY_WALL_BREAK_TEST_FAIL: raider did not destroy a blocking wall pos=%s" % str(raider.global_position))
		return

	_finish(true, "ENEMY_WALL_BREAK_TEST_PASS: blocked enemy destroyed a wall")
