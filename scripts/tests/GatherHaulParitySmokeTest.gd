extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
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
		_finish(false, "GATHER_HAUL_PARITY_TEST_FAIL: Godot scenario failed %s" % JSON.stringify(godot_result))
		return
	var pure_result: Dictionary = _run_pure_scenario()
	var diffs: Array[String] = _compare(godot_result, pure_result)
	if not diffs.is_empty():
		print("GATHER_HAUL_PARITY_DIFFS: %s" % JSON.stringify(diffs))
		print("GATHER_HAUL_PARITY_GODOT: %s" % JSON.stringify(godot_result))
		print("GATHER_HAUL_PARITY_PURE: %s" % JSON.stringify(pure_result))
		_finish(false, "GATHER_HAUL_PARITY_TEST_FAIL: Godot and pure runner diverged")
		return
	_finish(true, "GATHER_HAUL_PARITY_TEST_PASS: gather-drop-haul invariants match")

func _run_godot_scenario() -> Dictionary:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	for idx in range(colonists.size()):
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.cancel_current_job()
		colonist.set_work_enabled(&"Build", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", idx == 0)
		colonist.set_work_enabled(&"Haul", idx == 0)
	var stock_center: Vector2 = main._snap_to_tile(Vector2(4224.0, 2304.0))
	var stock_size: Vector2 = Vector2(192.0, 128.0)
	if not main.build_system.place_stockpile_zone(Rect2(stock_center - stock_size * 0.5, stock_size)):
		return {"ok": false}
	var node = GATHERABLE_SCENE.instantiate()
	node.global_position = main._snap_to_tile(Vector2(3760.0, 2160.0))
	main.world_root.add_child(node)
	node.resource_type = &"Wood"
	node.display_name = "ParityTree"
	node.max_amount = 60
	node.current_amount = 60
	node.gather_per_tick = 60
	node.set_designated(true)
	main._mark_group_cache_dirty(&"gatherables")
	main._mark_group_cache_dirty(&"stockpile_zones")
	main.job_system.mark_designation_dirty()
	main._mark_jobs_dirty()
	var last_state: Dictionary = {}
	for _step in range(7200):
		await get_tree().process_frame
		var remaining_gather: int = int(node.current_amount) if node != null and is_instance_valid(node) else 0
		var remaining_drop: int = 0
		for drop in main.get_tree().get_nodes_in_group("resource_drops"):
			if drop == null or not is_instance_valid(drop):
				continue
			if StringName(drop.get("resource_type")) == &"Wood":
				remaining_drop += int(drop.get("amount"))
		var stored: int = 0
		for zone in main.get_tree().get_nodes_in_group("stockpile_zones"):
			if zone == null or not is_instance_valid(zone):
				continue
			stored += int(zone.get_stored_amount(&"Wood"))
		last_state = {"ok": false, "stored": stored, "remaining_drop": remaining_drop, "remaining_gather": remaining_gather}
		if remaining_gather <= 0 and remaining_drop <= 0 and stored >= 60:
			return {"ok": true, "stored": stored, "remaining_drop": remaining_drop, "remaining_gather": remaining_gather}
	return last_state

func _run_pure_scenario() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{
			"id": 1,
			"pos": Vector2(3720.0, 2080.0),
			"move_speed": 220.0,
			"carry_capacity": 75,
			"haul_priority": 5,
			"gather_priority": 7,
			"current_job": {}
		}],
		"gatherables": [{
			"id": 1,
			"resource_type": &"Wood",
			"amount": 60,
			"gather_per_tick": 60,
			"designated": true,
			"job_queued": false,
			"pos": Vector2(3776.0, 2176.0)
		}],
		"stockpiles": [{
			"id": 10,
			"pos": Vector2(4224.0, 2304.0),
			"stored": {}
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(400, 0.1)
	var stockpiles: Array = snapshot.get("stockpiles", [])
	var gatherables: Array = snapshot.get("gatherables", [])
	var stored: int = 0
	if not stockpiles.is_empty():
		stored = int(stockpiles[0].get("stored", {}).get(&"Wood", 0))
	var remaining_drop: int = 0
	for drop_any in snapshot.get("drops", []):
		remaining_drop += int(drop_any.get("amount", 0))
	var remaining_gather: int = 0
	if not gatherables.is_empty():
		remaining_gather = int(gatherables[0].get("amount", 0))
	return {"stored": stored, "remaining_drop": remaining_drop, "remaining_gather": remaining_gather}

func _compare(a: Dictionary, b: Dictionary) -> Array[String]:
	var diffs: Array[String] = []
	for key in ["stored", "remaining_drop", "remaining_gather"]:
		if a.get(key) != b.get(key):
			diffs.append("%s: godot=%s pure=%s" % [key, str(a.get(key)), str(b.get(key))])
	return diffs
