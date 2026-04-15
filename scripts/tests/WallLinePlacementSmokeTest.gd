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

	for _i in range(12):
		await get_tree().process_frame

	for node in get_tree().get_nodes_in_group("gatherables"):
		if node != null and is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("huntables"):
		if node != null and is_instance_valid(node):
			node.queue_free()
	for node in get_tree().get_nodes_in_group("resource_drops"):
		if node != null and is_instance_valid(node):
			node.queue_free()

	for _i in range(3):
		await get_tree().process_frame

	main._on_building_selected(&"Wall")
	var y: float = 1120.0
	var start_pos: Vector2 = Vector2(3320.0, y)
	var end_pos: Vector2 = Vector2(3720.0, y)
	main._on_drag_selection(start_pos, end_pos)

	for _i in range(2):
		await get_tree().process_frame

	var expected_tiles: Array[Vector2] = []
	var x: float = start_pos.x
	while x <= end_pos.x + 0.1:
		expected_tiles.append(Vector2(x, y))
		x += 40.0

	var sites: Array = get_tree().get_nodes_in_group("build_sites")
	var missing: Array[String] = []
	for tile_pos in expected_tiles:
		var found: bool = false
		for site in sites:
			if site == null or not is_instance_valid(site):
				continue
			if StringName(site.get("building_id")) != &"Wall":
				continue
			if site.global_position.distance_to(tile_pos) <= 0.2:
				found = true
				break
		if not found:
			missing.append("%d,%d" % [int(tile_pos.x), int(tile_pos.y)])

	if not missing.is_empty():
		for tile_pos in expected_tiles:
			var blockers: int = int(main._collect_resource_blockers_for_build(tile_pos, &"Wall").size())
			var occupied: bool = bool(main.build_system._is_footprint_occupied(tile_pos, Vector2(40.0, 40.0)))
			print("WALL_LINE_TEST_INFO: tile=", tile_pos, " blockers=", blockers, " occupied=", occupied)
		print("WALL_LINE_TEST_INFO: deferred_count=", main._deferred_build_requests.size())
		print("WALL_LINE_TEST_INFO: structures_count=", get_tree().get_nodes_in_group("structures").size())
		print("WALL_LINE_TEST_INFO: build_sites_count=", get_tree().get_nodes_in_group("build_sites").size())
		_finish(false, "WALL_LINE_TEST_FAIL: missing=%s" % ", ".join(missing))
		return

	_finish(true, "WALL_LINE_TEST_PASS: drag wall line is contiguous")
