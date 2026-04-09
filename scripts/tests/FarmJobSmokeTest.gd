extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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

	main._configure_farm_zone_catalog(zone)
	zone.set_crop_type(&"Potato")
	main._mark_farm_dirty()
	main._mark_jobs_dirty()

	var saw_plant_workers: int = 0
	for _step in range(240):
		await get_tree().process_frame
		var assigned_ids: Dictionary = {}
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			var current_job: Dictionary = colonist.current_job
			if StringName(current_job.get("type", &"")) == &"PlantCrop":
				assigned_ids[colonist.get_instance_id()] = true
		saw_plant_workers = assigned_ids.size()
		if saw_plant_workers >= 2:
			break
	if saw_plant_workers < 2:
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
