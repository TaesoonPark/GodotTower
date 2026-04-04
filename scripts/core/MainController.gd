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
const PATHING_OCCUPANCY_SCRIPT: Script = preload("res://scripts/systems/PathingOccupancy.gd")
const DEFAULT_LOADOUT: ColonistLoadoutData = preload("res://data/colonists/default_loadout.tres")
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
	&"Wood": 0,
	&"Stone": 0,
	&"Steel": 0,
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
var _auto_repair_threshold_ratio: float = 0.75
var _defense_status_text: String = "-"
var _day_night_cycle_seconds: float = 240.0
var _pathing_occupancy: PathingOccupancy = null
var _cached_alive_enemies: Array = []
var _hud_dirty: bool = true
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
var _dispatch_queued: bool = false
var _dispatch_jobs_dirty: bool = true
var _dispatch_combat_dirty: bool = true
var _dispatch_economy_dirty: bool = true
var _dispatch_maintenance_dirty: bool = true
var _dispatch_farm_dirty: bool = true
var _dispatch_pathing_dirty: bool = true
var _dispatch_traps_dirty: bool = true
const TRAP_UPDATE_INTERVAL_SEC: float = 0.12
var _trap_update_accum: float = 0.0
var _trap_move_event_next_ms: int = 0
const TRAP_MAX_PER_UPDATE: int = 42
var _trap_update_cursor: int = 0
var _active_jobs_next_ms: int = 0
var _has_demolish_overlay: bool = false
var _last_hud_time_tick: int = -1
var _workstation_slots_dirty: bool = true
var _cached_workstation_slots_map: Dictionary = {}
var _structure_maintenance_dirty: bool = true
var _cached_damaged_repairables: Array = []
var _cached_maintainable_traps: Array = []
var _need_job_refresh_next_ms_by_colonist: Dictionary = {}
var _group_cache: Dictionary = {}
var _group_cache_dirty: Dictionary = {}

func _ready() -> void:
	add_to_group("main_controller")
	randomize()
	_pathing_occupancy = PATHING_OCCUPANCY_SCRIPT.new()
	_pathing_occupancy.name = "PathingOccupancy"
	var systems_node: Node = get_node_or_null("Systems")
	if systems_node != null:
		systems_node.add_child(_pathing_occupancy)
	else:
		add_child(_pathing_occupancy)
	_pathing_occupancy.add_to_group("pathing_occupancy")
	_pathing_occupancy.setup(TILE_SIZE)
	_init_group_cache()
	var now_ms: int = Time.get_ticks_msec()
	_perf_report_next_ms = now_ms + 5000
	_perf_last_ticks_usec = Time.get_ticks_usec()
	_reset_combat_window()
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
	_apply_starting_loadout(DEFAULT_LOADOUT)
	_set_combat_rally_point(_snap_to_tile(WORLD_SIZE * 0.5))
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
	hud.craft_recipe_front_queued.connect(_on_craft_recipe_front_queued)
	hud.craft_queue_clear_requested.connect(_on_craft_queue_clear_requested)
	hud.craft_queue_remove_requested.connect(_on_craft_queue_remove_requested)
	hud.craft_queue_pause_toggled.connect(_on_craft_queue_pause_toggled)
	hud.stockpile_filter_mode_changed.connect(_on_stockpile_filter_mode_changed)
	hud.stockpile_filter_item_changed.connect(_on_stockpile_filter_item_changed)
	hud.stockpile_priority_changed.connect(_on_stockpile_priority_changed)
	hud.stockpile_limit_changed.connect(_on_stockpile_limit_changed)
	hud.stockpile_preset_apply_requested.connect(_on_stockpile_preset_apply_requested)
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
	if hud == null or not is_instance_valid(hud):
		return
	var building_id: StringName = _get_gui_playtest_building_id()
	if hud.has_method("get_building_button_rect"):
		var rect: Rect2 = hud.get_building_button_rect(building_id)
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
		return center + Vector2(200.0, 0.0)
	var ring_steps: Array[Vector2] = [
		Vector2(160.0, 0.0),
		Vector2(200.0, 0.0),
		Vector2(160.0, 80.0),
		Vector2(200.0, 80.0),
		Vector2(120.0, -80.0),
		Vector2(240.0, -40.0),
		Vector2(240.0, 120.0)
	]
	for offset in ring_steps:
		var probe: Vector2 = _snap_to_tile(center + offset)
		if build_system != null and is_instance_valid(build_system) and build_system.has_method("_is_footprint_occupied"):
			if bool(build_system._is_footprint_occupied(probe, def.footprint_size)):
				continue
		return probe
	return _snap_to_tile(center + Vector2(240.0, 0.0))

