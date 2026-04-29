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

	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.global_position = Vector2(4480.0, 1840.0)
		colonist.cancel_current_job()

	var wall_x: float = 3840.0
	var gap_y: float = 2160.0
	var placed_walls: int = 0
	main.build_system.set_selected_building(&"Wall")
	for y in range(1440, 2921, 40):
		if absf(float(y) - gap_y) <= 0.1:
			continue
		if main.build_system.place_building(Vector2(wall_x, float(y)), false):
			placed_walls += 1
	if placed_walls < 30:
		_finish(false, "FLOW_WALL_GAP_TEST_FAIL: wall setup incomplete placed=%d" % placed_walls)
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame
	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	if occupancy != null and is_instance_valid(occupancy) and occupancy.has_method("is_blocked_for_enemy"):
		if not bool(occupancy.is_blocked_for_enemy(Vector2(wall_x, gap_y - 40.0))):
			_finish(false, "FLOW_WALL_GAP_TEST_FAIL: wall tile was not blocked")
			return
		if bool(occupancy.is_blocked_for_enemy(Vector2(wall_x, gap_y))):
			_finish(false, "FLOW_WALL_GAP_TEST_FAIL: gap tile was blocked")
			return

	var raider: Node2D = RAIDER_SCENE.instantiate()
	raider.global_position = Vector2(3200.0, 1840.0)
	if raider.has_method("set_tile_size"):
		raider.set_tile_size(64.0)
	main.units_root.add_child(raider)
	main._raid_state = &"Active"
	main._cached_alive_enemies = [raider]
	main._mark_combat_dirty()
	main._set_game_speed(4.0)
	for _i in range(20):
		await get_tree().process_frame

	var crossed: bool = false
	for _step in range(360):
		await get_tree().process_frame
		if raider == null or not is_instance_valid(raider):
			_finish(false, "FLOW_WALL_GAP_TEST_FAIL: raider died before crossing")
			return
		if raider.global_position.x >= wall_x + 80.0:
			crossed = true
			break

	var stats: Dictionary = {}
	var service: Node = get_tree().get_first_node_in_group("enemy_flow_field_service")
	if service != null and is_instance_valid(service) and service.has_method("get_debug_stats"):
		stats = service.get_debug_stats()
	if not crossed:
		_finish(false, "FLOW_WALL_GAP_TEST_FAIL: pos=%s stats=%s" % [str(raider.global_position), str(stats)])
		return
	if int(stats.get("field_builds", 0)) <= 0:
		_finish(false, "FLOW_WALL_GAP_TEST_FAIL: flow field did not build stats=%s" % str(stats))
		return

	_finish(true, "FLOW_WALL_GAP_TEST_PASS: enemy flow field routed through wall gap")
