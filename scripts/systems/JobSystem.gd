extends Node
class_name JobSystem

const JOB_SCORING: Script = preload("res://scripts/sim/JobScoring.gd")
const HAUL_RESERVATION_LOGIC: Script = preload("res://scripts/sim/HaulReservationLogic.gd")
const EQUIPMENT_STATS: Script = preload("res://scripts/core/EquipmentStats.gd")

const HAUL_QUEUE_TIMEOUT_MS: int = 5000
const HAUL_ASSIGN_TIMEOUT_MS: int = 12000
const WORK_ADJACENT_OFFSET: float = 40.0
const MAX_ASSIGN_PER_TICK: int = 8
const MAX_JOB_SCAN_PER_COLONIST: int = 48
const COMBAT_PREEMPT_DISTANCE: float = 160.0

var _jobs: Array[Dictionary] = []
var _craft_queues: Dictionary = {}
var _reserved_craft_slot_ids: Dictionary = {}
var _reserved_drop_ids: Dictionary = {}
var _paused_craft_workstations: Dictionary = {}
var _haul_urgency_multiplier: float = 1.0
var _combat_assign_cursor: int = 0
var _assign_scan_cursor_by_colonist: Dictionary = {}
var _pathing_occupancy: Node = null
var _cached_blocking_structures: Array = []
var _cached_build_sites: Array = []
var _cached_colonists: Array = []
var _spatial_cache_dirty: bool = true

var _dirty_haul: bool = true
var _dirty_combat: bool = true
var _dirty_assign: bool = true
var _dirty_craft: bool = true
var _dirty_research: bool = true
var _dirty_designation: bool = true
var _dirty_repair: bool = true
var _raid_mode_active: bool = false
var _rallied_colonist_ids: Dictionary = {}

func mark_spatial_dirty() -> void:
	_spatial_cache_dirty = true

func mark_haul_dirty() -> void:
	_dirty_haul = true
	_dirty_assign = true

func mark_combat_dirty() -> void:
	_dirty_combat = true
	_dirty_assign = true

func mark_assign_dirty() -> void:
	_dirty_assign = true

func mark_craft_dirty() -> void:
	_dirty_craft = true
	_dirty_assign = true

func mark_research_dirty() -> void:
	_dirty_research = true
	_dirty_assign = true

func mark_designation_dirty() -> void:
	_dirty_designation = true
	_dirty_assign = true

func mark_repair_dirty() -> void:
	_dirty_repair = true
	_dirty_assign = true

func enter_raid_mode() -> void:
	_raid_mode_active = true

func exit_raid_mode() -> void:
	if not _raid_mode_active:
		return
	_raid_mode_active = false
	_rallied_colonist_ids.clear()

func process_dirty(
	colonists: Array,
	enemies: Array,
	drops: Array,
	haul_targets: Array,
	current_stock: Dictionary,
	target_stock: Dictionary,
	rally_pos: Vector2,
	rally_radius: float,
	max_combatants: int,
	recipe_lookup: Dictionary,
	workstation_slots: Dictionary,
	can_start_callback: Callable = Callable(),
	on_start_callback: Callable = Callable(),
	research_target: Vector2 = Vector2.INF,
	research_project_id: StringName = &"",
	repairables: Array = [],
	traps: Array = [],
	gatherables: Array = [],
	huntables: Array = [],
	raid_active_mode: bool = false,
	rally_slot_validator: Callable = Callable()
) -> void:
	process_producers(
		colonists,
		enemies,
		drops,
		haul_targets,
		current_stock,
		target_stock,
		rally_pos,
		rally_radius,
		max_combatants,
		recipe_lookup,
		workstation_slots,
		can_start_callback,
		on_start_callback,
		research_target,
		research_project_id,
		repairables,
		traps,
		gatherables,
		huntables,
		raid_active_mode,
		rally_slot_validator
	)
	process_assignment(colonists)

func process_producers(
	colonists: Array,
	enemies: Array,
	drops: Array,
	haul_targets: Array,
	current_stock: Dictionary,
	target_stock: Dictionary,
	rally_pos: Vector2,
	rally_radius: float,
	max_combatants: int,
	recipe_lookup: Dictionary,
	workstation_slots: Dictionary,
	can_start_callback: Callable = Callable(),
	on_start_callback: Callable = Callable(),
	research_target: Vector2 = Vector2.INF,
	research_project_id: StringName = &"",
	repairables: Array = [],
	traps: Array = [],
	gatherables: Array = [],
	huntables: Array = [],
	raid_active_mode: bool = false,
	rally_slot_validator: Callable = Callable()
) -> void:
	if _dirty_designation:
		request_designated_gather_jobs(gatherables)
		request_designated_hunt_jobs(huntables)
		_dirty_designation = false
	if _dirty_haul:
		request_haul_jobs(drops, haul_targets, current_stock, target_stock)
		_dirty_haul = false
	if _dirty_repair:
		request_repair_jobs(repairables)
		request_trap_maintenance_jobs(traps)
		_dirty_repair = false
	if _dirty_craft:
		request_craft_jobs(recipe_lookup, workstation_slots, colonists, can_start_callback, on_start_callback)
		_dirty_craft = false
	if _dirty_research:
		request_research_jobs(colonists, research_target, research_project_id, 6.0)
		_dirty_research = false
	if _dirty_combat:
		request_combat_jobs(colonists, enemies, rally_pos, rally_radius, max_combatants, raid_active_mode, rally_slot_validator)
		_dirty_combat = false

func process_assignment(colonists: Array) -> void:
	if not _dirty_assign:
		return
	_cleanup_stale_jobs()
	var assigned_this_tick: int = assign_jobs(colonists)
	if assigned_this_tick >= MAX_ASSIGN_PER_TICK and not _jobs.is_empty() and _has_idle_colonist(colonists):
		return
	_dirty_assign = false

func has_pending_assignment() -> bool:
	return _dirty_assign

func has_unassigned_jobs() -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) == 0:
			return true
	return false

func queue_move_job(colonist: Node, target: Vector2) -> void:
	var job: Dictionary = {
		"type": &"MoveTo",
		"target": target,
		"base_priority": 10,
		"assigned_to": colonist.get_instance_id()
	}
	_jobs.append(job)
	_dirty_assign = true

func issue_immediate_move(colonist: Node, target: Vector2, preserve_current_job: bool = true) -> void:
	if preserve_current_job:
		if colonist.has_method("capture_current_job_for_resume"):
			colonist.capture_current_job_for_resume()
	elif colonist.has_method("clear_resume_job_after_move"):
		colonist.clear_resume_job_after_move()
	_remove_jobs_for_colonist(colonist.get_instance_id())
	colonist.assign_job({
		"type": &"MoveTo",
		"target": target,
		"base_priority": 100,
		"assigned_to": colonist.get_instance_id(),
		"__resume_after_move": preserve_current_job
	})
	_dirty_assign = true

