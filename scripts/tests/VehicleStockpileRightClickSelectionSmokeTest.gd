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
	for _i in range(24):
		await get_tree().process_frame

	if main.colonists.is_empty():
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: no colonist found")
		return
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		for work_type in [&"Haul", &"Build", &"Craft", &"Combat", &"Gather", &"Hunt"]:
			colonist.set_work_enabled(work_type, false)

	var stock_rect := Rect2(Vector2(3920.0, 2140.0), Vector2(240.0, 160.0))
	var existing_zone_ids: Dictionary = {}
	for existing_zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if existing_zone == null or not is_instance_valid(existing_zone):
			continue
		existing_zone_ids[int(existing_zone.get_instance_id())] = true
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: stockpile placement failed")
		return
	await get_tree().process_frame

	var zone: Node = null
	for candidate in get_tree().get_nodes_in_group("stockpile_zones"):
		if candidate == null or not is_instance_valid(candidate):
			continue
		if existing_zone_ids.has(int(candidate.get_instance_id())):
			continue
		zone = candidate
		break
	if zone == null:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: stockpile zone not found")
		return

	var added: int = int(zone.add_resource(&"Bicycle", 1))
	if added <= 0:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: failed to add bicycle to stockpile")
		return
	main.resource_stock[&"Bicycle"] = int(main.resource_stock.get(&"Bicycle", 0)) + added
	main.hud.set_resource_stock(main.resource_stock)
	await get_tree().process_frame

	var slot_index: int = -1
	for i in range(zone._stack_slots.size()):
		var slot: Dictionary = zone._stack_slots[i]
		if StringName(slot.get("resource_type", &"")) == &"Bicycle":
			slot_index = i
			break
	if slot_index < 0:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle stack slot not found")
		return

	var bicycle_slot: Dictionary = zone._stack_slots[slot_index]
	var slot_rect: Rect2 = bicycle_slot.get("rect", Rect2())
	var pick_world: Vector2 = main._snap_to_tile(zone.to_global(slot_rect.get_center() + Vector2(0.0, 14.0)))
	var stockpile_item: Dictionary = main._find_stockpile_item_at(pick_world)
	if stockpile_item.is_empty() or StringName(stockpile_item.get("resource_type", &"")) != &"Bicycle":
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle stockpile hit test failed")
		return

	var colonist: Node2D = main.colonists[0]
	colonist.global_position = main._snap_to_tile(pick_world - Vector2(240.0, 0.0))
	main._set_selected([colonist])
	if not bool(main._show_mountable_stockpile_context(stockpile_item, pick_world, Vector2(32.0, 32.0))):
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle right-click context branch failed")
		return
	await get_tree().process_frame
	if not main.hud.context_action_button.visible or StringName(main.hud._context_action_id) != &"UseVehicleFromStockpile":
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle context menu was not shown")
		return
	if StringName(main._selected_object_kind) == &"StockpileItem":
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: right-click selected stockpile item instead of showing context")
		return

	var existing_vehicle_ids: Dictionary = {}
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle != null and is_instance_valid(vehicle):
			existing_vehicle_ids[int(vehicle.get_instance_id())] = true
	main._on_context_action_requested(&"UseVehicleFromStockpile")
	for _i in range(4):
		await get_tree().process_frame
	if int(zone.get_stored_amount(&"Bicycle")) != 1:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle was removed before colonist arrived")
		return
	for vehicle in get_tree().get_nodes_in_group("vehicles"):
		if vehicle != null and is_instance_valid(vehicle) and not existing_vehicle_ids.has(int(vehicle.get_instance_id())):
			_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle spawned before colonist arrived")
			return

	var spawned_vehicle: Node2D = null
	for _step in range(900):
		await get_tree().process_frame
		for vehicle in get_tree().get_nodes_in_group("vehicles"):
			if vehicle == null or not is_instance_valid(vehicle):
				continue
			if existing_vehicle_ids.has(int(vehicle.get_instance_id())):
				continue
			spawned_vehicle = vehicle
			break
		if spawned_vehicle != null and bool(colonist.is_mounted()):
			break
	if spawned_vehicle == null:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: bicycle did not spawn after colonist arrived")
		return
	if not bool(colonist.is_mounted()):
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: colonist did not mount spawned bicycle")
		return
	if int(zone.get_stored_amount(&"Bicycle")) != 0:
		_finish(false, "VEHICLE_STOCKPILE_RIGHT_CLICK_FAIL: stockpile bicycle was not consumed on arrival")
		return

	_finish(true, "VEHICLE_STOCKPILE_RIGHT_CLICK_PASS: stockpile bicycle context use spawns on colonist arrival")