func _world_to_screen_point(world_pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom: Vector2 = camera.zoom if camera != null else Vector2.ONE
	var cam_pos: Vector2 = camera.global_position if camera != null else Vector2.ZERO
	return (world_pos - cam_pos) / zoom + viewport_size * 0.5

func _init_group_cache() -> void:
	var hot_groups: Array[StringName] = [
		&"stockpile_zones",
		&"resource_drops",
		&"gatherables",
		&"huntables",
		&"structures",
		&"farm_zones",
		&"raiders",
		&"trap_structures",
		&"repairable_structures",
		&"build_sites"
	]
	for group_name in hot_groups:
		_group_cache_dirty[group_name] = true
	if get_tree() != null:
		if not get_tree().is_connected("node_added", Callable(self, "_on_tree_node_added")):
			get_tree().connect("node_added", Callable(self, "_on_tree_node_added"))
		if not get_tree().is_connected("node_removed", Callable(self, "_on_tree_node_removed")):
			get_tree().connect("node_removed", Callable(self, "_on_tree_node_removed"))

func _on_tree_node_added(_node: Node) -> void:
	_mark_group_cache_for_node(_node)
	if _node == null:
		return
	if _node.is_in_group("blocking_structures") or _node.is_in_group("build_sites") or _node.is_in_group("structures"):
		_mark_pathing_dirty()

func _on_tree_node_removed(_node: Node) -> void:
	_mark_group_cache_for_node(_node)
	if _node == null:
		return
	if _node.is_in_group("blocking_structures") or _node.is_in_group("build_sites") or _node.is_in_group("structures"):
		_mark_pathing_dirty()

func _mark_group_cache_dirty(group_name: StringName) -> void:
	_group_cache_dirty[group_name] = true

func _mark_all_group_cache_dirty() -> void:
	for group_name_any in _group_cache_dirty.keys():
		_group_cache_dirty[group_name_any] = true

func _mark_group_cache_for_node(node: Node) -> void:
	if node == null:
		return
	for group_name_any in _group_cache_dirty.keys():
		var group_name: StringName = StringName(group_name_any)
		if node.is_in_group(group_name):
			_group_cache_dirty[group_name] = true

func _get_group_nodes_cached(group_name: StringName) -> Array:
	if bool(_group_cache_dirty.get(group_name, true)):
		_group_cache[group_name] = get_tree().get_nodes_in_group(StringName(group_name))
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
	var time_tick: int = int(floor(_elapsed_game_seconds * 10.0))
	if time_tick != _last_hud_time_tick:
		_last_hud_time_tick = time_tick
		_hud_dirty = true
	_update_raid_state(delta)
	if _raid_state == &"Active":
		_trap_update_accum += delta
		if _trap_update_accum >= TRAP_UPDATE_INTERVAL_SEC:
			_dispatch_traps_dirty = true
			_queue_event_dispatch()
	if _has_pending_dispatch():
		_dispatch_event_updates()

func _queue_event_dispatch() -> void:
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
		or _hud_dirty

func _mark_pathing_dirty() -> void:
	_dispatch_pathing_dirty = true
	_workstation_slots_dirty = true
	_structure_maintenance_dirty = true
	_mark_all_group_cache_dirty()
	_queue_event_dispatch()

func _mark_jobs_dirty() -> void:
	_dispatch_jobs_dirty = true
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_assign_dirty"):
		job_system.mark_assign_dirty()
	_queue_event_dispatch()

func _mark_combat_dirty() -> void:
	_dispatch_combat_dirty = true
	_dispatch_traps_dirty = true
	_mark_group_cache_dirty(&"raiders")
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
	if job_system != null and is_instance_valid(job_system) and job_system.has_method("mark_designation_dirty"):
		job_system.mark_designation_dirty()
	_queue_event_dispatch()

func _dispatch_event_updates() -> void:
	_dispatch_queued = false
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
		_update_farm_zones(0.2)
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
			var rally_pos: Vector2 = _combat_rally_point if _outfit_mode == &"Combat" else Vector2.INF
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
			job_system.process_dirty(
				colonists,
				enemies,
				_get_group_nodes_cached(&"resource_drops"),
				haul_targets,
				resource_stock,
				target_stock,
				rally_pos,
				TILE_SIZE * 3.0,
				max_combatants,
				recipe_lookup,
				_get_cached_workstation_slots_map(),
				Callable(self, "_can_start_recipe_at_workstation"),
				Callable(self, "_on_recipe_started_at_workstation"),
				_find_research_bench_pos(),
				_active_research_id if _research_running else &"",
				_get_damaged_repairable_structures(),
				_get_maintainable_traps(),
				_get_group_nodes_cached(&"gatherables"),
				_get_group_nodes_cached(&"huntables"),
				_raid_state == &"Active"
			)
			_dispatch_jobs_dirty = false
		dt_jobs_us = Time.get_ticks_usec() - t_us
	if _hud_dirty:
		var t_us: int = Time.get_ticks_usec()
		hud.set_craft_queue_preview(job_system.get_craft_queue(selected_workstation_id))
		hud.set_time_flow_state(_game_paused, _speed_scale, _elapsed_game_seconds)
		hud.set_raid_state(_raid_state, _raid_warning_timer, _raid_wave_kind)
		hud.set_research_state(_active_research_id, _active_research_points, _active_research_required_points(), _research_completed)
		hud.set_defense_status(_defense_status_text)
		_refresh_hud()
		_hud_dirty = false
		dt_hud_us = Time.get_ticks_usec() - t_us
	var dt_total_us: int = Time.get_ticks_usec() - dispatch_start_us
	if _raid_state == &"Active" and dt_total_us >= 40000:
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
				_on_action_changed(&"Interact")
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
	_hud_dirty = true
	_refresh_hud()

func _maybe_start_auto_raid_benchmark() -> void:
	var enabled: bool = OS.get_environment("AUTO_RAID_BENCH") == "1"
	if not enabled:
		var args: PackedStringArray = OS.get_cmdline_args()
		for arg in args:
			if arg == "--auto_raid_bench":
				enabled = true
				break
	if not enabled:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if _raid_state == &"Idle" or _raid_state == &"Resolved":
			_start_raid_warning()
	)

