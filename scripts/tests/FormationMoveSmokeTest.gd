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
	for _i in range(16):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.size() < 3:
		_finish(false, "FORMATION_MOVE_TEST_FAIL: insufficient colonists")
		return
	main._set_selected(colonists)
	await get_tree().process_frame
	main._on_command_move(Vector2(4300.0, 2400.0))
	await get_tree().process_frame

	var targets: Dictionary = {}
	var blocked_targets: Array[String] = []
	var occupancy: Node = get_tree().get_first_node_in_group("pathing_occupancy")
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var job: Dictionary = colonist.current_job
		if StringName(job.get("type", &"")) != &"MoveTo":
			_finish(false, "FORMATION_MOVE_TEST_FAIL: missing MoveTo for %s" % colonist.name)
			return
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			_finish(false, "FORMATION_MOVE_TEST_FAIL: invalid target for %s" % colonist.name)
			return
		targets["%d,%d" % [int(round(target.x)), int(round(target.y))]] = true
		if occupancy != null and is_instance_valid(occupancy) and occupancy.has_method("is_blocked_for_friendly"):
			if bool(occupancy.is_blocked_for_friendly(target)):
				blocked_targets.append("%s=%s" % [colonist.name, str(target)])
	if not blocked_targets.is_empty():
		_finish(false, "FORMATION_MOVE_TEST_FAIL: blocked targets=%s" % ", ".join(blocked_targets))
		return
	if targets.size() < mini(2, colonists.size()):
		_finish(false, "FORMATION_MOVE_TEST_FAIL: targets were not distributed")
		return

	_finish(true, "FORMATION_MOVE_TEST_PASS: selected move uses distributed formation targets")
