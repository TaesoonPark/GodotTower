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
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(24):
		await get_tree().process_frame

	var colonist: Node = main.colonists[0]
	main._set_selected([colonist])
	main._refresh_hud()
	if String(main.hud.current_job_label.text).contains("스턴"):
		_finish(false, "VEHICLE_HUD_STUN_FAIL: stun text visible before stun")
		return

	colonist.apply_stun(0.2)
	main._refresh_hud()
	if not String(main.hud.current_job_label.text).contains("스턴"):
		_finish(false, "VEHICLE_HUD_STUN_FAIL: stun text hidden during stun")
		return

	for _i in range(40):
		await get_tree().process_frame
	main._refresh_hud()
	if String(main.hud.current_job_label.text).contains("스턴"):
		_finish(false, "VEHICLE_HUD_STUN_FAIL: stun text remained after stun ended")
		return

	_finish(true, "VEHICLE_HUD_STUN_PASS: stun remaining text only appears while stunned")
