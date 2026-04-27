extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(30):
		await get_tree().process_frame

	var hud: HUDController = main.get("hud") as HUDController
	if hud == null or not is_instance_valid(hud):
		_finish(false, "HUD_FPS_TEST_FAIL: hud missing")
		return
	var fps_label: Label = hud.get_node_or_null("FPSLabel") as Label
	if fps_label == null:
		_finish(false, "HUD_FPS_TEST_FAIL: FPSLabel missing")
		return
	if not fps_label.visible:
		_finish(false, "HUD_FPS_TEST_FAIL: FPSLabel hidden")
		return
	if not fps_label.text.begins_with("FPS: "):
		_finish(false, "HUD_FPS_TEST_FAIL: FPSLabel text invalid: %s" % fps_label.text)
		return
	if fps_label.position.x > 24.0 or fps_label.position.y > 18.0:
		_finish(false, "HUD_FPS_TEST_FAIL: FPSLabel not in top-left")
		return

	_finish(true, "HUD_FPS_TEST_PASS: fps label is visible in top-left")
