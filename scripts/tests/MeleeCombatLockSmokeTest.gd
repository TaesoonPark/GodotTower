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

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 2:
		_finish(false, "MELEE_LOCK_TEST_FAIL: expected at least 2 colonists")
		return
	var fighter = colonists[0]
	var decoy = colonists[1]
	fighter.global_position = main._snap_to_tile(Vector2(4800.0, 3000.0))
	decoy.global_position = main._snap_to_tile(Vector2(600.0, 600.0))
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		if colonist.has_method("set_work_enabled"):
			colonist.set_work_enabled(&"Combat", false)
		colonist.set_selected(false)
		if colonist != fighter and colonist != decoy:
			colonist.global_position = main._snap_to_tile(Vector2(600.0 + float(colonist.get_instance_id() % 5) * 80.0, 720.0))

	var zombie = ZOMBIE_SCENE.instantiate()
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(40.0)
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.melee_attack = 0.0
	zombie.global_position = main._snap_to_tile(fighter.global_position + Vector2(40.0, 0.0))
	main._raid_state = &"Active"
	main._cached_alive_enemies = [zombie]
	main._set_selected([fighter])
	if fighter.has_method("set_equipment_slots"):
		fighter.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
	fighter.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": fighter.get_instance_id()
	})

	for _step in range(80):
		await get_tree().process_frame
		if fighter.has_method("is_melee_combat_locked") and zombie.has_method("is_melee_combat_locked"):
			if bool(fighter.is_melee_combat_locked()) and bool(zombie.is_melee_combat_locked()):
				break

	if not bool(fighter.is_melee_combat_locked()):
		_finish(false, "MELEE_LOCK_TEST_FAIL: colonist did not lock into melee fighter_pos=%s zombie_pos=%s job=%s profile=%s" % [str(fighter.global_position), str(zombie.global_position), str(fighter.current_job), str(fighter.combat_profile)])
		return
	if not bool(zombie.is_melee_combat_locked()):
		_finish(false, "MELEE_LOCK_TEST_FAIL: enemy did not lock into melee")
		return

	var locked_enemy_target: int = int(zombie.get("_target_colonist_id"))
	var fighter_start: Vector2 = fighter.global_position
	var zombie_start: Vector2 = zombie.global_position
	decoy.global_position = zombie.global_position + Vector2(4.0, 0.0)
	for _step in range(50):
		await get_tree().process_frame

	if int(zombie.get("_target_colonist_id")) != locked_enemy_target:
		_finish(false, "MELEE_LOCK_TEST_FAIL: locked enemy retargeted during melee")
		return
	if fighter.global_position.distance_to(fighter_start) > 2.0:
		_finish(false, "MELEE_LOCK_TEST_FAIL: locked colonist moved during melee")
		return
	if zombie.global_position.distance_to(zombie_start) > 2.0:
		_finish(false, "MELEE_LOCK_TEST_FAIL: locked enemy moved during melee")
		return

	main._issue_selected_move_command(fighter.global_position + Vector2(160.0, 0.0))
	await get_tree().process_frame
	if bool(fighter.is_melee_combat_locked()):
		_finish(false, "MELEE_LOCK_TEST_FAIL: user move did not release colonist lock")
		return
	if bool(zombie.is_melee_combat_locked()):
		_finish(false, "MELEE_LOCK_TEST_FAIL: user move did not release enemy lock")
		return
	if StringName(fighter.current_job.get("type", &"")) != &"MoveTo":
		_finish(false, "MELEE_LOCK_TEST_FAIL: user move did not assign MoveTo")
		return

	_finish(true, "MELEE_LOCK_TEST_PASS: melee combat locks until explicit user move")
