extends Node2D

const COMBAT_MATH: Script = preload("res://scripts/core/CombatMath.gd")
const FRIENDLY_PATHING: Script = preload("res://scripts/core/pathing/FriendlyPathing.gd")

signal status_changed(colonist: Node)
signal resource_harvested(resource_type: StringName, amount: int, world_pos: Vector2)
signal resource_delivered(resource_type: StringName, amount: int, zone: Node)
signal craft_completed(products: Dictionary, world_pos: Vector2, craft_slot_id: int)
signal research_progressed(project_id: StringName, points: float)
signal haul_job_released(drop_id: int)
signal structure_demolished(world_pos: Vector2, replace_building_id: StringName)
signal ate_food()
signal died(colonist: Node)

@export var stats: Resource
@export var priorities: Resource
@export var sprite_height: float = 72.0

var health: float = 100.0
var hunger: float = 100.0
var rest: float = 100.0
var mood: float = 100.0

var selected: bool = false
var current_job: Dictionary = {}
var gather_speed_multiplier: float = 1.0
var food_speed_buff_remaining: float = 0.0
var rest_recover_multiplier: float = 1.0
var wearing_clothes: bool = false
var equipment_slots: Dictionary = {
	&"Top": &"",
	&"Bottom": &"",
	&"Hat": &"",
	&"Weapon": &""
}
var combat_profile: Dictionary = {
	"base_hit": 0.72,
	"defense": 4.0,
	"melee_attack": 11.0,
	"ranged_attack": 7.0,
	"armor_penetration": 1.0,
	"melee_range": 34.0,
	"ranged_range": 200.0,
	"attack_cooldown_sec": 1.1,
	"accuracy_bonus": 0.0,
	"weapon_mode": &"Melee"
}
var work_enabled: Dictionary = {
	&"Haul": true,
	&"Build": true,
	&"Craft": true,
	&"Combat": true,
	&"Gather": true,
	&"Hunt": true
}
var tile_size: float = 40.0
const BUILD_WORK_TARGET_THRESHOLD: float = 18.0
const BUILD_WORK_SITE_RANGE_TILES: float = 1.6
const MOVE_STUCK_REPATH_SEC: float = 0.55
const UPDATE_NEAR_RADIUS: float = 900.0
const UPDATE_FAR_INTERVAL_SEC: float = 0.12
const OBSTACLE_SIG_INTERVAL_SEC: float = 0.25

var _move_stuck_elapsed: float = 0.0
var _reroute_target_pending: Vector2 = Vector2.INF
var _friendly_pathing: FriendlyPathing = null
var _sim_accum: float = 0.0
var _obstacle_sig_left: float = 0.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var job_label: Label = $JobLabel
@onready var work_progress: ProgressBar = $WorkProgress

func _ready() -> void:
	add_to_group("colonists")
	if stats == null:
		stats = load("res://scripts/data/ColonistStatsData.gd").new()
	if priorities == null:
		priorities = load("res://scripts/data/JobPriorityData.gd").new()
	health = stats.max_health
	set_combat_profile({
		"base_hit": float(stats.base_hit_chance),
		"defense": float(stats.base_defense),
		"melee_attack": float(stats.base_melee_attack),
		"ranged_attack": float(stats.base_ranged_attack),
		"armor_penetration": float(stats.base_armor_penetration),
		"melee_range": float(stats.melee_range),
		"ranged_range": float(stats.ranged_range),
		"attack_cooldown_sec": float(stats.attack_cooldown_sec),
		"accuracy_bonus": 0.0,
		"weapon_mode": &"Melee"
	})
	_fit_sprite()
	_friendly_pathing = FRIENDLY_PATHING.new()
	_friendly_pathing.setup(tile_size)
	emit_status()

func _physics_process(delta: float) -> void:
	_sim_accum += delta
	var tick_interval: float = _lod_tick_interval()
	if _sim_accum < tick_interval:
		return
	var sim_delta: float = _sim_accum
	_sim_accum = 0.0
	if food_speed_buff_remaining > 0.0:
		food_speed_buff_remaining = maxf(0.0, food_speed_buff_remaining - sim_delta)
	if _friendly_pathing != null:
		_friendly_pathing.tick(sim_delta)
	_update_local_obstacle_signature(sim_delta)
	_process_movement(sim_delta)
	_process_active_work(sim_delta)

func _lod_tick_interval() -> float:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	if global_position.distance_to(cam.global_position) <= UPDATE_NEAR_RADIUS:
		return 0.0
	return UPDATE_FAR_INTERVAL_SEC

