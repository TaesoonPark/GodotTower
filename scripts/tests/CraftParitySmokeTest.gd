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
	var godot_result: Dictionary = await _run_godot_scenario()
	if not bool(godot_result.get("ok", false)):
		_finish(false, "CRAFT_PARITY_TEST_FAIL: Godot scenario failed")
		return
	var pure_result: Dictionary = _run_pure_scenario()
	var diffs: Array[String] = _compare(godot_result, pure_result)
	if not diffs.is_empty():
		print("CRAFT_PARITY_DIFFS: %s" % JSON.stringify(diffs))
		print("CRAFT_PARITY_GODOT: %s" % JSON.stringify(godot_result))
		print("CRAFT_PARITY_PURE: %s" % JSON.stringify(pure_result))
		_finish(false, "CRAFT_PARITY_TEST_FAIL: Godot and pure runner diverged")
		return
	_finish(true, "CRAFT_PARITY_TEST_PASS: craft execution invariants match")

func _run_godot_scenario() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		return {"ok": false}
	var colonist = colonists[0]
	colonist.cancel_current_job()
	colonist.set_work_enabled(&"Build", false)
	colonist.set_work_enabled(&"Craft", true)
	colonist.set_work_enabled(&"Combat", false)
	colonist.set_work_enabled(&"Hunt", false)
	colonist.set_work_enabled(&"Gather", false)
	colonist.set_work_enabled(&"Haul", false)
	main.job_system._jobs.append({
		"type": &"CraftRecipe",
		"target": colonist.global_position,
		"recipe_id": &"CutStone",
		"workstation_id": &"SimpleBenchStation",
		"recipe_name": "Cut Stone Block",
		"work_duration": 0.2,
		"products": {&"StoneBlock": 6},
		"craft_slot_id": 1,
		"base_priority": 11,
		"assigned_to": 0
	})
	main.job_system.mark_assign_dirty()
	main._mark_jobs_dirty()
	for _step in range(240):
		await get_tree().process_frame
		var total: int = 0
		for drop in main.get_tree().get_nodes_in_group("resource_drops"):
			if drop == null or not is_instance_valid(drop):
				continue
			if StringName(drop.get("resource_type")) == &"StoneBlock":
				total += int(drop.get("amount"))
		if total >= 6:
			return {"ok": true, "stone_block_drops": total, "queued_jobs": main.job_system._jobs.size()}
	return {"ok": false}

func _run_pure_scenario() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{
			"id": 1,
			"pos": Vector2(3720.0, 2080.0),
			"move_speed": 220.0,
			"craft_priority": 8,
			"current_job": {}
		}],
		"craft_sites": [{
			"queued": true,
			"job_queued": false,
			"pos": Vector2(3720.0, 2080.0),
			"work_duration": 0.2,
			"products": {&"StoneBlock": 6}
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(20, 0.1)
	var total: int = 0
	for drop_any in snapshot.get("drops", []):
		if StringName(drop_any.get("resource_type", &"")) == &"StoneBlock":
			total += int(drop_any.get("amount", 0))
	return {"stone_block_drops": total, "queued_jobs": snapshot.get("jobs", []).size()}

func _compare(a: Dictionary, b: Dictionary) -> Array[String]:
	var diffs: Array[String] = []
	for key in ["stone_block_drops", "queued_jobs"]:
		if a.get(key) != b.get(key):
			diffs.append("%s: godot=%s pure=%s" % [key, str(a.get(key)), str(b.get(key))])
	return diffs