func queue_build_job(site: Node) -> bool:
	var work_target: Vector2 = site.global_position
	if site is Node2D:
		work_target = _find_adjacent_work_position(site)
	if work_target == Vector2.INF:
		return false
	var job: Dictionary = {
		"type": &"BuildSite",
		"target": work_target,
		"site_id": site.get_instance_id(),
		"work_duration": float(site.get("required_work")),
		"base_priority": 11,
		"assigned_to": 0
	}
	_jobs.append(job)
	_dirty_assign = true
	return true

func queue_repair_job(structure: Node, work_duration: float = 8.0) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	if bool(structure.get_meta("repair_job_queued")):
		return
	structure.set_meta("repair_job_queued", true)
	var target_pos: Vector2 = structure.global_position if structure is Node2D else Vector2.ZERO
	_jobs.append({
		"type": &"RepairStructure",
		"target": target_pos,
		"structure_id": structure.get_instance_id(),
		"work_duration": maxf(0.2, work_duration),
		"base_priority": 10,
		"assigned_to": 0
	})
	_dirty_assign = true

func queue_demolish_job(structure: Node, work_duration: float = 4.0, replace_building_id: StringName = &"") -> void:
	if structure == null or not is_instance_valid(structure):
		return
	if bool(structure.get_meta("demolish_job_queued")):
		return
	structure.set_meta("demolish_job_queued", true)
	var target_pos: Vector2 = structure.global_position if structure is Node2D else Vector2.ZERO
	if structure is Node2D and _requires_adjacent_work_target(structure):
		var adjacent_pos: Vector2 = _find_adjacent_work_position(structure)
		if adjacent_pos != Vector2.INF:
			target_pos = adjacent_pos
	_jobs.append({
		"type": &"DemolishStructure",
		"target": target_pos,
		"structure_id": structure.get_instance_id(),
		"replace_building_id": replace_building_id,
		"work_duration": maxf(0.2, work_duration),
		"base_priority": 10,
		"assigned_to": 0
	})
	_dirty_assign = true

func _requires_adjacent_work_target(structure: Node) -> bool:
	return bool(structure.get_meta("blocks_movement")) and not bool(structure.get_meta("passable_for_friendly"))

func queue_trap_maint_job(structure: Node, work_duration: float = 3.0) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	if bool(structure.get_meta("trap_maint_job_queued")):
		return
	structure.set_meta("trap_maint_job_queued", true)
	var target_pos: Vector2 = structure.global_position if structure is Node2D else Vector2.ZERO
	_jobs.append({
		"type": &"MaintainTrap",
		"target": target_pos,
		"structure_id": structure.get_instance_id(),
		"work_duration": maxf(0.2, work_duration),
		"base_priority": 10,
		"assigned_to": 0
	})
	_dirty_assign = true

func queue_gather_job(gatherable: Node, assigned_to: int = 0) -> void:
	if gatherable == null or not is_instance_valid(gatherable):
		return
	if gatherable.has_method("is_depleted") and gatherable.is_depleted():
		return
	if gatherable.has_method("set_job_queued"):
		gatherable.set_job_queued(true)
	var job: Dictionary = {
		"type": &"Gather",
		"target": gatherable.global_position,
		"gatherable_id": gatherable.get_instance_id(),
		"base_priority": 7,
		"assigned_to": assigned_to
	}
	_jobs.append(job)
	_dirty_assign = true

func queue_hunt_job(huntable: Node, assigned_to: int = 0) -> void:
	if huntable == null or not is_instance_valid(huntable):
		return
	if huntable.has_method("is_dead") and huntable.is_dead():
		return
	if huntable.has_method("set_job_queued"):
		huntable.set_job_queued(true)
	var job: Dictionary = {
		"type": &"Hunt",
		"target": huntable.global_position,
		"huntable_id": huntable.get_instance_id(),
		"base_priority": 7,
		"assigned_to": assigned_to
	}
	_jobs.append(job)
	_dirty_assign = true

func queue_farm_plant_job(farm_zone: Node, tile: Vector2i, crop_type: StringName, work_duration: float = 2.0, assigned_to: int = 0) -> void:
	if farm_zone == null or not is_instance_valid(farm_zone):
		return
	var target: Vector2 = farm_zone.global_position
	if farm_zone.has_method("get_plot_world"):
		target = farm_zone.get_plot_world(tile)
	_jobs.append({
		"type": &"PlantCrop",
		"target": target,
		"zone_id": farm_zone.get_instance_id(),
		"tile": tile,
		"crop_type": crop_type,
		"work_duration": maxf(0.1, work_duration),
		"base_priority": 9,
		"assigned_to": assigned_to
	})
	_dirty_assign = true

func queue_farm_harvest_job(farm_zone: Node, tile: Vector2i, crop_type: StringName, work_duration: float = 2.0, assigned_to: int = 0) -> void:
	if farm_zone == null or not is_instance_valid(farm_zone):
		return
	var target: Vector2 = farm_zone.global_position
	if farm_zone.has_method("get_plot_world"):
		target = farm_zone.get_plot_world(tile)
	_jobs.append({
		"type": &"HarvestCrop",
		"target": target,
		"zone_id": farm_zone.get_instance_id(),
		"tile": tile,
		"crop_type": crop_type,
		"work_duration": maxf(0.1, work_duration),
		"base_priority": 11,
		"assigned_to": assigned_to
	})
	_dirty_assign = true

func queue_combat_job(colonist: Node, enemy: Node, use_ranged: bool, forced_type: StringName = &"") -> void:
	if colonist == null or not is_instance_valid(colonist):
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	var colonist_id: int = colonist.get_instance_id()
	if _has_pending_combat_job(colonist_id):
		return
	var job_type: StringName = forced_type
	if job_type != &"CombatRanged" and job_type != &"CombatMelee":
		job_type = &"CombatRanged" if use_ranged else &"CombatMelee"
	_jobs.append({
		"type": job_type,
		"target": enemy.global_position,
		"target_id": enemy.get_instance_id(),
		"base_priority": 13,
		"assigned_to": colonist_id
	})
	_dirty_assign = true

