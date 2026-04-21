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

	if not main.selected_colonists.is_empty():
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: initial selection was not empty")
		return
	if bool(main._perf_logging_enabled):
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: perf logging enabled during normal play")
		return

	main._hud_dirty = false
	main._hud_time_dirty = false
	main._hud_selection_dirty = false
	main._raid_wave_size = 64
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	if bool(main._hud_dirty):
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: unfocused raid start dirtied full HUD")
		return
	if not bool(main._hud_time_dirty):
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: unfocused raid start did not dirty time HUD")
		return

	for _i in range(120):
		await get_tree().process_frame

	if bool(main._hud_dirty):
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: unfocused raid loop dirtied full HUD")
		return
	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	if enemies.size() < 64:
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: expected 64 raiders, got %d" % enemies.size())
		return
	var service: Node = get_tree().get_first_node_in_group("enemy_flow_field_service")
	var stats: Dictionary = {}
	if service != null and is_instance_valid(service) and service.has_method("get_debug_stats"):
		stats = service.get_debug_stats()
	if int(stats.get("field_builds", 0)) <= 0 and int(stats.get("direct_clear", 0)) <= 0:
		_finish(false, "RAID_UNFOCUSED_FRAME_TEST_FAIL: enemy flow service was not used stats=%s" % str(stats))
		return

	_finish(true, "RAID_UNFOCUSED_FRAME_TEST_PASS: unfocused raid keeps scoped HUD and normal-play perf logs muted")
