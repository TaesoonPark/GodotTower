extends Node2D

const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
const HUNTABLE_SCENE: PackedScene = preload("res://scenes/world/Huntable.tscn")
const WORKSTATION_DEPOT_SCRIPT: Script = preload("res://scripts/core/WorkstationDepot.gd")
const BUILDING_DEF_DIR := "res://data/buildings"
const RECIPE_DEF_DIR := "res://data/recipes"
const WORKSTATION_DEF_DIR := "res://data/workstations"
const CROP_DEF_DIR := "res://data/crops"
const RESEARCH_DEF_DIR := "res://data/research"
const RESOURCE_DROP_SCENE: PackedScene = preload("res://scenes/world/ResourceDrop.tscn")
const WORLD_SIZE: Vector2 = Vector2(7680.0, 4320.0)
const TILE_SIZE: float = 40.0
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
	&"Wood": 120,
	&"Stone": 120,
	&"Steel": 60,
	&"FoodRaw": 40,
	&"Meal": 20,
	&"Bed": 0,
	&"GatherTop": 0,
	&"GatherBottom": 0,
	&"StrawHat": 0,
	&"Weapon": 0,
	&"CombatTop": 4,
	&"CombatBottom": 4,
	&"CombatHat": 4,
	&"Sword": 0,
	&"Bow": 4
}
var _free_build_allowance: Dictionary = {
	&"Wall": 100,
	&"Gate": 8
}
var target_stock: Dictionary = {
	&"Wood": 80,
	&"Stone": 80,
	&"Steel": 40,
	&"FoodRaw": 40
}
var recipe_lookup: Dictionary = {}
var workstation_lookup: Dictionary = {}
var crop_lookup: Dictionary = {}
var research_lookup: Dictionary = {}
var _building_defs_all: Array = []
var _research_completed: Dictionary = {}
var _active_research_id: StringName = &""
var _active_research_points: float = 0.0
var _research_running: bool = false
var _farm_growth_multiplier: float = 1.0
var _combat_accuracy_bonus_from_research: float = 0.0
var selected_workstation_id: StringName = &""
var selected_stockpile_zone: Node = null
var selected_farm_zone: Node = null
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
var _outfit_mode: StringName = &"Combat"
var _equipped_weapon_kind: Dictionary = {}
var _raid_state: StringName = &"Idle"
var _raid_warning_timer: float = 0.0
var _raid_wave_size: int = 0
var _raid_wave_kind: StringName = &"RaiderOnly"
var _combat_tile_claims: Dictionary = {}
var _combat_rally_point: Vector2 = WORLD_SIZE * 0.5
var _rally_flag_node: Node2D = null

func _ready() -> void:
	add_to_group("main_controller")
	randomize()
	_configure_world_bounds()
	_randomize_world_spawns()
	var building_defs: Array = _load_building_defs()
	var workstation_defs: Array = _load_workstation_defs()
	var recipe_defs: Array = _load_recipe_defs()
	var crop_defs: Array = _load_crop_defs()
	var research_defs: Array = _load_research_defs()
	_building_defs_all = building_defs.duplicate()
	for ws in workstation_defs:
		if ws != null:
			workstation_lookup[ws.id] = ws
	if not workstation_defs.is_empty():
		selected_workstation_id = workstation_defs[0].id
	for recipe in recipe_defs:
		if recipe != null:
			recipe_lookup[recipe.id] = recipe
	for crop_def in crop_defs:
		if crop_def != null:
			crop_lookup[crop_def.id] = crop_def
	for research_def in research_defs:
		if research_def != null:
			research_lookup[research_def.id] = research_def
	_spawn_initial_colonists()
	_set_combat_rally_point(_snap_to_tile(WORLD_SIZE * 0.5))
	_refresh_building_catalog()
	if input_controller != null and input_controller.has_method("set_grid_size"):
		input_controller.set_grid_size(TILE_SIZE)
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
	hud.drag_farm_mode_requested.connect(func(): _on_action_changed(&"FarmZone"))
	hud.rally_flag_mode_requested.connect(func(): _on_action_changed(&"SetRallyFlag"))
	hud.clear_state_requested.connect(_on_clear_state_requested)
	hud.context_action_requested.connect(_on_context_action_requested)
	hud.selected_object_action_requested.connect(_on_selected_object_action_requested)
	hud.outfit_mode_changed.connect(_on_outfit_mode_changed)
	hud.raid_test_warning_requested.connect(_on_raid_test_warning_requested)
	hud.bed_assignee_changed.connect(_on_bed_assignee_changed)
	hud.bed_auto_assign_requested.connect(_on_bed_auto_assign_requested)
	hud.research_project_changed.connect(_on_research_project_changed)
	hud.research_start_requested.connect(_on_research_start_requested)
	hud.set_workstation_catalog(workstation_defs)
	hud.set_selected_workstation(selected_workstation_id)
	hud.set_recipe_catalog(_filter_recipes_for_workstation(selected_workstation_id))
	hud.set_research_catalog(_get_research_catalog(), _active_research_id)
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
	hud.set_raid_state(_raid_state, _raid_warning_timer, _raid_wave_kind)
	hud.set_research_state(_active_research_id, _active_research_points, _active_research_required_points(), _research_completed)
	hud.set_designation_panel_visible(false)
	hud.set_bed_assignment_visible(false)
	hud.set_equipment_preview(null)
	_apply_time_scale()
	_clamp_camera()