func _on_command_move(world_pos: Vector2) -> void:
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

func _refresh_hud() -> void:
	hud.set_selected_count(selected_colonists.size())
	hud.set_resource_stock(resource_stock)
	var focus: Node = selected_colonists[0] if not selected_colonists.is_empty() else null
	var stockpile_focus: Node = selected_stockpile_zone if selected_stockpile_zone != null and is_instance_valid(selected_stockpile_zone) else null
	var farm_focus: Node = selected_farm_zone if selected_farm_zone != null and is_instance_valid(selected_farm_zone) else null
	var object_focus: bool = _selected_object_kind != &"" and _selected_object_zone != null and is_instance_valid(_selected_object_zone)
	hud.set_research_panel_visible(object_focus and _selected_object_kind == &"ResearchBench")
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
			var options: Array = _get_cached_research_options()
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
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _on_work_toggle_changed(work_type: StringName, enabled: bool) -> void:
	for c in selected_colonists:
		c.set_work_enabled(work_type, enabled)
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _on_colonist_status_changed(_colonist: Node) -> void:
	if _colonist != null and is_instance_valid(_colonist):
		var cid: int = _colonist.get_instance_id()
		var now_ms: int = Time.get_ticks_msec()
		var next_ms: int = int(_need_job_refresh_next_ms_by_colonist.get(cid, 0))
		if now_ms >= next_ms:
			_need_job_refresh_next_ms_by_colonist[cid] = now_ms + 700
			var food_available: int = int(resource_stock.get(&"Meal", 0)) + int(resource_stock.get(&"FoodRaw", 0))
			if bool(job_system.queue_need_jobs(_colonist, food_available)):
				_mark_jobs_dirty()
			if _raid_state == &"Active":
				var current: Dictionary = _colonist.current_job if "current_job" in _colonist else {}
				var job_type: StringName = StringName(current.get("type", &""))
				if current.is_empty() or (job_type != &"CombatMelee" and job_type != &"CombatRanged"):
					_mark_combat_dirty()
					_mark_jobs_dirty()
	if selected_colonists.is_empty():
		return
	_hud_dirty = true

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
	hud.set_craft_queue_paused_state(job_system.is_craft_queue_paused(workstation_id))
	var ws_name: String = _get_workstation_display_name(workstation_id)
	hud.set_craft_panel_visible(true, ws_name)

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
	var inside_best_dist: float = INF
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
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