func queue_haul_job(drop_node: Node, zone_node: Node, assigned_to: int = 0, base_priority: int = 8, as_craft_supply: bool = false, urgency: float = 0.0) -> void:
	if drop_node == null or not is_instance_valid(drop_node):
		return
	if zone_node == null or not is_instance_valid(zone_node):
		return
	if drop_node.has_method("is_empty") and drop_node.is_empty():
		return
	var drop_id: int = drop_node.get_instance_id()
	if _reserved_drop_ids.has(drop_id):
		return
	if _has_queued_haul_job(drop_id):
		return
	if drop_node.has_method("set_job_queued"):
		drop_node.set_job_queued(true)
	var job: Dictionary = {
		"type": &"HaulResource",
		"target": drop_node.global_position,
		"drop_id": drop_id,
		"zone_id": zone_node.get_instance_id(),
		"base_priority": base_priority,
		"assigned_to": assigned_to,
		"as_craft_supply": as_craft_supply,
		"urgency": maxf(0.0, urgency),
		"drop_amount": int(drop_node.get("amount")),
		"queued_at_ms": Time.get_ticks_msec()
	}
	_jobs.append(job)
	_reserved_drop_ids[drop_id] = {
		"assigned_to": 0,
		"reserved_at_ms": Time.get_ticks_msec()
	}
	_dirty_assign = true

func enqueue_craft_recipe(recipe_id: StringName, workstation_id: StringName, repeat: bool = false) -> void:
	if recipe_id == &"" or workstation_id == &"":
		return
	if not _craft_queues.has(workstation_id):
		_craft_queues[workstation_id] = []
	var queue: Array = _craft_queues[workstation_id]
	queue.append({
		"recipe_id": recipe_id,
		"workstation_id": workstation_id,
		"repeat": repeat
	})
	_craft_queues[workstation_id] = queue

func enqueue_craft_recipe_front(recipe_id: StringName, workstation_id: StringName, repeat: bool = false) -> void:
	if recipe_id == &"" or workstation_id == &"":
		return
	if not _craft_queues.has(workstation_id):
		_craft_queues[workstation_id] = []
	var queue: Array = _craft_queues[workstation_id]
	queue.insert(0, {
		"recipe_id": recipe_id,
		"workstation_id": workstation_id,
		"repeat": repeat
	})
	_craft_queues[workstation_id] = queue

func dequeue_craft_recipe(workstation_id: StringName) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	var queue: Array = _craft_queues[workstation_id]
	if queue.is_empty():
		return
	queue.remove_at(0)
	_craft_queues[workstation_id] = queue

func clear_craft_queue(workstation_id: StringName) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	_craft_queues[workstation_id] = []

func set_craft_queue_paused(workstation_id: StringName, paused: bool) -> void:
	if workstation_id == &"":
		return
	_paused_craft_workstations[workstation_id] = paused

func is_craft_queue_paused(workstation_id: StringName) -> bool:
	if workstation_id == &"":
		return false
	return bool(_paused_craft_workstations.get(workstation_id, false))

func set_haul_urgency_multiplier(value: float) -> void:
	_haul_urgency_multiplier = clampf(value, 0.5, 3.0)

func remove_craft_recipe_at(workstation_id: StringName, index: int) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	var queue: Array = _craft_queues[workstation_id]
	if index < 0 or index >= queue.size():
		return
	queue.remove_at(index)
	_craft_queues[workstation_id] = queue

func get_craft_queue(workstation_id: StringName) -> Array[Dictionary]:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return []
	var queue: Array = _craft_queues[workstation_id]
	var out: Array[Dictionary] = []
	for item in queue:
		if item is Dictionary:
			out.append(item)
	return out

func notify_craft_job_finished(craft_slot_id: int = 0) -> void:
	if craft_slot_id != 0:
		_reserved_craft_slot_ids.erase(craft_slot_id)

func request_designated_gather_jobs(gatherables: Array) -> void:
	var pending_drop_types: Dictionary = _pending_drop_types()
	for node in gatherables:
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.get("job_queued")):
			continue
		if node.has_method("is_depleted") and node.is_depleted():
			continue
		if node.has_method("is_designated") and not bool(node.is_designated()):
			continue
		var resource_type: StringName = StringName(node.get("resource_type"))
		if resource_type != &"" and bool(pending_drop_types.get(resource_type, false)):
			continue
		queue_gather_job(node)

func request_designated_hunt_jobs(huntables: Array) -> void:
	for node in huntables:
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.get("job_queued")):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if node.has_method("is_designated") and not bool(node.is_designated()):
			continue
		queue_hunt_job(node)

func request_haul_jobs(drops: Array, stockpile_zones: Array, current_stock: Dictionary, target_stock: Dictionary) -> void:
	if stockpile_zones.is_empty():
		return
	_cleanup_haul_reservations()
	for drop_node in drops:
		if drop_node == null or not is_instance_valid(drop_node):
			continue
		if bool(drop_node.get("job_queued")):
			continue
		if drop_node.has_method("is_empty") and drop_node.is_empty():
			continue
		var resource_type: StringName = StringName(drop_node.get("resource_type"))
		var drop_amount: int = int(drop_node.get("amount"))
		var nearest_zone: Node = _find_nearest_zone(drop_node.global_position, stockpile_zones, resource_type, drop_amount)
		if nearest_zone == null:
			continue
		var need: int = int(target_stock.get(resource_type, 0))
		var have: int = int(current_stock.get(resource_type, 0))
		var urgency: float = maxf(0.0, float(need - have)) * _haul_urgency_multiplier
		var as_craft_supply: bool = bool(drop_node.get_meta("craft_supply")) if drop_node.has_meta("craft_supply") else false
		var base_priority: int = 12 if as_craft_supply else 8
		queue_haul_job(drop_node, nearest_zone, 0, base_priority, as_craft_supply, urgency)
		_set_latest_haul_meta(drop_node.get_instance_id(), urgency, drop_amount)

func request_craft_jobs(recipe_lookup: Dictionary, workstation_slots: Dictionary, colonists: Array, can_start_callback: Callable = Callable(), on_start_callback: Callable = Callable()) -> void:
	_cleanup_craft_slot_reservations(colonists)
	if _craft_queues.is_empty():
		return
	var ws_keys: Array = _craft_queues.keys()
	ws_keys.sort_custom(func(a, b): return String(a) < String(b))
	for ws_id_any in ws_keys:
		var workstation_id: StringName = StringName(ws_id_any)
		if is_craft_queue_paused(workstation_id):
			continue
		var queue: Array = _craft_queues[workstation_id]
		if queue.is_empty():
			continue
		var slots: Array = workstation_slots.get(workstation_id, [])
		if slots.is_empty():
			continue
		var free_slots: Array[Dictionary] = []
		for slot_any in slots:
			if not (slot_any is Dictionary):
				continue
			var slot: Dictionary = slot_any
			var slot_id: int = int(slot.get("slot_id", 0))
			if slot_id == 0:
				continue
			if _reserved_craft_slot_ids.has(slot_id):
				continue
			free_slots.append(slot)
		if free_slots.is_empty():
			continue
		for slot in free_slots:
			if queue.is_empty():
				break
			var order: Dictionary = queue[0]
			var recipe_id: StringName = order.get("recipe_id", &"")
			if not recipe_lookup.has(recipe_id):
				queue.remove_at(0)
				_craft_queues[workstation_id] = queue
				continue
			var recipe: Resource = recipe_lookup[recipe_id]
			var can_start: bool = true
			if can_start_callback.is_valid():
				can_start = bool(can_start_callback.call(workstation_id, recipe))
			if not can_start:
				break
			if on_start_callback.is_valid():
				on_start_callback.call(workstation_id, recipe)
			var slot_id: int = int(slot.get("slot_id", 0))
			var station_pos: Vector2 = slot.get("pos", Vector2.INF)
			if slot_id == 0 or station_pos == Vector2.INF:
				continue
			_jobs.append({
				"type": &"CraftRecipe",
				"target": station_pos,
				"recipe_id": recipe.id,
				"workstation_id": workstation_id,
				"recipe_name": recipe.display_name,
				"work_duration": maxf(0.1, float(recipe.work_required)),
				"products": recipe.products,
				"craft_slot_id": slot_id,
				"base_priority": 11,
				"assigned_to": 0
			})
			_reserved_craft_slot_ids[slot_id] = {
				"assigned_to": 0,
				"reserved_at_ms": Time.get_ticks_msec()
			}
			_dirty_assign = true
			if not bool(order.get("repeat", false)):
				queue.remove_at(0)
			_craft_queues[workstation_id] = queue

