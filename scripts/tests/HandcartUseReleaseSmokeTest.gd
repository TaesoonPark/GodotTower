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
		_finish(false, "HANDCART_USE_RELEASE_FAIL: no colonist found")
		return
	var colonist: Node2D = main.colonists[0]
	if colonist == null or not is_instance_valid(colonist):
		_finish(false, "HANDCART_USE_RELEASE_FAIL: primary colonist invalid")
		return

	var stock_rect := Rect2(Vector2(3980.0, 2140.0), Vector2(240.0, 160.0))
	var existing_zone_ids: Dictionary = {}
	for existing_zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if existing_zone == null or not is_instance_valid(existing_zone):
			continue
		existing_zone_ids[int(existing_zone.get_instance_id())] = true
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile placement failed")
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
		_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile zone not found")
		return
	var added: int = int(zone.add_resource(&"Handcart", 1))
	if added <= 0:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: failed to add stockpile handcart")
		return
	main.resource_stock[&"Handcart"] = int(main.resource_stock.get(&"Handcart", 0)) + added
	main.hud.set_resource_stock(main.resource_stock)
	await get_tree().process_frame

	var existing_handcart_ids: Dictionary = {}
	for node in get_tree().get_nodes_in_group("handcarts"):
		if node == null or not is_instance_valid(node):
			continue
		existing_handcart_ids[int(node.get_instance_id())] = true

	var use_pos: Vector2 = main._snap_to_tile(stock_rect.get_center() + Vector2(140.0, 0.0))
	colonist.global_position = main._snap_to_tile(use_pos - Vector2(240.0, 0.0))
	main._set_selected([colonist])
	main._context_stockpile_zone_id = zone.get_instance_id()
	main._context_stockpile_use_pos = use_pos
	main._on_context_action_requested(&"UseHandcartFromStockpile")
	for _i in range(4):
		await get_tree().process_frame

	if int(zone.get_stored_amount(&"Handcart")) != 1:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile handcart was removed before colonist arrived")
		return
	for node in get_tree().get_nodes_in_group("handcarts"):
		if node == null or not is_instance_valid(node):
			continue
		if not existing_handcart_ids.has(int(node.get_instance_id())):
			_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile use action spawned handcart before colonist arrived")
			return

	var handcart: Node2D = null
	var assigned: bool = false
	var owner_id: int = colonist.get_instance_id()
	for _step in range(900):
		await get_tree().process_frame
		for node in get_tree().get_nodes_in_group("handcarts"):
			if node == null or not is_instance_valid(node):
				continue
			if existing_handcart_ids.has(int(node.get_instance_id())):
				continue
			handcart = node
			break
		if handcart != null and int(handcart.get_meta("assigned_colonist_id")) == owner_id:
			assigned = true
			break

	if handcart == null:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile use action did not spawn handcart after arrival")
		return
	if handcart.global_position.distance_to(use_pos) > 48.0:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: spawned handcart moved away from stockpile use point")
		return
	if not assigned:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: colonist never reached stockpile handcart to use it")
		return
	if int(zone.get_stored_amount(&"Handcart")) != 0:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: stockpile handcart was not consumed on arrival")
		return
	for _step in range(120):
		await get_tree().process_frame
		var active_type: StringName = StringName(colonist.current_job.get("type", &""))
		if active_type != &"MoveTo":
			break
	if StringName(colonist.current_job.get("type", &"")) == &"MoveTo":
		_finish(false, "HANDCART_USE_RELEASE_FAIL: colonist stayed stuck on move job after using handcart")
		return

	colonist.global_position += Vector2(120.0, 0.0)
	for _i in range(8):
		await get_tree().process_frame
	if handcart.global_position.distance_to(colonist.global_position) > 80.0:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: assigned handcart did not follow colonist")
		return

	var release_pos: Vector2 = main._snap_to_tile(colonist.global_position + Vector2(120.0, 40.0))
	main._context_handcart_id = handcart.get_instance_id()
	main._context_handcart_release_pos = release_pos
	main._on_context_action_requested(&"ReleaseHandcart")
	await get_tree().process_frame

	if handcart.has_meta("assigned_colonist_id") and int(handcart.get_meta("assigned_colonist_id")) != 0:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: release action did not clear owner")
		return
	if handcart.global_position.distance_to(release_pos) > 0.1:
		_finish(false, "HANDCART_USE_RELEASE_FAIL: release action did not place handcart at clicked position")
		return

	_finish(true, "HANDCART_USE_RELEASE_PASS: use/release action toggles follow ownership")
