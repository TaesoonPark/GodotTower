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

func _find_feedback_text(text: String) -> Label:
	for node in get_tree().get_nodes_in_group("combat_feedback_text"):
		if node == null or not is_instance_valid(node) or not (node is Label):
			continue
		var label: Label = node
		if label.text == text:
			return label
	return null

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = main._snap_to_tile(Vector2(4800.0, 3000.0))
	main.units_root.add_child(zombie)
	await get_tree().process_frame

	main.report_combat_event(&"Colonist", true, 9, false, &"CombatMelee", zombie)
	await get_tree().process_frame
	var damage_label: Label = _find_feedback_text("9")
	if damage_label == null:
		_finish(false, "COMBAT_FEEDBACK_TEXT_FAIL: damage label missing")
		return
	var start_y: float = damage_label.global_position.y

	main.report_combat_event(&"Enemy", false, 0, false, &"CombatMelee", zombie)
	await get_tree().process_frame
	if _find_feedback_text("MISS") == null:
		_finish(false, "COMBAT_FEEDBACK_TEXT_FAIL: miss label missing")
		return

	for _i in range(16):
		await get_tree().process_frame
	if is_instance_valid(damage_label) and damage_label.global_position.y >= start_y:
		_finish(false, "COMBAT_FEEDBACK_TEXT_FAIL: damage label did not float upward")
		return

	for _i in range(80):
		await get_tree().process_frame
	for node in get_tree().get_nodes_in_group("combat_feedback_text"):
		if node != null and is_instance_valid(node):
			_finish(false, "COMBAT_FEEDBACK_TEXT_FAIL: feedback label did not disappear")
			return

	_finish(true, "COMBAT_FEEDBACK_TEXT_PASS: damage and miss text floats from combat target")
