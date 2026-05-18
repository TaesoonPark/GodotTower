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

	if not await _assert_blueprint_replaces(main, &"Wall", Vector2(3904.0, 2176.0), "wall"):
		return
	if not await _assert_blueprint_replaces(main, &"FiringWall", Vector2(3968.0, 2176.0), "firing wall"):
		return
	if not await _assert_completed_replaces(main, &"Wall", Vector2(4096.0, 2176.0), "wall"):
		return
	if not await _assert_completed_replaces(main, &"FiringWall", Vector2(4160.0, 2176.0), "firing wall"):
		return

	_finish(true, "GATE_WALL_REPLACE_PASS: gate replaces wall and firing wall blueprints and structures")

func _assert_blueprint_replaces(main: Node, source_building_id: StringName, world_pos: Vector2, label: String) -> bool:
	main.build_system.set_selected_building(source_building_id)
	if not main.build_system.place_building(world_pos, true):
		_finish(false, "GATE_WALL_REPLACE_FAIL: initial %s blueprint placement failed" % label)
		return false
	if not main._try_place_building_by_id(world_pos, &"Gate"):
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate over %s blueprint request was rejected" % label)
		return false
	await get_tree().process_frame
	if _find_build_site(source_building_id, world_pos) != null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: %s blueprint still exists" % label)
		return false
	var gate_site: Node = _find_build_site(&"Gate", world_pos)
	if gate_site == null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate blueprint was not placed over %s blueprint" % label)
		return false
	main._cancel_build_site(gate_site)
	await get_tree().process_frame
	return true

func _assert_completed_replaces(main: Node, source_building_id: StringName, world_pos: Vector2, label: String) -> bool:
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.global_position = world_pos + Vector2(-80.0, float(idx) * 40.0)
		colonist.cancel_current_job()
		colonist.set_work_enabled(&"Build", idx == 0)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Haul", false)

	main.build_system.set_selected_building(source_building_id)
	if not main.build_system.place_building(world_pos, false):
		_finish(false, "GATE_WALL_REPLACE_FAIL: initial %s placement failed" % label)
		return false
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	if not main._try_place_building_by_id(world_pos, &"Gate"):
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate over %s replacement request was rejected" % label)
		return false

	var wall: Node = _find_structure(source_building_id, world_pos)
	if wall == null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: %s missing before demolition" % label)
		return false
	if not bool(wall.get_meta("demolish_job_queued")):
		_finish(false, "GATE_WALL_REPLACE_FAIL: %s demolition was not queued" % label)
		return false

	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	var found_demolish_job: bool = false
	for job in main.job_system._jobs:
		if StringName(job.get("type", &"")) != &"DemolishStructure":
			continue
		if int(job.get("structure_id", 0)) != wall.get_instance_id():
			continue
		if StringName(job.get("replace_building_id", &"")) != &"Gate":
			continue
		found_demolish_job = true
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			_finish(false, "GATE_WALL_REPLACE_FAIL: %s demolish target missing" % label)
			return false
		if target.distance_to(world_pos) <= 18.0:
			_finish(false, "GATE_WALL_REPLACE_FAIL: %s demolish target remained inside wall" % label)
			return false
		if occupancy != null and is_instance_valid(occupancy) and occupancy.has_method("is_blocked_for_friendly"):
			if bool(occupancy.is_blocked_for_friendly(target)):
				_finish(false, "GATE_WALL_REPLACE_FAIL: %s demolish target was blocked" % label)
				return false
		break
	if not found_demolish_job:
		_finish(false, "GATE_WALL_REPLACE_FAIL: %s replacement demolish job missing" % label)
		return false

	main._set_game_speed(4.0)
	var gate_completed: bool = false
	for _step in range(900):
		await get_tree().process_frame
		var gate: Node = _find_structure(&"Gate", world_pos)
		if gate != null:
			gate_completed = true
			break

	if not gate_completed:
		_finish(false, "GATE_WALL_REPLACE_FAIL: gate did not replace %s state=%s" % [label, JSON.stringify(_debug_state(main))])
		return false
	if _find_structure(source_building_id, world_pos) != null:
		_finish(false, "GATE_WALL_REPLACE_FAIL: %s still exists after gate completion" % label)
		return false
	return true

func _find_structure(building_id: StringName, world_pos: Vector2 = Vector2.INF) -> Node:
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure == null or not is_instance_valid(structure):
			continue
		if not structure.has_meta("building_id"):
			continue
		if StringName(structure.get_meta("building_id")) == building_id:
			if world_pos != Vector2.INF and structure.global_position.distance_to(world_pos) > 1.0:
				continue
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