func _process(delta: float) -> void:
	if input_controller != null and input_controller.dragging:
		queue_redraw()
	elif _has_demolish_queued_structure():
		queue_redraw()
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
	_update_farm_zones(delta)
	_update_defense_traps(delta)
	var rally_pos: Vector2 = _combat_rally_point if _outfit_mode == &"Combat" else Vector2.INF
	job_system.request_combat_jobs(colonists, _get_alive_raiders(), rally_pos, TILE_SIZE * 3.0)
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
	_refresh_structure_integrity()
	job_system.request_repair_jobs(_get_damaged_repairable_structures())
	job_system.request_craft_jobs(
		recipe_lookup,
		_build_workstation_slots_map(),
		colonists,
		Callable(self, "_can_start_recipe_at_workstation"),
		Callable(self, "_on_recipe_started_at_workstation")
	)
	job_system.request_research_jobs(
		colonists,
		_find_research_bench_pos(),
		_active_research_id if _research_running else &"",
		6.0
	)
	job_system.assign_jobs(colonists)
	_apply_combat_tile_occupancy()
	_reconcile_stockpile_totals_with_resource_stock()
	hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
	hud.set_raid_state(_raid_state, _raid_warning_timer, _raid_wave_kind)
	hud.set_research_state(_active_research_id, _active_research_points, _active_research_required_points(), _research_completed)
	_refresh_hud()

