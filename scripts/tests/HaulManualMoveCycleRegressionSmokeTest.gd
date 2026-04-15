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

func _sum_stockpile_amount(resource_type: StringName) -> int:
	var total: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("get_stored_amount"):
			total += int(zone.get_stored_amount(resource_type))
	return total

func _is_drop_cleared(drop) -> bool:
	if drop == null or not is_instance_valid(drop):
		return true
	if drop.has_method("is_empty") and bool(drop.is_empty()):
		return true
	return false

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)

	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "HAUL_MANUAL_CYCLE_TEST_FAIL: no colonists")
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

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(4080.0, 2200.0), Vector2(200.0, 200.0))):
		_finish(false, "HAUL_MANUAL_CYCLE_TEST_FAIL: stockpile placement failed")
		return

	main._mark_group_cache_dirty(&"stockpile_zones")
	main._mark_jobs_dirty()
	var first_drop: Node = main._spawn_resource_drop(&"Wood", 40, Vector2(3760.0, 2320.0))
	if first_drop is Node2D:
		(first_drop as Node2D).global_position = Vector2(3760.0, 2320.0)
	var first_cleared_frames: int = 0

	for _step in range(2200):
		await get_tree().process_frame
		var lead_job: StringName = StringName(colonists[0].current_job.get("type", &""))
		if _is_drop_cleared(first_drop) and lead_job != &"HaulResource":
			first_cleared_frames += 1
		else:
			first_cleared_frames = 0
		if first_cleared_frames >= 24:
			break
	if first_cleared_frames < 24:
		_finish(false, "HAUL_MANUAL_CYCLE_TEST_FAIL: first haul did not finish")
		return

	var lead = colonists[0]
	if lead == null or not is_instance_valid(lead):
		_finish(false, "HAUL_MANUAL_CYCLE_TEST_FAIL: lead colonist missing")
		return

	main.job_system.issue_immediate_move(lead, lead.global_position + Vector2(120.0, 0.0), true)
	main._mark_jobs_dirty()

	for _step in range(180):
		await get_tree().process_frame

	var second_drop: Node = main._spawn_resource_drop(&"Wood", 40, Vector2(3760.0, 2320.0))
	if second_drop is Node2D:
		(second_drop as Node2D).global_position = Vector2(3760.0, 2320.0)
	main._mark_jobs_dirty()
	var second_cleared_frames: int = 0

	for _step in range(2600):
		await get_tree().process_frame
		var lead_job: StringName = StringName(lead.current_job.get("type", &""))
		if _is_drop_cleared(second_drop) and lead_job != &"HaulResource":
			second_cleared_frames += 1
		else:
			second_cleared_frames = 0
		if second_cleared_frames >= 24:
			_finish(true, "HAUL_MANUAL_CYCLE_TEST_PASS: manual move does not re-introduce haul stall")
			return

	var lead_info: String = "pos=%s job=%s phase=%s target=%s carried=%s" % [
		str(lead.global_position),
		String(lead.current_job.get("type", &"Idle")),
		String(lead.current_job.get("phase", &"")),
		str(lead.current_job.get("target", Vector2.ZERO)),
		str(lead.current_job.get("carried_amount", 0))
	]
	_finish(false, "HAUL_MANUAL_CYCLE_TEST_FAIL: second haul timed out, %s" % lead_info)
