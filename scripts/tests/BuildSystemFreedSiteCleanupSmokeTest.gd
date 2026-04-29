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
	for _i in range(20):
		await get_tree().process_frame

	var site_pos: Vector2 = Vector2(3960.0, 2200.0)
	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(site_pos, true):
		_finish(false, "BUILD_FREED_SITE_CLEANUP_FAIL: failed to place blueprint")
		return
	if main.build_system._sites.is_empty():
		_finish(false, "BUILD_FREED_SITE_CLEANUP_FAIL: build site was not tracked")
		return
	var site: Node = main.build_system._sites[0]
	site.queue_free()
	await get_tree().process_frame

	main.build_system.request_build_jobs(main.job_system)
	if not main.build_system._sites.is_empty():
		_finish(false, "BUILD_FREED_SITE_CLEANUP_FAIL: freed site was not removed")
		return
	if bool(main.build_system._is_footprint_occupied(site_pos, Vector2(64.0, 64.0))):
		_finish(false, "BUILD_FREED_SITE_CLEANUP_FAIL: freed site still occupied footprint")
		return

	_finish(true, "BUILD_FREED_SITE_CLEANUP_PASS: freed build site references are ignored")
