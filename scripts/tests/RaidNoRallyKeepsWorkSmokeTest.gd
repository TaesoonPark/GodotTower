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

func _is_combat_job(job_type: StringName) -> bool:
	return job_type == &"CombatMelee" or job_type == &"CombatRanged"

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)

	for _i in range(20):
		await get_tree().process_frame

	if main._rally_flag_node != null and is_instance_valid(main._rally_flag_node):
		main._rally_flag_node.queue_free()
	main._rally_flag_node = null

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "RAID_NO_RALLY_TEST_FAIL: no colonists")
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
		colonist.set_work_enabled(&"Combat", true)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))):
		_finish(false, "RAID_NO_RALLY_TEST_FAIL: stockpile placement failed")
		return

	main._mark_group_cache_dirty(&"stockpile_zones")
	main._mark_jobs_dirty()
	var drop: Node = main._spawn_resource_drop(&"Wood", 80, Vector2(3760.0, 2160.0))
	if drop is Node2D:
		(drop as Node2D).global_position = Vector2(3760.0, 2160.0)

	var lead = colonists[0]
	for _step in range(500):
		await get_tree().process_frame
		if StringName(lead.current_job.get("type", &"")) == &"HaulResource":
			break
	if StringName(lead.current_job.get("type", &"")) != &"HaulResource":
		_finish(false, "RAID_NO_RALLY_TEST_FAIL: lead did not enter hauling before raid")
		return

	main._start_raid_wave()
	var saw_noncombat_work: bool = false

	for _step in range(520):
		await get_tree().process_frame
		var enemies: Array = main._get_alive_raiders()
		if enemies.is_empty():
			continue
		var lead_job: StringName = StringName(lead.current_job.get("type", &""))
		if _is_combat_job(lead_job):
			_finish(false, "RAID_NO_RALLY_TEST_FAIL: lead switched to combat without rally")
			return
		if lead_job != &"":
			saw_noncombat_work = true
		if _is_drop_cleared(drop):
			saw_noncombat_work = true
	if saw_noncombat_work:
		_finish(true, "RAID_NO_RALLY_TEST_PASS: raid keeps ongoing work when no rally is set")
		return
	_finish(false, "RAID_NO_RALLY_TEST_FAIL: no non-combat work observed during active raid")
