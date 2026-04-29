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

	var wall_x: float = 3840.0
	var target_y: float = 2160.0
	main.build_system.set_selected_building(&"Wall")
	var placed_walls: int = 0
	for y in range(0, 4321, 40):
		if main.build_system.place_building(Vector2(wall_x, float(y)), false):
			placed_walls += 1
	if placed_walls < 100:
		_finish(false, "ENEMY_WALL_NO_TUNNEL_FAIL: wall setup incomplete placed=%d" % placed_walls)
		return
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	if occupancy == null or not is_instance_valid(occupancy) or not occupancy.has_method("is_blocked_for_enemy"):
		_finish(false, "ENEMY_WALL_NO_TUNNEL_FAIL: missing occupancy")
		return
	if not bool(occupancy.is_blocked_for_enemy(Vector2(wall_x, target_y))):
		_finish(false, "ENEMY_WALL_NO_TUNNEL_FAIL: target wall tile was not blocked")
		return

	var raider: Node2D = RAIDER_SCENE.instantiate()
	raider.global_position = Vector2(wall_x - 50.0, target_y)
	if raider.has_method("set_tile_size"):
		raider.set_tile_size(64.0)
	main.units_root.add_child(raider)
	await get_tree().process_frame
	raider.move_speed = 1600.0
	raider.structure_attack_range = 0.0
	raider.structure_attack_damage = 0.0
	raider._spawn_unclip_left = 0.0
	raider._move_goal = Vector2(wall_x + 240.0, target_y)
	raider._move_goal_exact = false

	for _step in range(8):
		raider._process_movement(0.05)
		await get_tree().process_frame
		if bool(occupancy.is_blocked_for_enemy(raider.global_position)):
			_finish(false, "ENEMY_WALL_NO_TUNNEL_FAIL: raider entered blocked wall pos=%s" % str(raider.global_position))
			return
		if raider.global_position.x >= wall_x - 20.0:
			_finish(false, "ENEMY_WALL_NO_TUNNEL_FAIL: raider crossed wall edge pos=%s" % str(raider.global_position))
			return

	_finish(true, "ENEMY_WALL_NO_TUNNEL_PASS: enemy movement does not tunnel through blocking walls")
