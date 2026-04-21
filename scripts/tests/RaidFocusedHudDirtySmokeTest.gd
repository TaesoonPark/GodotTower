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

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 2:
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: expected at least 2 colonists")
		return
	var focused: Node = colonists[0]
	var unfocused: Node = colonists[1]
	main._set_selected([focused])
	for _i in range(6):
		await get_tree().process_frame

	_mute_need_refresh(main, focused)
	_mute_need_refresh(main, unfocused)
	_clear_hud_flags(main)
	unfocused.emit_status()
	if bool(main._hud_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: unfocused status dirtied full HUD")
		return
	if bool(main._hud_selection_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: unfocused status dirtied focused HUD")
		return

	_clear_hud_flags(main)
	focused.emit_status()
	if bool(main._hud_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: focused status dirtied full HUD")
		return
	if not bool(main._hud_selection_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: focused status did not dirty selection HUD")
		return

	_clear_hud_flags(main)
	main._raid_wave_size = 64
	main._raid_wave_kind = &"RaiderOnly"
	main._start_raid_wave()
	if bool(main._hud_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: raid start dirtied full HUD")
		return
	if not bool(main._hud_time_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: raid start did not dirty time HUD")
		return

	for _i in range(60):
		await get_tree().process_frame
	if bool(main._hud_dirty):
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: focused raid loop dirtied full HUD")
		return
	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	if enemies.size() < 64:
		_finish(false, "RAID_FOCUSED_HUD_TEST_FAIL: expected 64 raiders, got %d" % enemies.size())
		return

	_finish(true, "RAID_FOCUSED_HUD_TEST_PASS: focused raid uses scoped HUD dirty flags")

func _clear_hud_flags(main: Node) -> void:
	main._hud_dirty = false
	main._hud_time_dirty = false
	main._hud_selection_dirty = false

func _mute_need_refresh(main: Node, colonist: Node) -> void:
	if main == null or colonist == null:
		return
	main._need_job_refresh_next_ms_by_colonist[colonist.get_instance_id()] = Time.get_ticks_msec() + 60000
