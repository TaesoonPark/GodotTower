extends Node2D

const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
const HUNTABLE_SCENE: PackedScene = preload("res://scenes/world/Huntable.tscn")
const WORKSTATION_DEPOT_SCRIPT: Script = preload("res://scripts/core/WorkstationDepot.gd")
const BUILDING_DEF_DIR := "res://data/buildings"
const RECIPE_DEF_DIR := "res://data/recipes"
const WORKSTATION_DEF_DIR := "res://data/workstations"
const RESOURCE_DROP_SCENE: PackedScene = preload("res://scenes/world/ResourceDrop.tscn")
const WORLD_SIZE: Vector2 = Vector2(7680.0, 4320.0)
const EDGE_SCROLL_MARGIN: float = 18.0
const EDGE_SCROLL_SPEED: float = 980.0
const MIN_ZOOM: float = 0.65
const MAX_ZOOM: float = 1.85
const ZOOM_STEP: float = 0.08

@onready var world_root: Node2D = $WorldRoot
@onready var units_root: Node2D = $UnitsRoot
@onready var camera: Camera2D = $Camera2D
@onready var input_controller: Node = $Systems/InputController
@onready var need_system: Node = $Systems/NeedSystem
@onready var job_system: Node = $Systems/JobSystem
@onready var build_system: Node = $Systems/BuildSystem
@onready var hud: HUDController = $HUD

var colonists: Array = []
var selected_colonists: Array = []
var camera_speed: float = 750.0
var current_action: StringName = &"Interact"
var resource_stock: Dictionary = {
	&"Wood": 30,
	&"Stone": 20,
	&"Steel": 15,
	&"FoodRaw": 0,
	&"Meal": 0,
	&"Bed": 0,
	&"GatherTop": 0,
	&"GatherBottom": 0,
	&"StrawHat": 0,
	&"Weapon": 0,
	&"CombatTop": 0,
	&"CombatBottom": 0,
	&"CombatHat": 0,
	&"Sword": 0,
	&"Bow": 0
}
var target_stock: Dictionary = {
	&"Wood": 80,
	&"Stone": 80,
	&"Steel": 40,
	&"FoodRaw": 40
}
var recipe_lookup: Dictionary = {}
var workstation_lookup: Dictionary = {}
var selected_workstation_id: StringName = &""
var selected_stockpile_zone: Node = null
var _middle_drag_camera: bool = false
var _game_paused: bool = false
var _speed_scale: float = 1.0
var pending_building_id: StringName = &""
var pending_install_item: StringName = &""
var pending_install_drop_id: int = 0
var selected_designation_target: Node = null
var selected_bed_node: Node = null
var _last_camera_ticks_usec: int = 0
var _elapsed_game_seconds: float = 0.0
var _equipped_top_ids: Dictionary = {}
var _equipped_bottom_ids: Dictionary = {}
var _equipped_hat_ids: Dictionary = {}
var _equipped_weapon_ids: Dictionary = {}
var _context_gather_target_id: int = 0
var _context_workstation_id: StringName = &""
var _selected_object_kind: StringName = &""
var _selected_object_resource: StringName = &""
var _selected_object_zone: Node = null
var _workstation_depots: Dictionary = {}
var _outfit_mode: StringName = &"Work"
var _equipped_weapon_kind: Dictionary = {}
var _raid_state: StringName = &"Idle"
var _raid_warning_timer: float = 0.0
var _raid_wave_size: int = 0

func _ready() -> void:
	randomize()
	_configure_world_bounds()
	_randomize_world_spawns()
	var building_defs: Array = _load_building_defs()
	var workstation_defs: Array = _load_workstation_defs()
	var recipe_defs: Array = _load_recipe_defs()
	for ws in workstation_defs:
		if ws != null:
			workstation_lookup[ws.id] = ws
	if not workstation_defs.is_empty():
		selected_workstation_id = workstation_defs[0].id
	for recipe in recipe_defs:
		if recipe != null:
			recipe_lookup[recipe.id] = recipe
	_spawn_initial_colonists()
	build_system.configure(world_root, building_defs)
	input_controller.left_click.connect(_on_left_click)
	input_controller.drag_selection.connect(_on_drag_selection)
	hud.priority_changed.connect(_on_priority_changed)
	hud.work_toggle_changed.connect(_on_work_toggle_changed)
	hud.building_selected.connect(_on_building_selected)
	hud.workstation_changed.connect(_on_workstation_changed)
	hud.craft_recipe_queued.connect(_on_craft_recipe_queued)
	hud.craft_queue_clear_requested.connect(_on_craft_queue_clear_requested)
	hud.craft_queue_remove_requested.connect(_on_craft_queue_remove_requested)
	hud.stockpile_filter_mode_changed.connect(_on_stockpile_filter_mode_changed)
	hud.stockpile_filter_item_changed.connect(_on_stockpile_filter_item_changed)
	hud.stockpile_priority_changed.connect(_on_stockpile_priority_changed)
	hud.stockpile_limit_changed.connect(_on_stockpile_limit_changed)
	hud.designation_toggle_requested.connect(_on_designation_toggle_requested)
	hud.drag_gather_mode_requested.connect(func(): _on_action_changed(&"DragGather"))
	hud.drag_stockpile_mode_requested.connect(func(): _on_action_changed(&"StockpileZone"))
	hud.clear_state_requested.connect(_on_clear_state_requested)
	hud.context_action_requested.connect(_on_context_action_requested)
	hud.selected_object_action_requested.connect(_on_selected_object_action_requested)
	hud.outfit_mode_changed.connect(_on_outfit_mode_changed)
	hud.raid_test_warning_requested.connect(_on_raid_test_warning_requested)
	hud.bed_assignee_changed.connect(_on_bed_assignee_changed)
	hud.bed_auto_assign_requested.connect(_on_bed_auto_assign_requested)
	hud.set_building_catalog(building_defs)
	hud.set_workstation_catalog(workstation_defs)
	hud.set_selected_workstation(selected_workstation_id)
	hud.set_recipe_catalog(_filter_recipes_for_workstation(selected_workstation_id))
	hud.set_selected_count(0)
	hud.set_needs_preview(null)
	hud.set_priority_preview(null)
	hud.set_current_job_preview(null)
	hud.set_carry_capacity_preview(null)
	hud.set_work_toggles({})
	hud.set_craft_queue_preview([])
	hud.set_stockpile_filter_state(false, 0, {}, 0, {})
	hud.set_selected_status_visible(false)
	hud.set_craft_panel_visible(false)
	hud.set_resource_stock(resource_stock)
	hud.set_active_action(&"Interact")
	hud.set_command_button_states(current_action)
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
	hud.set_outfit_mode(_outfit_mode)
	hud.set_raid_state(_raid_state, _raid_warning_timer)
	hud.set_designation_panel_visible(false)
	hud.set_bed_assignment_visible(false)
	hud.set_equipment_preview(null)
	_apply_time_scale()
	_clamp_camera()

