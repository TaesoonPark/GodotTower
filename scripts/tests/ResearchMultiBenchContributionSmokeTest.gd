extends Node

const JOB_SYSTEM_SCRIPT: Script = preload("res://scripts/systems/JobSystem.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

class DummyColonist:
	extends Node2D

	var current_job: Dictionary = {}
	var _can_research: bool = true

	func _init(can_research: bool = true) -> void:
		_can_research = can_research

	func can_do_job(job_type: StringName) -> bool:
		if job_type != &"ResearchTask":
			return true
		return _can_research

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
	var job_system = JOB_SYSTEM_SCRIPT.new()
	add_child(job_system)

	var colonist_a := DummyColonist.new(true)
	colonist_a.global_position = Vector2(0.0, 0.0)
	add_child(colonist_a)
	var colonist_b := DummyColonist.new(true)
	colonist_b.global_position = Vector2(120.0, 0.0)
	add_child(colonist_b)
	var colonist_c := DummyColonist.new(true)
	colonist_c.global_position = Vector2(260.0, 0.0)
	add_child(colonist_c)

	var research_targets: Array = [Vector2(0.0, 0.0), Vector2(160.0, 0.0)]
	job_system.request_research_jobs(
		[colonist_a, colonist_b, colonist_c],
		Vector2.INF,
		&"AgronomyI",
		0.5,
		research_targets
	)

	var first_jobs: Array = []
	for job_any in job_system._jobs:
		var job: Dictionary = job_any
		if StringName(job.get("type", &"")) == &"ResearchTask":
			first_jobs.append(job)
	if first_jobs.size() != 2:
		_finish(false, "RESEARCH_MULTI_BENCH_FAIL: expected 2 research jobs, got %d" % first_jobs.size())
		return

	var first_targets: Dictionary = {}
	var first_assignees: Dictionary = {}
	for job in first_jobs:
		first_targets[job.get("target", Vector2.INF)] = true
		first_assignees[int(job.get("assigned_to", 0))] = true
	if first_targets.size() != 2:
		_finish(false, "RESEARCH_MULTI_BENCH_FAIL: targets were not split per bench")
		return
	if first_assignees.size() != 2:
		_finish(false, "RESEARCH_MULTI_BENCH_FAIL: same colonist was assigned twice")
		return

	job_system._jobs.clear()
	colonist_a.current_job = {"type": &"ResearchTask", "target": Vector2(0.0, 0.0)}
	colonist_b.current_job = {}
	colonist_c.current_job = {}
	job_system.request_research_jobs(
		[colonist_a, colonist_b, colonist_c],
		Vector2.INF,
		&"AgronomyI",
		0.5,
		research_targets
	)

	var second_jobs: Array = []
	for job_any in job_system._jobs:
		var job: Dictionary = job_any
		if StringName(job.get("type", &"")) == &"ResearchTask":
			second_jobs.append(job)
	if second_jobs.size() != 1:
		_finish(false, "RESEARCH_MULTI_BENCH_FAIL: reserved bench should block duplicate queue")
		return
	if Vector2(second_jobs[0].get("target", Vector2.INF)) != Vector2(160.0, 0.0):
		_finish(false, "RESEARCH_MULTI_BENCH_FAIL: wrong bench target queued when one bench is occupied")
		return

	_finish(true, "RESEARCH_MULTI_BENCH_PASS: multi-bench research contribution works")
