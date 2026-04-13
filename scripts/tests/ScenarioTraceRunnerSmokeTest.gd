extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const TRACE_RUNNER: Script = preload("res://scripts/debug/ScenarioTraceRunner.gd")
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
	var runner = TRACE_RUNNER.new(main)
	var commands: Array = [
		{"action": &"wait_frames", "frames": 10},
		{"action": &"place_stockpile", "rect": Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))},
		{"action": &"spawn_drop", "resource_type": &"Wood", "amount": 10, "pos": Vector2(3760.0, 2160.0)}
	]
	var result: Dictionary = await runner.run_with_trace(commands, true)
	if not bool(result.get("ok", false)):
		_finish(false, "SCENARIO_TRACE_TEST_FAIL: %s" % String(result.get("error", "unknown")))
		return
	_finish(true, "SCENARIO_TRACE_TEST_PASS: trace runner emitted step snapshots")
