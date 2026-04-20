extends Node

class DummyTarget:
	extends Node2D
	var health: float = 120.0
	func apply_combat_damage(amount: int) -> void:
		health = maxf(0.0, health - float(amount))
	func is_dead() -> bool:
		return health <= 0.0
	func get_combat_defender_profile() -> Dictionary:
		return {"defense": 0.0}

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const COMBAT_LOS: Script = preload("res://scripts/core/CombatLineOfSight.gd")
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

	var colonist = get_tree().get_nodes_in_group("colonists")[0]
	colonist.global_position = Vector2(3000.0, 2200.0)
	colonist.cancel_current_job()
	colonist.set_combat_profile({
		"base_hit": 1.0,
		"ranged_attack": 35.0,
		"ranged_range": 260.0,
		"attack_cooldown_sec": 0.12,
		"weapon_mode": &"Ranged"
	})

	var target := DummyTarget.new()
	target.global_position = Vector2(3160.0, 2200.0)
	main.units_root.add_child(target)

	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(Vector2(3080.0, 2200.0), false):
		_finish(false, "RANGED_LOS_TEST_FAIL: wall placement failed")
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	await get_tree().process_frame
	if bool(COMBAT_LOS.has_ranged_line_of_sight(get_tree(), colonist.global_position, target.global_position)):
		_finish(false, "RANGED_LOS_TEST_FAIL: wall LOS check passed unexpectedly")
		return

	_assign_ranged_job(colonist, target)
	for _step in range(90):
		await get_tree().process_frame
	if target.health < 120.0:
		_finish(false, "RANGED_LOS_TEST_FAIL: wall did not block ranged damage health=%.1f" % target.health)
		return

	for structure in get_tree().get_nodes_in_group("structures"):
		if structure == null or not is_instance_valid(structure):
			continue
		if structure.has_meta("building_id") and StringName(structure.get_meta("building_id")) == &"Wall":
			structure.queue_free()
	await get_tree().process_frame

	main.build_system.set_selected_building(&"FiringWall")
	if not main.build_system.place_building(Vector2(3080.0, 2200.0), false):
		_finish(false, "RANGED_LOS_TEST_FAIL: firing wall placement failed")
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	target.health = 120.0
	if not bool(COMBAT_LOS.has_ranged_line_of_sight(get_tree(), colonist.global_position, target.global_position)):
		_finish(false, "RANGED_LOS_TEST_FAIL: firing wall LOS check was blocked")
		return
	_assign_ranged_job(colonist, target)
	for _step in range(240):
		await get_tree().process_frame
		if target.health < 120.0:
			_finish(true, "RANGED_LOS_TEST_PASS: normal walls block ranged LOS and firing walls allow it")
			return

	_finish(false, "RANGED_LOS_TEST_FAIL: firing wall blocked ranged damage")

func _assign_ranged_job(colonist: Node, target: Node2D) -> void:
	colonist.assign_job({
		"type": &"CombatRanged",
		"target": target.global_position,
		"target_id": target.get_instance_id(),
		"base_priority": 100,
		"assigned_to": colonist.get_instance_id(),
		"next_attack_ms": 0
	})
