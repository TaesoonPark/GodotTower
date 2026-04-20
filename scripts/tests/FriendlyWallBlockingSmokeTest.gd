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

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: missing colonist")
		return

	var lead: Node2D = colonists[0]
	var wall_x: float = 3360.0
	var wall_y: float = 2160.0
	for i in range(colonists.size()):
		var colonist: Node2D = colonists[i]
		colonist.global_position = Vector2(wall_x - 120.0, wall_y + float(i) * 80.0)
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()

	main.build_system.set_selected_building(&"Wall")
	for y in range(int(wall_y - 80.0), int(wall_y + 81.0), 40):
		if not main.build_system.place_building(Vector2(wall_x, float(y)), false):
			_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: wall setup failed")
			return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	if occupancy == null or not is_instance_valid(occupancy) or not occupancy.has_method("is_blocked_for_friendly"):
		_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: missing occupancy")
		return
	if not bool(occupancy.is_blocked_for_friendly(Vector2(wall_x, wall_y))):
		_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: wall tile was not blocked")
		return

	main._set_selected([lead])
	main._on_command_move(Vector2(wall_x, wall_y))
	await get_tree().process_frame

	if lead.current_job.is_empty() or StringName(lead.current_job.get("type", &"")) != &"MoveTo":
		_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: MoveTo was not assigned")
		return
	var assigned_target: Vector2 = lead.current_job.get("target", Vector2.INF)
	if assigned_target == Vector2.INF or bool(occupancy.is_blocked_for_friendly(assigned_target)):
		_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: blocked move target assigned=%s" % str(assigned_target))
		return

	main._set_game_speed(4.0)
	for _step in range(160):
		await get_tree().process_frame
		if bool(occupancy.is_blocked_for_friendly(lead.global_position)):
			_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: colonist entered blocked tile pos=%s" % str(lead.global_position))
			return
		if lead.global_position.x >= wall_x - 16.0:
			_finish(false, "FRIENDLY_WALL_BLOCKING_FAIL: colonist crossed into wall edge pos=%s target=%s" % [str(lead.global_position), str(assigned_target)])
			return

	_finish(true, "FRIENDLY_WALL_BLOCKING_PASS: colonist targets and movement stay out of walls")
