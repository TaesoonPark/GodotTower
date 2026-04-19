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
		_finish(false, "CRAFT_REPEAT_TEST_FAIL: no colonists")
		return

	var produced_state: Dictionary = {"meals": 0}
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
		colonist.craft_completed.connect(func(products: Dictionary, _world_pos: Vector2, _slot_id: int):
			produced_state["meals"] = int(produced_state.get("meals", 0)) + int(products.get(&"Meal", 0))
		)

	if not main.build_system.place_stockpile_zone(Rect2(Vector2(3880.0, 2140.0), Vector2(240.0, 160.0))):
		_finish(false, "CRAFT_REPEAT_TEST_FAIL: stockpile placement failed")
		return
	main._spawn_resource_drop(&"FoodRaw", 3, Vector2(3810.0, 2160.0))

	main.build_system.set_selected_building(&"Campfire")
	if not bool(main.build_system.place_building(Vector2(3960.0, 2200.0), true)):
		_finish(false, "CRAFT_REPEAT_TEST_FAIL: campfire blueprint failed")
		return

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
		_finish(false, "CRAFT_REPEAT_TEST_FAIL: campfire did not complete")
		return

	main._on_craft_recipe_repeat_queued(&"CookMeal", &"CampfireStation")

	var queue_ready: bool = false
	for _step in range(30):
		await get_tree().process_frame
		var queue_seed: Array[Dictionary] = main.job_system.get_craft_queue(&"CampfireStation")
		if queue_seed.is_empty():
			continue
		if bool(queue_seed[0].get("repeat", false)):
			queue_ready = true
			break
	if not queue_ready:
		_finish(false, "CRAFT_REPEAT_TEST_FAIL: repeat craft order not queued")
		return

	for _step in range(3600):
		await get_tree().process_frame
		var produced_meals: int = int(produced_state.get("meals", 0))
		if produced_meals >= 10:
			var queue_after: Array[Dictionary] = main.job_system.get_craft_queue(&"CampfireStation")
			if queue_after.is_empty() or not bool(queue_after[0].get("repeat", false)):
				print(_debug_snapshot(main, produced_meals))
				_finish(false, "CRAFT_REPEAT_TEST_FAIL: repeat order was removed")
				return
			_finish(true, "CRAFT_REPEAT_TEST_PASS: repeat recipe kept producing while materials existed")
			return

	print(_debug_snapshot(main, int(produced_state.get("meals", 0))))
	_finish(false, "CRAFT_REPEAT_TEST_FAIL: repeat crafting did not reach expected output")

func _debug_snapshot(main: Node, produced_meals: int) -> String:
	return "CRAFT_REPEAT_TEST_INFO: %s" % str({
		"produced_meals": produced_meals,
		"queue": main.job_system.get_craft_queue(&"CampfireStation"),
		"jobs": main.job_system._jobs,
		"dirty_craft": main.job_system._dirty_craft,
		"dispatch_jobs_dirty": main._dispatch_jobs_dirty
	})
