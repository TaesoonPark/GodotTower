extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")
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

func _cell_key(main: Node, pos: Vector2) -> String:
	var cell: Vector2 = main._snap_to_tile(pos)
	return "%d,%d" % [int(round(cell.x)), int(round(cell.y))]

func _assert_unique_cells_and_locked_adjacent(main: Node, units: Array, target: Node2D, label: String) -> bool:
	var occupied: Dictionary = {}
	var target_cell: Vector2 = main._snap_to_tile(target.global_position)
	for unit in units:
		if unit == null or not is_instance_valid(unit):
			_finish(false, "%s_FAIL: invalid unit" % label)
			return false
		var cell: Vector2 = main._snap_to_tile(unit.global_position)
		var key: String = _cell_key(main, unit.global_position)
		if occupied.has(key):
			_finish(false, "%s_FAIL: duplicate melee cell %s" % [label, key])
			return false
		occupied[key] = true
		if unit.has_method("is_melee_combat_locked") and bool(unit.is_melee_combat_locked()):
			if unit.global_position.distance_to(cell) > 0.01:
				_finish(false, "%s_FAIL: locked unit not centered pos=%s snap=%s" % [label, str(unit.global_position), str(cell)])
				return false
			var dx: int = absi(int(round((cell.x - target_cell.x) / 64.0)))
			var dy: int = absi(int(round((cell.y - target_cell.y) / 64.0)))
			if maxi(dx, dy) > 1:
				_finish(false, "%s_FAIL: locked unit outside sword melee cell pos=%s target=%s" % [label, str(cell), str(target_cell)])
				return false
	return true

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var target_pos: Vector2 = main._snap_to_tile(Vector2(4800.0, 3000.0))
	main.camera.global_position = target_pos
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		colonist.global_position = main._snap_to_tile(Vector2(640.0 + float(colonist.get_instance_id() % 6) * 80.0, 640.0))

	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = target_pos
	if zombie.has_method("set_tile_size"):
		zombie.set_tile_size(64.0)
	main.units_root.add_child(zombie)
	await get_tree().process_frame
	zombie.health = 10000.0
	zombie.move_speed = 0.0
	zombie.melee_attack = 0.0

	var attackers: Array = []
	for i in range(12):
		var fighter = colonists[i] if i < colonists.size() else null
		if fighter == null:
			fighter = COLONIST_SCENE.instantiate()
			fighter.name = "ExtraMelee%d" % i
			if fighter.has_method("set_tile_size"):
				fighter.set_tile_size(64.0)
			main.units_root.add_child(fighter)
			await get_tree().process_frame
		fighter.global_position = main._snap_to_tile(target_pos + Vector2(-80.0, -80.0 + float(i % 5) * 40.0))
		if fighter.has_method("cancel_current_job"):
			fighter.cancel_current_job()
		if fighter.has_method("set_equipment_slots"):
			fighter.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
		fighter.set_selected(false)
		fighter.assign_job({
			"type": &"CombatMelee",
			"target": zombie.global_position,
			"target_id": zombie.get_instance_id(),
			"base_priority": 13,
			"assigned_to": fighter.get_instance_id()
		})
		attackers.append(fighter)

	var settled: bool = false
	for _step in range(1200):
		await get_tree().process_frame
		var keys: Dictionary = {}
		settled = true
		for fighter in attackers:
			var key: String = _cell_key(main, fighter.global_position)
			if keys.has(key):
				settled = false
				break
			keys[key] = true
			if fighter.has_method("is_melee_combat_locked") and bool(fighter.is_melee_combat_locked()):
				var cell: Vector2 = main._snap_to_tile(fighter.global_position)
				if fighter.global_position.distance_to(cell) > 0.01:
					settled = false
					break
		if settled:
			break
	if not settled:
		var info: Array[String] = []
		for fighter in attackers:
			info.append("%s pos=%s snap=%s lock=%s" % [fighter.name, str(fighter.global_position), str(main._snap_to_tile(fighter.global_position)), str(fighter.is_melee_combat_locked() if fighter.has_method("is_melee_combat_locked") else false)])
		_finish(false, "MELEE_CELL_UNIQUENESS_FAIL: attackers did not maintain unique cells %s" % " | ".join(info))
		return
	if not _assert_unique_cells_and_locked_adjacent(main, attackers, zombie, "MELEE_CELL_UNIQUENESS"):
		return

	_finish(true, "MELEE_CELL_UNIQUENESS_PASS: melee attackers keep unique cells and locked attacks stay adjacent")
