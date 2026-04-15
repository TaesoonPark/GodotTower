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

	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		for work_type in [&"Haul", &"Build", &"Craft", &"Combat", &"Gather", &"Hunt"]:
			colonist.set_work_enabled(work_type, false)

	var stock_rect := Rect2(Vector2(4560.0, 2880.0), Vector2(320.0, 200.0))
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "STOCKPILE_UX_TEST_FAIL: stockpile placement failed")
		return
	main._mark_group_cache_dirty(&"stockpile_zones")

	var zone: Node = main._find_stockpile_zone_near(stock_rect.get_center(), 40.0)
	if zone == null or not is_instance_valid(zone):
		_finish(false, "STOCKPILE_UX_TEST_FAIL: failed to find placed stockpile")
		return

	var zone_size: Vector2 = zone.get("zone_size") if zone.get("zone_size") != null else Vector2(120.0, 80.0)
	var edge_world: Vector2 = zone.global_position + Vector2(zone_size.x * 0.5 - 8.0, 0.0)
	var picked_edge: Node = main._find_stockpile_zone_near(edge_world, 40.0)
	if picked_edge == null or picked_edge.get_instance_id() != zone.get_instance_id():
		_finish(false, "STOCKPILE_UX_TEST_FAIL: edge click did not select stockpile")
		return

	var zone_pos: Vector2 = zone.global_position
	var before_stock_wood: int = int(main.resource_stock.get(&"Wood", 0))
	var before_drop_total: int = _sum_drop_amount(&"Wood")
	var before_drop_near: int = _sum_drop_amount_near(&"Wood", zone_pos, 120.0)

	if not zone.has_method("add_resource"):
		_finish(false, "STOCKPILE_UX_TEST_FAIL: stockpile has no add_resource")
		return
	var injected: int = int(zone.add_resource(&"Wood", 7))
	if injected != 7:
		_finish(false, "STOCKPILE_UX_TEST_FAIL: failed to inject stockpile resource")
		return
	main.resource_stock[&"Wood"] = before_stock_wood + injected
	main.hud.set_resource_stock(main.resource_stock)

	main.selected_stockpile_zone = zone
	main._refresh_stockpile_filter_ui()
	main.hud.stockpile_delete_requested.emit()
	await get_tree().process_frame

	if is_instance_valid(zone) and not zone.is_queued_for_deletion():
		_finish(false, "STOCKPILE_UX_TEST_FAIL: stockpile was not deleted")
		return

	var after_stock_wood: int = int(main.resource_stock.get(&"Wood", 0))
	if after_stock_wood != before_stock_wood:
		_finish(false, "STOCKPILE_UX_TEST_FAIL: resource_stock wood mismatch after delete")
		return

	var after_drop_total: int = _sum_drop_amount(&"Wood")
	if after_drop_total < before_drop_total + injected:
		_finish(false, "STOCKPILE_UX_TEST_FAIL: dropped wood total did not increase as expected")
		return

	var after_drop_near: int = _sum_drop_amount_near(&"Wood", zone_pos, 120.0)
	if after_drop_near < before_drop_near + injected:
		_finish(false, "STOCKPILE_UX_TEST_FAIL: dropped wood did not spawn near deleted stockpile")
		return

	_finish(true, "STOCKPILE_UX_TEST_PASS: edge select and delete behavior verified")

func _sum_drop_amount(resource_type: StringName) -> int:
	var total: int = 0
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if StringName(drop.get("resource_type")) != resource_type:
			continue
		total += int(drop.get("amount"))
	return total

func _sum_drop_amount_near(resource_type: StringName, center: Vector2, radius: float) -> int:
	var total: int = 0
	for drop in get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if StringName(drop.get("resource_type")) != resource_type:
			continue
		if drop.global_position.distance_to(center) > radius:
			continue
		total += int(drop.get("amount"))
	return total