func request_research_jobs(colonists: Array, target_pos: Vector2, project_id: StringName, work_duration: float = 6.0) -> void:
	if project_id == &"":
		return
	if target_pos == Vector2.INF:
		return
	if _has_any_active_or_pending_research_job(colonists):
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not colonist.current_job.is_empty():
			continue
		if colonist.has_method("can_do_job") and not colonist.can_do_job(&"ResearchTask"):
			continue
		var colonist_id: int = colonist.get_instance_id()
		if _has_pending_research_job(colonist_id):
			continue
		_jobs.append({
			"type": &"ResearchTask",
			"target": target_pos,
			"project_id": project_id,
			"work_duration": maxf(0.5, work_duration),
			"research_points": 1.0,
			"base_priority": 9,
			"assigned_to": colonist_id
		})
		_dirty_assign = true
		return

func request_repair_jobs(structures: Array) -> void:
	for structure in structures:
		if structure == null or not is_instance_valid(structure):
			continue
		var max_hp: float = float(structure.get_meta("structure_max_health")) if structure.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(structure.get_meta("structure_health")) if structure.has_meta("structure_health") else max_hp
		if hp >= max_hp - 0.5:
			continue
		var work_duration: float = float(structure.get_meta("repair_work")) if structure.has_meta("repair_work") else 8.0
		queue_repair_job(structure, work_duration)

func request_trap_maintenance_jobs(structures: Array) -> void:
	for structure in structures:
		if structure == null or not is_instance_valid(structure):
			continue
		if int(structure.get_meta("trap_damage")) <= 0:
			continue
		var charges: int = int(structure.get_meta("trap_charges"))
		var max_charges: int = int(structure.get_meta("trap_max_charges")) if structure.has_meta("trap_max_charges") else charges
		if max_charges <= 0:
			continue
		if charges >= max_charges:
			continue
		queue_trap_maint_job(structure, 3.0)

func request_combat_jobs(
	colonists: Array,
	enemies: Array,
	rally_pos: Vector2 = Vector2.INF,
	rally_radius: float = 120.0,
	max_assignments: int = -1,
	raid_active_mode: bool = false,
	rally_slot_validator: Callable = Callable()
) -> void:
	if enemies.is_empty():
		return
	if colonists.is_empty():
		return
	var assigned_count: int = 0
	var size: int = colonists.size()
	var start_idx: int = posmod(_combat_assign_cursor, maxi(1, size))
	var rally_slot_claims: Dictionary = {}
	var rally_slots: Array[Vector2] = []
	var rally_slots_ready: bool = false
	var rally_slot_count: int = size if max_assignments < 0 else mini(size, maxi(1, max_assignments))
	for offset in range(size):
		if max_assignments >= 0 and assigned_count >= max_assignments:
			break
		var idx: int = (start_idx + offset) % size
		var colonist = colonists[idx]
		if colonist == null or not is_instance_valid(colonist):
			continue
		var preferred_job_type: StringName = _resolve_preferred_combat_job_type(colonist)
		if colonist.has_method("can_do_job") and not colonist.can_do_job(preferred_job_type):
			continue
		var colonist_id: int = colonist.get_instance_id()
		if _has_pending_combat_job(colonist_id):
			continue
		var nearest_enemy: Node = null
		var best_dist_sq: float = INF
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.has_method("is_dead") and bool(enemy.is_dead()):
				continue
			var dist_sq: float = colonist.global_position.distance_squared_to(enemy.global_position)
			if dist_sq < best_dist_sq:
				best_dist_sq = dist_sq
				nearest_enemy = enemy
		if nearest_enemy == null:
			continue
		var enemy_is_close: bool = best_dist_sq <= COMBAT_PREEMPT_DISTANCE * COMBAT_PREEMPT_DISTANCE
		var hold_before_engage: bool = raid_active_mode and not enemy_is_close
		if hold_before_engage and rally_pos == Vector2.INF:
			continue
		var has_pending_move: bool = _has_pending_move_job(colonist_id)
		var is_selected: bool = bool(colonist.get("selected"))
		if is_selected:
			if has_pending_move:
				_remove_pending_move_jobs_for_colonist(colonist_id)
			if hold_before_engage:
				continue
			if not colonist.current_job.is_empty():
				var selected_current_type: StringName = StringName(colonist.current_job.get("type", &""))
				if selected_current_type == &"CombatMelee" or selected_current_type == &"CombatRanged":
					continue
				continue
			var selected_attack_range: float = _combat_attack_range_for(colonist, preferred_job_type)
			if best_dist_sq > selected_attack_range * selected_attack_range:
				continue
			var selected_use_ranged: bool = preferred_job_type == &"CombatRanged"
			queue_combat_job(colonist, nearest_enemy, selected_use_ranged, preferred_job_type)
			assigned_count += 1
			continue
		if hold_before_engage:
			if not colonist.current_job.is_empty():
				continue
			var dist_to_rally: float = colonist.global_position.distance_to(rally_pos)
			_rallied_colonist_ids[colonist_id] = true
			if dist_to_rally <= maxf(20.0, rally_radius):
				continue
			if has_pending_move:
				continue
			if not rally_slots_ready:
				rally_slot_claims = _collect_rally_slot_claims(colonists, rally_pos, rally_radius)
				rally_slots = _build_rally_formation_slots(rally_pos, rally_radius, rally_slot_count, rally_slot_claims, rally_slot_validator)
				rally_slots_ready = true
			var rally_move_target: Vector2 = _select_rally_slot_for_colonist(colonist, rally_slots, rally_slot_claims, rally_pos, rally_radius, rally_slot_validator)
			_assign_rally_move_job(colonist, rally_move_target)
			assigned_count += 1
			continue
		if has_pending_move and not enemy_is_close:
			continue
		if not colonist.current_job.is_empty():
			var current_type: StringName = StringName(colonist.current_job.get("type", &""))
			if current_type == &"CombatMelee" or current_type == &"CombatRanged":
				continue
			if not enemy_is_close:
				continue
			if colonist.has_method("cancel_current_job"):
				colonist.cancel_current_job()
			else:
				continue
		if has_pending_move and enemy_is_close:
			_remove_pending_move_jobs_for_colonist(colonist_id)
		if rally_pos != Vector2.INF and not _rallied_colonist_ids.has(colonist_id) and not enemy_is_close:
			var dist_to_rally: float = colonist.global_position.distance_to(rally_pos)
			if dist_to_rally <= maxf(20.0, rally_radius):
				_rallied_colonist_ids[colonist_id] = true
			else:
				_rallied_colonist_ids[colonist_id] = true
				if not rally_slots_ready:
					rally_slot_claims = _collect_rally_slot_claims(colonists, rally_pos, rally_radius)
					rally_slots = _build_rally_formation_slots(rally_pos, rally_radius, rally_slot_count, rally_slot_claims, rally_slot_validator)
					rally_slots_ready = true
				var move_target: Vector2 = _select_rally_slot_for_colonist(colonist, rally_slots, rally_slot_claims, rally_pos, rally_radius, rally_slot_validator)
				_assign_rally_move_job(colonist, move_target)
				assigned_count += 1
				continue
		var use_ranged: bool = preferred_job_type == &"CombatRanged"
		queue_combat_job(colonist, nearest_enemy, use_ranged, preferred_job_type)
		assigned_count += 1
	_combat_assign_cursor = (start_idx + assigned_count + 1) % maxi(1, size)

