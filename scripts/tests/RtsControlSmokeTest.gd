extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const INCLUDE_RAID_ENV: String = "PLAYTEST_INCLUDE_RAID"

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
	
	for _i in range(12):
		await get_tree().process_frame
	
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 2:
		_finish(false, "RTS_TEST_FAIL: colonists not spawned")
		return
	
	var first = colonists[0]
	var first_pos: Vector2 = first.global_position
	
	main._on_left_click(first_pos)
	await get_tree().process_frame
	if main.selected_colonists.size() < 1:
		_finish(false, "RTS_TEST_FAIL: single select failed")
		return
	
	var move_target: Vector2 = first_pos + Vector2(220.0, 120.0)
	main._on_command_move(move_target)
	
	var moved: bool = false
	for _step in range(240):
		await get_tree().process_frame
		if first.global_position.distance_to(first_pos) > 24.0:
			moved = true
			break
	if not moved:
		_finish(false, "RTS_TEST_FAIL: move command failed")
		return
	
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = -INF
	var max_y: float = -INF
	for c in colonists:
		min_x = minf(min_x, c.global_position.x)
		min_y = minf(min_y, c.global_position.y)
		max_x = maxf(max_x, c.global_position.x)
		max_y = maxf(max_y, c.global_position.y)
	main._on_drag_selection(Vector2(min_x - 8.0, min_y - 8.0), Vector2(max_x + 8.0, max_y + 8.0))
	await get_tree().process_frame
	
	if main.selected_colonists.size() < 2:
		_finish(false, "RTS_TEST_FAIL: drag selection failed")
		return

	# 3) Building test: 블루프린트 건축 등록 확인
	main._on_building_selected(&"Wall")
	var build_pos: Vector2 = Vector2(260.0, 260.0)
	main._on_left_click(build_pos)
	for _step in range(20):
		await get_tree().process_frame
	var build_sites: Array = get_tree().get_nodes_in_group("build_sites")
	if build_sites.is_empty():
		_finish(false, "RTS_TEST_FAIL: build site not registered")
		return
	print("RTS_TEST_INFO: build site count=", build_sites.size())

	var include_raid: bool = OS.get_environment(INCLUDE_RAID_ENV) == "1"
	if include_raid:
		if not main.has_method("_start_raid_wave"):
			_finish(false, "RTS_TEST_FAIL: raid trigger method missing")
			return
		print("RTS_TEST_INFO: raid state before=", main._raid_state, ", units_root=", main.units_root)
		var units_before: int = main.units_root.get_child_count() if main.units_root != null else -1
		main._start_raid_wave()
		for _step in range(2):
			await get_tree().process_frame
		var raid_state_mid: StringName = main._raid_state
		var units_mid: int = main.units_root.get_child_count() if main.units_root != null else -1
		print("RTS_TEST_INFO: raid state mid=", raid_state_mid, ", units_before=", units_before, ", units_mid=", units_mid)
		if main.units_root != null:
			var unit_names_mid: Array = []
			for child in main.units_root.get_children():
				unit_names_mid.append(child.name)
			print("RTS_TEST_INFO: units_mid_names=", unit_names_mid)
		if main.has_method("_dispatch_event_updates"):
			main._dispatch_event_updates()
		print("RTS_TEST_INFO: raid state after dispatch=", main._raid_state, ", units_after_dispatch=", main.units_root.get_child_count() if main.units_root != null else -1)

		for _step in range(60):
			await get_tree().process_frame
		var raiders: Array = get_tree().get_nodes_in_group("raiders")
		if raiders.is_empty():
			_finish(false, "RTS_TEST_FAIL: raid spawn failed")
			return
		print("RTS_TEST_INFO: raiders count=", raiders.size())
	else:
		print("RTS_TEST_INFO: raid check skipped")

	await get_tree().create_timer(1.0).timeout
	
	_finish(true, "RTS_TEST_PASS: select/drag/move/build passed")
