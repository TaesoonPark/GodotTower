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
	if colonists.size() < 4:
		_finish(false, "MELEE_SPACING_TEST_FAIL: expected 4 colonists, got %d" % colonists.size())
		return

	var target_pos: Vector2 = main._snap_to_tile(Vector2(4800.0, 3000.0))
	main.camera.global_position = target_pos
	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = target_pos
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(40.0)
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.move_speed = 0.0
	zombie.melee_attack = 0.0

	var starts: Array[Vector2] = [
		target_pos + Vector2(-160.0, -60.0),
		target_pos + Vector2(-160.0, -20.0),
		target_pos + Vector2(-160.0, 20.0),
		target_pos + Vector2(-160.0, 60.0)
	]
	for i in range(4):
		var colonist = colonists[i]
		colonist.global_position = main._snap_to_tile(starts[i])
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
		colonist.set_selected(false)
		colonist.assign_job({
			"type": &"CombatMelee",
			"target": zombie.global_position,
			"target_id": zombie.get_instance_id(),
			"base_priority": 13,
			"assigned_to": colonist.get_instance_id()
		})

	for _step in range(260):
		await get_tree().process_frame

	var fighters: Array = colonists.slice(0, 4)
	for fighter in fighters:
		if fighter == null or not is_instance_valid(fighter):
			_finish(false, "MELEE_SPACING_TEST_FAIL: fighter invalid")
			return
		var fighter_cell: Vector2 = main._snap_to_tile(fighter.global_position)
		var enemy_cell: Vector2 = main._snap_to_tile(zombie.global_position)
		if fighter.global_position.distance_to(fighter_cell) > 0.01:
			_finish(false, "MELEE_SPACING_TEST_FAIL: fighter not centered pos=%s snap=%s" % [str(fighter.global_position), str(fighter_cell)])
			return
		var dist_to_enemy: float = fighter.global_position.distance_to(zombie.global_position)
		if fighter_cell.distance_to(enemy_cell) <= 0.1:
			_finish(false, "MELEE_SPACING_TEST_FAIL: fighter overlapped enemy dist=%.2f" % dist_to_enemy)
			return
		var cell_dx: int = absi(int(round((fighter_cell.x - enemy_cell.x) / 40.0)))
		var cell_dy: int = absi(int(round((fighter_cell.y - enemy_cell.y) / 40.0)))
		if maxi(cell_dx, cell_dy) > 1:
			_finish(false, "MELEE_SPACING_TEST_FAIL: fighter did not reach adjacent melee cell dist=%.2f" % dist_to_enemy)
			return

	var min_pair_dist: float = INF
	for a in range(fighters.size()):
		for b in range(a + 1, fighters.size()):
			var da: float = fighters[a].global_position.distance_to(fighters[b].global_position)
			min_pair_dist = minf(min_pair_dist, da)
	if min_pair_dist < 30.0:
		_finish(false, "MELEE_SPACING_TEST_FAIL: melee fighters overlapped pair_dist=%.2f" % min_pair_dist)
		return

	_finish(true, "MELEE_SPACING_TEST_PASS: melee fighters keep separate centered engagement cells")