func _assign_rally_move_job(colonist: Node, target: Vector2) -> void:
	if colonist == null or not is_instance_valid(colonist):
		return
	var colonist_id: int = colonist.get_instance_id()
	_remove_pending_move_jobs_for_colonist(colonist_id)
	colonist.assign_job({
		"type": &"MoveTo",
		"target": target,
		"base_priority": 14,
		"assigned_to": colonist_id
	})

func _collect_rally_slot_claims(colonists: Array, rally_pos: Vector2, rally_radius: float) -> Dictionary:
	var claims: Dictionary = {}
	for job in _jobs:
		if StringName(job.get("type", &"")) != &"MoveTo":
			continue
		_claim_rally_slot_target(claims, job.get("target", Vector2.INF), rally_pos, rally_radius)
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist) or not (colonist is Node2D):
			continue
		var current_cell: Vector2 = _snap_to_job_tile((colonist as Node2D).global_position)
		if current_cell.distance_to(rally_pos) <= maxf(20.0, rally_radius):
			claims[_rally_slot_key(current_cell)] = true
		var active_job_variant: Variant = colonist.get("current_job")
		if active_job_variant is Dictionary:
			var active_job: Dictionary = active_job_variant
			if StringName(active_job.get("type", &"")) == &"MoveTo":
				_claim_rally_slot_target(claims, active_job.get("target", Vector2.INF), rally_pos, rally_radius)
	return claims

func _claim_rally_slot_target(claims: Dictionary, target_variant: Variant, rally_pos: Vector2, rally_radius: float) -> void:
	if not (target_variant is Vector2):
		return
	var target: Vector2 = _snap_to_job_tile(target_variant)
	if target == Vector2.INF:
		return
	if target.distance_to(rally_pos) > maxf(rally_radius + WORK_ADJACENT_OFFSET * 4.0, WORK_ADJACENT_OFFSET * 6.0):
		return
	claims[_rally_slot_key(target)] = true

func _build_rally_formation_slots(rally_pos: Vector2, _rally_radius: float, unit_count: int, claims: Dictionary, rally_slot_validator: Callable) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var seen: Dictionary = {}
	var center: Vector2 = _snap_to_job_tile(rally_pos)
	var max_ring: int = maxi(2, int(ceil(sqrt(float(maxi(1, unit_count + claims.size()))))) + 4)
	for ring in range(0, max_ring + 1):
		if ring == 0:
			var center_key: String = _rally_slot_key(center)
			if not claims.has(center_key) and _is_rally_slot_valid(center, rally_slot_validator):
				slots.append(center)
				seen[center_key] = true
			if slots.size() >= unit_count:
				return slots
			continue
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				var candidate: Vector2 = _snap_to_job_tile(center + Vector2(float(x) * WORK_ADJACENT_OFFSET, float(y) * WORK_ADJACENT_OFFSET))
				var candidate_key: String = _rally_slot_key(candidate)
				if claims.has(candidate_key) or seen.has(candidate_key):
					continue
				if not _is_rally_slot_valid(candidate, rally_slot_validator):
					continue
				slots.append(candidate)
				seen[candidate_key] = true
		if slots.size() >= unit_count:
			return slots
	return slots

func _select_rally_slot_for_colonist(colonist: Node, slots: Array[Vector2], claims: Dictionary, rally_pos: Vector2, rally_radius: float, rally_slot_validator: Callable) -> Vector2:
	var selected: Vector2 = _pick_nearest_rally_slot(colonist, slots, claims)
	if selected == Vector2.INF:
		var expanded_slots: Array[Vector2] = _build_rally_formation_slots(rally_pos, rally_radius, claims.size() + 8, claims, rally_slot_validator)
		selected = _pick_nearest_rally_slot(colonist, expanded_slots, claims)
	if selected == Vector2.INF:
		selected = _fallback_rally_move_target(colonist, rally_pos, rally_radius, rally_slot_validator)
	claims[_rally_slot_key(selected)] = true
	return selected

func _pick_nearest_rally_slot(colonist: Node, slots: Array[Vector2], claims: Dictionary) -> Vector2:
	if slots.is_empty() or colonist == null or not is_instance_valid(colonist) or not (colonist is Node2D):
		return Vector2.INF
	var best: Vector2 = Vector2.INF
	var best_dist_sq: float = INF
	for slot in slots:
		if claims.has(_rally_slot_key(slot)):
			continue
		var dist_sq: float = (colonist as Node2D).global_position.distance_squared_to(slot)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best = slot
	return best

func _fallback_rally_move_target(colonist: Node, rally_pos: Vector2, rally_radius: float, rally_slot_validator: Callable) -> Vector2:
	var from_pos: Vector2 = rally_pos
	if colonist != null and is_instance_valid(colonist) and colonist is Node2D:
		from_pos = (colonist as Node2D).global_position
	var dir: Vector2 = rally_pos - from_pos
	var normalized: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var target: Vector2 = _snap_to_job_tile(rally_pos - normalized * minf(rally_radius * 0.55, 72.0))
	if _is_rally_slot_valid(target, rally_slot_validator):
		return target
	return _snap_to_job_tile(rally_pos)

