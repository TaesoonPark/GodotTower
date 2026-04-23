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

func _has_direct_label(node: Node) -> bool:
	for child in node.get_children():
		if child is Label:
			return true
	return false

func _assert_label_passthrough(node: Node, path: NodePath, message: String) -> bool:
	var label: Label = node.get_node_or_null(path) as Label
	if label == null:
		_finish(false, "%s: label missing" % message)
		return false
	if label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_finish(false, "%s: label mouse_filter=%d" % [message, label.mouse_filter])
		return false
	return true

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: no colonists")
		return
	main._set_selected([colonists[0]])

	var bed_pos: Vector2 = main._snap_to_tile(Vector2(5200.0, 2560.0))
	main._spawn_installed_bed(bed_pos)
	await get_tree().process_frame
	var bed: Node = main._find_installed_bed_near(bed_pos, 4.0)
	if bed == null:
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: installed bed missing")
		return
	if _has_direct_label(bed):
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: installed bed still has world label")
		return

	main._on_left_click(bed_pos)
	await get_tree().process_frame
	if main.selected_bed_node != bed:
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: installed bed was not selected")
		return
	if not main.selected_colonists.is_empty():
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: bed click did not clear colonist selection")
		return
	if not bool(main.hud.get_node("SelectedStatusPanel").visible):
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: bed click did not open selected status panel")
		return
	if not bool(main.hud.get_node("SelectedStatusPanel/VBox/BedAssignPanel").visible):
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: bed assignment panel not visible")
		return

	var drop_pos: Vector2 = main._snap_to_tile(Vector2(5360.0, 2560.0))
	var drop: Node = main._spawn_resource_drop(&"Wood", 12, drop_pos)
	await get_tree().process_frame
	if drop == null or not is_instance_valid(drop):
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: resource drop missing")
		return
	if not _assert_label_passthrough(drop, ^"Label", "BED_WORLD_RESOURCE_CLICK_FAIL: resource drop"):
		return
	main._on_left_click(drop.global_position)
	await get_tree().process_frame
	if StringName(main._selected_object_kind) != &"ResourceDrop":
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: resource drop was not selected")
		return
	if main._selected_object_zone != drop:
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: selected resource drop node mismatch")
		return
	if StringName(main._selected_object_resource) != &"Wood":
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: selected resource type mismatch")
		return
	if not bool(main.hud.get_node("SelectedStatusPanel").visible):
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: resource drop did not open selected status panel")
		return

	var gatherables: Array = get_tree().get_nodes_in_group("gatherables")
	if gatherables.is_empty():
		_finish(false, "BED_WORLD_RESOURCE_CLICK_FAIL: no field resources")
		return
	if not _assert_label_passthrough(gatherables[0], ^"Label", "BED_WORLD_RESOURCE_CLICK_FAIL: field resource"):
		return

	_finish(true, "BED_WORLD_RESOURCE_CLICK_PASS: installed bed and world resources are clickable")
