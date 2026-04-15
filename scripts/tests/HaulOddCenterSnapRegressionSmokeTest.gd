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
		_finish(false, "HAUL_ODD_CENTER_TEST_FAIL: no colonists")
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

	var stock_rect := Rect2(Vector2(4080.0, 2200.0), Vector2(200.0, 200.0))
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "HAUL_ODD_CENTER_TEST_FAIL: stockpile placement failed")
		return

	main._mark_group_cache_dirty(&"stockpile_zones")
	main._mark_jobs_dirty()
	var drop: Node = main._spawn_resource_drop(&"Wood", 40, Vector2(3760.0, 2320.0))
	if drop is Node2D:
		(drop as Node2D).global_position = Vector2(3760.0, 2320.0)
	var cleared_frames: int = 0

	for _step in range(2200):
		await get_tree().process_frame
		var lead = colonists[0]
		var lead_job: StringName = StringName(lead.current_job.get("type", &"")) if lead != null and is_instance_valid(lead) else &""
		if _is_drop_cleared(drop) and lead_job != &"HaulResource":
			cleared_frames += 1
		else:
			cleared_frames = 0
		if cleared_frames >= 24:
			_finish(true, "HAUL_ODD_CENTER_TEST_PASS: to_zone snap mismatch no longer stalls")
			return

	var lead = colonists[0]
	var lead_info: String = "<invalid>"
	var remaining_drop: int = 0
	for drop_node in get_tree().get_nodes_in_group("resource_drops"):
		if drop_node == null or not is_instance_valid(drop_node):
			continue
		remaining_drop += int(drop_node.get("amount"))
	if lead != null and is_instance_valid(lead):
		lead_info = "pos=%s job=%s phase=%s target=%s carried=%s stored=%d drops=%d" % [
			str(lead.global_position),
			String(lead.current_job.get("type", &"Idle")),
			String(lead.current_job.get("phase", &"")),
			str(lead.current_job.get("target", Vector2.ZERO)),
			str(lead.current_job.get("carried_amount", 0)),
			_sum_stockpile_amount(&"Wood"),
			remaining_drop
		]
	_finish(false, "HAUL_ODD_CENTER_TEST_FAIL: timed out, %s" % lead_info)
