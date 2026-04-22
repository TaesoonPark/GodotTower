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
		_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: no colonists")
		return

	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Build", idx == 0)
		colonist.set_work_enabled(&"Craft", idx <= 1)
		colonist.set_work_enabled(&"Haul", idx <= 1)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(3880.0, 2140.0), Vector2(240.0, 160.0))):
		_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: stockpile placement failed")
		return
	main._spawn_resource_drop(&"FoodRaw", 4, Vector2(3810.0, 2160.0))

	main.build_system.set_selected_building(&"Campfire")
	if not bool(main.build_system.place_building(Vector2(3960.0, 2200.0), true)):
		_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: campfire blueprint failed")
		return
	var campfire_pos: Vector2 = main._snap_to_tile(Vector2(3960.0, 2200.0))

	main._mark_jobs_dirty()

	var campfire_ready: bool = false
	for _step in range(2400):
		await get_tree().process_frame
		for site in get_tree().get_nodes_in_group("build_sites"):
			if site == null or not is_instance_valid(site):
				continue
			if StringName(site.get("building_id")) == &"Campfire" and bool(site.get("complete")):
				campfire_ready = true
				break
		if campfire_ready:
			break
	if not campfire_ready:
		_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: campfire did not complete")
		return

	main._on_craft_recipe_queued(&"CookMeal", &"CampfireStation")

	var observed_craft_supply: bool = false
	for _step in range(3200):
		await get_tree().process_frame
		var meal_drops: int = 0
		for drop in get_tree().get_nodes_in_group("resource_drops"):
			if drop == null or not is_instance_valid(drop):
				continue
			var is_craft_supply: bool = bool(drop.get_meta("craft_supply")) if drop.has_meta("craft_supply") else false
			if is_craft_supply and StringName(drop.get("resource_type")) == &"FoodRaw":
				observed_craft_supply = true
				if drop.global_position.distance_to(campfire_pos) <= 0.1:
					_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: craft supply drop teleported directly to campfire tile")
					return
			if StringName(drop.get("resource_type")) == &"Meal":
				meal_drops += int(drop.get("amount"))
		if meal_drops >= 5:
			if not observed_craft_supply:
				print(_debug_snapshot(main, colonists))
				_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: no craft supply FoodRaw drop observed")
				return
			_finish(true, "CRAFT_WORKFLOW_TEST_PASS: blueprint workstation crafted recipe")
			return

	print(_debug_snapshot(main, colonists))
	_finish(false, "CRAFT_WORKFLOW_TEST_FAIL: queued recipe never completed")

func _debug_snapshot(main: Node, colonists: Array) -> String:
	var craft_queue: Array = main.job_system.get_craft_queue(&"CampfireStation")
	var queued_jobs: Array[String] = []
	for job in main.job_system._jobs:
		queued_jobs.append("%s:%s" % [String(job.get("type", &"")), String(job.get("workstation_id", &""))])
	var colonist_rows: Array[String] = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist_rows.append("%s:%s target=%s" % [
			colonist.name,
			String(colonist.current_job.get("type", &"Idle")),
			str(colonist.current_job.get("target", Vector2.ZERO))
		])
	var depot = main._workstation_depots.get(&"CampfireStation", null)
	var depot_state: Dictionary = {}
	if depot != null and is_instance_valid(depot):
		depot_state = {
			"stored": depot.stored,
			"requested": depot.requested,
			"pending": depot.pending
		}
	var slots_map: Dictionary = main._get_cached_workstation_slots_map()
	var can_start: bool = false
	if main.recipe_lookup.has(&"CookMeal"):
		can_start = bool(main._can_start_recipe_at_workstation(&"CampfireStation", main.recipe_lookup[&"CookMeal"]))
	return "CRAFT_WORKFLOW_TEST_INFO: %s" % [
		str({
			"queue": craft_queue,
			"jobs": queued_jobs,
			"colonists": colonist_rows,
			"depot": depot_state,
			"slots": slots_map.get(&"CampfireStation", []),
			"can_start": can_start,
			"dirty_craft": main.job_system._dirty_craft,
			"dispatch_jobs_dirty": main._dispatch_jobs_dirty,
			"reserved_slots": main.job_system._reserved_craft_slot_ids
		})
	]