func _has_demolish_queued_structure() -> bool:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.get_meta("demolish_job_queued")):
			return true
	return false

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
	_draw_demolish_queued_outlines()
	if not input_controller.dragging:
		return
	var drag_start_world: Vector2 = _snap_to_tile(input_controller.drag_start)
	var drag_end_world: Vector2 = _snap_to_tile(world_root.get_global_mouse_position())
	var rect: Rect2 = Rect2(drag_start_world, drag_end_world - drag_start_world).abs()
	var fill_color := Color(0.3, 0.8, 1.0, 0.15)
	var border_color := Color(0.3, 0.8, 1.0)
	if current_action == &"StockpileZone":
		fill_color = Color(0.95, 0.75, 0.28, 0.18)
		border_color = Color(1.0, 0.82, 0.3)
	elif current_action == &"FarmZone":
		fill_color = Color(0.32, 0.82, 0.36, 0.18)
		border_color = Color(0.42, 0.93, 0.46, 1.0)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, border_color, false, 2.0)
	# Always show a green translucent command outline while dragging.
	draw_rect(rect.grow(1.0), Color(0.24, 0.96, 0.42, 0.55), false, 3.0)
	if pending_building_id != &"" and _can_drag_line_place(pending_building_id):
		var preview_tiles: Array[Vector2i] = _build_line_tiles_from_world(drag_start_world, drag_end_world)
		for tile in preview_tiles:
			var center: Vector2 = _tile_to_world(tile)
			var tile_rect := Rect2(center - Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5), Vector2(TILE_SIZE, TILE_SIZE))
			draw_rect(tile_rect, Color(0.35, 0.92, 0.4, 0.22), true)
			draw_rect(tile_rect, Color(0.42, 1.0, 0.5, 0.92), false, 2.0)

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
		c.global_position = _snap_to_tile(pos)
		if c.has_method("set_tile_size"):
			c.set_tile_size(TILE_SIZE)
		c.status_changed.connect(_on_colonist_status_changed)
		c.resource_harvested.connect(_on_resource_harvested)
		c.resource_delivered.connect(_on_resource_delivered)
		c.craft_completed.connect(_on_craft_completed)
		c.structure_demolished.connect(_on_structure_demolished)
		c.research_progressed.connect(_on_research_progressed)
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
	if current_action == &"SetRallyFlag":
		_set_combat_rally_point(world_pos)
		_on_action_changed(&"Interact")
		return
	hud.hide_context_action_button()
	selected_farm_zone = null
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
	if current_action == &"FarmZone":
		_clear_selected_object()
		selected_farm_zone = _find_farm_zone_near(world_pos, 48.0)
		_refresh_hud()
		hud.set_active_action(&"FarmZone")
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

	var research_bench: Node = _find_structure_by_building_near(world_pos, &"ResearchBench", 56.0)
	if research_bench != null:
		_clear_selected_object()
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_selected_object_kind = &"ResearchBench"
		_selected_object_zone = research_bench
		_selected_object_resource = &"ResearchBench"
		_refresh_hud()
		hud.set_active_action(&"ResearchBenchSelected")
		return

	var ws_id: StringName = _find_workstation_id_near(world_pos, 56.0)
	if ws_id != &"":
		_clear_selected_object()
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		var ws_node: Node = _find_workstation_node_near(world_pos, 56.0, ws_id)
		if workstation_lookup.has(ws_id):
			var ws_def: Resource = workstation_lookup[ws_id]
			if StringName(ws_def.linked_building_id) == &"ResearchBench":
				_selected_object_kind = &"ResearchBench"
				_selected_object_resource = ws_id
				_selected_object_zone = ws_node
		_activate_workstation(ws_id)
		_refresh_hud()
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

	var clicked_farm: Node = _find_farm_zone_near(world_pos, 40.0)
	if clicked_farm != null:
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_set_selected([])
		selected_farm_zone = clicked_farm
		_configure_farm_zone_catalog(selected_farm_zone)
		_selected_object_kind = &"FarmZone"
		_selected_object_zone = clicked_farm
		_selected_object_resource = &""
		_refresh_hud()
		hud.set_active_action(&"FarmZoneSelected")
		return
	else:
		selected_farm_zone = null

	if pending_install_item != &"":
		if _try_install_pending_item(world_pos):
			_clear_pending_placement()
		_refresh_hud()
		return

	if pending_building_id == &"Gate":
		var wall_site_target: Node = _find_build_site_near(world_pos, 28.0, &"Wall")
		if wall_site_target != null:
			_cancel_build_site(wall_site_target)
			_try_place_building_by_id(wall_site_target.global_position, &"Gate")
			_refresh_hud()
			return
		var wall_target: Node = _find_structure_by_building_near(world_pos, &"Wall", 32.0)
		if wall_target != null:
			_queue_demolish_structure(wall_target, &"Gate")
			_refresh_hud()
			return

	if pending_building_id != &"":
		_try_place_building_by_id(world_pos, pending_building_id)
		_refresh_hud()
		return

	var build_site_target: Node = _find_build_site_near(world_pos, 30.0)
	if build_site_target != null:
		_clear_selected_object()
		_set_selected([])
		_selected_object_kind = &"BuildSite"
		_selected_object_zone = build_site_target
		_selected_object_resource = StringName(build_site_target.get("building_id"))
		_refresh_hud()
		hud.set_active_action(&"BuildSiteSelected")
		return

	var structure_target: Node = _find_demolishable_structure_near(world_pos, 32.0)
	if structure_target != null:
		_clear_selected_object()
		_set_selected([])
		_selected_object_kind = &"Structure"
		_selected_object_zone = structure_target
		_selected_object_resource = StringName(structure_target.get_meta("building_id")) if structure_target.has_meta("building_id") else &"Structure"
		_refresh_hud()
		hud.set_active_action(&"StructureSelected")
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
	if pending_building_id != &"" and _can_drag_line_place(pending_building_id):
		var snapped_start: Vector2 = _snap_to_tile(start_pos)
		var snapped_end: Vector2 = _snap_to_tile(end_pos)
		_try_place_building_line_by_id(snapped_start, snapped_end, pending_building_id)
		queue_redraw()
		return
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
	if current_action == &"FarmZone":
		if build_system.place_farm_zone(rect):
			selected_farm_zone = _find_farm_zone_near(rect.get_center(), 96.0)
			_configure_farm_zone_catalog(selected_farm_zone)
		queue_redraw()
		return
	selected_stockpile_zone = null
	selected_farm_zone = null
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
	var farm_focus: Node = selected_farm_zone if selected_farm_zone != null and is_instance_valid(selected_farm_zone) else null
	var object_focus: bool = _selected_object_kind != &"" and _selected_object_zone != null and is_instance_valid(_selected_object_zone)
	hud.set_selected_status_visible(focus != null or stockpile_focus != null or farm_focus != null or object_focus)
	hud.set_needs_preview(focus)
	hud.set_priority_preview(focus)
	hud.set_current_job_preview(focus)
	hud.set_carry_capacity_preview(focus)
	hud.set_equipment_preview(focus)
	if focus != null:
		hud.set_stockpile_inventory_preview(null)
	elif farm_focus != null:
		var crop_name: String = "미선택"
		var crop_options: Array = []
		var selected_crop: StringName = &""
		if farm_focus.has_method("get_crop_display_name"):
			crop_name = String(farm_focus.get_crop_display_name())
		if farm_focus.has_method("get_crop_options"):
			crop_options = farm_focus.get_crop_options()
		if farm_focus.has_method("get_crop_type"):
			selected_crop = StringName(farm_focus.get_crop_type())
		hud.set_selected_object_preview(
			"Selected: Farm Zone",
			"Type: Farm Zone\nCrop: %s\nAction: 성숙 시 자동 수확" % crop_name,
			[{
				"type": &"crop_selector",
				"options": crop_options,
				"selected_id": selected_crop,
				"apply_action": &"SetFarmCrop",
				"apply_label": "작물 적용"
			}]
		)
	elif object_focus:
		if _selected_object_kind == &"ResearchBench":
			var options: Array = []
			var keys: Array = research_lookup.keys()
			keys.sort_custom(func(a, b): return String(a) < String(b))
			for key_any in keys:
				var key: StringName = StringName(key_any)
				var def: Resource = research_lookup[key]
				options.append({
					"id": key,
					"label": "%s (%.0f)" % [String(def.display_name), float(def.required_points)]
				})
			var progress_text: String = "없음"
			if _active_research_id != &"":
				progress_text = "%s %.0f / %.0f" % [
					String(_active_research_id),
					_active_research_points,
					_active_research_required_points()
				]
			hud.set_selected_object_preview(
				"Selected: Research Bench",
				"Type: Research Bench\n현재 연구: %s" % progress_text,
				[
					{
						"type": &"crop_selector",
						"options": options,
						"selected_id": _active_research_id,
						"apply_action": &"SetResearchProject",
						"apply_label": "연구 선택"
					},
					{"id": &"StartResearch", "label": "연구 시작"}
				]
			)
		elif _selected_object_kind == &"BuildSite":
			var bid_site: StringName = StringName(_selected_object_zone.get("building_id"))
			var work_need: float = float(_selected_object_zone.get("required_work"))
			var work_done: float = float(_selected_object_zone.get("work_progress"))
			hud.set_selected_object_preview(
				"Selected: Blueprint %s" % String(bid_site),
				"Type: Build Site\n진행도: %.1f / %.1f" % [work_done, work_need],
				[{"id": &"CancelBuildSite", "label": "건축 취소"}]
			)
		elif _selected_object_kind == &"Structure":
			var building_id: StringName = StringName(_selected_object_zone.get_meta("building_id")) if _selected_object_zone.has_meta("building_id") else &"Structure"
			var hp: float = float(_selected_object_zone.get_meta("structure_health")) if _selected_object_zone.has_meta("structure_health") else 0.0
			var max_hp: float = float(_selected_object_zone.get_meta("structure_max_health")) if _selected_object_zone.has_meta("structure_max_health") else hp
			var detail: String = "Type: Structure\nID: %s\n내구도: %.0f / %.0f" % [String(building_id), hp, max_hp]
			hud.set_selected_object_preview(
				"Selected: %s" % String(building_id),
				detail,
				[{"id": &"DemolishSelectedStructure", "label": "해체"}]
			)
		else:
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
	if action != &"FarmZone":
		selected_farm_zone = null

