extends Node2D

const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")
const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
const GATHERABLE_SCENE: PackedScene = preload("res://scenes/world/Gatherable.tscn")
const HUNTABLE_SCENE: PackedScene = preload("res://scenes/world/Huntable.tscn")
const BUILDING_SITE_SCENE: PackedScene = preload("res://scenes/world/BuildingSite.tscn")
const STOCKPILE_ZONE_SCENE: PackedScene = preload("res://scenes/world/StockpileZone.tscn")
const FARM_ZONE_SCENE: PackedScene = preload("res://scenes/world/FarmZone.tscn")
const WORKSTATION_DEPOT_SCRIPT: Script = preload("res://scripts/core/WorkstationDepot.gd")
const BUILDING_DEF_DIR := "res://data/buildings"
const RECIPE_DEF_DIR := "res://data/recipes"
const WORKSTATION_DEF_DIR := "res://data/workstations"
const CROP_DEF_DIR := "res://data/crops"
const RESEARCH_DEF_DIR := "res://data/research"
const VEHICLE_DEF_DIR := "res://data/vehicles"
const RESEARCH_REQUIRED_POINTS_SCALE: float = 0.1
const SAVE_VERSION: int = 1
const DEFAULT_AUTOSAVE_SLOT_ID: String = "slot_0"
const SAVE_DIR: String = "user://saves"
const SAVE_FILE_SUFFIX: String = "_autosave.json"
const AUTOSAVE_INTERVAL_SEC: float = 60.0
const PATHING_OCCUPANCY_SCRIPT: Script = preload("res://scripts/systems/PathingOccupancy.gd")
const ENEMY_FLOW_FIELD_SERVICE_SCRIPT: Script = preload("res://scripts/systems/EnemyFlowFieldService.gd")
const ENEMY_ENGAGEMENT_COORDINATOR_SCRIPT: Script = preload("res://scripts/systems/EnemyEngagementCoordinator.gd")
const WORLD_INDEX_SERVICE_SCRIPT: Script = preload("res://scripts/systems/WorldIndexService.gd")
const TRAP_SERVICE_SCRIPT: Script = preload("res://scripts/systems/TrapService.gd")
const SAVE_LOAD_SERVICE_SCRIPT: Script = preload("res://scripts/systems/SaveLoadService.gd")
const PERF_TELEMETRY_SERVICE_SCRIPT: Script = preload("res://scripts/systems/PerfTelemetryService.gd")
const SIMULATION_DISPATCH_SERVICE_SCRIPT: Script = preload("res://scripts/systems/SimulationDispatchService.gd")
const COMBAT_RAID_SERVICE_SCRIPT: Script = preload("res://scripts/systems/CombatRaidService.gd")
const STRUCTURE_HEALTH_BAR: Script = preload("res://scripts/core/StructureHealthBar.gd")
const EQUIPMENT_STATS: Script = preload("res://scripts/core/EquipmentStats.gd")
const HANDCART_SCRIPT: Script = preload("res://scripts/core/Handcart.gd")
const VEHICLE_SCRIPT: Script = preload("res://scripts/core/VehicleInstance.gd")
const DEFAULT_LOADOUT: ColonistLoadoutData = preload("res://data/colonists/default_loadout.tres")
const RESOURCE_DROP_SCENE: PackedScene = preload("res://scenes/world/ResourceDrop.tscn")
const GAME_TEXT: Script = preload("res://scripts/core/GameText.gd")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const WORLD_SIZE: Vector2 = Vector2(7680.0, 4352.0)
const TILE_SIZE: float = 64.0
const EDGE_SCROLL_MARGIN: float = 18.0
const EDGE_SCROLL_SPEED: float = 980.0
const MIN_ZOOM: float = 0.65
const MAX_ZOOM: float = 1.85
const ZOOM_STEP: float = 0.08
const COMBAT_FEEDBACK_BODY_OFFSET: Vector2 = Vector2(0.0, -30.0)
const COMBAT_FEEDBACK_FLOAT_DISTANCE: float = 46.0
const COMBAT_FEEDBACK_DURATION: float = 0.65

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
	&"Wood": 0,
	&"Stone": 0,
	&"Steel": 0,
	&"FoodRaw": 0,
	&"Meal": 0,
	&"Bed": 0,
	&"GatherTop": 0,
	&"GatherBottom": 0,
	&"Handcart": 0,
	&"Bicycle": 0,
	&"StrawHat": 0,
	&"Weapon": 0,
	&"CombatTop": 0,
	&"CombatBottom": 0,
	&"CombatHat": 0,
	&"Sword": 0,
	&"Rifle": 0
}
var _free_build_allowance: Dictionary = {
	&"Wall": 100,
	&"Gate": 8,
	&"FiringWall": 24
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
var vehicle_lookup: Dictionary = {}
var _building_defs_all: Array = []
var _research_completed: Dictionary = {}
var _active_research_id: StringName = &""
var _active_research_points: float = 0.0
var _research_running: bool = false
var _farm_growth_multiplier: float = 1.0
var _combat_accuracy_bonus_from_research: float = 0.0
var _build_speed_bonus_from_research: float = 1.0
var _repair_speed_bonus_from_research: float = 1.0
var _haul_urgency_bonus_from_research: float = 1.0
var _rest_recover_bonus_from_research: float = 1.0
var _trap_damage_bonus_from_research: float = 1.0
var _raid_reward_bonus_from_research: float = 1.0
var _trap_range_bonus_from_research: float = 1.0
var _enemy_drop_bonus_from_research: float = 1.0
var _trap_cooldown_bonus_from_research: float = 1.0
var _farm_yield_bonus_from_research: float = 1.0
var _farm_resilience_bonus_from_research: float = 1.0
var _enemy_night_slow_bonus_from_research: float = 1.0
var selected_workstation_id: StringName = &""
var selected_stockpile_zone: Node = null
var selected_farm_zone: Node = null
var _middle_drag_camera: bool = false
var _game_paused: bool = false
var _speed_scale: float = 1.0
var pending_building_id: StringName = &""
var pending_building_rotation: int = 0
var pending_install_item: StringName = &""
var pending_install_drop_id: int = 0
var _deferred_build_requests: Dictionary = {}
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
var _context_handcart_id: int = 0
var _context_handcart_release_pos: Vector2 = Vector2.INF
var _context_vehicle_id: int = 0
var _context_stockpile_zone_id: int = 0
var _context_stockpile_use_pos: Vector2 = Vector2.INF
var _context_stockpile_vehicle_resource: StringName = &""
var _context_equipment_resource: StringName = &""
var _context_equipment_source_kind: StringName = &""
var _context_equipment_drop_id: int = 0
var _context_equipment_stockpile_zone_id: int = 0
var _pending_handcart_use_by_colonist: Dictionary = {}
var _pending_vehicle_use_by_colonist: Dictionary = {}
var _pending_stockpile_mountable_use_by_colonist: Dictionary = {}
var _selected_object_kind: StringName = &""
var _selected_object_resource: StringName = &""
var _selected_object_zone: Node = null
var _workstation_depots: Dictionary = {}
var _outfit_mode: StringName = &"Combat"
var _equipped_weapon_kind: Dictionary = {}
var _manual_equipment_slots_by_colonist: Dictionary = {}
var _raid_state: StringName = &"Idle"
var _raid_warning_timer: float = 0.0
var _raid_wave_size: int = 0
var _raid_wave_kind: StringName = &"RaiderOnly"
var _combat_tile_claims: Dictionary = {}
var _combat_rally_point: Vector2 = WORLD_SIZE * 0.5
var _rally_flag_node: Node2D = null
var _auto_repair_threshold_ratio: float = 0.75
var _defense_status_text: String = "-"
var _day_night_cycle_seconds: float = 240.0
var _pathing_occupancy: PathingOccupancy = null
var _enemy_flow_field_service: Node = null
var _enemy_engagement_coordinator: Node = null
var _world_index_service: Node = null
var _trap_service: Node = null
var _save_load_service: Node = null
var _perf_telemetry_service: Node = null
var _simulation_dispatch_service: Node = null
var _combat_raid_service: Node = null
var _cached_alive_enemies: Array = []
var _hud_dirty: bool = true
var _hud_time_dirty: bool = false
var _hud_selection_dirty: bool = false
var _cached_research_options: Array = []
var _cached_research_options_sig: int = 0
var _perf_report_next_ms: int = 0
var _perf_samples: Array[float] = []
var _perf_samples_head: int = 0
var _perf_samples_count: int = 0
const PERF_RING_SIZE: int = 900
const GUI_PLAYTEST_HINTS_ENV := "GUI_PLAYTEST_HINTS"
const GUI_PLAYTEST_BUILDING_ENV := "GUI_PLAYTEST_BUILDING_ID"
var _enemy_sim_interval_scale: float = 1.0
var _friendly_pathing_budget_scale: float = 1.0
var _perf_last_ticks_usec: int = 0
var _combat_log_next_ms: int = 0
var _combat_window: Dictionary = {}
var _perf_logging_enabled: bool = false
var _dispatch_queued: bool = false
var _dispatch_jobs_dirty: bool = true
var _dispatch_combat_dirty: bool = true
var _dispatch_economy_dirty: bool = true
var _dispatch_maintenance_dirty: bool = true
var _dispatch_farm_dirty: bool = true
var _dispatch_pathing_dirty: bool = true
var _dispatch_traps_dirty: bool = true
const TRAP_UPDATE_INTERVAL_SEC: float = 0.12
const FARM_TICK_INTERVAL_SEC: float = 0.2
var _trap_update_accum: float = 0.0
var _farm_tick_accum: float = 0.0
var _trap_move_event_next_ms: int = 0
const TRAP_MAX_PER_UPDATE: int = 42
var _active_jobs_next_ms: int = 0
var _has_demolish_overlay: bool = false
var _last_hud_time_tick: int = -1
var _workstation_slots_dirty: bool = true
var _cached_workstation_slots_map: Dictionary = {}
var _structure_maintenance_dirty: bool = true
var _cached_damaged_repairables: Array = []
var _cached_maintainable_traps: Array = []
var _need_job_refresh_next_ms_by_colonist: Dictionary = {}
var _colonist_idle_state_by_id: Dictionary = {}
var _group_cache: Dictionary = {}
var _group_cache_dirty: Dictionary = {}
var _job_liveness_next_ms: int = 0
var _autosave_enabled: bool = false
var _next_autosave_ms: int = 0
var _save_load_in_progress: bool = false

func _ready() -> void:
	add_to_group("main_controller")
	randomize()
	_perf_logging_enabled = _is_perf_logging_enabled()
	_pathing_occupancy = PATHING_OCCUPANCY_SCRIPT.new()
	_pathing_occupancy.name = "PathingOccupancy"
	var systems_node: Node = get_node_or_null("Systems")
	if systems_node != null:
		systems_node.add_child(_pathing_occupancy)
	else:
		add_child(_pathing_occupancy)
	_pathing_occupancy.add_to_group("pathing_occupancy")
	_pathing_occupancy.setup(TILE_SIZE)
	_enemy_flow_field_service = ENEMY_FLOW_FIELD_SERVICE_SCRIPT.new()
	_enemy_flow_field_service.name = "EnemyFlowFieldService"
	_enemy_flow_field_service.add_to_group("enemy_flow_field_service")
	if systems_node != null:
		systems_node.add_child(_enemy_flow_field_service)
	else:
		add_child(_enemy_flow_field_service)
	_enemy_flow_field_service.setup(TILE_SIZE, WORLD_SIZE, _pathing_occupancy)
	_enemy_engagement_coordinator = ENEMY_ENGAGEMENT_COORDINATOR_SCRIPT.new()
	_enemy_engagement_coordinator.name = "EnemyEngagementCoordinator"
	_enemy_engagement_coordinator.add_to_group("enemy_engagement_coordinator")
	if systems_node != null:
		systems_node.add_child(_enemy_engagement_coordinator)
	else:
		add_child(_enemy_engagement_coordinator)
	_enemy_engagement_coordinator.setup(TILE_SIZE, _pathing_occupancy)
	_world_index_service = WORLD_INDEX_SERVICE_SCRIPT.new()
	_world_index_service.name = "WorldIndexService"
	_world_index_service.add_to_group("world_index_service")
	if systems_node != null:
		systems_node.add_child(_world_index_service)
	else:
		add_child(_world_index_service)
	if _world_index_service.has_signal("pathing_world_changed"):
		_world_index_service.connect("pathing_world_changed", Callable(self, "_mark_pathing_dirty"))
	_trap_service = TRAP_SERVICE_SCRIPT.new()
	_trap_service.name = "TrapService"
	_trap_service.add_to_group("trap_service")
	if systems_node != null:
		systems_node.add_child(_trap_service)
	else:
		add_child(_trap_service)
	_trap_service.setup(TILE_SIZE, TRAP_MAX_PER_UPDATE)
	_save_load_service = SAVE_LOAD_SERVICE_SCRIPT.new()
	_save_load_service.name = "SaveLoadService"
	_save_load_service.add_to_group("save_load_service")
	if systems_node != null:
		systems_node.add_child(_save_load_service)
	else:
		add_child(_save_load_service)
	_save_load_service.setup(self, SAVE_DIR, SAVE_FILE_SUFFIX, DEFAULT_AUTOSAVE_SLOT_ID, SAVE_VERSION)
	_perf_telemetry_service = PERF_TELEMETRY_SERVICE_SCRIPT.new()
	_perf_telemetry_service.name = "PerfTelemetryService"
	_perf_telemetry_service.add_to_group("perf_telemetry_service")
	if systems_node != null:
		systems_node.add_child(_perf_telemetry_service)
	else:
		add_child(_perf_telemetry_service)
	_perf_telemetry_service.setup(_perf_logging_enabled, PERF_RING_SIZE)
	_simulation_dispatch_service = SIMULATION_DISPATCH_SERVICE_SCRIPT.new()
	_simulation_dispatch_service.name = "SimulationDispatchService"
	_simulation_dispatch_service.add_to_group("simulation_dispatch_service")
	if systems_node != null:
		systems_node.add_child(_simulation_dispatch_service)
	else:
		add_child(_simulation_dispatch_service)
	_combat_raid_service = COMBAT_RAID_SERVICE_SCRIPT.new()
	_combat_raid_service.name = "CombatRaidService"
	_combat_raid_service.add_to_group("combat_raid_service")
	if systems_node != null:
		systems_node.add_child(_combat_raid_service)
	else:
		add_child(_combat_raid_service)
	_combat_raid_service.setup(_day_night_cycle_seconds)
	if _pathing_occupancy.has_signal("revision_changed"):
		_pathing_occupancy.connect("revision_changed", Callable(self, "_on_pathing_occupancy_revision_changed"))
	_init_group_cache()
	var now_ms: int = Time.get_ticks_msec()
	_perf_report_next_ms = now_ms + 5000
	_perf_last_ticks_usec = Time.get_ticks_usec()
	_reset_combat_window()
	if _perf_telemetry_service != null and is_instance_valid(_perf_telemetry_service):
		_perf_telemetry_service.start(now_ms, _perf_last_ticks_usec)
	_configure_world_bounds()
	_randomize_world_spawns()
	var building_defs: Array = _load_building_defs()
	var workstation_defs: Array = _load_workstation_defs()
	var recipe_defs: Array = _load_recipe_defs()
	var crop_defs: Array = _load_crop_defs()
	var research_defs: Array = _load_research_defs()
	var vehicle_defs: Array = _load_vehicle_defs()
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
	for vehicle_def in vehicle_defs:
		if vehicle_def != null:
			vehicle_lookup[vehicle_def.id] = vehicle_def
	if build_system != null and build_system.has_method("set_grid_size"):
		build_system.set_grid_size(TILE_SIZE)
	_spawn_initial_colonists()
	_apply_starting_loadout(DEFAULT_LOADOUT)
	_refresh_building_catalog()
	if input_controller != null and input_controller.has_method("set_grid_size"):
		input_controller.set_grid_size(TILE_SIZE)
	input_controller.left_click.connect(_on_left_click)
	input_controller.drag_selection.connect(_on_drag_selection)
	input_controller.command_move.connect(_on_command_move)
	hud.priority_changed.connect(_on_priority_changed)
	hud.work_toggle_changed.connect(_on_work_toggle_changed)
	hud.building_selected.connect(_on_building_selected)
	hud.workstation_changed.connect(_on_workstation_changed)
	hud.craft_recipe_queued.connect(_on_craft_recipe_queued)
	hud.craft_recipe_repeat_queued.connect(_on_craft_recipe_repeat_queued)
	hud.craft_recipe_front_queued.connect(_on_craft_recipe_front_queued)
	hud.craft_queue_clear_requested.connect(_on_craft_queue_clear_requested)
	hud.craft_queue_remove_requested.connect(_on_craft_queue_remove_requested)
	hud.craft_queue_pause_toggled.connect(_on_craft_queue_pause_toggled)
	hud.stockpile_filter_mode_changed.connect(_on_stockpile_filter_mode_changed)
	hud.stockpile_filter_item_changed.connect(_on_stockpile_filter_item_changed)
	hud.stockpile_priority_changed.connect(_on_stockpile_priority_changed)
	hud.stockpile_limit_changed.connect(_on_stockpile_limit_changed)
	hud.stockpile_preset_apply_requested.connect(_on_stockpile_preset_apply_requested)
	hud.stockpile_delete_requested.connect(_on_stockpile_delete_requested)
	hud.designation_toggle_requested.connect(_on_designation_toggle_requested)
	hud.drag_gather_mode_requested.connect(func(): _on_action_changed(&"DragGather"))
	hud.drag_stockpile_mode_requested.connect(func(): _on_action_changed(&"StockpileZone"))
	hud.drag_farm_mode_requested.connect(func(): _on_action_changed(&"FarmZone"))
	hud.rally_flag_mode_requested.connect(func(): _on_action_changed(&"SetRallyFlag"))
	hud.action_button_pressed.connect(_on_hud_action_button_pressed)
	hud.clear_state_requested.connect(_on_clear_state_requested)
	hud.context_action_requested.connect(_on_context_action_requested)
	hud.selected_object_action_requested.connect(_on_selected_object_action_requested)
	hud.outfit_mode_changed.connect(_on_outfit_mode_changed)
	hud.raid_test_warning_requested.connect(_on_raid_test_warning_requested)
	hud.save_reset_requested.connect(_on_save_reset_requested)
	hud.bed_assignee_changed.connect(_on_bed_assignee_changed)
	hud.bed_auto_assign_requested.connect(_on_bed_auto_assign_requested)
	hud.research_project_changed.connect(_on_research_project_changed)
	hud.research_start_requested.connect(_on_research_start_requested)
	if hud.has_signal("portrait_selected"):
		hud.connect("portrait_selected", Callable(self, "_on_hud_portrait_selected"))
	if hud.has_signal("catalog_item_activated"):
		hud.connect("catalog_item_activated", Callable(self, "_on_hud_catalog_item_activated"))
	if build_system != null and is_instance_valid(build_system):
		if build_system.has_signal("build_site_added"):
			build_system.connect("build_site_added", Callable(self, "_on_build_site_added"))
		if build_system.has_signal("build_site_removed"):
			build_system.connect("build_site_removed", Callable(self, "_on_build_site_removed"))
		if build_system.has_signal("structure_added"):
			build_system.connect("structure_added", Callable(self, "_on_structure_added"))
		if build_system.has_signal("stockpile_zone_added"):
			build_system.connect("stockpile_zone_added", Callable(self, "_on_stockpile_zone_added"))
		if build_system.has_signal("farm_zone_added"):
			build_system.connect("farm_zone_added", Callable(self, "_on_farm_zone_added"))
	hud.set_workstation_catalog(workstation_defs)
	hud.set_selected_workstation(selected_workstation_id)
	hud.set_recipe_catalog(_filter_recipes_for_workstation(selected_workstation_id))
	hud.set_research_catalog(
		_get_research_catalog(),
		_active_research_id,
		_get_research_lock_map(),
		_get_research_prereq_map(),
		_get_research_tree_rows()
	)
	hud.set_selected_count(0)
	hud.set_needs_preview(null)
	hud.set_priority_preview(null)
	hud.set_current_job_preview(null)
	hud.set_carry_capacity_preview(null)
	hud.set_work_toggles({})
	hud.set_craft_queue_preview([])
	hud.set_stockpile_filter_state(false, 0, {}, 0, {})
	hud.set_stockpile_presets(_get_stockpile_preset_options(), &"")
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
	_wire_existing_world_signals()
	_cached_alive_enemies = _get_alive_raiders()
	_refresh_demolish_overlay_state()
	_autosave_enabled = _is_primary_main_scene_run()
	if _autosave_enabled and has_save_slot(DEFAULT_AUTOSAVE_SLOT_ID):
		load_game_from_slot(DEFAULT_AUTOSAVE_SLOT_ID)
	_schedule_next_autosave()
	_maybe_start_auto_raid_benchmark()
	if _is_gui_playtest_hints_enabled():
		call_deferred("_emit_gui_playtest_hints")
	_queue_event_dispatch()

func _is_gui_playtest_hints_enabled() -> bool:
	return OS.get_environment(GUI_PLAYTEST_HINTS_ENV) == "1"

func _get_gui_playtest_building_id() -> StringName:
	var raw: String = OS.get_environment(GUI_PLAYTEST_BUILDING_ENV).strip_edges()
	if raw.is_empty():
		return &"Campfire"
	return StringName(raw)

func _emit_gui_playtest_hints() -> void:
	if not is_inside_tree():
		return
	if hud == null or not is_instance_valid(hud):
		return
	var building_id: StringName = _get_gui_playtest_building_id()
	if hud.has_method("get_building_button_rect"):
		var rect: Rect2 = hud.get_building_button_rect(building_id)
		if rect.size == Vector2.ZERO:
			await get_tree().process_frame
			if not is_inside_tree() or hud == null or not is_instance_valid(hud):
				return
			rect = hud.get_building_button_rect(building_id)
		if rect.size != Vector2.ZERO:
			print("GUI_HINT_BUILD_BUTTON %s %d %d %d %d" % [
				String(building_id),
				int(round(rect.position.x)),
				int(round(rect.position.y)),
				int(round(rect.size.x)),
				int(round(rect.size.y))
			])
	var target_world: Vector2 = _find_gui_playtest_build_target(building_id)
	var target_screen: Vector2 = _world_to_screen_point(target_world)
	print("GUI_HINT_BUILD_TARGET %s %d %d" % [
		String(building_id),
		int(round(target_screen.x)),
		int(round(target_screen.y))
	])

func _find_gui_playtest_build_target(building_id: StringName) -> Vector2:
	var def: Resource = build_system._building_defs.get(building_id, null) if build_system != null and is_instance_valid(build_system) else null
	var center: Vector2 = _snap_to_tile(WORLD_SIZE * 0.5)
	if def == null:
		return center + Vector2(TILE_SIZE * 3.0, 0.0)
	var ring_steps: Array[Vector2] = [
		Vector2(TILE_SIZE * 3.0, 0.0),
		Vector2(TILE_SIZE * 4.0, 0.0),
		Vector2(TILE_SIZE * 3.0, TILE_SIZE * 2.0),
		Vector2(TILE_SIZE * 4.0, TILE_SIZE * 2.0),
		Vector2(TILE_SIZE * 2.0, -TILE_SIZE * 2.0),
		Vector2(TILE_SIZE * 5.0, -TILE_SIZE),
		Vector2(TILE_SIZE * 5.0, TILE_SIZE * 3.0)
	]
	for offset in ring_steps:
		var probe: Vector2 = _snap_building_to_grid(center + offset, building_id)
		if build_system != null and is_instance_valid(build_system) and build_system.has_method("_is_footprint_occupied"):
			if bool(build_system._is_footprint_occupied(probe, def.footprint_size)):
				continue
		return probe
	return _snap_building_to_grid(center + Vector2(TILE_SIZE * 5.0, 0.0), building_id)

func _world_to_screen_point(world_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var cam_pos: Vector2 = camera.global_position if camera != null else Vector2.ZERO
	return (world_pos - cam_pos) / zoom + viewport_size * 0.5

func _init_group_cache() -> void:
	var hot_groups: Array[StringName] = [
		&"stockpile_zones",
		&"resource_drops",
		&"vehicles",
		&"handcarts",
		&"gatherables",
		&"huntables",
		&"structures",
		&"farm_zones",
		&"raiders",
		&"zombies",
		&"trap_structures",
		&"repairable_structures",
		&"build_sites"
	]
	if _world_index_service != null and is_instance_valid(_world_index_service):
		_world_index_service.setup(hot_groups)
		return
	for group_name in hot_groups:
		_group_cache_dirty[group_name] = true
	if get_tree() != null:
		if not get_tree().is_connected("node_added", Callable(self, "_on_tree_node_added")):
			get_tree().connect("node_added", Callable(self, "_on_tree_node_added"))
		if not get_tree().is_connected("node_removed", Callable(self, "_on_tree_node_removed")):
			get_tree().connect("node_removed", Callable(self, "_on_tree_node_removed"))

func _on_tree_node_added(_node: Node) -> void:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		return
	_mark_group_cache_for_node(_node)
	if _node == null:
		return
	if _node.is_in_group("blocking_structures") or _node.is_in_group("build_sites") or _node.is_in_group("structures"):
		_mark_pathing_dirty()

func _on_tree_node_removed(_node: Node) -> void:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		return
	_mark_group_cache_for_node(_node)
	if _node == null:
		return
	if _node.is_in_group("blocking_structures") or _node.is_in_group("build_sites") or _node.is_in_group("structures"):
		_mark_pathing_dirty()

func _mark_group_cache_dirty(group_name: StringName) -> void:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		_world_index_service.mark_group_dirty(group_name)
		return
	_group_cache_dirty[group_name] = true

func _mark_all_group_cache_dirty() -> void:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		_world_index_service.mark_all_dirty()
		return
	for group_name_any in _group_cache_dirty.keys():
		_group_cache_dirty[group_name_any] = true

func _mark_group_cache_for_node(node: Node) -> void:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		_world_index_service.mark_node_groups_dirty(node)
		return
	if node == null:
		return
	for group_name_any in _group_cache_dirty.keys():
		var group_name: StringName = StringName(group_name_any)
		if node.is_in_group(group_name):
			_group_cache_dirty[group_name] = true

func _get_group_nodes_cached(group_name: StringName) -> Array:
	if _world_index_service != null and is_instance_valid(_world_index_service):
		return _world_index_service.get_nodes_cached(group_name)
	if not is_inside_tree():
		return []
	if bool(_group_cache_dirty.get(group_name, true)):
		var tree: SceneTree = get_tree()
		_group_cache[group_name] = tree.get_nodes_in_group(StringName(group_name))
		_group_cache_dirty[group_name] = false
	return _group_cache.get(group_name, [])

func _process(delta: float) -> void:
	_record_frame_profile(delta)
	if input_controller != null and input_controller.dragging:
		queue_redraw()
	elif _has_demolish_overlay:
		queue_redraw()
	_process_camera(_get_camera_delta(delta))
	if not _game_paused:
		_elapsed_game_seconds += delta
		_farm_tick_accum += delta
		while _farm_tick_accum >= FARM_TICK_INTERVAL_SEC:
			_tick_farm_zones(FARM_TICK_INTERVAL_SEC)
			_farm_tick_accum -= FARM_TICK_INTERVAL_SEC
	var time_tick: int = int(floor(_elapsed_game_seconds * 10.0))
	if time_tick != _last_hud_time_tick:
		_last_hud_time_tick = time_tick
		_mark_hud_time_dirty()
	_update_raid_state(delta)
	_process_deferred_build_requests()
	_resolve_pending_stockpile_mountable_use_requests()
	_resolve_pending_handcart_use_requests()
	_resolve_pending_vehicle_use_requests()
	if _raid_state == &"Active":
		_trap_update_accum += delta
		if _trap_update_accum >= TRAP_UPDATE_INTERVAL_SEC:
			_dispatch_traps_dirty = true
			_queue_event_dispatch()
	if _has_pending_dispatch():
		_dispatch_event_updates()
	_check_job_liveness_watchdog()
	_process_autosave_timer()

func has_save_slot(slot_id: String = DEFAULT_AUTOSAVE_SLOT_ID) -> bool:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return bool(_save_load_service.has_save_slot(slot_id))
	return FileAccess.file_exists(_save_slot_path(slot_id))

func delete_save_slot(slot_id: String = DEFAULT_AUTOSAVE_SLOT_ID) -> bool:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return bool(_save_load_service.delete_save_slot(slot_id))
	if _save_load_in_progress:
		return false
	var path: String = _save_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return true
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Autosave delete failed: %s" % error_string(err))
		return false
	return true

func reset_save_and_reload_game_scene(slot_id: String = DEFAULT_AUTOSAVE_SLOT_ID) -> bool:
	if not delete_save_slot(slot_id):
		return false
	_autosave_enabled = false
	_next_autosave_ms = 0
	_clear_pending_dispatch_state()
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return true
	var tree: SceneTree = get_tree()
	if tree.current_scene != self:
		return true
	var err: Error = tree.reload_current_scene()
	if err != OK:
		push_warning("Game scene reload failed after save reset: %s" % error_string(err))
		return false
	return true

func save_game_to_slot(slot_id: String = DEFAULT_AUTOSAVE_SLOT_ID) -> bool:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return bool(_save_load_service.save_game_to_slot(slot_id))
	if _save_load_in_progress:
		return false
	var safe_slot: String = _sanitize_save_slot_id(slot_id)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if dir_error != OK:
		push_warning("Autosave directory create failed: %s" % error_string(dir_error))
		return false
	var path: String = _save_slot_path(safe_slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Autosave open failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	_save_load_in_progress = true
	var payload: Dictionary = _build_save_payload(safe_slot)
	file.store_string(JSON.stringify(payload, "\t"))
	_save_load_in_progress = false
	return true

func load_game_from_slot(slot_id: String = DEFAULT_AUTOSAVE_SLOT_ID) -> bool:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		var service_ok: bool = bool(_save_load_service.load_game_from_slot(slot_id))
		if service_ok:
			_schedule_next_autosave()
		return service_ok
	if _save_load_in_progress:
		return false
	var path: String = _save_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("Autosave parse failed: %s" % path)
		return false
	var payload: Dictionary = parsed
	if int(payload.get("version", 0)) != SAVE_VERSION:
		push_warning("Autosave version mismatch: %s" % path)
		return false
	_save_load_in_progress = true
	var ok: bool = _apply_save_payload(payload)
	_save_load_in_progress = false
	if ok:
		_schedule_next_autosave()
	return ok

func _is_primary_main_scene_run() -> bool:
	var tree: SceneTree = get_tree()
	return tree != null and tree.current_scene == self

func _is_save_load_in_progress() -> bool:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return bool(_save_load_service.is_in_progress())
	return _save_load_in_progress

func _process_autosave_timer() -> void:
	if not _autosave_enabled or _is_save_load_in_progress():
		return
	if _next_autosave_ms <= 0:
		_schedule_next_autosave()
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_autosave_ms:
		return
	if save_game_to_slot(DEFAULT_AUTOSAVE_SLOT_ID):
		_schedule_next_autosave()
	else:
		_next_autosave_ms = now_ms + 5000

func _schedule_next_autosave() -> void:
	if not _autosave_enabled:
		_next_autosave_ms = 0
		return
	_next_autosave_ms = Time.get_ticks_msec() + int(round(AUTOSAVE_INTERVAL_SEC * 1000.0))

func _save_slot_path(slot_id: String) -> String:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return String(_save_load_service.save_slot_path(slot_id))
	return "%s/%s%s" % [SAVE_DIR, _sanitize_save_slot_id(slot_id), SAVE_FILE_SUFFIX]

func _sanitize_save_slot_id(slot_id: String) -> String:
	if _save_load_service != null and is_instance_valid(_save_load_service):
		return String(_save_load_service.sanitize_save_slot_id(slot_id))
	var safe: String = slot_id.strip_edges()
	safe = safe.replace("/", "_").replace("\\", "_").replace(":", "_").replace("..", "_")
	if safe.is_empty():
		return DEFAULT_AUTOSAVE_SLOT_ID
	return safe

func _build_save_payload(slot_id: String) -> Dictionary:
	var craft_state: Dictionary = _save_craft_state()
	return {
		"version": SAVE_VERSION,
		"slot_id": slot_id,
		"saved_unix_time": Time.get_unix_time_from_system(),
		"time": {
			"elapsed_game_seconds": _elapsed_game_seconds,
			"game_paused": _game_paused,
			"speed_scale": _speed_scale,
			"camera_pos": _vector2_to_save(camera.global_position if camera != null else WORLD_SIZE * 0.5),
			"camera_zoom": _vector2_to_save(camera.zoom if camera != null else Vector2.ONE)
		},
		"ui": {
			"outfit_mode": String(_outfit_mode),
			"selected_workstation_id": String(selected_workstation_id)
		},
		"resources": _dict_int_to_save(resource_stock),
		"research": {
			"completed": _dict_bool_to_save(_research_completed),
			"active_id": String(_active_research_id),
			"points": _active_research_points,
			"running": _research_running
		},
		"craft": craft_state,
		"colonists": _save_colonists(),
		"world": {
			"gatherables": _save_gatherables(),
			"huntables": _save_huntables(),
			"drops": _save_resource_drops(_collect_carried_haul_drops()),
			"stockpiles": _save_stockpile_zones(),
			"farms": _save_farm_zones(),
			"build_sites": _save_build_sites(),
			"structures": _save_direct_structures(),
			"vehicles": _save_vehicles(),
			"rally": _save_rally_state()
		},
		"raid": _save_raid_state()
	}

func _apply_save_payload(payload: Dictionary) -> bool:
	_reset_world_for_load()
	_apply_time_save(payload.get("time", {}))
	_apply_ui_save(payload.get("ui", {}))
	resource_stock = _resource_stock_from_save(payload.get("resources", {}))
	_apply_research_save(payload.get("research", {}))
	var colonist_by_name: Dictionary = _restore_colonists(payload.get("colonists", []))
	var craft_state: Dictionary = payload.get("craft", {})
	_restore_world_save(payload.get("world", {}), colonist_by_name, craft_state)
	_restore_craft_state(craft_state)
	_apply_raid_save(payload.get("raid", {}))
	_finalize_loaded_state()
	return true

func _reset_world_for_load() -> void:
	_clear_pending_placement()
	for colonist in selected_colonists:
		if colonist != null and is_instance_valid(colonist) and colonist.has_method("set_selected"):
			colonist.set_selected(false)
	selected_colonists.clear()
	colonists.clear()
	_colonist_idle_state_by_id.clear()
	_need_job_refresh_next_ms_by_colonist.clear()
	_pending_handcart_use_by_colonist.clear()
	_pending_vehicle_use_by_colonist.clear()
	_pending_stockpile_mountable_use_by_colonist.clear()
	_equipped_top_ids.clear()
	_equipped_bottom_ids.clear()
	_equipped_hat_ids.clear()
	_equipped_weapon_ids.clear()
	_equipped_weapon_kind.clear()
	_manual_equipment_slots_by_colonist.clear()
	_combat_tile_claims.clear()
	_cached_alive_enemies.clear()
	_clear_saved_world_nodes()
	_reset_job_runtime_for_load()
	_reset_build_runtime_for_load()
	_workstation_depots.clear()
	_init_group_cache()
	_mark_all_group_cache_dirty()

func _clear_saved_world_nodes() -> void:
	var seen: Dictionary = {}
	var group_names: Array[StringName] = [
		&"colonists", &"raiders", &"zombies", &"gatherables", &"huntables",
		&"resource_drops", &"stockpile_zones", &"farm_zones", &"build_sites",
		&"structures", &"handcarts", &"vehicles"
	]
	for group_name in group_names:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node):
				continue
			var id: int = node.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_queue_free_without_groups(node)
	for depot in _workstation_depots.values():
		if depot != null and is_instance_valid(depot):
			_queue_free_without_groups(depot)
	if _rally_flag_node != null and is_instance_valid(_rally_flag_node):
		_rally_flag_node.queue_free()
	_rally_flag_node = null

func _queue_free_without_groups(node: Node) -> void:
	var groups: Array = node.get_groups().duplicate()
	for group_any in groups:
		node.remove_from_group(StringName(group_any))
	node.queue_free()

func _reset_job_runtime_for_load() -> void:
	if job_system == null or not is_instance_valid(job_system):
		return
	if "_jobs" in job_system:
		job_system._jobs.clear()
	if "_reserved_craft_slot_ids" in job_system:
		job_system._reserved_craft_slot_ids.clear()
	if "_reserved_drop_ids" in job_system:
		job_system._reserved_drop_ids.clear()
	if "_craft_queues" in job_system:
		job_system._craft_queues.clear()
	if "_paused_craft_workstations" in job_system:
		job_system._paused_craft_workstations.clear()
	if "_rallied_colonist_ids" in job_system:
		job_system._rallied_colonist_ids.clear()
	if job_system.has_method("exit_raid_mode"):
		job_system.exit_raid_mode()
	job_system.mark_haul_dirty()
	job_system.mark_craft_dirty()
	job_system.mark_research_dirty()
	job_system.mark_designation_dirty()
	job_system.mark_repair_dirty()
	job_system.mark_combat_dirty()

func _reset_build_runtime_for_load() -> void:
	if build_system == null or not is_instance_valid(build_system):
		return
	if "_sites" in build_system:
		build_system._sites.clear()
	if "_zones" in build_system:
		build_system._zones.clear()
	if "_cached_structures" in build_system:
		build_system._cached_structures.clear()
	if "_structures_cache_dirty" in build_system:
		build_system._structures_cache_dirty = true

func _apply_time_save(time_state: Variant) -> void:
	if not (time_state is Dictionary):
		time_state = {}
	var state: Dictionary = time_state
	_elapsed_game_seconds = maxf(0.0, float(state.get("elapsed_game_seconds", 0.0)))
	_game_paused = bool(state.get("game_paused", false))
	_speed_scale = clampf(float(state.get("speed_scale", 1.0)), 0.25, 8.0)
	if camera != null:
		camera.global_position = _load_vector2(state.get("camera_pos", WORLD_SIZE * 0.5), WORLD_SIZE * 0.5)
		camera.zoom = _load_vector2(state.get("camera_zoom", Vector2.ONE), Vector2.ONE)

func _apply_ui_save(ui_state: Variant) -> void:
	if not (ui_state is Dictionary):
		ui_state = {}
	var state: Dictionary = ui_state
	_outfit_mode = StringName(state.get("outfit_mode", String(_outfit_mode)))
	var ws_id: StringName = StringName(state.get("selected_workstation_id", String(selected_workstation_id)))
	if ws_id != &"" and workstation_lookup.has(ws_id):
		selected_workstation_id = ws_id
	elif not workstation_lookup.is_empty():
		selected_workstation_id = StringName(workstation_lookup.keys()[0])
	current_action = &"Interact"

func _apply_research_save(research_state: Variant) -> void:
	if not (research_state is Dictionary):
		research_state = {}
	var state: Dictionary = research_state
	_research_completed = _string_name_bool_dict_from_save(state.get("completed", {}))
	_active_research_id = StringName(state.get("active_id", ""))
	_active_research_points = maxf(0.0, float(state.get("points", 0.0)))
	_research_running = bool(state.get("running", false)) and _active_research_id != &""
	_reset_research_bonuses_for_load()
	var keys: Array = _research_completed.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		var research_id: StringName = StringName(key_any)
		if bool(_research_completed.get(research_id, false)):
			_apply_research_bonus(research_id)

func _reset_research_bonuses_for_load() -> void:
	_farm_growth_multiplier = 1.0
	_combat_accuracy_bonus_from_research = 0.0
	_build_speed_bonus_from_research = 1.0
	_repair_speed_bonus_from_research = 1.0
	_haul_urgency_bonus_from_research = 1.0
	_rest_recover_bonus_from_research = 1.0
	_trap_damage_bonus_from_research = 1.0
	_raid_reward_bonus_from_research = 1.0
	_trap_range_bonus_from_research = 1.0
	_enemy_drop_bonus_from_research = 1.0
	_trap_cooldown_bonus_from_research = 1.0
	_farm_yield_bonus_from_research = 1.0
	_farm_resilience_bonus_from_research = 1.0
	_enemy_night_slow_bonus_from_research = 1.0

func _restore_colonists(rows: Variant) -> Dictionary:
	var by_name: Dictionary = {}
	if not (rows is Array):
		return by_name
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var colonist: Node = COLONIST_SCENE.instantiate()
		var saved_name: String = String(row.get("name", "Colonist%d" % [colonists.size() + 1]))
		colonist.name = saved_name
		colonist.global_position = _snap_to_tile(_load_vector2(row.get("pos", WORLD_SIZE * 0.5), WORLD_SIZE * 0.5))
		if colonist.has_method("set_tile_size"):
			colonist.set_tile_size(TILE_SIZE)
		_connect_loaded_colonist_signals(colonist)
		units_root.add_child(colonist)
		colonist.set("health", float(row.get("health", colonist.get("health"))))
		colonist.set("hunger", float(row.get("hunger", colonist.get("hunger"))))
		colonist.set("rest", float(row.get("rest", colonist.get("rest"))))
		colonist.set("mood", float(row.get("mood", colonist.get("mood"))))
		_restore_colonist_priorities(colonist, row.get("priorities", {}))
		_restore_colonist_work_toggles(colonist, row.get("work_enabled", {}))
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots(_string_name_dict_from_save(row.get("equipment", {})))
		if colonist.has_method("set_combat_ready"):
			colonist.set_combat_ready(bool(row.get("combat_ready", false)))
		else:
			colonist.set("combat_ready", bool(row.get("combat_ready", false)))
		if colonist.has_method("emit_status"):
			colonist.emit_status()
		_colonist_idle_state_by_id[colonist.get_instance_id()] = true
		colonists.append(colonist)
		by_name[saved_name] = colonist
	return by_name

func _connect_loaded_colonist_signals(colonist: Node) -> void:
	colonist.status_changed.connect(_on_colonist_status_changed)
	colonist.resource_harvested.connect(_on_resource_harvested)
	colonist.resource_delivered.connect(_on_resource_delivered)
	colonist.workstation_supply_picked.connect(_on_workstation_supply_picked)
	colonist.workstation_supply_delivered.connect(_on_workstation_supply_delivered)
	colonist.workstation_supply_returned.connect(_on_workstation_supply_returned)
	colonist.craft_completed.connect(_on_craft_completed)
	colonist.structure_demolished.connect(_on_structure_demolished)
	colonist.research_progressed.connect(_on_research_progressed)
	colonist.haul_job_released.connect(_on_haul_job_released)
	colonist.ate_food.connect(_on_colonist_ate_food)
	colonist.died.connect(_on_colonist_died)

func _restore_world_save(world_state: Variant, colonist_by_name: Dictionary, craft_state: Dictionary) -> void:
	if not (world_state is Dictionary):
		world_state = {}
	var state: Dictionary = world_state
	_restore_gatherables(state.get("gatherables", []))
	_restore_huntables(state.get("huntables", []))
	_restore_stockpile_zones(state.get("stockpiles", []))
	_restore_farm_zones(state.get("farms", []))
	_restore_build_sites(state.get("build_sites", []))
	_restore_direct_structures(state.get("structures", []), colonist_by_name)
	_refresh_all_wall_variants()
	_restore_vehicles(state.get("vehicles", []), colonist_by_name)
	_restore_workstation_depots(craft_state)
	_restore_resource_drops(state.get("drops", []))
	_restore_rally_state(state.get("rally", {}))

func _restore_gatherables(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var node: Node2D = GATHERABLE_SCENE.instantiate()
		node.global_position = _snap_to_tile(_load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO))
		node.set("resource_type", StringName(row.get("resource_type", "Wood")))
		node.set("display_name", String(row.get("display_name", "Resource")))
		node.set("max_amount", maxi(1, int(row.get("max_amount", 1))))
		node.set("gather_per_tick", maxi(1, int(row.get("gather_per_tick", 1))))
		node.set("tint", _load_color(row.get("tint", {}), Color(0.3, 0.65, 0.35, 1.0)))
		world_root.add_child(node)
		node.set("current_amount", maxi(0, int(row.get("current_amount", node.get("max_amount")))))
		node.set("job_queued", false)
		node.set("designated", bool(row.get("designated", false)))
		if node.has_method("_refresh_visual"):
			node.call("_refresh_visual")

func _restore_huntables(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var node: Node2D = HUNTABLE_SCENE.instantiate()
		node.global_position = _snap_to_tile(_load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO))
		node.set("display_name", String(row.get("display_name", "Animal")))
		node.set("max_health", maxi(1, int(row.get("max_health", 1))))
		node.set("hunt_damage_per_tick", maxi(1, int(row.get("hunt_damage_per_tick", 1))))
		node.set("meat_type", StringName(row.get("meat_type", "FoodRaw")))
		node.set("meat_yield", maxi(0, int(row.get("meat_yield", 0))))
		node.set("tint", _load_color(row.get("tint", {}), Color(0.78, 0.56, 0.36, 1.0)))
		world_root.add_child(node)
		node.set("health", maxi(0, int(row.get("health", node.get("max_health")))))
		node.set("job_queued", false)
		node.set("designated", bool(row.get("designated", false)))
		if node.has_method("_refresh_visual"):
			node.call("_refresh_visual")

func _restore_resource_drops(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var amount: int = int(row.get("amount", 0))
		if amount <= 0:
			continue
		var drop: Node = _spawn_resource_drop(
			StringName(row.get("resource_type", "Wood")),
			amount,
			_load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO)
		)
		if drop == null or not is_instance_valid(drop):
			continue
		drop.set("job_queued", false)
		if bool(row.get("craft_supply", false)):
			drop.set_meta("craft_supply", true)
		var target_ws: StringName = StringName(row.get("target_workstation_id", ""))
		if target_ws != &"" and _workstation_depots.has(target_ws):
			var depot: Node = _workstation_depots[target_ws]
			if depot != null and is_instance_valid(depot):
				drop.set_meta("craft_supply", true)
				drop.set_meta("preferred_zone_id", depot.get_instance_id())

func _restore_stockpile_zones(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var zone: Node = STOCKPILE_ZONE_SCENE.instantiate()
		world_root.add_child(zone)
		var pos: Vector2 = _load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO)
		var size: Vector2 = _load_vector2(row.get("size", Vector2(192, 128)), Vector2(192, 128))
		if zone.has_method("setup_from_rect"):
			zone.setup_from_rect(Rect2(pos - size * 0.5, size))
		zone.set("stored", _string_name_int_dict_from_save(row.get("stored", {})))
		zone.set("filter_mode", int(row.get("filter_mode", 0)))
		zone.set("filter_types", _string_name_array_from_save(row.get("filter_types", [])))
		zone.set("zone_priority", int(row.get("zone_priority", 0)))
		zone.set("resource_limits", _string_name_int_dict_from_save(row.get("resource_limits", {})))
		zone.set("preset_id", StringName(row.get("preset_id", "All")))
		if zone.has_method("_refresh_shape"):
			zone.call("_refresh_shape")
		elif zone.has_method("_update_label"):
			zone.call("_update_label")
		_track_loaded_zone(zone)
		_on_stockpile_zone_added(zone)

func _restore_farm_zones(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var zone: Node = FARM_ZONE_SCENE.instantiate()
		world_root.add_child(zone)
		var pos: Vector2 = _load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO)
		var size: Vector2 = _load_vector2(row.get("size", Vector2(192, 128)), Vector2(192, 128))
		if "tile_size" in zone:
			zone.tile_size = TILE_SIZE
		if zone.has_method("setup_from_rect"):
			zone.setup_from_rect(Rect2(pos - size * 0.5, size))
		_configure_farm_zone_catalog(zone)
		zone.set("crop_type", StringName(row.get("crop_type", "")))
		zone.set("zone_fertility", float(row.get("zone_fertility", 1.0)))
		zone.set("growth_time_multiplier", float(row.get("growth_time_multiplier", 1.0)))
		zone.set("yield_multiplier", float(row.get("yield_multiplier", 1.0)))
		zone.set("fertility_resilience", float(row.get("fertility_resilience", 1.0)))
		zone.set("_plots", _plots_from_save(row.get("plots", [])))
		if zone.has_method("_refresh_shape"):
			zone.call("_refresh_shape")
		if zone.has_method("_refresh_ground_tiles"):
			zone.call("_refresh_ground_tiles")
		if zone.has_method("_refresh_plot_markers"):
			zone.call("_refresh_plot_markers")
		if zone.has_method("_refresh_label"):
			zone.call("_refresh_label")
		_track_loaded_zone(zone)
		_on_farm_zone_added(zone)

func _restore_build_sites(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var building_id: StringName = StringName(row.get("building_id", ""))
		var def: Resource = _find_building_def(building_id)
		if def == null:
			continue
		var rotation_index: int = int(row.get("rotation", 0))
		var footprint: Vector2 = _effective_building_footprint(def, rotation_index)
		var complete: bool = bool(row.get("complete", false))
		var site: Node = BUILDING_SITE_SCENE.instantiate()
		world_root.add_child(site)
		site.global_position = _snap_footprint_to_grid(_load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO), footprint)
		if site.has_method("setup_building"):
			site.setup_building(def, complete, rotation_index)
		site.set("work_progress", float(row.get("work_progress", site.get("work_progress"))))
		site.set("complete", complete)
		site.set("job_queued", false)
		var materials_delivered: bool = bool(row.get("materials_delivered", complete))
		site.set("materials_delivered", materials_delivered)
		site.set_meta("materials_delivered", materials_delivered)
		_apply_structure_runtime_from_save(site, row.get("runtime", {}))
		if site.has_method("_update_visual"):
			site.call("_update_visual")
		_track_loaded_build_site(site)
		_on_build_site_added(site)
		if complete:
			_on_structure_added(site)

func _restore_direct_structures(rows: Variant, colonist_by_name: Dictionary) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var building_id: StringName = StringName(row.get("building_id", ""))
		if building_id == &"":
			continue
		var node: Node = _spawn_loaded_direct_structure(building_id, _load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO), int(row.get("rotation", 0)))
		if node == null or not is_instance_valid(node):
			continue
		_apply_structure_runtime_from_save(node, row.get("runtime", {}))
		_restore_assigned_colonist_meta(node, String(row.get("assigned_colonist", "")), colonist_by_name)
		_on_structure_added(node)

func _spawn_loaded_direct_structure(building_id: StringName, pos: Vector2, rotation_index: int = 0) -> Node:
	var def: Resource = _find_building_def(building_id)
	var footprint: Vector2 = _effective_building_footprint(def, rotation_index) if def != null else Vector2(TILE_SIZE, TILE_SIZE)
	var snapped: Vector2 = _snap_footprint_to_grid(pos, footprint) if def != null else _snap_to_tile(pos)
	match building_id:
		&"InstalledBed":
			_spawn_installed_bed(snapped)
			return _find_structure_by_building_near(snapped, &"InstalledBed", 4.0)
		&"InstalledHandcart":
			return _spawn_installed_handcart(snapped)
		_:
			if def == null:
				return null
			var placed := Node2D.new()
			placed.name = "Built_%s" % String(building_id)
			placed.global_position = snapped
			if build_system != null and is_instance_valid(build_system) and build_system.has_method("_apply_structure_metas"):
				build_system.call("_apply_structure_metas", placed, def, rotation_index, footprint)
			else:
				placed.add_to_group("structures")
				placed.set_meta("building_id", building_id)
				placed.set_meta("building_rotation", _normalized_building_rotation(def, rotation_index))
				placed.set_meta("footprint_size", footprint)
			var sprite := Sprite2D.new()
			var sprite_tex: Texture2D = GAME_SPRITE.get_building_texture(building_id, rotation_index)
			if sprite_tex != null:
				sprite.texture = sprite_tex
			else:
				sprite.texture = _make_loaded_block_texture(int(footprint.x), int(footprint.y), def.direct_place_color)
			placed.add_child(sprite)
			world_root.add_child(placed)
			return placed

func _restore_workstation_depots(craft_state: Dictionary) -> void:
	var depot_rows: Variant = craft_state.get("depots", {})
	if depot_rows is Dictionary:
		for ws_any in depot_rows.keys():
			var ws_id: StringName = StringName(ws_any)
			var row_any: Variant = depot_rows[ws_any]
			if not (row_any is Dictionary):
				continue
			var row: Dictionary = row_any
			var pos: Vector2 = _load_vector2(row.get("pos", _find_workstation_pos(ws_id)), _find_workstation_pos(ws_id))
			if pos == Vector2.INF:
				continue
			var depot: Node = _ensure_workstation_depot(ws_id, pos)
			if depot == null:
				continue
			depot.set("stored", _string_name_int_dict_from_save(row.get("stored", {})))
			depot.set("requested", _string_name_int_dict_from_save(row.get("requested", {})))
			depot.set("pending", _string_name_int_dict_from_save(row.get("pending", {})))
	var returns: Variant = craft_state.get("interrupted_returns", {})
	if not (returns is Dictionary):
		return
	for ws_any in returns.keys():
		var ws_id: StringName = StringName(ws_any)
		var returned: Dictionary = _string_name_int_dict_from_save(returns[ws_any])
		if returned.is_empty():
			continue
		var depot: Node = _workstation_depots.get(ws_id, null)
		var depot_pos: Vector2 = _find_workstation_pos(ws_id)
		if (depot == null or not is_instance_valid(depot)) and depot_pos != Vector2.INF:
			depot = _ensure_workstation_depot(ws_id, depot_pos)
		for resource_any in returned.keys():
			var resource_type: StringName = StringName(resource_any)
			var amount: int = int(returned[resource_any])
			if amount <= 0:
				continue
			if depot != null and is_instance_valid(depot):
				var stored: Dictionary = depot.get("stored")
				stored[resource_type] = int(stored.get(resource_type, 0)) + amount
				depot.set("stored", stored)
			else:
				_spawn_resource_drop(resource_type, amount, camera.global_position if camera != null else WORLD_SIZE * 0.5)

func _restore_craft_state(craft_state: Variant) -> void:
	if job_system == null or not is_instance_valid(job_system):
		return
	if not (craft_state is Dictionary):
		craft_state = {}
	var state: Dictionary = craft_state
	job_system._craft_queues = _craft_queues_from_save(state.get("queues", {}))
	job_system._paused_craft_workstations = _string_name_bool_dict_from_save(state.get("paused", {}))
	job_system.mark_craft_dirty()
	job_system.mark_assign_dirty()

func _apply_raid_save(raid_state: Variant) -> void:
	if not (raid_state is Dictionary):
		raid_state = {}
	var state: Dictionary = raid_state
	_raid_state = StringName(state.get("state", "Idle"))
	_raid_warning_timer = maxf(0.0, float(state.get("warning_timer", 0.0)))
	_raid_wave_size = maxi(0, int(state.get("wave_size", 0)))
	_raid_wave_kind = StringName(state.get("wave_kind", "RaiderOnly"))
	_restore_enemies(state.get("enemies", []))
	if _raid_state == &"Active" and job_system != null and is_instance_valid(job_system) and job_system.has_method("enter_raid_mode"):
		job_system.enter_raid_mode()

func _restore_enemies(rows: Variant) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var enemy_type: StringName = StringName(row.get("type", "Raider"))
		var scene: PackedScene = ZOMBIE_SCENE if enemy_type == &"Zombie" else RAIDER_SCENE
		var enemy: Node2D = scene.instantiate()
		enemy.global_position = _snap_to_tile(_load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO))
		if enemy.has_method("set_tile_size"):
			enemy.set_tile_size(TILE_SIZE)
		units_root.add_child(enemy)
		if enemy.has_method("set_equipment_slots"):
			enemy.set_equipment_slots(_string_name_dict_from_save(row.get("equipment", {})))
		enemy.set("health", float(row.get("health", enemy.get("health"))))
		if enemy.has_method("_refresh_label"):
			enemy.call("_refresh_label")
		_connect_enemy_signals(enemy)

