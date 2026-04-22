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

	var stock_rect := Rect2(Vector2(3940.0, 2140.0), Vector2(240.0, 160.0))
	var existing_zone_ids: Dictionary = {}
	for existing_zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if existing_zone == null or not is_instance_valid(existing_zone):
			continue
		existing_zone_ids[int(existing_zone.get_instance_id())] = true
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "HANDCART_PLACE_FAIL: stockpile placement failed")
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
		_finish(false, "HANDCART_PLACE_FAIL: stockpile zone not found")
		return

	var added: int = int(zone.add_resource(&"Handcart", 1))
	if added <= 0:
		_finish(false, "HANDCART_PLACE_FAIL: failed to add handcart to stockpile")
		return
	main.resource_stock[&"Handcart"] = int(main.resource_stock.get(&"Handcart", 0)) + added
	main.hud.set_resource_stock(main.resource_stock)
	await get_tree().process_frame

	var slot_index: int = -1
	for i in range(zone._stack_slots.size()):
		var slot: Dictionary = zone._stack_slots[i]
		if StringName(slot.get("resource_type", &"")) == &"Handcart":
			slot_index = i
			break
	if slot_index < 0:
		_finish(false, "HANDCART_PLACE_FAIL: handcart stack slot not found")
		return

	var handcart_slot: Dictionary = zone._stack_slots[slot_index]
	var slot_rect: Rect2 = handcart_slot.get("rect", Rect2())
	var pick_world: Vector2 = zone.to_global(slot_rect.get_center() + Vector2(0.0, 14.0))
	main._on_left_click(main._snap_to_tile(pick_world))
	await get_tree().process_frame
	if StringName(main._selected_object_kind) != &"StockpileItem" or StringName(main._selected_object_resource) != &"Handcart":
		_finish(false, "HANDCART_PLACE_FAIL: failed to select handcart stockpile item")
		return

	main._on_selected_object_action_requested(&"PlaceHandcartFromStockpile")
	await get_tree().process_frame
	if StringName(main.pending_install_item) != &"Handcart":
		_finish(false, "HANDCART_PLACE_FAIL: handcart install mode not started")
		return

	var place_world: Vector2 = main._snap_to_tile(stock_rect.get_center() + Vector2(220.0, 0.0))
	main._on_left_click(place_world)
	await get_tree().process_frame

	var placed: Node = null
	for handcart in get_tree().get_nodes_in_group("handcarts"):
		if handcart == null or not is_instance_valid(handcart):
			continue
		if handcart.global_position.distance_to(place_world) <= 6.0:
			placed = handcart
			break
	if placed == null:
		_finish(false, "HANDCART_PLACE_FAIL: handcart object was not placed in world")
		return

	_finish(true, "HANDCART_PLACE_PASS: stockpile handcart placement works")