func _set_combat_rally_point(world_pos: Vector2) -> void:
	_combat_rally_point = _snap_to_tile(world_pos)
	if _rally_flag_node == null or not is_instance_valid(_rally_flag_node):
		_rally_flag_node = Node2D.new()
		_rally_flag_node.name = "RallyFlag"
		var pole := Sprite2D.new()
		var pole_img := Image.create(8, 32, false, Image.FORMAT_RGBA8)
		pole_img.fill(Color(0.78, 0.78, 0.78, 0.9))
		pole.texture = ImageTexture.create_from_image(pole_img)
		pole.position = Vector2(0.0, -16.0)
		_rally_flag_node.add_child(pole)
		var cloth := Sprite2D.new()
		var cloth_img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
		cloth_img.fill(Color(0.92, 0.36, 0.22, 0.9))
		cloth.texture = ImageTexture.create_from_image(cloth_img)
		cloth.position = Vector2(10.0, -24.0)
		_rally_flag_node.add_child(cloth)
		var label := Label.new()
		label.text = "집합 깃발"
		label.position = Vector2(-26.0, -46.0)
		_rally_flag_node.add_child(label)
		world_root.add_child(_rally_flag_node)
	_rally_flag_node.global_position = _combat_rally_point

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

func _find_structure_by_building_near(world_pos: Vector2, building_id: StringName, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		if StringName(node.get_meta("building_id")) != building_id:
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_build_site_near(world_pos: Vector2, radius: float, required_building_id: StringName = &"") -> Node:
	var best: Node = null
	var best_dist: float = radius
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var site_building_id: StringName = StringName(site.get("building_id"))
		if required_building_id != &"" and site_building_id != required_building_id:
			continue
		var d: float = site.global_position.distance_to(world_pos)
		if d > best_dist:
			continue
		best_dist = d
		best = site
	return best

func _cancel_build_site(site: Node) -> void:
	if site == null or not is_instance_valid(site):
		return
	if build_system != null and is_instance_valid(build_system) and build_system.has_method("cancel_build_site"):
		build_system.cancel_build_site(site)
		return
	if site.has_method("set_job_queued"):
		site.set_job_queued(false)
	site.queue_free()

func _find_demolishable_structure_near(world_pos: Vector2, radius: float) -> Node:
	var best: Node = null
	var best_dist: float = radius
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		var bid: StringName = StringName(node.get_meta("building_id"))
		if bid == &"InstalledBed" or bid == &"ResearchBench":
			continue
		if _is_workstation_building_id(bid):
			continue
		var d: float = node.global_position.distance_to(world_pos)
		if d > best_dist:
			continue
		best_dist = d
		best = node
	return best

func _is_workstation_building_id(building_id: StringName) -> bool:
	for ws_id_any in workstation_lookup.keys():
		var ws_id: StringName = StringName(ws_id_any)
		var ws: Resource = workstation_lookup.get(ws_id, null)
		if ws == null:
			continue
		if StringName(ws.linked_building_id) == building_id:
			return true
	return false

func _queue_demolish_structure(structure: Node, replace_building_id: StringName = &"") -> void:
	if structure == null or not is_instance_valid(structure):
		return
	var required_work: float = 30.0
	if structure.has_meta("required_work"):
		required_work = float(structure.get_meta("required_work"))
	var demolish_work: float = maxf(0.5, required_work / 3.0)
	job_system.queue_demolish_job(structure, demolish_work, replace_building_id)

func _draw_demolish_queued_outlines() -> void:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("demolish_job_queued")):
			continue
		var size: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(TILE_SIZE, TILE_SIZE)
		var rect := Rect2(node.global_position - size * 0.5, size)
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.22), true)
		draw_rect(rect, Color(1.0, 0.3, 0.3, 0.95), false, 2.0)

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