func _process(delta: float) -> void:
	_process_camera(_get_camera_delta(delta))
	if not _game_paused:
		_elapsed_game_seconds += delta
	_prune_colonists()
	_update_raid_state(delta)
	need_system.process_needs(delta, colonists)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		colonist.update_job_completion(delta)
		var food_available: int = int(resource_stock.get(&"Meal", 0)) + int(resource_stock.get(&"FoodRaw", 0))
		job_system.queue_need_jobs(colonist, food_available)
	_apply_passive_item_bonuses()
	job_system.request_combat_jobs(colonists, _get_alive_raiders())
	_request_designated_resource_jobs()
	_update_workstation_supply_requests()
	var haul_targets: Array = get_tree().get_nodes_in_group("stockpile_zones")
	for depot in _workstation_depots.values():
		if depot != null and is_instance_valid(depot):
			haul_targets.append(depot)
	job_system.request_haul_jobs(
		get_tree().get_nodes_in_group("resource_drops"),
		haul_targets,
		resource_stock,
		target_stock
	)
	build_system.request_build_jobs(job_system)
	job_system.request_craft_jobs(
		recipe_lookup,
		_build_workstation_position_map(),
		Callable(self, "_can_start_recipe_at_workstation"),
		Callable(self, "_on_recipe_started_at_workstation")
	)
	job_system.assign_jobs(colonists)
	_reconcile_stockpile_totals_with_resource_stock()
	hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
	hud.set_raid_state(_raid_state, _raid_warning_timer)
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_handle_user_right_click(event)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_drag_camera = event.pressed
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_camera_zoom(camera.zoom.x + ZOOM_STEP)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_camera_zoom(camera.zoom.x - ZOOM_STEP)
			return
	if event is InputEventMouseMotion and _middle_drag_camera:
		camera.global_position -= event.relative * camera.zoom.x
		_clamp_camera()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_game_paused = not _game_paused
				_apply_time_scale()
				return
			KEY_1, KEY_KP_1:
				_set_game_speed(1.0)
				return
			KEY_2, KEY_KP_2:
				_set_game_speed(2.0)
				return
			KEY_3, KEY_KP_3:
				_set_game_speed(4.0)
				return
			KEY_ESCAPE:
				_clear_pending_placement()
				hud.set_active_action(&"Interact")
				return
	input_controller.process_unhandled_input(event, world_root)
	if event is InputEventMouseMotion and input_controller.dragging:
		queue_redraw()

func _draw() -> void:
	if not input_controller.dragging:
		return
	var rect: Rect2 = Rect2(input_controller.drag_start, input_controller.drag_end - input_controller.drag_start).abs()
	var fill_color := Color(0.3, 0.8, 1.0, 0.15)
	var border_color := Color(0.3, 0.8, 1.0)
	if current_action == &"StockpileZone":
		fill_color = Color(0.95, 0.75, 0.28, 0.18)
		border_color = Color(1.0, 0.82, 0.3)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, 2.0)

func _spawn_initial_colonists() -> void:
	var center: Vector2 = WORLD_SIZE * 0.5
	var positions := [
		center + Vector2(-120, -70),
		center + Vector2(-60, 20),
		center + Vector2(10, -60),
		center + Vector2(-130, 90)
	]
	for pos in positions:
		var c := COLONIST_SCENE.instantiate()
		c.name = "Colonist%d" % [colonists.size() + 1]
		c.global_position = pos
		c.status_changed.connect(_on_colonist_status_changed)
		c.resource_harvested.connect(_on_resource_harvested)
		c.resource_delivered.connect(_on_resource_delivered)
		c.craft_completed.connect(_on_craft_completed)
		c.haul_job_released.connect(_on_haul_job_released)
		c.ate_food.connect(_on_colonist_ate_food)
		c.died.connect(_on_colonist_died)
		units_root.add_child(c)
		c.priorities.combat = 10
		c.priorities.build = 9
		c.priorities.craft = 8
		c.priorities.gather = 7
		c.priorities.hunt = 6
		c.priorities.haul = 5
		colonists.append(c)

func _on_left_click(world_pos: Vector2) -> void:
	hud.hide_context_action_button()
	var stockpile_item: Dictionary = _find_stockpile_item_at(world_pos)
	if not stockpile_item.is_empty():
		_set_selected([])
		selected_stockpile_zone = stockpile_item.get("zone", null)
		_selected_object_kind = &"StockpileItem"
		_selected_object_zone = selected_stockpile_zone
		_selected_object_resource = StringName(stockpile_item.get("resource_type", &""))
		_refresh_hud()
		hud.set_active_action(&"StockpileItem")
		return
	var bed_node: Node = _find_installed_bed_near(world_pos, 42.0)
	if bed_node != null:
		_clear_selected_object()
		selected_bed_node = bed_node
		_refresh_bed_assign_ui()
		hud.set_active_action(&"BedSelected")
		return
	if current_action == &"StockpileZone":
		_clear_selected_object()
		_select_stockpile_zone_near(world_pos)
		hud.set_active_action(&"StockpileDesignate")
		return
	selected_bed_node = null
	hud.set_bed_assignment_visible(false)
	var clicked: Node = _find_colonist_near(world_pos, 30.0)
	if clicked != null:
		_clear_selected_object()
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_set_selected([clicked])
		hud.set_active_action(&"UnitSelected")
		return

	var drop: Node = _find_resource_drop_near(world_pos, 40.0)
	if drop != null and StringName(drop.get("resource_type")) == &"Bed":
		_clear_selected_object()
		pending_install_item = &"Bed"
		pending_install_drop_id = drop.get_instance_id()
		hud.set_active_action(&"InstallBed")
		return

	var gatherable: Node = _find_gatherable_near(world_pos, 48.0)
	if gatherable != null:
		_clear_selected_object()
		selected_designation_target = gatherable
		_refresh_designation_ui()
		hud.set_active_action(&"GatherTarget")
		return

	var huntable: Node = _find_huntable_near(world_pos, 52.0)
	if huntable != null:
		_clear_selected_object()
		selected_designation_target = huntable
		_refresh_designation_ui()
		hud.set_active_action(&"HuntTarget")
		return

	var ws_id: StringName = _find_workstation_id_near(world_pos, 56.0)
	if ws_id != &"":
		_clear_selected_object()
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_activate_workstation(ws_id)
		hud.set_active_action(&"Workstation")
		return
	hud.set_craft_panel_visible(false)

	var clicked_zone: Node = _find_stockpile_zone_near(world_pos, 40.0)
	if clicked_zone != null:
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_set_selected([])
		selected_stockpile_zone = clicked_zone
		_clear_selected_object()
		_refresh_stockpile_filter_ui()
		hud.set_active_action(&"Stockpile")
		return
	else:
		selected_stockpile_zone = null

	if pending_install_item != &"":
		if _try_install_pending_item(world_pos):
			_clear_pending_placement()
		_refresh_hud()
		return

	if pending_building_id != &"":
		_try_place_building_by_id(world_pos, pending_building_id)
		_clear_pending_placement()
		_refresh_hud()
		return

	_set_selected([])
	_clear_selected_object()
	selected_designation_target = null
	hud.set_designation_panel_visible(false)
	hud.set_active_action(&"Interact")
	_refresh_stockpile_filter_ui()

