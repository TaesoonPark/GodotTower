extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const FARM_RECT := Rect2(Vector2(3720.0, 2120.0), Vector2(120.0, 120.0))

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

	for _i in range(16):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "FARM_TEST_FAIL: colonists not spawned")
		return

	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_work_enabled(&"Haul", false)
		colonist.set_work_enabled(&"Build", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", true)

	if main.build_system == null or not is_instance_valid(main.build_system):
		_finish(false, "FARM_TEST_FAIL: build_system missing")
		return
	if not bool(main.build_system.place_farm_zone(FARM_RECT)):
		_finish(false, "FARM_TEST_FAIL: farm zone not created")
		return

	for _i in range(8):
		await get_tree().process_frame

	var farm_zones: Array = get_tree().get_nodes_in_group("farm_zones")
	if farm_zones.is_empty():
		_finish(false, "FARM_TEST_FAIL: farm zone not registered")
		return
	var zone = farm_zones[0]
	if zone == null or not is_instance_valid(zone):
		_finish(false, "FARM_TEST_FAIL: farm zone invalid")
		return

	var plot_tiles: Array = zone._plots.keys()
	plot_tiles.sort_custom(func(a, b):
		var ta: Vector2i = a
		var tb: Vector2i = b
		if ta.y == tb.y:
			return ta.x < tb.x
		return ta.y < tb.y
	)
	if plot_tiles.is_empty():
		_finish(false, "FARM_TEST_FAIL: farm zone has no plots")
		return
	var blocked_tile: Vector2i = plot_tiles[0]
	var blocked_world: Vector2 = zone.get_plot_world(blocked_tile)
	var blocker = GATHERABLE_SCENE.instantiate()
	blocker.global_position = blocked_world
	main.world_root.add_child(blocker)
	blocker.resource_type = &"Wood"
	blocker.display_name = "FarmBlocker"
	blocker.max_amount = 24
	blocker.current_amount = 24
	blocker.gather_per_tick = 1000
	if blocker.has_method("set_designated"):
		blocker.set_designated(false)
	main._mark_group_cache_dirty(&"gatherables")

	main._configure_farm_zone_catalog(zone)
	zone.set_crop_type(&"Potato")
	main._mark_farm_dirty()
	main._mark_jobs_dirty()

	var blocker_id: int = blocker.get_instance_id()
	var saw_blocker_gather_job: bool = false
	var blocked_tile_planted: bool = false
	var max_plant_workers_observed: int = 0
	for _step in range(1800):
		await get_tree().process_frame
		var blocked_plot: Dictionary = zone._plots.get(blocked_tile, {})
		var blocked_state: StringName = StringName(blocked_plot.get("state", &"Empty"))
		var blocker_depleted: bool = true
		var assigned_plant_ids: Dictionary = {}
		if blocker != null and is_instance_valid(blocker):
			if blocker.has_method("is_depleted"):
				blocker_depleted = bool(blocker.is_depleted())
			else:
				blocker_depleted = int(blocker.get("current_amount")) <= 0
		if not blocker_depleted and blocked_state != &"Empty":
			_finish(false, "FARM_TEST_FAIL: blocked plot was planted before gather clear")
			return
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var current_job: Dictionary = colonist.current_job
			var job_type: StringName = StringName(current_job.get("type", &""))
			if job_type == &"PlantCrop":
				assigned_plant_ids[colonist.get_instance_id()] = true
			if job_type == &"Gather" and int(current_job.get("gatherable_id", 0)) == blocker_id:
				saw_blocker_gather_job = true
		max_plant_workers_observed = maxi(max_plant_workers_observed, assigned_plant_ids.size())
		if blocked_state == &"Growing":
			blocked_tile_planted = true
			break
	if not saw_blocker_gather_job:
		_finish(false, "FARM_TEST_FAIL: no gather job assigned for farm plot blocker")
		return
	if not blocked_tile_planted:
		var blocker_amount: int = int(blocker.get("current_amount")) if blocker != null and is_instance_valid(blocker) else -1
		_finish(false, "FARM_TEST_FAIL: blocked plot did not plant after gather clear (blocker_amount=%d)" % blocker_amount)
		return
	if max_plant_workers_observed < 2:
		var queued_types: Array[String] = []
		for job in main.job_system._jobs:
			queued_types.append(String(job.get("type", &"")))
		print("FARM_TEST_INFO: queued_jobs=", queued_types)
		_finish(false, "FARM_TEST_FAIL: fewer than two colonists assigned to planting")
		return

	var planted_tiles: Array[Vector2i] = []
	for _step in range(360):
		await get_tree().process_frame
		for tile in zone._plots.keys():
			var plot: Dictionary = zone._plots[tile]
			if StringName(plot.get("state", &"Empty")) == &"Growing":
				if not planted_tiles.has(tile):
					planted_tiles.append(tile)
		if planted_tiles.size() >= 2:
			break
	if planted_tiles.size() < 2:
		_finish(false, "FARM_TEST_FAIL: fewer than two crops were planted")
		return

	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()

	for tile in planted_tiles:
		var mature_plot: Dictionary = zone._plots[tile]
		mature_plot["state"] = &"Mature"
		mature_plot["elapsed"] = 0.0
		mature_plot["job_queued"] = false
		mature_plot["crop"] = &"Potato"
		zone._plots[tile] = mature_plot
	zone._emit_zone_updates()
	main._mark_farm_dirty()
	main._mark_jobs_dirty()

	var saw_harvest_workers: int = 0
	for _step in range(240):
		await get_tree().process_frame
		var assigned_ids: Dictionary = {}
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var current_job: Dictionary = colonist.current_job
			if StringName(current_job.get("type", &"")) == &"HarvestCrop":
				assigned_ids[colonist.get_instance_id()] = true
		saw_harvest_workers = assigned_ids.size()
		if saw_harvest_workers >= 2:
			break
	if saw_harvest_workers < 2:
		var queued_types: Array[String] = []
		for job in main.job_system._jobs:
			queued_types.append(String(job.get("type", &"")))
		print("FARM_TEST_INFO: queued_jobs=", queued_types)
		_finish(false, "FARM_TEST_FAIL: fewer than two colonists assigned to harvest")
		return

	_finish(true, "FARM_TEST_PASS: multi-worker plant/harvest jobs assigned")