func _on_craft_completed(products: Dictionary, world_pos: Vector2, craft_slot_id: int = 0) -> void:
	for k in products.keys():
		var amount: int = int(products[k])
		if amount <= 0:
			continue
		_spawn_resource_drop(StringName(k), amount, world_pos)
	job_system.notify_craft_job_finished(craft_slot_id)

func _on_structure_demolished(world_pos: Vector2, replace_building_id: StringName) -> void:
	if replace_building_id == &"":
		return
	_try_place_building_by_id(world_pos, replace_building_id)

func _on_research_progressed(project_id: StringName, points: float) -> void:
	if project_id == &"" or points <= 0.0:
		return
	if project_id != _active_research_id:
		return
	_active_research_points += points
	var required: float = _active_research_required_points()
	if required <= 0.0:
		return
	if _active_research_points < required:
		return
	_research_completed[project_id] = true
	_apply_research_bonus(project_id)
	_active_research_points = 0.0
	_active_research_id = &""
	_research_running = false
	_refresh_building_catalog()
	hud.set_research_catalog(_get_research_catalog(), _active_research_id)

func _on_research_project_changed(project_id: StringName) -> void:
	if project_id == &"":
		return
	if project_id == _active_research_id:
		return
	_active_research_id = project_id
	_active_research_points = 0.0
	_research_running = false

func _on_research_start_requested() -> void:
	if _active_research_id == &"":
		return
	if bool(_research_completed.get(_active_research_id, false)):
		return
	_research_running = true

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
	var placed: bool = build_system.place_building(world_pos, as_blueprint)
	if placed and not as_blueprint:
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

