extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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

	main._raid_wave_size = 64
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	for _i in range(20):
		await get_tree().process_frame

	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	if enemies.size() < 64:
		_finish(false, "FLOW_SCALE_TEST_FAIL: expected 64 raiders, got %d" % enemies.size())
		return

	var start_positions: Dictionary = {}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		start_positions[enemy.get_instance_id()] = enemy.global_position

	var moved_ids: Dictionary = {}
	for _step in range(240):
		await get_tree().process_frame
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			var start_pos: Vector2 = start_positions.get(enemy.get_instance_id(), enemy.global_position)
			if enemy.global_position.distance_to(start_pos) >= 80.0:
				moved_ids[enemy.get_instance_id()] = true
		if moved_ids.size() >= 48:
			break

	var stats: Dictionary = {}
	var service: Node = get_tree().get_first_node_in_group("enemy_flow_field_service")
	if service != null and is_instance_valid(service) and service.has_method("get_debug_stats"):
		stats = service.get_debug_stats()
	if int(stats.get("field_builds", 0)) <= 0:
		_finish(false, "FLOW_SCALE_TEST_FAIL: flow field did not build stats=%s" % str(stats))
		return
	if moved_ids.size() < 48:
		_finish(false, "FLOW_SCALE_TEST_FAIL: moved=%d stats=%s" % [moved_ids.size(), str(stats)])
		return

	_finish(true, "FLOW_SCALE_TEST_PASS: 64 raiders shared flow fields and advanced")
