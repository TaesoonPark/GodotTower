extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const FARM_RECT := Rect2(Vector2(3720.0, 2120.0), Vector2(120.0, 120.0))

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

	if main.build_system == null or not is_instance_valid(main.build_system):
		_finish(false, "FARM_DELETE_TEST_FAIL: build_system missing")
		return
	if not bool(main.build_system.place_farm_zone(FARM_RECT)):
		_finish(false, "FARM_DELETE_TEST_FAIL: farm zone not created")
		return

	for _i in range(12):
		await get_tree().process_frame

	var farm_zones: Array = get_tree().get_nodes_in_group("farm_zones")
	if farm_zones.is_empty():
		_finish(false, "FARM_DELETE_TEST_FAIL: farm zone missing after place")
		return
	var zone: Node = farm_zones[0]
	if zone == null or not is_instance_valid(zone):
		_finish(false, "FARM_DELETE_TEST_FAIL: farm zone invalid")
		return

	main._on_action_changed(&"FarmZone")
	main.selected_farm_zone = zone
	main._selected_object_kind = &"FarmZone"
	main._selected_object_zone = zone
	main._on_selected_object_action_requested(&"DeleteFarmZone")

	for _i in range(12):
		await get_tree().process_frame

	if zone != null and is_instance_valid(zone):
		_finish(false, "FARM_DELETE_TEST_FAIL: zone still valid after delete action")
		return
	if not get_tree().get_nodes_in_group("farm_zones").is_empty():
		_finish(false, "FARM_DELETE_TEST_FAIL: farm zone group still non-empty")
		return

	if StringName(main.current_action) != &"Interact":
		_finish(false, "FARM_DELETE_TEST_FAIL: action mode did not reset to Interact")
		return

	var gatherable: Node = GATHERABLE_SCENE.instantiate()
	var click_pos: Vector2 = Vector2(4240.0, 2480.0)
	gatherable.global_position = click_pos
	main.world_root.add_child(gatherable)
	main._on_left_click(click_pos)
	if main.selected_designation_target != gatherable:
		_finish(false, "FARM_DELETE_TEST_FAIL: field gatherable not selectable after farm delete")
		return

	_finish(true, "FARM_DELETE_TEST_PASS: farm zone deleted via selected action")
