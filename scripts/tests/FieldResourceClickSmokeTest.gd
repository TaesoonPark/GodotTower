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

	var gatherables: Array = get_tree().get_nodes_in_group("gatherables")
	if gatherables.is_empty():
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: no initial gatherables")
		return
	var gatherable: Node = gatherables[0]
	if gatherable == null or not is_instance_valid(gatherable):
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: gatherable invalid")
		return
	var click_pos: Vector2 = gatherable.global_position

	main._on_action_changed(&"Interact")
	main._on_left_click(click_pos)
	if main.selected_designation_target != gatherable:
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: interact mode failed to select gatherable")
		return

	main._on_action_changed(&"FarmZone")
	main._on_left_click(click_pos)
	if main.selected_designation_target != gatherable:
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: farm mode did not fall back to resource click")
		return
	if StringName(main.current_action) != &"Interact":
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: farm mode did not reset to interact on resource click")
		return

	main._on_action_changed(&"StockpileZone")
	main._on_left_click(click_pos)
	if main.selected_designation_target != gatherable:
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: stockpile mode did not fall back to resource click")
		return
	if StringName(main.current_action) != &"Interact":
		_finish(false, "FIELD_RESOURCE_CLICK_TEST_FAIL: stockpile mode did not reset to interact on resource click")
		return

	_finish(true, "FIELD_RESOURCE_CLICK_TEST_PASS: field gatherable remains clickable across mode fallback")