func _is_rally_slot_valid(world_pos: Vector2, rally_slot_validator: Callable) -> bool:
	if rally_slot_validator.is_valid():
		return bool(rally_slot_validator.call(world_pos))
	return not _is_blocked_by_structure(world_pos)

func _snap_to_job_tile(world_pos: Vector2) -> Vector2:
	if world_pos == Vector2.INF:
		return Vector2.INF
	return Vector2(
		round(world_pos.x / WORK_ADJACENT_OFFSET) * WORK_ADJACENT_OFFSET,
		round(world_pos.y / WORK_ADJACENT_OFFSET) * WORK_ADJACENT_OFFSET
	)

func _rally_slot_key(world_pos: Vector2) -> String:
	var snapped: Vector2 = _snap_to_job_tile(world_pos)
	return "%d,%d" % [int(round(snapped.x)), int(round(snapped.y))]

func _combat_attack_range_for(colonist: Node, preferred_job_type: StringName) -> float:
	if colonist != null and is_instance_valid(colonist) and colonist.has_method("get_combat_profile"):
		var profile: Dictionary = colonist.get_combat_profile()
		if preferred_job_type == &"CombatRanged":
			return maxf(20.0, float(profile.get("ranged_range", 160.0)))
		return maxf(18.0, float(profile.get("melee_range", 30.0)))
	if preferred_job_type == &"CombatRanged":
		return 160.0
	return 30.0

func _resolve_preferred_combat_job_type(colonist: Node) -> StringName:
	if colonist == null or not is_instance_valid(colonist):
		return &"CombatMelee"
	if colonist.has_method("get_preferred_combat_job_type"):
		var preferred: StringName = StringName(colonist.get_preferred_combat_job_type())
		if preferred == &"CombatRanged" or preferred == &"CombatMelee":
			return preferred
	if colonist.has_method("get_equipment_snapshot"):
		var gear: Dictionary = colonist.get_equipment_snapshot()
		var weapon_id: StringName = StringName(gear.get(&"Weapon", &""))
		var weapon_def: Resource = EQUIPMENT_STATS.get_resource_def(weapon_id)
		var weapon_mode: StringName = StringName(weapon_def.get("equipment_weapon_mode")) if weapon_def != null else &""
		if weapon_mode == &"Ranged":
			return &"CombatRanged"
		if weapon_mode == &"Melee":
			return &"CombatMelee"
	if colonist.has_method("get_combat_profile"):
		var profile: Dictionary = colonist.get_combat_profile()
		if StringName(profile.get("weapon_mode", &"Melee")) == &"Ranged":
			return &"CombatRanged"
	return &"CombatMelee"

func queue_need_jobs(colonist: Node, food_available: int) -> bool:
	var colonist_id: int = colonist.get_instance_id()
	var queued: bool = false
	if colonist.hunger < 45.0 and food_available > 0:
		if _has_pending_need_job(colonist_id, &"EatStub"):
			return false
		_jobs.append({
			"type": &"EatStub",
			"base_priority": 7,
			"assigned_to": colonist_id
		})
		_dirty_assign = true
		queued = true
	elif colonist.rest < 35.0:
		if _has_pending_need_job(colonist_id, &"IdleRecover"):
			return false
		_jobs.append({
			"type": &"IdleRecover",
			"base_priority": 6,
			"assigned_to": colonist_id
		})
		_dirty_assign = true
		queued = true
	return queued

func assign_jobs(colonists: Array) -> int:
	var assigned_this_tick: int = 0
	for colonist in colonists:
		if assigned_this_tick >= MAX_ASSIGN_PER_TICK:
			break
		if colonist == null or not colonist.is_idle():
			continue
		var chosen_index: int = _pick_best_job_index(colonist)
		if chosen_index < 0:
			continue
		var job: Dictionary = _jobs[chosen_index]
		_jobs.remove_at(chosen_index)
		if job.get("type", &"") == &"HaulResource":
			_reserved_drop_ids[int(job.get("drop_id", 0))] = {
				"assigned_to": colonist.get_instance_id(),
				"reserved_at_ms": Time.get_ticks_msec()
			}
		if job.get("type", &"") == &"CraftRecipe":
			var slot_id: int = int(job.get("craft_slot_id", 0))
			if slot_id != 0:
				_reserved_craft_slot_ids[slot_id] = {
					"assigned_to": colonist.get_instance_id(),
					"reserved_at_ms": Time.get_ticks_msec()
			}
		colonist.assign_job(job)
		assigned_this_tick += 1
	return assigned_this_tick

func _has_idle_colonist(colonists: Array) -> bool:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.is_idle():
			return true
	return false

func _pick_best_job_index(colonist: Node) -> int:
	var best_idx: int = -1
	var best_score: float = -INF
	var job_count: int = _jobs.size()
	if job_count <= 0:
		return -1
	var colonist_id: int = colonist.get_instance_id()
	var primary_scan_count: int = mini(job_count, MAX_JOB_SCAN_PER_COLONIST)
	var start_idx: int = posmod(int(_assign_scan_cursor_by_colonist.get(colonist_id, 0)), job_count)
	var primary_result: Dictionary = _scan_job_window(colonist, start_idx, primary_scan_count, best_idx, best_score)
	best_idx = int(primary_result.get("best_idx", -1))
	best_score = float(primary_result.get("best_score", -INF))
	var scanned_count: int = primary_scan_count
	if best_idx < 0 and primary_scan_count < job_count:
		var secondary_start: int = (start_idx + primary_scan_count) % job_count
		var secondary_count: int = job_count - primary_scan_count
		var secondary_result: Dictionary = _scan_job_window(colonist, secondary_start, secondary_count, best_idx, best_score)
		best_idx = int(secondary_result.get("best_idx", -1))
		scanned_count = job_count
	_assign_scan_cursor_by_colonist[colonist_id] = (start_idx + scanned_count) % maxi(1, job_count)
	return best_idx

func _scan_job_window(colonist: Node, start_idx: int, scan_count: int, best_idx: int, best_score: float) -> Dictionary:
	var job_count: int = _jobs.size()
	var out_idx: int = best_idx
	var out_score: float = best_score
	for n in range(scan_count):
		var i: int = (start_idx + n) % job_count
		var score: float = _score_job_for_colonist(colonist, _jobs[i])
		if score > out_score:
			out_score = score
			out_idx = i
	return {"best_idx": out_idx, "best_score": out_score}

