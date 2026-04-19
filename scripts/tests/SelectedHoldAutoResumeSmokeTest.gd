extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
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

	for _i in range(24):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 2:
		_finish(false, "SELECT_HOLD_TEST_FAIL: colonists not spawned")
		return

	var primary = colonists[0]
	if primary == null or not is_instance_valid(primary):
		_finish(false, "SELECT_HOLD_TEST_FAIL: invalid primary colonist")
		return

	_prepare_colonists(colonists, primary)
	main.job_system._jobs.clear()
	main.job_system.mark_assign_dirty()
	main._mark_jobs_dirty()

	var site_pos_a: Vector2 = main._snap_to_tile(primary.global_position + Vector2(240.0, 0.0))
	var site_pos_b: Vector2 = main._snap_to_tile(primary.global_position + Vector2(320.0, 0.0))
	main._try_place_building_by_id(site_pos_a, &"Wall")
	main._try_place_building_by_id(site_pos_b, &"Wall")
	main._mark_jobs_dirty()

	var picked_build_job: bool = false
	for _step in range(420):
		await get_tree().process_frame
		if StringName(primary.current_job.get("type", &"")) == &"BuildSite":
			picked_build_job = true
			break
	if not picked_build_job:
		_finish(false, "SELECT_HOLD_TEST_FAIL: primary never started first build job")
		return

	main._on_left_click(primary.global_position)
	await get_tree().process_frame
	if not bool(primary.get("selected")):
		_finish(false, "SELECT_HOLD_TEST_FAIL: mouse select did not latch")
		return

	var first_site_id: int = int(primary.current_job.get("site_id", 0))
	if first_site_id == 0:
		_finish(false, "SELECT_HOLD_TEST_FAIL: first build job missing site id")
		return

	var first_site_done: bool = false
	for _step in range(1500):
		await get_tree().process_frame
		var site_obj: Object = instance_from_id(first_site_id)
		var complete: bool = false
		if site_obj != null and is_instance_valid(site_obj):
			complete = bool(site_obj.get("complete"))
		if complete and primary.current_job.is_empty():
			first_site_done = true
			break
	if not first_site_done:
		_finish(false, "SELECT_HOLD_TEST_FAIL: selected unit did not finish current job")
		return

	var pending_second_site: bool = false
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if site.get_instance_id() == first_site_id:
			continue
		if not bool(site.get("complete")):
			pending_second_site = true
			break
	if not pending_second_site:
		_finish(false, "SELECT_HOLD_TEST_FAIL: no pending follow-up build job to validate hold")
		return

	for _step in range(210):
		await get_tree().process_frame
	if not primary.current_job.is_empty():
		_finish(false, "SELECT_HOLD_TEST_FAIL: selected unit picked next non-combat job")
		return

	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = primary.global_position + Vector2(8.0, 0.0)
	main.units_root.add_child(zombie)
	zombie.health = 1.0
	main._mark_combat_dirty()
	main._mark_jobs_dirty()

	var anchor_pos: Vector2 = primary.global_position
	var killed_in_place: bool = false
	for _step in range(540):
		await get_tree().process_frame
		if zombie == null or not is_instance_valid(zombie):
			killed_in_place = true
			break
		if zombie.has_method("is_dead") and bool(zombie.is_dead()):
			killed_in_place = true
			break
	if not killed_in_place:
		print("SELECT_HOLD_TEST_INFO: selected=", bool(primary.get("selected")), " current_job=", StringName(primary.current_job.get("type", &"")), " queued_jobs=", _queued_job_types(main.job_system), " dist=", primary.global_position.distance_to(zombie.global_position), " zombie_hp=", zombie.health if zombie != null and is_instance_valid(zombie) else -1)
		_finish(false, "SELECT_HOLD_TEST_FAIL: selected unit failed to fight in place")
		return

	var moved_dist: float = primary.global_position.distance_to(anchor_pos)
	if moved_dist > 12.0:
		_finish(false, "SELECT_HOLD_TEST_FAIL: selected combat moved off position")
		return

	main._on_left_click(Vector2(40.0, 40.0))
	await get_tree().process_frame
	if bool(primary.get("selected")):
		_finish(false, "SELECT_HOLD_TEST_FAIL: deselect did not clear selection")
		return

	var resumed_auto_work: bool = false
	for _step in range(420):
		await get_tree().process_frame
		if StringName(primary.current_job.get("type", &"")) == &"BuildSite":
			resumed_auto_work = true
			break
	if not resumed_auto_work:
		_finish(false, "SELECT_HOLD_TEST_FAIL: auto work did not resume after deselect")
		return

	_finish(true, "SELECT_HOLD_TEST_PASS: selection hold + in-place combat + auto-resume verified")

func _prepare_colonists(colonists: Array, primary: Node) -> void:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		var is_primary: bool = colonist == primary
		colonist.set_work_enabled(&"Build", is_primary)
		colonist.set_work_enabled(&"Combat", is_primary)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Haul", false)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Hunt", false)
		if is_primary and colonist.has_method("set_build_work_speed_multiplier"):
			colonist.set_build_work_speed_multiplier(3.0)

func _queued_job_types(job_system: Node) -> Array[StringName]:
	var out: Array[StringName] = []
	if job_system == null or not is_instance_valid(job_system):
		return out
	for job in job_system._jobs:
		if not (job is Dictionary):
			continue
		out.append(StringName(job.get("type", &"")))
	return out
