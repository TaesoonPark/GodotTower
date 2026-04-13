extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const COMMAND_RUNNER: Script = preload("res://scripts/debug/CommandSequenceRunner.gd")
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
		_finish(false, "SYSTEM_PARITY_TEST_FAIL: Godot scenario failed: %s" % String(godot_result.get("error", "unknown")))
		return

	var pure_result: Dictionary = _run_pure_scenario()
	var diffs: Array[String] = _compare_results(godot_result, pure_result)
	if not diffs.is_empty():
		print("SYSTEM_PARITY_DIFFS: %s" % JSON.stringify(diffs))
		print("SYSTEM_PARITY_GODOT: %s" % JSON.stringify(godot_result))
		print("SYSTEM_PARITY_PURE: %s" % JSON.stringify(pure_result))
		_finish(false, "SYSTEM_PARITY_TEST_FAIL: Godot and pure runner diverged")
		return

	_finish(true, "SYSTEM_PARITY_TEST_PASS: Godot and pure runner match on haul invariants")

func _run_godot_scenario() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	var runner = COMMAND_RUNNER.new(main)
	var result: Dictionary = await runner.run_from_file("res://data/debug/haul_sequence.json")
	if not bool(result.get("ok", false)):
		return result

	var stock_wood: int = 0
	for zone in main.get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("get_stored_amount"):
			stock_wood += int(zone.get_stored_amount(&"Wood"))

	var remaining_drop_wood: int = 0
	for drop in main.get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if StringName(drop.get("resource_type")) != &"Wood":
			continue
		remaining_drop_wood += int(drop.get("amount"))

	var reservations: Dictionary = {}
	if main.job_system != null and is_instance_valid(main.job_system):
		reservations = main.job_system._reserved_drop_ids.duplicate(true)

	var queued_haul_jobs: int = 0
	for job_any in main.job_system._jobs:
		if not (job_any is Dictionary):
			continue
		if StringName(job_any.get("type", &"")) == &"HaulResource":
			queued_haul_jobs += 1

	return {
		"ok": true,
		"stock_wood": stock_wood,
		"remaining_drop_wood": remaining_drop_wood,
		"queued_haul_jobs": queued_haul_jobs,
		"reservations": reservations.size()
	}

func _run_pure_scenario() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{
			"id": 1,
			"pos": Vector2(3720.0, 2080.0),
			"move_speed": 220.0,
			"carry_capacity": 75,
			"haul_priority": 5,
			"current_job": {}
		}],
		"drops": [{
			"id": 100,
			"resource_type": &"Wood",
			"amount": 40,
			"job_queued": false,
			"pos": Vector2(3760.0, 2160.0)
		}],
		"stockpiles": [{
			"id": 10,
			"pos": Vector2(4240.0, 2300.0),
			"stored": {}
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(120, 0.1)
	var stock_wood: int = 0
	for zone_any in snapshot.get("stockpiles", []):
		var zone: Dictionary = zone_any
		stock_wood += int(zone.get("stored", {}).get(&"Wood", 0))
	var remaining_drop_wood: int = 0
	for drop_any in snapshot.get("drops", []):
		var drop: Dictionary = drop_any
		if StringName(drop.get("resource_type", &"")) != &"Wood":
			continue
		remaining_drop_wood += int(drop.get("amount", 0))
	return {
		"stock_wood": stock_wood,
		"remaining_drop_wood": remaining_drop_wood,
		"queued_haul_jobs": snapshot.get("jobs", []).size(),
		"reservations": snapshot.get("reservations", {}).size()
	}

func _compare_results(godot_result: Dictionary, pure_result: Dictionary) -> Array[String]:
	var diffs: Array[String] = []
	for key in ["stock_wood", "remaining_drop_wood", "queued_haul_jobs", "reservations"]:
		if godot_result.get(key) != pure_result.get(key):
			diffs.append("%s: godot=%s pure=%s" % [key, str(godot_result.get(key)), str(pure_result.get(key))])
	return diffs