func _on_drag_selection(start_pos: Vector2, end_pos: Vector2) -> void:
	hud.hide_context_action_button()
	_clear_selected_object()
	var rect := Rect2(start_pos, end_pos - start_pos).abs()
	if current_action == &"DragGather":
		for node in get_tree().get_nodes_in_group("gatherables"):
			if node == null or not is_instance_valid(node):
				continue
			if not rect.has_point(node.global_position):
				continue
			if node.has_method("set_designated"):
				node.set_designated(true)
		for node in get_tree().get_nodes_in_group("huntables"):
			if node == null or not is_instance_valid(node):
				continue
			if not rect.has_point(node.global_position):
				continue
			if node.has_method("set_designated"):
				node.set_designated(true)
		queue_redraw()
		return
	if current_action == &"StockpileZone":
		if build_system.place_stockpile_zone(rect):
			_select_stockpile_zone_near(rect.get_center())
		queue_redraw()
		return
	selected_stockpile_zone = null
	selected_bed_node = null
	var picked: Array = []
	for colonist in colonists:
		if rect.has_point(colonist.global_position):
			picked.append(colonist)
	_set_selected(picked)
	queue_redraw()

func _set_selected(new_selection: Array) -> void:
	for c in selected_colonists:
		if c != null:
			c.set_selected(false)
	selected_colonists = new_selection
	for c in selected_colonists:
		c.set_selected(true)
	_refresh_hud()

func _find_colonist_near(world_pos: Vector2, radius: float) -> Node:
	for colonist in colonists:
		if colonist.global_position.distance_to(world_pos) <= radius:
			return colonist
	return null

func _refresh_hud() -> void:
	hud.set_selected_count(selected_colonists.size())
	hud.set_resource_stock(resource_stock)
	var focus: Node = selected_colonists[0] if not selected_colonists.is_empty() else null
	var stockpile_focus: Node = selected_stockpile_zone if selected_stockpile_zone != null and is_instance_valid(selected_stockpile_zone) else null
	var object_focus: bool = _selected_object_kind != &"" and _selected_object_zone != null and is_instance_valid(_selected_object_zone)
	hud.set_selected_status_visible(focus != null or stockpile_focus != null or object_focus)
	hud.set_needs_preview(focus)
	hud.set_priority_preview(focus)
	hud.set_current_job_preview(focus)
	hud.set_carry_capacity_preview(focus)
	hud.set_equipment_preview(focus)
	if focus != null:
		hud.set_stockpile_inventory_preview(null)
	elif object_focus:
		var amount: int = 0
		if _selected_object_zone.has_method("get_stored_amount"):
			amount = int(_selected_object_zone.get_stored_amount(_selected_object_resource))
		var title: String = "Selected: %s" % String(_selected_object_resource)
		var detail: String = "Type: Stockpile Item\nAmount: %d" % amount
		var actions: Array = []
		if _selected_object_resource == &"Bed" and amount > 0:
			actions.append({"id": &"PlaceBedFromStockpile", "label": "배치하기"})
		hud.set_selected_object_preview(title, detail, actions)
	else:
		hud.set_stockpile_inventory_preview(stockpile_focus)
	if focus != null:
		hud.set_work_toggles(focus.work_enabled)
	else:
		hud.set_work_toggles({})
	_refresh_designation_ui()
	_refresh_bed_assign_ui()
	_refresh_stockpile_filter_ui()

func _on_priority_changed(job_type: StringName, value: int) -> void:
	for c in colonists:
		match job_type:
			&"Haul":
				c.priorities.haul = value
			&"Build":
				c.priorities.build = value
			&"Craft":
				c.priorities.craft = value
			&"Gather":
				c.priorities.gather = value
			&"Hunt":
				c.priorities.hunt = value
			&"Combat":
				c.priorities.combat = value

func _on_work_toggle_changed(work_type: StringName, enabled: bool) -> void:
	for c in selected_colonists:
		c.set_work_enabled(work_type, enabled)

func _on_colonist_status_changed(_colonist: Node) -> void:
	if selected_colonists.is_empty():
		return
	_refresh_hud()

func _on_action_changed(action: StringName) -> void:
	current_action = action
	hud.set_active_action(action)
	hud.set_command_button_states(current_action)
	if action == &"StockpileZone":
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
	if action != &"StockpileZone":
		selected_stockpile_zone = null

func _on_building_selected(building_id: StringName) -> void:
	pending_building_id = building_id
	pending_install_item = &""
	pending_install_drop_id = 0
	hud.set_active_action(StringName("Place %s" % String(building_id)))

func _on_workstation_changed(workstation_id: StringName) -> void:
	selected_workstation_id = workstation_id
	hud.set_recipe_catalog(_filter_recipes_for_workstation(workstation_id))
	hud.set_craft_queue_preview(job_system.get_craft_queue(workstation_id))
	var ws_name: String = _get_workstation_display_name(workstation_id)
	hud.set_craft_panel_visible(true, ws_name)