func _score_job_for_colonist(colonist: Node, job: Dictionary) -> float:
	var assigned_to: int = int(job.get("assigned_to", 0))
	if assigned_to != 0 and assigned_to != colonist.get_instance_id():
		return -INF
	var job_type: StringName = StringName(job.get("type", &"Idle"))
	if colonist.has_method("can_do_job") and not colonist.can_do_job(job_type):
		return -INF
	if not (colonist is Node2D):
		return -INF
	return JOB_SCORING.score_job(
		job,
		(colonist as Node2D).global_position,
		colonist.get_priority(job_type),
		colonist.get_priority(&"Build"),
		colonist.get_priority(&"Craft"),
		colonist.get_priority(&"Combat"),
		colonist.get_priority(&"Gather")
	)

func release_haul_reservation(drop_id: int) -> void:
	if drop_id == 0:
		return
	_reserved_drop_ids.erase(drop_id)

func _remove_jobs_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	var filtered: Array[Dictionary] = []
	for job in _jobs:
		var assigned_to: int = int(job.get("assigned_to", 0))
		if assigned_to == colonist_id:
			continue
		filtered.append(job)
	_jobs = filtered

func _remove_pending_move_jobs_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	var filtered: Array[Dictionary] = []
	for job in _jobs:
		var assigned_to: int = int(job.get("assigned_to", 0))
		if assigned_to == colonist_id and StringName(job.get("type", &"")) == &"MoveTo":
			continue
		filtered.append(job)
	_jobs = filtered

func _find_nearest_zone(world_pos: Vector2, zones: Array, resource_type: StringName, amount: int) -> Node:
	var best_zone: Node = null
	var best_score: float = -INF
	for zone in zones:
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("accepts_resource") and not zone.accepts_resource(resource_type):
			continue
		if zone.has_method("preview_acceptable_amount"):
			var can_take: int = int(zone.preview_acceptable_amount(resource_type, amount))
			if can_take <= 0:
				continue
		var d: float = world_pos.distance_to(zone.global_position)
		var zone_priority: int = 0
		if zone.has_method("get_zone_priority"):
			zone_priority = int(zone.get_zone_priority())
		var score: float = float(zone_priority) * 100.0 - d
		if score > best_score:
			best_score = score
			best_zone = zone
	return best_zone

func _can_consume(stock: Dictionary, cost: Dictionary) -> bool:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		if have < need:
			return false
	return true

func _consume(stock: Dictionary, cost: Dictionary) -> void:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		stock[k] = maxi(0, have - need)

func _has_queued_haul_job(drop_id: int) -> bool:
	for job in _jobs:
		if job.get("type", &"") != &"HaulResource":
			continue
		if int(job.get("drop_id", 0)) == drop_id:
			return true
	return false

func _cleanup_haul_reservations() -> void:
	var now_ms: int = Time.get_ticks_msec()
	var drop_states: Dictionary = {}
	for drop_id_any in _reserved_drop_ids.keys():
		var drop_id: int = int(drop_id_any)
		var obj: Object = instance_from_id(drop_id)
		if obj == null or not is_instance_valid(obj):
			continue
		drop_states[drop_id] = {
			"job_queued": bool(obj.get("job_queued")),
			"is_empty": bool(obj.has_method("is_empty") and obj.is_empty())
		}
	for job in _jobs:
		if not (job is Dictionary):
			continue
		if StringName(job.get("type", &"")) != &"HaulResource":
			continue
		var job_drop_id: int = int(job.get("drop_id", 0))
		if job_drop_id == 0 or drop_states.has(job_drop_id):
			continue
		var obj: Object = instance_from_id(job_drop_id)
		if obj == null or not is_instance_valid(obj):
			continue
		drop_states[job_drop_id] = {
			"job_queued": bool(obj.get("job_queued")),
			"is_empty": bool(obj.has_method("is_empty") and obj.is_empty())
		}

	var queue_result: Dictionary = HAUL_RESERVATION_LOGIC.collect_stale_queue_jobs(
		_jobs,
		_reserved_drop_ids,
		drop_states,
		now_ms,
		HAUL_QUEUE_TIMEOUT_MS
	)
	var remove_indexes: Array = queue_result.get("remove_indexes", [])
	for idx_any in remove_indexes:
		_jobs.remove_at(int(idx_any))
	for drop_id_any in queue_result.get("release_drop_ids", []):
		var drop_id: int = int(drop_id_any)
		_set_drop_job_queued(drop_id, false)
		_reserved_drop_ids.erase(drop_id)

	var reservation_result: Dictionary = HAUL_RESERVATION_LOGIC.collect_stale_reservations(
		_reserved_drop_ids,
		drop_states,
		now_ms,
		HAUL_ASSIGN_TIMEOUT_MS
	)
	for colonist_id_any in reservation_result.get("cancel_colonist_ids", []):
		var colonist_id: int = int(colonist_id_any)
		var colonist: Object = instance_from_id(colonist_id)
		if colonist != null and is_instance_valid(colonist) and colonist.has_method("cancel_current_job"):
			colonist.cancel_current_job()
	for drop_id_any in reservation_result.get("stale_drop_ids", []):
		var drop_id: int = int(drop_id_any)
		_set_drop_job_queued(drop_id, false)
		_reserved_drop_ids.erase(drop_id)

func _set_latest_haul_meta(drop_id: int, urgency: float, drop_amount: int) -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		if _jobs[i].get("type", &"") != &"HaulResource":
			continue
		if int(_jobs[i].get("drop_id", 0)) != drop_id:
			continue
		_jobs[i]["urgency"] = urgency
		_jobs[i]["drop_amount"] = drop_amount
		return

func _set_drop_job_queued(drop_id: int, value: bool) -> void:
	if drop_id == 0:
		return
	var obj: Object = instance_from_id(drop_id)
	if obj == null or not is_instance_valid(obj):
		return
	if obj.has_method("set_job_queued"):
		obj.set_job_queued(value)

func _pending_drop_types() -> Dictionary:
	var out: Dictionary = {}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return out
	if tree.get_nodes_in_group("stockpile_zones").is_empty():
		return out
	for drop in tree.get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		if drop.has_method("is_empty") and bool(drop.is_empty()):
			continue
		var resource_type: StringName = StringName(drop.get("resource_type"))
		if resource_type == &"":
			continue
		out[resource_type] = true
	return out

func _has_pending_need_job(colonist_id: int, job_type: StringName) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == job_type:
			return true
	return false

func _has_pending_combat_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		var t: StringName = StringName(job.get("type", &""))
		if t == &"CombatMelee" or t == &"CombatRanged":
			return true
	return false

func _has_pending_move_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == &"MoveTo":
			return true
	return false

func _has_pending_research_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == &"ResearchTask":
			return true
	return false

