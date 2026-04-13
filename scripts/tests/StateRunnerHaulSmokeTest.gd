extends Node

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
			"amount": 75,
			"job_queued": false,
			"pos": Vector2(3760.0, 2160.0)
		}, {
			"id": 101,
			"resource_type": &"Wood",
			"amount": 75,
			"job_queued": false,
			"pos": Vector2(3800.0, 2160.0)
		}],
		"stockpiles": [{
			"id": 10,
			"pos": Vector2(4240.0, 2300.0),
			"stored": {}
		}]
	})

	var snapshot: Dictionary = runner.run_ticks(200, 0.1)
	var stockpiles: Array = snapshot.get("stockpiles", [])
	if stockpiles.is_empty():
		_finish(false, "STATE_RUNNER_TEST_FAIL: no stockpile state")
		return
	var stored: Dictionary = stockpiles[0].get("stored", {})
	if int(stored.get(&"Wood", 0)) < 150:
		print(JSON.stringify(snapshot))
		_finish(false, "STATE_RUNNER_TEST_FAIL: pure haul runner did not deliver all resources")
		return
	if snapshot.get("jobs", []).size() != 0:
		print(JSON.stringify(snapshot))
		_finish(false, "STATE_RUNNER_TEST_FAIL: jobs remained after completion")
		return
	_finish(true, "STATE_RUNNER_TEST_PASS: pure haul state runner completed deterministically")
