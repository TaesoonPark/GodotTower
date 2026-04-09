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

	for _i in range(16):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 3:
		_finish(false, "FAST_MOVE_TEST_FAIL: insufficient colonists")
		return

	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	var start_positions: Dictionary = {}
	for colonist in colonists:
		start_positions[colonist.get_instance_id()] = colonist.global_position
		min_x = minf(min_x, colonist.global_position.x)
		min_y = minf(min_y, colonist.global_position.y)
		max_x = maxf(max_x, colonist.global_position.x)
		max_y = maxf(max_y, colonist.global_position.y)

	main._on_drag_selection(Vector2(min_x - 8.0, min_y - 8.0), Vector2(max_x + 8.0, max_y + 8.0))
	await get_tree().process_frame
	main._set_game_speed(4.0)
	main._on_command_move(Vector2(4300.0, 2400.0))

	var moved_ids: Dictionary = {}
	for _step in range(180):
		await get_tree().process_frame
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var start_pos: Vector2 = start_positions.get(colonist.get_instance_id(), colonist.global_position)
			if colonist.global_position.distance_to(start_pos) >= 120.0:
				moved_ids[colonist.get_instance_id()] = true
		if moved_ids.size() >= 3:
			break

	if moved_ids.size() < 3:
		var distances: Array[String] = []
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var start_pos: Vector2 = start_positions.get(colonist.get_instance_id(), colonist.global_position)
			distances.append("%s=%.1f" % [colonist.name, colonist.global_position.distance_to(start_pos)])
		print("FAST_MOVE_TEST_INFO: moved=", distances)
		_finish(false, "FAST_MOVE_TEST_FAIL: colonists stalled at 4x speed")
		return

	_finish(true, "FAST_MOVE_TEST_PASS: multi-colonist movement stable at 4x")
