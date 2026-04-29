extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
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

	var wall_pos: Vector2 = Vector2(3960.0, 2200.0)
	main.build_system.set_selected_building(&"Wall")
	if not main.build_system.place_building(wall_pos, true):
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: wall blueprint placement failed")
		return
	if main.build_system._sites.is_empty():
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: build site was not tracked")
		return
	var site: Node = main.build_system._sites[0]
	if not site.has_method("apply_work"):
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: site cannot complete")
		return
	site.apply_work(9999.0)
	await get_tree().process_frame
	if not site.is_in_group("blocking_structures"):
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: completed site is not blocking")
		return

	var raider: Node2D = RAIDER_SCENE.instantiate()
	raider.global_position = wall_pos + Vector2(-48.0, 0.0)
	if raider.has_method("set_tile_size"):
		raider.set_tile_size(64.0)
	main.units_root.add_child(raider)
	await get_tree().process_frame
	raider.structure_attack_damage = 10000.0
	raider.structure_attack_range = 80.0
	if not bool(raider._try_attack_structure(wall_pos)):
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: raider did not attack built site")
		return
	await get_tree().process_frame

	if not main.build_system._sites.is_empty():
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: destroyed built site stayed tracked")
		return
	main.build_system.request_build_jobs(main.job_system)
	if bool(main.build_system._is_footprint_occupied(wall_pos, Vector2(64.0, 64.0))):
		_finish(false, "ENEMY_BREAK_SITE_CLEANUP_FAIL: destroyed built site still occupied footprint")
		return

	_finish(true, "ENEMY_BREAK_SITE_CLEANUP_PASS: enemy-destroyed built sites are untracked")
