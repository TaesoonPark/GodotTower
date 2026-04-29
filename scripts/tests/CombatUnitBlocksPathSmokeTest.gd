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
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: need at least 2 colonists")
		return

	var target_pos: Vector2 = main._snap_to_tile(Vector2(4800.0, 3000.0))
	main.camera.global_position = target_pos
	for i in range(colonists.size()):
		var colonist = colonists[i]
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.set_selected(false)
		colonist.global_position = main._snap_to_tile(Vector2(640.0 + float(i) * 40.0, 640.0))

	var blocker = colonists[0]
	var friendly_probe = colonists[1]
	blocker.global_position = target_pos + Vector2(-40.0, 0.0)
	friendly_probe.global_position = target_pos + Vector2(-120.0, 0.0)
	if blocker.has_method("set_equipment_slots"):
		blocker.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})

	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = target_pos
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(64.0)
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.move_speed = 0.0
	zombie.melee_attack = 0.0

	var enemy_probe = ZOMBIE_SCENE.instantiate()
	enemy_probe.global_position = target_pos + Vector2(-160.0, 40.0)
	if enemy_probe.has_method("set_tile_size"):
		enemy_probe.set_tile_size(64.0)
	main.units_root.add_child(enemy_probe)
	await get_tree().process_frame
	enemy_probe.health = 10000.0
	enemy_probe.move_speed = 0.0
	enemy_probe.melee_attack = 0.0

	blocker.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": blocker.get_instance_id()
	})

	var locked: bool = false
	for _step in range(180):
		await get_tree().process_frame
		locked = bool(blocker.is_melee_combat_locked()) and bool(zombie.is_melee_combat_locked())
		if locked:
			break
	if not locked:
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: combatants did not enter melee lock blocker=%s zombie=%s" % [str(blocker.is_melee_combat_locked()), str(zombie.is_melee_combat_locked())])
		return

	if not bool(friendly_probe._is_path_blocked_position(blocker.global_position)):
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: friendly pathing did not block colonist combat cell")
		return
	if not bool(friendly_probe._is_path_blocked_position(zombie.global_position)):
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: friendly pathing did not block enemy combat cell")
		return
	if not bool(enemy_probe._is_blocked_position(blocker.global_position)):
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: enemy pathing did not block colonist combat cell")
		return
	if not bool(enemy_probe._is_blocked_position(zombie.global_position)):
		_finish(false, "COMBAT_UNIT_BLOCKS_PATH_FAIL: enemy pathing did not block enemy combat cell")
		return

	_finish(true, "COMBAT_UNIT_BLOCKS_PATH_PASS: combat units block friendly and enemy pathing")
