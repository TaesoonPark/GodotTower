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
		_finish(false, "MELEE_ALLY_BLOCKER_DETOUR_FAIL: need two colonists")
		return
	var attacker = colonists[0]
	var blocker = colonists[1]
	for colonist in [attacker, blocker]:
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
		colonist.set_selected(false)
	if blocker.has_method("set_equipment_slots"):
		blocker.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Rifle"})

	var target_pos: Vector2 = main._snap_to_tile(Vector2(4800.0, 3000.0))
	attacker.global_position = main._snap_to_tile(target_pos + Vector2(-160.0, 0.0))
	blocker.global_position = main._snap_to_tile(target_pos + Vector2(-80.0, 0.0))
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = target_pos
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(64.0)
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.move_speed = 0.0
	zombie.melee_attack = 0.0
	blocker.assign_job({
		"type": &"CombatRanged",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": blocker.get_instance_id()
	})

	attacker.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": attacker.get_instance_id()
	})

	var start_pos: Vector2 = attacker.global_position
	var reached_adjacent: bool = false
	for _step in range(360):
		await get_tree().process_frame
		var attacker_cell: Vector2 = main._snap_to_tile(attacker.global_position)
		var target_cell: Vector2 = main._snap_to_tile(zombie.global_position)
		var dx: int = absi(int(round((attacker_cell.x - target_cell.x) / 64.0)))
		var dy: int = absi(int(round((attacker_cell.y - target_cell.y) / 64.0)))
		if maxi(dx, dy) == 1:
			reached_adjacent = true
			break
	if not reached_adjacent:
		_finish(false, "MELEE_ALLY_BLOCKER_DETOUR_FAIL: attacker did not detour to adjacent cell start=%s pos=%s blocker=%s" % [str(start_pos), str(attacker.global_position), str(blocker.global_position)])
		return

	_finish(true, "MELEE_ALLY_BLOCKER_DETOUR_PASS: melee path detours around allied blocker")
