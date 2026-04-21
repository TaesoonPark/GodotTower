extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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

	main._raid_wave_size = 6
	main._raid_wave_kind = &"Mixed"
	main._start_raid_wave()
	for _i in range(20):
		await get_tree().physics_frame

	var enemies: Array = []
	enemies.append_array(get_tree().get_nodes_in_group("raiders"))
	enemies.append_array(get_tree().get_nodes_in_group("zombies"))
	if enemies.size() < 6:
		_finish(false, "ENEMY_NO_ROTATION_TEST_FAIL: expected mixed enemies, got %d" % enemies.size())
		return
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if absf(float(enemy.rotation)) > 0.001:
			_finish(false, "ENEMY_NO_ROTATION_TEST_FAIL: spawned enemy rotated %.3f" % float(enemy.rotation))
			return

	var first_enemy: Node2D = enemies[0] as Node2D
	first_enemy.rotation = 1.2
	await get_tree().physics_frame
	if absf(first_enemy.rotation) > 0.001:
		_finish(false, "ENEMY_NO_ROTATION_TEST_FAIL: rotation lock did not reset enemy rotation")
		return

	_finish(true, "ENEMY_NO_ROTATION_TEST_PASS: enemies remain unrotated")
