extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
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

func _is_centered(main: Node, node: Node2D) -> bool:
	return node.global_position.distance_to(main._snap_to_tile(node.global_position)) <= 0.01

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 3:
		_finish(false, "CELL_ANCHOR_TEST_FAIL: expected at least 3 colonists")
		return
	var movers: Array = colonists.slice(0, 3)
	var start: Vector2 = main._snap_to_tile(Vector2(3600.0, 2160.0))
	for i in range(movers.size()):
		movers[i].global_position = start + Vector2(0.0, float(i) * 40.0)
	for colonist in movers:
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_selected(false)
	main._set_selected(movers)
	main._issue_selected_move_command(Vector2(3840.0, 2160.0))

	var all_done: bool = false
	for _step in range(260):
		await get_tree().process_frame
		all_done = true
		for colonist in movers:
			if StringName(colonist.current_job.get("type", &"")) == &"MoveTo":
				all_done = false
				break
		if all_done:
			break

	if not all_done:
		_finish(false, "CELL_ANCHOR_TEST_FAIL: move command did not finish")
		return
	for colonist in movers:
		if not _is_centered(main, colonist):
			_finish(false, "CELL_ANCHOR_TEST_FAIL: move ended off cell center %s pos=%s snap=%s" % [colonist.name, str(colonist.global_position), str(main._snap_to_tile(colonist.global_position))])
			return

	var fighter = movers[0]
	main._set_selected([])
	fighter.global_position = main._snap_to_tile(Vector2(3840.0, 2160.0))
	if fighter.has_method("cancel_current_job"):
		fighter.cancel_current_job()
	var zombie = ZOMBIE_SCENE.instantiate()
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(40.0)
	zombie.global_position = main._snap_to_tile(fighter.global_position + Vector2(160.0, 0.0))
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.melee_attack = 0.0
	fighter.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": fighter.get_instance_id()
	})

	for _step in range(600):
		await get_tree().process_frame
		if fighter.has_method("is_melee_combat_locked") and zombie.has_method("is_melee_combat_locked") and bool(fighter.is_melee_combat_locked()) and bool(zombie.is_melee_combat_locked()):
			break

	if not (bool(fighter.is_melee_combat_locked()) and bool(zombie.is_melee_combat_locked())):
		_finish(false, "CELL_ANCHOR_TEST_FAIL: melee pair did not lock before anchor check fighter=%s zombie=%s zgoal=%s zexact=%s ztarget=%s zlock=%s job=%s" % [str(fighter.global_position), str(zombie.global_position), str(zombie.get("_move_goal")), str(zombie.get("_move_goal_exact")), str(zombie.get("_target_colonist_id")), str(zombie.is_melee_combat_locked()), str(fighter.current_job)])
		return
	if not _is_centered(main, fighter):
		_finish(false, "CELL_ANCHOR_TEST_FAIL: melee fighter off cell center pos=%s snap=%s" % [str(fighter.global_position), str(main._snap_to_tile(fighter.global_position))])
		return
	if not _is_centered(main, zombie):
		_finish(false, "CELL_ANCHOR_TEST_FAIL: enemy off cell center pos=%s snap=%s" % [str(zombie.global_position), str(main._snap_to_tile(zombie.global_position))])
		return

	_finish(true, "CELL_ANCHOR_TEST_PASS: characters settle on fixed cell centers")