func _finalize_loaded_state() -> void:
	_refresh_building_catalog()
	hud.set_workstation_catalog(workstation_lookup.values())
	hud.set_selected_workstation(selected_workstation_id)
	hud.set_recipe_catalog(_filter_recipes_for_workstation(selected_workstation_id))
	hud.set_research_catalog(
		_get_research_catalog(),
		_active_research_id,
		_get_research_lock_map(),
		_get_research_prereq_map(),
		_get_research_tree_rows()
	)
	hud.set_resource_stock(resource_stock)
	hud.set_active_action(&"Interact")
	hud.set_command_button_states(current_action)
	hud.set_outfit_mode(_outfit_mode)
	hud.set_raid_state(_raid_state, _raid_warning_timer, _raid_wave_kind)
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
	hud.set_research_state(_active_research_id, _active_research_points, _active_research_required_points(), _research_completed)
	hud.set_craft_panel_visible(false)
	hud.set_selected_count(0)
	_seed_equipment_maps_from_colonists()
	_apply_time_scale()
	_clamp_camera()
	_mark_all_group_cache_dirty()
	_mark_pathing_dirty()
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_mark_maintenance_dirty()
	_mark_farm_dirty()
	_hud_dirty = true
	_hud_time_dirty = true
	_hud_selection_dirty = true
	_cached_alive_enemies = _get_alive_raiders()
	_refresh_demolish_overlay_state()
	_queue_event_dispatch()

func _save_colonists() -> Array:
	var rows: Array = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		rows.append({
			"name": String(colonist.name),
			"pos": _vector2_to_save(colonist.global_position),
			"health": float(colonist.get("health")),
			"hunger": float(colonist.get("hunger")),
			"rest": float(colonist.get("rest")),
			"mood": float(colonist.get("mood")),
			"combat_ready": bool(colonist.get("combat_ready")),
			"work_enabled": _dict_bool_to_save(colonist.get("work_enabled")),
			"priorities": _save_colonist_priorities(colonist),
			"equipment": _dict_string_to_save(colonist.get_equipment_snapshot() if colonist.has_method("get_equipment_snapshot") else {})
		})
	return rows

func _save_colonist_priorities(colonist: Node) -> Dictionary:
	var out: Dictionary = {}
	var priorities: Variant = colonist.get("priorities")
	if priorities == null:
		return out
	for key in ["haul", "build", "craft", "gather", "hunt", "combat", "idle", "eat"]:
		out[key] = int(priorities.get(key))
	return out

func _restore_colonist_priorities(colonist: Node, saved: Variant) -> void:
	if not (saved is Dictionary):
		return
	var priorities: Variant = colonist.get("priorities")
	if priorities == null:
		return
	for key in ["haul", "build", "craft", "gather", "hunt", "combat", "idle", "eat"]:
		if saved.has(key):
			priorities.set(key, int(saved[key]))

func _restore_colonist_work_toggles(colonist: Node, saved: Variant) -> void:
	if not (saved is Dictionary):
		return
	for key_any in saved.keys():
		var work_type: StringName = StringName(key_any)
		if colonist.has_method("set_work_enabled"):
			colonist.set_work_enabled(work_type, bool(saved[key_any]))

func _save_gatherables() -> Array:
	var rows: Array = []
	for node in _get_group_nodes_cached(&"gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_depleted") and bool(node.is_depleted()):
			continue
		rows.append({
			"resource_type": String(node.get("resource_type")),
			"display_name": String(node.get("display_name")),
			"pos": _vector2_to_save(node.global_position),
			"max_amount": int(node.get("max_amount")),
			"current_amount": int(node.get("current_amount")),
			"gather_per_tick": int(node.get("gather_per_tick")),
			"tint": _color_to_save(node.get("tint")),
			"designated": bool(node.get("designated"))
		})
	return rows

func _save_huntables() -> Array:
	var rows: Array = []
	for node in _get_group_nodes_cached(&"huntables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		rows.append({
			"display_name": String(node.get("display_name")),
			"pos": _vector2_to_save(node.global_position),
			"max_health": int(node.get("max_health")),
			"health": int(node.get("health")),
			"hunt_damage_per_tick": int(node.get("hunt_damage_per_tick")),
			"meat_type": String(node.get("meat_type")),
			"meat_yield": int(node.get("meat_yield")),
			"tint": _color_to_save(node.get("tint")),
			"designated": bool(node.get("designated"))
		})
	return rows

func _save_resource_drops(extra_drops: Array) -> Array:
	var rows: Array = []
	for drop in _get_group_nodes_cached(&"resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if drop.has_method("is_empty") and bool(drop.is_empty()):
			continue
		var row: Dictionary = {
			"resource_type": String(drop.get("resource_type")),
			"amount": int(drop.get("amount")),
			"pos": _vector2_to_save(drop.global_position),
			"craft_supply": bool(drop.get_meta("craft_supply")) if drop.has_meta("craft_supply") else false
		}
		if drop.has_meta("preferred_zone_id"):
			var target_ws: String = _workstation_id_for_zone_id(int(drop.get_meta("preferred_zone_id")))
			if not target_ws.is_empty():
				row["target_workstation_id"] = target_ws
		rows.append(row)
	for carried in extra_drops:
		if carried is Dictionary:
			rows.append(carried)
	return rows

func _collect_carried_haul_drops() -> Array:
	var rows: Array = []
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var job: Dictionary = colonist.get("current_job")
		if StringName(job.get("type", &"")) != &"HaulResource":
			continue
		if StringName(job.get("phase", &"")) != &"to_zone":
			continue
		var amount: int = int(job.get("carried_amount", 0))
		var resource_type: StringName = StringName(job.get("carried_type", &""))
		if amount <= 0 or resource_type == &"":
			continue
		var row: Dictionary = {
			"resource_type": String(resource_type),
			"amount": amount,
			"pos": _vector2_to_save(colonist.global_position),
			"craft_supply": bool(job.get("as_craft_supply", false))
		}
		if bool(row["craft_supply"]):
			var target_ws: String = _workstation_id_for_zone_id(int(job.get("zone_id", 0)))
			if not target_ws.is_empty():
				row["target_workstation_id"] = target_ws
		rows.append(row)
	return rows

func _save_stockpile_zones() -> Array:
	var rows: Array = []
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		rows.append({
			"pos": _vector2_to_save(zone.global_position),
			"size": _vector2_to_save(zone.get("zone_size")),
			"stored": _dict_int_to_save(zone.get("stored")),
			"filter_mode": int(zone.get("filter_mode")),
			"filter_types": _string_name_array_to_save(zone.get("filter_types")),
			"zone_priority": int(zone.get("zone_priority")),
			"resource_limits": _dict_int_to_save(zone.get("resource_limits")),
			"preset_id": String(zone.get("preset_id"))
		})
	return rows

func _save_farm_zones() -> Array:
	var rows: Array = []
	for zone in _get_group_nodes_cached(&"farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		rows.append({
			"pos": _vector2_to_save(zone.global_position),
			"size": _vector2_to_save(zone.get("zone_size")),
			"crop_type": String(zone.get("crop_type")),
			"zone_fertility": float(zone.get("zone_fertility")),
			"growth_time_multiplier": float(zone.get("growth_time_multiplier")),
			"yield_multiplier": float(zone.get("yield_multiplier")),
			"fertility_resilience": float(zone.get("fertility_resilience")),
			"plots": _plots_to_save(zone.get("_plots"))
		})
	return rows