func _update_local_obstacle_signature(delta: float) -> void:
	if _friendly_pathing == null:
		return
	if current_job.is_empty():
		return
	_obstacle_sig_left = maxf(0.0, _obstacle_sig_left - delta)
	if _obstacle_sig_left > 0.0:
		return
	_obstacle_sig_left = OBSTACLE_SIG_INTERVAL_SEC
	_friendly_pathing.notify_obstacle_signature(_compute_local_obstacle_signature())

func _compute_local_obstacle_signature() -> int:
	var radius: float = tile_size * 3.2
	var sig: int = 17
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		if bool(node.get_meta("passable_for_friendly")):
			continue
		if global_position.distance_to(node.global_position) > radius:
			continue
		sig = int((sig * 131 + node.get_instance_id()) % 2147483647)
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		if global_position.distance_to(site.global_position) > radius:
			continue
		sig = int((sig * 131 + site.get_instance_id()) % 2147483647)
	return sig

func _process_movement(delta: float) -> void:
	var goal: Vector2 = _resolve_move_goal()
	if goal == Vector2.INF:
		_clear_path_cache()
		_move_stuck_elapsed = 0.0
		return
	if global_position.distance_to(goal) <= 6.0:
		_clear_path_cache()
		_move_stuck_elapsed = 0.0
		if _reroute_target_pending != Vector2.INF:
			nav.target_position = _reroute_target_pending
			_reroute_target_pending = Vector2.INF
		return
	var speed_mul: float = 1.5 if food_speed_buff_remaining > 0.0 else 1.0
	var result: Dictionary = {}
	if _friendly_pathing != null:
		result = _friendly_pathing.move_step(
			global_position,
			goal,
			stats.move_speed * speed_mul,
			delta,
			Callable(self, "_is_blocked_position")
		)
	var blocked: bool = bool(result.get("blocked", false))
	if blocked:
		_move_stuck_elapsed += delta
		if _move_stuck_elapsed >= MOVE_STUCK_REPATH_SEC:
			_move_stuck_elapsed = 0.0
		return
	global_position = result.get("position", global_position)
	_move_stuck_elapsed = 0.0

func set_tile_size(value: float) -> void:
	tile_size = maxf(4.0, value)
	if _friendly_pathing != null:
		_friendly_pathing.setup(tile_size)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / tile_size) * tile_size,
		round(world_pos.y / tile_size) * tile_size
	)

