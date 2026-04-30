extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _snapshot_drop_ids() -> Dictionary:
	var out: Dictionary = {}
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		out[drop.get_instance_id()] = true
	return out

func _drop_label_rect(drop: Node2D) -> Rect2:
	var label: Label = drop.get_node_or_null("Label") as Label
	if label == null:
		return Rect2()
	var size: Vector2 = label.get_combined_minimum_size()
	return Rect2(label.global_position, size)

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var before_ids: Dictionary = _snapshot_drop_ids()
	var raider: Node2D = RAIDER_SCENE.instantiate()
	add_child(raider)
	raider.global_position = main._snap_to_tile(Vector2(4096.0, 2304.0))
	await get_tree().process_frame

	if not raider.has_method("set_equipment_slots"):
		_finish(false, "ENEMY_DROP_SPREAD_FAIL: raider has no equipment slots")
		return
	raider.set_equipment_slots({
		&"Top": &"CombatTop",
		&"Bottom": &"CombatBottom",
		&"Hat": &"CombatHat",
		&"Weapon": &"Sword"
	})

	main._drop_enemy_equipment(raider)
	for _i in range(2):
		await get_tree().process_frame

	var new_drops: Array = []
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if before_ids.has(drop.get_instance_id()):
			continue
		new_drops.append(drop)

	if new_drops.size() != 4:
		_finish(false, "ENEMY_DROP_SPREAD_FAIL: expected 4 drops, got %d" % new_drops.size())
		return

	for i in range(new_drops.size()):
		for j in range(i + 1, new_drops.size()):
			var left_rect: Rect2 = _drop_label_rect(new_drops[i] as Node2D)
			var right_rect: Rect2 = _drop_label_rect(new_drops[j] as Node2D)
			if left_rect.intersects(right_rect):
				_finish(false, "ENEMY_DROP_SPREAD_FAIL: drop labels overlap")
				return

	var expected: Dictionary = {
		&"CombatTop": true,
		&"CombatBottom": true,
		&"CombatHat": true,
		&"Sword": true
	}
	var positions: Dictionary = {}
	for drop in new_drops:
		var drop_pos: Vector2 = drop.global_position
		var key: String = "%d,%d" % [roundi(drop_pos.x), roundi(drop_pos.y)]
		if positions.has(key):
			_finish(false, "ENEMY_DROP_SPREAD_FAIL: duplicate drop position %s" % key)
			return
		positions[key] = true
		if drop_pos.distance_to(raider.global_position) < TILE_SIZE * 0.9:
			_finish(false, "ENEMY_DROP_SPREAD_FAIL: drop too close at %s" % str(drop_pos))
			return
		expected.erase(StringName(drop.get("resource_type")))

	if not expected.is_empty():
		_finish(false, "ENEMY_DROP_SPREAD_FAIL: missing equipment drops %s" % str(expected.keys()))
		return

	_finish(true, "ENEMY_DROP_SPREAD_PASS: enemy equipment drops spread across distinct tiles")
