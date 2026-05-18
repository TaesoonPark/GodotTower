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

	var origin: Vector2 = main._snap_to_tile(Vector2(3200.0, 1920.0))
	if not await _run_variant_case(main, &"Wall", origin, "wall"):
		return
	if not await _run_variant_case(main, &"FiringWall", origin + Vector2(TILE_SIZE * 7.0, 0.0), "firing wall"):
		return

	_finish(true, "WALL_SPRITE_VARIANT_PASS: wall and firing wall sprites switch between horizontal, vertical, and corner variants")

func _run_variant_case(main: Node, building_id: StringName, origin: Vector2, label: String) -> bool:
	main.build_system.set_selected_building(building_id)
	if not main.build_system.place_building(origin, false):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: direct center %s placement failed" % label)
		return false
	if not main.build_system.place_building(origin + Vector2(TILE_SIZE, 0.0), false):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: direct right %s placement failed" % label)
		return false
	if not main.build_system.place_building(origin + Vector2(0.0, TILE_SIZE), false):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: direct down %s placement failed" % label)
		return false
	for _i in range(3):
		await get_tree().process_frame

	var direct_center: Node = _find_wall_at(origin, &"structures", building_id)
	if direct_center == null:
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: direct center %s missing" % label)
		return false
	if not _expect_variant(direct_center, &"corner_down_right", "direct center %s" % label):
		return false
	var direct_down: Node = _find_wall_at(origin + Vector2(0.0, TILE_SIZE), &"structures", building_id)
	if not _expect_variant(direct_down, &"vertical", "direct down %s" % label):
		return false

	var blueprint_origin: Vector2 = origin + Vector2(TILE_SIZE * 4.0, 0.0)
	if not main.build_system.place_building(blueprint_origin, true):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: blueprint center %s placement failed" % label)
		return false
	if not main.build_system.place_building(blueprint_origin + Vector2(TILE_SIZE, 0.0), true):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: blueprint right %s placement failed" % label)
		return false
	if not main.build_system.place_building(blueprint_origin + Vector2(0.0, -TILE_SIZE), true):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: blueprint up %s placement failed" % label)
		return false
	for _i in range(3):
		await get_tree().process_frame

	var blueprint_center: Node = _find_wall_at(blueprint_origin, &"build_sites", building_id)
	if not _expect_variant(blueprint_center, &"corner_up_right", "blueprint center %s" % label):
		return false
	return true

func _find_wall_at(pos: Vector2, group_name: StringName, building_id: StringName) -> Node:
	for node in get_tree().get_nodes_in_group(group_name):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id") or StringName(node.get_meta("building_id")) != building_id:
			continue
		if node is Node2D and (node as Node2D).global_position.distance_to(pos) <= 0.2:
			return node
	return null

func _expect_variant(node: Node, expected: StringName, label: String) -> bool:
	if node == null or not is_instance_valid(node):
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: %s wall missing" % label)
		return false
	var actual: StringName = StringName(node.get_meta("wall_sprite_variant")) if node.has_meta("wall_sprite_variant") else &""
	if actual != expected:
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: %s variant expected=%s actual=%s" % [label, String(expected), String(actual)])
		return false
	var sprite: Sprite2D = _find_sprite(node)
	if sprite == null or sprite.texture == null:
		_finish(false, "WALL_SPRITE_VARIANT_FAIL: %s sprite texture missing" % label)
		return false
	return true

func _find_sprite(node: Node) -> Sprite2D:
	var base_sprite: Node = node.get_node_or_null("BaseSprite")
	if base_sprite is Sprite2D:
		return base_sprite as Sprite2D
	for child in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null