func _is_blocked_position(world_pos: Vector2) -> bool:
	var tile: Vector2 = _snap_to_tile(world_pos)
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		# Friendly colonists can pass through gate-like structures.
		if bool(node.get_meta("passable_for_friendly")):
			continue
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(tile_size, tile_size)
		var dx: float = absf(tile.x - node.global_position.x)
		var dy: float = absf(tile.y - node.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(tile_size, tile_size)
		var dx: float = absf(tile.x - site.global_position.x)
		var dy: float = absf(tile.y - site.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	return false

func _resolve_move_goal() -> Vector2:
	if current_job.is_empty():
		return Vector2.INF
	if current_job.has("target"):
		return _snap_to_tile(current_job.get("target", global_position))
	return _snap_to_tile(nav.target_position)

func _is_at_goal(goal: Vector2) -> bool:
	return global_position.distance_to(goal) <= 6.0

func _clear_path_cache() -> void:
	if _friendly_pathing != null:
		_friendly_pathing.clear()

func _nearby_cover_bonus() -> float:
	var best_bonus: float = 0.0
	for node in get_tree().get_nodes_in_group("cover_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist > maxf(48.0, tile_size * 1.2):
			continue
		var cover: float = float(node.get_meta("cover_bonus")) if node.has_meta("cover_bonus") else 0.0
		if cover > best_bonus:
			best_bonus = cover
	return best_bonus

func tick_needs(delta: float) -> void:
	hunger = clampf(hunger - stats.hunger_decay_per_sec * delta, 0.0, 100.0)
	rest = clampf(rest - stats.rest_decay_per_sec * delta, 0.0, 100.0)
	var mood_penalty: float = (100.0 - hunger) * 0.01 + (100.0 - rest) * 0.008
	mood = clampf(mood - (stats.mood_decay_per_sec + mood_penalty) * delta, 0.0, 100.0)
	emit_status()

func get_priority(job_type: StringName) -> int:
	return priorities.get_priority(job_type)

func assign_job(job: Dictionary) -> void:
	current_job = job
	_reroute_target_pending = Vector2.INF
	_move_stuck_elapsed = 0.0
	_clear_path_cache()
	var job_type: StringName = job.get("type", &"Idle")
	match job_type:
		&"MoveTo":
			var target: Vector2 = job.get("target", global_position)
			target = _snap_to_tile(target)
			current_job["target"] = target
			nav.target_position = target
		&"BuildSite":
			var build_target: Vector2 = job.get("target", global_position)
			build_target = _snap_to_tile(build_target)
			current_job["target"] = build_target
			nav.target_position = build_target
		&"RepairStructure":
			var repair_target: Vector2 = job.get("target", global_position)
			repair_target = _snap_to_tile(repair_target)
			current_job["target"] = repair_target
			nav.target_position = repair_target
		&"DemolishStructure":
			var demolish_target: Vector2 = job.get("target", global_position)
			demolish_target = _snap_to_tile(demolish_target)
			current_job["target"] = demolish_target
			nav.target_position = demolish_target
		&"Gather":
			var gather_target: Vector2 = job.get("target", global_position)
			gather_target = _snap_to_tile(gather_target)
			current_job["target"] = gather_target
			nav.target_position = gather_target
		&"Hunt":
			var hunt_target: Vector2 = job.get("target", global_position)
			hunt_target = _snap_to_tile(hunt_target)
			current_job["target"] = hunt_target
			nav.target_position = hunt_target
		&"HaulResource":
			var drop_target: Vector2 = job.get("target", global_position)
			drop_target = _snap_to_tile(drop_target)
			current_job["target"] = drop_target
			nav.target_position = drop_target
		&"CraftRecipe":
			var craft_target: Vector2 = job.get("target", global_position)
			craft_target = _snap_to_tile(craft_target)
			current_job["target"] = craft_target
			nav.target_position = craft_target
		&"ResearchTask":
			var research_target: Vector2 = job.get("target", global_position)
			research_target = _snap_to_tile(research_target)
			current_job["target"] = research_target
			nav.target_position = research_target
		&"PlantCrop", &"HarvestCrop":
			var farm_target: Vector2 = job.get("target", global_position)
			farm_target = _snap_to_tile(farm_target)
			current_job["target"] = farm_target
			nav.target_position = farm_target
		&"CombatMelee", &"CombatRanged":
			var combat_target: Vector2 = job.get("target", global_position)
			combat_target = _snap_to_tile(combat_target)
			current_job["target"] = combat_target
			nav.target_position = combat_target
			current_job["next_attack_ms"] = 0
		&"EatStub":
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = 2.0
			_set_work_progress(0.0, true)
			nav.target_position = global_position
		&"IdleRecover":
			rest = clampf(rest + 20.0 * rest_recover_multiplier, 0.0, 100.0)
			mood = clampf(mood + 4.0 * rest_recover_multiplier, 0.0, 100.0)
			_finish_current_job()
	emit_status()

func cancel_current_job() -> void:
	if current_job.is_empty():
		nav.target_position = global_position
		return
	var job_type: StringName = current_job.get("type", &"")
	if job_type == &"BuildSite":
		var site_id: int = int(current_job.get("site_id", 0))
		if site_id != 0:
			var site: Object = instance_from_id(site_id)
			if site != null and is_instance_valid(site):
				site.set_job_queued(false)
	elif job_type == &"RepairStructure":
		var structure_id: int = int(current_job.get("structure_id", 0))
		if structure_id != 0:
			var structure: Object = instance_from_id(structure_id)
			if structure != null and is_instance_valid(structure):
				structure.set_meta("repair_job_queued", false)
	elif job_type == &"DemolishStructure":
		var structure_id: int = int(current_job.get("structure_id", 0))
		if structure_id != 0:
			var structure: Object = instance_from_id(structure_id)
			if structure != null and is_instance_valid(structure):
				structure.set_meta("demolish_job_queued", false)
	elif job_type == &"Gather":
		var gatherable_id: int = int(current_job.get("gatherable_id", 0))
		if gatherable_id != 0:
			var gatherable: Object = instance_from_id(gatherable_id)
			if gatherable != null and is_instance_valid(gatherable):
				gatherable.set_job_queued(false)
	elif job_type == &"Hunt":
		var huntable_id: int = int(current_job.get("huntable_id", 0))
		if huntable_id != 0:
			var huntable: Object = instance_from_id(huntable_id)
			if huntable != null and is_instance_valid(huntable):
				huntable.set_job_queued(false)
	elif job_type == &"HaulResource":
		var drop_id: int = int(current_job.get("drop_id", 0))
		if drop_id != 0:
			var drop: Object = instance_from_id(drop_id)
			if drop != null and is_instance_valid(drop) and drop.has_method("set_job_queued"):
				drop.set_job_queued(false)
			haul_job_released.emit(drop_id)
	elif job_type == &"PlantCrop" or job_type == &"HarvestCrop":
		var zone_id: int = int(current_job.get("zone_id", 0))
		if zone_id != 0:
			var zone_obj: Object = instance_from_id(zone_id)
			if zone_obj != null and is_instance_valid(zone_obj) and zone_obj.has_method("clear_plot_job"):
				zone_obj.clear_plot_job(current_job.get("tile", Vector2i.ZERO))
	current_job.clear()
	_reroute_target_pending = Vector2.INF
	_move_stuck_elapsed = 0.0
	_clear_path_cache()
	nav.target_position = global_position
	emit_status()

func is_idle() -> bool:
	return current_job.is_empty()

func update_job_completion(_delta: float = 0.0) -> void:
	if current_job.is_empty():
		return
	var job_type: StringName = current_job.get("type", &"")
	if job_type == &"MoveTo" and _is_job_target_reached(10.0):
		_finish_current_job()
	elif job_type == &"BuildSite":
		var site_for_supply: Object = instance_from_id(int(current_job.get("site_id", 0)))
		if site_for_supply == null or not is_instance_valid(site_for_supply):
			_finish_current_job()
			return
		if bool(site_for_supply.get("complete")):
			_finish_current_job()
			return
		if _is_build_site_reach_failed(site_for_supply):
			if site_for_supply.has_method("set_job_queued"):
				site_for_supply.set_job_queued(false)
			_finish_current_job()
			return
		if not _can_start_build_site_work(site_for_supply):
			return
		if site_for_supply != null and is_instance_valid(site_for_supply):
			if site_for_supply.has_method("requires_material_delivery") and bool(site_for_supply.requires_material_delivery()):
				if not _try_supply_build_site(site_for_supply):
					if site_for_supply.has_method("set_job_queued"):
						site_for_supply.set_job_queued(false)
					_finish_current_job()
					return
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(1.0, float(current_job.get("work_duration", 30.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"RepairStructure" and _is_job_target_reached(18.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(0.2, float(current_job.get("work_duration", 8.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"DemolishStructure" and _is_job_target_reached(18.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(0.2, float(current_job.get("work_duration", 4.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"Gather" and _is_job_target_reached(18.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = 5.0
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"Hunt" and _is_job_target_reached(20.0):
		var huntable_id: int = int(current_job.get("huntable_id", 0))
		if huntable_id != 0:
			var huntable: Object = instance_from_id(huntable_id)
			if huntable != null and is_instance_valid(huntable) and huntable.has_method("hunt_once"):
				var result: Dictionary = huntable.hunt_once(25.0)
				var amount: int = int(result.get("amount", 0))
				var resource_type: StringName = result.get("resource_type", &"")
				if amount > 0 and resource_type != &"":
					resource_harvested.emit(resource_type, amount, global_position)
				if huntable.has_method("set_job_queued"):
					huntable.set_job_queued(false)
		current_job.clear()
		_set_work_progress(0.0, false)
		_finish_current_job()
	elif job_type == &"HaulResource" and _is_job_target_reached(18.0):
		var drop_id: int = int(current_job.get("drop_id", 0))
		var zone_id: int = int(current_job.get("zone_id", 0))
		var phase: StringName = current_job.get("phase", &"to_drop")
		var zone_node: Node = null
		if zone_id != 0:
			var z: Object = instance_from_id(zone_id)
			if z != null and is_instance_valid(z):
				zone_node = z

		if phase == &"to_drop":
			var requested_amount: int = 0
			var pickup_amount: int = 0
			var pickup_type: StringName = &""
			var carry_limit: int = maxi(1, int(stats.haul_carry_capacity))
			var target_pickup: int = carry_limit
			if drop_id != 0:
				var drop: Object = instance_from_id(drop_id)
				if drop != null and is_instance_valid(drop) and drop.has_method("take_amount"):
					pickup_type = StringName(drop.get("resource_type"))
					requested_amount = int(drop.get("amount"))
					var accepted: int = mini(requested_amount, carry_limit)
					if zone_node != null and zone_node.has_method("preview_acceptable_amount"):
						target_pickup = int(zone_node.preview_acceptable_amount(pickup_type, carry_limit))
						accepted = mini(accepted, target_pickup)
					pickup_amount = drop.take_amount(accepted)
					if drop.has_method("is_empty") and drop.is_empty():
						drop.queue_free()
					elif drop.has_method("set_job_queued"):
						drop.set_job_queued(false)
			if pickup_type != &"" and pickup_amount > 0 and pickup_amount < target_pickup:
				pickup_amount += _pickup_additional_nearby_drops(pickup_type, target_pickup - pickup_amount)
			if pickup_amount <= 0 or pickup_type == &"":
				if drop_id != 0:
					haul_job_released.emit(drop_id)
				_finish_current_job()
				return

			current_job["carried_type"] = pickup_type
			current_job["carried_amount"] = pickup_amount
			current_job["phase"] = &"to_zone"
			var target_pos: Vector2 = global_position
			if zone_node != null:
				target_pos = zone_node.global_position
				if zone_node.has_method("get_drop_point"):
					target_pos = zone_node.get_drop_point()
			current_job["target"] = target_pos
			nav.target_position = target_pos
			emit_status()
			return

		var delivered_type: StringName = current_job.get("carried_type", &"")
		var delivered_amount: int = int(current_job.get("carried_amount", 0))
		if delivered_amount > 0 and delivered_type != &"":
			resource_delivered.emit(delivered_type, delivered_amount, zone_node)
		if drop_id != 0:
			haul_job_released.emit(drop_id)
		_finish_current_job()
	elif job_type == &"CraftRecipe" and _is_job_target_reached(18.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(0.1, float(current_job.get("work_duration", 5.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"ResearchTask" and _is_job_target_reached(18.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(0.5, float(current_job.get("work_duration", 6.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif (job_type == &"PlantCrop" or job_type == &"HarvestCrop") and _is_job_target_reached(12.0):
		if not bool(current_job.get("work_started", false)):
			current_job["work_started"] = true
			current_job["work_elapsed"] = 0.0
			current_job["work_duration"] = maxf(0.1, float(current_job.get("work_duration", 2.0)))
			_set_work_progress(0.0, true)
			emit_status()
		return
	elif job_type == &"CombatMelee" or job_type == &"CombatRanged":
		_process_combat_job(job_type)

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func emit_status() -> void:
	_update_job_label()
	status_changed.emit(self)

func set_work_enabled(work_type: StringName, enabled: bool) -> void:
	work_enabled[work_type] = enabled
	emit_status()

func set_gather_speed_multiplier(value: float) -> void:
	gather_speed_multiplier = clampf(value, 1.0, 2.5)

func set_rest_recover_multiplier(value: float) -> void:
	rest_recover_multiplier = clampf(value, 1.0, 2.0)

func set_wearing_clothes(value: bool) -> void:
	if wearing_clothes == value:
		return
	wearing_clothes = value
	emit_status()

func is_wearing_clothes() -> bool:
	return wearing_clothes

func set_equipment_slots(next_slots: Dictionary) -> void:
	var keys := [&"Top", &"Bottom", &"Hat", &"Weapon"]
	var changed: bool = false
	for k in keys:
		var next_value: StringName = StringName(next_slots.get(k, &""))
		if StringName(equipment_slots.get(k, &"")) == next_value:
			continue
		equipment_slots[k] = next_value
		changed = true
	if changed:
		emit_status()

func get_equipment_snapshot() -> Dictionary:
	return equipment_slots.duplicate(true)

func can_do_job(job_type: StringName) -> bool:
	match job_type:
		&"BuildSite":
			return bool(work_enabled.get(&"Build", true))
		&"RepairStructure":
			return bool(work_enabled.get(&"Build", true))
		&"DemolishStructure":
			return bool(work_enabled.get(&"Build", true))
		&"Gather":
			return bool(work_enabled.get(&"Gather", true))
		&"Hunt":
			return bool(work_enabled.get(&"Hunt", true))
		&"HaulResource":
			return bool(work_enabled.get(&"Haul", true))
		&"CraftRecipe":
			return bool(work_enabled.get(&"Craft", true))
		&"ResearchTask":
			return bool(work_enabled.get(&"Craft", true))
		&"CombatMelee", &"CombatRanged":
			return bool(work_enabled.get(&"Combat", true))
		&"PlantCrop", &"HarvestCrop":
			return bool(work_enabled.get(&"Gather", true))
		_:
			return true

func _draw() -> void:
	if not selected:
		return
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 48, Color(0.35, 0.9, 1.0), 2.0)

func _fit_sprite() -> void:
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.y <= 0.0:
		return
	var scale_factor: float = sprite_height / tex_size.y
	sprite.scale = Vector2(scale_factor, scale_factor)

func _is_job_target_reached(threshold: float) -> bool:
	var target: Vector2 = current_job.get("target", global_position)
	return global_position.distance_to(target) <= threshold

func _can_start_build_site_work(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	var target: Vector2 = current_job.get("target", global_position)
	if global_position.distance_to(target) > BUILD_WORK_TARGET_THRESHOLD:
		return false
	if site_obj is Node2D:
		var site_range: float = maxf(tile_size * BUILD_WORK_SITE_RANGE_TILES, BUILD_WORK_TARGET_THRESHOLD + 6.0)
		if global_position.distance_to((site_obj as Node2D).global_position) > site_range:
			return false
	return true

func _is_build_site_reach_failed(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return true
	var target: Vector2 = current_job.get("target", global_position)
	if not _is_at_goal(target):
		return false
	if global_position.distance_to(target) > BUILD_WORK_TARGET_THRESHOLD + 4.0:
		return true
	if site_obj is Node2D:
		var site_range: float = maxf(tile_size * BUILD_WORK_SITE_RANGE_TILES, BUILD_WORK_TARGET_THRESHOLD + 10.0)
		if global_position.distance_to((site_obj as Node2D).global_position) > site_range:
			return true
	return false

func _update_job_label() -> void:
	if job_label == null:
		return
	if current_job.is_empty():
		job_label.visible = false
		return
	var job_type: StringName = current_job.get("type", &"Idle")
	var job_name: String = _job_display_name(job_type)
	if job_name.is_empty():
		job_label.visible = false
		return
	job_label.text = job_name
	job_label.visible = true
	if job_type == &"Gather" and bool(current_job.get("work_started", false)):
		job_label.text = "채집 진행중"

func _job_display_name(job_type: StringName) -> String:
	match job_type:
		&"MoveTo":
			return "이동"
		&"BuildSite":
			return "건설"
		&"RepairStructure":
			return "수리"
		&"DemolishStructure":
			return "해체"
		&"Gather":
			return "채집"
		&"Hunt":
			return "사냥"
		&"HaulResource":
			return "운반"
		&"CraftRecipe":
			return "제작"
		&"ResearchTask":
			return "연구"
		&"PlantCrop":
			return "파종"
		&"HarvestCrop":
			return "수확"
		&"EatStub":
			return "식사"
		&"IdleRecover":
			return "휴식"
		&"CombatMelee":
			return "근접 전투"
		&"CombatRanged":
			return "원거리 전투"
		_:
			return ""

func _process_active_work(delta: float) -> void:
	if current_job.is_empty():
		_set_work_progress(0.0, false)
		return
	var job_type: StringName = current_job.get("type", &"")
	if job_type != &"Gather" and job_type != &"BuildSite" and job_type != &"RepairStructure" and job_type != &"DemolishStructure" and job_type != &"CraftRecipe" and job_type != &"ResearchTask" and job_type != &"EatStub" and job_type != &"PlantCrop" and job_type != &"HarvestCrop":
		_set_work_progress(0.0, false)
		return
	if not bool(current_job.get("work_started", false)):
		return
	var elapsed: float = float(current_job.get("work_elapsed", 0.0))
	var duration: float = float(current_job.get("work_duration", 5.0))
	var work_speed: float = gather_speed_multiplier if job_type == &"Gather" else 1.0
	elapsed += delta * work_speed
	current_job["work_elapsed"] = elapsed
	var ratio: float = 1.0 if duration <= 0.0 else clampf(elapsed / duration, 0.0, 1.0)
	_set_work_progress(ratio, true)
	if elapsed >= duration:
		if job_type == &"Gather":
			_complete_gather_job()
		elif job_type == &"BuildSite":
			_complete_build_job()
		elif job_type == &"RepairStructure":
			_complete_repair_job()
		elif job_type == &"DemolishStructure":
			_complete_demolish_job()
		elif job_type == &"PlantCrop":
			_complete_plant_crop_job()
		elif job_type == &"HarvestCrop":
			_complete_harvest_crop_job()
		elif job_type == &"EatStub":
			_complete_eat_job()
		elif job_type == &"ResearchTask":
			_complete_research_job()
		else:
			_complete_craft_job()

func _complete_gather_job() -> void:
	var gatherable_id: int = int(current_job.get("gatherable_id", 0))
	if gatherable_id != 0:
		var gatherable: Object = instance_from_id(gatherable_id)
		if gatherable != null and is_instance_valid(gatherable) and gatherable.has_method("gather_once"):
			var result: Dictionary = gatherable.gather_once(25.0)
			var amount: int = int(result.get("amount", 0))
			var resource_type: StringName = result.get("resource_type", &"")
			if amount > 0 and resource_type != &"":
				resource_harvested.emit(resource_type, amount, global_position)
			if gatherable.has_method("set_job_queued"):
				gatherable.set_job_queued(false)
	_finish_current_job()

func _complete_build_job() -> void:
	var site_id: int = int(current_job.get("site_id", 0))
	if site_id != 0:
		var site: Object = instance_from_id(site_id)
		if site != null and is_instance_valid(site):
			var target_work: float = float(site.get("required_work"))
			var progressed: float = float(site.get("work_progress"))
			site.apply_work(maxf(0.0, target_work - progressed))
			if not bool(site.get("complete")) and site.has_method("set_job_queued"):
				site.set_job_queued(false)
	_finish_current_job()

func _complete_repair_job() -> void:
	var structure_id: int = int(current_job.get("structure_id", 0))
	if structure_id != 0:
		var structure: Object = instance_from_id(structure_id)
		if structure != null and is_instance_valid(structure):
			var max_hp: float = float(structure.get_meta("structure_max_health")) if structure.has_meta("structure_max_health") else 0.0
			if max_hp > 0.0:
				structure.set_meta("structure_health", max_hp)
			structure.set_meta("repair_job_queued", false)
	_finish_current_job()

func _complete_demolish_job() -> void:
	var structure_id: int = int(current_job.get("structure_id", 0))
	var replace_building_id: StringName = StringName(current_job.get("replace_building_id", &""))
	if structure_id != 0:
		var structure: Object = instance_from_id(structure_id)
		if structure != null and is_instance_valid(structure):
			var pos: Vector2 = structure.global_position if structure is Node2D else global_position
			structure.set_meta("demolish_job_queued", false)
			structure.queue_free()
			structure_demolished.emit(pos, replace_building_id)
	_finish_current_job()

func _complete_craft_job() -> void:
	var products: Dictionary = current_job.get("products", {})
	var craft_slot_id: int = int(current_job.get("craft_slot_id", 0))
	craft_completed.emit(products, global_position, craft_slot_id)
	_finish_current_job()

func _complete_eat_job() -> void:
	hunger = clampf(hunger + 60.0, 0.0, 100.0)
	mood = clampf(mood + 15.0, 0.0, 100.0)
	food_speed_buff_remaining = maxf(food_speed_buff_remaining, 300.0)
	ate_food.emit()
	_finish_current_job()

func _complete_research_job() -> void:
	var project_id: StringName = StringName(current_job.get("project_id", &""))
	var points: float = maxf(0.1, float(current_job.get("research_points", 1.0)))
	if project_id != &"":
		research_progressed.emit(project_id, points)
	_finish_current_job()

func _complete_plant_crop_job() -> void:
	var zone_id: int = int(current_job.get("zone_id", 0))
	if zone_id != 0:
		var zone_obj: Object = instance_from_id(zone_id)
		if zone_obj != null and is_instance_valid(zone_obj) and zone_obj.has_method("plant_crop"):
			zone_obj.plant_crop(current_job.get("tile", Vector2i.ZERO), StringName(current_job.get("crop_type", &"Potato")))
	_finish_current_job()

func _complete_harvest_crop_job() -> void:
	var zone_id: int = int(current_job.get("zone_id", 0))
	if zone_id != 0:
		var zone_obj: Object = instance_from_id(zone_id)
		if zone_obj != null and is_instance_valid(zone_obj) and zone_obj.has_method("harvest_crop"):
			var result: Dictionary = zone_obj.harvest_crop(current_job.get("tile", Vector2i.ZERO))
			var amount: int = int(result.get("amount", 0))
			var resource_type: StringName = StringName(result.get("resource_type", &""))
			if amount > 0 and resource_type != &"":
				resource_harvested.emit(resource_type, amount, global_position)
	_finish_current_job()

func _set_work_progress(ratio: float, visible_flag: bool) -> void:
	if work_progress == null:
		return
	work_progress.visible = visible_flag
	work_progress.value = clampf(ratio * 100.0, 0.0, 100.0)

func _pickup_additional_nearby_drops(resource_type: StringName, remaining_capacity: int) -> int:
	var remain: int = remaining_capacity
	if remain <= 0:
		return 0
	var picked_total: int = 0
	var pickup_radius: float = 90.0
	var drops: Array = get_tree().get_nodes_in_group("resource_drops")
	drops.sort_custom(func(a, b):
		if a == null or not is_instance_valid(a):
			return false
		if b == null or not is_instance_valid(b):
			return true
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	for drop in drops:
		if remain <= 0:
			break
		if drop == null or not is_instance_valid(drop):
			continue
		if StringName(drop.get("resource_type")) != resource_type:
			continue
		if global_position.distance_to(drop.global_position) > pickup_radius:
			continue
		if not drop.has_method("take_amount"):
			continue
		var taken: int = int(drop.take_amount(remain))
		if taken <= 0:
			continue
		if drop.has_method("set_job_queued"):
			drop.set_job_queued(false)
		haul_job_released.emit(drop.get_instance_id())
		picked_total += taken
		remain -= taken
		if drop.has_method("is_empty") and drop.is_empty():
			drop.queue_free()
	return picked_total

func set_combat_profile(profile: Dictionary) -> void:
	var keys := [
		"base_hit",
		"defense",
		"melee_attack",
		"ranged_attack",
		"armor_penetration",
		"melee_range",
		"ranged_range",
		"attack_cooldown_sec",
		"accuracy_bonus",
		"weapon_mode"
	]
	for key in keys:
		if profile.has(key):
			combat_profile[key] = profile[key]

func get_combat_profile() -> Dictionary:
	return combat_profile.duplicate(true)

func get_combat_defender_profile() -> Dictionary:
	return {
		"defense": float(combat_profile.get("defense", 0.0)) + _nearby_cover_bonus()
	}

func is_dead() -> bool:
	return health <= 0.0

func apply_combat_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	health = maxf(0.0, health - float(amount))
	emit_status()
	if health <= 0.0:
		_die()

func _process_combat_job(job_type: StringName) -> void:
	var target_id: int = int(current_job.get("target_id", 0))
	if target_id == 0:
		_finish_current_job()
		return
	var target_obj: Object = instance_from_id(target_id)
	if target_obj == null or not is_instance_valid(target_obj):
		_finish_current_job()
		return
	if not (target_obj is Node2D):
		_finish_current_job()
		return
	var target_node: Node2D = target_obj
	var target_pos: Vector2 = target_node.global_position
	current_job["target"] = target_pos
	var attack_range: float = _combat_attack_range(job_type)
	var dist: float = global_position.distance_to(target_pos)
	if dist > attack_range:
		nav.target_position = target_pos
		return
	nav.target_position = global_position
	var now_ms: int = Time.get_ticks_msec()
	var next_attack_ms: int = int(current_job.get("next_attack_ms", 0))
	if now_ms < next_attack_ms:
		return
	var attacker: Dictionary = {
		"attack_power": _combat_attack_power(job_type),
		"armor_penetration": float(combat_profile.get("armor_penetration", 0.0)),
		"base_hit": float(combat_profile.get("base_hit", 0.7)),
		"accuracy_bonus": float(combat_profile.get("accuracy_bonus", 0.0)),
		"attack_range": attack_range
	}
	var defender: Dictionary = {"defense": 0.0}
	if target_obj.has_method("get_combat_defender_profile"):
		defender = target_obj.get_combat_defender_profile()
	var result: Dictionary = COMBAT_MATH.resolve_attack(attacker, defender, dist)
	if bool(result.get("hit", false)) and target_obj.has_method("apply_combat_damage"):
		target_obj.apply_combat_damage(int(result.get("damage", 0)))
	current_job["next_attack_ms"] = now_ms + int(round(1000.0 * maxf(0.1, float(combat_profile.get("attack_cooldown_sec", 1.1)))))
	if target_obj.has_method("is_dead") and bool(target_obj.is_dead()):
		_finish_current_job()

func _combat_attack_range(job_type: StringName) -> float:
	if job_type == &"CombatRanged":
		return maxf(20.0, float(combat_profile.get("ranged_range", 160.0)))
	return maxf(18.0, float(combat_profile.get("melee_range", 30.0)))

func _combat_attack_power(job_type: StringName) -> float:
	if job_type == &"CombatRanged":
		return maxf(1.0, float(combat_profile.get("ranged_attack", 5.0)))
	return maxf(1.0, float(combat_profile.get("melee_attack", 8.0)))

func _die() -> void:
	if not current_job.is_empty():
		cancel_current_job()
	died.emit(self)
	queue_free()

func _try_supply_build_site(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	var controller: Node = get_tree().get_first_node_in_group("main_controller")
	if controller == null or not is_instance_valid(controller):
		return false
	if not controller.has_method("try_supply_build_site"):
		return false
	return bool(controller.try_supply_build_site(site_obj))

func _finish_current_job() -> void:
	current_job.clear()
	_reroute_target_pending = Vector2.INF
	_move_stuck_elapsed = 0.0
	_clear_path_cache()
	_set_work_progress(0.0, false)
	nav.target_position = global_position
	emit_status()
