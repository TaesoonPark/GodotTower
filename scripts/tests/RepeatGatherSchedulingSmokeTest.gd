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
	if colonists.is_empty():
		_finish(false, "REPEAT_GATHER_TEST_FAIL: no colonists")
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

	var node = GATHERABLE_SCENE.instantiate()
	node.global_position = Vector2(3760.0, 2160.0)
	main.world_root.add_child(node)
	node.resource_type = &"Wood"
	node.display_name = "RepeatTree"
	node.max_amount = 80
	node.current_amount = 80
	node.gather_per_tick = 10
	node.set_designated(true)

	main._mark_group_cache_dirty(&"gatherables")
	main.job_system.mark_designation_dirty()
	main._mark_jobs_dirty()

	var harvest_count: int = 0
	for _step in range(1800):
		await get_tree().process_frame
		var remaining: int = int(node.current_amount) if node != null and is_instance_valid(node) else 0
		harvest_count = int(round(float(80 - remaining) / 10.0))
		if remaining <= 60:
			break

	if node == null or not is_instance_valid(node):
		_finish(false, "REPEAT_GATHER_TEST_FAIL: gatherable disappeared unexpectedly")
		return
	if int(node.current_amount) > 60:
		var queued_types: Array[String] = []
		for job in main.job_system._jobs:
			queued_types.append(String(job.get("type", &"")))
		var colonist_jobs: Array[String] = []
		for colonist in colonists:
			if colonist == null or not is_instance_valid(colonist):
				continue
			colonist_jobs.append("%s:%s" % [colonist.name, String(colonist.current_job.get("type", &"Idle"))])
		print("REPEAT_GATHER_TEST_INFO: current_amount=", node.current_amount, " designated=", node.designated, " job_queued=", node.job_queued, " dirty_designation=", main.job_system._dirty_designation, " dispatch_jobs_dirty=", main._dispatch_jobs_dirty, " queued_jobs=", queued_types, " colonists=", colonist_jobs)
		_finish(false, "REPEAT_GATHER_TEST_FAIL: designated gather did not continue scheduling")
		return

	_finish(true, "REPEAT_GATHER_TEST_PASS: designated gather re-queued after completion")
