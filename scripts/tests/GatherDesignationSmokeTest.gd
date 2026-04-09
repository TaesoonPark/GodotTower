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

	for _i in range(16):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 2:
		_finish(false, "GATHER_TEST_FAIL: insufficient colonists")
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

	var spawn_points: Array[Vector2] = [
		Vector2(3760.0, 2160.0),
		Vector2(3800.0, 2160.0),
		Vector2(3840.0, 2160.0)
	]
	for pos in spawn_points:
		var node = GATHERABLE_SCENE.instantiate()
		node.global_position = pos
		main.world_root.add_child(node)
		node.resource_type = &"Wood"
		node.display_name = "TestTree"
		node.max_amount = 60
		node.gather_per_tick = 10
		if node.has_method("set_designated"):
			node.set_designated(true)

	main._mark_group_cache_dirty(&"gatherables")
	main.job_system.mark_designation_dirty()
	main._mark_jobs_dirty()

	var gather_workers: int = 0
	for _step in range(240):
		await get_tree().process_frame
		var assigned_ids: Dictionary = {}
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			if StringName(colonist.current_job.get("type", &"")) == &"Gather":
				assigned_ids[colonist.get_instance_id()] = true
		gather_workers = assigned_ids.size()
		if gather_workers >= 2:
			break

	if gather_workers < 2:
		var queued_types: Array[String] = []
		for job in main.job_system._jobs:
			queued_types.append(String(job.get("type", &"")))
		print("GATHER_TEST_INFO: queued_jobs=", queued_types)
		_finish(false, "GATHER_TEST_FAIL: fewer than two colonists assigned to designated gather")
		return

	_finish(true, "GATHER_TEST_PASS: multi-worker designated gather assigned")
