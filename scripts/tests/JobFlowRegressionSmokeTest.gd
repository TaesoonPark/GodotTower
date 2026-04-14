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
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: colonist not spawned")
		return
	if main.job_system == null:
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: job system missing")
		return
	var colonist = colonists[0]
	var colonist_id: int = colonist.get_instance_id()

	# 1) Idle transition should re-trigger research producer dirty state.
	main.job_system._dirty_research = false
	main._colonist_idle_state_by_id[colonist_id] = false
	colonist.current_job = {}
	main._on_colonist_status_changed(colonist)
	if not bool(main.job_system._dirty_research):
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: idle transition did not mark research dirty")
		return

	# 2) Combat preempt should only clear pending MoveTo, not other assigned jobs.
	main.job_system._jobs.clear()
	main.job_system._jobs.append({
		"type": &"MoveTo",
		"target": colonist.global_position + Vector2(40.0, 0.0),
		"base_priority": 10,
		"assigned_to": colonist_id
	})
	main.job_system._jobs.append({
		"type": &"ResearchTask",
		"target": colonist.global_position,
		"project_id": &"DummyProject",
		"work_duration": 6.0,
		"research_points": 1.0,
		"base_priority": 9,
		"assigned_to": colonist_id
	})
	main.job_system._jobs.append({
		"type": &"HaulResource",
		"target": colonist.global_position,
		"drop_id": 999999,
		"zone_id": 0,
		"base_priority": 8,
		"assigned_to": 0
	})
	main.job_system._remove_pending_move_jobs_for_colonist(colonist_id)

	var has_move: bool = false
	var has_research: bool = false
	var has_haul: bool = false
	for job_any in main.job_system._jobs:
		var job: Dictionary = job_any
		var t: StringName = StringName(job.get("type", &""))
		var assigned_to: int = int(job.get("assigned_to", 0))
		if t == &"MoveTo" and assigned_to == colonist_id:
			has_move = true
		if t == &"ResearchTask" and assigned_to == colonist_id:
			has_research = true
		if t == &"HaulResource":
			has_haul = true
	if has_move:
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: pending MoveTo was not removed")
		return
	if not has_research:
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: non-move assigned job was removed")
		return
	if not has_haul:
		_finish(false, "JOB_FLOW_REGRESSION_FAIL: unrelated shared job was removed")
		return

	_finish(true, "JOB_FLOW_REGRESSION_PASS: idle re-trigger and move-only preempt validated")
