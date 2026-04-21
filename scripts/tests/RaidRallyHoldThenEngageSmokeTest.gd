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

func _pin_enemy(enemy: Node2D, pos: Vector2) -> void:
	enemy.global_position = pos
	enemy.move_speed = 0.0
	enemy._spawn_unclip_left = 0.0
	enemy._move_goal = pos

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
	await get_tree().process_frame

	main._mark_group_cache_dirty(&"raiders")
	main._mark_group_cache_dirty(&"zombies")
	var far_enemy_pos: Vector2 = Vector2(7440.0, 4160.0)
	var moved_enemy_count: int = 0
	for enemy in main._get_alive_raiders():
		if enemy == null or not is_instance_valid(enemy):
			continue
		_pin_enemy(enemy, far_enemy_pos)
		moved_enemy_count += 1
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if _is_combat_job(StringName(colonist.current_job.get("type", &""))) and colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
	if main.job_system != null and is_instance_valid(main.job_system):
		main.job_system._jobs.clear()
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	for _step in range(20):
		await get_tree().process_frame

	for _step in range(160):
		await get_tree().process_frame
		for enemy in main._get_alive_raiders():
			if enemy == null or not is_instance_valid(enemy):
				continue
			_pin_enemy(enemy, far_enemy_pos)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if _is_combat_job(StringName(colonist.current_job.get("type", &""))):
			var min_dist: float = INF
			var enemy_positions: Array[String] = []
			for enemy in main._get_alive_raiders():
				if enemy == null or not is_instance_valid(enemy):
					continue
				min_dist = minf(min_dist, colonist.global_position.distance_to(enemy.global_position))
				enemy_positions.append(str(enemy.global_position))
			_finish(false, "RAID_RALLY_HOLD_TEST_FAIL: combat started before threat entered 160 range job=%s dist=%.1f moved=%d enemies=%s pos=%s" % [str(colonist.current_job.get("type", &"")), min_dist, moved_enemy_count, ",".join(enemy_positions), str(colonist.global_position)])
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
