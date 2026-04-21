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

func _spawn_zombie(main: Node, pos: Vector2) -> Node2D:
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = pos
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(40.0)
	main.units_root.add_child(zombie)
	return zombie

func _assign_melee(attacker: Node, target: Node2D) -> void:
	attacker.assign_job({
		"type": &"CombatMelee",
		"target": target.global_position,
		"target_id": target.get_instance_id(),
		"base_priority": 13,
		"assigned_to": attacker.get_instance_id()
	})

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "MELEE_WEAPON_RANGE_CELLS_FAIL: missing colonist")
		return
	var attacker = colonists[0]
	if attacker.has_method("cancel_current_job"):
		attacker.cancel_current_job()
	attacker.set_selected(true)
	attacker.combat_profile["weapon_mode"] = &"Melee"
	attacker.combat_profile["melee_attack"] = 200.0
	attacker.combat_profile["attack_cooldown_sec"] = 0.1

	var target_pos: Vector2 = main._snap_to_tile(Vector2(4800.0, 3000.0))
	var sword_target: Node2D = _spawn_zombie(main, target_pos)
	await get_tree().process_frame
	sword_target.health = 1000.0
	sword_target.move_speed = 0.0
	sword_target.melee_attack = 0.0

	attacker.global_position = main._snap_to_tile(target_pos + Vector2(-80.0, 0.0))
	attacker.combat_profile["melee_range"] = 34.0
	_assign_melee(attacker, sword_target)
	for _step in range(90):
		await get_tree().process_frame
	if sword_target.health < 999.0:
		_finish(false, "MELEE_WEAPON_RANGE_CELLS_FAIL: 34 range damaged from two cells health=%.2f" % sword_target.health)
		return

	if attacker.has_method("cancel_current_job"):
		attacker.cancel_current_job()
	sword_target.queue_free()
	await get_tree().process_frame

	var reach_target: Node2D = _spawn_zombie(main, target_pos)
	await get_tree().process_frame
	reach_target.health = 1000.0
	reach_target.move_speed = 0.0
	reach_target.melee_attack = 0.0
	attacker.global_position = main._snap_to_tile(target_pos + Vector2(-80.0, 0.0))
	attacker.combat_profile["melee_range"] = 80.0
	_assign_melee(attacker, reach_target)
	for _step in range(90):
		await get_tree().process_frame
	if reach_target.health >= 999.0:
		_finish(false, "MELEE_WEAPON_RANGE_CELLS_FAIL: 80 range did not damage from two cells")
		return

	_finish(true, "MELEE_WEAPON_RANGE_CELLS_PASS: melee cell range follows weapon data")