func _on_stockpile_zone_added(zone: Node) -> void:
	if zone != null and is_instance_valid(zone) and zone.has_signal("stockpile_changed") and not zone.is_connected("stockpile_changed", Callable(self, "_on_stockpile_zone_changed")):
		zone.connect("stockpile_changed", Callable(self, "_on_stockpile_zone_changed"))
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_farm_zone_added(zone: Node) -> void:
	if zone != null and is_instance_valid(zone):
		if zone.has_signal("zone_changed") and not zone.is_connected("zone_changed", Callable(self, "_on_farm_zone_changed")):
			zone.connect("zone_changed", Callable(self, "_on_farm_zone_changed"))
		if zone.has_signal("farm_job_needed") and not zone.is_connected("farm_job_needed", Callable(self, "_on_farm_zone_job_needed")):
			zone.connect("farm_job_needed", Callable(self, "_on_farm_zone_job_needed"))
	_mark_farm_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

func _on_stockpile_zone_changed(_zone: Node) -> void:
	_mark_economy_dirty()
	_mark_jobs_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

func _on_farm_zone_changed(_zone: Node) -> void:
	_mark_farm_dirty()
	_hud_dirty = true

func _on_farm_zone_job_needed(_zone: Node) -> void:
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
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_mark_maintenance_dirty()
	_hud_dirty = true

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
	selected_workstation_id = ws_id
	job_system.enqueue_craft_recipe(recipe_id, ws_id)
	job_system.mark_craft_dirty()
	_mark_jobs_dirty()
	hud.set_craft_queue_preview(job_system.get_craft_queue(ws_id))

func _on_craft_recipe_front_queued(recipe_id: StringName, workstation_id: StringName) -> void:
	var ws_id: StringName = workstation_id if workstation_id != &"" else selected_workstation_id
	if ws_id == &"":
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

func _try_place_selected_building(world_pos: Vector2, as_blueprint: bool) -> void:
	var placed: bool = build_system.place_building(world_pos, as_blueprint)
	if placed and not as_blueprint:
		hud.set_resource_stock(resource_stock)
	if placed:
		_mark_pathing_dirty()
		_mark_jobs_dirty()
		_mark_maintenance_dirty()
		_mark_economy_dirty()
		_hud_dirty = true

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
			_mark_economy_dirty()
			_mark_jobs_dirty()
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
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
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
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
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
		_mark_economy_dirty()
		_mark_jobs_dirty()
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
	_hud_dirty = true

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
	_cached_alive_enemies = _get_alive_raiders()
	_cancel_noncombat_jobs_for_active_raid()
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_hud_dirty = true

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

func _cancel_noncombat_jobs_for_active_raid() -> void:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
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

func _spawn_raiders(count: int) -> void:
	if count <= 0:
		return
	var center: Vector2 = WORLD_SIZE * 0.5
	for _i in range(count):
		var raider: Node2D = RAIDER_SCENE.instantiate()
		raider.global_position = _resolve_enemy_spawn_position(_random_edge_spawn(140.0))
		if raider.has_method("set_tile_size"):
			raider.set_tile_size(TILE_SIZE)
		if raider.has_method("look_at"):
			raider.look_at(center)
		if raider.has_signal("died"):
			raider.died.connect(_on_raider_died)
		_connect_enemy_signals(raider)
		units_root.add_child(raider)

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
	_spawn_resource_drop(&"FoodRaw", food_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(60.0, -40.0)))
	_spawn_resource_drop(&"Wood", wood_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(-50.0, -36.0)))
	_spawn_resource_drop(&"Steel", steel_amount, _snap_to_tile(WORLD_SIZE * 0.5 + Vector2(8.0, -44.0)))

