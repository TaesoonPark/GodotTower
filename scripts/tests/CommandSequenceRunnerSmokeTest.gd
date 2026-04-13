extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RUNNER: Script = preload("res://scripts/debug/CommandSequenceRunner.gd")
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
	var runner = RUNNER.new(main)

	var result: Dictionary = await runner.run([
		{"action": &"wait_frames", "frames": 20},
		{"action": &"set_colonist_work", "index": 0, "flags": {
			&"Haul": true,
			&"Build": false,
			&"Craft": false,
			&"Combat": false,
			&"Hunt": false,
			&"Gather": false
		}},
		{"action": &"place_stockpile", "rect": Rect2(Vector2(4080.0, 2200.0), Vector2(320.0, 200.0))},
		{"action": &"spawn_drop", "resource_type": &"Wood", "amount": 40, "pos": Vector2(3760.0, 2160.0)},
		{"action": &"snapshot"},
		{"action": &"wait_until_stock", "resource_type": &"Wood", "at_least": 40, "timeout_frames": 1800}
	])

	if not bool(result.get("ok", false)):
		if result.has("snapshot"):
			print(JSON.stringify(result["snapshot"]))
		_finish(false, "COMMAND_SEQUENCE_TEST_FAIL: %s" % String(result.get("error", "unknown")))
		return
	_finish(true, "COMMAND_SEQUENCE_TEST_PASS: scripted haul flow completed")