func _on_stockpile_filter_mode_changed(mode: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_filter_mode"):
		selected_stockpile_zone.set_filter_mode(mode)
	_refresh_stockpile_filter_ui()

func _on_stockpile_filter_item_changed(resource_type: StringName, enabled: bool) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_filter_item"):
		selected_stockpile_zone.set_filter_item(resource_type, enabled)
	_refresh_stockpile_filter_ui()

func _on_stockpile_priority_changed(value: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_zone_priority"):
		selected_stockpile_zone.set_zone_priority(value)
	_refresh_stockpile_filter_ui()

func _on_stockpile_limit_changed(resource_type: StringName, limit: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_resource_limit"):
		selected_stockpile_zone.set_resource_limit(resource_type, limit)
	_refresh_stockpile_filter_ui()

func _find_gatherable_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_huntable_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("huntables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_resource_drop_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("resource_drops"):
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_installed_bed_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		if node.get_meta("building_id") != &"InstalledBed":
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _on_resource_harvested(resource_type: StringName, amount: int, world_pos: Vector2) -> void:
	# Harvest result is always dropped in world first; stock updates only after hauling into stockpile.
	_spawn_resource_drop(resource_type, amount, world_pos)

func _on_resource_delivered(resource_type: StringName, amount: int, zone: Node) -> void:
	if amount <= 0:
		return
	if zone == null or not is_instance_valid(zone) or not zone.has_method("add_resource"):
		_spawn_resource_drop(resource_type, amount, camera.global_position)
		return
	var accepted: int = int(zone.add_resource(resource_type, amount))
	if accepted <= 0:
		_spawn_resource_drop(resource_type, amount, zone.global_position)
		return
	var delivered_to_workstation: bool = zone.has_method("can_start_recipe")
	if not delivered_to_workstation:
		if not resource_stock.has(resource_type):
			resource_stock[resource_type] = 0
		resource_stock[resource_type] += accepted
	var remain: int = amount - accepted
	if remain > 0:
		_spawn_resource_drop(resource_type, remain, zone.global_position)
	hud.set_resource_stock(resource_stock)

func _on_craft_completed(products: Dictionary, world_pos: Vector2) -> void:
	for k in products.keys():
		var amount: int = int(products[k])
		if amount <= 0:
			continue
		_spawn_resource_drop(StringName(k), amount, world_pos)
	job_system.notify_craft_job_finished()

func _on_craft_recipe_queued(recipe_id: StringName, workstation_id: StringName) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	selected_workstation_id = ws_id
	job_system.enqueue_craft_recipe(recipe_id, ws_id)
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_queue_clear_requested() -> void:
	job_system.clear_craft_queue(selected_workstation_id)
	hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))

func _on_craft_queue_remove_requested(workstation_id: StringName, index: int) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	selected_workstation_id = ws_id
	job_system.remove_craft_recipe_at(ws_id, index)
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_haul_job_released(drop_id: int) -> void:
	job_system.release_haul_reservation(drop_id)

func _on_colonist_ate_food() -> void:
	if _consume_resource_stock(&"Meal", 1):
		hud.set_resource_stock(resource_stock)
		return
	if _consume_resource_stock(&"FoodRaw", 1):
		hud.set_resource_stock(resource_stock)

func _try_place_selected_building(world_pos: Vector2, as_blueprint: bool) -> void:
	var snapshot: Dictionary = resource_stock.duplicate(true)
	if not build_system.consume_selected_cost(resource_stock):
		return
	var placed: bool = build_system.place_building(world_pos, as_blueprint)
	if not placed:
		resource_stock = snapshot
	else:
		_consume_stockpile_by_delta(snapshot, resource_stock)
	hud.set_resource_stock(resource_stock)

func _try_place_building_by_id(world_pos: Vector2, building_id: StringName) -> void:
	if building_id == &"Stockpile":
		var snapshot: Dictionary = resource_stock.duplicate(true)
		build_system.set_selected_building(building_id)
		if not build_system.consume_selected_cost(resource_stock):
			return
		var zone_rect := Rect2(world_pos - Vector2(80.0, 60.0), Vector2(160.0, 120.0))
		if not build_system.place_stockpile_zone(zone_rect):
			resource_stock = snapshot
		else:
			_consume_stockpile_by_delta(snapshot, resource_stock)
		hud.set_resource_stock(resource_stock)
		return
	build_system.set_selected_building(building_id)
	_try_place_selected_building(world_pos, true)

func _try_install_pending_item(world_pos: Vector2) -> bool:
	if pending_install_item != &"Bed":
		return false
	var consumed: bool = false
	if pending_install_drop_id == -1:
		consumed = true
	elif pending_install_drop_id != 0:
		var drop_obj: Object = instance_from_id(pending_install_drop_id)
		if drop_obj != null and is_instance_valid(drop_obj) and drop_obj.has_method("take_amount"):
			var taken: int = int(drop_obj.take_amount(1))
			if taken > 0:
				if drop_obj.has_method("is_empty") and drop_obj.is_empty():
					drop_obj.queue_free()
				consumed = true
	if not consumed:
		if not _consume_resource_stock(&"Bed", 1):
			return false
		consumed = true
	if not consumed:
		return false
	var snapped_pos := Vector2(
		round(world_pos.x / 40.0) * 40.0,
		round(world_pos.y / 40.0) * 40.0
	)
	var placed := Node2D.new()
	placed.name = "Installed_Bed"
	placed.global_position = snapped_pos
	placed.add_to_group("structures")
	placed.set_meta("building_id", &"InstalledBed")
	placed.set_meta("assigned_colonist_id", 0)
	var sprite := Sprite2D.new()
	var image := Image.create(68, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.73, 0.54, 0.36, 1.0))
	sprite.texture = ImageTexture.create_from_image(image)
	placed.add_child(sprite)
	var txt := Label.new()
	txt.text = "Bed (미배정)"
	txt.position = Vector2(-24, -28)
	placed.add_child(txt)
	world_root.add_child(placed)
	hud.set_resource_stock(resource_stock)
	return true

func _can_start_recipe_at_workstation(workstation_id: StringName, recipe: Resource) -> bool:
	if recipe == null:
		return false
	var depot: Node = _workstation_depots.get(workstation_id, null)
	if depot == null or not is_instance_valid(depot) or not depot.has_method("can_start_recipe"):
		return false
	return bool(depot.can_start_recipe(recipe.ingredients))

func _on_recipe_started_at_workstation(workstation_id: StringName, recipe: Resource) -> void:
	if recipe == null:
		return
	var depot: Node = _workstation_depots.get(workstation_id, null)
	if depot == null or not is_instance_valid(depot) or not depot.has_method("consume_for_recipe"):
		return
	depot.consume_for_recipe(recipe.ingredients)

func _update_workstation_supply_requests() -> void:
	var workstation_positions: Dictionary = _build_workstation_position_map()
	for ws_id_any in workstation_lookup.keys():
		var ws_id: StringName = StringName(ws_id_any)
		var ws_pos: Vector2 = workstation_positions.get(ws_id, Vector2.INF)
		if ws_pos == Vector2.INF:
			continue
		var depot: Node = _ensure_workstation_depot(ws_id, ws_pos)
		if depot == null:
			continue
		var craft_queue: Array[Dictionary] = job_system.get_craft_queue(ws_id)
		if craft_queue.is_empty():
			depot.set_requested_ingredients({})
			continue
		var front: Dictionary = craft_queue[0]
		var recipe_id: StringName = front.get("recipe_id", &"")
		if not recipe_lookup.has(recipe_id):
			depot.set_requested_ingredients({})
			continue
		var recipe: Resource = recipe_lookup[recipe_id]
		depot.set_requested_ingredients(recipe.ingredients)
		for key_any in recipe.ingredients.keys():
			var resource_type: StringName = StringName(key_any)
			var need: int = int(recipe.ingredients[key_any])
			var ready: int = int(depot.get_stored_amount(resource_type)) + int(depot.get_pending_amount(resource_type))
			var deficit: int = maxi(0, need - ready)
			if deficit <= 0:
				continue
			var withdrawn: int = _withdraw_from_stockpiles_for_supply(resource_type, deficit)
			if withdrawn <= 0:
				continue
			depot.mark_supply_spawned(resource_type, withdrawn)
			_spawn_supply_drop_for_workstation(resource_type, withdrawn)

func _ensure_workstation_depot(workstation_id: StringName, pos: Vector2) -> Node:
	if _workstation_depots.has(workstation_id):
		var existing: Node = _workstation_depots[workstation_id]
		if existing != null and is_instance_valid(existing):
			existing.global_position = pos
			return existing
	var depot: Node2D = WORKSTATION_DEPOT_SCRIPT.new()
	depot.name = "Depot_%s" % String(workstation_id)
	world_root.add_child(depot)
	if depot.has_method("setup"):
		depot.setup(workstation_id, pos)
	_workstation_depots[workstation_id] = depot
	return depot

func _spawn_supply_drop_for_workstation(resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var anchor_zone: Node = _find_best_stockpile_with_resource(resource_type)
	var spawn_pos: Vector2 = camera.global_position
	if anchor_zone != null and is_instance_valid(anchor_zone):
		spawn_pos = anchor_zone.global_position + Vector2(randf_range(-20.0, 20.0), randf_range(-12.0, 12.0))
	var drop: Node = _spawn_resource_drop(resource_type, amount, spawn_pos)
	if drop != null and is_instance_valid(drop):
		drop.set_meta("craft_supply", true)

func _find_best_stockpile_with_resource(resource_type: StringName) -> Node:
	var best_zone: Node = null
	var best_amount: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("get_stored_amount"):
			continue
		var amount: int = int(zone.get_stored_amount(resource_type))
		if amount <= best_amount:
			continue
		best_amount = amount
		best_zone = zone
	return best_zone

func _withdraw_from_stockpiles_for_supply(resource_type: StringName, amount: int) -> int:
	var remain: int = maxi(0, amount)
	if remain <= 0:
		return 0
	var removed_total: int = 0
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if remain <= 0:
			break
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("remove_resource"):
			continue
		var removed: int = int(zone.remove_resource(resource_type, remain))
		if removed <= 0:
			continue
		removed_total += removed
		remain -= removed
	if removed_total > 0:
		resource_stock[resource_type] = maxi(0, int(resource_stock.get(resource_type, 0)) - removed_total)
		hud.set_resource_stock(resource_stock)
	return removed_total

func _consume_stockpile_by_delta(before_stock: Dictionary, after_stock: Dictionary) -> void:
	for key_any in before_stock.keys():
		var key: StringName = StringName(key_any)
		var before_amount: int = int(before_stock.get(key, 0))
		var after_amount: int = int(after_stock.get(key, 0))
		var used: int = maxi(0, before_amount - after_amount)
		if used > 0:
			_consume_from_stockpiles(key, used)

func _consume_resource_stock(resource_type: StringName, amount: int) -> bool:
	var have: int = int(resource_stock.get(resource_type, 0))
	if have < amount:
		return false
	resource_stock[resource_type] = have - amount
	_consume_from_stockpiles(resource_type, amount)
	return true

func _consume_from_stockpiles(resource_type: StringName, amount: int) -> void:
	var remain: int = amount
	if remain <= 0:
		return
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if remain <= 0:
			break
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("remove_resource"):
			continue
		var removed: int = int(zone.remove_resource(resource_type, remain))
		remain -= maxi(0, removed)

func _reconcile_stockpile_totals_with_resource_stock() -> void:
	var zones: Array = get_tree().get_nodes_in_group("stockpile_zones")
	if zones.is_empty():
		return
	for key_any in resource_stock.keys():
		var resource_type: StringName = StringName(key_any)
		var desired: int = int(resource_stock.get(resource_type, 0))
		var zone_total: int = 0
		for zone in zones:
			if zone == null or not is_instance_valid(zone):
				continue
			if not zone.has_method("get_stored_amount"):
				continue
			zone_total += int(zone.get_stored_amount(resource_type))
		var excess: int = zone_total - desired
		if excess > 0:
			_consume_from_stockpiles(resource_type, excess)

func _request_designated_resource_jobs() -> void:
	job_system.request_designated_gather_jobs(get_tree().get_nodes_in_group("gatherables"))
	job_system.request_designated_hunt_jobs(get_tree().get_nodes_in_group("huntables"))

func _refresh_designation_ui() -> void:
	if selected_designation_target == null or not is_instance_valid(selected_designation_target):
		hud.set_designation_panel_visible(false)
		return
	var enabled: bool = false
	if selected_designation_target.has_method("is_designated"):
		enabled = bool(selected_designation_target.is_designated())
	var title: String = String(selected_designation_target.get("display_name"))
	if title.is_empty():
		title = String(selected_designation_target.name)
	var kind: String = "채집"
	if selected_designation_target.is_in_group("huntables"):
		kind = "사냥"
	hud.set_designation_target_preview(title, enabled, kind)

func _refresh_bed_assign_ui() -> void:
	if selected_bed_node == null or not is_instance_valid(selected_bed_node):
		hud.set_bed_assignment_visible(false)
		return
	var options: Array = [{"id": 0, "name": "미배정"}]
	for i in range(colonists.size()):
		var c: Node = colonists[i]
		if c == null or not is_instance_valid(c):
			continue
		options.append({
			"id": c.get_instance_id(),
			"name": c.name
		})
	var selected_id: int = int(selected_bed_node.get_meta("assigned_colonist_id"))
	hud.set_bed_assignment_visible(true)
	hud.set_bed_assignment_options(options, selected_id)

func _on_bed_assignee_changed(colonist_id: int) -> void:
	if selected_bed_node == null or not is_instance_valid(selected_bed_node):
		return
	selected_bed_node.set_meta("assigned_colonist_id", colonist_id)
	var owner_name: String = "미배정"
	if colonist_id != 0:
		for c in colonists:
			if c != null and is_instance_valid(c) and c.get_instance_id() == colonist_id:
				owner_name = c.name
				break
	for child in selected_bed_node.get_children():
		if child is Label:
			child.text = "Bed (%s)" % owner_name
			break
	_apply_passive_item_bonuses()

func _on_bed_auto_assign_requested() -> void:
	if selected_bed_node == null or not is_instance_valid(selected_bed_node):
		return
	var assigned_ids: Dictionary = {}
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		if node.get_meta("building_id") != &"InstalledBed":
			continue
		var owner_id: int = int(node.get_meta("assigned_colonist_id"))
		if owner_id != 0:
			assigned_ids[owner_id] = true
	var picked_id: int = 0
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		var cid: int = c.get_instance_id()
		if assigned_ids.has(cid):
			continue
		picked_id = cid
		break
	_on_bed_assignee_changed(picked_id)
	_refresh_bed_assign_ui()

func _on_mouse_mode_cycle_requested() -> void:
	match current_action:
		&"Interact":
			_on_action_changed(&"DragGather")
		&"DragGather":
			_on_action_changed(&"StockpileZone")
		_:
			_on_action_changed(&"Interact")

func _on_clear_state_requested() -> void:
	_clear_pending_placement()
	_on_action_changed(&"Interact")
	_clear_selected_object()

func _on_context_action_requested(action_id: StringName) -> void:
	match action_id:
		&"Gather":
			var gather_obj: Object = instance_from_id(_context_gather_target_id)
			if gather_obj != null and is_instance_valid(gather_obj):
				if gather_obj.has_method("set_designated"):
					gather_obj.set_designated(true)
				var assigned_to: int = 0
				if not selected_colonists.is_empty():
					assigned_to = selected_colonists[0].get_instance_id()
					if selected_colonists[0].has_method("cancel_current_job"):
						selected_colonists[0].cancel_current_job()
				job_system.queue_gather_job(gather_obj, assigned_to)
		&"Workstation":
			if _context_workstation_id != &"":
				_activate_workstation(_context_workstation_id)
				if workstation_lookup.has(_context_workstation_id):
					var ws: Resource = workstation_lookup[_context_workstation_id]
					var work_pos: Vector2 = _find_workstation_pos(ws.linked_building_id)
					if work_pos != Vector2.INF:
						_issue_selected_move_command(work_pos)
	_context_gather_target_id = 0
	_context_workstation_id = &""

func _on_designation_toggle_requested() -> void:
	if selected_designation_target == null or not is_instance_valid(selected_designation_target):
		return
	if not selected_designation_target.has_method("is_designated") or not selected_designation_target.has_method("set_designated"):
		return
	var next_state: bool = not bool(selected_designation_target.is_designated())
	selected_designation_target.set_designated(next_state)
	if next_state:
		if selected_designation_target.is_in_group("gatherables"):
			job_system.queue_gather_job(selected_designation_target)
		elif selected_designation_target.is_in_group("huntables"):
			job_system.queue_hunt_job(selected_designation_target)
	_refresh_designation_ui()

func _on_outfit_mode_changed(mode: StringName) -> void:
	if mode != &"Work" and mode != &"Combat":
		return
	_outfit_mode = mode
	hud.set_outfit_mode(_outfit_mode)
	_apply_passive_item_bonuses()

func _on_colonist_died(_colonist: Node) -> void:
	_prune_colonists()

func _prune_colonists() -> void:
	var alive: Array = []
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		if c.has_method("is_dead") and bool(c.is_dead()):
			continue
		alive.append(c)
	colonists = alive
	var selected_alive: Array = []
	for c in selected_colonists:
		if c != null and is_instance_valid(c):
			selected_alive.append(c)
	selected_colonists = selected_alive

func _update_raid_state(delta: float) -> void:
	if _game_paused:
		return
	match _raid_state:
		&"Idle", &"Resolved":
			pass
		&"Warning":
			_raid_warning_timer = maxf(0.0, _raid_warning_timer - delta)
			if _raid_warning_timer <= 0.0:
				_start_raid_wave()
		&"Active":
			var raiders_alive: int = _get_alive_raiders().size()
			if raiders_alive <= 0:
				_resolve_raid(true)
			elif colonists.is_empty():
				_resolve_raid(false)

func _start_raid_warning() -> void:
	_raid_state = &"Warning"
	_raid_warning_timer = 18.0
	_raid_wave_size = maxi(2, 2 + int(floor(_elapsed_game_seconds / 120.0)))

func _start_raid_wave() -> void:
	_raid_state = &"Active"
	_raid_warning_timer = 0.0
	_spawn_raiders(_raid_wave_size)

func _resolve_raid(_colony_survived: bool) -> void:
	_raid_state = &"Resolved"

func _on_raid_test_warning_requested() -> void:
	if _raid_state == &"Warning" or _raid_state == &"Active":
		return
	if not _get_alive_raiders().is_empty():
		return
	_start_raid_warning()

func _spawn_raiders(count: int) -> void:
	if count <= 0:
		return
	var center: Vector2 = WORLD_SIZE * 0.5
	for _i in range(count):
		var raider: Node2D = RAIDER_SCENE.instantiate()
		raider.global_position = _random_edge_spawn(140.0)
		if raider.has_method("look_at"):
			raider.look_at(center)
		if raider.has_signal("died"):
			raider.died.connect(_on_raider_died)
		units_root.add_child(raider)

func _on_raider_died(_raider: Node) -> void:
	if _raid_state == &"Active" and _get_alive_raiders().is_empty():
		_resolve_raid(true)

func _get_alive_raiders() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("raiders"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		out.append(node)
	return out

func _random_edge_spawn(margin: float) -> Vector2:
	var edge: int = randi_range(0, 3)
	match edge:
		0:
			return Vector2(randf_range(margin, WORLD_SIZE.x - margin), margin)
		1:
			return Vector2(WORLD_SIZE.x - margin, randf_range(margin, WORLD_SIZE.y - margin))
		2:
			return Vector2(randf_range(margin, WORLD_SIZE.x - margin), WORLD_SIZE.y - margin)
		_:
			return Vector2(margin, randf_range(margin, WORLD_SIZE.y - margin))

func _apply_passive_item_bonuses() -> void:
	var alive_ids: Dictionary = {}
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		alive_ids[c.get_instance_id()] = true
	if _outfit_mode == &"Combat":
		_sync_equipped_map(_equipped_top_ids, int(resource_stock.get(&"CombatTop", 0)), alive_ids)
		_sync_equipped_map(_equipped_bottom_ids, int(resource_stock.get(&"CombatBottom", 0)), alive_ids)
		_sync_equipped_map(_equipped_hat_ids, int(resource_stock.get(&"CombatHat", 0)), alive_ids)
	else:
		_sync_equipped_map(_equipped_top_ids, int(resource_stock.get(&"GatherTop", 0)), alive_ids)
		_sync_equipped_map(_equipped_bottom_ids, int(resource_stock.get(&"GatherBottom", 0)), alive_ids)
		_sync_equipped_map(_equipped_hat_ids, int(resource_stock.get(&"StrawHat", 0)), alive_ids)
	_rebuild_weapon_assignments(alive_ids)
	var assigned_bed_map: Dictionary = {}
	for node in get_tree().get_nodes_in_group("structures"):
		if node != null and is_instance_valid(node) and node.has_meta("building_id"):
			if node.get_meta("building_id") == &"InstalledBed":
				var owner_id: int = int(node.get_meta("assigned_colonist_id"))
				if owner_id != 0:
					assigned_bed_map[owner_id] = true
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var cid: int = colonist.get_instance_id()
		var has_top: bool = _equipped_top_ids.has(cid)
		var has_bottom: bool = _equipped_bottom_ids.has(cid)
		var has_hat: bool = _equipped_hat_ids.has(cid)
		var weapon_id: StringName = StringName(_equipped_weapon_kind.get(cid, &""))
		var has_weapon: bool = weapon_id != &""
		var has_any_apparel: bool = has_top or has_bottom or has_hat
		if colonist.has_method("set_wearing_clothes"):
			colonist.set_wearing_clothes(has_any_apparel)
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots({
				&"Top": (&"CombatTop" if _outfit_mode == &"Combat" else &"GatherTop") if has_top else &"",
				&"Bottom": (&"CombatBottom" if _outfit_mode == &"Combat" else &"GatherBottom") if has_bottom else &"",
				&"Hat": (&"CombatHat" if _outfit_mode == &"Combat" else &"StrawHat") if has_hat else &"",
				&"Weapon": weapon_id if has_weapon else &""
			})
		var melee_attack: float = float(colonist.stats.base_melee_attack)
		var ranged_attack: float = float(colonist.stats.base_ranged_attack)
		var armor_pen: float = float(colonist.stats.base_armor_penetration)
		var defense: float = float(colonist.stats.base_defense)
		var accuracy_bonus: float = 0.0
		if weapon_id == &"Sword":
			melee_attack += 8.0
			armor_pen += 2.0
		elif weapon_id == &"Bow":
			ranged_attack += 7.0
			accuracy_bonus += 0.08
		elif weapon_id == &"Weapon":
			melee_attack += 4.0
			armor_pen += 1.0
		if _outfit_mode == &"Combat" and has_any_apparel:
			defense += 2.5
		if colonist.has_method("set_combat_profile"):
			colonist.set_combat_profile({
				"base_hit": float(colonist.stats.base_hit_chance),
				"defense": defense,
				"melee_attack": melee_attack,
				"ranged_attack": ranged_attack,
				"armor_penetration": armor_pen,
				"melee_range": float(colonist.stats.melee_range),
				"ranged_range": float(colonist.stats.ranged_range) + (36.0 if weapon_id == &"Bow" else 0.0),
				"attack_cooldown_sec": maxf(0.25, float(colonist.stats.attack_cooldown_sec) - (0.08 if weapon_id == &"Sword" else 0.0)),
				"accuracy_bonus": accuracy_bonus,
				"weapon_mode": (&"Ranged" if weapon_id == &"Bow" else &"Melee")
			})
		if colonist.has_method("set_gather_speed_multiplier"):
			colonist.set_gather_speed_multiplier(1.2 if has_any_apparel else 1.0)
		if colonist.has_method("set_rest_recover_multiplier"):
			var rest_mult: float = 1.5 if assigned_bed_map.has(colonist.get_instance_id()) else 1.0
			colonist.set_rest_recover_multiplier(rest_mult)

func _sync_equipped_map(equipped_map: Dictionary, max_count: int, alive_ids: Dictionary) -> void:
	for cid in equipped_map.keys():
		if not alive_ids.has(cid):
			equipped_map.erase(cid)
	var kept: int = 0
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		var cid: int = c.get_instance_id()
		if equipped_map.has(cid) and kept < max_count:
			kept += 1
		else:
			equipped_map.erase(cid)
	for c in colonists:
		if kept >= max_count:
			break
		if c == null or not is_instance_valid(c):
			continue
		var cid: int = c.get_instance_id()
		if not equipped_map.has(cid):
			equipped_map[cid] = true
			kept += 1

func _rebuild_weapon_assignments(alive_ids: Dictionary) -> void:
	for cid in _equipped_weapon_kind.keys():
		if not alive_ids.has(cid):
			_equipped_weapon_kind.erase(cid)
	var wanted: Array[StringName] = []
	if _outfit_mode == &"Combat":
		for _i in range(int(resource_stock.get(&"Bow", 0))):
			wanted.append(&"Bow")
		for _i in range(int(resource_stock.get(&"Sword", 0))):
			wanted.append(&"Sword")
	for _i in range(int(resource_stock.get(&"Weapon", 0))):
		wanted.append(&"Weapon")
	var next_map: Dictionary = {}
	var idx: int = 0
	for colonist in colonists:
		if idx >= wanted.size():
			break
		if colonist == null or not is_instance_valid(colonist):
			continue
		var cid: int = colonist.get_instance_id()
		if not alive_ids.has(cid):
			continue
		next_map[cid] = wanted[idx]
		idx += 1
	_equipped_weapon_kind = next_map
	_equipped_weapon_ids.clear()
	for cid in _equipped_weapon_kind.keys():
		_equipped_weapon_ids[cid] = true

func _clear_pending_placement() -> void:
	pending_building_id = &""
	pending_install_item = &""
	pending_install_drop_id = 0
	selected_designation_target = null
	selected_stockpile_zone = null
	selected_bed_node = null
	_clear_selected_object()
	hud.set_selected_building(&"")
	hud.set_designation_panel_visible(false)
	hud.set_bed_assignment_visible(false)
	hud.hide_context_action_button()

func _clear_selected_object() -> void:
	_selected_object_kind = &""
	_selected_object_resource = &""
	_selected_object_zone = null

func _find_stockpile_item_at(world_pos: Vector2) -> Dictionary:
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("get_resource_at_point"):
			continue
		var resource_type: StringName = zone.get_resource_at_point(world_pos)
		if resource_type == &"":
			continue
		return {
			"zone": zone,
			"resource_type": resource_type
		}
	return {}

func _on_selected_object_action_requested(action_id: StringName) -> void:
	if action_id == &"PlaceBedFromStockpile":
		if _selected_object_kind != &"StockpileItem" or _selected_object_resource != &"Bed":
			return
		if _selected_object_zone == null or not is_instance_valid(_selected_object_zone):
			return
		if not _selected_object_zone.has_method("remove_resource"):
			return
		var removed: int = int(_selected_object_zone.remove_resource(&"Bed", 1))
		if removed <= 0:
			return
		resource_stock[&"Bed"] = maxi(0, int(resource_stock.get(&"Bed", 0)) - removed)
		_clear_selected_object()
		selected_stockpile_zone = null
		pending_install_item = &"Bed"
		pending_install_drop_id = -1
		hud.set_resource_stock(resource_stock)
		hud.set_active_action(&"InstallBed")
		hud.set_selected_status_visible(false)

func _handle_user_right_click(event: InputEventMouseButton) -> void:
	var world_pos: Vector2 = world_root.get_global_mouse_position()
	if not selected_colonists.is_empty():
		var gatherable: Node = _find_gatherable_near(world_pos, 48.0)
		if gatherable != null:
			_context_gather_target_id = gatherable.get_instance_id()
			_context_workstation_id = &""
			hud.show_context_action_button(&"Gather", "채집하기", event.position)
			return
		var ws_id: StringName = _find_workstation_id_near(world_pos, 56.0)
		if ws_id != &"":
			_context_workstation_id = ws_id
			_context_gather_target_id = 0
			hud.show_context_action_button(&"Workstation", "작업하기", event.position)
			return
		_issue_selected_move_command(world_pos)
		return
	_clear_pending_placement()
	_on_action_changed(&"Interact")

func _issue_selected_move_command(target_pos: Vector2) -> void:
	for colonist in selected_colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		job_system.issue_immediate_move(colonist, target_pos)

func _spawn_resource_drop(resource_type: StringName, amount: int, world_pos: Vector2) -> Node:
	if amount <= 0:
		return null
	var drop := RESOURCE_DROP_SCENE.instantiate()
	drop.global_position = world_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	world_root.add_child(drop)
	if drop.has_method("setup_drop"):
		drop.setup_drop(resource_type, amount)
	return drop

func _build_workstation_position_map() -> Dictionary:
	var out: Dictionary = {}
	for ws_id in workstation_lookup.keys():
		var ws: Resource = workstation_lookup[ws_id]
		out[ws_id] = _find_workstation_pos(ws.linked_building_id)
	return out

func _filter_recipes_for_workstation(workstation_id: StringName) -> Array:
	var out: Array = []
	if workstation_lookup.has(workstation_id):
		var ws: Resource = workstation_lookup[workstation_id]
		for recipe_id in ws.recipe_ids:
			if recipe_lookup.has(recipe_id):
				out.append(recipe_lookup[recipe_id])
		out.sort_custom(func(a, b): return String(a.id) < String(b.id))
		return out
	for recipe_id in recipe_lookup.keys():
		var recipe: Resource = recipe_lookup[recipe_id]
		if recipe.workstation_id == workstation_id:
			out.append(recipe)
	out.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return out

func _select_stockpile_zone_near(world_pos: Vector2) -> void:
	selected_stockpile_zone = _find_stockpile_zone_near(world_pos, 40.0)
	_refresh_stockpile_filter_ui()

func _find_stockpile_zone_near(world_pos: Vector2, radius: float) -> Node:
	for zone in get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.global_position.distance_to(world_pos) <= radius:
			return zone
	return null

func _refresh_stockpile_filter_ui() -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		hud.set_stockpile_filter_state(false, 0, {}, 0, {})
		return
	if not selected_stockpile_zone.has_method("get_filter_snapshot"):
		hud.set_stockpile_filter_state(false, 0, {}, 0, {})
		return
	var snapshot: Dictionary = selected_stockpile_zone.get_filter_snapshot()
	hud.set_stockpile_filter_state(
		true,
		int(snapshot.get("mode", 0)),
		snapshot.get("items", {}),
		int(snapshot.get("priority", 0)),
		snapshot.get("limits", {})
	)

func _process_camera(delta: float) -> void:
	var key_vec: Vector2 = Vector2.ZERO
	if _is_left_move_pressed():
		key_vec.x -= 1.0
	if _is_right_move_pressed():
		key_vec.x += 1.0
	if _is_up_move_pressed():
		key_vec.y -= 1.0
	if _is_down_move_pressed():
		key_vec.y += 1.0
	var edge_vec: Vector2 = Vector2.ZERO
	if not _middle_drag_camera:
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var viewport_size: Vector2 = get_viewport_rect().size
		if mouse_pos.x <= EDGE_SCROLL_MARGIN:
			edge_vec.x -= 1.0
		elif mouse_pos.x >= viewport_size.x - EDGE_SCROLL_MARGIN:
			edge_vec.x += 1.0
		if mouse_pos.y <= EDGE_SCROLL_MARGIN:
			edge_vec.y -= 1.0
		elif mouse_pos.y >= viewport_size.y - EDGE_SCROLL_MARGIN:
			edge_vec.y += 1.0
	var move_vec: Vector2 = Vector2.ZERO
	if key_vec != Vector2.ZERO:
		move_vec += key_vec.normalized() * camera_speed
	if edge_vec != Vector2.ZERO:
		move_vec += edge_vec.normalized() * EDGE_SCROLL_SPEED
	if move_vec != Vector2.ZERO:
		camera.global_position += move_vec * delta
	_clamp_camera()

func _get_camera_delta(frame_delta: float) -> float:
	if not _game_paused and frame_delta > 0.0:
		_last_camera_ticks_usec = Time.get_ticks_usec()
		return frame_delta
	var now_usec: int = Time.get_ticks_usec()
	if _last_camera_ticks_usec <= 0:
		_last_camera_ticks_usec = now_usec
		return 0.0
	var real_delta: float = float(now_usec - _last_camera_ticks_usec) / 1000000.0
	_last_camera_ticks_usec = now_usec
	return clampf(real_delta, 0.0, 0.1)

func _is_left_move_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)

func _is_right_move_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)

func _is_up_move_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)