func try_supply_build_site(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	if not (site_obj is Node):
		return false
	var site_node: Node = site_obj
	if site_node.has_method("requires_material_delivery") and not bool(site_node.requires_material_delivery()):
		return true
	var site_building_id: StringName = StringName(site_node.get("building_id"))
	if site_building_id != &"" and _consume_free_build_allowance(site_building_id):
		if site_node.has_method("mark_materials_delivered"):
			site_node.mark_materials_delivered()
		return true
	var build_cost: Dictionary = {}
	if site_node.has_method("get_build_cost"):
		build_cost = site_node.get_build_cost()
	if build_cost.is_empty():
		if site_node.has_method("mark_materials_delivered"):
			site_node.mark_materials_delivered()
		return true
	if not _can_afford_build_cost(build_cost):
		return false
	_consume_build_cost(build_cost)
	if site_node.has_method("mark_materials_delivered"):
		site_node.mark_materials_delivered()
	hud.set_resource_stock(resource_stock)
	return true

func _can_afford_build_cost(cost: Dictionary) -> bool:
	for key_any in cost.keys():
		var key: StringName = StringName(key_any)
		var need: int = int(cost[key_any])
		if int(resource_stock.get(key, 0)) < need:
			return false
	return true

func _consume_build_cost(cost: Dictionary) -> void:
	for key_any in cost.keys():
		var key: StringName = StringName(key_any)
		var need: int = int(cost[key_any])
		_consume_resource_stock(key, need)

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
	_raid_wave_kind = _pick_raid_wave_kind()

func _start_raid_wave() -> void:
	_raid_state = &"Active"
	_raid_warning_timer = 0.0
	match _raid_wave_kind:
		&"ZombieHorde":
			_spawn_zombies(_raid_wave_size + 1)
		&"Mixed":
			var zombie_count: int = maxi(1, int(round(_raid_wave_size * 0.55)))
			var raider_count: int = maxi(1, _raid_wave_size - zombie_count)
			_spawn_zombies(zombie_count)
			_spawn_raiders(raider_count)
		_:
			_spawn_raiders(_raid_wave_size)

func _resolve_raid(_colony_survived: bool) -> void:
	_raid_state = &"Resolved"
	if _colony_survived:
		_grant_raid_reward()

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
		raider.global_position = _snap_to_tile(_random_edge_spawn(140.0))
		if raider.has_method("set_tile_size"):
			raider.set_tile_size(TILE_SIZE)
		if raider.has_method("look_at"):
			raider.look_at(center)
		if raider.has_signal("died"):
			raider.died.connect(_on_raider_died)
		units_root.add_child(raider)

func _spawn_zombies(count: int) -> void:
	if count <= 0:
		return
	for _i in range(count):
		var zombie: Node2D = ZOMBIE_SCENE.instantiate()
		zombie.global_position = _snap_to_tile(_random_edge_spawn(120.0))
		if zombie.has_method("set_tile_size"):
			zombie.set_tile_size(TILE_SIZE)
		units_root.add_child(zombie)

func _pick_raid_wave_kind() -> StringName:
	var roll: float = randf()
	var tier: int = int(floor(_elapsed_game_seconds / 240.0))
	if tier <= 0:
		return &"RaiderOnly"
	if tier == 1:
		if roll < 0.5:
			return &"RaiderOnly"
		return &"ZombieHorde"
	if roll < 0.35:
		return &"RaiderOnly"
	if roll < 0.7:
		return &"ZombieHorde"
	return &"Mixed"

func _grant_raid_reward() -> void:
	var bonus_scale: int = maxi(1, _raid_wave_size)
	var food_amount: int = 2 + bonus_scale
	var wood_amount: int = 1 + int(floor(bonus_scale * 0.5))
	_spawn_resource_drop(&"FoodRaw", food_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(60.0, -40.0)))
	_spawn_resource_drop(&"Wood", wood_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(-50.0, -36.0)))

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
		accuracy_bonus += _combat_accuracy_bonus_from_research
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
	selected_farm_zone = null
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
	elif String(action_id).begins_with("SetFarmCrop:"):
		var target_zone: Node = null
		if selected_farm_zone != null and is_instance_valid(selected_farm_zone):
			target_zone = selected_farm_zone
		elif _selected_object_kind == &"FarmZone" and _selected_object_zone != null and is_instance_valid(_selected_object_zone):
			target_zone = _selected_object_zone
		if target_zone == null:
			return
		var prefix: String = "SetFarmCrop:"
		var raw: String = String(action_id)
		var crop_raw: String = raw.substr(prefix.length())
		var crop_id: StringName = StringName(crop_raw)
		if crop_id == &"":
			if target_zone.has_method("get_crop_options"):
				var options: Array = target_zone.get_crop_options()
				if not options.is_empty():
					crop_id = StringName(options[0].get("id", &""))
			if crop_id == &"":
				return
		_configure_farm_zone_catalog(target_zone)
		if target_zone.has_method("set_crop_type"):
			target_zone.set_crop_type(crop_id)
		selected_farm_zone = target_zone
		_selected_object_kind = &"FarmZone"
		_selected_object_zone = target_zone
		_refresh_hud()
	elif action_id == &"StartResearch":
		if _selected_object_kind != &"ResearchBench":
			return
		_on_research_start_requested()
		_refresh_hud()
	elif String(action_id).begins_with("SetResearchProject:"):
		if _selected_object_kind != &"ResearchBench":
			return
		var prefix: String = "SetResearchProject:"
		var raw: String = String(action_id)
		var project_raw: String = raw.substr(prefix.length())
		var project_id: StringName = StringName(project_raw)
		if project_id == &"":
			return
		_on_research_project_changed(project_id)
		_refresh_hud()
	elif action_id == &"DemolishSelectedStructure":
		if _selected_object_kind != &"Structure":
			return
		if _selected_object_zone == null or not is_instance_valid(_selected_object_zone):
			return
		_queue_demolish_structure(_selected_object_zone)
		_refresh_hud()
	elif action_id == &"CancelBuildSite":
		if _selected_object_kind != &"BuildSite":
			return
		if _selected_object_zone == null or not is_instance_valid(_selected_object_zone):
			return
		_cancel_build_site(_selected_object_zone)
		_clear_selected_object()
		_refresh_hud()

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
	var snapped_target: Vector2 = _snap_to_tile(target_pos)
	for colonist in selected_colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		job_system.issue_immediate_move(colonist, snapped_target)

func _spawn_resource_drop(resource_type: StringName, amount: int, world_pos: Vector2) -> Node:
	if amount <= 0:
		return null
	var drop := RESOURCE_DROP_SCENE.instantiate()
	drop.global_position = _snap_to_tile(world_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)))
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

func _build_workstation_slots_map() -> Dictionary:
	var out: Dictionary = {}
	for ws_id_any in workstation_lookup.keys():
		out[StringName(ws_id_any)] = []
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		var building_id: StringName = StringName(node.get_meta("building_id"))
		for ws_id_any in workstation_lookup.keys():
			var ws_id: StringName = StringName(ws_id_any)
			var ws: Resource = workstation_lookup[ws_id]
			if StringName(ws.linked_building_id) != building_id:
				continue
			var slots: Array = out.get(ws_id, [])
			slots.append({
				"slot_id": node.get_instance_id(),
				"pos": node.global_position
			})
			out[ws_id] = slots
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

func _refresh_building_catalog() -> void:
	var unlocked_defs: Array = []
	for def in _building_defs_all:
		if def == null:
			continue
		if _is_building_unlocked(def):
			unlocked_defs.append(def)
	build_system.configure(world_root, unlocked_defs)
	hud.set_building_catalog(unlocked_defs)
	if pending_building_id != &"":
		var still_exists: bool = false
		for def in unlocked_defs:
			if def.id == pending_building_id:
				still_exists = true
				break
		if not still_exists:
			pending_building_id = &""

func _is_building_unlocked(def: Resource) -> bool:
	if def == null:
		return false
	var required: StringName = StringName(def.required_research)
	if required == &"":
		return true
	return bool(_research_completed.get(required, false))

