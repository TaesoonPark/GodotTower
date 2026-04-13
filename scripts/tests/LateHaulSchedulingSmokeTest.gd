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

	for _i in range(180):
		await get_tree().process_frame

	if bool(main.job_system.get("_dirty_haul")):
		_finish(false, "LATE_HAUL_TEST_FAIL: haul producer did not settle before scenario")
		return

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "LATE_HAUL_TEST_FAIL: no colonists")
		return

	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Haul", idx == 0)
		colonist.set_work_enabled(&"Build", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))):
		_finish(false, "LATE_HAUL_TEST_FAIL: stockpile placement failed")
		return

	main._spawn_resource_drop(&"Wood", 18, Vector2(3760.0, 2160.0))
	main._mark_group_cache_dirty(&"stockpile_zones")
	main._mark_jobs_dirty()

	var last_progress_step: int = -1
	var last_pos: Vector2 = colonists[0].global_position if colonists[0] != null and is_instance_valid(colonists[0]) else Vector2.INF
	for step in range(1200):
		await get_tree().process_frame
		var stored: int = _sum_stockpile_amount(&"Wood")
		if stored >= 18:
			_finish(true, "LATE_HAUL_TEST_PASS: late drop scheduled after idle settle")
			return
		var lead = colonists[0]
		if lead != null and is_instance_valid(lead):
			var pos: Vector2 = lead.global_position
			if pos.distance_to(last_pos) > 2.0:
				last_progress_step = step
				last_pos = pos
		if step == 30 and not bool(main.job_system.get("_dirty_haul")) and main.job_system.get("_jobs").is_empty():
			print(_debug_snapshot(main, colonists))
		if last_progress_step >= 0 and step - last_progress_step > 420:
			print(_debug_snapshot(main, colonists))
			_finish(false, "LATE_HAUL_TEST_FAIL: haul colonist stopped making progress")
			return

	print(_debug_snapshot(main, colonists))
	_finish(false, "LATE_HAUL_TEST_FAIL: late drop never entered haul loop")

func _sum_stockpile_amount(resource_type: StringName) -> int:
	var total: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("get_stored_amount"):
			total += int(zone.get_stored_amount(resource_type))
	return total

func _debug_snapshot(main: Node, colonists: Array) -> String:
	var colonist_jobs: Array[String] = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist_jobs.append("%s:%s phase=%s drop=%s zone=%s carried=%s target=%s" % [
			colonist.name,
			String(colonist.current_job.get("type", &"Idle")),
			String(colonist.current_job.get("phase", &"")),
			str(colonist.current_job.get("drop_id", 0)),
			str(colonist.current_job.get("zone_id", 0)),
			str(colonist.current_job.get("carried_amount", 0)),
			str(colonist.current_job.get("target", Vector2.ZERO))
		])
	return "LATE_HAUL_TEST_INFO: dirty_haul=%s queued=%s reservations=%s colonists=%s drops=%d stored=%d" % [
		str(main.job_system.get("_dirty_haul")),
		str(main.job_system.get("_jobs")),
		str(main.job_system.get("_reserved_drop_ids")),
		str(colonist_jobs),
		get_tree().get_nodes_in_group("resource_drops").size(),
		_sum_stockpile_amount(&"Wood")
	]
