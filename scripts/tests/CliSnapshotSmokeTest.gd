extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const SNAPSHOT: Script = preload("res://scripts/debug/SimulationSnapshot.gd")
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

	for _i in range(20):
		await get_tree().process_frame

	var snapshot: Dictionary = SNAPSHOT.from_main(main)
	print("CLI_SNAPSHOT_BEGIN")
	print(SNAPSHOT.to_text(snapshot))
	print("CLI_SNAPSHOT_END")

	if int(snapshot.get("colonists", []).size()) < 1:
		_finish(false, "CLI_SNAPSHOT_TEST_FAIL: no colonists in snapshot")
		return
	_finish(true, "CLI_SNAPSHOT_TEST_PASS: snapshot emitted")
