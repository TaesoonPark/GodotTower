extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TEST_SLOT: String = "autosave_smoke_test"

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	_delete_test_save()
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	_delete_test_save()
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var stock_center := Vector2(4440.0, 2480.0)
	var farm_center := Vector2(4760.0, 2480.0)
	var drop_pos := Vector2(4300.0, 2360.0)
	var rally_pos := Vector2(4200.0, 2600.0)
	var craft_supply_pos := Vector2(3860.0, 2200.0)
	_prepare_saved_state(main, stock_center, farm_center, drop_pos, rally_pos, craft_supply_pos)
	if not bool(main.save_game_to_slot(TEST_SLOT)):
		_finish(false, "AUTOSAVE_TEST_FAIL: save_game_to_slot returned false")
		return

	main.queue_free()
	for _i in range(2):
		await get_tree().process_frame

	var loaded: Node = MAIN_SCENE.instantiate()
	add_child(loaded)
	for _i in range(20):
		await get_tree().process_frame
	if not bool(loaded.load_game_from_slot(TEST_SLOT)):
		_finish(false, "AUTOSAVE_TEST_FAIL: load_game_from_slot returned false")
		return

	var result: String = _verify_loaded_state(loaded, stock_center, farm_center, drop_pos, rally_pos)
	if not result.is_empty():
		_finish(false, result)
		return
	_finish(true, "AUTOSAVE_TEST_PASS: autosave save/load restored core play state")

func _prepare_saved_state(main: Node, stock_center: Vector2, farm_center: Vector2, drop_pos: Vector2, rally_pos: Vector2, craft_supply_pos: Vector2) -> void:
	for colonist in main.colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
		for work_type in [&"Haul", &"Build", &"Craft", &"Combat", &"Gather", &"Hunt"]:
			colonist.set_work_enabled(work_type, false)
	main.resource_stock = main._empty_resource_stock()
	main.resource_stock[&"Wood"] = 7
	main.resource_stock[&"FoodRaw"] = 3
	main.hud.set_resource_stock(main.resource_stock)
	main._active_research_id = &"HandcartI"
	main._active_research_points = 2.5
	main._research_running = true
	main._elapsed_game_seconds = 123.0

	var first = main.colonists[0]
	first.global_position = Vector2(3800.0, 2200.0)
	first.health = 77.0
	first.hunger = 66.0
	first.rest = 55.0
	first.mood = 44.0
	var handcart: Node = main._spawn_installed_handcart(first.global_position + Vector2(42.0, 0.0))
	if handcart == null or not bool(main._assign_handcart_to_colonist(handcart, first)):
		_finish(false, "AUTOSAVE_TEST_FAIL: handcart assignment setup failed")
		return

	if not main.build_system.place_stockpile_zone(Rect2(stock_center - Vector2(80.0, 60.0), Vector2(160.0, 120.0))):
		_finish(false, "AUTOSAVE_TEST_FAIL: stockpile placement failed")
		return
	main._mark_group_cache_dirty(&"stockpile_zones")
	var stockpile: Node = main._find_stockpile_zone_near(stock_center, 80.0)
	if stockpile != null and stockpile.has_method("add_resource"):
		stockpile.add_resource(&"Wood", 7)

	if not main.build_system.place_farm_zone(Rect2(farm_center - Vector2(80.0, 60.0), Vector2(160.0, 120.0))):
		_finish(false, "AUTOSAVE_TEST_FAIL: farm placement failed")
		return
	main._mark_group_cache_dirty(&"farm_zones")
	var farm: Node = main._find_farm_zone_near(farm_center, 80.0)
	if farm != null:
		main._configure_farm_zone_catalog(farm)
		farm.set_crop_type(&"Potato")
		var plots: Dictionary = farm.get("_plots")
		if not plots.is_empty():
			var tile: Vector2i = plots.keys()[0]
			farm.plant_crop(tile, &"Potato")
			plots = farm.get("_plots")
			var plot: Dictionary = plots[tile]
			plot["elapsed"] = 42.0
			plots[tile] = plot
			farm.set("_plots", plots)

	main._spawn_resource_drop(&"Stone", 9, drop_pos)
	var depot: Node = main._ensure_workstation_depot(&"CampfireStation", craft_supply_pos + Vector2(96.0, 0.0))
	if depot == null or not is_instance_valid(depot):
		_finish(false, "AUTOSAVE_TEST_FAIL: workstation depot setup failed")
		return
	var requested: Dictionary = {}
	requested[&"FoodRaw"] = 1
	depot.set_requested_ingredients(requested)
	first.current_job = {
		"type": &"HaulStockpileToDepot",
		"phase": &"to_depot",
		"resource_type": &"FoodRaw",
		"amount": 1,
		"carried_type": &"FoodRaw",
		"carried_amount": 1,
		"source_zone_id": stockpile.get_instance_id() if stockpile != null else 0,
		"depot_id": depot.get_instance_id(),
		"target": depot.global_position
	}
	main.job_system.enqueue_craft_recipe(&"CookMeal", &"CampfireStation")
	main._set_combat_rally_point(rally_pos)

