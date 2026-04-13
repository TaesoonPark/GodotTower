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

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "HAUL_LOOP_TEST_FAIL: no colonists")
		return

	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Haul", true)
		colonist.set_work_enabled(&"Build", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)

	var stock_rect := Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "HAUL_LOOP_TEST_FAIL: stockpile placement failed")
		return

	main._mark_group_cache_dirty(&"stockpile_zones")
	main._mark_jobs_dirty()

	var drop_positions: Array[Vector2] = [
		Vector2(3760.0, 2160.0),
		Vector2(3800.0, 2160.0),
		Vector2(3840.0, 2160.0),
		Vector2(3880.0, 2160.0)
	]
	for pos in drop_positions:
		main._spawn_resource_drop(&"Wood", 75, pos)

	var expected_total: int = drop_positions.size() * 75
	var last_delivered_step: int = -1
	var last_remaining: int = expected_total
	var stalled_snapshot: String = ""

	for step in range(2400):
		await get_tree().process_frame
		var remaining: int = _sum_drop_amount()
		var stored: int = _sum_stockpile_amount(&"Wood")
		if stored >= expected_total and remaining <= 0:
			_finish(true, "HAUL_LOOP_TEST_PASS: hauled all drops to stockpile")
			return
		if remaining < last_remaining:
			last_remaining = remaining
			last_delivered_step = step
		elif last_delivered_step >= 0 and step - last_delivered_step > 360 and remaining > 0:
			stalled_snapshot = _debug_snapshot(main, colonists, remaining, stored)
			break

	if stalled_snapshot != "":
		print(stalled_snapshot)
		_finish(false, "HAUL_LOOP_TEST_FAIL: hauling stalled with drops remaining")
		return

	var final_snapshot: String = _debug_snapshot(main, colonists, _sum_drop_amount(), _sum_stockpile_amount(&"Wood"))
	print(final_snapshot)
	_finish(false, "HAUL_LOOP_TEST_FAIL: timed out before haul completed")

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

func _debug_snapshot(main: Node, colonists: Array, remaining: int, stored: int) -> String:
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
	return "HAUL_LOOP_TEST_INFO: remaining=%d stored=%d reservations=%s queued=%s colonists=%s" % [
		remaining,
		stored,
		str(main.job_system._reserved_drop_ids),
		str(queued_jobs),
		str(colonist_jobs)
	]