func _is_down_move_pressed() -> bool:
	return Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)

func _clamp_camera() -> void:
	var view_size: Vector2 = get_viewport_rect().size * camera.zoom
	var half: Vector2 = view_size * 0.5
	var min_x: float = half.x
	var max_x: float = WORLD_SIZE.x - half.x
	var min_y: float = half.y
	var max_y: float = WORLD_SIZE.y - half.y
	if min_x > max_x:
		min_x = WORLD_SIZE.x * 0.5
		max_x = min_x
	if min_y > max_y:
		min_y = WORLD_SIZE.y * 0.5
		max_y = min_y
	camera.global_position.x = clampf(camera.global_position.x, min_x, max_x)
	camera.global_position.y = clampf(camera.global_position.y, min_y, max_y)

func _set_camera_zoom(value: float) -> void:
	var clamped_zoom: float = clampf(value, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(clamped_zoom, clamped_zoom)
	_clamp_camera()

func _set_game_speed(scale: float) -> void:
	_speed_scale = clampf(scale, 1.0, 4.0)
	_game_paused = false
	_apply_time_scale()

func _apply_time_scale() -> void:
	Engine.time_scale = 0.0 if _game_paused else _speed_scale
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)

func _configure_world_bounds() -> void:
	var p0: Vector2 = Vector2.ZERO
	var p1: Vector2 = Vector2(WORLD_SIZE.x, 0.0)
	var p2: Vector2 = WORLD_SIZE
	var p3: Vector2 = Vector2(0.0, WORLD_SIZE.y)
	var ground: Polygon2D = world_root.get_node_or_null("Ground")
	if ground != null:
		ground.polygon = PackedVector2Array([p0, p1, p2, p3])
	var nav_region: NavigationRegion2D = world_root.get_node_or_null("NavigationRegion2D")
	if nav_region != null:
		var nav_poly: NavigationPolygon = NavigationPolygon.new()
		nav_poly.vertices = PackedVector2Array([p0, p1, p2, p3])
		nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))
		nav_region.navigation_polygon = nav_poly
	camera.global_position = WORLD_SIZE * 0.5

