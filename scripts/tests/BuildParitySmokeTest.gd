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
		_finish(false, "BUILD_PARITY_TEST_FAIL: Godot scenario failed")
		return
	var pure_result: Dictionary = _run_pure_scenario()
	var diffs: Array[String] = _compare(godot_result, pure_result)
	if not diffs.is_empty():
		print("BUILD_PARITY_DIFFS: %s" % JSON.stringify(diffs))
		print("BUILD_PARITY_GODOT: %s" % JSON.stringify(godot_result))
		print("BUILD_PARITY_PURE: %s" % JSON.stringify(pure_result))
		_finish(false, "BUILD_PARITY_TEST_FAIL: Godot and pure runner diverged")
		return
	_finish(true, "BUILD_PARITY_TEST_PASS: build invariants match")

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
		colonist.set_work_enabled(&"Build", idx == 0)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Hunt", false)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Haul", false)
	main._on_building_selected(&"Wall")
	main._on_left_click(Vector2(3960.0, 2200.0))
	for _step in range(2400):
		await get_tree().process_frame
		var build_sites: Array = get_tree().get_nodes_in_group("build_sites")
		if build_sites.is_empty():
			return {"ok": false}
		var site = build_sites[0]
		if bool(site.get("complete")):
			return {"ok": true, "complete": true, "queued": bool(site.get("job_queued")), "work_progress": int(round(float(site.get("work_progress"))))}
	return {"ok": false}

func _run_pure_scenario() -> Dictionary:
	var runner = STATE_RUNNER.new({
		"colonists": [{
			"id": 1,
			"pos": Vector2(3720.0, 2080.0),
			"move_speed": 220.0,
			"build_priority": 9,
			"current_job": {}
		}],
		"build_sites": [{
			"id": 1,
			"pos": Vector2(3960.0, 2200.0),
			"work_pos": Vector2(3920.0, 2200.0),
			"required_work": 1.0,
			"work_progress": 0.0,
			"complete": false,
			"job_queued": false
		}]
	})
	var snapshot: Dictionary = runner.run_ticks(300, 0.1)
	var build_sites: Array = snapshot.get("build_sites", [])
	if build_sites.is_empty():
		return {}
	var site: Dictionary = build_sites[0]
	return {"complete": bool(site.get("complete", false)), "queued": bool(site.get("job_queued", false)), "work_progress": int(round(float(site.get("work_progress", 0.0))))}

func _compare(a: Dictionary, b: Dictionary) -> Array[String]:
	var diffs: Array[String] = []
	for key in ["complete", "queued", "work_progress"]:
		if a.get(key) != b.get(key):
			diffs.append("%s: godot=%s pure=%s" % [key, str(a.get(key)), str(b.get(key))])
	return diffs
