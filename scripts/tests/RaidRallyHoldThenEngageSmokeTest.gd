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

func _is_combat_job(job_type: StringName) -> bool:
	return job_type == &"CombatMelee" or job_type == &"CombatRanged"

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)

	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "RAID_RALLY_HOLD_TEST_FAIL: no colonists")
		return

	var lead = colonists[0]
	main._set_combat_rally_point(lead.global_position + Vector2(200.0, 120.0))
	main._start_raid_wave()

	for _step in range(20):
		await get_tree().process_frame
	for enemy in main._get_alive_raiders():
		if enemy == null or not is_instance_valid(enemy):
			continue
		enemy.global_position = Vector2(7440.0, 4160.0)
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(160):
		await get_tree().process_frame
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if _is_combat_job(StringName(colonist.current_job.get("type", &""))):
			_finish(false, "RAID_RALLY_HOLD_TEST_FAIL: combat started before threat entered 160 range")
			return

	var enemies: Array = main._get_alive_raiders()
	if enemies.is_empty():
		_finish(false, "RAID_RALLY_HOLD_TEST_FAIL: no enemies after raid start")
		return
	var first_enemy = enemies[0]
	first_enemy.global_position = lead.global_position + Vector2(100.0, 0.0)
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(260):
		await get_tree().process_frame
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			if _is_combat_job(StringName(colonist.current_job.get("type", &""))):
				_finish(true, "RAID_RALLY_HOLD_TEST_PASS: hold at rally then engage within threat range")
				return

	_finish(false, "RAID_RALLY_HOLD_TEST_FAIL: combat did not start after close threat")