func _verify_loaded_state(main: Node, stock_center: Vector2, farm_center: Vector2, drop_pos: Vector2, rally_pos: Vector2) -> String:
	if int(main.resource_stock.get(&"Wood", 0)) != 7:
		return "AUTOSAVE_TEST_FAIL: resource stock did not restore"
	if main.colonists.size() != 4:
		return "AUTOSAVE_TEST_FAIL: colonist count did not restore"
	var first = main.colonists[0]
	if first.global_position.distance_to(main._snap_to_tile(Vector2(3800.0, 2200.0))) > 0.1:
		return "AUTOSAVE_TEST_FAIL: colonist position did not restore"
	if int(round(first.health)) != 77 or int(round(first.hunger)) != 66:
		return "AUTOSAVE_TEST_FAIL: colonist needs did not restore"
	if bool(first.work_enabled.get(&"Hunt", true)):
		return "AUTOSAVE_TEST_FAIL: colonist work toggle did not restore"
	if not _has_handcart_owned_by(first.get_instance_id()):
		return "AUTOSAVE_TEST_FAIL: handcart assignment did not restore %s" % _handcart_debug(first.get_instance_id())
	if StringName(main._active_research_id) != &"HandcartI" or not is_equal_approx(float(main._active_research_points), 2.5):
		return "AUTOSAVE_TEST_FAIL: research state did not restore"

	var stockpile: Node = main._find_stockpile_zone_near(stock_center, 80.0)
	if stockpile == null or not is_instance_valid(stockpile):
		return "AUTOSAVE_TEST_FAIL: stockpile did not restore"
	if int(stockpile.get_stored_amount(&"Wood")) != 7:
		return "AUTOSAVE_TEST_FAIL: stockpile contents did not restore"
	if int(stockpile.get_stored_amount(&"FoodRaw")) != 0:
		return "AUTOSAVE_TEST_FAIL: craft supply leaked into stockpile"

	var farm: Node = main._find_farm_zone_near(farm_center, 80.0)
	if farm == null or not is_instance_valid(farm):
		return "AUTOSAVE_TEST_FAIL: farm did not restore"
	if StringName(farm.get("crop_type")) != &"Potato":
		return "AUTOSAVE_TEST_FAIL: farm crop did not restore"
	if not _has_growing_plot(farm):
		return "AUTOSAVE_TEST_FAIL: farm plot state did not restore"

	if _sum_drop_amount_near(&"Stone", drop_pos, 80.0) < 9:
		return "AUTOSAVE_TEST_FAIL: resource drop did not restore"
	var queue: Array[Dictionary] = main.job_system.get_craft_queue(&"CampfireStation")
	if queue.is_empty() or StringName(queue[0].get("recipe_id", &"")) != &"CookMeal":
		return "AUTOSAVE_TEST_FAIL: craft queue did not restore"
	if not _depot_has_stored_supply(main, &"CampfireStation", &"FoodRaw", 1):
		return "AUTOSAVE_TEST_FAIL: carried workstation supply did not restore %s" % _depot_debug(main, &"CampfireStation")
	if main._rally_flag_node == null or not is_instance_valid(main._rally_flag_node):
		return "AUTOSAVE_TEST_FAIL: rally flag did not restore"
	if main._combat_rally_point.distance_to(main._snap_to_tile(rally_pos)) > 0.1:
		return "AUTOSAVE_TEST_FAIL: rally point did not restore"
	return ""

func _has_growing_plot(farm: Node) -> bool:
	var plots: Dictionary = farm.get("_plots")
	for tile in plots.keys():
		var plot: Dictionary = plots[tile]
		if StringName(plot.get("state", &"")) == &"Growing" and float(plot.get("elapsed", 0.0)) >= 40.0:
			return true
	return false

func _has_handcart_owned_by(owner_id: int) -> bool:
	for handcart in get_tree().get_nodes_in_group("handcarts"):
		if handcart == null or not is_instance_valid(handcart):
			continue
		if handcart.has_method("is_owned_by") and bool(handcart.is_owned_by(owner_id)):
			return true
		if handcart.has_meta("assigned_colonist_id") and int(handcart.get_meta("assigned_colonist_id")) == owner_id:
			return true
	return false

func _handcart_debug(owner_id: int) -> String:
	var rows: Array[String] = []
	for handcart in get_tree().get_nodes_in_group("handcarts"):
		if handcart == null or not is_instance_valid(handcart):
			continue
		var assigned: int = int(handcart.get_meta("assigned_colonist_id")) if handcart.has_meta("assigned_colonist_id") else -1
		rows.append("%s:%d" % [String(handcart.name), assigned])
	return "(owner=%d handcarts=%s)" % [owner_id, ",".join(rows)]

func _depot_has_stored_supply(main: Node, workstation_id: StringName, resource_type: StringName, amount: int) -> bool:
	var depot: Node = main._workstation_depots.get(workstation_id, null)
	if depot == null or not is_instance_valid(depot):
		return false
	return int(depot.get_stored_amount(resource_type)) >= amount

func _depot_debug(main: Node, workstation_id: StringName) -> String:
	var depot: Node = main._workstation_depots.get(workstation_id, null)
	if depot == null or not is_instance_valid(depot):
		return "(depot missing)"
	return str({
		"stored": depot.get("stored"),
		"requested": depot.get("requested"),
		"pending": depot.get("pending")
	})

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

func _delete_test_save() -> void:
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return
	var file_name := "%s_autosave.json" % TEST_SLOT
	if dir.file_exists(file_name):
		dir.remove(file_name)
