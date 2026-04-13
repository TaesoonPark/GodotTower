extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
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
		_finish(false, "COMBAT_PARITY_TEST_FAIL: Godot scenario failed")
		return
	var pure: Dictionary = _run_pure()
	if godot.get("enemy_dead") != pure.get("enemy_dead"):
		print("COMBAT_PARITY_GODOT: %s" % JSON.stringify(godot))
		print("COMBAT_PARITY_PURE: %s" % JSON.stringify(pure))
		_finish(false, "COMBAT_PARITY_TEST_FAIL: combat result diverged")
		return
	_finish(true, "COMBAT_PARITY_TEST_PASS: combat kill invariant matches")

func _run_godot() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame
	var colonist = get_tree().get_nodes_in_group("colonists")[0]
	colonist.cancel_current_job()
	colonist.set_work_enabled(&"Build", false)
	colonist.set_work_enabled(&"Craft", false)
	colonist.set_work_enabled(&"Combat", true)
	colonist.set_work_enabled(&"Hunt", false)
	colonist.set_work_enabled(&"Gather", false)
	colonist.set_work_enabled(&"Haul", false)
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = colonist.global_position
	main.units_root.add_child(zombie)
	zombie.health = 1.0
	main.job_system._jobs.append({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": 0
	})
	main.job_system.mark_assign_dirty()
	main._mark_jobs_dirty()
	for _step in range(400):
		await get_tree().process_frame
		if zombie == null or not is_instance_valid(zombie):
			return {"ok": true, "enemy_dead": true}
		if zombie.has_method("is_dead") and bool(zombie.is_dead()):
			return {"ok": true, "enemy_dead": true}
	return {"ok": false}

func _run_pure() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{"id": 1, "pos": Vector2.ZERO, "move_speed": 220.0, "combat_priority": 10, "current_job": {}}],
		"enemies": [{"id": 1, "pos": Vector2.ZERO, "health": 1.0, "dead": false}],
		"jobs": [{
			"type": &"CombatMelee",
			"target": Vector2.ZERO,
			"target_id": 1,
			"base_priority": 13,
			"assigned_to": 0
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(5, 0.1)
	var enemy_dead: bool = false
	if not snapshot.get("enemies", []).is_empty():
		enemy_dead = bool(snapshot.get("enemies", [])[0].get("dead", false))
	return {"enemy_dead": enemy_dead}
