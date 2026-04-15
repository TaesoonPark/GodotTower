extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const BLOCKED_ASSIGNEE_ID: int = 99999999

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
		_finish(false, "JOB_ASSIGN_STARVATION_FAIL: colonist not spawned")
		return
	if main.job_system == null:
		_finish(false, "JOB_ASSIGN_STARVATION_FAIL: job system missing")
		return
	var colonist = colonists[0]
	if colonist.has_method("cancel_current_job"):
		colonist.cancel_current_job()

	var valid_target: Vector2 = colonist.global_position + Vector2(200.0, 0.0)
	main.job_system._jobs.clear()
	for i in range(48):
		main.job_system._jobs.append({
			"type": &"MoveTo",
			"target": colonist.global_position + Vector2(20.0 + float(i), 0.0),
			"base_priority": 10,
			"assigned_to": BLOCKED_ASSIGNEE_ID
		})
	main.job_system._jobs.append({
		"type": &"MoveTo",
		"target": valid_target,
		"base_priority": 10,
		"assigned_to": 0
	})
	main.job_system._dirty_assign = true
	main.job_system.process_assignment([colonist])
	var assigned_type: StringName = StringName(colonist.current_job.get("type", &""))
	var assigned_target: Vector2 = colonist.current_job.get("target", Vector2.INF)
	if assigned_type != &"MoveTo" or assigned_target != valid_target:
		_finish(false, "JOB_ASSIGN_STARVATION_FAIL: fallback scan did not pick tail job")
		return

	# stale cleanup should run from assignment path even when combat producer is not dirty.
	var stale_site := Node2D.new()
	add_child(stale_site)
	var stale_site_id: int = stale_site.get_instance_id()
	stale_site.queue_free()
	await get_tree().process_frame
	colonist.assign_job({
		"type": &"MoveTo",
		"target": colonist.global_position,
		"base_priority": 10,
		"assigned_to": colonist.get_instance_id()
	})
	main.job_system._jobs.clear()
	main.job_system._jobs.append({
		"type": &"BuildSite",
		"target": colonist.global_position,
		"site_id": stale_site_id,
		"work_duration": 10.0,
		"base_priority": 11,
		"assigned_to": 0
	})
	main.job_system._dirty_combat = false
	main.job_system._dirty_assign = true
	main.job_system.process_assignment([colonist])
	if not main.job_system._jobs.is_empty():
		_finish(false, "JOB_ASSIGN_STARVATION_FAIL: stale jobs were not cleaned in assignment pass")
		return

	# liveness watchdog should re-kick assignment when unassigned jobs exist but dirty flags were lost.
	if colonist.has_method("cancel_current_job"):
		colonist.cancel_current_job()
	var watchdog_target: Vector2 = colonist.global_position + Vector2(120.0, 40.0)
	main.job_system._jobs.clear()
	main.job_system._jobs.append({
		"type": &"MoveTo",
		"target": watchdog_target,
		"base_priority": 10,
		"assigned_to": 0
	})
	main.job_system._dirty_assign = false
	main._dispatch_jobs_dirty = false
	main._job_liveness_next_ms = 0
	for _step in range(80):
		await get_tree().process_frame
		if StringName(colonist.current_job.get("type", &"")) == &"MoveTo":
			break
	if StringName(colonist.current_job.get("type", &"")) != &"MoveTo":
		_finish(false, "JOB_ASSIGN_STARVATION_FAIL: liveness watchdog did not re-trigger assignment")
		return

	_finish(true, "JOB_ASSIGN_STARVATION_PASS: fallback scan, stale cleanup, liveness watchdog validated")
