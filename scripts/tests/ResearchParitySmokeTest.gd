extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const STATE_RUNNER: Script = preload("res://scripts/sim/StateRunner.gd")
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
	var godot: Dictionary = await _run_godot()
	if not bool(godot.get("ok", false)):
		_finish(false, "RESEARCH_PARITY_TEST_FAIL: Godot scenario failed")
		return
	var pure: Dictionary = _run_pure()
	if godot.get("points") != pure.get("points"):
		print("RESEARCH_PARITY_GODOT: %s" % JSON.stringify(godot))
		print("RESEARCH_PARITY_PURE: %s" % JSON.stringify(pure))
		_finish(false, "RESEARCH_PARITY_TEST_FAIL: points diverged")
		return
	_finish(true, "RESEARCH_PARITY_TEST_PASS: research progression matches")

func _run_godot() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame
	var colonist = get_tree().get_nodes_in_group("colonists")[0]
	colonist.cancel_current_job()
	colonist.set_work_enabled(&"Build", false)
	colonist.set_work_enabled(&"Craft", true)
	colonist.set_work_enabled(&"Combat", false)
	colonist.set_work_enabled(&"Hunt", false)
	colonist.set_work_enabled(&"Gather", false)
	colonist.set_work_enabled(&"Haul", false)
	main._active_research_id = &"AgronomyI"
	main._research_running = true
	main._active_research_points = 0.0
	main.job_system._jobs.append({
		"type": &"ResearchTask",
		"target": colonist.global_position,
		"project_id": &"AgronomyI",
		"work_duration": 0.2,
		"research_points": 1.0,
		"base_priority": 9,
		"assigned_to": 0
	})
	main.job_system.mark_assign_dirty()
	main._mark_jobs_dirty()
	for _step in range(200):
		await get_tree().process_frame
		if float(main._active_research_points) > 0.0:
			return {"ok": true, "points": float(main._active_research_points)}
	return {"ok": false}

func _run_pure() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{"id": 1, "pos": Vector2.ZERO, "move_speed": 220.0, "craft_priority": 8, "current_job": {}}],
		"research": {"running": false, "project_id": &"AgronomyI", "points": 0.0, "points_per_job": 1.0, "work_duration": 0.5, "pos": Vector2.ZERO},
		"jobs": [{
			"type": &"ResearchTask",
			"target": Vector2.ZERO,
			"project_id": &"AgronomyI",
			"work_duration": 0.2,
			"research_points": 1.0,
			"base_priority": 9,
			"assigned_to": 0
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(10, 0.1)
	return {"points": float(snapshot.get("research", {}).get("points", 0.0))}
