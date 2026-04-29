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

func _slot_pick_world(zone: Node, resource_type: StringName) -> Vector2:
	for i in range(zone._stack_slots.size()):
		var slot: Dictionary = zone._stack_slots[i]
		if StringName(slot.get("resource_type", &"")) != resource_type:
			continue
		var slot_rect: Rect2 = slot.get("rect", Rect2())
		return zone.to_global(slot_rect.get_center())
	return Vector2.INF

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: no colonists")
		return
	var colonist: Node = colonists[0]
	main._set_selected([colonist])

	var stock_rect := Rect2(Vector2(3880.0, 2140.0), Vector2(240.0, 160.0))
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: stockpile placement failed")
		return
	await get_tree().process_frame
	var zone: Node = main._find_stockpile_zone_near(stock_rect.get_center(), 40.0)
	if zone == null:
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: stockpile missing")
		return
	if int(zone.add_resource(&"Rifle", 1)) <= 0:
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: failed to seed rifle")
		return
	main.resource_stock[&"Rifle"] = int(main.resource_stock.get(&"Rifle", 0)) + 1
	await get_tree().process_frame

	var rifle_pick: Vector2 = _slot_pick_world(zone, &"Rifle")
	if rifle_pick == Vector2.INF:
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: rifle slot missing")
		return
	if not bool(main._try_show_equipment_context_from_right_click(rifle_pick, Vector2(24.0, 24.0))):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: stockpile rifle did not show equip menu")
		return
	if StringName(main.hud.get("_context_action_id")) != &"EquipSelectedItem":
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: stockpile rifle context action mismatch")
		return
	main._on_context_action_requested(&"EquipSelectedItem")
	await get_tree().process_frame
	var equipment: Dictionary = colonist.get_equipment_snapshot()
	if StringName(equipment.get(&"Weapon", &"")) != &"Rifle":
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: rifle was not equipped")
		return
	if int(zone.get_stored_amount(&"Rifle")) != 0:
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: rifle was not removed from stockpile")
		return

	var hat_drop: Node = main._spawn_resource_drop(&"CombatHat", 1, Vector2(5360.0, 2560.0))
	await get_tree().process_frame
	if hat_drop == null or not is_instance_valid(hat_drop):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: combat hat drop missing")
		return
	if not bool(main._try_show_equipment_context_from_right_click(hat_drop.global_position, Vector2(42.0, 42.0))):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: floor hat did not show equip menu")
		return
	main._on_context_action_requested(&"EquipSelectedItem")
	await get_tree().process_frame
	equipment = colonist.get_equipment_snapshot()
	if StringName(equipment.get(&"Hat", &"")) != &"CombatHat":
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: floor hat was not equipped")
		return
	if int(main.resource_stock.get(&"CombatHat", 0)) < 1:
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: equipped floor hat was not counted in stock")
		return

	var wood_drop: Node = main._spawn_resource_drop(&"Wood", 1, Vector2(5480.0, 2560.0))
	await get_tree().process_frame
	if wood_drop == null or not is_instance_valid(wood_drop):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: wood drop missing")
		return
	if bool(main._try_show_equipment_context_from_right_click(wood_drop.global_position, Vector2(64.0, 64.0))):
		_finish(false, "EQUIPMENT_CONTEXT_MENU_FAIL: non-equipment wood showed equip menu")
		return

	_finish(true, "EQUIPMENT_CONTEXT_MENU_PASS: selected colonist can equip stockpile and floor equipment")