func _on_raider_died(_raider: Node) -> void:
	if _raider != null and is_instance_valid(_raider):
		_spawn_resource_drop(&"Wood", randi_range(1, 3), _raider.global_position)
		_spawn_resource_drop(&"FoodRaw", randi_range(0, 2), _raider.global_position + Vector2(8.0, 0.0))
		var rare_mul: float = maxf(1.0, _enemy_drop_bonus_from_research)
		if randf() < minf(0.45, 0.18 * rare_mul):
			_spawn_resource_drop(&"Steel", 1, _raider.global_position + Vector2(-8.0, -4.0))
		if randf() < minf(0.25, 0.07 * rare_mul):
			_spawn_resource_drop(&"Bow", 1, _raider.global_position + Vector2(0.0, -10.0))
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_zombie_died(_zombie: Node) -> void:
	if _zombie != null and is_instance_valid(_zombie):
		_spawn_resource_drop(&"FoodRaw", randi_range(1, 3), _zombie.global_position)
		_spawn_resource_drop(&"Stone", randi_range(0, 2), _zombie.global_position + Vector2(-6.0, 0.0))
		var rare_mul: float = maxf(1.0, _enemy_drop_bonus_from_research)
		if randf() < minf(0.35, 0.11 * rare_mul):
			_spawn_resource_drop(&"Steel", 1, _zombie.global_position + Vector2(6.0, -4.0))
	_mark_combat_dirty()
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _get_alive_raiders() -> Array:
	var out: Array = []
	for node in _get_group_nodes_cached(&"raiders"):
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
		_mark_economy_dirty()
		_mark_jobs_dirty()
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

func _handle_user_right_click(event: InputEventMouseButton) -> void:
	var world_pos: Vector2 = world_root.get_global_mouse_position()
	if pending_building_id != &"" or pending_install_item != &"" or current_action == &"StockpileZone" or current_action == &"FarmZone" or current_action == &"SetRallyFlag" or current_action == &"DragGather":
		_clear_pending_placement()
		_on_action_changed(&"Interact")
		return
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
	job_system.mark_assign_dirty()
	_mark_jobs_dirty()

func _spawn_resource_drop(resource_type: StringName, amount: int, world_pos: Vector2) -> Node:
	if amount <= 0:
		return null
	var drop := RESOURCE_DROP_SCENE.instantiate()
	drop.global_position = _snap_to_tile(world_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)))
	world_root.add_child(drop)
	if drop.has_method("setup_drop"):
		drop.setup_drop(resource_type, amount)
	_connect_resource_drop_signals(drop)
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
	_mark_jobs_dirty()
	_mark_economy_dirty()

func _on_resource_drop_emptied(_drop: Node) -> void:
	_mark_jobs_dirty()
	_mark_economy_dirty()
	_hud_dirty = true

