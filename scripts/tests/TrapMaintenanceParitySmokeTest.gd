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
		_finish(false, "TRAP_PARITY_TEST_FAIL: Godot scenario failed")
		return
	var pure: Dictionary = _run_pure()
	if godot.get("charges") != pure.get("charges"):
		print("TRAP_PARITY_GODOT: %s" % JSON.stringify(godot))
		print("TRAP_PARITY_PURE: %s" % JSON.stringify(pure))
		_finish(false, "TRAP_PARITY_TEST_FAIL: trap charges diverged")
		return
	_finish(true, "TRAP_PARITY_TEST_PASS: trap maintenance matches")

func _run_godot() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame
	var colonist = get_tree().get_nodes_in_group("colonists")[0]
	colonist.cancel_current_job()
	colonist.set_work_enabled(&"Build", true)
	colonist.set_work_enabled(&"Craft", false)
	colonist.set_work_enabled(&"Combat", false)
	colonist.set_work_enabled(&"Hunt", false)
	colonist.set_work_enabled(&"Gather", false)
	colonist.set_work_enabled(&"Haul", false)
	main.resource_stock[&"Wood"] = 10
	main.resource_stock[&"Steel"] = 10
	var trap := Node2D.new()
	trap.global_position = colonist.global_position
	trap.set_meta("trap_damage", 5)
	trap.set_meta("trap_charges", 0)
	trap.set_meta("trap_max_charges", 4)
	trap.set_meta("trap_maint_job_queued", false)
	main.world_root.add_child(trap)
	main.job_system._jobs.append({
		"type": &"MaintainTrap",
		"structure_id": trap.get_instance_id(),
		"target": trap.global_position,
		"work_duration": 0.2,
		"base_priority": 10,
		"assigned_to": 0
	})
	main.job_system.mark_assign_dirty()
	main._mark_jobs_dirty()
	for _step in range(200):
		await get_tree().process_frame
		if int(trap.get_meta("trap_charges")) >= 4:
			return {"ok": true, "charges": int(trap.get_meta("trap_charges"))}
	return {"ok": false}

func _run_pure() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{"id": 1, "pos": Vector2.ZERO, "move_speed": 220.0, "build_priority": 9, "current_job": {}}],
		"traps": [{"id": 1, "pos": Vector2.ZERO, "charges": 0, "max_charges": 4, "job_queued": false, "work_duration": 0.2}],
		"jobs": [{
			"type": &"MaintainTrap",
			"structure_id": 1,
			"target": Vector2.ZERO,
			"work_duration": 0.2,
			"base_priority": 10,
			"assigned_to": 0
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(20, 0.1)
	return {"charges": int(snapshot.get("traps", [])[0].get("charges", 0))}
