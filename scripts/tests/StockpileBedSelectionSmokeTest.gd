extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
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

	var stock_rect := Rect2(Vector2(3880.0, 2140.0), Vector2(240.0, 160.0))
	var existing_zone_ids: Dictionary = {}
	for existing_zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if existing_zone == null or not is_instance_valid(existing_zone):
			continue
		existing_zone_ids[int(existing_zone.get_instance_id())] = true
	if not main.build_system.place_stockpile_zone(stock_rect):
		_finish(false, "STOCKPILE_BED_TEST_FAIL: stockpile placement failed")
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
		zone = main._find_stockpile_zone_near(stock_rect.get_center(), 40.0)
	if zone == null:
		_finish(false, "STOCKPILE_BED_TEST_FAIL: no stockpile zone")
		return

	var added_bed: int = int(zone.add_resource(&"Bed", 1))
	var added_wood: int = int(zone.add_resource(&"Wood", 1))
	if added_bed <= 0 or added_wood <= 0:
		_finish(false, "STOCKPILE_BED_TEST_FAIL: failed to seed resources")
		return
	main.resource_stock[&"Bed"] = int(main.resource_stock.get(&"Bed", 0)) + added_bed
	main.resource_stock[&"Wood"] = int(main.resource_stock.get(&"Wood", 0)) + added_wood
	main.hud.set_resource_stock(main.resource_stock)
	await get_tree().process_frame

	var bed_slot_index: int = -1
	for i in range(zone._stack_slots.size()):
		var slot: Dictionary = zone._stack_slots[i]
		if String(slot.get("resource_type", "")).to_lower() == "bed":
			bed_slot_index = i
			break
	if bed_slot_index < 0:
		_finish(false, "STOCKPILE_BED_TEST_FAIL: bed slot not built")
		return

	var bed_holder: Node = zone._stack_root.get_child(bed_slot_index)
	var bed_sprite: Sprite2D = bed_holder.get_child(0) as Sprite2D
	var expected_tex: Texture2D = GAME_SPRITE.get_drop_texture(&"Bed")
	if expected_tex == null:
		_finish(false, "STOCKPILE_BED_TEST_FAIL: missing bed drop texture")
		return
	if bed_sprite == null or bed_sprite.texture != expected_tex:
		_finish(false, "STOCKPILE_BED_TEST_FAIL: stockpile bed icon texture not applied")
		return

	var bed_slot: Dictionary = zone._stack_slots[bed_slot_index]
	var slot_rect: Rect2 = bed_slot.get("rect", Rect2())
	var pick_world: Vector2 = zone.to_global(slot_rect.get_center() + Vector2(0.0, 14.0))
	main._on_left_click(main._snap_to_tile(pick_world))
	await get_tree().process_frame

	if StringName(main._selected_object_kind) != &"StockpileItem":
		_finish(false, "STOCKPILE_BED_TEST_FAIL: stockpile item not selected")
		return
	if StringName(main._selected_object_resource) != &"Bed":
		_finish(false, "STOCKPILE_BED_TEST_FAIL: bed item selection failed")
		return

	_finish(true, "STOCKPILE_BED_TEST_PASS: bed selectable and stockpile icon rendered")