func _has_any_active_or_pending_research_job(colonists: Array) -> bool:
	for job in _jobs:
		if StringName(job.get("type", &"")) == &"ResearchTask":
			return true
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.current_job.is_empty():
			continue
		if StringName(colonist.current_job.get("type", &"")) == &"ResearchTask":
			return true
	return false

func _cleanup_stale_jobs() -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		var t_all: StringName = StringName(job.get("type", &""))
		match t_all:
			&"BuildSite":
				var site_id: int = int(job.get("site_id", 0))
				if site_id == 0:
					_jobs.remove_at(i)
					continue
				var site_obj: Object = instance_from_id(site_id)
				if site_obj == null or not is_instance_valid(site_obj):
					_jobs.remove_at(i)
			&"CombatMelee", &"CombatRanged":
				var target_id: int = int(job.get("target_id", 0))
				if target_id == 0:
					_jobs.remove_at(i)
					continue
				var target_obj: Object = instance_from_id(target_id)
				if target_obj == null or not is_instance_valid(target_obj):
					_jobs.remove_at(i)
					continue
				if target_obj.has_method("is_dead") and bool(target_obj.is_dead()):
					_jobs.remove_at(i)
			&"PlantCrop", &"HarvestCrop":
				var zone_id: int = int(job.get("zone_id", 0))
				if zone_id == 0:
					_jobs.remove_at(i)
					continue
				var zone_obj: Object = instance_from_id(zone_id)
				if zone_obj == null or not is_instance_valid(zone_obj):
					_jobs.remove_at(i)
			&"ResearchTask":
				var target: Vector2 = job.get("target", Vector2.INF)
				if target == Vector2.INF:
					_jobs.remove_at(i)
			&"RepairStructure", &"DemolishStructure", &"MaintainTrap":
				var structure_id: int = int(job.get("structure_id", 0))
				if structure_id == 0:
					_jobs.remove_at(i)
					continue
				var structure_obj: Object = instance_from_id(structure_id)
				if structure_obj == null or not is_instance_valid(structure_obj):
					_jobs.remove_at(i)

func _cleanup_stale_combat_jobs() -> void:
	_cleanup_stale_jobs()

func _cleanup_craft_slot_reservations(colonists: Array) -> void:
	var active_slots: Dictionary = {}
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var current_job: Dictionary = colonist.current_job
		if current_job.is_empty():
			continue
		if StringName(current_job.get("type", &"")) != &"CraftRecipe":
			continue
		var active_slot_id: int = int(current_job.get("craft_slot_id", 0))
		if active_slot_id != 0:
			active_slots[active_slot_id] = colonist.get_instance_id()
	for job in _jobs:
		if StringName(job.get("type", &"")) != &"CraftRecipe":
			continue
		var queued_slot_id: int = int(job.get("craft_slot_id", 0))
		if queued_slot_id != 0:
			active_slots[queued_slot_id] = 0
	var stale_slot_ids: Array[int] = []
	for slot_id_any in _reserved_craft_slot_ids.keys():
		var slot_id: int = int(slot_id_any)
		if active_slots.has(slot_id):
			continue
		stale_slot_ids.append(slot_id)
	for slot_id in stale_slot_ids:
		_reserved_craft_slot_ids.erase(slot_id)

func _find_adjacent_work_position(site: Node2D) -> Vector2:
	var center: Vector2 = site.global_position
	var candidates: Array[Vector2] = [
		center + Vector2(WORK_ADJACENT_OFFSET, 0.0),
		center + Vector2(-WORK_ADJACENT_OFFSET, 0.0),
		center + Vector2(0.0, WORK_ADJACENT_OFFSET),
		center + Vector2(0.0, -WORK_ADJACENT_OFFSET),
		center + Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET),
		center + Vector2(WORK_ADJACENT_OFFSET, -WORK_ADJACENT_OFFSET),
		center + Vector2(-WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET),
		center + Vector2(-WORK_ADJACENT_OFFSET, -WORK_ADJACENT_OFFSET)
	]
	var site_id: int = site.get_instance_id()
	for pos in candidates:
		if _is_blocked_by_structure(pos):
			continue
		if _is_work_position_reserved(pos, site_id):
			continue
		return pos
	for pos in candidates:
		if _is_blocked_by_structure(pos):
			continue
		return pos
	var ring2: Array[Vector2] = [
		center + Vector2(WORK_ADJACENT_OFFSET * 2.0, 0.0),
		center + Vector2(-WORK_ADJACENT_OFFSET * 2.0, 0.0),
		center + Vector2(0.0, WORK_ADJACENT_OFFSET * 2.0),
		center + Vector2(0.0, -WORK_ADJACENT_OFFSET * 2.0)
	]
	for pos in ring2:
		if _is_blocked_by_structure(pos):
			continue
		if _is_work_position_reserved(pos, site_id):
			continue
		return pos
	return Vector2.INF

func _is_work_position_reserved(world_pos: Vector2, for_site_id: int) -> bool:
	for job in _jobs:
		if StringName(job.get("type", &"")) != &"BuildSite":
			continue
		var job_site_id: int = int(job.get("site_id", 0))
		if job_site_id == 0 or job_site_id == for_site_id:
			continue
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			continue
		if target.distance_to(world_pos) <= 8.0:
			return true
	var colonists: Array = _get_cached_colonists()
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var active_job: Dictionary = colonist.get("current_job")
		if active_job.is_empty():
			continue
		if StringName(active_job.get("type", &"")) != &"BuildSite":
			continue
		var job_site_id: int = int(active_job.get("site_id", 0))
		if job_site_id == 0 or job_site_id == for_site_id:
			continue
		var active_target: Vector2 = active_job.get("target", Vector2.INF)
		if active_target == Vector2.INF:
			continue
		if active_target.distance_to(world_pos) <= 10.0:
			return true
	return false

func _is_blocked_by_structure(world_pos: Vector2) -> bool:
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("is_blocked_for_friendly"):
		return bool(_pathing_occupancy.is_blocked_for_friendly(world_pos))
	_refresh_spatial_cache()
	for node in _cached_blocking_structures:
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET)
		var dx: float = absf(world_pos.x - node.global_position.x)
		var dy: float = absf(world_pos.y - node.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	for site in _cached_build_sites:
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET)
		var dx: float = absf(world_pos.x - site.global_position.x)
		var dy: float = absf(world_pos.y - site.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	return false

func _refresh_spatial_cache() -> void:
	if not _spatial_cache_dirty:
		return
	_spatial_cache_dirty = false
	_cached_blocking_structures = get_tree().get_nodes_in_group("blocking_structures")
	_cached_build_sites = get_tree().get_nodes_in_group("build_sites")
	_cached_colonists = get_tree().get_nodes_in_group("colonists")

func _get_cached_colonists() -> Array:
	_refresh_spatial_cache()
	return _cached_colonists
