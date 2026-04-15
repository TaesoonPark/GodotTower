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

	if main._rally_flag_node != null and is_instance_valid(main._rally_flag_node):
		main._rally_flag_node.queue_free()
	main._rally_flag_node = null

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "RAID_RANGED_HOLD_TEST_FAIL: no colonists")
		return
	var lead = colonists[0]

	main._start_raid_wave()
	for _step in range(40):
		await get_tree().process_frame

	var enemies: Array = main._get_alive_raiders()
	if enemies.is_empty():
		_finish(false, "RAID_RANGED_HOLD_TEST_FAIL: no enemies")
		return
	var enemy = enemies[0]
	if enemy == null or not is_instance_valid(enemy):
		_finish(false, "RAID_RANGED_HOLD_TEST_FAIL: invalid enemy")
		return

	enemy.global_position = lead.global_position + Vector2(90.0, 0.0)
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(220):
		await get_tree().process_frame
		if StringName(lead.current_job.get("type", &"")) == &"CombatRanged":
			break
	if StringName(lead.current_job.get("type", &"")) != &"CombatRanged":
		_finish(false, "RAID_RANGED_HOLD_TEST_FAIL: lead did not enter CombatRanged")
		return

	var start_pos: Vector2 = lead.global_position
	enemy.global_position = lead.global_position + Vector2(520.0, 0.0)
	var max_move: float = 0.0
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(260):
		await get_tree().process_frame
		if enemy == null or not is_instance_valid(enemy):
			break
		var moved: float = lead.global_position.distance_to(start_pos)
		if moved > max_move:
			max_move = moved

	if max_move <= 8.0:
		_finish(true, "RAID_RANGED_HOLD_TEST_PASS: ranged combatant holds position when out of range")
		return
	_finish(false, "RAID_RANGED_HOLD_TEST_FAIL: max_move=%.2f" % [max_move])
