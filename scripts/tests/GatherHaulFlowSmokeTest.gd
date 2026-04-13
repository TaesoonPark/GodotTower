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
		_finish(false, "GATHER_HAUL_TEST_FAIL: no colonists")
		return

	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Build", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", idx == 0)
		colonist.set_work_enabled(&"Haul", idx == 0)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))):
		_finish(false, "GATHER_HAUL_TEST_FAIL: stockpile placement failed")
		return

	var node = GATHERABLE_SCENE.instantiate()
	node.global_position = Vector2(3760.0, 2160.0)
	main.world_root.add_child(node)
	node.resource_type = &"Wood"
	node.display_name = "GatherHaulTree"
	node.max_amount = 60
	node.current_amount = 60
	node.gather_per_tick = 10
	node.set_designated(true)

	main._mark_group_cache_dirty(&"gatherables")
	main._mark_group_cache_dirty(&"stockpile_zones")
	main.job_system.mark_designation_dirty()
	main._mark_jobs_dirty()

	var last_progress_step: int = -1
	var last_drop_count: int = 0
	var last_stock_count: int = 0
	var stuck_snapshot: String = ""

	for step in range(3600):
		await get_tree().process_frame
		var remaining_gather: int = int(node.current_amount) if node != null and is_instance_valid(node) else 0
		var drop_count: int = _sum_drop_amount()
		var stock_count: int = _sum_stockpile_amount(&"Wood")
		if drop_count != last_drop_count or stock_count != last_stock_count or remaining_gather < 60:
			last_progress_step = step
			last_drop_count = drop_count
			last_stock_count = stock_count
		if remaining_gather <= 0 and drop_count <= 0 and stock_count >= 60:
			_finish(true, "GATHER_HAUL_TEST_PASS: gather to haul flow completed")
			return
		if last_progress_step >= 0 and step - last_progress_step > 480:
			stuck_snapshot = _debug_snapshot(main, colonists, remaining_gather, drop_count, stock_count)
			break

	if stuck_snapshot != "":
		print(stuck_snapshot)
		_finish(false, "GATHER_HAUL_TEST_FAIL: gather/haul flow stalled")
		return

	print(_debug_snapshot(main, colonists, int(node.current_amount) if node != null and is_instance_valid(node) else -1, _sum_drop_amount(), _sum_stockpile_amount(&"Wood")))
	_finish(false, "GATHER_HAUL_TEST_FAIL: timed out before gather/haul completion")

func _sum_drop_amount() -> int:
	var total: int = 0
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		total += int(drop.get("amount"))
	return total

func _sum_stockpile_amount(resource_type: StringName) -> int:
	var total: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("get_stored_amount"):
			total += int(zone.get_stored_amount(resource_type))
	return total

func _debug_snapshot(main: Node, colonists: Array, remaining_gather: int, drop_count: int, stock_count: int) -> String:
	var queued_jobs: Array[String] = []
	for job in main.job_system._jobs:
		queued_jobs.append("%s:%s" % [
			String(job.get("type", &"")),
			String(job.get("phase", &""))
		])
	var colonist_jobs: Array[String] = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist_jobs.append("%s:%s@%s" % [
			colonist.name,
			String(colonist.current_job.get("type", &"Idle")),
			str(colonist.global_position)
		])
	return "GATHER_HAUL_TEST_INFO: remaining_gather=%d drops=%d stored=%d reservations=%s queued=%s colonists=%s" % [
		remaining_gather,
		drop_count,
		stock_count,
		str(main.job_system._reserved_drop_ids),
		str(queued_jobs),
		str(colonist_jobs)
	]