func _get_research_catalog() -> Array:
	var defs: Array = []
	var keys: Array = research_lookup.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		var key: StringName = StringName(key_any)
		defs.append(research_lookup[key])
	return defs

func _active_research_required_points() -> float:
	if _active_research_id == &"":
		return 0.0
	if not research_lookup.has(_active_research_id):
		return 0.0
	return float(research_lookup[_active_research_id].required_points)

func _apply_research_bonus(research_id: StringName) -> void:
	if not research_lookup.has(research_id):
		return
	var def: Resource = research_lookup[research_id]
	var bonus_type: StringName = StringName(def.bonus_type)
	var bonus_value: float = float(def.bonus_value)
	match bonus_type:
		&"FarmGrowthMultiplier":
			_farm_growth_multiplier = clampf(bonus_value, 0.3, 1.0)
		&"CombatAccuracy":
			_combat_accuracy_bonus_from_research = maxf(_combat_accuracy_bonus_from_research, bonus_value)
		_:
			pass

func _find_research_bench_pos() -> Vector2:
	var pos: Vector2 = _find_workstation_pos(&"ResearchBench")
	if pos != Vector2.INF:
		return pos
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		if StringName(node.get_meta("building_id")) == &"ResearchBench":
			return node.global_position
	return Vector2.INF

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