func _randomize_world_spawns() -> void:
	_clear_group_nodes(&"gatherables")
	_clear_group_nodes(&"huntables")
	_spawn_random_gatherables(&"Wood", "Tree", Color(0.27, 0.63, 0.32, 1.0), 26, 70, 130, 10)
	_spawn_random_gatherables(&"Stone", "Stone", Color(0.56, 0.58, 0.62, 1.0), 20, 90, 150, 8)
	_spawn_random_gatherables(&"Steel", "Steel", Color(0.6, 0.66, 0.78, 1.0), 14, 110, 170, 7)
	_spawn_random_gatherables(&"FoodRaw", "Berry", Color(0.82, 0.3, 0.5, 1.0), 22, 70, 120, 9)
	_spawn_random_huntables("Deer", Color(0.76, 0.62, 0.44, 1.0), 10, 55, 75, 28, 40)
	_spawn_random_huntables("Boar", Color(0.62, 0.47, 0.33, 1.0), 8, 70, 95, 32, 48)

func _clear_group_nodes(group_name: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if node == null or not is_instance_valid(node):
			continue
		node.queue_free()

func _spawn_random_gatherables(resource_type: StringName, display_name: String, tint: Color, count: int, min_amount: int, max_amount: int, gather_speed: int) -> void:
	for _i in range(count):
		var node: Node2D = GATHERABLE_SCENE.instantiate()
		node.global_position = _random_world_position(240.0)
		node.set("resource_type", resource_type)
		node.set("display_name", display_name)
		node.set("max_amount", randi_range(min_amount, max_amount))
		node.set("gather_per_tick", maxi(3, gather_speed + randi_range(-2, 2)))
		node.set("tint", tint)
		world_root.add_child(node)

func _spawn_random_huntables(display_name: String, tint: Color, count: int, min_hp: int, max_hp: int, min_meat: int, max_meat: int) -> void:
	for _i in range(count):
		var node: Node2D = HUNTABLE_SCENE.instantiate()
		node.global_position = _random_world_position(260.0)
		node.set("display_name", display_name)
		node.set("max_health", randi_range(min_hp, max_hp))
		node.set("meat_type", &"FoodRaw")
		node.set("meat_yield", randi_range(min_meat, max_meat))
		node.set("hunt_damage_per_tick", 25)
		node.set("tint", tint)
		world_root.add_child(node)

func _random_world_position(margin: float) -> Vector2:
	return Vector2(
		randf_range(margin, WORLD_SIZE.x - margin),
		randf_range(margin, WORLD_SIZE.y - margin)
	)

func _load_building_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(BUILDING_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [BUILDING_DEF_DIR, file_name]
			var def: Resource = load(path)
			if def != null:
				defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	defs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return defs

func _load_recipe_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(RECIPE_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [RECIPE_DEF_DIR, file_name]
			var def: Resource = load(path)
			if def != null:
				defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	defs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return defs

func _load_workstation_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(WORKSTATION_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [WORKSTATION_DEF_DIR, file_name]
			var def: Resource = load(path)
			if def != null:
				defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	defs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return defs

func _find_workstation_pos(building_id: StringName) -> Vector2:
	for node in get_tree().get_nodes_in_group("structures"):
		if node != null and is_instance_valid(node) and node.has_meta("building_id"):
			if node.get_meta("building_id") == building_id:
				return node.global_position
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if site.complete and site.building_id == building_id:
			return site.global_position
	return Vector2.INF

func _find_workstation_id_near(world_pos: Vector2, radius: float) -> StringName:
	var best_id: StringName = &""
	var best_dist: float = radius
	for ws_id in workstation_lookup.keys():
		var ws: Resource = workstation_lookup[ws_id]
		var pos: Vector2 = _find_workstation_pos(ws.linked_building_id)
		if pos == Vector2.INF:
			continue
		var dist: float = pos.distance_to(world_pos)
		if dist <= best_dist:
			best_dist = dist
			best_id = ws.id
	return best_id

func _activate_workstation(workstation_id: StringName) -> void:
	if workstation_id == &"":
		hud.set_craft_panel_visible(false)
		return
	selected_workstation_id = workstation_id
	hud.set_selected_workstation(workstation_id)
	hud.set_recipe_catalog(_filter_recipes_for_workstation(workstation_id))
	hud.set_craft_panel_visible(true, _get_workstation_display_name(workstation_id))

func _get_workstation_display_name(workstation_id: StringName) -> String:
	if workstation_lookup.has(workstation_id):
		var ws: Resource = workstation_lookup[workstation_id]
		return ws.display_name
	return String(workstation_id)
