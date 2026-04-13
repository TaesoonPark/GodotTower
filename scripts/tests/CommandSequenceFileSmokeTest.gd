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
	var result: Dictionary = await runner.run_from_file("res://data/debug/haul_sequence.json")
	if not bool(result.get("ok", false)):
		_finish(false, "COMMAND_SEQUENCE_FILE_TEST_FAIL: %s" % String(result.get("error", "unknown")))
		return
	_finish(true, "COMMAND_SEQUENCE_FILE_TEST_PASS: file scenario completed")
