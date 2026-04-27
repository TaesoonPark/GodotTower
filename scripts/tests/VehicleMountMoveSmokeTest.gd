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
	for _i in range(24):
		await get_tree().process_frame

	if main.colonists.is_empty():
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: no colonist found")
		return
	var colonist: Node2D = main.colonists[0]
	colonist.cancel_current_job()
	colonist.set_external_move_speed_multiplier(1.0)
	var bike_pos: Vector2 = main._snap_to_tile(colonist.global_position + Vector2(40.0, 0.0))
	var bike: Node2D = main._spawn_vehicle(&"Bicycle", bike_pos)
	if bike == null:
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: failed to spawn bicycle")
		return

	if not bool(main._request_vehicle_use(bike, colonist)):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: request mount failed")
		return
	for _step in range(180):
		await get_tree().process_frame
		if colonist.has_method("is_mounted") and bool(colonist.is_mounted()):
			break
	if not bool(colonist.is_mounted()):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: colonist never mounted bicycle")
		return
	if not is_equal_approx(float(colonist.get_effective_move_speed()), 250.0):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: mounted move speed did not use vehicle override")
		return

	main._set_selected([colonist])
	var before_move: Vector2 = colonist.global_position
	main._issue_selected_move_command(before_move + Vector2(240.0, 0.0))
	for _step in range(90):
		await get_tree().process_frame
	if colonist.global_position.distance_to(before_move) <= 60.0:
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: mounted colonist did not move on ground right-click path")
		return
	if bike.global_position.distance_to(colonist.global_position) > 4.0:
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: mounted bicycle did not follow rider")
		return

	if not bool(main._show_vehicle_dismount_context(bike, colonist, Vector2(24.0, 24.0))):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: dismount context was not shown")
		return
	await get_tree().process_frame
	if not main.hud.context_action_button.visible or StringName(main.hud._context_action_id) != &"DismountVehicle":
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: dismount button did not appear")
		return
	if not bool(colonist.is_mounted()):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: bicycle dismounted before button was selected")
		return
	main._on_context_action_requested(&"DismountVehicle")
	await get_tree().process_frame
	if bool(colonist.is_mounted()):
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: dismount button did not dismount")
		return
	if int(bike.get_meta("rider_colonist_id")) != 0:
		_finish(false, "VEHICLE_MOUNT_MOVE_FAIL: dismount did not clear vehicle rider")
		return

	_finish(true, "VEHICLE_MOUNT_MOVE_PASS: bicycle mount, movement, speed override, and dismount work")
