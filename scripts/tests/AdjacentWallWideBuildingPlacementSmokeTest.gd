extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
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
	for _i in range(2):
		await get_tree().process_frame

	var wall_pos: Vector2 = main._snap_to_tile(Vector2(3200.0, 1920.0))
	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(wall_pos, false):
		_finish(false, "ADJACENT_WALL_WIDE_BUILD_FAIL: wall placement failed")
		return

	var click_pos: Vector2 = wall_pos + Vector2(TILE_SIZE, 0.0)
	if not main._try_place_building_by_id(click_pos, &"SimpleBench"):
		_finish(false, "ADJACENT_WALL_WIDE_BUILD_FAIL: simple bench rejected next to wall")
		return
	for _i in range(2):
		await get_tree().process_frame

	var expected_site_pos: Vector2 = wall_pos + Vector2(TILE_SIZE * 1.5, 0.0)
	var site: Node = _find_build_site(&"SimpleBench", expected_site_pos)
	if site == null:
		_finish(false, "ADJACENT_WALL_WIDE_BUILD_FAIL: simple bench did not snap flush expected=%s" % str(expected_site_pos))
		return
	if not bool(main.build_system._is_footprint_occupied(expected_site_pos, Vector2(TILE_SIZE * 2.0, TILE_SIZE))):
		_finish(false, "ADJACENT_WALL_WIDE_BUILD_FAIL: placed bench footprint was not occupied")
		return

	_finish(true, "ADJACENT_WALL_WIDE_BUILD_PASS: even-footprint buildings can be placed flush against walls")

func _find_build_site(building_id: StringName, world_pos: Vector2) -> Node:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if StringName(site.get("building_id")) != building_id:
			continue
		if site is Node2D and (site as Node2D).global_position.distance_to(world_pos) <= 0.2:
			return site
	return null
