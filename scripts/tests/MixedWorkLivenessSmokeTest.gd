extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
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
		_finish(false, "MIXED_LIVENESS_TEST_FAIL: no colonists")
		return

	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Haul", idx < 3)
		colonist.set_work_enabled(&"Gather", idx != 3)
		colonist.set_work_enabled(&"Build", true)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(4080.0, 2200.0), Vector2(360.0, 240.0))):
		_finish(false, "MIXED_LIVENESS_TEST_FAIL: stockpile placement failed")
		return

	var wood_node = _spawn_gatherable(main, &"Wood", "LivenessTree", Vector2(3720.0, 2160.0), 90)
	var stone_node = _spawn_gatherable(main, &"Stone", "LivenessRock", Vector2(3680.0, 2240.0), 90)

	if wood_node == null or stone_node == null:
		_finish(false, "MIXED_LIVENESS_TEST_FAIL: gatherable spawn failed")
		return

	main.build_system.set_selected_building(&"Floor")
	if not bool(main.build_system.place_building(Vector2(3920.0, 2320.0), true)):
		_finish(false, "MIXED_LIVENESS_TEST_FAIL: floor blueprint failed")
		return
	main.build_system.set_selected_building(&"Wall")
	if not bool(main.build_system.place_building(Vector2(4040.0, 2320.0), true)):
		_finish(false, "MIXED_LIVENESS_TEST_FAIL: wall blueprint failed")
		return

	main.job_system.mark_designation_dirty()
	main._mark_jobs_dirty()

	var last_hash: String = ""
	var last_change_step: int = 0

	for step in range(5600):
		if step == 160:
			main._spawn_resource_drop(&"Wood", 25, Vector2(3780.0, 2120.0))
		elif step == 420:
			main._spawn_resource_drop(&"Stone", 20, Vector2(3820.0, 2120.0))
		elif step == 760:
			main.build_system.set_selected_building(&"Wall")
			main.build_system.place_building(Vector2(4080.0, 2320.0), true)
		await get_tree().process_frame

		var current_hash: String = _state_hash(main)
		if current_hash != last_hash:
			last_hash = current_hash
			last_change_step = step
		elif _has_pending_work(main) and step - last_change_step > 540:
			print(_debug_snapshot(main, colonists))
			_finish(false, "MIXED_LIVENESS_TEST_FAIL: state stopped changing while work remained")
			return

		if _floor_complete(main) and _all_drops_cleared() and _sum_stockpile_amount(&"Stone") >= 20:
			_finish(true, "MIXED_LIVENESS_TEST_PASS: mixed workload stayed live")
			return

	print(_debug_snapshot(main, colonists))
	_finish(false, "MIXED_LIVENESS_TEST_FAIL: timed out before mixed workload completion")

func _spawn_gatherable(main: Node, resource_type: StringName, display_name: String, pos: Vector2, amount: int) -> Node:
	var node = GATHERABLE_SCENE.instantiate()
	node.global_position = pos
	main.world_root.add_child(node)
	node.resource_type = resource_type
	node.display_name = display_name
	node.max_amount = amount
	node.current_amount = amount
	node.gather_per_tick = 10
	node.set_designated(true)
	main._mark_group_cache_dirty(&"gatherables")
	return node

func _floor_complete(main: Node) -> bool:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if StringName(site.get("building_id")) == &"Floor" and bool(site.get("complete")):
			return true
	return false

func _all_drops_cleared() -> bool:
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if int(drop.get("amount")) > 0:
			return false
	return true

func _sum_stockpile_amount(resource_type: StringName) -> int:
	var total: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("get_stored_amount"):
			total += int(zone.get_stored_amount(resource_type))
	return total

func _has_pending_work(main: Node) -> bool:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not bool(site.get("complete")):
			return true
	for node in get_tree().get_nodes_in_group("gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_depleted") and not bool(node.is_depleted()) and bool(node.get("designated")):
			return true
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if int(drop.get("amount")) > 0:
			return true
	if not main.job_system.get("_jobs").is_empty():
		return true
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not colonist.current_job.is_empty():
			return true
	return false

func _state_hash(main: Node) -> String:
	var colonist_rows: Array[String] = []
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		var pos: Vector2 = colonist.global_position
		var row: String = "%s:%d:%d:%s:%s:%d" % [
			colonist.name,
			int(round(pos.x / 10.0)),
			int(round(pos.y / 10.0)),
			String(colonist.current_job.get("type", &"Idle")),
			String(colonist.current_job.get("phase", &"")),
			int(round(float(colonist.current_job.get("work_elapsed", 0.0)) * 10.0))
		]
		colonist_rows.append(row)
	colonist_rows.sort()

	var build_rows: Array[String] = []
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		build_rows.append("%s:%s:%d:%d" % [
			String(site.get("building_id")),
			str(site.get("complete")),
			int(round(float(site.get("work_progress")) * 10.0)),
			int(site.get("job_queued"))
		])
	build_rows.sort()

	var gather_rows: Array[String] = []
	for node in get_tree().get_nodes_in_group("gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		gather_rows.append("%s:%d:%s:%s" % [
			String(node.get("resource_type")),
			int(node.get("current_amount")),
			str(node.get("designated")),
			str(node.get("job_queued"))
		])
	gather_rows.sort()

	var drop_rows: Array[String] = []
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		drop_rows.append("%s:%d:%s" % [
			String(drop.get("resource_type")),
			int(drop.get("amount")),
			str(drop.get("job_queued"))
		])
	drop_rows.sort()

	return JSON.stringify({
		"c": colonist_rows,
		"b": build_rows,
		"g": gather_rows,
		"d": drop_rows,
		"j": main.job_system.get("_jobs"),
		"r": main.job_system.get("_reserved_drop_ids"),
		"s": {
			"Wood": _sum_stockpile_amount(&"Wood"),
			"Stone": _sum_stockpile_amount(&"Stone")
		}
	})

func _debug_snapshot(main: Node, colonists: Array) -> String:
	var colonist_jobs: Array[String] = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist_jobs.append("%s:%s:%s started=%s elapsed=%.2f target=%s@%s" % [
			colonist.name,
			String(colonist.current_job.get("type", &"Idle")),
			String(colonist.current_job.get("phase", &"")),
			str(colonist.current_job.get("work_started", false)),
			float(colonist.current_job.get("work_elapsed", 0.0)),
			str(colonist.current_job.get("target", Vector2.ZERO)),
			str(colonist.global_position)
		])
	var build_rows: Array[String] = []
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		build_rows.append("%s complete=%s progress=%.2f queued=%s" % [
			String(site.get("building_id")),
			str(site.get("complete")),
			float(site.get("work_progress")),
			str(site.get("job_queued"))
		])
	var gather_rows: Array[String] = []
	for node in get_tree().get_nodes_in_group("gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		gather_rows.append("%s amount=%d designated=%s queued=%s" % [
			String(node.get("resource_type")),
			int(node.get("current_amount")),
			str(node.get("designated")),
			str(node.get("job_queued"))
		])
	return "MIXED_LIVENESS_TEST_INFO: queued=%s reservations=%s colonists=%s builds=%s gather=%s stock={Wood:%d,Stone:%d} drops=%d" % [
		str(main.job_system.get("_jobs")),
		str(main.job_system.get("_reserved_drop_ids")),
		str(colonist_jobs),
		str(build_rows),
		str(gather_rows),
		_sum_stockpile_amount(&"Wood"),
		_sum_stockpile_amount(&"Stone"),
		get_tree().get_nodes_in_group("resource_drops").size()
	]