func _find_farm_zone_near(world_pos: Vector2, radius: float) -> Node:
	for zone in get_tree().get_nodes_in_group("farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("contains_point") and bool(zone.contains_point(world_pos)):
			return zone
		if zone.global_position.distance_to(world_pos) <= radius:
			return zone
	return null

func _update_farm_zones(delta: float) -> void:
	if _game_paused:
		return
	for zone in get_tree().get_nodes_in_group("farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		_configure_farm_zone_catalog(zone)
		if zone.has_method("tick_growth"):
			zone.tick_growth(delta)
		if zone.has_method("request_jobs"):
			zone.request_jobs(job_system)

func _configure_farm_zone_catalog(zone: Node) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	if zone.has_method("set_crop_catalog"):
		zone.set_crop_catalog(crop_lookup)
	if zone.has_method("set_growth_time_multiplier"):
		zone.set_growth_time_multiplier(_farm_growth_multiplier)

func _update_defense_traps(delta: float) -> void:
	if _game_paused:
		return
	var raiders: Array = _get_alive_raiders()
	for trap in get_tree().get_nodes_in_group("trap_structures"):
		if trap == null or not is_instance_valid(trap):
			continue
		var trap_damage: int = int(trap.get_meta("trap_damage")) if trap.has_meta("trap_damage") else 0
		if trap_damage <= 0:
			continue
		var cooldown_left: float = float(trap.get_meta("trap_cooldown_left")) if trap.has_meta("trap_cooldown_left") else 0.0
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			trap.set_meta("trap_cooldown_left", cooldown_left)
		if cooldown_left > 0.0:
			continue
		var target: Node = null
		var best_dist: float = 36.0
		for raider in raiders:
			if raider == null or not is_instance_valid(raider):
				continue
			var dist: float = trap.global_position.distance_to(raider.global_position)
			if dist <= best_dist:
				best_dist = dist
				target = raider
		if target == null:
			continue
		if target.has_method("apply_combat_damage"):
			target.apply_combat_damage(trap_damage)
		var cooldown: float = float(trap.get_meta("trap_cooldown_sec")) if trap.has_meta("trap_cooldown_sec") else 3.0
		trap.set_meta("trap_cooldown_left", maxf(0.3, cooldown))
		var charges: int = int(trap.get_meta("trap_charges")) if trap.has_meta("trap_charges") else 0
		if charges > 0:
			charges -= 1
			trap.set_meta("trap_charges", charges)
			if charges <= 0:
				trap.queue_free()

func _refresh_structure_integrity() -> void:
	for node in get_tree().get_nodes_in_group("repairable_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var max_hp: float = float(node.get_meta("structure_max_health")) if node.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(node.get_meta("structure_health")) if node.has_meta("structure_health") else max_hp
		hp = clampf(hp, 0.0, max_hp)
		node.set_meta("structure_health", hp)
		var ratio: float = hp / max_hp
		for child in node.get_children():
			if child is Sprite2D:
				child.modulate = Color(1.0, ratio, ratio, 1.0)
				break

func _get_damaged_repairable_structures() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group("repairable_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var max_hp: float = float(node.get_meta("structure_max_health")) if node.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(node.get_meta("structure_health")) if node.has_meta("structure_health") else max_hp
		if hp >= max_hp - 0.5:
			continue
		out.append(node)
	return out

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
		node.global_position = _snap_to_tile(_random_world_position(240.0))
		node.set("resource_type", resource_type)
		node.set("display_name", display_name)
		node.set("max_amount", randi_range(min_amount, max_amount))
		node.set("gather_per_tick", maxi(3, gather_speed + randi_range(-2, 2)))
		node.set("tint", tint)
		world_root.add_child(node)

func _spawn_random_huntables(display_name: String, tint: Color, count: int, min_hp: int, max_hp: int, min_meat: int, max_meat: int) -> void:
	for _i in range(count):
		var node: Node2D = HUNTABLE_SCENE.instantiate()
		node.global_position = _snap_to_tile(_random_world_position(260.0))
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

func _load_crop_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(CROP_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [CROP_DEF_DIR, file_name]
			var def: Resource = load(path)
			if def != null:
				defs.append(def)
		file_name = dir.get_next()
	dir.list_dir_end()
	defs.sort_custom(func(a, b): return String(a.id) < String(b.id))
	return defs

func _load_research_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(RESEARCH_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [RESEARCH_DEF_DIR, file_name]
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
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		var building_id: StringName = StringName(node.get_meta("building_id"))
		for ws_id_any in workstation_lookup.keys():
			var ws_id: StringName = StringName(ws_id_any)
			var ws: Resource = workstation_lookup[ws_id]
			if StringName(ws.linked_building_id) != building_id:
				continue
			var dist: float = node.global_position.distance_to(world_pos)
			if dist <= best_dist:
				best_dist = dist
				best_id = ws.id
	return best_id

func _find_workstation_node_near(world_pos: Vector2, radius: float, workstation_id: StringName = &"") -> Node:
	var best_node: Node = null
	var best_dist: float = radius
	var target_building_id: StringName = &""
	if workstation_id != &"" and workstation_lookup.has(workstation_id):
		target_building_id = StringName(workstation_lookup[workstation_id].linked_building_id)
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		var building_id: StringName = StringName(node.get_meta("building_id"))
		if target_building_id != &"" and building_id != target_building_id:
			continue
		var dist: float = node.global_position.distance_to(world_pos)
		if dist > best_dist:
			continue
		best_dist = dist
		best_node = node
	return best_node

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

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / TILE_SIZE)),
		int(round(world_pos.y / TILE_SIZE))
	)

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) * TILE_SIZE, float(tile.y) * TILE_SIZE)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return _tile_to_world(_world_to_tile(world_pos))

func _can_drag_line_place(building_id: StringName) -> bool:
	return building_id == &"Wall" or building_id == &"Gate"

func _build_line_tiles_from_world(start_world: Vector2, end_world: Vector2) -> Array[Vector2i]:
	var start_tile: Vector2i = _world_to_tile(start_world)
	var end_tile: Vector2i = _world_to_tile(end_world)
	var out: Array[Vector2i] = []
	var dx: int = end_tile.x - start_tile.x
	var dy: int = end_tile.y - start_tile.y
	# Lock to the dominant axis so wall drag remains a straight line.
	if abs(dx) >= abs(dy):
		var dir_x: int = 1 if dx >= 0 else -1
		for x in range(start_tile.x, end_tile.x + dir_x, dir_x):
			out.append(Vector2i(x, start_tile.y))
	else:
		var dir_y: int = 1 if dy >= 0 else -1
		for y in range(start_tile.y, end_tile.y + dir_y, dir_y):
			out.append(Vector2i(start_tile.x, y))
	return out

func _try_place_building_line_by_id(start_world: Vector2, end_world: Vector2, building_id: StringName) -> void:
	if building_id == &"":
		return
	var tiles: Array[Vector2i] = _build_line_tiles_from_world(start_world, end_world)
	if tiles.is_empty():
		return
	for tile in tiles:
		_try_place_building_by_id(_tile_to_world(tile), building_id)

func _consume_free_build_allowance(building_id: StringName) -> bool:
	if building_id == &"":
		return false
	var remain: int = int(_free_build_allowance.get(building_id, 0))
	if remain <= 0:
		return false
	_free_build_allowance[building_id] = remain - 1
	return true

func _is_colonist_in_combat(colonist: Node) -> bool:
	if colonist == null or not is_instance_valid(colonist):
		return false
	if colonist.has_method("is_dead") and bool(colonist.is_dead()):
		return false
	if colonist.current_job.is_empty():
		return false
	var job_type: StringName = StringName(colonist.current_job.get("type", &""))
	return job_type == &"CombatMelee" or job_type == &"CombatRanged"

func _find_free_combat_tile(preferred: Vector2i, max_radius: int = 2) -> Vector2i:
	if not _combat_tile_claims.has(preferred):
		return preferred
	for r in range(1, max_radius + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var candidate := Vector2i(preferred.x + x, preferred.y + y)
				if _combat_tile_claims.has(candidate):
					continue
				return candidate
	return preferred

func _apply_combat_tile_occupancy() -> void:
	_combat_tile_claims.clear()
	var raid_active: bool = _raid_state == &"Active"
	var combat_units: Array[Node2D] = []
	for c in colonists:
		if _is_colonist_in_combat(c):
			combat_units.append(c)
	# Units can overlap in normal state; enforce one-unit-per-tile only in combat.
	if raid_active:
		for r in _get_alive_raiders():
			if r != null and is_instance_valid(r):
				combat_units.append(r)
	if combat_units.is_empty():
		return
	for unit in combat_units:
		var preferred_tile: Vector2i = _world_to_tile(unit.global_position)
		var assigned_tile: Vector2i = _find_free_combat_tile(preferred_tile, 2)
		_combat_tile_claims[assigned_tile] = unit.get_instance_id()
		unit.global_position = _tile_to_world(assigned_tile)
