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

func _cell_key(main: Node, pos: Vector2) -> String:
	var cell: Vector2 = main._snap_to_tile(pos)
	return "%d,%d" % [int(round(cell.x)), int(round(cell.y))]

func _is_combat_job(job_type: StringName) -> bool:
	return job_type == &"CombatMelee" or job_type == &"CombatRanged"

func _pin_enemy(enemy: Node2D, pos: Vector2) -> void:
	enemy.global_position = pos
	enemy.move_speed = 0.0
	enemy._spawn_unclip_left = 0.0
	enemy._move_goal = pos

func _move_target_for(main: Node, colonist: Node) -> Vector2:
	var current_job: Dictionary = colonist.current_job
	if StringName(current_job.get("type", &"")) == &"MoveTo":
		return current_job.get("target", Vector2.INF)
	for job in main.job_system._jobs:
		if int(job.get("assigned_to", 0)) != colonist.get_instance_id():
			continue
		if StringName(job.get("type", &"")) == &"MoveTo":
			return job.get("target", Vector2.INF)
	return Vector2.INF

func _assert_unique_centered(main: Node, colonists: Array) -> bool:
	var cells: Dictionary = {}
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var cell: Vector2 = main._snap_to_tile(colonist.global_position)
		if colonist.global_position.distance_to(cell) > 0.02:
			_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: colonist not centered pos=%s cell=%s" % [str(colonist.global_position), str(cell)])
			return false
		var key: String = _cell_key(main, colonist.global_position)
		if cells.has(key):
			_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: duplicate settled cell %s" % key)
			return false
		cells[key] = true
	return true

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 3:
		_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: insufficient colonists")
		return

	var rally_pos: Vector2 = main._snap_to_tile(Vector2(3840.0, 2160.0))
	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.global_position = main._snap_to_tile(Vector2(3200.0 + float(idx) * 40.0, 1880.0))
		colonist.set_selected(false)
		colonist.set_work_enabled(&"Combat", true)

	main._set_combat_rally_point(rally_pos)
	main._raid_wave_size = 4
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	main._mark_group_cache_dirty(&"raiders")
	main._mark_group_cache_dirty(&"zombies")
	var far_enemy_pos: Vector2 = Vector2(7440.0, 4160.0)
	for enemy in main._get_alive_raiders():
		if enemy == null or not is_instance_valid(enemy):
			continue
		_pin_enemy(enemy, far_enemy_pos)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if _is_combat_job(StringName(colonist.current_job.get("type", &""))) and colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
	main.job_system._jobs.clear()
	main.job_system._rallied_colonist_ids.clear()
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	var saw_targets: bool = false
	for _step in range(120):
		await get_tree().process_frame
		for enemy in main._get_alive_raiders():
			if enemy != null and is_instance_valid(enemy):
				_pin_enemy(enemy, far_enemy_pos)
		var targets: Dictionary = {}
		var missing: bool = false
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var target: Vector2 = _move_target_for(main, colonist)
			if target == Vector2.INF:
				missing = true
				break
			var key: String = _cell_key(main, target)
			if targets.has(key):
				_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: duplicate rally MoveTo target %s" % key)
				return
			targets[key] = true
		if not missing:
			saw_targets = true
			break
	if not saw_targets:
		_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: rally MoveTo targets were not assigned")
		return

	var settled: bool = false
	for _step in range(900):
		await get_tree().process_frame
		for enemy in main._get_alive_raiders():
			if enemy != null and is_instance_valid(enemy):
				_pin_enemy(enemy, far_enemy_pos)
		settled = true
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			if StringName(colonist.current_job.get("type", &"")) == &"MoveTo":
				settled = false
				break
		if settled:
			break
	if not settled:
		_finish(false, "RALLY_FORMATION_NO_OVERLAP_FAIL: colonists did not settle at rally")
		return
	if not _assert_unique_centered(main, colonists):
		return

	_finish(true, "RALLY_FORMATION_NO_OVERLAP_PASS: rally MoveTo targets and settled cells are unique")
