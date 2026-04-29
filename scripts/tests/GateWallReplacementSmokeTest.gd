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

	var blueprint_wall_pos: Vector2 = Vector2(3904.0, 2176.0)
	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(blueprint_wall_pos, true):
		_finish(false, "GATE_WALL_REPLACE_FAIL: initial wall blueprint placement failed")
		return
	if not main._try_place_building_by_id(blueprint_wall_pos, &"Gate"):
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate over wall blueprint request was rejected")
		return
	await get_tree().process_frame
	if _find_build_site(&"Wall", blueprint_wall_pos) != null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: wall blueprint still exists")
		return
	if _find_build_site(&"Gate", blueprint_wall_pos) == null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate blueprint was not placed over wall blueprint")
		return
	main._cancel_build_site(_find_build_site(&"Gate", blueprint_wall_pos))
	await get_tree().process_frame

	var wall_pos: Vector2 = Vector2(4096.0, 2176.0)
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.global_position = wall_pos + Vector2(-80.0, float(idx) * 40.0)
		colonist.cancel_current_job()
		colonist.set_work_enabled(&"Build", idx == 0)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Haul", false)

	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(wall_pos, false):
		_finish(false, "GATE_WALL_REPLACE_FAIL: initial wall placement failed")
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	if not main._try_place_building_by_id(wall_pos, &"Gate"):
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate replacement request was rejected")
		return

	var wall: Node = _find_structure(&"Wall")
	if wall == null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: wall missing before demolition")
		return
	if not bool(wall.get_meta("demolish_job_queued")):
		_finish(false, "GATE_WALL_REPLACE_FAIL: wall demolition was not queued")
		return

	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	var found_demolish_job: bool = false
	for job in main.job_system._jobs:
		if StringName(job.get("type", &"")) != &"DemolishStructure":
			continue
		if StringName(job.get("replace_building_id", &"")) != &"Gate":
			continue
		found_demolish_job = true
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			_finish(false, "GATE_WALL_REPLACE_FAIL: demolish target missing")
			return
		if target.distance_to(wall_pos) <= 18.0:
			_finish(false, "GATE_WALL_REPLACE_FAIL: demolish target remained inside wall")
			return
		if occupancy != null and is_instance_valid(occupancy) and occupancy.has_method("is_blocked_for_friendly"):
			if bool(occupancy.is_blocked_for_friendly(target)):
				_finish(false, "GATE_WALL_REPLACE_FAIL: demolish target was blocked")
				return
		break
	if not found_demolish_job:
		_finish(false, "GATE_WALL_REPLACE_FAIL: replacement demolish job missing")
		return

	main._set_game_speed(4.0)
	var gate_completed: bool = false
	for _step in range(900):
		await get_tree().process_frame
		var gate: Node = _find_structure(&"Gate")
		if gate != null:
			gate_completed = true
			break

	if not gate_completed:
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate did not replace wall state=%s" % JSON.stringify(_debug_state(main)))
		return
	if _find_structure(&"Wall") != null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: wall still exists after gate completion")
		return

	_finish(true, "GATE_WALL_REPLACE_PASS: gate blueprint replaces an existing wall")

func _find_structure(building_id: StringName) -> Node:
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure == null or not is_instance_valid(structure):
			continue
		if not structure.has_meta("building_id"):
			continue
		if StringName(structure.get_meta("building_id")) == building_id:
			return structure
	return null

func _find_build_site(building_id: StringName, world_pos: Vector2) -> Node:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if site.is_queued_for_deletion() or not site.is_inside_tree():
			continue
		if StringName(site.get("building_id")) != building_id:
			continue
		if site.global_position.distance_to(world_pos) <= 1.0:
			return site
	return null

func _debug_state(main: Node) -> Dictionary:
	var gate_sites: int = 0
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if StringName(site.get("building_id")) == &"Gate":
			gate_sites += 1
	var active_jobs: Array = []
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		active_jobs.append({
			"name": colonist.name,
			"pos": str(colonist.global_position),
			"job": String(colonist.current_job.get("type", &"")),
			"target": str(colonist.current_job.get("target", Vector2.INF))
		})
	return {
		"wall": _find_structure(&"Wall") != null,
		"gate": _find_structure(&"Gate") != null,
		"gate_sites": gate_sites,
		"queued_jobs": main.job_system._jobs.size(),
		"active_jobs": active_jobs,
		"stock": main.resource_stock
	}