func _save_build_sites() -> Array:
	var rows: Array = []
	for site in _get_group_nodes_cached(&"build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		var building_id: StringName = StringName(site.get("building_id"))
		if building_id == &"":
			continue
		rows.append({
			"building_id": String(building_id),
			"pos": _vector2_to_save(site.global_position),
			"rotation": int(site.get("building_rotation")),
			"work_progress": float(site.get("work_progress")),
			"complete": bool(site.get("complete")),
			"materials_delivered": bool(site.get("materials_delivered")),
			"runtime": _save_structure_runtime(site)
		})
	return rows

func _save_direct_structures() -> Array:
	var rows: Array = []
	for node in _get_group_nodes_cached(&"structures"):
		if node == null or not is_instance_valid(node):
			continue
		if node.is_in_group("build_sites"):
			continue
		if not node.has_meta("building_id"):
			continue
		var assigned_name: String = ""
		if node.has_meta("assigned_colonist_id"):
			assigned_name = _colonist_name_for_id(int(node.get_meta("assigned_colonist_id")))
		rows.append({
			"building_id": String(node.get_meta("building_id")),
			"pos": _vector2_to_save(node.global_position),
			"rotation": int(node.get_meta("building_rotation")) if node.has_meta("building_rotation") else 0,
			"runtime": _save_structure_runtime(node),
			"assigned_colonist": assigned_name
		})
	return rows

func _save_vehicles() -> Array:
	var rows: Array = []
	for node in _get_group_nodes_cached(&"vehicles"):
		if node == null or not is_instance_valid(node):
			continue
		var rider_name: String = ""
		var rider_id: int = 0
		if node.has_method("get_rider_id"):
			rider_id = int(node.call("get_rider_id"))
		elif node.has_meta("rider_colonist_id"):
			rider_id = int(node.get_meta("rider_colonist_id"))
		if rider_id != 0:
			rider_name = _colonist_name_for_id(rider_id)
		var vehicle_id: StringName = StringName(node.get("vehicle_id"))
		if vehicle_id == &"" and node.has_meta("vehicle_id"):
			vehicle_id = StringName(node.get_meta("vehicle_id"))
		rows.append({
			"vehicle_id": String(vehicle_id),
			"pos": _vector2_to_save(node.global_position),
			"health": float(node.get("health")),
			"rider_name": rider_name
		})
	return rows

func _restore_vehicles(rows: Variant, colonist_by_name: Dictionary) -> void:
	if not (rows is Array):
		return
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var vehicle_id: StringName = StringName(row.get("vehicle_id", ""))
		if vehicle_id == &"":
			continue
		var vehicle: Node2D = _spawn_vehicle(vehicle_id, _load_vector2(row.get("pos", Vector2.ZERO), Vector2.ZERO))
		if vehicle == null or not is_instance_valid(vehicle):
			continue
		if "health" in vehicle:
			vehicle.set("health", clampf(float(row.get("health", vehicle.get("health"))), 0.0, float(vehicle.get("max_health"))))
			vehicle.set_meta("vehicle_health", float(vehicle.get("health")))
		if vehicle.has_method("_refresh_visuals"):
			vehicle.call("_refresh_visuals")
		var rider_name: String = String(row.get("rider_name", row.get("rider", "")))
		if not rider_name.is_empty() and colonist_by_name.has(rider_name):
			var colonist: Node = colonist_by_name[rider_name]
			if colonist != null and is_instance_valid(colonist) and colonist.has_method("mount_vehicle"):
				colonist.mount_vehicle(vehicle)

func _save_structure_runtime(node: Node) -> Dictionary:
	var out: Dictionary = {}
	for key in [
		&"structure_health", &"structure_max_health", &"trap_charges",
		&"trap_max_charges", &"trap_cooldown_left", &"assigned_colonist_id"
	]:
		if node.has_meta(key):
			out[String(key)] = node.get_meta(key)
	return out

func _apply_structure_runtime_from_save(node: Node, saved: Variant) -> void:
	if node == null or not is_instance_valid(node):
		return
	if saved is Dictionary:
		var row: Dictionary = saved
		for key_any in row.keys():
			var key: StringName = StringName(key_any)
			if key == &"assigned_colonist_id":
				continue
			node.set_meta(key, row[key_any])
	if node.has_meta("repair_job_queued"):
		node.set_meta("repair_job_queued", false)
	if node.has_meta("demolish_job_queued"):
		node.set_meta("demolish_job_queued", false)
	if node.has_meta("trap_maint_job_queued"):
		node.set_meta("trap_maint_job_queued", false)
	var max_hp: float = float(node.get_meta("structure_max_health")) if node.has_meta("structure_max_health") else 0.0
	var hp: float = float(node.get_meta("structure_health")) if node.has_meta("structure_health") else max_hp
	if max_hp > 0.0:
		STRUCTURE_HEALTH_BAR.update_bar(node, hp, max_hp)

func _restore_assigned_colonist_meta(node: Node, colonist_name: String, colonist_by_name: Dictionary) -> void:
	if colonist_name.is_empty() or not colonist_by_name.has(colonist_name):
		if node.has_method("clear_owner"):
			node.call("clear_owner")
		elif node.has_meta("assigned_colonist_id"):
			node.set_meta("assigned_colonist_id", 0)
		return
	var colonist: Node = colonist_by_name[colonist_name]
	if colonist != null and is_instance_valid(colonist):
		var colonist_id: int = colonist.get_instance_id()
		if node.has_method("assign_owner") and bool(node.call("assign_owner", colonist_id)):
			return
		node.set_meta("assigned_colonist_id", colonist_id)

func _save_rally_state() -> Dictionary:
	return {
		"exists": _rally_flag_node != null and is_instance_valid(_rally_flag_node),
		"pos": _vector2_to_save(_combat_rally_point)
	}

func _restore_rally_state(saved: Variant) -> void:
	if not (saved is Dictionary):
		return
	var row: Dictionary = saved
	_combat_rally_point = _snap_to_tile(_load_vector2(row.get("pos", WORLD_SIZE * 0.5), WORLD_SIZE * 0.5))
	if bool(row.get("exists", false)):
		_set_combat_rally_point(_combat_rally_point)

func _save_raid_state() -> Dictionary:
	return {
		"state": String(_raid_state),
		"warning_timer": _raid_warning_timer,
		"wave_size": _raid_wave_size,
		"wave_kind": String(_raid_wave_kind),
		"enemies": _save_enemies()
	}

func _save_enemies() -> Array:
	var rows: Array = []
	var groups: Array[StringName] = [&"raiders", &"zombies"]
	for group_name in groups:
		for enemy in _get_group_nodes_cached(group_name):
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.has_method("is_dead") and bool(enemy.is_dead()):
				continue
			rows.append({
				"type": "Zombie" if enemy.is_in_group("zombies") else "Raider",
				"pos": _vector2_to_save(enemy.global_position),
				"health": float(enemy.get("health")),
				"equipment": _dict_string_to_save(enemy.get_equipment_snapshot() if enemy.has_method("get_equipment_snapshot") else {})
			})
	return rows

func _save_craft_state() -> Dictionary:
	var queues: Dictionary = _craft_queues_to_save(job_system._craft_queues if job_system != null and "_craft_queues" in job_system else {})
	var interrupted_returns: Dictionary = {}
	for job in _collect_interrupted_craft_jobs():
		var ws_id: StringName = StringName(job.get("workstation_id", &""))
		var recipe_id: StringName = StringName(job.get("recipe_id", &""))
		if ws_id == &"" or recipe_id == &"" or not recipe_lookup.has(recipe_id):
			continue
		var recipe: Resource = recipe_lookup[recipe_id]
		_merge_nested_int_dict(interrupted_returns, String(ws_id), recipe.ingredients)
		if not _saved_queue_has_repeat_front(queues, ws_id, recipe_id):
			if not queues.has(String(ws_id)):
				queues[String(ws_id)] = []
			var queue: Array = queues[String(ws_id)]
			queue.insert(0, {
				"recipe_id": String(recipe_id),
				"workstation_id": String(ws_id),
				"repeat": false
			})
			queues[String(ws_id)] = queue
	_merge_carried_workstation_supply_returns(interrupted_returns)
	return {
		"queues": queues,
		"paused": _dict_bool_to_save(job_system._paused_craft_workstations if job_system != null and "_paused_craft_workstations" in job_system else {}),
		"depots": _save_workstation_depots(),
		"interrupted_returns": interrupted_returns
	}

func _collect_interrupted_craft_jobs() -> Array:
	var rows: Array = []
	var seen: Dictionary = {}
	if job_system != null and is_instance_valid(job_system) and "_jobs" in job_system:
		for job in job_system._jobs:
			_append_interrupted_craft_job(job, rows, seen)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		_append_interrupted_craft_job(colonist.get("current_job"), rows, seen)
	return rows

func _append_interrupted_craft_job(job_any: Variant, rows: Array, seen: Dictionary) -> void:
	if not (job_any is Dictionary):
		return
	var job: Dictionary = job_any
	if StringName(job.get("type", &"")) != &"CraftRecipe":
		return
	var ws_id: StringName = StringName(job.get("workstation_id", &""))
	var recipe_id: StringName = StringName(job.get("recipe_id", &""))
	if ws_id == &"" or recipe_id == &"":
		return
	var slot_id: int = int(job.get("craft_slot_id", 0))
	var sig: String = "%s|%s|%d" % [String(ws_id), String(recipe_id), slot_id]
	if seen.has(sig):
		return
	seen[sig] = true
	rows.append(job)

func _merge_carried_workstation_supply_returns(interrupted_returns: Dictionary) -> void:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var job: Dictionary = colonist.get("current_job")
		if StringName(job.get("type", &"")) != &"HaulStockpileToDepot":
			continue
		if StringName(job.get("phase", &"to_stockpile")) != &"to_depot":
			continue
		var ws_id: String = _workstation_id_for_zone_id(int(job.get("depot_id", 0)))
		var resource_type: StringName = StringName(job.get("carried_type", job.get("resource_type", &"")))
		var amount: int = int(job.get("carried_amount", 0))
		if ws_id.is_empty() or resource_type == &"" or amount <= 0:
			continue
		var values: Dictionary = {}
		values[resource_type] = amount
		_merge_nested_int_dict(interrupted_returns, ws_id, values)

func _save_workstation_depots() -> Dictionary:
	var rows: Dictionary = {}
	for ws_any in _workstation_depots.keys():
		var ws_id: StringName = StringName(ws_any)
		var depot: Node = _workstation_depots[ws_any]
		if depot == null or not is_instance_valid(depot):
			continue
		rows[String(ws_id)] = {
			"pos": _vector2_to_save(depot.global_position if depot is Node2D else Vector2.ZERO),
			"stored": _dict_int_to_save(depot.get("stored")),
			"requested": _dict_int_to_save(depot.get("requested")),
			"pending": _dict_int_to_save(depot.get("pending"))
		}
	return rows

func _track_loaded_zone(zone: Node) -> void:
	if build_system != null and is_instance_valid(build_system) and "_zones" in build_system:
		build_system._zones.append(zone)

func _track_loaded_build_site(site: Node) -> void:
	if build_system != null and is_instance_valid(build_system):
		if "_sites" in build_system:
			build_system._sites.append(site)
		if build_system.has_method("_connect_tracked_site"):
			build_system.call("_connect_tracked_site", site)
		if "_structures_cache_dirty" in build_system:
			build_system._structures_cache_dirty = true

func _seed_equipment_maps_from_colonists() -> void:
	_equipped_top_ids.clear()
	_equipped_bottom_ids.clear()
	_equipped_hat_ids.clear()
	_equipped_weapon_ids.clear()
	_equipped_weapon_kind.clear()
	_manual_equipment_slots_by_colonist.clear()
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var equipment: Dictionary = colonist.get_equipment_snapshot() if colonist.has_method("get_equipment_snapshot") else {}
		var cid: int = colonist.get_instance_id()
		var top: StringName = StringName(equipment.get(&"Top", &""))
		var bottom: StringName = StringName(equipment.get(&"Bottom", &""))
		var hat: StringName = StringName(equipment.get(&"Hat", &""))
		var weapon: StringName = StringName(equipment.get(&"Weapon", &""))
		if top != &"":
			_equipped_top_ids[cid] = true
		if bottom != &"":
			_equipped_bottom_ids[cid] = true
		if hat != &"":
			_equipped_hat_ids[cid] = true
		if weapon != &"":
			_equipped_weapon_ids[cid] = true
			_equipped_weapon_kind[cid] = weapon
		var manual_slots: Dictionary = {}
		for slot_key in [&"Top", &"Bottom", &"Hat", &"Weapon"]:
			var item_id: StringName = StringName(equipment.get(slot_key, &""))
			if item_id != &"":
				manual_slots[slot_key] = item_id
		if not manual_slots.is_empty():
			_manual_equipment_slots_by_colonist[cid] = manual_slots

func _colonist_name_for_id(colonist_id: int) -> String:
	if colonist_id == 0:
		return ""
	for colonist in colonists:
		if colonist != null and is_instance_valid(colonist) and colonist.get_instance_id() == colonist_id:
			return String(colonist.name)
	return ""

func _workstation_id_for_zone_id(zone_id: int) -> String:
	if zone_id == 0:
		return ""
	for ws_any in _workstation_depots.keys():
		var depot: Node = _workstation_depots[ws_any]
		if depot != null and is_instance_valid(depot) and depot.get_instance_id() == zone_id:
			return String(ws_any)
	return ""

func _resource_stock_from_save(saved: Variant) -> Dictionary:
	var out: Dictionary = _empty_resource_stock()
	if saved is Dictionary:
		for key_any in saved.keys():
			out[StringName(key_any)] = maxi(0, int(saved[key_any]))
	return out

func _empty_resource_stock() -> Dictionary:
	return {
		&"Wood": 0,
		&"Stone": 0,
		&"Steel": 0,
		&"FoodRaw": 0,
		&"Meal": 0,
		&"Bed": 0,
		&"GatherTop": 0,
		&"GatherBottom": 0,
		&"Handcart": 0,
		&"Bicycle": 0,
		&"StrawHat": 0,
		&"Weapon": 0,
		&"CombatTop": 0,
		&"CombatBottom": 0,
		&"CombatHat": 0,
		&"Sword": 0,
		&"Rifle": 0
	}

func _dict_int_to_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	var keys: Array = dict.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		out[String(key_any)] = int(dict[key_any])
	return out

func _dict_bool_to_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	var keys: Array = dict.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		out[String(key_any)] = bool(dict[key_any])
	return out

func _dict_string_to_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	var keys: Array = dict.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		out[String(key_any)] = String(dict[key_any])
	return out

func _string_name_int_dict_from_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	for key_any in dict.keys():
		out[StringName(key_any)] = int(dict[key_any])
	return out

func _string_name_bool_dict_from_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	for key_any in dict.keys():
		out[StringName(key_any)] = bool(dict[key_any])
	return out

func _string_name_dict_from_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	for key_any in dict.keys():
		out[StringName(key_any)] = StringName(dict[key_any])
	return out

func _string_name_array_to_save(input: Variant) -> Array:
	var out: Array = []
	if not (input is Array):
		return out
	for value in input:
		out.append(String(value))
	return out

func _string_name_array_from_save(input: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if not (input is Array):
		return out
	for value in input:
		out.append(StringName(value))
	return out

func _vector2_to_save(value: Vector2) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _load_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Dictionary:
		var dict: Dictionary = value
		return Vector2(float(dict.get("x", fallback.x)), float(dict.get("y", fallback.y)))
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	return fallback

func _vector2i_to_save(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

func _load_vector2i(value: Variant, fallback: Vector2i) -> Vector2i:
	if value is Dictionary:
		var dict: Dictionary = value
		return Vector2i(int(dict.get("x", fallback.x)), int(dict.get("y", fallback.y)))
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Vector2i:
		return value
	return fallback

func _color_to_save(value: Color) -> Dictionary:
	return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}

func _load_color(value: Variant, fallback: Color) -> Color:
	if not (value is Dictionary):
		return fallback
	var dict: Dictionary = value
	return Color(
		float(dict.get("r", fallback.r)),
		float(dict.get("g", fallback.g)),
		float(dict.get("b", fallback.b)),
		float(dict.get("a", fallback.a))
	)

func _plots_to_save(input: Variant) -> Array:
	var rows: Array = []
	if not (input is Dictionary):
		return rows
	var plots: Dictionary = input
	var keys: Array = plots.keys()
	keys.sort_custom(func(a, b):
		var av: Vector2i = a
		var bv: Vector2i = b
		if av.y == bv.y:
			return av.x < bv.x
		return av.y < bv.y
	)
	for tile_any in keys:
		var tile: Vector2i = tile_any
		var plot: Dictionary = plots[tile_any]
		rows.append({
			"tile": _vector2i_to_save(tile),
			"state": String(plot.get("state", &"Empty")),
			"crop": String(plot.get("crop", &"")),
			"elapsed": float(plot.get("elapsed", 0.0)),
			"last_crop": String(plot.get("last_crop", &"")),
			"consecutive_crop": int(plot.get("consecutive_crop", 0)),
			"rotation_mult": float(plot.get("rotation_mult", 1.0))
		})
	return rows

func _plots_from_save(rows: Variant) -> Dictionary:
	var plots: Dictionary = {}
	if not (rows is Array):
		return plots
	for row_any in rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var tile: Vector2i = _load_vector2i(row.get("tile", Vector2i.ZERO), Vector2i.ZERO)
		plots[tile] = {
			"state": StringName(row.get("state", "Empty")),
			"crop": StringName(row.get("crop", "")),
			"elapsed": maxf(0.0, float(row.get("elapsed", 0.0))),
			"job_queued": false,
			"last_crop": StringName(row.get("last_crop", "")),
			"consecutive_crop": maxi(0, int(row.get("consecutive_crop", 0))),
			"rotation_mult": maxf(0.1, float(row.get("rotation_mult", 1.0)))
		}
	return plots

func _craft_queues_to_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	var keys: Array = dict.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for ws_any in keys:
		var rows: Array = []
		var queue_any: Variant = dict[ws_any]
		if queue_any is Array:
			for item_any in queue_any:
				if not (item_any is Dictionary):
					continue
				var item: Dictionary = item_any
				rows.append({
					"recipe_id": String(item.get("recipe_id", "")),
					"workstation_id": String(item.get("workstation_id", ws_any)),
					"repeat": bool(item.get("repeat", false))
				})
		out[String(ws_any)] = rows
	return out

func _craft_queues_from_save(input: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (input is Dictionary):
		return out
	var dict: Dictionary = input
	for ws_any in dict.keys():
		var ws_id: StringName = StringName(ws_any)
		var queue: Array = []
		var saved_queue: Variant = dict[ws_any]
		if saved_queue is Array:
			for item_any in saved_queue:
				if not (item_any is Dictionary):
					continue
				var item: Dictionary = item_any
				var recipe_id: StringName = StringName(item.get("recipe_id", ""))
				if recipe_id == &"":
					continue
				queue.append({
					"recipe_id": recipe_id,
					"workstation_id": StringName(item.get("workstation_id", String(ws_id))),
					"repeat": bool(item.get("repeat", false))
				})
		out[ws_id] = queue
	return out

func _saved_queue_has_repeat_front(queues: Dictionary, workstation_id: StringName, recipe_id: StringName) -> bool:
	var key: String = String(workstation_id)
	if not queues.has(key):
		return false
	var queue: Array = queues[key]
	if queue.is_empty():
		return false
	var front: Dictionary = queue[0]
	return bool(front.get("repeat", false)) and StringName(front.get("recipe_id", "")) == recipe_id

func _merge_nested_int_dict(target: Dictionary, nested_key: String, values: Dictionary) -> void:
	if not target.has(nested_key):
		target[nested_key] = {}
	var nested: Dictionary = target[nested_key]
	for key_any in values.keys():
		var amount: int = int(values[key_any])
		if amount <= 0:
			continue
		var key: String = String(key_any)
		nested[key] = int(nested.get(key, 0)) + amount
	target[nested_key] = nested

func _make_loaded_block_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(maxi(8, w), maxi(8, h), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _queue_event_dispatch() -> void:
	if not is_inside_tree():
		return
	if _dispatch_queued:
		return
	_dispatch_queued = true
	call_deferred("_dispatch_event_updates")

func _has_pending_dispatch() -> bool:
	return _dispatch_pathing_dirty \
		or _dispatch_combat_dirty \
		or _dispatch_traps_dirty \
		or _dispatch_farm_dirty \
		or _dispatch_maintenance_dirty \
		or _dispatch_economy_dirty \
		or _dispatch_jobs_dirty \
		or _hud_dirty \
		or _hud_time_dirty \
		or _hud_selection_dirty

func _clear_pending_dispatch_state() -> void:
	_dispatch_queued = false
	_dispatch_pathing_dirty = false
	_dispatch_combat_dirty = false
	_dispatch_traps_dirty = false
	_dispatch_farm_dirty = false
	_dispatch_maintenance_dirty = false
	_dispatch_economy_dirty = false
	_dispatch_jobs_dirty = false
	_hud_dirty = false
	_hud_time_dirty = false
	_hud_selection_dirty = false

func _mark_pathing_dirty() -> void:
	_dispatch_pathing_dirty = true
	_workstation_slots_dirty = true
	_structure_maintenance_dirty = true
	_mark_all_group_cache_dirty()
	_queue_event_dispatch()

func _on_pathing_occupancy_revision_changed(revision: int) -> void:
	if _enemy_flow_field_service != null and is_instance_valid(_enemy_flow_field_service):
		_enemy_flow_field_service.notify_obstacle_revision(revision)

func _mark_jobs_dirty() -> void:
	_dispatch_jobs_dirty = true
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_assign_dirty"):
		job_system.mark_assign_dirty()
	_queue_event_dispatch()

func _mark_combat_dirty() -> void:
	_dispatch_combat_dirty = true
	_dispatch_traps_dirty = true
	_mark_group_cache_dirty(&"raiders")
	_mark_group_cache_dirty(&"zombies")
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_combat_dirty"):
		job_system.mark_combat_dirty()
	_queue_event_dispatch()

func _mark_economy_dirty() -> void:
	_dispatch_economy_dirty = true
	_structure_maintenance_dirty = true
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_haul_dirty"):
		job_system.mark_haul_dirty()
	_queue_event_dispatch()

func _mark_maintenance_dirty() -> void:
	_dispatch_maintenance_dirty = true
	_structure_maintenance_dirty = true
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_repair_dirty"):
		job_system.mark_repair_dirty()
	_queue_event_dispatch()

func _mark_farm_dirty() -> void:
	_dispatch_farm_dirty = true
	_queue_event_dispatch()

func _mark_hud_time_dirty() -> void:
	_hud_time_dirty = true
	_queue_event_dispatch()

func _mark_hud_selection_dirty() -> void:
	_hud_selection_dirty = true
	_queue_event_dispatch()

func _check_job_liveness_watchdog() -> void:
	if job_system == null or not is_instance_valid(job_system):
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _job_liveness_next_ms:
		return
	_job_liveness_next_ms = now_ms + 500
	if _dispatch_jobs_dirty:
		return
	if not job_system.has_method("has_pending_assignment") or bool(job_system.has_pending_assignment()):
		return
	if not job_system.has_method("has_unassigned_jobs") or not bool(job_system.has_unassigned_jobs()):
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not colonist.is_idle():
			continue
		_mark_jobs_dirty()
		return

func _dispatch_event_updates() -> void:
	_dispatch_queued = false
	if not is_inside_tree():
		_clear_pending_dispatch_state()
		return
	if not _has_pending_dispatch():
		return
	var dispatch_start_us: int = Time.get_ticks_usec()
	var dt_pathing_us: int = 0
	var dt_combat_us: int = 0
	var dt_traps_us: int = 0
	var dt_farm_us: int = 0
	var dt_maint_us: int = 0
	var dt_econ_us: int = 0
	var dt_jobs_us: int = 0
	var dt_hud_us: int = 0
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _dispatch_pathing_dirty:
		var t_us: int = Time.get_ticks_usec()
		_pathing_occupancy.notify_world_changed()
		_dispatch_pathing_dirty = false
		if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_spatial_dirty"):
			job_system.mark_spatial_dirty()
		dt_pathing_us = Time.get_ticks_usec() - t_us
	if _dispatch_combat_dirty:
		var t_us: int = Time.get_ticks_usec()
		_cached_alive_enemies = _get_alive_raiders()
		_enemy_sim_interval_scale = _compute_enemy_sim_interval_scale(_cached_alive_enemies.size())
		_apply_enemy_sim_budget(_cached_alive_enemies, _enemy_sim_interval_scale)
		_friendly_pathing_budget_scale = _compute_friendly_pathing_budget_scale(_cached_alive_enemies.size())
		_apply_friendly_pathing_budget(_friendly_pathing_budget_scale)
		_apply_day_night_to_enemies(_cached_alive_enemies)
		_dispatch_traps_dirty = true
		_dispatch_combat_dirty = false
		dt_combat_us = Time.get_ticks_usec() - t_us
	if _dispatch_traps_dirty and _raid_state == &"Active":
		var t_us: int = Time.get_ticks_usec()
		var trap_delta: float = maxf(0.02, _trap_update_accum)
		_trap_update_accum = 0.0
		# Emergency guard: when frame budget collapses, skip trap simulation first.
		if Engine.get_frames_per_second() >= 45.0:
			_update_defense_traps(trap_delta, _cached_alive_enemies)
		_dispatch_traps_dirty = false
		dt_traps_us = Time.get_ticks_usec() - t_us
	if _dispatch_farm_dirty:
		var t_us: int = Time.get_ticks_usec()
		_produce_farm_jobs()
		_dispatch_farm_dirty = false
		dt_farm_us = Time.get_ticks_usec() - t_us
	if _dispatch_maintenance_dirty:
		var t_us: int = Time.get_ticks_usec()
		_refresh_structure_integrity()
		_apply_passive_item_bonuses()
		_dispatch_maintenance_dirty = false
		dt_maint_us = Time.get_ticks_usec() - t_us
	if _dispatch_economy_dirty:
		var t_us: int = Time.get_ticks_usec()
		_reconcile_stockpile_totals_with_resource_stock()
		_dispatch_economy_dirty = false
		dt_econ_us = Time.get_ticks_usec() - t_us
	if _dispatch_jobs_dirty:
		var t_us: int = Time.get_ticks_usec()
		var now_jobs_ms: int = Time.get_ticks_msec()
		var throttled: bool = _raid_state == &"Active" and now_jobs_ms < _active_jobs_next_ms
		if not throttled:
			var enemies: Array = _cached_alive_enemies
			var rally_pos: Vector2 = Vector2.INF
			if _rally_flag_node != null and is_instance_valid(_rally_flag_node):
				if _outfit_mode == &"Combat" or _raid_state == &"Active":
					rally_pos = _combat_rally_point
			var max_combatants: int = mini(maxi(2, enemies.size() * 2), maxi(2, colonists.size()))
			if _raid_state != &"Active" and _outfit_mode != &"Combat":
				enemies = _get_workmode_threat_enemies(enemies)
				max_combatants = mini(maxi(1, enemies.size()), 2)
			elif _raid_state == &"Active":
				max_combatants = mini(12, mini(maxi(2, enemies.size() * 2), maxi(2, colonists.size())))
				_active_jobs_next_ms = now_jobs_ms + 180
			job_system.set_haul_urgency_multiplier(_haul_urgency_multiplier_by_colony_state())
			var haul_targets: Array = _get_group_nodes_cached(&"stockpile_zones").duplicate()
			for depot in _workstation_depots.values():
				if depot != null and is_instance_valid(depot):
					haul_targets.append(depot)
			if _raid_state != &"Active":
				_update_workstation_supply_requests()
			if build_system != null and is_instance_valid(build_system):
				build_system.request_build_jobs(job_system)
			var drops: Array = _get_group_nodes_cached(&"resource_drops")
			var workstation_slots: Dictionary = _get_cached_workstation_slots_map()
			var repairables: Array = _get_damaged_repairable_structures()
			var traps: Array = _get_maintainable_traps()
			var gatherables: Array = _get_group_nodes_cached(&"gatherables")
			var huntables: Array = _get_group_nodes_cached(&"huntables")
			var keep_jobs_dirty: bool = false
			if job_system.has_method("process_producers"):
				job_system.process_producers(
					colonists,
					enemies,
					drops,
					haul_targets,
					resource_stock,
					target_stock,
					rally_pos,
					TILE_SIZE * 3.0,
					max_combatants,
					recipe_lookup,
					workstation_slots,
					Callable(self, "_can_start_recipe_at_workstation"),
					Callable(self, "_on_recipe_started_at_workstation"),
					_find_research_bench_pos(),
					_active_research_id if _research_running else &"",
					repairables,
					traps,
					gatherables,
					huntables,
					_raid_state == &"Active",
					Callable(self, "_is_valid_formation_slot"),
					_find_research_bench_positions()
				)
				job_system.process_assignment(colonists)
				if job_system.has_method("has_pending_assignment"):
					keep_jobs_dirty = bool(job_system.has_pending_assignment())
			else:
				job_system.process_dirty(
					colonists,
					enemies,
					drops,
					haul_targets,
					resource_stock,
					target_stock,
					rally_pos,
					TILE_SIZE * 3.0,
					max_combatants,
					recipe_lookup,
					workstation_slots,
					Callable(self, "_can_start_recipe_at_workstation"),
					Callable(self, "_on_recipe_started_at_workstation"),
					_find_research_bench_pos(),
					_active_research_id if _research_running else &"",
					repairables,
					traps,
					gatherables,
					huntables,
					_raid_state == &"Active",
					Callable(self, "_is_valid_formation_slot"),
					_find_research_bench_positions()
				)
			_dispatch_jobs_dirty = keep_jobs_dirty
		dt_jobs_us = Time.get_ticks_usec() - t_us
	if _hud_dirty:
		var t_us: int = Time.get_ticks_usec()
		hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))
		_refresh_hud_time_status()
		hud.set_research_state(_active_research_id, _active_research_points, _active_research_required_points(), _research_completed)
		_refresh_hud()
		_hud_dirty = false
		_hud_time_dirty = false
		_hud_selection_dirty = false
		dt_hud_us = Time.get_ticks_usec() - t_us
	elif _hud_time_dirty or _hud_selection_dirty:
		var t_us: int = Time.get_ticks_usec()
		if _hud_time_dirty:
			_refresh_hud_time_status()
			_hud_time_dirty = false
		if _hud_selection_dirty:
			_refresh_selected_colonist_hud()
			_hud_selection_dirty = false
		dt_hud_us = Time.get_ticks_usec() - t_us
	var dt_total_us: int = Time.get_ticks_usec() - dispatch_start_us
	if _simulation_dispatch_service != null and is_instance_valid(_simulation_dispatch_service):
		_simulation_dispatch_service.report_hitch(
			_perf_logging_enabled,
			_raid_state,
			dt_total_us,
			dt_pathing_us,
			dt_combat_us,
			dt_traps_us,
			dt_farm_us,
			dt_maint_us,
			dt_econ_us,
			dt_jobs_us,
			dt_hud_us,
			_cached_alive_enemies.size()
		)
	elif _perf_logging_enabled and _raid_state == &"Active" and dt_total_us >= 40000:
		print("[Perf][Hitch][Dispatch] total=%.2f path=%.2f combat=%.2f traps=%.2f farm=%.2f maint=%.2f econ=%.2f jobs=%.2f hud=%.2f enemies=%d" % [
			float(dt_total_us) / 1000.0,
			float(dt_pathing_us) / 1000.0,
			float(dt_combat_us) / 1000.0,
			float(dt_traps_us) / 1000.0,
			float(dt_farm_us) / 1000.0,
			float(dt_maint_us) / 1000.0,
			float(dt_econ_us) / 1000.0,
			float(dt_jobs_us) / 1000.0,
			float(dt_hud_us) / 1000.0,
			_cached_alive_enemies.size()
		])

func _has_demolish_queued_structure() -> bool:
	for node in _get_group_nodes_cached(&"structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("demolish_job_queued"):
			continue
		if node.get_meta("demolish_job_queued") == true:
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
			KEY_R:
				if pending_building_id != &"":
					_rotate_pending_building()
					return
				_toggle_selected_combat_ready()
				return
			KEY_ESCAPE:
				_clear_pending_placement()
				if hud != null and is_instance_valid(hud) and hud.has_method("reset_bottom_catalog_state"):
					hud.reset_bottom_catalog_state()
				else:
					_close_bottom_catalog_if_supported()
				_on_action_changed(&"Interact")
				return
	var was_dragging: bool = input_controller.dragging
	input_controller.process_unhandled_input(event, world_root)
	if event is InputEventMouseMotion and input_controller.dragging:
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and was_dragging:
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
		_colonist_idle_state_by_id[c.get_instance_id()] = true
		c.resource_harvested.connect(_on_resource_harvested)
		c.resource_delivered.connect(_on_resource_delivered)
		c.workstation_supply_picked.connect(_on_workstation_supply_picked)
		c.workstation_supply_delivered.connect(_on_workstation_supply_delivered)
		c.workstation_supply_returned.connect(_on_workstation_supply_returned)
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

func _apply_starting_loadout(loadout: ColonistLoadoutData) -> void:
	var count: int = colonists.size()
	var slot_map: Dictionary = {
		&"weapon": loadout.weapon,
		&"top": loadout.top,
		&"bottom": loadout.bottom,
		&"hat": loadout.hat
	}
	for slot_key in slot_map:
		var item_id: StringName = slot_map[slot_key]
		if item_id == &"":
			continue
		if not resource_stock.has(item_id):
			resource_stock[item_id] = 0
		resource_stock[item_id] = int(resource_stock[item_id]) + count
	for item_id in loadout.starting_inventory:
		var qty: int = int(loadout.starting_inventory[item_id])
		if qty <= 0:
			continue
		if not resource_stock.has(item_id):
			resource_stock[item_id] = 0
		resource_stock[item_id] = int(resource_stock[item_id]) + qty

func _on_left_click(world_pos: Vector2) -> void:
	if current_action == &"SetRallyFlag":
		_set_combat_rally_point(world_pos)
		_on_action_changed(&"Interact")
		return
	hud.hide_context_action_button()
	selected_farm_zone = null
	var stockpile_item: Dictionary = _find_stockpile_item_at(world_pos)
	if not stockpile_item.is_empty():
		_select_stockpile_item(stockpile_item)
		return
	var bed_node: Node = _find_installed_bed_near(world_pos, 42.0)
	if bed_node != null:
		_clear_selected_object()
		_set_selected([])
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		selected_stockpile_zone = null
		selected_farm_zone = null
		selected_bed_node = bed_node
		hud.set_selected_status_visible(true)
		_refresh_bed_assign_ui()
		hud.set_active_action(&"BedSelected")
		_close_bottom_catalog_if_supported()
		return
	if current_action == &"StockpileZone":
		_clear_selected_object()
		_select_stockpile_zone_near(world_pos)
		if selected_stockpile_zone != null and is_instance_valid(selected_stockpile_zone):
			hud.set_active_action(&"StockpileDesignate")
			_close_bottom_catalog_if_supported()
			return
		_on_action_changed(&"Interact")
	if current_action == &"FarmZone":
		_clear_selected_object()
		_set_selected([])
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		selected_stockpile_zone = null
		selected_bed_node = null
		selected_farm_zone = _find_farm_zone_near(world_pos, 48.0)
		if selected_farm_zone != null:
			_configure_farm_zone_catalog(selected_farm_zone)
			_selected_object_kind = &"FarmZone"
			_selected_object_zone = selected_farm_zone
			_selected_object_resource = &""
			hud.set_active_action(&"FarmZoneSelected")
			_open_farm_catalog_if_supported(selected_farm_zone)
			_refresh_hud()
			return
		_on_action_changed(&"Interact")
		_close_bottom_catalog_if_supported()
		_refresh_hud()
	selected_bed_node = null
	hud.set_bed_assignment_visible(false)

	if pending_building_id != &"":
		_try_place_building_by_id(world_pos, pending_building_id)
		_refresh_hud()
		return

	var clicked: Node = _find_colonist_near(world_pos, 30.0)
	if clicked != null:
		_clear_selected_object()
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_set_selected([clicked])
		hud.set_active_action(&"UnitSelected")
		_close_bottom_catalog_if_supported()
		return

	var drop: Node = _find_resource_drop_near(world_pos, TILE_SIZE * 0.75)
	if drop != null:
		var drop_type: StringName = StringName(drop.get("resource_type"))
		if drop_type == &"Bed" or drop_type == &"Handcart" or _is_vehicle_item(drop_type):
			_clear_selected_object()
			pending_install_item = drop_type
			pending_install_drop_id = drop.get_instance_id()
			hud.set_active_action(&"Install%s" % String(drop_type))
			_close_bottom_catalog_if_supported()
			return
		_clear_selected_object()
		_set_selected([])
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		selected_stockpile_zone = null
		selected_farm_zone = null
		selected_bed_node = null
		hud.set_bed_assignment_visible(false)
		_selected_object_kind = &"ResourceDrop"
		_selected_object_zone = drop
		_selected_object_resource = drop_type
		_refresh_hud()
		hud.set_active_action(&"ResourceDropSelected")
		_close_bottom_catalog_if_supported()
		return

	var gatherable: Node = _find_gatherable_near(world_pos, 48.0)
	if gatherable != null:
		_clear_selected_object()
		selected_designation_target = gatherable
		_refresh_designation_ui()
		hud.set_active_action(&"GatherTarget")
		_close_bottom_catalog_if_supported()
		return

	var huntable: Node = _find_huntable_near(world_pos, 52.0)
	if huntable != null:
		_clear_selected_object()
		selected_designation_target = huntable
		_refresh_designation_ui()
		hud.set_active_action(&"HuntTarget")
		_close_bottom_catalog_if_supported()
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
		_open_research_catalog_if_supported()
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
	var keep_build_catalog_open: bool = pending_building_id != &"" and hud.is_bottom_catalog_visible() and hud.get_bottom_catalog_mode() == &"Build"
	if not keep_build_catalog_open:
		_close_bottom_catalog_if_supported()

	if pending_install_item != &"":
		if _try_install_pending_item(world_pos):
			_clear_pending_placement()
		_refresh_hud()
		_close_bottom_catalog_if_supported()
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
		_close_bottom_catalog_if_supported()
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
		_close_bottom_catalog_if_supported()
		return

	var clicked_zone: Node = _find_stockpile_zone_near(world_pos, TILE_SIZE * 0.75)
	if clicked_zone != null:
		selected_designation_target = null
		hud.set_designation_panel_visible(false)
		_set_selected([])
		selected_stockpile_zone = clicked_zone
		_clear_selected_object()
		_refresh_stockpile_filter_ui()
		hud.set_active_action(&"Stockpile")
		_close_bottom_catalog_if_supported()
		return
	else:
		selected_stockpile_zone = null

	var clicked_farm: Node = _find_farm_zone_near(world_pos, TILE_SIZE * 0.75)
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
		_open_farm_catalog_if_supported(clicked_farm)
		return
	else:
		selected_farm_zone = null

	_set_selected([])
	_clear_selected_object()
	selected_designation_target = null
	hud.set_designation_panel_visible(false)
	hud.set_active_action(&"Interact")
	_refresh_stockpile_filter_ui()
	_close_bottom_catalog_if_supported()

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
		var changed: bool = false
		for node in get_tree().get_nodes_in_group("gatherables"):
			if node == null or not is_instance_valid(node):
				continue
			if not rect.has_point(node.global_position):
				continue
			if node.has_method("set_designated"):
				node.set_designated(true)
				changed = true
		for node in get_tree().get_nodes_in_group("huntables"):
			if node == null or not is_instance_valid(node):
				continue
			if not rect.has_point(node.global_position):
				continue
			if node.has_method("set_designated"):
				node.set_designated(true)
				changed = true
		if changed:
			job_system.mark_designation_dirty()
			_mark_jobs_dirty()
		_close_bottom_catalog_if_supported()
		queue_redraw()
		return
	if current_action == &"StockpileZone":
		if build_system.place_stockpile_zone(rect):
			_select_stockpile_zone_near(rect.get_center())
		_close_bottom_catalog_if_supported()
		queue_redraw()
		return
	if current_action == &"FarmZone":
		if build_system.place_farm_zone(rect):
			selected_farm_zone = _find_farm_zone_near(rect.get_center(), 96.0)
			_configure_farm_zone_catalog(selected_farm_zone)
			_open_farm_catalog_if_supported(selected_farm_zone)
		else:
			_close_bottom_catalog_if_supported()
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
	_close_bottom_catalog_if_supported()
	queue_redraw()

func _set_selected(new_selection: Array) -> void:
	var prev_ids: Dictionary = {}
	for c_prev in selected_colonists:
		if c_prev == null or not is_instance_valid(c_prev):
			continue
		prev_ids[c_prev.get_instance_id()] = true
	var next_ids: Dictionary = {}
	for c_next in new_selection:
		if c_next == null or not is_instance_valid(c_next):
			continue
		next_ids[c_next.get_instance_id()] = true
	var selection_changed: bool = prev_ids.size() != next_ids.size()
	if not selection_changed:
		for id_any in prev_ids.keys():
			if not next_ids.has(id_any):
				selection_changed = true
				break
	for c in selected_colonists:
		if c != null and is_instance_valid(c):
			c.set_selected(false)
	selected_colonists.clear()
	for c in new_selection:
		if c == null or not is_instance_valid(c):
			continue
		selected_colonists.append(c)
	for c in selected_colonists:
		c.set_selected(true)
	if selection_changed:
		_mark_jobs_dirty()
		_mark_combat_dirty()
	_hud_dirty = true
	_refresh_hud()

func _toggle_selected_combat_ready() -> void:
	_sanitize_selected_colonists()
	if selected_colonists.is_empty():
		return
	var enable_ready: bool = false
	for c in selected_colonists:
		if c == null or not is_instance_valid(c):
			continue
		if not bool(c.get("combat_ready")):
			enable_ready = true
			break
	for c in selected_colonists:
		if c == null or not is_instance_valid(c):
			continue
		if enable_ready and c.has_method("set_work_enabled"):
			c.set_work_enabled(&"Combat", true)
		if job_system != null and is_instance_valid(job_system) and job_system.has_method("clear_jobs_for_colonist"):
			job_system.clear_jobs_for_colonist(c.get_instance_id())
		if c.has_method("set_combat_ready"):
			c.set_combat_ready(enable_ready)
		else:
			c.set("combat_ready", enable_ready)
	_hud_dirty = true
	_hud_selection_dirty = true
	_mark_jobs_dirty()
	_mark_combat_dirty()
	_refresh_hud()

func _maybe_start_auto_raid_benchmark() -> void:
	if not _is_auto_raid_benchmark_enabled():
		return
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if not is_inside_tree():
			return
		if _raid_state == &"Idle" or _raid_state == &"Resolved":
			_start_raid_warning()
	)

func _is_perf_logging_enabled() -> bool:
	if OS.get_environment("PERF_LOGS") == "1":
		return true
	return _is_auto_raid_benchmark_enabled()

func _is_auto_raid_benchmark_enabled() -> bool:
	if OS.get_environment("AUTO_RAID_BENCH") == "1":
		return true
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		if arg == "--auto_raid_bench":
			return true
	return false

func _on_command_move(world_pos: Vector2) -> void:
	_sanitize_selected_colonists()
	if selected_colonists.is_empty():
		return
	_issue_selected_move_command(world_pos)
	_mark_jobs_dirty()
	_mark_combat_dirty()

func _find_colonist_near(world_pos: Vector2, radius: float) -> Node:
	for colonist in colonists:
		if colonist.global_position.distance_to(world_pos) <= radius:
			return colonist
	return null

func _find_colonist_by_id(colonist_id: int) -> Node:
	if colonist_id == 0:
		return null
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.get_instance_id() == colonist_id:
			return colonist
	return null

func _build_colonist_roster_entries() -> Array:
	var selected_ids: Dictionary = {}
	for c in selected_colonists:
		if c == null or not is_instance_valid(c):
			continue
		selected_ids[c.get_instance_id()] = true
	var out: Array = []
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		var alive: bool = true
		if c.has_method("is_dead"):
			alive = not bool(c.is_dead())
		out.append({
			"id": c.get_instance_id(),
			"name": c.name,
			"selected": bool(selected_ids.get(c.get_instance_id(), false)),
			"combat_ready": bool(c.get("combat_ready")),
			"alive": alive
		})
	return out

func _close_bottom_catalog_if_supported() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if hud.has_method("close_bottom_catalog"):
		hud.close_bottom_catalog()

func _open_research_catalog_if_supported() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if not hud.has_method("open_bottom_catalog"):
		return
	hud.open_bottom_catalog(&"Research")

func _open_farm_catalog_if_supported(zone: Node) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if not hud.has_method("open_bottom_catalog"):
		return
	var crop_options: Array = []
	var selected_crop: StringName = &""
	var crop_name: String = _t("common.unselected")
	if zone != null and is_instance_valid(zone):
		if zone.has_method("get_crop_options"):
			crop_options = zone.get_crop_options()
		if zone.has_method("get_crop_type"):
			selected_crop = StringName(zone.get_crop_type())
		if zone.has_method("get_crop_display_name"):
			crop_name = String(zone.get_crop_display_name())
	if hud.has_method("set_farm_catalog"):
		hud.set_farm_catalog(crop_options, selected_crop, _t("main.farm.catalog.description"))
	hud.open_bottom_catalog(&"Farm", _t("main.farm.current_crop", {"crop": crop_name}))

func _open_craft_catalog_if_supported() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if hud.has_method("open_bottom_catalog"):
		hud.open_bottom_catalog(&"Craft", _t("main.craft.catalog.description"))

func _on_hud_portrait_selected(colonist_id: int) -> void:
	var colonist: Node = _find_colonist_by_id(colonist_id)
	if colonist == null:
		return
	_clear_selected_object()
	selected_designation_target = null
	selected_stockpile_zone = null
	selected_farm_zone = null
	selected_bed_node = null
	hud.set_designation_panel_visible(false)
	hud.set_bed_assignment_visible(false)
	_on_action_changed(&"Interact")
	_set_selected([colonist])
	hud.set_active_action(&"UnitSelected")
	_close_bottom_catalog_if_supported()

func _on_hud_catalog_item_activated(_mode: StringName, _item_id: StringName) -> void:
	_hud_dirty = true

func _on_hud_action_button_pressed(action_id: StringName) -> void:
	if action_id != &"BuildCatalogToggle":
		return
	# Build tab toggle should always reset current building choice so reopening starts unselected.
	pending_building_id = &""
	pending_building_rotation = 0
	hud.set_selected_building(&"")
	_hud_dirty = true

func _refresh_hud() -> void:
	_sanitize_selected_colonists()
	hud.set_selected_count(selected_colonists.size())
	hud.set_resource_stock(resource_stock)
	if hud.has_method("set_colonist_roster"):
		hud.set_colonist_roster(_build_colonist_roster_entries())
	var focus: Node = selected_colonists[0] if not selected_colonists.is_empty() else null
	var stockpile_focus: Node = selected_stockpile_zone if selected_stockpile_zone != null and is_instance_valid(selected_stockpile_zone) else null
	var farm_focus: Node = selected_farm_zone if selected_farm_zone != null and is_instance_valid(selected_farm_zone) else null
	var bed_focus: Node = selected_bed_node if selected_bed_node != null and is_instance_valid(selected_bed_node) else null
	var object_focus: bool = _selected_object_kind != &"" and _selected_object_zone != null and is_instance_valid(_selected_object_zone)
	hud.set_research_panel_visible(object_focus and _selected_object_kind == &"ResearchBench")
	hud.set_selected_status_visible(focus != null or stockpile_focus != null or farm_focus != null or bed_focus != null or object_focus)
	hud.set_needs_preview(focus)
	hud.set_priority_preview(focus)
	hud.set_current_job_preview(focus)
	hud.set_carry_capacity_preview(focus)
	hud.set_equipment_preview(focus)
	if focus != null:
		hud.set_stockpile_inventory_preview(null)
	elif farm_focus != null:
		var crop_name: String = _t("common.unselected")
		var crop_options: Array = []
		var selected_crop: StringName = &""
		if farm_focus.has_method("get_crop_display_name"):
			crop_name = String(farm_focus.get_crop_display_name())
		if farm_focus.has_method("get_crop_options"):
			crop_options = farm_focus.get_crop_options()
		if farm_focus.has_method("get_crop_type"):
			selected_crop = StringName(farm_focus.get_crop_type())
		if hud.has_method("set_farm_catalog"):
			hud.set_farm_catalog(crop_options, selected_crop, _t("main.farm.catalog.description"))
		hud.set_selected_object_preview(
			_t("main.selected.farm.title"),
			_t("main.selected.farm.detail", {"crop": crop_name}),
			[{"id": &"DeleteFarmZone", "label": _t("hud.stock.delete")}]
		)
	elif object_focus:
		if _selected_object_kind == &"ResearchBench":
			var progress_text: String = _t("main.research.progress.none")
			if _active_research_id != &"":
				progress_text = "%s %.0f / %.0f" % [
					String(_active_research_id),
					_active_research_points,
					_active_research_required_points()
				]
			hud.set_selected_object_preview(
				_t("main.selected.research.title"),
				_t("main.selected.research.detail", {"progress": progress_text}),
				[]
			)
		elif _selected_object_kind == &"BuildSite":
			var bid_site: StringName = StringName(_selected_object_zone.get("building_id"))
			var work_need: float = float(_selected_object_zone.get("required_work"))
			var work_done: float = float(_selected_object_zone.get("work_progress"))
			hud.set_selected_object_preview(
				_t("main.selected.blueprint.title", {"id": String(bid_site)}),
				_t("main.selected.buildsite.detail", {"done": "%.1f" % work_done, "need": "%.1f" % work_need}),
				[{"id": &"CancelBuildSite", "label": _t("main.action.cancel_build")}]
			)
		elif _selected_object_kind == &"Structure":
			var building_id: StringName = StringName(_selected_object_zone.get_meta("building_id")) if _selected_object_zone.has_meta("building_id") else &"Structure"
			var hp: float = float(_selected_object_zone.get_meta("structure_health")) if _selected_object_zone.has_meta("structure_health") else 0.0
			var max_hp: float = float(_selected_object_zone.get_meta("structure_max_health")) if _selected_object_zone.has_meta("structure_max_health") else hp
			var detail: String = _t("main.selected.structure.detail", {"id": String(building_id), "hp": "%.0f" % hp, "max_hp": "%.0f" % max_hp})
			hud.set_selected_object_preview(
				"Selected: %s" % String(building_id),
				detail,
				[{"id": &"DemolishSelectedStructure", "label": _t("main.action.demolish")}]
			)
		elif _selected_object_kind == &"ResourceDrop":
			var drop_amount: int = int(_selected_object_zone.get("amount"))
			var title: String = _t("main.selected.resource.title", {"resource": String(_selected_object_resource)})
			var detail: String = _t("main.selected.resource.detail", {"amount": drop_amount})
			hud.set_selected_object_preview(title, detail, [])
		else:
			var amount: int = 0
			if _selected_object_zone.has_method("get_stored_amount"):
				amount = int(_selected_object_zone.get_stored_amount(_selected_object_resource))
			var title: String = _t("main.selected.resource.title", {"resource": String(_selected_object_resource)})
			var detail: String = _t("main.selected.resource.detail", {"amount": amount})
			var actions: Array = []
			if _selected_object_resource == &"Bed" and amount > 0:
				actions.append({"id": &"PlaceBedFromStockpile", "label": _t("main.action.place_bed")})
			elif _selected_object_resource == &"Handcart" and amount > 0:
				actions.append({"id": &"PlaceHandcartFromStockpile", "label": "Place Handcart"})
			elif _is_vehicle_item(_selected_object_resource) and amount > 0:
				actions.append({"id": &"PlaceVehicleFromStockpile", "label": "Place %s" % String(_selected_object_resource)})
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

func _refresh_hud_time_status() -> void:
	hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
	hud.set_raid_state(_raid_state, _raid_warning_timer, _raid_wave_kind)
	hud.set_defense_status(_defense_status_text)

func _refresh_selected_colonist_hud() -> void:
	_sanitize_selected_colonists()
	var focus: Node = selected_colonists[0] if not selected_colonists.is_empty() else null
	if focus == null:
		return
	hud.set_selected_status_visible(true)
	hud.set_needs_preview(focus)
	hud.set_priority_preview(focus)
	hud.set_current_job_preview(focus)
	hud.set_carry_capacity_preview(focus)
	hud.set_equipment_preview(focus)
	hud.set_stockpile_inventory_preview(null)
	hud.set_work_toggles(focus.work_enabled)

func _is_selected_colonist(colonist: Node) -> bool:
	if colonist == null or not is_instance_valid(colonist):
		return false
	var colonist_id: int = colonist.get_instance_id()
	for selected_colonist in selected_colonists:
		if selected_colonist == null or not is_instance_valid(selected_colonist):
			continue
		if selected_colonist.get_instance_id() == colonist_id:
			return true
	return false

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
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _on_work_toggle_changed(work_type: StringName, enabled: bool) -> void:
	_sanitize_selected_colonists()
	for c in selected_colonists:
		if c == null or not is_instance_valid(c):
			continue
		c.set_work_enabled(work_type, enabled)
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _on_colonist_status_changed(_colonist: Node) -> void:
	if _colonist != null and is_instance_valid(_colonist):
		var cid: int = _colonist.get_instance_id()
		var current: Dictionary = _colonist.current_job if "current_job" in _colonist else {}
		var is_idle_now: bool = current.is_empty()
		var was_idle: bool = bool(_colonist_idle_state_by_id.get(cid, is_idle_now))
		_colonist_idle_state_by_id[cid] = is_idle_now
		if is_idle_now and not was_idle:
			job_system.mark_designation_dirty()
			job_system.mark_research_dirty()
			_mark_farm_dirty()
			_mark_jobs_dirty()
		var now_ms: int = Time.get_ticks_msec()
		var next_ms: int = int(_need_job_refresh_next_ms_by_colonist.get(cid, 0))
		if now_ms >= next_ms:
			_need_job_refresh_next_ms_by_colonist[cid] = now_ms + 700
			var food_available: int = int(resource_stock.get(&"Meal", 0)) + int(resource_stock.get(&"FoodRaw", 0))
			if bool(job_system.queue_need_jobs(_colonist, food_available)):
				_mark_jobs_dirty()
			if _raid_state == &"Active":
				var job_type: StringName = StringName(current.get("type", &""))
				if current.is_empty() or (job_type != &"CombatMelee" and job_type != &"CombatRanged"):
					_mark_combat_dirty()
					_mark_jobs_dirty()
	_sanitize_selected_colonists()
	if selected_colonists.is_empty():
		return
	if _is_selected_colonist(_colonist):
		_mark_hud_selection_dirty()

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
		label.text = _t("main.rally.label")
		label.position = Vector2(-26.0, -46.0)
		_rally_flag_node.add_child(label)
		world_root.add_child(_rally_flag_node)
	_rally_flag_node.global_position = _combat_rally_point

func _on_building_selected(building_id: StringName) -> void:
	pending_building_id = building_id
	pending_building_rotation = 0
	pending_install_item = &""
	pending_install_drop_id = 0
	hud.set_active_action(StringName("Place %s" % String(building_id)))

func _on_workstation_changed(workstation_id: StringName) -> void:
	selected_workstation_id = workstation_id
	if _is_research_workstation(workstation_id):
		hud.set_craft_panel_visible(false)
		_open_research_catalog_if_supported()
		return
	hud.set_recipe_catalog(_filter_recipes_for_workstation(workstation_id))
	hud.set_craft_queue_preview(job_system.get_craft_queue(workstation_id))
	hud.set_craft_queue_paused_state(job_system.is_craft_queue_paused(workstation_id))
	var ws_name: String = _get_workstation_display_name(workstation_id)
	hud.set_craft_panel_visible(true, ws_name)
	_open_craft_catalog_if_supported()

func _on_stockpile_filter_mode_changed(mode: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_filter_mode"):
		selected_stockpile_zone.set_filter_mode(mode)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_refresh_stockpile_filter_ui()

func _on_stockpile_filter_item_changed(resource_type: StringName, enabled: bool) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_filter_item"):
		selected_stockpile_zone.set_filter_item(resource_type, enabled)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_refresh_stockpile_filter_ui()

func _on_stockpile_priority_changed(value: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_zone_priority"):
		selected_stockpile_zone.set_zone_priority(value)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_refresh_stockpile_filter_ui()

func _on_stockpile_limit_changed(resource_type: StringName, limit: int) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("set_resource_limit"):
		selected_stockpile_zone.set_resource_limit(resource_type, limit)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_refresh_stockpile_filter_ui()

func _on_stockpile_preset_apply_requested(preset_id: StringName) -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	if selected_stockpile_zone.has_method("apply_preset"):
		selected_stockpile_zone.apply_preset(preset_id)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_refresh_stockpile_filter_ui()

func _on_stockpile_delete_requested() -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		return
	var zone: Node = selected_stockpile_zone
	var zone_pos: Vector2 = zone.global_position if zone is Node2D else Vector2.ZERO
	var snapshot: Dictionary = zone.get_stored_snapshot() if zone.has_method("get_stored_snapshot") else {}
	for key_any in snapshot.keys():
		var resource_type: StringName = StringName(key_any)
		var amount: int = int(snapshot.get(key_any, 0))
		if amount <= 0:
			continue
		resource_stock[resource_type] = maxi(0, int(resource_stock.get(resource_type, 0)) - amount)
		_spawn_resource_drop(resource_type, amount, zone_pos)
	if _selected_object_zone == zone:
		_clear_selected_object()
	selected_stockpile_zone = null
	zone.queue_free()
	hud.set_resource_stock(resource_stock)
	_mark_group_cache_dirty(&"stockpile_zones")
	job_system.mark_haul_dirty()
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_refresh_stockpile_filter_ui()
	_refresh_hud()

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

func _find_handcart_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("handcarts"):
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_vehicle_near(world_pos: Vector2, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("vehicles"):
		if node == null or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(world_pos) <= radius:
			return node
	return null

func _find_structure_by_building_near(world_pos: Vector2, building_id: StringName, radius: float) -> Node:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if node.is_queued_for_deletion() or not node.is_inside_tree():
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
	var inside_best_dist: float = INF
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if site.is_queued_for_deletion() or not site.is_inside_tree():
			continue
		if bool(site.get("complete")):
			continue
		var site_building_id: StringName = StringName(site.get("building_id"))
		if required_building_id != &"" and site_building_id != required_building_id:
			continue
		var footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(TILE_SIZE, TILE_SIZE)
		var half: Vector2 = footprint * 0.5
		var local: Vector2 = world_pos - site.global_position
		var inside: bool = absf(local.x) <= half.x and absf(local.y) <= half.y
		var d: float = site.global_position.distance_to(world_pos)
		if inside and d < inside_best_dist:
			inside_best_dist = d
			best = site
			continue
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

func _on_build_site_added(site: Node) -> void:
	if site == null or not is_instance_valid(site):
		return
	if site.has_signal("site_changed") and not site.is_connected("site_changed", Callable(self, "_on_build_site_state_changed")):
		site.connect("site_changed", Callable(self, "_on_build_site_state_changed"))
	if site.has_signal("site_completed") and not site.is_connected("site_completed", Callable(self, "_on_build_site_completed")):
		site.connect("site_completed", Callable(self, "_on_build_site_completed"))
	if site.has_signal("site_removed") and not site.is_connected("site_removed", Callable(self, "_on_build_site_removed")):
		site.connect("site_removed", Callable(self, "_on_build_site_removed"))
	if site.has_signal("site_retry_due") and not site.is_connected("site_retry_due", Callable(self, "_on_build_site_retry_due")):
		site.connect("site_retry_due", Callable(self, "_on_build_site_retry_due"))
	_mark_pathing_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true
	if _is_gui_playtest_hints_enabled() and site != null and is_instance_valid(site):
		print("GUI_EVENT_BUILD_SITE_ADDED %s" % String(site.get("building_id")))

func _on_build_site_removed(_site: Node) -> void:
	_mark_pathing_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_build_site_state_changed(_site: Node) -> void:
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_build_site_completed(_site: Node) -> void:
	_mark_pathing_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_mark_combat_dirty()
	_hud_dirty = true
	if _is_gui_playtest_hints_enabled() and _site != null and is_instance_valid(_site):
		print("GUI_EVENT_BUILD_COMPLETED %s" % String(_site.get("building_id")))

func _on_build_site_retry_due(_site: Node) -> void:
	_mark_jobs_dirty()

func _on_structure_added(_structure: Node) -> void:
	_mark_pathing_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_mark_combat_dirty()
	_hud_dirty = true
	if _structure != null and is_instance_valid(_structure) and _structure.has_meta("building_id"):
		var building_id: StringName = StringName(_structure.get_meta("building_id"))
		if building_id == &"Wall" or building_id == &"FiringWall":
			_refresh_wall_variants_at(_structure.global_position if _structure is Node2D else Vector2.INF)

func _refresh_all_wall_variants() -> void:
	if not is_inside_tree():
		return
	GAME_SPRITE.refresh_all_wall_variants(get_tree(), TILE_SIZE)

func _refresh_wall_variants_at(world_pos: Vector2) -> void:
	if world_pos == Vector2.INF or not is_inside_tree():
		return
	GAME_SPRITE.refresh_wall_variants_around(get_tree(), world_pos, TILE_SIZE)

func _on_stockpile_zone_added(zone: Node) -> void:
	_mark_group_cache_dirty(&"stockpile_zones")
	if zone != null and is_instance_valid(zone) and zone.has_signal("stockpile_changed") and not zone.is_connected("stockpile_changed", Callable(self, "_on_stockpile_zone_changed")):
		zone.connect("stockpile_changed", Callable(self, "_on_stockpile_zone_changed"))
	job_system.mark_haul_dirty()
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_farm_zone_added(zone: Node) -> void:
	_mark_group_cache_dirty(&"farm_zones")
	if zone != null and is_instance_valid(zone):
		if zone.has_signal("zone_changed") and not zone.is_connected("zone_changed", Callable(self, "_on_farm_zone_changed")):
			zone.connect("zone_changed", Callable(self, "_on_farm_zone_changed"))
		if zone.has_signal("farm_job_needed") and not zone.is_connected("farm_job_needed", Callable(self, "_on_farm_zone_job_needed")):
			zone.connect("farm_job_needed", Callable(self, "_on_farm_zone_job_needed"))
	_mark_farm_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_stockpile_zone_changed(_zone: Node) -> void:
	job_system.mark_haul_dirty()
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_farm_zone_changed(_zone: Node) -> void:
	_mark_farm_dirty()
	_hud_dirty = true

func _on_farm_zone_job_needed(_zone: Node) -> void:
	_mark_farm_dirty()
	_mark_jobs_dirty()

func _on_enemy_moved(_enemy: Node, _tile: Vector2i) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _trap_move_event_next_ms:
		return
	_trap_move_event_next_ms = now_ms + int(round(TRAP_UPDATE_INTERVAL_SEC * 1000.0))
	if _raid_state != &"Active":
		_mark_combat_dirty()
	_dispatch_traps_dirty = true
	_queue_event_dispatch()

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
	_refresh_demolish_overlay_state()
	job_system.mark_repair_dirty()
	_mark_jobs_dirty()
	_mark_pathing_dirty()

func _draw_demolish_queued_outlines() -> void:
	for node in get_tree().get_nodes_in_group("structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("demolish_job_queued"):
			continue
		if node.get_meta("demolish_job_queued") != true:
			continue
		var size: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(TILE_SIZE, TILE_SIZE)
		var rect := Rect2(node.global_position - size * 0.5, size)
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.22), true)
		draw_rect(rect, Color(1.0, 0.3, 0.3, 0.95), false, 2.0)

func _on_resource_harvested(resource_type: StringName, amount: int, world_pos: Vector2) -> void:
	# Harvest result is always dropped in world first; stock updates only after hauling into stockpile.
	_spawn_resource_drop(resource_type, amount, world_pos)
	job_system.mark_designation_dirty()
	_mark_jobs_dirty()

func _on_resource_delivered(resource_type: StringName, amount: int, zone: Node) -> void:
	if amount <= 0:
		return
	if zone == null or not is_instance_valid(zone) or not zone.has_method("add_resource"):
		_spawn_resource_drop(resource_type, amount, camera.global_position)
		return
	var accepted: int = int(zone.add_resource(resource_type, amount))
	if accepted <= 0:
		if zone.has_method("can_start_recipe"):
			_store_workstation_resource_unbounded(zone, resource_type, amount)
		else:
			_spawn_resource_drop(resource_type, amount, zone.global_position)
		return
	var delivered_to_workstation: bool = zone.has_method("can_start_recipe")
	if delivered_to_workstation and job_system != null and is_instance_valid(job_system):
		job_system.mark_craft_dirty()
	if not delivered_to_workstation:
		if not resource_stock.has(resource_type):
			resource_stock[resource_type] = 0
		resource_stock[resource_type] += accepted
	var remain: int = amount - accepted
	if remain > 0:
		_spawn_resource_drop(resource_type, remain, zone.global_position)
	hud.set_resource_stock(resource_stock)
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_workstation_supply_picked(resource_type: StringName, amount: int, _zone: Node) -> void:
	if amount <= 0:
		return
	resource_stock[resource_type] = maxi(0, int(resource_stock.get(resource_type, 0)) - amount)
	hud.set_resource_stock(resource_stock)
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_workstation_supply_delivered(resource_type: StringName, amount: int, depot: Node, source_zone: Node) -> void:
	if amount <= 0:
		return
	var accepted: int = 0
	if depot != null and is_instance_valid(depot) and depot.has_method("add_resource"):
		accepted = int(depot.add_resource(resource_type, amount))
	if accepted > 0 and job_system != null and is_instance_valid(job_system):
		job_system.mark_craft_dirty()
	var remain: int = amount - accepted
	if remain > 0:
		_return_workstation_supply_to_source(resource_type, remain, source_zone, depot)
	hud.set_resource_stock(resource_stock)
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_workstation_supply_returned(resource_type: StringName, amount: int, zone: Node) -> void:
	if amount <= 0:
		return
	_return_workstation_supply_to_source(resource_type, amount, zone, null)
	hud.set_resource_stock(resource_stock)
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _return_workstation_supply_to_source(resource_type: StringName, amount: int, zone: Node, fallback_node: Node) -> void:
	var remain: int = amount
	if zone != null and is_instance_valid(zone) and zone.has_method("add_resource"):
		var accepted: int = int(zone.add_resource(resource_type, remain))
		if accepted > 0:
			resource_stock[resource_type] = int(resource_stock.get(resource_type, 0)) + accepted
			remain -= accepted
	if remain <= 0:
		return
	var fallback_pos: Vector2 = camera.global_position if camera != null else WORLD_SIZE * 0.5
	if fallback_node != null and is_instance_valid(fallback_node) and fallback_node is Node2D:
		fallback_pos = (fallback_node as Node2D).global_position
	elif zone != null and is_instance_valid(zone) and zone is Node2D:
		fallback_pos = (zone as Node2D).global_position
	_spawn_resource_drop(resource_type, remain, fallback_pos)

func _store_workstation_resource_unbounded(depot: Node, resource_type: StringName, amount: int) -> void:
	if depot == null or not is_instance_valid(depot) or amount <= 0:
		return
	var stored: Dictionary = depot.get("stored")
	stored[resource_type] = int(stored.get(resource_type, 0)) + amount
	depot.set("stored", stored)
	if job_system != null and is_instance_valid(job_system):
		job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()

func _on_craft_completed(products: Dictionary, world_pos: Vector2, craft_slot_id: int = 0) -> void:
	for k in products.keys():
		var amount: int = int(products[k])
		if amount <= 0:
			continue
		_spawn_resource_drop(StringName(k), amount, world_pos)
	job_system.notify_craft_job_finished(craft_slot_id)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_structure_demolished(world_pos: Vector2, replace_building_id: StringName) -> void:
	_refresh_demolish_overlay_state()
	_mark_pathing_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	call_deferred("_refresh_wall_variants_at", world_pos)
	if replace_building_id == &"":
		return
	call_deferred("_try_place_replacement_building_after_demolish", world_pos, replace_building_id)

func _try_place_replacement_building_after_demolish(world_pos: Vector2, replace_building_id: StringName) -> void:
	if not is_inside_tree():
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
	if selected_workstation_id != &"" and not _is_research_workstation(selected_workstation_id):
		hud.set_recipe_catalog(_filter_recipes_for_workstation(selected_workstation_id))
	hud.set_research_catalog(
		_get_research_catalog(),
		_active_research_id,
		_get_research_lock_map(),
		_get_research_prereq_map(),
		_get_research_tree_rows()
	)
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_mark_farm_dirty()
	_mark_pathing_dirty()
	_hud_dirty = true

func _on_research_project_changed(project_id: StringName) -> void:
	if project_id == &"":
		return
	if project_id == _active_research_id:
		return
	if not _can_select_research_project(project_id):
		_hud_dirty = true
		return
	_active_research_id = project_id
	_active_research_points = 0.0
	_research_running = false
	job_system.mark_research_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_research_start_requested() -> void:
	if _active_research_id == &"":
		return
	if bool(_research_completed.get(_active_research_id, false)):
		return
	if not _can_select_research_project(_active_research_id):
		_hud_dirty = true
		return
	_research_running = true
	job_system.mark_research_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_craft_recipe_queued(recipe_id: StringName, workstation_id: StringName) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	if not _can_enqueue_recipe(recipe_id):
		return
	selected_workstation_id = ws_id
	job_system.enqueue_craft_recipe(recipe_id, ws_id)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_recipe_repeat_queued(recipe_id: StringName, workstation_id: StringName) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	if not _can_enqueue_recipe(recipe_id):
		return
	selected_workstation_id = ws_id
	job_system.enqueue_craft_recipe(recipe_id, ws_id, true)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_recipe_front_queued(recipe_id: StringName, workstation_id: StringName) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	if not _can_enqueue_recipe(recipe_id):
		return
	selected_workstation_id = ws_id
	job_system.enqueue_craft_recipe_front(recipe_id, ws_id)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_queue_clear_requested() -> void:
	job_system.clear_craft_queue(selected_workstation_id)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))

func _on_craft_queue_remove_requested(workstation_id: StringName, index: int) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	selected_workstation_id = ws_id
	job_system.remove_craft_recipe_at(ws_id, index)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_queue_pause_toggled(workstation_id: StringName, paused: bool) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
		return
	selected_workstation_id = ws_id
	job_system.set_craft_queue_paused(ws_id, paused)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_paused_state(job_system.is_craft_queue_paused(ws_id))

func _can_enqueue_recipe(recipe_id: StringName) -> bool:
	if recipe_id == &"":
		return false
	if not recipe_lookup.has(recipe_id):
		return false
	return _is_recipe_unlocked(recipe_lookup[recipe_id])

func _on_haul_job_released(drop_id: int) -> void:
	job_system.release_haul_reservation(drop_id)
	job_system.mark_haul_dirty()
	_mark_jobs_dirty()

func _on_colonist_ate_food() -> void:
	if _consume_resource_stock(&"Meal", 1):
		hud.set_resource_stock(resource_stock)
		_mark_economy_dirty()
		_mark_jobs_dirty()
		return
	if _consume_resource_stock(&"FoodRaw", 1):
		hud.set_resource_stock(resource_stock)
		_mark_economy_dirty()
		_mark_jobs_dirty()

func _try_place_selected_building(world_pos: Vector2, as_blueprint: bool, rotation_index: int = -1) -> bool:
	var place_rotation: int = pending_building_rotation if rotation_index < 0 else rotation_index
	var placed: bool = build_system.place_building(world_pos, as_blueprint, place_rotation)
	if placed and not as_blueprint:
		hud.set_resource_stock(resource_stock)
	if placed:
		_mark_pathing_dirty()
		_mark_jobs_dirty()
		_mark_maintenance_dirty()
		_mark_economy_dirty()
		_hud_dirty = true
	return placed

func _try_place_building_by_id(world_pos: Vector2, building_id: StringName, rotation_override: int = -1) -> bool:
	if building_id == &"Stockpile":
		var snapshot: Dictionary = resource_stock.duplicate(true)
		build_system.set_selected_building(building_id)
		if not build_system.consume_selected_cost(resource_stock):
			return false
		var zone_rect := Rect2(world_pos - Vector2(TILE_SIZE * 1.5, TILE_SIZE), Vector2(TILE_SIZE * 3.0, TILE_SIZE * 2.0))
		if not build_system.place_stockpile_zone(zone_rect):
			resource_stock = snapshot
		else:
			_consume_stockpile_by_delta(snapshot, resource_stock)
			_mark_economy_dirty()
			_mark_jobs_dirty()
		hud.set_resource_stock(resource_stock)
		return true
	if building_id == &"Gate" and _try_queue_gate_wall_replacement(world_pos):
		return true
	var rotation_index: int = _pending_building_rotation_for(building_id) if rotation_override < 0 else _normalized_building_rotation(_find_building_def(building_id), rotation_override)
	if _queue_deferred_build_request_if_resource_blocked(world_pos, building_id, rotation_index):
		return false
	build_system.set_selected_building(building_id)
	var placed: bool = _try_place_selected_building(world_pos, true, rotation_index)
	if placed:
		_deferred_build_requests.erase(_deferred_build_key(world_pos, building_id, rotation_index))
	return placed

func _try_queue_gate_wall_replacement(world_pos: Vector2) -> bool:
	var snapped_pos: Vector2 = _snap_to_tile(world_pos)
	var wall_site_target: Node = _find_gate_replaceable_build_site_near(snapped_pos, TILE_SIZE * 0.75)
	if wall_site_target != null:
		var gate_pos: Vector2 = wall_site_target.global_position if wall_site_target is Node2D else snapped_pos
		_cancel_build_site(wall_site_target)
		build_system.set_selected_building(&"Gate")
		return _try_place_selected_building(gate_pos, true, 0)
	var wall_target: Node = _find_gate_replaceable_structure_near(snapped_pos, TILE_SIZE * 0.75)
	if wall_target == null:
		return false
	_queue_demolish_structure(wall_target, &"Gate")
	return true

func _find_gate_replaceable_build_site_near(world_pos: Vector2, radius: float) -> Node:
	for building_id in _gate_replaceable_wall_ids():
		var site: Node = _find_build_site_near(world_pos, radius, building_id)
		if site != null:
			return site
	return null

func _find_gate_replaceable_structure_near(world_pos: Vector2, radius: float) -> Node:
	for building_id in _gate_replaceable_wall_ids():
		var structure: Node = _find_structure_by_building_near(world_pos, building_id, radius)
		if structure != null:
			return structure
	return null

func _gate_replaceable_wall_ids() -> Array[StringName]:
	return [&"Wall", &"FiringWall"]

func _deferred_build_key(world_pos: Vector2, building_id: StringName, rotation_index: int = 0) -> String:
	var snapped: Vector2 = _snap_building_to_grid(world_pos, building_id, rotation_index)
	return "%s:%d:%d:%d" % [String(building_id), int(posmod(rotation_index, 4)), int(round(snapped.x)), int(round(snapped.y))]

func _find_building_def(building_id: StringName) -> Resource:
	for def in _building_defs_all:
		if def == null:
			continue
		if StringName(def.id) == building_id:
			return def
	return null

func _build_candidate_rect(world_pos: Vector2, building_id: StringName, rotation_index: int = 0) -> Rect2:
	var footprint: Vector2 = Vector2(TILE_SIZE, TILE_SIZE)
	var def: Resource = _find_building_def(building_id)
	if def != null:
		footprint = _effective_building_footprint(def, rotation_index)
	var snapped: Vector2 = _snap_footprint_to_grid(world_pos, footprint)
	return Rect2(snapped - footprint * 0.5, footprint)

func _is_resource_node_overlapping_build(node: Node, candidate_rect: Rect2) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var center: Vector2 = _snap_to_tile(node.global_position)
	var half: float = TILE_SIZE * 0.5
	var blocker_rect := Rect2(center - Vector2(half, half), Vector2(TILE_SIZE, TILE_SIZE))
	return candidate_rect.intersects(blocker_rect)

func _collect_resource_blockers_for_build(world_pos: Vector2, building_id: StringName, rotation_index: int = 0) -> Array:
	var candidate_rect: Rect2 = _build_candidate_rect(world_pos, building_id, rotation_index)
	var blockers: Array = []
	var seen_ids: Dictionary = {}
	for node in _get_group_nodes_cached(&"gatherables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_depleted") and bool(node.is_depleted()):
			continue
		if not _is_resource_node_overlapping_build(node, candidate_rect):
			continue
		var nid: int = node.get_instance_id()
		if seen_ids.has(nid):
			continue
		seen_ids[nid] = true
		blockers.append(node)
	for node in _get_group_nodes_cached(&"huntables"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		if not _is_resource_node_overlapping_build(node, candidate_rect):
			continue
		var nid: int = node.get_instance_id()
		if seen_ids.has(nid):
			continue
		seen_ids[nid] = true
		blockers.append(node)
	for node in _get_group_nodes_cached(&"resource_drops"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_empty") and bool(node.is_empty()):
			continue
		if not _is_resource_node_overlapping_build(node, candidate_rect):
			continue
		var nid: int = node.get_instance_id()
		if seen_ids.has(nid):
			continue
		seen_ids[nid] = true
		blockers.append(node)
	return blockers

func _queue_resource_clear_jobs_for_build(blockers: Array) -> void:
	var queued_designation_job: bool = false
	var has_drop_blocker: bool = false
	for blocker in blockers:
		if blocker == null or not is_instance_valid(blocker):
			continue
		if blocker.is_in_group("gatherables"):
			if blocker.has_method("set_designated"):
				blocker.set_designated(true)
			if not bool(blocker.get("job_queued")):
				job_system.queue_gather_job(blocker)
				queued_designation_job = true
		elif blocker.is_in_group("huntables"):
			if blocker.has_method("set_designated"):
				blocker.set_designated(true)
			if not bool(blocker.get("job_queued")):
				job_system.queue_hunt_job(blocker)
				queued_designation_job = true
		elif blocker.is_in_group("resource_drops"):
			has_drop_blocker = true
	if queued_designation_job and job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_designation_dirty"):
		job_system.mark_designation_dirty()
	if queued_designation_job:
		_mark_jobs_dirty()
	if has_drop_blocker:
		_mark_economy_dirty()
		_mark_jobs_dirty()

func _queue_deferred_build_request_if_resource_blocked(world_pos: Vector2, building_id: StringName, rotation_index: int = 0) -> bool:
	var blockers: Array = _collect_resource_blockers_for_build(world_pos, building_id, rotation_index)
	if blockers.is_empty():
		return false
	var key: String = _deferred_build_key(world_pos, building_id, rotation_index)
	if _deferred_build_requests.has(key):
		return true
	_deferred_build_requests[key] = {
		"building_id": building_id,
		"world_pos": _snap_building_to_grid(world_pos, building_id, rotation_index),
		"rotation": int(posmod(rotation_index, 4))
	}
	_queue_resource_clear_jobs_for_build(blockers)
	_hud_dirty = true
	return true

func _process_deferred_build_requests() -> void:
	if _deferred_build_requests.is_empty():
		return
	var request_keys: Array = _deferred_build_requests.keys()
	for key_any in request_keys:
		var key: String = String(key_any)
		var request: Dictionary = _deferred_build_requests.get(key, {})
		var building_id: StringName = StringName(request.get("building_id", &""))
		var world_pos: Vector2 = request.get("world_pos", Vector2.INF)
		var rotation_index: int = int(request.get("rotation", 0))
		if building_id == &"" or world_pos == Vector2.INF:
			_deferred_build_requests.erase(key)
			continue
		if not _collect_resource_blockers_for_build(world_pos, building_id, rotation_index).is_empty():
			continue
		if _try_place_building_by_id(world_pos, building_id, rotation_index):
			_deferred_build_requests.erase(key)
			continue
		# Placement still failed after resource clear (ex: structure occupancy). Drop request.
		_deferred_build_requests.erase(key)

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

func can_fund_build_site(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	if not (site_obj is Node):
		return false
	var site_node: Node = site_obj
	if site_node.has_method("requires_material_delivery") and not bool(site_node.requires_material_delivery()):
		return true
	var site_building_id: StringName = StringName(site_node.get("building_id"))
	if site_building_id != &"" and int(_free_build_allowance.get(site_building_id, 0)) > 0:
		return true
	var build_cost: Dictionary = {}
	if site_node.has_method("get_build_cost"):
		build_cost = site_node.get_build_cost()
	if build_cost.is_empty():
		return true
	return _can_afford_build_cost(build_cost)

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
	if pending_install_item != &"Bed" and pending_install_item != &"Handcart" and not _is_vehicle_item(pending_install_item):
		return false
	var install_item: StringName = pending_install_item
	if not _try_consume_pending_install_source(install_item):
		return false
	var snapped_pos := _snap_to_tile(world_pos)
	match install_item:
		&"Bed":
			_spawn_installed_bed(snapped_pos)
		&"Handcart":
			_spawn_installed_handcart(snapped_pos)
		_:
			if _spawn_vehicle_for_resource(install_item, snapped_pos) == null:
				return false
	hud.set_resource_stock(resource_stock)
	return true

func _try_consume_pending_install_source(item_type: StringName) -> bool:
	if item_type == &"":
		return false
	if pending_install_drop_id == -1:
		return true
	if pending_install_drop_id != 0:
		var drop_obj: Object = instance_from_id(pending_install_drop_id)
		if drop_obj != null and is_instance_valid(drop_obj) and drop_obj.has_method("take_amount"):
			var taken: int = int(drop_obj.take_amount(1))
			if taken > 0:
				if drop_obj.has_method("is_empty") and drop_obj.is_empty():
					drop_obj.queue_free()
				return true
	return _consume_resource_stock(item_type, 1)

func _spawn_installed_bed(world_pos: Vector2) -> void:
	var placed := Node2D.new()
	placed.name = "Installed_Bed"
	placed.global_position = world_pos
	placed.add_to_group("structures")
	placed.set_meta("building_id", &"InstalledBed")
	placed.set_meta("assigned_colonist_id", 0)
	var sprite := Sprite2D.new()
	var image := Image.create(68, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.73, 0.54, 0.36, 1.0))
	sprite.texture = ImageTexture.create_from_image(image)
	placed.add_child(sprite)
	world_root.add_child(placed)
	_mark_group_cache_dirty(&"structures")

func _spawn_installed_handcart(world_pos: Vector2) -> Node2D:
	var placed: Node2D = null
	if HANDCART_SCRIPT != null:
		var inst: Object = HANDCART_SCRIPT.new()
		if inst is Node2D:
			placed = inst
	if placed == null:
		placed = Node2D.new()
		placed.add_to_group("structures")
		placed.add_to_group("handcarts")
		placed.set_meta("building_id", &"InstalledHandcart")
		placed.set_meta("carry_bonus", 80)
		placed.set_meta("assigned_colonist_id", 0)
		var sprite := Sprite2D.new()
		var image := Image.create(30, 18, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.58, 0.44, 0.28, 1.0))
		sprite.texture = ImageTexture.create_from_image(image)
		placed.add_child(sprite)
		var txt := Label.new()
		txt.text = "Handcart"
		txt.position = Vector2(-18.0, -20.0)
		placed.add_child(txt)
	placed.name = "Installed_Handcart"
	placed.global_position = world_pos
	placed.set_meta("building_id", &"InstalledHandcart")
	if not placed.has_meta("carry_bonus"):
		placed.set_meta("carry_bonus", 80)
	if not placed.has_meta("assigned_colonist_id"):
		placed.set_meta("assigned_colonist_id", 0)
	if not placed.is_in_group("structures"):
		placed.add_to_group("structures")
	if not placed.is_in_group("handcarts"):
		placed.add_to_group("handcarts")
	world_root.add_child(placed)
	_mark_group_cache_dirty(&"structures")
	_mark_group_cache_dirty(&"handcarts")
	return placed

func _spawn_vehicle(vehicle_id: StringName, world_pos: Vector2) -> Node2D:
	if vehicle_id == &"" or not vehicle_lookup.has(vehicle_id):
		return null
	var def: Resource = vehicle_lookup[vehicle_id]
	var placed: Node2D = null
	if VEHICLE_SCRIPT != null:
		var inst: Object = VEHICLE_SCRIPT.new()
		if inst is Node2D:
			placed = inst
	if placed == null:
		placed = Node2D.new()
	placed.name = "Vehicle_%s" % String(vehicle_id)
	placed.global_position = _snap_to_tile(world_pos)
	if placed.has_method("setup"):
		placed.call("setup", def)
	if not placed.is_in_group("vehicles"):
		placed.add_to_group("vehicles")
	world_root.add_child(placed)
	_mark_group_cache_dirty(&"vehicles")
	return placed

func _spawn_vehicle_for_resource(resource_type: StringName, world_pos: Vector2) -> Node2D:
	var def: Resource = _vehicle_def_for_item(resource_type)
	if def == null:
		return null
	return _spawn_vehicle(StringName(def.get("id")), world_pos)

func _vehicle_def_for_item(resource_type: StringName) -> Resource:
	if resource_type == &"":
		return null
	for key_any in vehicle_lookup.keys():
		var def: Resource = vehicle_lookup[key_any]
		if def == null:
			continue
		if StringName(def.get("item_resource_id")) == resource_type:
			return def
	return null

func _is_vehicle_item(resource_type: StringName) -> bool:
	return _vehicle_def_for_item(resource_type) != null

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
			ready += _workstation_supply_in_flight_amount(depot, resource_type)
			var deficit: int = maxi(0, need - ready)
			if deficit <= 0:
				continue
			_queue_workstation_supply_jobs(resource_type, deficit, depot)

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

func _queue_workstation_supply_jobs(resource_type: StringName, amount: int, depot: Node) -> void:
	var remain: int = maxi(0, amount)
	if remain <= 0 or depot == null or not is_instance_valid(depot):
		return
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		if remain <= 0:
			break
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("get_stored_amount"):
			continue
		var available: int = int(zone.get_stored_amount(resource_type))
		if available <= 0:
			continue
		var queued_amount: int = mini(available, remain)
		if job_system.queue_workstation_supply_job(zone, depot, resource_type, queued_amount):
			remain -= queued_amount

func _workstation_supply_in_flight_amount(depot: Node, resource_type: StringName) -> int:
	if depot == null or not is_instance_valid(depot):
		return 0
	var depot_id: int = depot.get_instance_id()
	var total: int = 0
	if job_system != null and is_instance_valid(job_system) and "_jobs" in job_system:
		for job in job_system._jobs:
			total += _workstation_supply_job_amount(job, depot_id, resource_type)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		total += _workstation_supply_job_amount(colonist.get("current_job"), depot_id, resource_type)
	return total

func _workstation_supply_job_amount(job_any: Variant, depot_id: int, resource_type: StringName) -> int:
	if not (job_any is Dictionary):
		return 0
	var job: Dictionary = job_any
	if StringName(job.get("type", &"")) != &"HaulStockpileToDepot":
		return 0
	if int(job.get("depot_id", 0)) != depot_id:
		return 0
	if StringName(job.get("resource_type", job.get("carried_type", &""))) != resource_type:
		return 0
	if StringName(job.get("phase", &"to_stockpile")) == &"to_depot":
		return maxi(0, int(job.get("carried_amount", job.get("amount", 0))))
	return maxi(0, int(job.get("amount", 0)))

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
	_mark_economy_dirty()
	_mark_jobs_dirty()
	return true

func _consume_from_stockpiles(resource_type: StringName, amount: int) -> void:
	var remain: int = amount
	if remain <= 0:
		return
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		if remain <= 0:
			break
		if zone == null or not is_instance_valid(zone):
			continue
		if not zone.has_method("remove_resource"):
			continue
		var removed: int = int(zone.remove_resource(resource_type, remain))
		remain -= maxi(0, removed)
	if amount > 0:
		_mark_economy_dirty()

func _reconcile_stockpile_totals_with_resource_stock() -> void:
	var zones: Array = _get_group_nodes_cached(&"stockpile_zones")
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
	var kind: String = _t("main.designation.kind.gather")
	if selected_designation_target.is_in_group("huntables"):
		kind = _t("main.designation.kind.hunt")
	hud.set_designation_target_preview(title, enabled, kind)

func _refresh_bed_assign_ui() -> void:
	if selected_bed_node == null or not is_instance_valid(selected_bed_node):
		hud.set_bed_assignment_visible(false)
		return
	var options: Array = [{"id": 0, "name": _t("common.unselected")}]
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
	var owner_name: String = _t("common.unselected")
	if colonist_id != 0:
		for c in colonists:
			if c != null and is_instance_valid(c) and c.get_instance_id() == colonist_id:
				owner_name = c.name
				break
	for child in selected_bed_node.get_children():
		if child is Label:
			child.text = _t("main.bed.label", {"owner": owner_name})
			break
	_apply_passive_item_bonuses()
	_mark_maintenance_dirty()
	_hud_dirty = true

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
	_close_bottom_catalog_if_supported()

func _on_context_action_requested(action_id: StringName) -> void:
	match action_id:
		&"Gather":
			var gather_obj: Object = instance_from_id(_context_gather_target_id)
			if gather_obj != null and is_instance_valid(gather_obj):
				if gather_obj.has_method("set_designated"):
					gather_obj.set_designated(true)
				var assigned_to: int = 0
				_sanitize_selected_colonists()
				if not selected_colonists.is_empty():
					var primary: Node = selected_colonists[0]
					assigned_to = primary.get_instance_id()
					if primary.has_method("cancel_current_job"):
						primary.cancel_current_job()
				job_system.queue_gather_job(gather_obj, assigned_to)
				job_system.mark_designation_dirty()
				_mark_jobs_dirty()
		&"Workstation":
			if _context_workstation_id != &"":
				_activate_workstation(_context_workstation_id)
				if workstation_lookup.has(_context_workstation_id):
					var ws: Resource = workstation_lookup[_context_workstation_id]
					var work_pos: Vector2 = _find_workstation_pos(ws.linked_building_id)
					if work_pos != Vector2.INF:
						_issue_selected_move_command(work_pos)
				_mark_jobs_dirty()
		&"UseHandcart":
			var handcart_obj: Object = instance_from_id(_context_handcart_id)
			var primary_colonist: Node = _get_primary_selected_colonist()
			if handcart_obj != null and is_instance_valid(handcart_obj) and primary_colonist != null and is_instance_valid(primary_colonist):
				if _request_handcart_use(handcart_obj, primary_colonist):
					_mark_jobs_dirty()
					_hud_dirty = true
		&"ReleaseHandcart":
			var handcart_obj: Object = instance_from_id(_context_handcart_id)
			var primary_colonist: Node = _get_primary_selected_colonist()
			if handcart_obj != null and is_instance_valid(handcart_obj) and primary_colonist != null and is_instance_valid(primary_colonist):
				var owner_id: int = _get_handcart_owner_id(handcart_obj)
				var colonist_id: int = primary_colonist.get_instance_id()
				if owner_id == colonist_id:
					_clear_pending_handcart_use_for_colonist(colonist_id)
					if handcart_obj is Node2D:
						var release_pos: Vector2 = _context_handcart_release_pos if _context_handcart_release_pos != Vector2.INF else (handcart_obj as Node2D).global_position
						(handcart_obj as Node2D).global_position = _snap_to_tile(release_pos)
					_clear_handcart_owner(handcart_obj, colonist_id)
					_mark_jobs_dirty()
					_hud_dirty = true
		&"UseHandcartFromStockpile":
			var zone_obj: Object = instance_from_id(_context_stockpile_zone_id)
			var primary_colonist: Node = _get_primary_selected_colonist()
			if zone_obj != null and is_instance_valid(zone_obj) and primary_colonist != null and is_instance_valid(primary_colonist):
				if _request_stockpile_mountable_use(&"Handcart", zone_obj, primary_colonist, _context_stockpile_use_pos):
					_mark_jobs_dirty()
					_hud_dirty = true
		&"UseVehicleFromStockpile":
			var zone_obj: Object = instance_from_id(_context_stockpile_zone_id)
			var primary_colonist: Node = _get_primary_selected_colonist()
			var vehicle_resource: StringName = _context_stockpile_vehicle_resource
			if zone_obj != null and is_instance_valid(zone_obj) and primary_colonist != null and is_instance_valid(primary_colonist):
				if _request_stockpile_mountable_use(vehicle_resource, zone_obj, primary_colonist, _context_stockpile_use_pos):
					_mark_jobs_dirty()
					_hud_dirty = true
		&"DismountVehicle":
			var vehicle_obj: Object = instance_from_id(_context_vehicle_id)
			var primary_colonist: Node = _get_primary_selected_colonist()
			if vehicle_obj != null and is_instance_valid(vehicle_obj) and primary_colonist != null and is_instance_valid(primary_colonist):
				var colonist_id: int = primary_colonist.get_instance_id()
				if _get_vehicle_rider_id(vehicle_obj) == colonist_id and primary_colonist.has_method("dismount_vehicle"):
					_clear_pending_vehicle_use_for_colonist(colonist_id)
					_clear_pending_stockpile_mountable_use_for_colonist(colonist_id)
					primary_colonist.dismount_vehicle()
					_mark_jobs_dirty()
					_hud_dirty = true
		&"EquipSelectedItem":
			if _equip_context_item_to_primary():
				_mark_jobs_dirty()
				_hud_dirty = true
	_context_gather_target_id = 0
	_context_workstation_id = &""
	_context_handcart_id = 0
	_context_handcart_release_pos = Vector2.INF
	_context_vehicle_id = 0
	_context_stockpile_zone_id = 0
	_context_stockpile_use_pos = Vector2.INF
	_context_stockpile_vehicle_resource = &""
	_clear_equipment_context()

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
	job_system.mark_designation_dirty()
	_mark_jobs_dirty()
	_refresh_designation_ui()

func _on_outfit_mode_changed(mode: StringName) -> void:
	if mode != &"Work" and mode != &"Combat":
		return
	_outfit_mode = mode
	hud.set_outfit_mode(_outfit_mode)
	_apply_passive_item_bonuses()
	_mark_combat_dirty()
	_mark_maintenance_dirty()

func _on_colonist_died(_colonist: Node) -> void:
	_prune_colonists()
	_mark_jobs_dirty()
	_mark_combat_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _refresh_demolish_overlay_state() -> void:
	_has_demolish_overlay = _has_demolish_queued_structure()

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
			var raiders_alive: int = _cached_alive_enemies.size()
			if raiders_alive <= 0:
				_resolve_raid(true)
			elif colonists.is_empty():
				_resolve_raid(false)

func _start_raid_warning() -> void:
	_raid_state = &"Warning"
	_raid_warning_timer = 18.0
	_raid_wave_size = mini(20, maxi(2, 2 + int(floor(_elapsed_game_seconds / 120.0))))
	_raid_wave_kind = _pick_raid_wave_kind()
	_mark_combat_dirty()
	_mark_hud_time_dirty()

func _start_raid_wave() -> void:
	if _raid_wave_size <= 0:
		_raid_wave_size = mini(20, maxi(2, 2 + int(floor(_elapsed_game_seconds / 120.0))))
	if _raid_wave_kind == &"":
		_raid_wave_kind = _pick_raid_wave_kind()
	_raid_state = &"Active"
	_raid_warning_timer = 0.0
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("enter_raid_mode"):
		job_system.enter_raid_mode()
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
	# Refresh enemy cache immediately so the next process tick does not
	# resolve the raid before deferred combat dispatch sees spawned enemies.
	_mark_group_cache_dirty(&"raiders")
	_mark_group_cache_dirty(&"zombies")
	_cached_alive_enemies = _get_alive_raiders()
	_cancel_noncombat_jobs_for_active_raid()
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_hud_time_dirty()

func _resolve_raid(_colony_survived: bool) -> void:
	_raid_state = &"Resolved"
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("exit_raid_mode"):
		job_system.exit_raid_mode()
	if _colony_survived:
		_grant_raid_reward()
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_raid_test_warning_requested() -> void:
	if _raid_state == &"Warning" or _raid_state == &"Active":
		return
	if not _get_alive_raiders().is_empty():
		return
	_start_raid_warning()

func _on_save_reset_requested() -> void:
	reset_save_and_reload_game_scene()

func _cancel_noncombat_jobs_for_active_raid() -> void:
	if _rally_flag_node == null or not is_instance_valid(_rally_flag_node):
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not _can_colonist_enter_raid_combat(colonist):
			continue
		if not colonist.has_method("cancel_current_job"):
			continue
		var current: Dictionary = colonist.current_job if "current_job" in colonist else {}
		if current.is_empty():
			continue
		var job_type: StringName = StringName(current.get("type", &""))
		if job_type == &"CombatMelee" or job_type == &"CombatRanged":
			continue
		colonist.cancel_current_job()

func _can_colonist_enter_raid_combat(colonist: Node) -> bool:
	if colonist == null or not is_instance_valid(colonist):
		return false
	if not colonist.has_method("can_do_job"):
		return true
	var preferred: StringName = &"CombatMelee"
	if colonist.has_method("get_preferred_combat_job_type"):
		var preferred_type: StringName = StringName(colonist.get_preferred_combat_job_type())
		if preferred_type == &"CombatMelee" or preferred_type == &"CombatRanged":
			preferred = preferred_type
	if bool(colonist.can_do_job(preferred)):
		return true
	var fallback: StringName = &"CombatRanged" if preferred == &"CombatMelee" else &"CombatMelee"
	return bool(colonist.can_do_job(fallback))

func _spawn_raiders(count: int) -> void:
	if count <= 0:
		return
	for _i in range(count):
		var raider: Node2D = RAIDER_SCENE.instantiate()
		raider.global_position = _resolve_enemy_spawn_position(_random_edge_spawn(140.0))
		if raider.has_method("set_tile_size"):
			raider.set_tile_size(TILE_SIZE)
		if raider.has_signal("died"):
			raider.died.connect(_on_raider_died)
		_connect_enemy_signals(raider)
		units_root.add_child(raider)
		_apply_raid_enemy_equipment(raider, &"Raider")

func _spawn_zombies(count: int) -> void:
	if count <= 0:
		return
	for _i in range(count):
		var zombie: Node2D = ZOMBIE_SCENE.instantiate()
		zombie.global_position = _resolve_enemy_spawn_position(_random_edge_spawn(120.0))
		if zombie.has_method("set_tile_size"):
			zombie.set_tile_size(TILE_SIZE)
		if zombie.has_signal("died"):
			zombie.died.connect(_on_zombie_died)
		_connect_enemy_signals(zombie)
		units_root.add_child(zombie)
		_apply_raid_enemy_equipment(zombie, &"Zombie")

func _apply_raid_enemy_equipment(enemy: Node, enemy_kind: StringName) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("set_equipment_slots"):
		return
	var slots: Dictionary = {
		&"Top": &"",
		&"Bottom": &"",
		&"Hat": &"",
		&"Weapon": &""
	}
	match enemy_kind:
		&"Raider":
			slots = {
				&"Top": &"CombatTop",
				&"Bottom": &"CombatBottom",
				&"Hat": &"CombatHat",
				&"Weapon": &"Sword"
			}
		&"Zombie":
			slots = {
				&"Top": &"GatherTop",
				&"Bottom": &"GatherBottom",
				&"Hat": &"StrawHat",
				&"Weapon": &"Weapon"
			}
		_:
			slots = {
				&"Top": &"",
				&"Bottom": &"",
				&"Hat": &"",
				&"Weapon": &"Weapon"
			}
	enemy.set_equipment_slots(slots)

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
	var bonus_scale: int = maxi(1, _raid_wave_size + int(floor(_elapsed_game_seconds / 240.0)))
	var wave_mul: float = 1.0
	match _raid_wave_kind:
		&"ZombieHorde":
			wave_mul = 1.15
		&"Mixed":
			wave_mul = 1.25
		_:
			wave_mul = 1.0
	var reward_mul: float = maxf(1.0, _raid_reward_bonus_from_research)
	var food_amount: int = int(round((2 + bonus_scale) * wave_mul * reward_mul))
	var wood_amount: int = int(round((1 + int(floor(bonus_scale * 0.5))) * wave_mul * reward_mul))
	var steel_amount: int = int(round(maxf(1.0, bonus_scale * 0.2 * wave_mul * reward_mul)))
	_spawn_resource_drop(&"FoodRaw", food_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(TILE_SIZE, -TILE_SIZE)))
	_spawn_resource_drop(&"Wood", wood_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(-TILE_SIZE, -TILE_SIZE)))
	_spawn_resource_drop(&"Steel", steel_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(0.0, -TILE_SIZE)))

