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
	enemy.melee_attack = 0.0
	enemy.ranged_attack = 0.0
	enemy.health = maxf(enemy.health, 10000.0)
	enemy._spawn_unclip_left = 0.0
	enemy._move_goal = pos

func _assert_unique_colonist_cells(main: Node, colonists: Array, label: String) -> bool:
	var cells: Dictionary = {}
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("is_dead") and bool(colonist.is_dead()):
			continue
		var key: String = _cell_key(main, colonist.global_position)
		if cells.has(key):
			_finish(false, "%s_FAIL: duplicate colonist cell %s %s/%s details=%s" % [label, key, cells[key], colonist.name, _describe_colonists(main, colonists)])
			return false
		cells[key] = colonist.name
	return true

func _describe_colonists(main: Node, colonists: Array) -> String:
	var parts: Array[String] = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var job: Dictionary = colonist.current_job
		var cache_cell: Vector2 = colonist.get("_melee_goal_cache_cell")
		parts.append("%s pos=%s cell=%s job=%s target=%s cache=%s lock=%s" % [
			colonist.name,
			str(colonist.global_position),
			str(main._snap_to_tile(colonist.global_position)),
			str(job.get("type", &"")),
			str(job.get("target", Vector2.INF)),
			str(cache_cell),
			str(colonist.is_melee_combat_locked() if colonist.has_method("is_melee_combat_locked") else false)
		])
	return " | ".join(parts)

func _assert_unique_locked_cells(main: Node, colonists: Array) -> bool:
	var cells: Dictionary = {}
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not colonist.has_method("is_melee_combat_locked") or not bool(colonist.is_melee_combat_locked()):
			continue
		var key: String = _cell_key(main, colonist.global_position)
		if cells.has(key):
			_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: duplicate locked melee cell %s" % key)
			return false
		var target_id: int = int(colonist.current_job.get("target_id", 0))
		var target_obj: Object = instance_from_id(target_id)
		if target_obj != null and is_instance_valid(target_obj) and target_obj is Node2D:
			var own_cell: Vector2 = main._snap_to_tile(colonist.global_position)
			var target_cell: Vector2 = main._snap_to_tile((target_obj as Node2D).global_position)
			var dx: int = absi(int(round((own_cell.x - target_cell.x) / 64.0)))
			var dy: int = absi(int(round((own_cell.y - target_cell.y) / 64.0)))
			if maxi(dx, dy) > 1:
				_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: locked melee outside adjacent cell own=%s target=%s" % [str(own_cell), str(target_cell)])
				return false
		cells[key] = true
	return true

func _settle_at_rally(main: Node, colonists: Array, far_enemy_pos: Vector2) -> bool:
	for _step in range(900):
		await get_tree().process_frame
		for enemy in main._get_alive_raiders():
			if enemy != null and is_instance_valid(enemy):
				_pin_enemy(enemy, far_enemy_pos)
		var settled: bool = true
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			if StringName(colonist.current_job.get("type", &"")) == &"MoveTo":
				settled = false
				break
		if settled:
			return true
	return false

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 3:
		_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: insufficient colonists")
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
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})

	main._set_combat_rally_point(rally_pos)
	main._raid_wave_size = 4
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	main._mark_group_cache_dirty(&"raiders")
	main._mark_group_cache_dirty(&"zombies")
	var far_enemy_pos: Vector2 = Vector2(7440.0, 4160.0)
	for enemy in main._get_alive_raiders():
		if enemy != null and is_instance_valid(enemy):
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

	var settled: bool = await _settle_at_rally(main, colonists, far_enemy_pos)
	if not settled:
		_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: colonists did not settle at rally")
		return
	if not _assert_unique_colonist_cells(main, colonists, "RALLY_MELEE_TRANSITION_NO_OVERLAP"):
		return

	var enemies: Array = main._get_alive_raiders()
	if enemies.is_empty():
		_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: no raid enemies")
		return
	var close_enemy = enemies[0]
	var close_enemy_pos: Vector2 = main._snap_to_tile(rally_pos + Vector2(80.0, 0.0))
	_pin_enemy(close_enemy, close_enemy_pos)
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	var saw_melee: bool = false
	for _step in range(300):
		await get_tree().process_frame
		if close_enemy != null and is_instance_valid(close_enemy):
			_pin_enemy(close_enemy, close_enemy_pos)
		if not _assert_unique_colonist_cells(main, colonists, "RALLY_MELEE_TRANSITION_NO_OVERLAP"):
			return
		if not _assert_unique_locked_cells(main, colonists):
			return
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			if StringName(colonist.current_job.get("type", &"")) == &"CombatMelee":
				saw_melee = true
	if not saw_melee:
		_finish(false, "RALLY_MELEE_TRANSITION_NO_OVERLAP_FAIL: no melee combat job observed")
		return

	_finish(true, "RALLY_MELEE_TRANSITION_NO_OVERLAP_PASS: rally-to-melee transition keeps colonist cells unique")
