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
		_finish(false, "COMBAT_READY_TEST_FAIL: colonists not spawned")
		return

	var primary: Node = colonists[0]
	var blocker_probe: Node = colonists[1]
	_prepare_colonists(colonists, primary)
	blocker_probe.global_position = main._snap_to_tile(primary.global_position + Vector2(192.0, 0.0))
	if main.job_system != null and is_instance_valid(main.job_system):
		main.job_system._jobs.clear()
		main.job_system.mark_assign_dirty()

	main._set_selected([primary])
	await get_tree().process_frame

	primary.assign_job({
		"type": &"Gather",
		"target": primary.global_position + Vector2(64.0, 0.0),
		"assigned_to": primary.get_instance_id()
	})
	if primary.current_job.is_empty():
		_finish(false, "COMBAT_READY_TEST_FAIL: setup non-combat job missing")
		return

	_press_r(main)
	for _i in range(2):
		await get_tree().process_frame

	if not bool(primary.get("combat_ready")):
		_finish(false, "COMBAT_READY_TEST_FAIL: R did not enable combat ready")
		return
	if not primary.current_job.is_empty():
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready did not cancel non-combat job")
		return
	if not primary.can_accept_manual_move():
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready blocks manual move")
		return
	if not bool(primary.can_do_job(&"CombatMelee")):
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready cannot accept combat job")
		return
	if not bool(blocker_probe._is_path_blocked_position(primary.global_position)):
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready unit does not block another colonist")
		return
	blocker_probe.set_combat_ready(true)
	if not bool(primary._is_path_blocked_position(blocker_probe.global_position)):
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready units do not mutually block")
		return
	blocker_probe.set_combat_ready(false)

	var move_target: Vector2 = primary.global_position + Vector2(128.0, 0.0)
	main._on_command_move(move_target)
	await get_tree().process_frame
	if StringName(primary.current_job.get("type", &"")) != &"MoveTo":
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready did not accept manual move command")
		return

	main._set_selected([])
	await get_tree().process_frame
	if not bool(primary.get("combat_ready")):
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready cleared on deselect")
		return
	if bool(primary.can_do_job(&"BuildSite")):
		_finish(false, "COMBAT_READY_TEST_FAIL: combat ready accepts non-combat job while deselected")
		return

	var ready_button: Button = _get_roster_button(main, primary.get_instance_id())
	if ready_button == null:
		_finish(false, "COMBAT_READY_TEST_FAIL: roster button missing")
		return
	if not bool(ready_button.get_meta("combat_ready", false)):
		_finish(false, "COMBAT_READY_TEST_FAIL: roster button missing combat ready marker")
		return
	var style := ready_button.get_theme_stylebox("normal") as StyleBoxFlat
	if style == null or style.border_color.r < 0.8 or style.border_color.g > 0.3:
		_finish(false, "COMBAT_READY_TEST_FAIL: roster button does not have red border style")
		return

	main._set_selected([primary])
	await get_tree().process_frame
	_press_r(main)
	for _i in range(2):
		await get_tree().process_frame
	main._set_selected([])
	await get_tree().process_frame

	if bool(primary.get("combat_ready")):
		_finish(false, "COMBAT_READY_TEST_FAIL: second R did not disable combat ready")
		return
	if not primary.can_accept_manual_move():
		_finish(false, "COMBAT_READY_TEST_FAIL: manual move still blocked after combat ready off")
		return
	if not bool(primary.can_do_job(&"BuildSite")):
		_finish(false, "COMBAT_READY_TEST_FAIL: non-combat work did not resume after combat ready off")
		return

	var normal_button: Button = _get_roster_button(main, primary.get_instance_id())
	if normal_button == null:
		_finish(false, "COMBAT_READY_TEST_FAIL: roster button missing after toggle off")
		return
	if bool(normal_button.get_meta("combat_ready", false)):
		_finish(false, "COMBAT_READY_TEST_FAIL: roster button marker remained after toggle off")
		return

	_finish(true, "COMBAT_READY_TEST_PASS: R toggles combat-ready hold, job filter, and roster marker")

func _prepare_colonists(colonists: Array, primary: Node) -> void:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		var is_primary: bool = colonist == primary
		colonist.set_work_enabled(&"Build", is_primary)
		colonist.set_work_enabled(&"Combat", false)
		colonist.set_work_enabled(&"Craft", false)
		colonist.set_work_enabled(&"Haul", false)
		colonist.set_work_enabled(&"Gather", false)
		colonist.set_work_enabled(&"Hunt", false)

func _press_r(main: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	main._unhandled_input(event)

func _get_roster_button(main: Node, colonist_id: int) -> Button:
	if main.hud == null or not is_instance_valid(main.hud):
		return null
	var roster = main.hud.roster_panel
	if roster == null or not is_instance_valid(roster):
		return null
	if not roster._button_by_id.has(colonist_id):
		return null
	return roster._button_by_id[colonist_id] as Button
