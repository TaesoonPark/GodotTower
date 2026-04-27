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
	for _i in range(24):
		await get_tree().process_frame

	var colonist: Node2D = main.colonists[0]
	colonist.cancel_current_job()
	var bike: Node2D = main._spawn_vehicle(&"Bicycle", colonist.global_position)
	if bike == null or not bool(main._request_vehicle_use(bike, colonist)):
		_finish(false, "VEHICLE_SCHEDULING_FAIL: setup mount failed")
		return
	await get_tree().process_frame

	for job_type in [&"BuildSite", &"CraftRecipe", &"Gather", &"HaulResource", &"ResearchTask", &"CombatMelee", &"CombatRanged", &"EatStub", &"IdleRecover"]:
		if bool(colonist.can_do_job(job_type)):
			_finish(false, "VEHICLE_SCHEDULING_FAIL: mounted bicycle allowed job %s" % String(job_type))
			return

	colonist.hunger = 1.0
	if bool(main.job_system.queue_need_jobs(colonist, 1)):
		_finish(false, "VEHICLE_SCHEDULING_FAIL: mounted bicycle queued need job")
		return

	main.job_system._jobs.append({
		"type": &"Gather",
		"target": colonist.global_position,
		"base_priority": 20,
		"assigned_to": colonist.get_instance_id()
	})
	main.job_system.mark_assign_dirty()
	main.job_system.process_assignment(main.colonists)
	if not colonist.current_job.is_empty():
		_finish(false, "VEHICLE_SCHEDULING_FAIL: mounted bicycle received scheduled job")
		return

	_finish(true, "VEHICLE_SCHEDULING_PASS: bicycle rider does not participate in scheduling")
