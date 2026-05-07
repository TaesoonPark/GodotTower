extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

class DummyEnemy:
	extends Node2D
	var damage_taken: int = 0

	func apply_combat_damage(amount: int) -> void:
		damage_taken += amount

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
	for _i in range(12):
		await get_tree().process_frame

	var def: Resource = main._find_building_def(&"SpikeTrap")
	if def == null:
		_finish(false, "SPIKE_TRAP_CELL_TRIGGER_FAIL: missing SpikeTrap def")
		return
	if StringName(def.required_research) != &"" or not bool(main._is_building_unlocked(def)):
		_finish(false, "SPIKE_TRAP_CELL_TRIGGER_FAIL: SpikeTrap is not in the default build catalog")
		return

	var trap := Node2D.new()
	trap.set_meta("building_id", &"SpikeTrap")
	trap.set_meta("footprint_size", Vector2(TILE_SIZE, TILE_SIZE))
	trap.set_meta("trap_damage", 10)
	trap.set_meta("trap_charges", 2)
	trap.set_meta("trap_max_charges", 2)
	trap.set_meta("trap_cooldown_left", 0.0)
	trap.set_meta("trap_cooldown_sec", 5.0)
	trap.add_to_group("trap_structures")
	main.world_root.add_child(trap)
	trap.global_position = Vector2(3200.0, 2200.0)
	main._mark_group_cache_dirty(&"trap_structures")

	var outside := DummyEnemy.new()
	main.world_root.add_child(outside)
	outside.global_position = trap.global_position + Vector2(34.0, 0.0)
	main._update_defense_traps(1.0, [outside])
	if outside.damage_taken != 0 or int(trap.get_meta("trap_charges")) != 2:
		_finish(false, "SPIKE_TRAP_CELL_TRIGGER_FAIL: trap fired outside occupied cell")
		return

	var inside := DummyEnemy.new()
	main.world_root.add_child(inside)
	inside.global_position = trap.global_position + Vector2(31.0, 0.0)
	main._update_defense_traps(1.0, [inside])
	if inside.damage_taken != 10 or int(trap.get_meta("trap_charges")) != 1:
		_finish(false, "SPIKE_TRAP_CELL_TRIGGER_FAIL: trap did not fire inside occupied cell")
		return

	_finish(true, "SPIKE_TRAP_CELL_TRIGGER_PASS: SpikeTrap is default and triggers only in occupied cell")