func _on_raider_died(_raider: Node) -> void:
	if _raider != null and is_instance_valid(_raider):
		_drop_enemy_equipment(_raider)
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_zombie_died(_zombie: Node) -> void:
	if _zombie != null and is_instance_valid(_zombie):
		_drop_enemy_equipment(_zombie)
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _drop_enemy_equipment(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("get_equipment_snapshot"):
		return
	var slots: Dictionary = enemy.get_equipment_snapshot()
	var slot_order := [&"Top", &"Bottom", &"Hat", &"Weapon"]
	var base_pos: Vector2 = _snap_to_tile(enemy.global_position)
	var offsets: Array[Vector2] = [
		Vector2(-TILE_SIZE, 0.0),
		Vector2(TILE_SIZE, 0.0),
		Vector2(0.0, -TILE_SIZE),
		Vector2(0.0, TILE_SIZE)
	]
	for i in range(slot_order.size()):
		var slot_key: StringName = slot_order[i]
		var item_id: StringName = StringName(slots.get(slot_key, &""))
		if item_id == &"":
			continue
		var offset: Vector2 = offsets[i] if i < offsets.size() else Vector2.ZERO
		_spawn_resource_drop(item_id, 1, base_pos + offset)

func _get_alive_raiders() -> Array:
	var out: Array = []
	for node in _get_group_nodes_cached(&"raiders"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		out.append(node)
	for node in _get_group_nodes_cached(&"zombies"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		out.append(node)
	return out

func _get_workmode_threat_enemies(enemies: Array) -> Array:
	var out: Array = []
	var center: Vector2 = WORLD_SIZE * 0.5
	var threat_radius: float = 520.0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(center) <= threat_radius:
			out.append(enemy)
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

func _resolve_enemy_spawn_position(raw_pos: Vector2) -> Vector2:
	var start: Vector2 = _snap_to_tile(raw_pos)
	if _pathing_occupancy == null or not is_instance_valid(_pathing_occupancy):
		return start
	if not _pathing_occupancy.is_blocked_for_enemy(start):
		return start
	var center: Vector2 = _snap_to_tile(WORLD_SIZE * 0.5)
	var to_center: Vector2 = start.direction_to(center)
	if to_center == Vector2.ZERO:
		to_center = Vector2.DOWN
	# Cheap inward sampling to avoid expensive spawn-time scans.
	for step in range(1, 28):
		var inward_probe: Vector2 = _snap_to_tile(start + to_center * TILE_SIZE * float(step))
		if not _pathing_occupancy.is_blocked_for_enemy(inward_probe):
			return inward_probe
	# Fallback: sample random points across the map to avoid spawn-locks.
	for _i in range(48):
		var probe_any: Vector2 = _snap_to_tile(Vector2(
			randf_range(TILE_SIZE, WORLD_SIZE.x - TILE_SIZE),
			randf_range(TILE_SIZE, WORLD_SIZE.y - TILE_SIZE)
		))
		if not _pathing_occupancy.is_blocked_for_enemy(probe_any):
			return probe_any
	if not _pathing_occupancy.is_blocked_for_enemy(center):
		return center
	return start

func _apply_passive_item_bonuses() -> void:
	var alive_ids: Dictionary = {}
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		alive_ids[c.get_instance_id()] = true
	_prune_manual_equipment_slots(alive_ids)
	var manual_counts: Dictionary = _manual_equipment_item_counts(alive_ids)
	_remove_manual_slot_ids(_equipped_top_ids, &"Top", alive_ids)
	_remove_manual_slot_ids(_equipped_bottom_ids, &"Bottom", alive_ids)
	_remove_manual_slot_ids(_equipped_hat_ids, &"Hat", alive_ids)
	if _outfit_mode == &"Combat":
		_sync_equipped_map(_equipped_top_ids, maxi(0, int(resource_stock.get(&"CombatTop", 0)) - int(manual_counts.get(&"CombatTop", 0))), alive_ids)
		_sync_equipped_map(_equipped_bottom_ids, maxi(0, int(resource_stock.get(&"CombatBottom", 0)) - int(manual_counts.get(&"CombatBottom", 0))), alive_ids)
		_sync_equipped_map(_equipped_hat_ids, maxi(0, int(resource_stock.get(&"CombatHat", 0)) - int(manual_counts.get(&"CombatHat", 0))), alive_ids)
	else:
		_sync_equipped_map(_equipped_top_ids, maxi(0, int(resource_stock.get(&"GatherTop", 0)) - int(manual_counts.get(&"GatherTop", 0))), alive_ids)
		_sync_equipped_map(_equipped_bottom_ids, maxi(0, int(resource_stock.get(&"GatherBottom", 0)) - int(manual_counts.get(&"GatherBottom", 0))), alive_ids)
		_sync_equipped_map(_equipped_hat_ids, maxi(0, int(resource_stock.get(&"StrawHat", 0)) - int(manual_counts.get(&"StrawHat", 0))), alive_ids)
	var manual_weapon_ids: Dictionary = _manual_equipment_colonist_ids_for_slot(&"Weapon", alive_ids)
	_rebuild_weapon_assignments(alive_ids, manual_counts, manual_weapon_ids)
	_apply_manual_equipment_tracking(alive_ids)
	var assigned_bed_map: Dictionary = {}
	for node in _get_group_nodes_cached(&"structures"):
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
		var equipped_slots: Dictionary = {
			&"Top": (&"CombatTop" if _outfit_mode == &"Combat" else &"GatherTop") if has_top else &"",
			&"Bottom": (&"CombatBottom" if _outfit_mode == &"Combat" else &"GatherBottom") if has_bottom else &"",
			&"Hat": (&"CombatHat" if _outfit_mode == &"Combat" else &"StrawHat") if has_hat else &"",
			&"Weapon": weapon_id if has_weapon else &""
		}
		var manual_slots: Dictionary = _manual_equipment_slots_for_colonist(cid)
		for slot_key in manual_slots.keys():
			equipped_slots[StringName(slot_key)] = StringName(manual_slots[slot_key])
		if colonist.has_method("set_wearing_clothes"):
			colonist.set_wearing_clothes(has_any_apparel)
		if colonist.has_method("set_equipment_slots"):
			colonist.set_equipment_slots(equipped_slots)
		var armor_pen: float = float(colonist.stats.base_armor_penetration)
		var defense: float = float(colonist.stats.base_defense)
		if colonist.has_method("set_combat_profile"):
			var profile: Dictionary = EQUIPMENT_STATS.make_colonist_base_profile(
				float(colonist.stats.base_hit_chance),
				defense,
				armor_pen,
				_combat_accuracy_bonus_from_research
			)
			colonist.set_combat_profile(EQUIPMENT_STATS.apply_equipment_to_profile(profile, equipped_slots))
		if colonist.has_method("set_external_accuracy_bonus"):
			colonist.set_external_accuracy_bonus(_day_night_combat_accuracy_bonus())
		if colonist.has_method("set_external_move_speed_multiplier"):
			colonist.set_external_move_speed_multiplier(_day_night_move_multiplier())
		if colonist.has_method("set_gather_speed_multiplier"):
			colonist.set_gather_speed_multiplier(1.2 if has_any_apparel else 1.0)
		if colonist.has_method("set_build_work_speed_multiplier"):
			colonist.set_build_work_speed_multiplier(_build_speed_bonus_from_research)
		if colonist.has_method("set_repair_work_speed_multiplier"):
			colonist.set_repair_work_speed_multiplier(_repair_speed_bonus_from_research)
		if colonist.has_method("set_rest_recover_multiplier"):
			var rest_mult: float = 1.5 if assigned_bed_map.has(colonist.get_instance_id()) else 1.0
			if _is_night_time() and assigned_bed_map.has(colonist.get_instance_id()):
				rest_mult *= 1.12
			colonist.set_rest_recover_multiplier(rest_mult * _rest_recover_bonus_from_research)
		if colonist.has_method("set_need_decay_multiplier"):
			var need_decay_mult: float = 0.94 if _is_night_time() else 1.02
			if _outfit_mode == &"Combat":
				need_decay_mult *= 1.06
			colonist.set_need_decay_multiplier(need_decay_mult)

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

func _rebuild_weapon_assignments(alive_ids: Dictionary, manual_counts: Dictionary = {}, manual_weapon_ids: Dictionary = {}) -> void:
	for cid in _equipped_weapon_kind.keys():
		if not alive_ids.has(cid) or manual_weapon_ids.has(cid):
			_equipped_weapon_kind.erase(cid)
	var wanted: Array[StringName] = []
	if _outfit_mode == &"Combat":
		for _i in range(maxi(0, int(resource_stock.get(&"Rifle", 0)) - int(manual_counts.get(&"Rifle", 0)))):
			wanted.append(&"Rifle")
		for _i in range(maxi(0, int(resource_stock.get(&"Sword", 0)) - int(manual_counts.get(&"Sword", 0)))):
			wanted.append(&"Sword")
	for _i in range(maxi(0, int(resource_stock.get(&"Weapon", 0)) - int(manual_counts.get(&"Weapon", 0)))):
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
		if manual_weapon_ids.has(cid):
			continue
		next_map[cid] = wanted[idx]
		idx += 1
	_equipped_weapon_kind = next_map
	_equipped_weapon_ids.clear()
	for cid in _equipped_weapon_kind.keys():
		_equipped_weapon_ids[cid] = true

func _prune_manual_equipment_slots(alive_ids: Dictionary) -> void:
	for cid_any in _manual_equipment_slots_by_colonist.keys():
		var cid: int = int(cid_any)
		if not alive_ids.has(cid):
			_manual_equipment_slots_by_colonist.erase(cid)

func _manual_equipment_slots_for_colonist(colonist_id: int) -> Dictionary:
	var slots_variant: Variant = _manual_equipment_slots_by_colonist.get(colonist_id, {})
	if slots_variant is Dictionary:
		return (slots_variant as Dictionary).duplicate(true)
	return {}

func _manual_equipment_item_counts(alive_ids: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for cid_any in _manual_equipment_slots_by_colonist.keys():
		var cid: int = int(cid_any)
		if not alive_ids.has(cid):
			continue
		var slots: Dictionary = _manual_equipment_slots_for_colonist(cid)
		for slot_key in slots.keys():
			var item_id: StringName = StringName(slots[slot_key])
			if item_id == &"":
				continue
			counts[item_id] = int(counts.get(item_id, 0)) + 1
	return counts

func _manual_equipment_colonist_ids_for_slot(slot_key: StringName, alive_ids: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	for cid_any in _manual_equipment_slots_by_colonist.keys():
		var cid: int = int(cid_any)
		if not alive_ids.has(cid):
			continue
		var slots: Dictionary = _manual_equipment_slots_for_colonist(cid)
		if StringName(slots.get(slot_key, &"")) != &"":
			ids[cid] = true
	return ids

func _remove_manual_slot_ids(equipped_map: Dictionary, slot_key: StringName, alive_ids: Dictionary) -> void:
	var ids: Dictionary = _manual_equipment_colonist_ids_for_slot(slot_key, alive_ids)
	for cid_any in ids.keys():
		equipped_map.erase(int(cid_any))

func _apply_manual_equipment_tracking(alive_ids: Dictionary) -> void:
	for cid_any in _manual_equipment_slots_by_colonist.keys():
		var cid: int = int(cid_any)
		if not alive_ids.has(cid):
			continue
		var slots: Dictionary = _manual_equipment_slots_for_colonist(cid)
		if StringName(slots.get(&"Top", &"")) != &"":
			_equipped_top_ids[cid] = true
		if StringName(slots.get(&"Bottom", &"")) != &"":
			_equipped_bottom_ids[cid] = true
		if StringName(slots.get(&"Hat", &"")) != &"":
			_equipped_hat_ids[cid] = true
		var weapon_id: StringName = StringName(slots.get(&"Weapon", &""))
		if weapon_id != &"":
			_equipped_weapon_kind[cid] = weapon_id
			_equipped_weapon_ids[cid] = true

func _clear_pending_placement() -> void:
	pending_building_id = &""
	pending_building_rotation = 0
	pending_install_item = &""
	pending_install_drop_id = 0
	_context_handcart_id = 0
	_context_handcart_release_pos = Vector2.INF
	_context_vehicle_id = 0
	_context_stockpile_zone_id = 0
	_context_stockpile_use_pos = Vector2.INF
	_context_stockpile_vehicle_resource = &""
	_clear_equipment_context()
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

func _select_stockpile_item(stockpile_item: Dictionary) -> bool:
	if stockpile_item.is_empty():
		return false
	var zone: Node = stockpile_item.get("zone", null)
	if zone == null or not is_instance_valid(zone):
		return false
	var resource_type: StringName = StringName(stockpile_item.get("resource_type", &""))
	if resource_type == &"":
		return false
	_set_selected([])
	selected_bed_node = null
	selected_farm_zone = null
	hud.set_bed_assignment_visible(false)
	selected_stockpile_zone = zone
	_selected_object_kind = &"StockpileItem"
	_selected_object_zone = selected_stockpile_zone
	_selected_object_resource = resource_type
	_refresh_hud()
	hud.set_active_action(&"StockpileItem")
	_close_bottom_catalog_if_supported()
	return true

func _find_stockpile_item_at(world_pos: Vector2) -> Dictionary:
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
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
		_prepare_install_from_selected_stockpile(&"Bed")
	elif action_id == &"PlaceHandcartFromStockpile":
		_prepare_install_from_selected_stockpile(&"Handcart")
	elif action_id == &"PlaceVehicleFromStockpile":
		if _is_vehicle_item(_selected_object_resource):
			_prepare_install_from_selected_stockpile(_selected_object_resource)
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
		_mark_farm_dirty()
		_mark_jobs_dirty()
	elif action_id == &"DeleteFarmZone":
		var target_farm_zone: Node = null
		if selected_farm_zone != null and is_instance_valid(selected_farm_zone):
			target_farm_zone = selected_farm_zone
		elif _selected_object_kind == &"FarmZone" and _selected_object_zone != null and is_instance_valid(_selected_object_zone):
			target_farm_zone = _selected_object_zone
		if target_farm_zone == null:
			return
		if _selected_object_zone == target_farm_zone:
			_clear_selected_object()
		selected_farm_zone = null
		target_farm_zone.queue_free()
		_mark_group_cache_dirty(&"farm_zones")
		_mark_farm_dirty()
		_mark_jobs_dirty()
		_hud_dirty = true
		_on_action_changed(&"Interact")
		_close_bottom_catalog_if_supported()
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
		_mark_jobs_dirty()
		_mark_pathing_dirty()
		_mark_maintenance_dirty()
	elif action_id == &"CancelBuildSite":
		if _selected_object_kind != &"BuildSite":
			return
		if _selected_object_zone == null or not is_instance_valid(_selected_object_zone):
			return
		_cancel_build_site(_selected_object_zone)
		_clear_selected_object()
		_refresh_hud()
		_mark_jobs_dirty()
		_mark_pathing_dirty()
		_mark_maintenance_dirty()

func _prepare_install_from_selected_stockpile(resource_type: StringName) -> void:
	if resource_type == &"":
		return
	if _selected_object_kind != &"StockpileItem" or _selected_object_resource != resource_type:
		return
	if _selected_object_zone == null or not is_instance_valid(_selected_object_zone):
		return
	if not _selected_object_zone.has_method("remove_resource"):
		return
	var removed: int = int(_selected_object_zone.remove_resource(resource_type, 1))
	if removed <= 0:
		return
	resource_stock[resource_type] = maxi(0, int(resource_stock.get(resource_type, 0)) - removed)
	_clear_selected_object()
	selected_stockpile_zone = null
	pending_install_item = resource_type
	pending_install_drop_id = -1
	hud.set_resource_stock(resource_stock)
	hud.set_active_action(StringName("Install%s" % String(resource_type)))
	hud.set_selected_status_visible(false)
	_mark_economy_dirty()
	_mark_jobs_dirty()

func _clear_equipment_context() -> void:
	_context_equipment_resource = &""
	_context_equipment_source_kind = &""
	_context_equipment_drop_id = 0
	_context_equipment_stockpile_zone_id = 0

func _equipment_slot_for_item(item_id: StringName) -> StringName:
	if item_id == &"":
		return &""
	var def: Resource = EQUIPMENT_STATS.get_resource_def(item_id)
	if def == null:
		return &""
	if String(def.get("category")) == "Weapon":
		return &"Weapon"
	var raw: String = String(item_id)
	if raw.ends_with("Top"):
		return &"Top"
	if raw.ends_with("Bottom"):
		return &"Bottom"
	if raw.ends_with("Hat"):
		return &"Hat"
	return &""

func _is_equipment_item(item_id: StringName) -> bool:
	return _equipment_slot_for_item(item_id) != &""

func _resource_display_name(item_id: StringName) -> String:
	var def: Resource = EQUIPMENT_STATS.get_resource_def(item_id)
	if def != null:
		var display: String = String(def.get("display_name"))
		if not display.is_empty():
			return display
	return String(item_id)

func _try_show_equipment_context_from_right_click(world_pos: Vector2, screen_pos: Vector2) -> bool:
	var stockpile_item: Dictionary = _find_stockpile_item_at(world_pos)
	if not stockpile_item.is_empty():
		var stock_resource: StringName = StringName(stockpile_item.get("resource_type", &""))
		var stock_zone: Node = stockpile_item.get("zone", null)
		if _is_equipment_item(stock_resource) and stock_zone != null and is_instance_valid(stock_zone):
			_context_equipment_resource = stock_resource
			_context_equipment_source_kind = &"Stockpile"
			_context_equipment_stockpile_zone_id = stock_zone.get_instance_id()
			_context_equipment_drop_id = 0
			_context_gather_target_id = 0
			_context_workstation_id = &""
			_context_handcart_id = 0
			_context_handcart_release_pos = Vector2.INF
			_context_stockpile_zone_id = 0
			_context_stockpile_use_pos = Vector2.INF
			_context_stockpile_vehicle_resource = &""
			hud.show_context_action_button(
				&"EquipSelectedItem",
				_t("main.context.equip", {"item": _resource_display_name(stock_resource)}, "%s 장착" % _resource_display_name(stock_resource)),
				screen_pos
			)
			return true
	var drop: Node = _find_resource_drop_near(world_pos, TILE_SIZE * 0.75)
	if drop == null:
		return false
	var drop_resource: StringName = StringName(drop.get("resource_type"))
	if not _is_equipment_item(drop_resource):
		return false
	if int(drop.get("amount")) <= 0:
		return false
	_context_equipment_resource = drop_resource
	_context_equipment_source_kind = &"Drop"
	_context_equipment_drop_id = drop.get_instance_id()
	_context_equipment_stockpile_zone_id = 0
	_context_gather_target_id = 0
	_context_workstation_id = &""
	_context_handcart_id = 0
	_context_handcart_release_pos = Vector2.INF
	_context_stockpile_zone_id = 0
	_context_stockpile_use_pos = Vector2.INF
	_context_stockpile_vehicle_resource = &""
	hud.show_context_action_button(
		&"EquipSelectedItem",
		_t("main.context.equip", {"item": _resource_display_name(drop_resource)}, "%s 장착" % _resource_display_name(drop_resource)),
		screen_pos
	)
	return true

func _equip_context_item_to_primary() -> bool:
	var colonist: Node = _get_primary_selected_colonist()
	if colonist == null or not is_instance_valid(colonist):
		return false
	var item_id: StringName = _context_equipment_resource
	var slot_key: StringName = _equipment_slot_for_item(item_id)
	if slot_key == &"":
		return false
	var current_slots: Dictionary = colonist.get_equipment_snapshot() if colonist.has_method("get_equipment_snapshot") else {}
	var already_equipped: bool = StringName(current_slots.get(slot_key, &"")) == item_id
	var manual_slots: Dictionary = _manual_equipment_slots_for_colonist(colonist.get_instance_id())
	if already_equipped and StringName(manual_slots.get(slot_key, &"")) == item_id:
		return true
	if already_equipped and _context_equipment_source_kind == &"Drop":
		return true
	match _context_equipment_source_kind:
		&"Stockpile":
			var zone_obj: Object = instance_from_id(_context_equipment_stockpile_zone_id)
			if zone_obj == null or not is_instance_valid(zone_obj) or not zone_obj.has_method("remove_resource"):
				return false
			var removed: int = int(zone_obj.remove_resource(item_id, 1))
			if removed <= 0:
				return false
		&"Drop":
			var drop_obj: Object = instance_from_id(_context_equipment_drop_id)
			if drop_obj == null or not is_instance_valid(drop_obj) or not drop_obj.has_method("take_amount"):
				return false
			var taken: int = int(drop_obj.take_amount(1))
			if taken <= 0:
				return false
			resource_stock[item_id] = int(resource_stock.get(item_id, 0)) + taken
			if drop_obj.has_method("is_empty") and bool(drop_obj.is_empty()):
				drop_obj.queue_free()
		_:
			return false
	if already_equipped:
		_set_manual_equipment_slot(colonist, slot_key, item_id)
		_apply_passive_item_bonuses()
		_mark_maintenance_dirty()
		_hud_dirty = true
		return true
	return _equip_item_to_colonist(colonist, item_id, slot_key)

func _set_manual_equipment_slot(colonist: Node, slot_key: StringName, item_id: StringName) -> void:
	var cid: int = colonist.get_instance_id()
	var manual_slots: Dictionary = _manual_equipment_slots_for_colonist(cid)
	manual_slots[slot_key] = item_id
	_manual_equipment_slots_by_colonist[cid] = manual_slots

func _equip_item_to_colonist(colonist: Node, item_id: StringName, slot_key: StringName) -> bool:
	if colonist == null or not is_instance_valid(colonist):
		return false
	if item_id == &"" or slot_key == &"":
		return false
	if not colonist.has_method("get_equipment_snapshot") or not colonist.has_method("set_equipment_slots"):
		return false
	var slots: Dictionary = colonist.get_equipment_snapshot()
	var old_item: StringName = StringName(slots.get(slot_key, &""))
	if old_item == item_id:
		return true
	if old_item != &"":
		resource_stock[old_item] = maxi(0, int(resource_stock.get(old_item, 0)) - 1)
		if colonist is Node2D:
			_spawn_resource_drop(old_item, 1, (colonist as Node2D).global_position)
	slots[slot_key] = item_id
	colonist.set_equipment_slots(slots)
	_set_manual_equipment_slot(colonist, slot_key, item_id)
	_apply_passive_item_bonuses()
	hud.set_resource_stock(resource_stock)
	_mark_economy_dirty()
	_mark_maintenance_dirty()
	_mark_combat_dirty()
	_hud_dirty = true
	return true

func _handle_user_right_click(event: InputEventMouseButton) -> void:
	var world_pos: Vector2 = world_root.get_global_mouse_position()
	if pending_building_id != &"" or pending_install_item != &"" or current_action == &"StockpileZone" or current_action == &"FarmZone" or current_action == &"SetRallyFlag" or current_action == &"DragGather":
		_clear_pending_placement()
		_on_action_changed(&"Interact")
		_close_bottom_catalog_if_supported()
		return
	_sanitize_selected_colonists()
	var stockpile_item: Dictionary = _find_stockpile_item_at(world_pos)
	if not selected_colonists.is_empty():
		if _try_show_equipment_context_from_right_click(world_pos, event.position):
			return
		if not stockpile_item.is_empty():
			if _show_mountable_stockpile_context(stockpile_item, world_pos, event.position):
				return
		var vehicle: Node = _find_vehicle_near(world_pos, 48.0)
		if vehicle != null:
			var primary_vehicle_colonist: Node = _get_primary_selected_colonist()
			if primary_vehicle_colonist != null and is_instance_valid(primary_vehicle_colonist):
				if _show_vehicle_dismount_context(vehicle, primary_vehicle_colonist, event.position):
					return
				if _request_vehicle_use(vehicle, primary_vehicle_colonist):
					_mark_jobs_dirty()
					_hud_dirty = true
					return
		var handcart: Node = _find_handcart_near(world_pos, 48.0)
		if handcart != null:
			var primary_colonist: Node = _get_primary_selected_colonist()
			if primary_colonist != null and is_instance_valid(primary_colonist):
				var owner_id: int = _get_handcart_owner_id(handcart)
				var colonist_id: int = primary_colonist.get_instance_id()
				if owner_id == colonist_id:
					_context_handcart_id = handcart.get_instance_id()
					_context_handcart_release_pos = _snap_to_tile(world_pos)
					_context_gather_target_id = 0
					_context_workstation_id = &""
					_context_stockpile_zone_id = 0
					_context_stockpile_use_pos = Vector2.INF
					_context_stockpile_vehicle_resource = &""
					hud.show_context_action_button(&"ReleaseHandcart", _t("main.context.handcart.release", {}, "해제하기"), event.position)
					return
				if owner_id == 0:
					_context_handcart_id = handcart.get_instance_id()
					_context_handcart_release_pos = _snap_to_tile(world_pos)
					_context_gather_target_id = 0
					_context_workstation_id = &""
					_context_stockpile_zone_id = 0
					_context_stockpile_use_pos = Vector2.INF
					_context_stockpile_vehicle_resource = &""
					hud.show_context_action_button(&"UseHandcart", _t("main.context.handcart.use", {}, "사용하기"), event.position)
					return
		var gatherable: Node = _find_gatherable_near(world_pos, 48.0)
		if gatherable != null:
			_context_gather_target_id = gatherable.get_instance_id()
			_context_workstation_id = &""
			_context_handcart_id = 0
			_context_handcart_release_pos = Vector2.INF
			_context_stockpile_zone_id = 0
			_context_stockpile_use_pos = Vector2.INF
			_context_stockpile_vehicle_resource = &""
			hud.show_context_action_button(&"Gather", _t("main.context.gather"), event.position)
			return
		var ws_id: StringName = _find_workstation_id_near(world_pos, 56.0)
		if ws_id != &"":
			_context_workstation_id = ws_id
			_context_gather_target_id = 0
			_context_handcart_id = 0
			_context_handcart_release_pos = Vector2.INF
			_context_stockpile_zone_id = 0
			_context_stockpile_use_pos = Vector2.INF
			_context_stockpile_vehicle_resource = &""
			hud.show_context_action_button(&"Workstation", _t("main.context.workstation"), event.position)
			return
		_issue_selected_move_command(world_pos)
		return
	_clear_pending_placement()
	_on_action_changed(&"Interact")
	_close_bottom_catalog_if_supported()

func _get_primary_selected_colonist() -> Node:
	_sanitize_selected_colonists()
	if selected_colonists.is_empty():
		return null
	var primary: Node = selected_colonists[0]
	if primary == null or not is_instance_valid(primary):
		return null
	return primary

func _show_mountable_stockpile_context(stockpile_item: Dictionary, world_pos: Vector2, screen_pos: Vector2) -> bool:
	if stockpile_item.is_empty():
		return false
	var resource_type: StringName = StringName(stockpile_item.get("resource_type", &""))
	var stock_zone: Node = stockpile_item.get("zone", null)
	if stock_zone == null or not is_instance_valid(stock_zone):
		return false
	var action_id: StringName = &""
	if resource_type == &"Handcart":
		action_id = &"UseHandcartFromStockpile"
		_context_stockpile_vehicle_resource = &""
	elif _is_vehicle_item(resource_type):
		action_id = &"UseVehicleFromStockpile"
		_context_stockpile_vehicle_resource = resource_type
	else:
		return false
	_context_stockpile_zone_id = stock_zone.get_instance_id()
	_context_stockpile_use_pos = _snap_to_tile(world_pos)
	_context_vehicle_id = 0
	_context_handcart_id = 0
	_context_handcart_release_pos = Vector2.INF
	_context_gather_target_id = 0
	_context_workstation_id = &""
	hud.show_context_action_button(action_id, _t("main.context.handcart.use", {}, "사용하기"), screen_pos)
	return true

func _show_vehicle_dismount_context(vehicle: Object, colonist: Node, screen_pos: Vector2) -> bool:
	if vehicle == null or not is_instance_valid(vehicle):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	var colonist_id: int = colonist.get_instance_id()
	if _get_vehicle_rider_id(vehicle) != colonist_id:
		return false
	if not colonist.has_method("is_mounted") or not bool(colonist.is_mounted()):
		return false
	if not (vehicle is Node2D):
		return false
	_context_vehicle_id = (vehicle as Node2D).get_instance_id()
	_context_handcart_id = 0
	_context_handcart_release_pos = Vector2.INF
	_context_stockpile_zone_id = 0
	_context_stockpile_use_pos = Vector2.INF
	_context_stockpile_vehicle_resource = &""
	_context_gather_target_id = 0
	_context_workstation_id = &""
	hud.show_context_action_button(&"DismountVehicle", _t("main.context.vehicle.dismount", {}, "하차하기"), screen_pos)
	return true

func _request_stockpile_mountable_use(resource_type: StringName, zone: Object, colonist: Node, use_pos: Vector2) -> bool:
	if resource_type == &"":
		return false
	if resource_type != &"Handcart" and not _is_vehicle_item(resource_type):
		return false
	if zone == null or not is_instance_valid(zone):
		return false
	if colonist == null or not is_instance_valid(colonist) or not (colonist is Node2D):
		return false
	if colonist.has_method("can_accept_manual_move") and not bool(colonist.can_accept_manual_move()):
		return false
	var target_pos: Vector2 = use_pos
	if target_pos == Vector2.INF:
		target_pos = _stockpile_mountable_spawn_pos(zone, use_pos)
	var colonist_id: int = colonist.get_instance_id()
	_clear_pending_stockpile_mountable_use_for_colonist(colonist_id)
	_clear_pending_handcart_use_for_colonist(colonist_id)
	_clear_pending_vehicle_use_for_colonist(colonist_id)
	_pending_stockpile_mountable_use_by_colonist[colonist_id] = {
		"zone_id": zone.get_instance_id(),
		"resource_type": resource_type,
		"pos": _snap_to_tile(target_pos)
	}
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("issue_immediate_move"):
		job_system.issue_immediate_move(colonist, _snap_to_tile(target_pos), resource_type == &"Handcart")
	elif colonist.has_method("assign_job"):
		colonist.assign_job({
			"type": &"MoveTo",
			"target": _snap_to_tile(target_pos),
			"base_priority": 100,
			"assigned_to": colonist_id
		})
	return true

func _clear_pending_stockpile_mountable_use_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	if _pending_stockpile_mountable_use_by_colonist.has(colonist_id):
		_pending_stockpile_mountable_use_by_colonist.erase(colonist_id)

func _resolve_pending_stockpile_mountable_use_requests() -> void:
	if _pending_stockpile_mountable_use_by_colonist.is_empty():
		return
	var resolved_or_stale: Array[int] = []
	var resolved_any: bool = false
	for colonist_id_any in _pending_stockpile_mountable_use_by_colonist.keys():
		var colonist_id: int = int(colonist_id_any)
		var request: Dictionary = _pending_stockpile_mountable_use_by_colonist[colonist_id_any]
		var colonist_obj: Object = instance_from_id(colonist_id)
		if colonist_obj == null or not is_instance_valid(colonist_obj) or not (colonist_obj is Node2D):
			resolved_or_stale.append(colonist_id)
			continue
		var zone_obj: Object = instance_from_id(int(request.get("zone_id", 0)))
		if zone_obj == null or not is_instance_valid(zone_obj):
			resolved_or_stale.append(colonist_id)
			continue
		var target_pos: Vector2 = _snap_to_tile(request.get("pos", Vector2.INF))
		if target_pos == Vector2.INF:
			resolved_or_stale.append(colonist_id)
			continue
		var colonist_node: Node2D = colonist_obj as Node2D
		if colonist_node.global_position.distance_to(target_pos) > 28.0:
			continue
		var resource_type: StringName = StringName(request.get("resource_type", &""))
		if _spawn_stockpile_mountable_for_colonist(resource_type, zone_obj, colonist_node, target_pos):
			resolved_any = true
		resolved_or_stale.append(colonist_id)
	for colonist_id in resolved_or_stale:
		_pending_stockpile_mountable_use_by_colonist.erase(colonist_id)
	if resolved_any:
		_mark_economy_dirty()
		_mark_jobs_dirty()
		_hud_dirty = true

func _spawn_stockpile_mountable_for_colonist(resource_type: StringName, zone: Object, colonist: Node, spawn_pos: Vector2) -> bool:
	if zone == null or not is_instance_valid(zone) or not zone.has_method("remove_resource"):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	if resource_type != &"Handcart" and not _is_vehicle_item(resource_type):
		return false
	var removed: int = int(zone.remove_resource(resource_type, 1))
	if removed <= 0:
		return false
	resource_stock[resource_type] = maxi(0, int(resource_stock.get(resource_type, 0)) - removed)
	var snapped_pos: Vector2 = _stockpile_mountable_spawn_pos(zone, spawn_pos)
	var success: bool = false
	if resource_type == &"Handcart":
		var handcart_node: Node2D = _spawn_installed_handcart(snapped_pos)
		success = handcart_node != null and is_instance_valid(handcart_node) and _assign_handcart_to_colonist(handcart_node, colonist)
		if success:
			_finish_pending_handcart_use_move(colonist)
		elif handcart_node != null and is_instance_valid(handcart_node):
			handcart_node.queue_free()
	else:
		var vehicle_node: Node2D = _spawn_vehicle_for_resource(resource_type, snapped_pos)
		success = vehicle_node != null and is_instance_valid(vehicle_node) and _assign_vehicle_to_colonist(vehicle_node, colonist)
		if not success and vehicle_node != null and is_instance_valid(vehicle_node):
			vehicle_node.queue_free()
	if not success:
		if zone.has_method("add_resource"):
			zone.add_resource(resource_type, removed)
		resource_stock[resource_type] = int(resource_stock.get(resource_type, 0)) + removed
	hud.set_resource_stock(resource_stock)
	return success

func _stockpile_mountable_spawn_pos(zone: Object, fallback_pos: Vector2) -> Vector2:
	if fallback_pos != Vector2.INF:
		return _snap_to_tile(fallback_pos)
	if zone != null and is_instance_valid(zone):
		if zone.has_method("get_drop_point"):
			return _snap_to_tile(zone.get_drop_point())
		if zone is Node2D:
			return _snap_to_tile((zone as Node2D).global_position)
	return Vector2.ZERO

func _request_vehicle_use(vehicle: Object, colonist: Node) -> bool:
	if vehicle == null or not is_instance_valid(vehicle):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	if not (vehicle is Node2D) or not (colonist is Node2D):
		return false
	if colonist.has_method("can_accept_manual_move") and not bool(colonist.can_accept_manual_move()):
		return false
	var colonist_id: int = colonist.get_instance_id()
	var vehicle_id: int = (vehicle as Node2D).get_instance_id()
	var rider_id: int = _get_vehicle_rider_id(vehicle)
	_clear_pending_stockpile_mountable_use_for_colonist(colonist_id)
	if rider_id == colonist_id:
		_clear_pending_vehicle_use_for_colonist(colonist_id)
		return true
	if rider_id != 0:
		return false
	_clear_pending_vehicle_use_for_colonist(colonist_id)
	for pending_colonist_any in _pending_vehicle_use_by_colonist.keys():
		var pending_colonist_id: int = int(pending_colonist_any)
		if int(_pending_vehicle_use_by_colonist[pending_colonist_any]) != vehicle_id:
			continue
		_pending_vehicle_use_by_colonist.erase(pending_colonist_id)
	if (colonist as Node2D).global_position.distance_to((vehicle as Node2D).global_position) <= 28.0:
		return _assign_vehicle_to_colonist(vehicle, colonist)
	_pending_vehicle_use_by_colonist[colonist_id] = vehicle_id
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("issue_immediate_move"):
		job_system.issue_immediate_move(colonist, (vehicle as Node2D).global_position, false)
	elif colonist.has_method("assign_job"):
		colonist.assign_job({
			"type": &"MoveTo",
			"target": (vehicle as Node2D).global_position,
			"base_priority": 100,
			"assigned_to": colonist_id
		})
	return true

func _resolve_pending_vehicle_use_requests() -> void:
	if _pending_vehicle_use_by_colonist.is_empty():
		return
	var resolved_or_stale: Array[int] = []
	var resolved_any: bool = false
	for colonist_id_any in _pending_vehicle_use_by_colonist.keys():
		var colonist_id: int = int(colonist_id_any)
		var vehicle_id: int = int(_pending_vehicle_use_by_colonist[colonist_id_any])
		var colonist_obj: Object = instance_from_id(colonist_id)
		var vehicle_obj: Object = instance_from_id(vehicle_id)
		if colonist_obj == null or not is_instance_valid(colonist_obj):
			resolved_or_stale.append(colonist_id)
			continue
		if vehicle_obj == null or not is_instance_valid(vehicle_obj):
			resolved_or_stale.append(colonist_id)
			continue
		var colonist_node: Node2D = colonist_obj as Node2D
		var vehicle_node: Node2D = vehicle_obj as Node2D
		if colonist_node == null or vehicle_node == null:
			resolved_or_stale.append(colonist_id)
			continue
		var rider_id: int = _get_vehicle_rider_id(vehicle_obj)
		if rider_id != 0 and rider_id != colonist_id:
			resolved_or_stale.append(colonist_id)
			continue
		if colonist_node.global_position.distance_to(vehicle_node.global_position) > 28.0:
			continue
		if _assign_vehicle_to_colonist(vehicle_obj, colonist_node):
			resolved_any = true
		resolved_or_stale.append(colonist_id)
	for colonist_id in resolved_or_stale:
		_pending_vehicle_use_by_colonist.erase(colonist_id)
	if resolved_any:
		_mark_jobs_dirty()
		_hud_dirty = true

func _assign_vehicle_to_colonist(vehicle: Object, colonist: Node) -> bool:
	if vehicle == null or not is_instance_valid(vehicle):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	if not colonist.has_method("mount_vehicle"):
		return false
	return bool(colonist.mount_vehicle(vehicle))

func _clear_pending_vehicle_use_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	if _pending_vehicle_use_by_colonist.has(colonist_id):
		_pending_vehicle_use_by_colonist.erase(colonist_id)

func _get_vehicle_rider_id(vehicle: Object) -> int:
	if vehicle == null or not is_instance_valid(vehicle):
		return 0
	if vehicle.has_method("get_rider_id"):
		return int(vehicle.call("get_rider_id"))
	if vehicle.has_meta("rider_colonist_id"):
		return int(vehicle.get_meta("rider_colonist_id"))
	return 0

func _get_handcart_owner_id(handcart: Object) -> int:
	if handcart == null or not is_instance_valid(handcart):
		return 0
	if handcart.has_meta("assigned_colonist_id"):
		return int(handcart.get_meta("assigned_colonist_id"))
	return 0

func _clear_handcart_owner(handcart: Object, owner_id: int = 0) -> void:
	if handcart == null or not is_instance_valid(handcart):
		return
	if handcart.has_method("clear_owner"):
		handcart.clear_owner(owner_id)
	elif handcart.has_meta("assigned_colonist_id"):
		var current_owner: int = int(handcart.get_meta("assigned_colonist_id"))
		if owner_id == 0 or owner_id == current_owner:
			handcart.set_meta("assigned_colonist_id", 0)

func _clear_pending_handcart_use_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	if _pending_handcart_use_by_colonist.has(colonist_id):
		_pending_handcart_use_by_colonist.erase(colonist_id)

func _request_handcart_use(handcart: Object, colonist: Node) -> bool:
	if handcart == null or not is_instance_valid(handcart):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	var handcart_node: Node2D = handcart as Node2D
	var colonist_node: Node2D = colonist as Node2D
	if handcart_node == null or colonist_node == null:
		return false
	var colonist_id: int = colonist.get_instance_id()
	var handcart_id: int = handcart_node.get_instance_id()
	var current_owner: int = _get_handcart_owner_id(handcart)
	if current_owner != 0 and current_owner != colonist_id:
		return false
	_clear_pending_stockpile_mountable_use_for_colonist(colonist_id)
	_clear_pending_handcart_use_for_colonist(colonist_id)
	for pending_colonist_any in _pending_handcart_use_by_colonist.keys():
		var pending_colonist_id: int = int(pending_colonist_any)
		if int(_pending_handcart_use_by_colonist[pending_colonist_any]) != handcart_id:
			continue
		_pending_handcart_use_by_colonist.erase(pending_colonist_id)
	if colonist_node.global_position.distance_to(handcart_node.global_position) <= 28.0:
		return _assign_handcart_to_colonist(handcart, colonist)
	_pending_handcart_use_by_colonist[colonist_id] = handcart_id
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("issue_immediate_move"):
		job_system.issue_immediate_move(colonist, handcart_node.global_position, true)
	elif colonist.has_method("assign_job"):
		colonist.assign_job({
			"type": &"MoveTo",
			"target": handcart_node.global_position,
			"base_priority": 100,
			"assigned_to": colonist_id
		})
	return true

func _resolve_pending_handcart_use_requests() -> void:
	if _pending_handcart_use_by_colonist.is_empty():
		return
	var resolved_or_stale: Array[int] = []
	var resolved_any: bool = false
	for colonist_id_any in _pending_handcart_use_by_colonist.keys():
		var colonist_id: int = int(colonist_id_any)
		var handcart_id: int = int(_pending_handcart_use_by_colonist[colonist_id_any])
		var colonist_obj: Object = instance_from_id(colonist_id)
		var handcart_obj: Object = instance_from_id(handcart_id)
		if colonist_obj == null or not is_instance_valid(colonist_obj):
			resolved_or_stale.append(colonist_id)
			continue
		if handcart_obj == null or not is_instance_valid(handcart_obj):
			resolved_or_stale.append(colonist_id)
			continue
		var colonist_node: Node2D = colonist_obj as Node2D
		var handcart_node: Node2D = handcart_obj as Node2D
		if colonist_node == null or handcart_node == null:
			resolved_or_stale.append(colonist_id)
			continue
		var owner_id: int = _get_handcart_owner_id(handcart_obj)
		if owner_id != 0 and owner_id != colonist_id:
			resolved_or_stale.append(colonist_id)
			continue
		if colonist_node.global_position.distance_to(handcart_node.global_position) > 28.0:
			continue
		if _assign_handcart_to_colonist(handcart_obj, colonist_node):
			_finish_pending_handcart_use_move(colonist_node)
			resolved_any = true
		resolved_or_stale.append(colonist_id)
	for colonist_id in resolved_or_stale:
		_pending_handcart_use_by_colonist.erase(colonist_id)
	if resolved_any:
		_mark_jobs_dirty()
		_hud_dirty = true

func _finish_pending_handcart_use_move(colonist: Node) -> void:
	if colonist == null or not is_instance_valid(colonist):
		return
	if not ("current_job" in colonist):
		return
	var job: Dictionary = colonist.current_job
	if job.is_empty():
		return
	if StringName(job.get("type", &"")) != &"MoveTo":
		return
	if not bool(job.get("__resume_after_move", false)):
		return
	if colonist.has_method("_finish_current_job"):
		colonist.call("_finish_current_job")
	elif colonist.has_method("cancel_current_job"):
		colonist.cancel_current_job()

func _assign_handcart_to_colonist(handcart: Object, colonist: Node) -> bool:
	if handcart == null or not is_instance_valid(handcart):
		return false
	if colonist == null or not is_instance_valid(colonist):
		return false
	if not (colonist is Node2D):
		return false
	var colonist_id: int = colonist.get_instance_id()
	var current_owner: int = _get_handcart_owner_id(handcart)
	if current_owner != 0 and current_owner != colonist_id:
		return false
	for node in get_tree().get_nodes_in_group("handcarts"):
		if node == null or not is_instance_valid(node):
			continue
		if node == handcart:
			continue
		if _get_handcart_owner_id(node) != colonist_id:
			continue
		_clear_handcart_owner(node, colonist_id)
	var assigned: bool = false
	if handcart.has_method("assign_owner"):
		assigned = bool(handcart.assign_owner(colonist_id))
	elif handcart.has_meta("assigned_colonist_id"):
		handcart.set_meta("assigned_colonist_id", colonist_id)
		assigned = true
	if not assigned:
		return false
	return true

func _issue_selected_move_command(target_pos: Vector2) -> void:
	var snapped_target: Vector2 = _snap_to_tile(target_pos)
	var active_colonists: Array = []
	for colonist in selected_colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("can_accept_manual_move") and not bool(colonist.can_accept_manual_move()):
			continue
		active_colonists.append(colonist)
	var formation_slots: Array[Vector2] = _build_formation_slots(snapped_target, active_colonists.size())
	var used_slots: Dictionary = {}
	for colonist in active_colonists:
		var move_target: Vector2 = _select_formation_slot_for_colonist(colonist, formation_slots, used_slots, snapped_target)
		var preserve_current_job: bool = _raid_state != &"Active" and not _is_colonist_in_combat_job(colonist)
		_release_melee_locks_for_user_move(colonist)
		job_system.issue_immediate_move(colonist, move_target, preserve_current_job)
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _is_colonist_in_combat_job(colonist: Node) -> bool:
	if colonist == null or not is_instance_valid(colonist):
		return false
	var job_variant: Variant = colonist.get("current_job")
	if not (job_variant is Dictionary):
		return false
	var job: Dictionary = job_variant
	var job_type: StringName = StringName(job.get("type", &""))
	return job_type == &"CombatMelee" or job_type == &"CombatRanged"

func _release_melee_locks_for_user_move(colonist: Node) -> void:
	if colonist == null or not is_instance_valid(colonist):
		return
	if colonist.has_method("release_melee_combat_lock"):
		colonist.release_melee_combat_lock()
	var colonist_id: int = colonist.get_instance_id()
	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	enemies.append_array(get_tree().get_nodes_in_group("zombies"))
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("release_melee_lock_if_target"):
			enemy.release_melee_lock_if_target(colonist_id)

func _build_formation_slots(snapped_target: Vector2, unit_count: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var max_ring: int = maxi(2, int(ceil(sqrt(float(unit_count)))) + 3)
	for ring in range(0, max_ring + 1):
		if ring == 0:
			if _is_valid_formation_slot(snapped_target):
				slots.append(snapped_target)
			if slots.size() >= unit_count:
				return slots
			continue
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var candidate: Vector2 = _snap_to_tile(snapped_target + Vector2(float(x) * TILE_SIZE, float(y) * TILE_SIZE))
				if not _is_valid_formation_slot(candidate):
					continue
				if slots.has(candidate):
					continue
				slots.append(candidate)
		if slots.size() >= unit_count:
			return slots
	return slots

func _select_formation_slot_for_colonist(colonist: Node, slots: Array[Vector2], used_slots: Dictionary, fallback: Vector2) -> Vector2:
	if slots.is_empty() or colonist == null or not is_instance_valid(colonist):
		return fallback
	var best_index: int = -1
	var best_dist_sq: float = INF
	for i in range(slots.size()):
		if used_slots.has(i):
			continue
		var dist_sq: float = colonist.global_position.distance_squared_to(slots[i])
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	if best_index < 0:
		return fallback
	used_slots[best_index] = true
	return slots[best_index]

func _is_valid_formation_slot(world_pos: Vector2) -> bool:
	if world_pos.x < 0.0 or world_pos.y < 0.0 or world_pos.x > WORLD_SIZE.x or world_pos.y > WORLD_SIZE.y:
		return false
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("is_blocked_for_friendly"):
		return not bool(_pathing_occupancy.is_blocked_for_friendly(world_pos))
	return true

func _spawn_resource_drop(resource_type: StringName, amount: int, world_pos: Vector2) -> Node:
	if amount <= 0:
		return null
	var drop := RESOURCE_DROP_SCENE.instantiate()
	drop.global_position = _snap_to_tile(world_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)))
	world_root.add_child(drop)
	_mark_group_cache_dirty(&"resource_drops")
	_connect_resource_drop_signals(drop)
	if drop.has_method("setup_drop"):
		drop.setup_drop(resource_type, amount)
	job_system.mark_haul_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true
	return drop

func _wire_existing_world_signals() -> void:
	for site in _get_group_nodes_cached(&"build_sites"):
		_on_build_site_added(site)
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		_on_stockpile_zone_added(zone)
	for zone in _get_group_nodes_cached(&"farm_zones"):
		_on_farm_zone_added(zone)
	for drop in _get_group_nodes_cached(&"resource_drops"):
		_connect_resource_drop_signals(drop)
	for enemy in _get_group_nodes_cached(&"raiders"):
		_connect_enemy_signals(enemy)
	for enemy in _get_group_nodes_cached(&"zombies"):
		_connect_enemy_signals(enemy)

func _connect_resource_drop_signals(drop: Node) -> void:
	if drop == null or not is_instance_valid(drop):
		return
	if drop.has_signal("drop_changed") and not drop.is_connected("drop_changed", Callable(self, "_on_resource_drop_changed")):
		drop.connect("drop_changed", Callable(self, "_on_resource_drop_changed"))
	if drop.has_signal("drop_emptied") and not drop.is_connected("drop_emptied", Callable(self, "_on_resource_drop_emptied")):
		drop.connect("drop_emptied", Callable(self, "_on_resource_drop_emptied"))
	if drop.has_signal("drop_removed") and not drop.is_connected("drop_removed", Callable(self, "_on_resource_drop_removed")):
		drop.connect("drop_removed", Callable(self, "_on_resource_drop_removed"))

func _on_resource_drop_changed(_drop: Node) -> void:
	job_system.mark_haul_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()

func _on_resource_drop_emptied(_drop: Node) -> void:
	_mark_group_cache_dirty(&"resource_drops")
	job_system.mark_haul_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_resource_drop_removed(_drop: Node) -> void:
	_mark_group_cache_dirty(&"resource_drops")
	job_system.mark_haul_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _connect_enemy_signals(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_signal("moved") and not enemy.is_connected("moved", Callable(self, "_on_enemy_moved")):
		enemy.connect("moved", Callable(self, "_on_enemy_moved"))

func _build_workstation_position_map() -> Dictionary:
	var out: Dictionary = {}
	for ws_id in workstation_lookup.keys():
		var ws: Resource = workstation_lookup[ws_id]
		out[ws_id] = _find_workstation_pos(ws.linked_building_id)
	return out

func _build_workstation_slots_map() -> Dictionary:
	var out: Dictionary = {}
	var seen_slot_ids: Dictionary = {}
	for ws_id_any in workstation_lookup.keys():
		out[StringName(ws_id_any)] = []
		seen_slot_ids[StringName(ws_id_any)] = {}
	for node in _get_group_nodes_cached(&"structures"):
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
			var seen: Dictionary = seen_slot_ids.get(ws_id, {})
			var slot_id: int = node.get_instance_id()
			if seen.has(slot_id):
				continue
			seen[slot_id] = true
			seen_slot_ids[ws_id] = seen
			slots.append({
				"slot_id": slot_id,
				"pos": node.global_position
			})
			out[ws_id] = slots
	for site in _get_group_nodes_cached(&"build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not bool(site.get("complete")):
			continue
		var building_id: StringName = StringName(site.get("building_id"))
		for ws_id_any in workstation_lookup.keys():
			var ws_id: StringName = StringName(ws_id_any)
			var ws: Resource = workstation_lookup[ws_id]
			if StringName(ws.linked_building_id) != building_id:
				continue
			var slots: Array = out.get(ws_id, [])
			var seen: Dictionary = seen_slot_ids.get(ws_id, {})
			var slot_id: int = site.get_instance_id()
			if seen.has(slot_id):
				continue
			seen[slot_id] = true
			seen_slot_ids[ws_id] = seen
			slots.append({
				"slot_id": slot_id,
				"pos": site.global_position
			})
			out[ws_id] = slots
	return out

func _get_cached_workstation_slots_map() -> Dictionary:
	if _workstation_slots_dirty:
		_cached_workstation_slots_map = _build_workstation_slots_map()
		_workstation_slots_dirty = false
	return _cached_workstation_slots_map

func _filter_recipes_for_workstation(workstation_id: StringName) -> Array:
	var out: Array = []
	if workstation_lookup.has(workstation_id):
		var ws: Resource = workstation_lookup[workstation_id]
		for recipe_id in ws.recipe_ids:
			if recipe_lookup.has(recipe_id):
				var recipe: Resource = recipe_lookup[recipe_id]
				if _is_recipe_unlocked(recipe):
					out.append(recipe)
		out.sort_custom(func(a, b): return String(a.id) < String(b.id))
		return out
	for recipe_id in recipe_lookup.keys():
		var recipe: Resource = recipe_lookup[recipe_id]
		if recipe.workstation_id == workstation_id and _is_recipe_unlocked(recipe):
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
			pending_building_rotation = 0

func _is_building_unlocked(def: Resource) -> bool:
	if def == null:
		return false
	var required: StringName = StringName(def.required_research)
	if required == &"":
		return true
	return bool(_research_completed.get(required, false))

func _is_recipe_unlocked(def: Resource) -> bool:
	if def == null:
		return false
	var required: StringName = StringName(def.get("required_research"))
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

func _get_research_prereq_map() -> Dictionary:
	var out: Dictionary = {}
	for key_any in research_lookup.keys():
		var rid: StringName = StringName(key_any)
		var req: StringName = &""
		var def: Resource = research_lookup.get(rid, null)
		if def != null:
			req = StringName(def.get("prerequisite_research_id"))
			if req != &"" and not research_lookup.has(req):
				req = &""
		out[rid] = req
	return out

func _get_research_lock_map() -> Dictionary:
	var prereq_map: Dictionary = _get_research_prereq_map()
	var out: Dictionary = {}
	for key_any in research_lookup.keys():
		var rid: StringName = StringName(key_any)
		var req: StringName = StringName(prereq_map.get(rid, &""))
		var unlocked: bool = req == &"" or bool(_research_completed.get(req, false))
		out[rid] = unlocked
	return out

func _can_select_research_project(project_id: StringName) -> bool:
	if project_id == &"":
		return false
	var lock_map: Dictionary = _get_research_lock_map()
	return bool(lock_map.get(project_id, true))

func _get_research_tree_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var prereq_map: Dictionary = _get_research_prereq_map()
	var lock_map: Dictionary = _get_research_lock_map()
	var children: Dictionary = {}
	for key_any in research_lookup.keys():
		var rid: StringName = StringName(key_any)
		var req: StringName = StringName(prereq_map.get(rid, &""))
		if req == &"":
			continue
		if not children.has(req):
			children[req] = []
		var arr: Array = children[req]
		arr.append(rid)
		children[req] = arr
	var roots: Array[StringName] = []
	for key_any in research_lookup.keys():
		var rid: StringName = StringName(key_any)
		var req: StringName = StringName(prereq_map.get(rid, &""))
		if req == &"":
			roots.append(rid)
	roots.sort_custom(func(a, b): return String(a) < String(b))
	var visited: Dictionary = {}
	for root in roots:
		_append_research_tree_rows(root, 0, children, prereq_map, lock_map, visited, rows)
	for key_any in research_lookup.keys():
		var rid: StringName = StringName(key_any)
		if visited.has(rid):
			continue
		_append_research_tree_rows(rid, 0, children, prereq_map, lock_map, visited, rows)
	return rows

func _append_research_tree_rows(
	research_id: StringName,
	depth: int,
	children: Dictionary,
	prereq_map: Dictionary,
	lock_map: Dictionary,
	visited: Dictionary,
	rows: Array[Dictionary]
) -> void:
	if visited.has(research_id):
		return
	visited[research_id] = true
	var def: Resource = research_lookup.get(research_id, null)
	var display_name: String = String(research_id)
	if def != null:
		display_name = String(def.display_name)
	var req: StringName = StringName(prereq_map.get(research_id, &""))
	var state: StringName = &"locked"
	if bool(_research_completed.get(research_id, false)):
		state = &"done"
	elif research_id == _active_research_id and _research_running:
		state = &"active"
	elif bool(lock_map.get(research_id, true)):
		state = &"ready"
	rows.append({
		"id": research_id,
		"name": display_name,
		"depth": depth,
		"state": state,
		"prereq": req
	})
	if not children.has(research_id):
		return
	var next_nodes: Array = children[research_id]
	next_nodes.sort_custom(func(a, b): return String(a) < String(b))
	for child_any in next_nodes:
		_append_research_tree_rows(StringName(child_any), depth + 1, children, prereq_map, lock_map, visited, rows)

func _active_research_required_points() -> float:
	if _active_research_id == &"":
		return 0.0
	if not research_lookup.has(_active_research_id):
		return 0.0
	return _scaled_research_required_points(float(research_lookup[_active_research_id].required_points))

func _scaled_research_required_points(raw_required_points: float) -> float:
	return raw_required_points * RESEARCH_REQUIRED_POINTS_SCALE

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
		&"BuildWorkSpeed":
			_build_speed_bonus_from_research = maxf(_build_speed_bonus_from_research, bonus_value)
		&"RepairWorkSpeed":
			_repair_speed_bonus_from_research = maxf(_repair_speed_bonus_from_research, bonus_value)
		&"HaulUrgencyBoost":
			_haul_urgency_bonus_from_research = maxf(_haul_urgency_bonus_from_research, bonus_value)
		&"RestRecoverBoost":
			_rest_recover_bonus_from_research = maxf(_rest_recover_bonus_from_research, bonus_value)
		&"TrapDamageBoost":
			_trap_damage_bonus_from_research = maxf(_trap_damage_bonus_from_research, bonus_value)
		&"RaidRewardBoost":
			_raid_reward_bonus_from_research = maxf(_raid_reward_bonus_from_research, bonus_value)
		&"TrapRangeBoost":
			_trap_range_bonus_from_research = maxf(_trap_range_bonus_from_research, bonus_value)
		&"EnemyDropBoost":
			_enemy_drop_bonus_from_research = maxf(_enemy_drop_bonus_from_research, bonus_value)
		&"TrapCooldownBoost":
			_trap_cooldown_bonus_from_research = maxf(_trap_cooldown_bonus_from_research, bonus_value)
		&"FarmYieldBoost":
			_farm_yield_bonus_from_research = maxf(_farm_yield_bonus_from_research, bonus_value)
		&"FarmResilienceBoost":
			_farm_resilience_bonus_from_research = maxf(_farm_resilience_bonus_from_research, bonus_value)
		&"EnemyNightSlow":
			_enemy_night_slow_bonus_from_research = maxf(_enemy_night_slow_bonus_from_research, bonus_value)
		_:
			pass

func _find_research_bench_pos() -> Vector2:
	var positions: Array[Vector2] = _find_research_bench_positions()
	if not positions.is_empty():
		return positions[0]
	return Vector2.INF

func _find_research_bench_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var seen: Dictionary = {}
	var pos: Vector2 = _find_workstation_pos(&"ResearchBench")
	if pos != Vector2.INF:
		seen[pos] = true
		positions.append(pos)
	for node in _get_group_nodes_cached(&"structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_meta("building_id"):
			continue
		if StringName(node.get_meta("building_id")) == &"ResearchBench":
			var bench_pos: Vector2 = node.global_position
			if seen.has(bench_pos):
				continue
			seen[bench_pos] = true
			positions.append(bench_pos)
	for site in _get_group_nodes_cached(&"build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not bool(site.get("complete")):
			continue
		if StringName(site.get("building_id")) != &"ResearchBench":
			continue
		var site_pos: Vector2 = site.global_position
		if seen.has(site_pos):
			continue
		seen[site_pos] = true
		positions.append(site_pos)
	positions.sort_custom(func(a: Vector2, b: Vector2):
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		return a.y < b.y
	)
	return positions

func _select_stockpile_zone_near(world_pos: Vector2) -> void:
	selected_stockpile_zone = _find_stockpile_zone_near(world_pos, TILE_SIZE * 0.75)
	_refresh_stockpile_filter_ui()

func _find_stockpile_zone_near(world_pos: Vector2, radius: float) -> Node:
	var best_inside: Node = null
	var best_inside_dist_sq: float = INF
	var best_near: Node = null
	var best_near_dist_sq: float = INF
	var radius_sq: float = radius * radius
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		var dist_sq: float = zone.global_position.distance_squared_to(world_pos)
		if zone.has_method("contains_point") and bool(zone.contains_point(world_pos)):
			if dist_sq < best_inside_dist_sq:
				best_inside_dist_sq = dist_sq
				best_inside = zone
			continue
		if dist_sq <= radius_sq and dist_sq < best_near_dist_sq:
			best_near_dist_sq = dist_sq
			best_near = zone
	if best_inside != null:
		return best_inside
	return best_near

func _find_farm_zone_near(world_pos: Vector2, radius: float) -> Node:
	for zone in _get_group_nodes_cached(&"farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("contains_point") and bool(zone.contains_point(world_pos)):
			return zone
		if zone.global_position.distance_to(world_pos) <= radius:
			return zone
	return null

func _tick_farm_zones(delta: float) -> void:
	if _game_paused:
		return
	for zone in _get_group_nodes_cached(&"farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		_configure_farm_zone_catalog(zone)
		if zone.has_method("tick_growth"):
			zone.tick_growth(delta)

func _produce_farm_jobs() -> void:
	if _game_paused:
		return
	var idle_colonists: int = 0
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.is_idle():
			idle_colonists += 1
	for zone in _get_group_nodes_cached(&"farm_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		_configure_farm_zone_catalog(zone)
		if zone.has_method("request_jobs"):
			zone.request_jobs(job_system, maxi(1, idle_colonists))

func _configure_farm_zone_catalog(zone: Node) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	if zone.has_method("set_crop_catalog"):
		zone.set_crop_catalog(crop_lookup)
	if zone.has_method("set_growth_time_multiplier"):
		zone.set_growth_time_multiplier(_farm_growth_multiplier)
	if zone.has_method("set_yield_multiplier"):
		zone.set_yield_multiplier(_farm_yield_bonus_from_research)
	if zone.has_method("set_fertility_resilience"):
		zone.set_fertility_resilience(_farm_resilience_bonus_from_research)

func _update_defense_traps(delta: float, enemies: Array = []) -> void:
	var raiders: Array = enemies
	if raiders.is_empty():
		raiders = _get_alive_raiders()
	var trap_nodes: Array = _get_group_nodes_cached(&"trap_structures")
	if _trap_service == null or not is_instance_valid(_trap_service):
		return
	var traps_changed: bool = bool(_trap_service.update_defense_traps(
		delta,
		raiders,
		trap_nodes,
		_trap_damage_bonus_from_research,
		_trap_cooldown_bonus_from_research,
		_game_paused
	))
	if traps_changed:
		_structure_maintenance_dirty = true
		_hud_dirty = true

func _get_cached_research_options() -> Array:
	var sig: int = int(research_lookup.size() * 97 + _research_completed.size() * 31 + (String(_active_research_id).hash() % 997))
	if sig == _cached_research_options_sig and not _cached_research_options.is_empty():
		return _cached_research_options
	var options: Array = []
	var keys: Array = research_lookup.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var lock_map: Dictionary = _get_research_lock_map()
	var prereq_map: Dictionary = _get_research_prereq_map()
	for key_any in keys:
		var key: StringName = StringName(key_any)
		var def: Resource = research_lookup[key]
		var unlocked: bool = bool(lock_map.get(key, true))
		var req: StringName = StringName(prereq_map.get(key, &""))
		var scaled_required: float = _scaled_research_required_points(float(def.required_points))
		var label: String = "%s (%.1f)%s" % [String(def.display_name), scaled_required, "" if unlocked else " [%s]" % _t("common.locked")]
		if not unlocked and req != &"":
			label += " <- %s" % String(req)
		options.append({
			"id": key,
			"label": label
		})
	_cached_research_options = options
	_cached_research_options_sig = sig
	return _cached_research_options

func _record_frame_profile(delta: float) -> void:
	if _perf_telemetry_service != null and is_instance_valid(_perf_telemetry_service):
		_perf_telemetry_service.record_frame(
			_raid_state,
			_cached_alive_enemies.size(),
			colonists.size(),
			_enemy_engagement_coordinator,
			_pathing_occupancy,
			_enemy_flow_field_service
		)
		return
	if not _perf_logging_enabled:
		return
	var now_usec: int = Time.get_ticks_usec()
	var now_ms: int = Time.get_ticks_msec()
	_report_combat_window_if_due(now_ms)
	if _perf_last_ticks_usec <= 0:
		_perf_last_ticks_usec = now_usec
		return
	var dt_real: float = float(now_usec - _perf_last_ticks_usec) / 1000000.0
	_perf_last_ticks_usec = now_usec
	if dt_real <= 0.0 or dt_real < 0.0015:
		return
	if _perf_samples.size() < PERF_RING_SIZE:
		_perf_samples.append(dt_real)
		_perf_samples_count = _perf_samples.size()
	else:
		_perf_samples[_perf_samples_head] = dt_real
		_perf_samples_head = (_perf_samples_head + 1) % PERF_RING_SIZE
		_perf_samples_count = PERF_RING_SIZE
	if now_ms < _perf_report_next_ms:
		return
	if _perf_samples_count <= 0:
		_perf_report_next_ms = now_ms + 5000
		return
	var sorted_samples: Array = _perf_samples.duplicate()
	sorted_samples.sort()
	var sum: float = 0.0
	for v_any in sorted_samples:
		sum += float(v_any)
	var sample_count: int = sorted_samples.size()
	var avg_dt: float = sum / float(sample_count)
	var p95_index: int = int(floor(float(sample_count - 1) * 0.95))
	var p95_dt: float = float(sorted_samples[clampi(p95_index, 0, sample_count - 1)])
	var p99_index: int = int(floor(float(sample_count - 1) * 0.99))
	var p99_dt: float = float(sorted_samples[clampi(p99_index, 0, sample_count - 1)])
	var fast_index: int = int(floor(float(sample_count - 1) * 0.02))
	var fast_dt: float = float(sorted_samples[clampi(fast_index, 0, sample_count - 1)])
	var max_dt: float = float(sorted_samples[sample_count - 1])
	var hitch_33: int = 0
	var hitch_100: int = 0
	var hitch_250: int = 0
	for sample_any in sorted_samples:
		var sample: float = float(sample_any)
		if sample >= (1.0 / 30.0):
			hitch_33 += 1
		if sample >= 0.1:
			hitch_100 += 1
		if sample >= 0.25:
			hitch_250 += 1
	var avg_fps: float = 1.0 / maxf(0.0001, avg_dt)
	var p95_fps: float = 1.0 / maxf(0.0001, p95_dt)
	var p99_fps: float = 1.0 / maxf(0.0001, p99_dt)
	var max_fps: float = 1.0 / maxf(0.0001, fast_dt)
	var render_fps: float = Engine.get_frames_per_second()
	print("[Perf][Wave] render_fps=%.1f avg_fps=%.1f p95_fps=%.1f p99_fps=%.1f peak_fps=%.1f max_dt_ms=%.1f hitch33=%d hitch100=%d hitch250=%d samples=%d raid=%s" % [
		render_fps, avg_fps, p95_fps, p99_fps, max_fps, max_dt * 1000.0, hitch_33, hitch_100, hitch_250, sample_count, String(_raid_state)
	])
	_report_enemy_perf_snapshot()
	_perf_report_next_ms = now_ms + 5000

func _report_enemy_perf_snapshot() -> void:
	if _perf_telemetry_service != null and is_instance_valid(_perf_telemetry_service):
		_perf_telemetry_service.report_enemy_perf_snapshot(_enemy_engagement_coordinator, _pathing_occupancy, _enemy_flow_field_service)
		return
	var enemy_perf: Dictionary = EnemyUnitBase.consume_perf_stats()
	var coordinator_stats: Dictionary = {}
	if _enemy_engagement_coordinator != null and is_instance_valid(_enemy_engagement_coordinator) and _enemy_engagement_coordinator.has_method("get_debug_stats"):
		coordinator_stats = _enemy_engagement_coordinator.get_debug_stats()
	var occupancy_stats: Dictionary = {}
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("get_debug_stats"):
		occupancy_stats = _pathing_occupancy.get_debug_stats()
	var flow_stats: Dictionary = {}
	if _enemy_flow_field_service != null and is_instance_valid(_enemy_flow_field_service) and _enemy_flow_field_service.has_method("get_debug_stats"):
		flow_stats = _enemy_flow_field_service.get_debug_stats()
	print("[Perf][Enemy] units=%d steps=%d move=%.2f ai=%.2f coord_req=%d coord_builds=%d coord_ms=%.2f dyn_block=%.2f dyn_units=%d flow_build=%.2f flow_exp=%d" % [
		int(enemy_perf.get("units", 0)),
		int(enemy_perf.get("steps", 0)),
		float(enemy_perf.get("move_ms", 0.0)),
		float(enemy_perf.get("ai_ms", 0.0)),
		int(coordinator_stats.get("requests", 0)),
		int(coordinator_stats.get("target_context_builds", 0)),
		float(coordinator_stats.get("total_request_ms", 0.0)),
		float(occupancy_stats.get("last_dynamic_ms", 0.0)),
		int(occupancy_stats.get("dynamic_units", 0)),
		float(flow_stats.get("last_build_ms", 0.0)),
		int(flow_stats.get("last_expansions", 0))
	])

func _reset_combat_window() -> void:
	if _perf_telemetry_service != null and is_instance_valid(_perf_telemetry_service):
		_perf_telemetry_service.reset_combat_window()
	_combat_window = {
		"colonist_attempts": 0,
		"colonist_hits": 0,
		"colonist_damage": 0,
		"colonist_kills": 0,
		"colonist_ranged_attempts": 0,
		"colonist_ranged_hits": 0,
		"enemy_attempts": 0,
		"enemy_hits": 0,
		"enemy_damage": 0,
		"enemy_kills": 0
	}

func report_combat_event(source_side: StringName, hit: bool, damage: int, kill: bool, attack_mode: StringName = &"", target_node: Node = null) -> void:
	_spawn_combat_feedback_text(source_side, hit, damage, kill, target_node)
	if _perf_telemetry_service != null and is_instance_valid(_perf_telemetry_service):
		_perf_telemetry_service.report_combat_event(source_side, hit, damage, kill, attack_mode)
		return
	if _combat_window.is_empty():
		_reset_combat_window()
	if source_side == &"Colonist":
		_combat_window["colonist_attempts"] = int(_combat_window.get("colonist_attempts", 0)) + 1
		if attack_mode == &"CombatRanged" or attack_mode == &"Ranged":
			_combat_window["colonist_ranged_attempts"] = int(_combat_window.get("colonist_ranged_attempts", 0)) + 1
		if hit:
			_combat_window["colonist_hits"] = int(_combat_window.get("colonist_hits", 0)) + 1
			_combat_window["colonist_damage"] = int(_combat_window.get("colonist_damage", 0)) + maxi(0, damage)
			if attack_mode == &"CombatRanged" or attack_mode == &"Ranged":
				_combat_window["colonist_ranged_hits"] = int(_combat_window.get("colonist_ranged_hits", 0)) + 1
		if kill:
			_combat_window["colonist_kills"] = int(_combat_window.get("colonist_kills", 0)) + 1
		return
	if source_side == &"Enemy":
		_combat_window["enemy_attempts"] = int(_combat_window.get("enemy_attempts", 0)) + 1
		if hit:
			_combat_window["enemy_hits"] = int(_combat_window.get("enemy_hits", 0)) + 1
			_combat_window["enemy_damage"] = int(_combat_window.get("enemy_damage", 0)) + maxi(0, damage)
		if kill:
			_combat_window["enemy_kills"] = int(_combat_window.get("enemy_kills", 0)) + 1

func _spawn_combat_feedback_text(source_side: StringName, hit: bool, damage: int, kill: bool, target_node: Node) -> void:
	if target_node == null or not is_instance_valid(target_node) or not (target_node is Node2D):
		return
	var text: String = "MISS"
	var text_color: Color = Color(0.78, 0.82, 0.88, 0.95)
	var font_size: int = 15
	if hit:
		text = str(maxi(0, damage))
		text_color = Color(1.0, 0.30, 0.24, 1.0) if source_side == &"Enemy" else Color(1.0, 0.82, 0.26, 1.0)
		font_size = 20 if kill else 18
	var label := Label.new()
	label.name = "CombatFeedbackText"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(72.0, 24.0)
	label.size = label.custom_minimum_size
	label.z_as_relative = false
	label.z_index = 1000
	label.add_to_group("combat_feedback_text")
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	var parent_node: Node = units_root if units_root != null and is_instance_valid(units_root) else self
	parent_node.add_child(label)
	var target_2d: Node2D = target_node as Node2D
	var origin: Vector2 = _combat_feedback_origin(target_2d)
	var jitter_seed: int = int(Time.get_ticks_msec() + target_2d.get_instance_id() + damage * 17)
	origin.x += float(posmod(jitter_seed, 17) - 8)
	var local_origin: Vector2 = origin
	if parent_node is Node2D:
		local_origin = (parent_node as Node2D).to_local(origin)
	label.position = local_origin - label.size * 0.5
	label.scale = Vector2(0.84, 0.84)
	var start_pos: Vector2 = label.position
	var end_pos: Vector2 = start_pos + Vector2(0.0, -COMBAT_FEEDBACK_FLOAT_DISTANCE)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position", end_pos, COMBAT_FEEDBACK_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, COMBAT_FEEDBACK_DURATION * 0.65).set_delay(COMBAT_FEEDBACK_DURATION * 0.35)
	tw.chain().tween_callback(label.queue_free)

func _combat_feedback_origin(target_node: Node2D) -> Vector2:
	var sprite: Sprite2D = target_node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		return sprite.global_position + sprite.offset + Vector2(0.0, -8.0)
	return target_node.global_position + COMBAT_FEEDBACK_BODY_OFFSET

func _report_combat_window_if_due(now_ms: int) -> void:
	if _raid_state != &"Active":
		_combat_log_next_ms = 0
		_reset_combat_window()
		return
	if _combat_log_next_ms <= 0:
		_combat_log_next_ms = now_ms + 5000
		return
	if now_ms < _combat_log_next_ms:
		return
	print("[Combat][Window] raid=%s enemies=%d colonists=%d c_att=%d c_hit=%d c_dmg=%d c_kill=%d c_rng_att=%d c_rng_hit=%d e_att=%d e_hit=%d e_dmg=%d e_kill=%d" % [
		String(_raid_state),
		_cached_alive_enemies.size(),
		colonists.size(),
		int(_combat_window.get("colonist_attempts", 0)),
		int(_combat_window.get("colonist_hits", 0)),
		int(_combat_window.get("colonist_damage", 0)),
		int(_combat_window.get("colonist_kills", 0)),
		int(_combat_window.get("colonist_ranged_attempts", 0)),
		int(_combat_window.get("colonist_ranged_hits", 0)),
		int(_combat_window.get("enemy_attempts", 0)),
		int(_combat_window.get("enemy_hits", 0)),
		int(_combat_window.get("enemy_damage", 0)),
		int(_combat_window.get("enemy_kills", 0))
	])
	_reset_combat_window()
	_combat_log_next_ms = now_ms + 5000

func _compute_enemy_sim_interval_scale(enemy_count: int) -> float:
	if _combat_raid_service != null and is_instance_valid(_combat_raid_service):
		return float(_combat_raid_service.compute_enemy_sim_interval_scale(_raid_state, enemy_count))
	if _raid_state != &"Active":
		return 1.0
	if enemy_count <= 16:
		return 1.0
	if enemy_count <= 32:
		return 1.25
	if enemy_count <= 56:
		return 1.55
	if enemy_count <= 84:
		return 1.9
	return 2.3

func _compute_friendly_pathing_budget_scale(enemy_count: int) -> float:
	if _combat_raid_service != null and is_instance_valid(_combat_raid_service):
		return float(_combat_raid_service.compute_friendly_pathing_budget_scale(_raid_state, enemy_count))
	if _raid_state != &"Active":
		return 1.0
	if enemy_count <= 0:
		return 1.0
	if enemy_count <= 8:
		return 2.5
	if enemy_count <= 16:
		return 3.0
	return 3.5

func _apply_enemy_sim_budget(enemies: Array, interval_scale: float) -> void:
	if _combat_raid_service != null and is_instance_valid(_combat_raid_service):
		_combat_raid_service.apply_enemy_sim_budget(enemies, interval_scale)
		return
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_sim_interval_scale"):
			enemy.set_sim_interval_scale(interval_scale)

func _apply_friendly_pathing_budget(scale: float) -> void:
	if _combat_raid_service != null and is_instance_valid(_combat_raid_service):
		_combat_raid_service.apply_friendly_pathing_budget(colonists, scale)
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("set_pathing_budget_scale"):
			colonist.set_pathing_budget_scale(scale)

func _refresh_structure_integrity() -> void:
	for node in _get_group_nodes_cached(&"repairable_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var max_hp: float = float(node.get_meta("structure_max_health")) if node.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(node.get_meta("structure_health")) if node.has_meta("structure_health") else max_hp
		hp = clampf(hp, 0.0, max_hp)
		node.set_meta("structure_health", hp)
		STRUCTURE_HEALTH_BAR.update_bar(node, hp, max_hp)

func _get_damaged_repairable_structures() -> Array:
	_refresh_structure_maintenance_cache()
	return _cached_damaged_repairables

func _get_maintainable_traps() -> Array:
	_refresh_structure_maintenance_cache()
	return _cached_maintainable_traps

func _refresh_structure_maintenance_cache() -> void:
	if not _structure_maintenance_dirty:
		return
	_structure_maintenance_dirty = false
	_cached_damaged_repairables.clear()
	_cached_maintainable_traps.clear()
	for node in _get_group_nodes_cached(&"repairable_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var max_hp: float = float(node.get_meta("structure_max_health")) if node.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(node.get_meta("structure_health")) if node.has_meta("structure_health") else max_hp
		var threshold_ratio: float = _auto_repair_threshold_ratio
		if node.has_meta("building_id"):
			var building_id: StringName = StringName(node.get_meta("building_id"))
			if building_id == &"Wall" or building_id == &"Gate":
				threshold_ratio = minf(0.9, threshold_ratio + 0.08)
		if _is_night_time():
			threshold_ratio *= 0.85
		var threshold_hp: float = max_hp * threshold_ratio
		if hp < threshold_hp:
			_cached_damaged_repairables.append(node)
	var pending_count: int = 0
	var depleted_count: int = 0
	var missing_charge_total: int = 0
	for trap in _get_group_nodes_cached(&"trap_structures"):
		if trap == null or not is_instance_valid(trap):
			continue
		var max_charges: int = int(trap.get_meta("trap_max_charges")) if trap.has_meta("trap_max_charges") else int(trap.get_meta("trap_charges"))
		if max_charges <= 0:
			continue
		var charges: int = int(trap.get_meta("trap_charges"))
		missing_charge_total += maxi(0, max_charges - charges)
		if charges <= 0:
			depleted_count += 1
		if charges >= max_charges:
			continue
		_cached_maintainable_traps.append(trap)
		if bool(trap.get_meta("trap_maint_job_queued")):
			pending_count += 1
	var estimated_batches: int = maxi(1, int(ceil(float(missing_charge_total) / 2.0)))
	var maintain_affordable: bool = int(resource_stock.get(&"Wood", 0)) >= estimated_batches and int(resource_stock.get(&"Steel", 0)) >= estimated_batches
	var maint_state: String = _t("main.defense.maint.state.ok") if maintain_affordable else _t("main.defense.maint.state.lack")
	_defense_status_text = _t("main.defense.maint.summary", {
		"repair": _cached_damaged_repairables.size(),
		"pending": pending_count,
		"depleted": depleted_count,
		"wood": estimated_batches,
		"steel": estimated_batches,
		"state": maint_state
	})

func _haul_urgency_multiplier_by_colony_state() -> float:
	var avg_hunger: float = 100.0
	var avg_rest: float = 100.0
	var alive: int = 0
	for c in colonists:
		if c == null or not is_instance_valid(c):
			continue
		avg_hunger += c.hunger
		avg_rest += c.rest
		alive += 1
	if alive > 0:
		avg_hunger = avg_hunger / float(alive + 1)
		avg_rest = avg_rest / float(alive + 1)
	var hunger_boost: float = 1.0
	if avg_hunger < 45.0:
		hunger_boost = 1.5
	elif avg_hunger < 65.0:
		hunger_boost = 1.2
	var rest_boost: float = 1.0
	if avg_rest < 40.0:
		rest_boost = 1.22
	var shortage_boost: float = 1.0
	var core_materials: int = int(resource_stock.get(&"Wood", 0)) + int(resource_stock.get(&"Stone", 0))
	if core_materials < 30:
		shortage_boost = 1.18
	return _haul_urgency_bonus_from_research * hunger_boost * rest_boost * shortage_boost

func _refresh_stockpile_filter_ui() -> void:
	if selected_stockpile_zone == null or not is_instance_valid(selected_stockpile_zone):
		hud.set_stockpile_filter_state(false, 0, {}, 0, {})
		hud.set_stockpile_presets(_get_stockpile_preset_options(), &"")
		return
	if not selected_stockpile_zone.has_method("get_filter_snapshot"):
		hud.set_stockpile_filter_state(false, 0, {}, 0, {})
		hud.set_stockpile_presets(_get_stockpile_preset_options(), &"")
		return
	var snapshot: Dictionary = selected_stockpile_zone.get_filter_snapshot()
	hud.set_stockpile_filter_state(
		true,
		int(snapshot.get("mode", 0)),
		snapshot.get("items", {}),
		int(snapshot.get("priority", 0)),
		snapshot.get("limits", {})
	)
	var selected_preset: StringName = StringName(snapshot.get("preset_id", &""))
	hud.set_stockpile_presets(_get_stockpile_preset_options(), selected_preset)

func _get_stockpile_preset_options() -> Array:
	return [
		{"id": &"All", "label": _t("main.stock.preset.all")},
		{"id": &"Food", "label": _t("main.stock.preset.food")},
		{"id": &"War", "label": _t("main.stock.preset.war")},
		{"id": &"Build", "label": _t("main.stock.preset.build")},
		{"id": &"Industry", "label": _t("main.stock.preset.industry")},
		{"id": &"Emergency", "label": _t("main.stock.preset.emergency")},
		{"id": &"Harvest", "label": _t("main.stock.preset.harvest")}
	]

func try_consume_trap_maintenance_cost(batch_count: int = 1) -> bool:
	var need: int = maxi(1, batch_count)
	if int(resource_stock.get(&"Wood", 0)) < need:
		return false
	if int(resource_stock.get(&"Steel", 0)) < need:
		return false
	return _consume_resource_stock(&"Wood", need) and _consume_resource_stock(&"Steel", need)

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

func _is_night_time() -> bool:
	var phase: float = fmod(_elapsed_game_seconds, _day_night_cycle_seconds)
	return phase >= (_day_night_cycle_seconds * 0.5)

func _day_night_lerp() -> float:
	if _day_night_cycle_seconds <= 0.01:
		return 1.0
	var phase: float = fmod(_elapsed_game_seconds, _day_night_cycle_seconds) / _day_night_cycle_seconds
	return 0.5 + 0.5 * cos(phase * TAU)

func _day_night_move_multiplier() -> float:
	return lerpf(0.9, 1.06, _day_night_lerp())

func _day_night_combat_accuracy_bonus() -> float:
	return lerpf(-0.03, 0.025, _day_night_lerp())

func _apply_day_night_to_enemies(enemies: Array = []) -> void:
	if _combat_raid_service != null and is_instance_valid(_combat_raid_service):
		var target_enemies_for_service: Array = enemies
		if target_enemies_for_service.is_empty():
			target_enemies_for_service = _get_alive_raiders()
		_combat_raid_service.apply_day_night_to_enemies(target_enemies_for_service, _elapsed_game_seconds, _enemy_night_slow_bonus_from_research)
		return
	var t: float = _day_night_lerp()
	var move_mul: float = lerpf(0.95, 1.05, t)
	if _is_night_time():
		move_mul /= maxf(1.0, _enemy_night_slow_bonus_from_research)
	var acc_bonus: float = lerpf(-0.02, 0.02, t)
	var target_enemies: Array = enemies
	if target_enemies.is_empty():
		target_enemies = _get_alive_raiders()
	for enemy in target_enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_external_move_speed_multiplier"):
			enemy.set_external_move_speed_multiplier(move_mul)
		if enemy.has_method("set_external_accuracy_bonus"):
			enemy.set_external_accuracy_bonus(acc_bonus)

func _configure_world_bounds() -> void:
	var p0: Vector2 = Vector2.ZERO
	var p1: Vector2 = Vector2(WORLD_SIZE.x, 0.0)
	var p2: Vector2 = WORLD_SIZE
	var p3: Vector2 = Vector2(0.0, WORLD_SIZE.y)
	var ground: Polygon2D = world_root.get_node_or_null("Ground")
	if ground != null:
		ground.polygon = PackedVector2Array([p0, p1, p2, p3])
	var asphalt_background: Node = world_root.get_node_or_null("AsphaltBackground")
	if asphalt_background != null and asphalt_background.has_method("setup"):
		asphalt_background.setup(WORLD_SIZE, TILE_SIZE)
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

func _load_vehicle_defs() -> Array:
	var defs: Array = []
	var dir := DirAccess.open(VEHICLE_DEF_DIR)
	if dir == null:
		return defs
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "%s/%s" % [VEHICLE_DEF_DIR, file_name]
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
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not bool(site.get("complete")):
			continue
		var building_id: StringName = StringName(site.get("building_id"))
		for ws_id_any in workstation_lookup.keys():
			var ws_id: StringName = StringName(ws_id_any)
			var ws: Resource = workstation_lookup[ws_id]
			if StringName(ws.linked_building_id) != building_id:
				continue
			var dist: float = site.global_position.distance_to(world_pos)
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
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not bool(site.get("complete")):
			continue
		if not site.has_method("get"):
			continue
		var building_id: StringName = StringName(site.get("building_id"))
		if target_building_id != &"" and building_id != target_building_id:
			continue
		var dist: float = site.global_position.distance_to(world_pos)
		if dist > best_dist:
			continue
		best_dist = dist
		best_node = site
	return best_node

func _activate_workstation(workstation_id: StringName) -> void:
	if workstation_id == &"":
		hud.set_craft_panel_visible(false)
		_close_bottom_catalog_if_supported()
		return
	selected_workstation_id = workstation_id
	hud.set_selected_workstation(workstation_id)
	if _is_research_workstation(workstation_id):
		hud.set_craft_panel_visible(false)
		_open_research_catalog_if_supported()
		return
	hud.set_recipe_catalog(_filter_recipes_for_workstation(workstation_id))
	hud.set_craft_queue_paused_state(job_system.is_craft_queue_paused(workstation_id))
	hud.set_craft_panel_visible(true, _get_workstation_display_name(workstation_id))
	_open_craft_catalog_if_supported()

func _get_workstation_display_name(workstation_id: StringName) -> String:
	if workstation_lookup.has(workstation_id):
		var ws: Resource = workstation_lookup[workstation_id]
		return ws.display_name
	return String(workstation_id)

func _is_research_workstation(workstation_id: StringName) -> bool:
	if workstation_id == &"" or not workstation_lookup.has(workstation_id):
		return false
	var ws: Resource = workstation_lookup[workstation_id]
	return StringName(ws.linked_building_id) == &"ResearchBench"

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / TILE_SIZE)),
		int(round(world_pos.y / TILE_SIZE))
	)

func _tile_to_world(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) * TILE_SIZE, float(tile.y) * TILE_SIZE)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return _tile_to_world(_world_to_tile(world_pos))

func _snap_building_to_grid(world_pos: Vector2, building_id: StringName, rotation_index: int = 0) -> Vector2:
	var footprint: Vector2 = Vector2(TILE_SIZE, TILE_SIZE)
	var def: Resource = _find_building_def(building_id)
	if def != null:
		footprint = _effective_building_footprint(def, rotation_index)
	return _snap_footprint_to_grid(world_pos, footprint)

func _snap_footprint_to_grid(world_pos: Vector2, footprint_size: Vector2) -> Vector2:
	return Vector2(
		_snap_axis_to_footprint_grid(world_pos.x, footprint_size.x),
		_snap_axis_to_footprint_grid(world_pos.y, footprint_size.y)
	)

func _snap_axis_to_footprint_grid(value: float, footprint_axis: float) -> float:
	var cells: int = maxi(1, int(round(footprint_axis / TILE_SIZE)))
	var offset: float = TILE_SIZE * 0.5 if cells % 2 == 0 else 0.0
	return round((value - offset) / TILE_SIZE) * TILE_SIZE + offset

func _can_drag_line_place(building_id: StringName) -> bool:
	return building_id == &"Wall" or building_id == &"Gate" or building_id == &"FiringWall"

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

func _pending_building_rotation_for(building_id: StringName) -> int:
	if pending_building_id != building_id:
		return 0
	var def: Resource = _find_building_def(building_id)
	return _normalized_building_rotation(def, pending_building_rotation)

func _rotate_pending_building() -> void:
	if pending_building_id == &"":
		return
	var def: Resource = _find_building_def(pending_building_id)
	if def == null or not bool(def.get("rotatable")):
		return
	pending_building_rotation = int(posmod(pending_building_rotation + 1, 4))
	_hud_dirty = true
	queue_redraw()

func _normalized_building_rotation(def: Resource, rotation_index: int) -> int:
	if def == null or not bool(def.get("rotatable")):
		return 0
	return int(posmod(rotation_index, 4))

func _effective_building_footprint(def: Resource, rotation_index: int) -> Vector2:
	if def == null:
		return Vector2(TILE_SIZE, TILE_SIZE)
	var footprint: Vector2 = def.footprint_size
	if bool(def.get("rotatable")) and int(posmod(rotation_index, 4)) % 2 == 1:
		return Vector2(footprint.y, footprint.x)
	return footprint

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
	if colonist.get("combat_ready") == true:
		return true
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

func _apply_combat_tile_occupancy(enemies: Array = []) -> void:
	# Skipped for performance: hard occupancy snaps were removed and
	# this pass became an avoidable O(units) loop during raids.
	return
	_combat_tile_claims.clear()
	var raid_active: bool = _raid_state == &"Active"
	var combat_units: Array[Node2D] = []
	for c in colonists:
		if _is_colonist_in_combat(c):
			combat_units.append(c)
	# Units can overlap in normal state; enforce one-unit-per-tile only in combat.
	if raid_active:
		var enemy_list: Array = enemies
		if enemy_list.is_empty():
			enemy_list = _get_alive_raiders()
		for r in enemy_list:
			if r != null and is_instance_valid(r):
				combat_units.append(r)
	if combat_units.is_empty():
		return
	for unit in combat_units:
		var preferred_tile: Vector2i = _world_to_tile(unit.global_position)
		var assigned_tile: Vector2i = _find_free_combat_tile(preferred_tile, 2)
		_combat_tile_claims[assigned_tile] = unit.get_instance_id()
	# Do not forcibly snap unit positions. Hard snapping can cause wall clipping and jitter
	# when units are enclosed; claims are kept for lightweight occupancy bookkeeping only.

func _sanitize_selected_colonists() -> void:
	if selected_colonists.is_empty():
		return
	var valid: Array = []
	for c in selected_colonists:
		if c == null or not is_instance_valid(c):
			continue
		valid.append(c)
	selected_colonists = valid

func _t(key: String, params: Dictionary = {}, fallback: String = "") -> String:
	return GAME_TEXT.get_text(key, params, fallback)