func _on_resource_drop_removed(_drop: Node) -> void:
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
	for ws_id_any in workstation_lookup.keys():
		out[StringName(ws_id_any)] = []
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
			slots.append({
				"slot_id": node.get_instance_id(),
				"pos": node.global_position
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
	var pos: Vector2 = _find_workstation_pos(&"ResearchBench")
	if pos != Vector2.INF:
		return pos
	for node in _get_group_nodes_cached(&"structures"):
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
	for zone in _get_group_nodes_cached(&"stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.global_position.distance_to(world_pos) <= radius:
			return zone
	return null

func _find_farm_zone_near(world_pos: Vector2, radius: float) -> Node:
	for zone in _get_group_nodes_cached(&"farm_zones"):
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
	for zone in _get_group_nodes_cached(&"farm_zones"):
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
	if zone.has_method("set_yield_multiplier"):
		zone.set_yield_multiplier(_farm_yield_bonus_from_research)
	if zone.has_method("set_fertility_resilience"):
		zone.set_fertility_resilience(_farm_resilience_bonus_from_research)

func _update_defense_traps(delta: float, enemies: Array = []) -> void:
	if _game_paused:
		return
	var raiders: Array = enemies
	if raiders.is_empty():
		raiders = _get_alive_raiders()
	var traps_changed: bool = false
	var trap_cell_size: float = TILE_SIZE * 4.0
	var enemy_buckets: Dictionary = {}
	for raider in raiders:
		if raider == null or not is_instance_valid(raider):
			continue
		var bucket: Vector2i = Vector2i(
			int(floor(raider.global_position.x / trap_cell_size)),
			int(floor(raider.global_position.y / trap_cell_size))
		)
		var key: int = _pack_tile_key(bucket)
		if not enemy_buckets.has(key):
			enemy_buckets[key] = []
		var bucket_enemies: Array = enemy_buckets[key]
		bucket_enemies.append(raider)
		enemy_buckets[key] = bucket_enemies
	var trap_nodes: Array = _get_group_nodes_cached(&"trap_structures")
	if trap_nodes.is_empty():
		return
	var trap_count: int = trap_nodes.size()
	var max_to_process: int = mini(TRAP_MAX_PER_UPDATE, trap_count)
	var start_idx: int = posmod(_trap_update_cursor, trap_count)
	for i in range(max_to_process):
		var trap = trap_nodes[(start_idx + i) % trap_count]
		if trap == null or not is_instance_valid(trap):
			continue
		var trap_damage: int = int(trap.get_meta("trap_damage")) if trap.has_meta("trap_damage") else 0
		if trap_damage <= 0:
			continue
		trap_damage = int(round(float(trap_damage) * _trap_damage_bonus_from_research))
		var charges: int = int(trap.get_meta("trap_charges")) if trap.has_meta("trap_charges") else 0
		if charges <= 0:
			continue
		var cooldown_left: float = float(trap.get_meta("trap_cooldown_left")) if trap.has_meta("trap_cooldown_left") else 0.0
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			trap.set_meta("trap_cooldown_left", cooldown_left)
			traps_changed = true
		if cooldown_left > 0.0:
			continue
		var target: Node = null
		var best_dist_sq: float = pow(36.0 * maxf(1.0, _trap_range_bonus_from_research), 2.0)
		var range_tiles: int = maxi(1, int(ceil(sqrt(best_dist_sq) / trap_cell_size)))
		var trap_bucket: Vector2i = Vector2i(
			int(floor(trap.global_position.x / trap_cell_size)),
			int(floor(trap.global_position.y / trap_cell_size))
		)
		for by in range(trap_bucket.y - range_tiles, trap_bucket.y + range_tiles + 1):
			for bx in range(trap_bucket.x - range_tiles, trap_bucket.x + range_tiles + 1):
				var local_key: int = _pack_tile_key(Vector2i(bx, by))
				if not enemy_buckets.has(local_key):
					continue
				var bucket_enemies: Array = enemy_buckets[local_key]
				for raider in bucket_enemies:
					if raider == null or not is_instance_valid(raider):
						continue
					var dist_sq: float = trap.global_position.distance_squared_to(raider.global_position)
					if dist_sq <= best_dist_sq:
						best_dist_sq = dist_sq
						target = raider
		if target == null:
			continue
		if target.has_method("apply_combat_damage"):
			target.apply_combat_damage(trap_damage)
		var cooldown: float = float(trap.get_meta("trap_cooldown_sec")) if trap.has_meta("trap_cooldown_sec") else 3.0
		trap.set_meta("trap_cooldown_left", maxf(0.3, cooldown / maxf(1.0, _trap_cooldown_bonus_from_research)))
		charges -= 1
		trap.set_meta("trap_charges", charges)
		traps_changed = true
	if traps_changed:
		_structure_maintenance_dirty = true
		_hud_dirty = true
	_trap_update_cursor = (start_idx + max_to_process) % trap_count

func _pack_tile_key(tile: Vector2i) -> int:
	var packed_x: int = (tile.x + 32768) & 0xFFFF
	var packed_y: int = (tile.y + 32768) & 0xFFFF
	return (packed_x << 16) | packed_y

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
		var label: String = "%s (%.0f)%s" % [String(def.display_name), float(def.required_points), "" if unlocked else " [잠김]"]
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
	_perf_report_next_ms = now_ms + 5000

func _reset_combat_window() -> void:
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

func report_combat_event(source_side: StringName, hit: bool, damage: int, kill: bool, attack_mode: StringName = &"") -> void:
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
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_sim_interval_scale"):
			enemy.set_sim_interval_scale(interval_scale)

func _apply_friendly_pathing_budget(scale: float) -> void:
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
		var ratio: float = hp / max_hp
		for child in node.get_children():
			if child is Sprite2D:
				child.modulate = Color(1.0, ratio, ratio, 1.0)
				break

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
	var maint_state: String = "가능" if maintain_affordable else "재료부족"
	_defense_status_text = "수리:%d / 함정정비:%d / 소진함정:%d / 필요(W:%d,S:%d) %s" % [_cached_damaged_repairables.size(), pending_count, depleted_count, estimated_batches, estimated_batches, maint_state]

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
		{"id": &"All", "label": "전체"},
		{"id": &"Food", "label": "식량"},
		{"id": &"War", "label": "전투 물자"},
		{"id": &"Build", "label": "건설 자재"},
		{"id": &"Industry", "label": "산업 물자"},
		{"id": &"Emergency", "label": "응급 보급"},
		{"id": &"Harvest", "label": "농산물"}
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
	hud.set_craft_queue_paused_state(job_system.is_craft_queue_paused(workstation_id))
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
