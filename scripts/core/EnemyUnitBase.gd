extends Node2D
class_name EnemyUnitBase

const COMBAT_MATH: Script = preload("res://scripts/core/CombatMath.gd")
const COMBAT_LOS: Script = preload("res://scripts/core/CombatLineOfSight.gd")
const ENEMY_PATHING: Script = preload("res://scripts/core/pathing/EnemyPathing.gd")
const EQUIPMENT_STATS: Script = preload("res://scripts/core/EquipmentStats.gd")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const STRUCTURE_HEALTH_BAR: Script = preload("res://scripts/core/StructureHealthBar.gd")

signal died(enemy: Node)
signal moved(enemy: Node, tile: Vector2i)

const UPDATE_NEAR_RADIUS: float = 900.0
const UPDATE_NEAR_INTERVAL_SEC: float = 0.1
const UPDATE_FAR_INTERVAL_SEC: float = 0.24
const TARGET_REFRESH_SEC: float = 0.35
const AI_STEP_SEC: float = 0.16
const LOD_REFRESH_SEC: float = 0.3
const CELL_CENTER_EPSILON: float = 0.75
const MELEE_GOAL_CACHE_MS: int = 1600
const MELEE_SLOT_COUNT: int = 8
const MELEE_SLOT_MAX_RING: int = 8
const MELEE_SLOT_RESOLVE_DISTANCE_TILES: float = 6.0
const MAX_SIM_ACCUM_SEC: float = 0.65
const MAX_SIM_STEPS_PER_PHYSICS: int = 2
const STRUCTURE_ATTACK_TARGET_REFRESH_MS: int = 450
const STRUCTURE_ATTACK_TARGET_FAIL_REFRESH_MS: int = 120
const STRUCTURE_ATTACK_SCAN_BUDGET_PER_FRAME: int = 10
const POST_BREACH_FLOW_DEFER_MS: int = 350

static var _melee_attacker_cache_frame: int = -1
static var _melee_attacker_ids_by_target: Dictionary = {}
static var _melee_cell_cache_frame: int = -1
static var _melee_occupied_ids_by_cell: Dictionary = {}
static var _melee_claim_ids_by_cell: Dictionary = {}
static var _structure_attack_scan_frame: int = -1
static var _structure_attack_scan_count: int = 0
static var _perf_env_checked: bool = false
static var _perf_enabled: bool = false
static var _perf_units: int = 0
static var _perf_steps: int = 0
static var _perf_move_us: int = 0
static var _perf_ai_us: int = 0
static var _post_breach_flow_defer_until_ms: int = 0

var health: float = 0.0
var _target_colonist_id: int = 0
var _melee_lock_target_id: int = 0
var _melee_goal_cache_target_id: int = 0
var _melee_goal_cache_cell: Vector2 = Vector2.INF
var _melee_goal_cache_next_ms: int = 0
var _melee_step_claim_cell: Vector2 = Vector2.INF
var _melee_step_claim_next_ms: int = 0
var _next_attack_ms: int = 0
var _next_structure_attack_ms: int = 0
var _structure_attack_target_id: int = 0
var _structure_attack_target_refresh_ms: int = 0
var _target_refresh_left: float = 0.0
var _ai_phase_left: float = 0.0
var tile_size: float = 64.0
var _enemy_pathing: EnemyPathing = null
var _enemy_flow_field_service: Node = null
var _enemy_engagement_coordinator: Node = null
var _pathing_occupancy: Node = null
var _main_controller: Node = null
var _sim_accum: float = 0.0
var external_move_speed_multiplier: float = 1.0
var external_accuracy_bonus: float = 0.0
var _cached_lod_interval: float = UPDATE_NEAR_INTERVAL_SEC
var _next_lod_refresh_ms: int = 0
var _sim_interval_scale: float = 1.0
var _weapon_mode: StringName = &"Melee"
var _default_weapon_mode: StringName = &"Melee"
var _move_goal: Vector2 = Vector2.INF
var _move_goal_exact: bool = false
var _last_move_tile: Vector2i = Vector2i(999999, 999999)
var _last_move_bucket: Vector2i = Vector2i(999999, 999999)
var _spawn_unclip_left: float = 3.0
var _spawn_unclip_retry_left: float = 0.0
var _grp_colonists: Array = []
var _grp_colonists_ms: int = 0
var _grp_structures: Array = []
var _grp_structures_ms: int = 0
var _grp_blocking: Array = []
var _grp_blocking_ms: int = 0
var _is_blocked_callable: Callable
var _profile_ready: bool = false
var equipment_slots: Dictionary = {
	&"Top": &"",
	&"Bottom": &"",
	&"Hat": &"",
	&"Weapon": &""
}

var max_health: float = 100.0
var move_speed: float = 100.0
var base_hit_chance: float = 0.65
var defense: float = 2.0
var melee_attack: float = 8.0
var ranged_attack: float = 0.0
var armor_penetration: float = 0.5
var melee_range: float = 28.0
var ranged_range: float = 180.0
var attack_cooldown_sec: float = 1.2
var structure_attack_damage: float = 10.0
var structure_attack_range: float = 30.0
var ranged_ratio: float = 0.0
var _base_max_health: float = 100.0
var _base_move_speed: float = 100.0
var _base_hit_chance: float = 0.65
var _base_defense: float = 2.0
var _base_melee_attack: float = 8.0
var _base_ranged_attack: float = 0.0
var _base_armor_penetration: float = 0.5
var _base_melee_range: float = 28.0
var _base_ranged_range: float = 180.0
var _base_attack_cooldown_sec: float = 1.2
var _base_structure_attack_damage: float = 10.0
var _base_structure_attack_range: float = 30.0
var _base_ranged_ratio: float = 0.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	_lock_rotation()
	_apply_profile(get_unit_profile())
	_profile_ready = true
	_default_weapon_mode = get_initial_weapon_mode()
	health = max_health
	_weapon_mode = _default_weapon_mode
	_apply_equipment_profile()
	_register_enemy_groups()
	_enemy_pathing = ENEMY_PATHING.new()
	_enemy_pathing.setup(tile_size)
	_is_blocked_callable = Callable(self, "_is_blocked_position")
	_ai_phase_left = fmod(float(get_instance_id()) * 0.017, AI_STEP_SEC)
	_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	_enemy_flow_field_service = get_tree().get_first_node_in_group("enemy_flow_field_service")
	_enemy_engagement_coordinator = get_tree().get_first_node_in_group("enemy_engagement_coordinator")
	_main_controller = get_tree().get_first_node_in_group("main_controller")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_signal("revision_changed"):
		_pathing_occupancy.connect("revision_changed", Callable(self, "_on_pathing_revision_changed"))
	if nav != null:
		nav.set_physics_process(false)
	if sprite != null and sprite.texture == null:
		var sprite_tex: Texture2D = GAME_SPRITE.get_unit_texture(_resolve_unit_sprite_id())
		if sprite_tex != null:
			sprite.texture = sprite_tex
		else:
			sprite.texture = _make_texture(28, 34, Color(0.86, 0.22, 0.22, 1.0))
	_ensure_unblocked_spawn()
	_last_move_tile = _world_to_tile(global_position)
	_last_move_bucket = _world_to_bucket(global_position)
	_refresh_label()

func get_unit_profile() -> Dictionary:
	return {
		"max_health": 100.0,
		"move_speed": 100.0,
		"base_hit_chance": 0.65,
		"defense": 2.0,
		"melee_attack": 8.0,
		"ranged_attack": 0.0,
		"armor_penetration": 0.5,
		"melee_range": 28.0,
		"ranged_range": 180.0,
		"attack_cooldown_sec": 1.2,
		"structure_attack_damage": 10.0,
		"structure_attack_range": 30.0,
		"ranged_ratio": 0.0
	}

func get_enemy_groups() -> Array[StringName]:
	return []

func get_initial_weapon_mode() -> StringName:
	return &"Melee"

func _register_enemy_groups() -> void:
	for group_name in get_enemy_groups():
		add_to_group(group_name)

func _apply_profile(profile: Dictionary) -> void:
	_base_max_health = float(profile.get("max_health", _base_max_health))
	_base_move_speed = float(profile.get("move_speed", _base_move_speed))
	_base_hit_chance = float(profile.get("base_hit_chance", _base_hit_chance))
	_base_defense = float(profile.get("defense", _base_defense))
	_base_melee_attack = float(profile.get("melee_attack", _base_melee_attack))
	_base_ranged_attack = float(profile.get("ranged_attack", _base_ranged_attack))
	_base_armor_penetration = float(profile.get("armor_penetration", _base_armor_penetration))
	_base_melee_range = float(profile.get("melee_range", _base_melee_range))
	_base_ranged_range = float(profile.get("ranged_range", _base_ranged_range))
	_base_attack_cooldown_sec = float(profile.get("attack_cooldown_sec", _base_attack_cooldown_sec))
	_base_structure_attack_damage = float(profile.get("structure_attack_damage", _base_structure_attack_damage))
	_base_structure_attack_range = float(profile.get("structure_attack_range", _base_structure_attack_range))
	_base_ranged_ratio = float(profile.get("ranged_ratio", _base_ranged_ratio))
	_apply_equipment_profile()
	tile_size = float(profile.get("tile_size", tile_size))

func set_equipment_slots(next_slots: Dictionary) -> void:
	var keys := [&"Top", &"Bottom", &"Hat", &"Weapon"]
	for key in keys:
		equipment_slots[key] = StringName(next_slots.get(key, &""))
	if _profile_ready:
		_apply_equipment_profile()
		_refresh_label()

func get_equipment_snapshot() -> Dictionary:
	return equipment_slots.duplicate(true)

func _apply_equipment_profile() -> void:
	max_health = _base_max_health
	move_speed = _base_move_speed
	base_hit_chance = _base_hit_chance
	defense = _base_defense
	melee_attack = _base_melee_attack
	ranged_attack = _base_ranged_attack
	armor_penetration = _base_armor_penetration
	melee_range = _base_melee_range
	ranged_range = _base_ranged_range
	attack_cooldown_sec = _base_attack_cooldown_sec
	structure_attack_damage = _base_structure_attack_damage
	structure_attack_range = _base_structure_attack_range
	ranged_ratio = _base_ranged_ratio
	var base_profile: Dictionary = {
		"base_hit": base_hit_chance,
		"defense": defense,
		"melee_attack": melee_attack,
		"ranged_attack": ranged_attack,
		"armor_penetration": armor_penetration,
		"melee_range": melee_range,
		"ranged_range": ranged_range,
		"attack_cooldown_sec": attack_cooldown_sec,
		"accuracy_bonus": 0.0,
		"weapon_mode": _default_weapon_mode
	}
	var profile: Dictionary = EQUIPMENT_STATS.apply_equipment_to_profile(base_profile, equipment_slots)
	base_hit_chance = clampf(float(profile.get("base_hit", base_hit_chance)) + float(profile.get("accuracy_bonus", 0.0)), 0.05, 0.98)
	defense = float(profile.get("defense", defense))
	melee_attack = float(profile.get("melee_attack", melee_attack))
	ranged_attack = float(profile.get("ranged_attack", ranged_attack))
	armor_penetration = float(profile.get("armor_penetration", armor_penetration))
	melee_range = float(profile.get("melee_range", melee_range))
	ranged_range = float(profile.get("ranged_range", ranged_range))
	attack_cooldown_sec = float(profile.get("attack_cooldown_sec", attack_cooldown_sec))
	_weapon_mode = StringName(profile.get("weapon_mode", _default_weapon_mode))

func _physics_process(delta: float) -> void:
	_lock_rotation()
	_spawn_unclip_left = maxf(0.0, _spawn_unclip_left - delta)
	_spawn_unclip_retry_left = maxf(0.0, _spawn_unclip_retry_left - delta)
	_sim_accum = minf(_sim_accum + delta, MAX_SIM_ACCUM_SEC)
	var tick_interval: float = _lod_tick_interval()
	if tick_interval > 0.0 and _sim_accum < tick_interval:
		return
	var sim_remaining: float = _sim_accum
	if _enemy_pathing != null:
		_enemy_pathing.tick(sim_remaining)
	var perf_enabled: bool = _enemy_perf_enabled()
	var perf_move_us: int = 0
	var perf_ai_us: int = 0
	var step_count: int = 0
	while sim_remaining > 0.0 and step_count < MAX_SIM_STEPS_PER_PHYSICS:
		var sim_delta: float = minf(sim_remaining, 0.05)
		sim_remaining -= sim_delta
		step_count += 1
		var move_start_us: int = Time.get_ticks_usec() if perf_enabled else 0
		_process_movement(sim_delta)
		if perf_enabled:
			perf_move_us += Time.get_ticks_usec() - move_start_us
		_ai_phase_left = maxf(0.0, _ai_phase_left - sim_delta)
		if _ai_phase_left <= 0.0:
			var ai_start_us: int = Time.get_ticks_usec() if perf_enabled else 0
			_ai_tick(sim_delta)
			if perf_enabled:
				perf_ai_us += Time.get_ticks_usec() - ai_start_us
			_ai_phase_left = _ai_tick_interval()
	_sim_accum = minf(sim_remaining, MAX_SIM_ACCUM_SEC)
	if perf_enabled:
		_record_enemy_perf(perf_move_us, perf_ai_us, step_count)

static func consume_perf_stats() -> Dictionary:
	var out: Dictionary = {
		"units": _perf_units,
		"steps": _perf_steps,
		"move_ms": float(_perf_move_us) / 1000.0,
		"ai_ms": float(_perf_ai_us) / 1000.0
	}
	_perf_units = 0
	_perf_steps = 0
	_perf_move_us = 0
	_perf_ai_us = 0
	return out

static func _enemy_perf_enabled() -> bool:
	if not _perf_env_checked:
		_perf_enabled = OS.get_environment("PERF_LOGS") == "1"
		_perf_env_checked = true
	return _perf_enabled

static func _record_enemy_perf(move_us: int, ai_us: int, steps: int) -> void:
	_perf_units += 1
	_perf_steps += steps
	_perf_move_us += move_us
	_perf_ai_us += ai_us

func _lock_rotation() -> void:
	if absf(rotation) > 0.0001:
		rotation = 0.0

func _ai_tick_interval() -> float:
	return clampf(AI_STEP_SEC * _sim_interval_scale, AI_STEP_SEC, 0.25)

func _lod_tick_interval() -> float:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_lod_refresh_ms:
		return _cached_lod_interval
	_next_lod_refresh_ms = now_ms + int(round(LOD_REFRESH_SEC * 1000.0))
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		_cached_lod_interval = 0.0
		return _cached_lod_interval
	var base_interval: float = UPDATE_NEAR_INTERVAL_SEC if global_position.distance_squared_to(cam.global_position) <= UPDATE_NEAR_RADIUS * UPDATE_NEAR_RADIUS else UPDATE_FAR_INTERVAL_SEC
	_cached_lod_interval = base_interval * _sim_interval_scale
	return _cached_lod_interval

func _on_pathing_revision_changed(revision: int) -> void:
	if _enemy_pathing == null:
		return
	_enemy_pathing.notify_obstacle_signature(revision)

func set_tile_size(value: float) -> void:
	tile_size = maxf(4.0, value)
	if _enemy_pathing != null:
		_enemy_pathing.setup(tile_size)

func set_external_move_speed_multiplier(value: float) -> void:
	external_move_speed_multiplier = clampf(value, 0.5, 1.6)

func set_external_accuracy_bonus(value: float) -> void:
	external_accuracy_bonus = clampf(value, -0.2, 0.2)

func set_sim_interval_scale(value: float) -> void:
	_sim_interval_scale = clampf(value, 1.0, 2.5)
	if _enemy_pathing != null and _enemy_pathing.has_method("set_budget_scale"):
		_enemy_pathing.set_budget_scale(_sim_interval_scale)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / tile_size) * tile_size,
		round(world_pos.y / tile_size) * tile_size
	)

func _anchor_to_cell(world_pos: Vector2) -> bool:
	var snapped: Vector2 = _snap_to_tile(world_pos)
	if _snap_to_tile(global_position).distance_to(snapped) > 0.1 and _is_blocked_position(snapped):
		return false
	if _is_move_segment_blocked(global_position, snapped):
		return false
	if global_position.distance_to(snapped) <= CELL_CENTER_EPSILON:
		global_position = snapped
		return false
	global_position = snapped
	_emit_moved_if_needed()
	return true

func _move_toward_cell(world_pos: Vector2, speed: float, delta: float) -> bool:
	var snapped: Vector2 = _snap_to_tile(world_pos)
	if _snap_to_tile(global_position).distance_to(snapped) > 0.1 and _is_blocked_position(snapped):
		return false
	var to_center: Vector2 = snapped - global_position
	var dist: float = to_center.length()
	if dist <= CELL_CENTER_EPSILON:
		global_position = snapped
		_emit_moved_if_needed()
		return true
	var step_len: float = minf(dist, maxf(1.0, speed) * minf(delta, 0.05))
	var next_pos: Vector2 = global_position + to_center.normalized() * step_len
	if _is_move_segment_blocked(global_position, next_pos):
		return false
	global_position = snapped if step_len >= dist else next_pos
	_emit_moved_if_needed()
	return global_position.distance_to(snapped) <= CELL_CENTER_EPSILON

func get_combat_defender_profile() -> Dictionary:
	return _get_combat_defender_profile()

func _get_combat_defender_profile() -> Dictionary:
	return {"defense": float(defense)}

func is_dead() -> bool:
	return health <= 0.0

func apply_combat_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	health = maxf(0.0, health - float(amount))
	_refresh_label()
	if health <= 0.0:
		died.emit(self)
		queue_free()

func _ai_tick(_delta: float) -> void:
	if is_dead():
		return
	if _try_process_melee_combat_lock():
		return
	_target_refresh_left = maxf(0.0, _target_refresh_left - _delta)
	var target: Node2D = null
	if _target_refresh_left <= 0.0:
		target = _resolve_target()
		_target_refresh_left = TARGET_REFRESH_SEC
	else:
		var explicit: Object = instance_from_id(_target_colonist_id) if _target_colonist_id != 0 else null
		if explicit != null and is_instance_valid(explicit) and explicit is Node2D:
			target = explicit
		else:
			target = _resolve_target()
			_target_refresh_left = TARGET_REFRESH_SEC
	if target == null:
		_target_colonist_id = 0
		_clear_melee_goal_cache()
		_try_attack_structure()
		var structure_target: Node2D = _resolve_structure_target()
		if structure_target != null:
			_move_goal = _snap_to_tile(structure_target.global_position)
			_move_goal_exact = false
		else:
			_move_goal = Vector2.INF
			_move_goal_exact = false
		return
	var previous_target_id: int = _target_colonist_id
	_target_colonist_id = target.get_instance_id()
	var attack_mode: StringName = get_current_weapon_mode()
	if attack_mode == &"Ranged":
		_clear_melee_goal_cache()
		if previous_target_id != _target_colonist_id:
			_invalidate_dynamic_combat_blockers()
	elif previous_target_id != _target_colonist_id:
		_clear_melee_goal_cache()
	var attack_range: float = _resolve_attack_range(attack_mode)
	var dist: float = global_position.distance_to(target.global_position)
	if attack_mode != &"Ranged":
		if not _should_resolve_melee_slot(target, attack_range):
			_clear_melee_goal_cache()
			_move_goal = _snap_to_tile(target.global_position)
			_move_goal_exact = false
			return
		var melee_goal: Vector2 = _resolve_melee_engagement_goal(target, attack_range)
		var melee_engaged: bool = _is_melee_engaged_with_target(target, attack_range, melee_goal)
		if not melee_engaged and not _is_melee_cell_available(_snap_to_tile(global_position)) and _is_melee_cell_available(melee_goal):
			if _can_step_toward_melee_cell(melee_goal):
				_move_toward_cell(melee_goal, move_speed * maxf(0.5, external_move_speed_multiplier), _delta)
			else:
				_move_toward_cell(_snap_to_tile(global_position), move_speed * maxf(0.5, external_move_speed_multiplier), _delta)
			dist = global_position.distance_to(target.global_position)
			melee_engaged = _is_melee_engaged_with_target(target, attack_range, melee_goal)
		if not melee_engaged and _snap_to_tile(global_position).distance_to(_snap_to_tile(target.global_position)) <= 0.1 and not _is_blocked_position(melee_goal):
			if _can_step_toward_melee_cell(melee_goal):
				_move_toward_cell(melee_goal, move_speed * maxf(0.5, external_move_speed_multiplier), _delta)
			else:
				_move_toward_cell(_snap_to_tile(global_position), move_speed * maxf(0.5, external_move_speed_multiplier), _delta)
			dist = global_position.distance_to(target.global_position)
			melee_engaged = _is_melee_engaged_with_target(target, attack_range, melee_goal)
		var local_positioning: bool = dist <= maxf(tile_size * (float(_melee_allowed_ring(target.get_instance_id())) + 2.4), attack_range + tile_size * 2.4)
		if not melee_engaged:
			_move_goal = melee_goal if local_positioning else _snap_to_tile(melee_goal)
			_move_goal_exact = local_positioning
			return
		else:
			_move_goal = global_position
			_move_goal_exact = false
		if _melee_lock_target_id == 0 and _can_start_melee_combat_lock(target, attack_range, melee_goal):
			_start_melee_combat_lock(target)
	elif dist > attack_range:
		_move_goal = _snap_to_tile(target.global_position)
		_move_goal_exact = false
		return
	if attack_mode == &"Ranged" and not bool(COMBAT_LOS.has_ranged_line_of_sight(get_tree(), global_position, target.global_position)):
		_move_goal = _snap_to_tile(target.global_position)
		_move_goal_exact = false
		return
	if attack_mode == &"Ranged":
		_move_goal = global_position
		_move_goal_exact = false
	_try_attack_target(target, attack_mode, attack_range, dist)

func _should_resolve_melee_slot(target: Node2D, attack_range: float) -> bool:
	var target_cell: Vector2 = _snap_to_tile(target.global_position)
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var resolve_distance: float = maxf(tile_size * MELEE_SLOT_RESOLVE_DISTANCE_TILES, attack_range + tile_size * 4.0)
	return own_cell.distance_to(target_cell) <= resolve_distance

func _try_process_melee_combat_lock() -> bool:
	if _melee_lock_target_id == 0:
		return false
	if get_current_weapon_mode() == &"Ranged":
		_clear_melee_combat_lock()
		return false
	var target_obj: Object = instance_from_id(_melee_lock_target_id)
	if target_obj == null or not is_instance_valid(target_obj) or not (target_obj is Node2D):
		_clear_melee_combat_lock()
		_target_colonist_id = 0
		_target_refresh_left = 0.0
		return false
	if target_obj.has_method("is_dead") and bool(target_obj.is_dead()):
		_clear_melee_combat_lock()
		_target_colonist_id = 0
		_target_refresh_left = 0.0
		return false
	var target: Node2D = target_obj as Node2D
	_target_colonist_id = _melee_lock_target_id
	_move_goal = global_position
	_move_goal_exact = false
	var attack_mode: StringName = &"Melee"
	var attack_range: float = _resolve_attack_range(attack_mode)
	if not _is_melee_engaged_with_target(target, attack_range):
		return true
	var dist: float = global_position.distance_to(target.global_position)
	_try_attack_target(target, attack_mode, attack_range, minf(dist, attack_range))
	return true

func _start_melee_combat_lock(target: Node2D) -> void:
	_melee_lock_target_id = target.get_instance_id()
	_target_colonist_id = _melee_lock_target_id
	_move_goal = global_position
	_move_goal_exact = false
	if _enemy_pathing != null:
		_enemy_pathing.clear()
	_invalidate_dynamic_combat_blockers()

func _can_start_melee_combat_lock(target: Node2D, attack_range: float, desired: Vector2 = Vector2.INF) -> bool:
	return _is_melee_engaged_with_target(target, attack_range, desired)

func _is_melee_engaged_with_target(target: Node2D, attack_range: float, desired: Vector2 = Vector2.INF) -> bool:
	var target_cell: Vector2 = _snap_to_tile(target.global_position)
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var own_ring: int = _melee_cell_ring(own_cell, target_cell)
	if own_ring >= 1 \
		and own_ring <= _melee_engagement_ring(target.get_instance_id(), attack_range) \
		and _melee_cell_in_weapon_range(own_cell, target_cell, attack_range) \
		and _is_melee_cell_available(own_cell) \
		and global_position.distance_to(own_cell) <= CELL_CENTER_EPSILON:
		global_position = own_cell
		_emit_moved_if_needed()
		return true
	if desired == Vector2.INF:
		desired = _resolve_melee_engagement_goal(target, attack_range)
	var engagement_ring: int = _melee_engagement_ring(target.get_instance_id(), attack_range)
	var desired_ring: int = _melee_cell_ring(desired, target_cell)
	if desired_ring >= 1 and desired_ring <= engagement_ring and _melee_cell_in_weapon_range(desired, target_cell, attack_range) and global_position.distance_to(desired) <= CELL_CENTER_EPSILON:
		global_position = desired
		_emit_moved_if_needed()
		return true
	return false

func _melee_cell_ring(cell: Vector2, target_cell: Vector2) -> int:
	if cell == Vector2.INF:
		return MELEE_SLOT_MAX_RING + 1
	var cell_dx: int = absi(int(round((cell.x - target_cell.x) / tile_size)))
	var cell_dy: int = absi(int(round((cell.y - target_cell.y) / tile_size)))
	return maxi(cell_dx, cell_dy)

func _melee_required_ring(target_id: int) -> int:
	var attacker_count: int = _get_melee_attacker_ids_for_target(target_id).size()
	for ring in range(1, MELEE_SLOT_MAX_RING + 1):
		if attacker_count <= 4 * ring * (ring + 1):
			return ring
	return MELEE_SLOT_MAX_RING

func _get_melee_attacker_ids_for_target(target_id: int) -> Array[int]:
	if target_id == 0:
		return []
	var frame_id: int = Engine.get_physics_frames()
	if _melee_attacker_cache_frame != frame_id:
		_melee_attacker_cache_frame = frame_id
		_melee_attacker_ids_by_target.clear()
	if _melee_attacker_ids_by_target.has(target_id):
		return _melee_attacker_ids_by_target[target_id]
	var attacker_ids: Array[int] = []
	var enemies: Array = get_tree().get_nodes_in_group("raiders")
	enemies.append_array(get_tree().get_nodes_in_group("zombies"))
	for node in enemies:
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		if node.has_method("get_current_weapon_mode") and StringName(node.get_current_weapon_mode()) == &"Ranged":
			continue
		var node_target_id: int = int(node.get("_melee_lock_target_id"))
		if node_target_id == 0:
			node_target_id = int(node.get("_target_colonist_id"))
		if node_target_id == target_id:
			attacker_ids.append(node.get_instance_id())
	attacker_ids.sort()
	_melee_attacker_ids_by_target[target_id] = attacker_ids
	return attacker_ids

func _melee_allowed_ring(target_id: int) -> int:
	var required: int = _melee_required_ring(target_id)
	return mini(MELEE_SLOT_MAX_RING, required + 1)

func _melee_engagement_ring(_target_id: int, attack_range: float) -> int:
	return clampi(int(ceil(maxf(1.0, attack_range) / tile_size)), 1, MELEE_SLOT_MAX_RING)

func _melee_cell_in_weapon_range(cell: Vector2, target_cell: Vector2, attack_range: float) -> bool:
	if cell == Vector2.INF:
		return false
	var ring: int = _melee_cell_ring(cell, target_cell)
	return ring >= 1 and ring <= _melee_engagement_ring(0, attack_range)

func is_melee_combat_locked() -> bool:
	return _melee_lock_target_id != 0

func release_melee_lock_if_target(target_id: int) -> void:
	if _melee_lock_target_id != target_id:
		return
	_clear_melee_combat_lock()
	_target_colonist_id = 0
	_target_refresh_left = 0.0
	if _enemy_pathing != null:
		_enemy_pathing.clear()

func _clear_melee_combat_lock() -> void:
	var had_lock: bool = _melee_lock_target_id != 0
	_melee_lock_target_id = 0
	_clear_melee_goal_cache()
	if had_lock:
		_invalidate_dynamic_combat_blockers()

func _try_attack_target(target: Node2D, attack_mode: StringName, attack_range: float, dist: float) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_attack_ms:
		return
	if attack_mode == &"Ranged" and not bool(COMBAT_LOS.has_ranged_line_of_sight(get_tree(), global_position, target.global_position)):
		return
	var attack_power: float = _resolve_attack_power(attack_mode)
	var attacker: Dictionary = {
		"attack_power": attack_power,
		"armor_penetration": armor_penetration,
		"base_hit": base_hit_chance,
		"accuracy_bonus": external_accuracy_bonus,
		"attack_range": attack_range
	}
	var defender: Dictionary = {"defense": 0.0}
	if target.has_method("get_combat_defender_profile"):
		defender = target.get_combat_defender_profile()
	var result: Dictionary = COMBAT_MATH.resolve_attack(attacker, defender, dist)
	var hit: bool = bool(result.get("hit", false))
	var damage: int = maxi(0, int(result.get("damage", 0)))
	if hit and target.has_method("apply_combat_damage"):
		target.apply_combat_damage(damage)
	var killed: bool = false
	if hit and target.has_method("is_dead"):
		killed = bool(target.is_dead())
	_report_combat_event(hit, damage, killed, attack_mode)
	_next_attack_ms = now_ms + int(round(1000.0 * maxf(0.1, attack_cooldown_sec)))
	if killed:
		_clear_melee_combat_lock()
		_target_colonist_id = 0

func get_current_weapon_mode() -> StringName:
	return _weapon_mode

func _resolve_attack_range(attack_mode: StringName) -> float:
	if attack_mode == &"Ranged":
		return maxf(12.0, ranged_range)
	return maxf(12.0, melee_range)

func _resolve_attack_power(attack_mode: StringName) -> float:
	if attack_mode == &"Ranged":
		return maxf(1.0, ranged_attack)
	return maxf(1.0, melee_attack)

func _resolve_target() -> Node2D:
	var explicit: Object = instance_from_id(_target_colonist_id) if _target_colonist_id != 0 else null
	if explicit != null and is_instance_valid(explicit) and explicit is Node2D:
		if explicit.has_method("is_dead") and bool(explicit.is_dead()):
			_target_colonist_id = 0
		else:
			return explicit
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= _grp_colonists_ms:
		_grp_colonists = get_tree().get_nodes_in_group("colonists")
		_grp_colonists_ms = now_ms + 300
	var best_target: Node2D = null
	var best_dist_sq: float = INF
	for node in _grp_colonists:
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		var dist_sq: float = global_position.distance_squared_to(node.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = node
	return best_target

func _resolve_structure_target() -> Node2D:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= _grp_structures_ms:
		_grp_structures = get_tree().get_nodes_in_group("structures")
		_grp_structures_ms = now_ms + 500
	var best_target: Node2D = null
	var best_dist_sq: float = INF
	for node in _grp_structures:
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		var dist_sq: float = global_position.distance_squared_to((node as Node2D).global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_target = node as Node2D
	return best_target

func _process_movement(delta: float) -> void:
	if _melee_lock_target_id != 0:
		return
	var goal: Vector2 = _move_goal if _move_goal_exact else _snap_to_tile(_move_goal)
	if goal == Vector2.INF:
		if _enemy_pathing != null:
			_enemy_pathing.clear()
		return
	var speed: float = move_speed * maxf(0.5, external_move_speed_multiplier)
	if global_position.distance_to(goal) <= 24.0:
		var before_center_step: Vector2 = global_position
		var reached_center: bool = _move_toward_cell(goal, speed, delta)
		if reached_center and _enemy_pathing != null:
			_enemy_pathing.clear()
			return
		if global_position.distance_squared_to(before_center_step) > 0.0001:
			return
	if _move_goal_exact and _try_process_exact_combat_positioning(goal, speed, minf(delta, 0.05)):
		return
	var result: Dictionary = {}
	var flow_direction_missing: bool = false
	var flow_navigation_deferred: bool = false
	if _enemy_flow_field_service == null or not is_instance_valid(_enemy_flow_field_service):
		_enemy_flow_field_service = get_tree().get_first_node_in_group("enemy_flow_field_service")
	if _enemy_flow_field_service != null and is_instance_valid(_enemy_flow_field_service) and _enemy_flow_field_service.has_method("get_flow_direction"):
		var flow_dir: Vector2 = _enemy_flow_field_service.get_flow_direction(global_position, goal, get_instance_id())
		if flow_dir != Vector2.ZERO:
			var flow_delta: float = minf(delta, 0.05)
			var flow_pos: Vector2 = global_position + flow_dir * speed * flow_delta
			if not _is_blocked_position(flow_pos) and not _is_move_segment_blocked(global_position, flow_pos):
				result = {"position": flow_pos, "reached_goal": false, "blocked": false}
		else:
			flow_direction_missing = true
			if _enemy_flow_field_service.has_method("is_navigation_deferred"):
				flow_navigation_deferred = bool(_enemy_flow_field_service.is_navigation_deferred(goal))
	if flow_navigation_deferred and Time.get_ticks_msec() < _post_breach_flow_defer_until_ms:
		_try_attack_structure(goal)
		return
	if result.is_empty() and _enemy_pathing != null:
		result = _enemy_pathing.move_step(
			global_position,
			goal,
			speed,
			delta,
			_is_blocked_callable
		)
	if bool(result.get("reached_goal", false)):
		_anchor_to_cell(goal)
		return
	if flow_direction_missing and _try_attack_structure(goal):
		return
	if bool(result.get("blocked", false)):
		if _spawn_unclip_left > 0.0 and _spawn_unclip_retry_left <= 0.0 and _is_blocked_position(global_position):
			_spawn_unclip_retry_left = 0.35
			var unstuck_pos: Vector2 = _find_quick_unblocked_position(global_position)
			if unstuck_pos != Vector2.INF:
				global_position = unstuck_pos
				if _enemy_pathing != null:
					_enemy_pathing.clear()
				return
			if _force_nudge_toward_goal(goal, delta):
				if _enemy_pathing != null:
					_enemy_pathing.clear()
				return
		_try_attack_structure(goal)
		return
	var current: Vector2 = global_position
	var next_pos: Vector2 = result.get("position", current)
	if next_pos.distance_to(goal) <= CELL_CENTER_EPSILON:
		next_pos = _snap_to_tile(goal)
	if next_pos.distance_squared_to(current) <= 0.0001:
		var fallback_dir: Vector2 = current.direction_to(goal)
		if fallback_dir != Vector2.ZERO:
			var fallback_step: Vector2 = current + fallback_dir * speed * minf(delta, 0.05)
			if not _is_blocked_position(fallback_step) and not _is_move_segment_blocked(current, fallback_step):
				next_pos = fallback_step
			elif _try_attack_structure(goal):
				return
	if _is_blocked_position(next_pos) or _is_move_segment_blocked(current, next_pos):
		if _enemy_pathing != null:
			_enemy_pathing.clear()
		_try_attack_structure(goal)
		return
	global_position = next_pos
	_emit_moved_if_needed()

func _try_process_exact_combat_positioning(goal: Vector2, speed: float, delta: float) -> bool:
	if goal == Vector2.INF:
		return false
	var to_goal: Vector2 = goal - global_position
	var steer: Vector2 = to_goal.normalized() if to_goal.length() > 0.001 else Vector2.ZERO
	if steer == Vector2.ZERO:
		return true
	var step_goal_len: float = maxf(0.0, to_goal.length())
	var step_len: float = minf(step_goal_len, speed * delta)
	if to_goal.length() <= tile_size or _snap_to_tile(global_position).distance_to(_snap_to_tile(goal)) <= 0.1:
		if not _can_step_toward_melee_cell(goal):
			_move_toward_cell(_snap_to_tile(global_position), speed, delta)
			return true
		_move_toward_cell(goal, speed, delta)
		return true
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var step_cell: Vector2 = _next_melee_step_cell_toward(goal, own_cell)
	if step_cell.distance_to(own_cell) > 0.1 and not _can_step_toward_melee_cell(step_cell):
		return false
	var next_pos: Vector2 = global_position + steer * step_len
	if next_pos.distance_to(goal) <= CELL_CENTER_EPSILON:
		next_pos = _snap_to_tile(goal)
	if not _can_step_toward_melee_cell(next_pos):
		return false
	if _is_blocked_position(next_pos) or _is_move_segment_blocked(global_position, next_pos):
		return false
	global_position = next_pos
	_emit_moved_if_needed()
	return true

func _next_melee_step_cell_toward(desired: Vector2, own_cell: Vector2) -> Vector2:
	var desired_cell: Vector2 = _snap_to_tile(desired)
	var step_x: float = 0.0
	var step_y: float = 0.0
	if desired_cell.x > own_cell.x + 0.1:
		step_x = tile_size
	elif desired_cell.x < own_cell.x - 0.1:
		step_x = -tile_size
	if desired_cell.y > own_cell.y + 0.1:
		step_y = tile_size
	elif desired_cell.y < own_cell.y - 0.1:
		step_y = -tile_size
	return _snap_to_tile(own_cell + Vector2(step_x, step_y))

func _is_melee_goal_step_available(desired: Vector2, own_cell: Vector2) -> bool:
	var step_cell: Vector2 = _next_melee_step_cell_toward(desired, own_cell)
	return step_cell.distance_to(own_cell) <= 0.1 or _is_melee_cell_available(step_cell)

func _should_require_melee_step_available(own_cell: Vector2, target_cell: Vector2, allowed_ring: int) -> bool:
	var own_ring: int = _melee_cell_ring(own_cell, target_cell)
	return own_ring <= allowed_ring + 2

func _can_step_toward_melee_cell(next_pos: Vector2) -> bool:
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var next_cell: Vector2 = _snap_to_tile(next_pos)
	if next_cell.distance_to(own_cell) <= 0.1:
		return true
	if not _is_melee_cell_available(next_cell):
		return false
	_melee_step_claim_cell = next_cell
	_melee_step_claim_next_ms = Time.get_ticks_msec() + 120
	_register_melee_claim_for_current_frame(next_cell)
	return true

func _get_enemy_engagement_coordinator() -> Node:
	if _enemy_engagement_coordinator == null or not is_instance_valid(_enemy_engagement_coordinator):
		_enemy_engagement_coordinator = get_tree().get_first_node_in_group("enemy_engagement_coordinator")
	return _enemy_engagement_coordinator

func _get_current_target_node() -> Node2D:
	var explicit: Object = instance_from_id(_target_colonist_id) if _target_colonist_id != 0 else null
	if explicit != null and is_instance_valid(explicit) and explicit is Node2D:
		return explicit as Node2D
	return null

func _invalidate_dynamic_combat_blockers() -> void:
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("invalidate_dynamic_combat_blockers"):
		_pathing_occupancy.invalidate_dynamic_combat_blockers()

func _resolve_melee_engagement_goal(target: Node2D, attack_range: float) -> Vector2:
	var cached_staging_goal: Vector2 = _try_reuse_cached_staging_goal(target, attack_range)
	if cached_staging_goal != Vector2.INF:
		return cached_staging_goal
	var coordinator: Node = _get_enemy_engagement_coordinator()
	if coordinator != null and is_instance_valid(coordinator) and coordinator.has_method("request_melee_goal"):
		var coordinated_goal: Vector2 = coordinator.request_melee_goal(self, target, attack_range)
		if coordinated_goal != Vector2.INF:
			_cache_melee_goal(target.get_instance_id(), coordinated_goal)
			return coordinated_goal
	var target_id: int = target.get_instance_id()
	var target_cell: Vector2 = _snap_to_tile(target.global_position)
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var own_dx: int = absi(int(round((own_cell.x - target_cell.x) / tile_size)))
	var own_dy: int = absi(int(round((own_cell.y - target_cell.y) / tile_size)))
	var own_ring: int = maxi(own_dx, own_dy)
	var engagement_ring: int = _melee_engagement_ring(target_id, attack_range)
	var allowed_ring: int = maxi(_melee_allowed_ring(target_id), engagement_ring)
	var require_step_available: bool = _should_require_melee_step_available(own_cell, target_cell, allowed_ring)
	if own_ring >= 1 and own_ring <= engagement_ring and _melee_cell_in_weapon_range(own_cell, target_cell, attack_range) and _is_melee_cell_available(own_cell):
		_cache_melee_goal(target_id, own_cell)
		return own_cell
	var now_ms: int = Time.get_ticks_msec()
	if _melee_goal_cache_target_id == target_id and _melee_goal_cache_cell != Vector2.INF and now_ms < _melee_goal_cache_next_ms:
		var cached_cell: Vector2 = _melee_goal_cache_cell
		var cached_dx: int = absi(int(round((cached_cell.x - target_cell.x) / tile_size)))
		var cached_dy: int = absi(int(round((cached_cell.y - target_cell.y) / tile_size)))
		var cached_ring: int = maxi(cached_dx, cached_dy)
		if cached_ring >= 1 and cached_ring <= engagement_ring and _melee_cell_in_weapon_range(cached_cell, target_cell, attack_range) and (not require_step_available or _is_melee_goal_step_available(cached_cell, own_cell)) and _is_melee_cell_available(cached_cell):
			_cache_melee_goal(target_id, cached_cell)
			return cached_cell
		if cached_ring >= 1 and cached_ring <= allowed_ring and (not require_step_available or _is_melee_goal_step_available(cached_cell, own_cell)) and _is_melee_cell_available(cached_cell):
			_cache_melee_goal(target_id, cached_cell)
			return cached_cell
	var slots: Array[Vector2] = _order_melee_slots_by_distance(_build_melee_slot_cells(target_cell, allowed_ring))
	var start_idx: int = _melee_slot_index(target_id, slots.size())
	for offset in range(slots.size()):
		var idx: int = (start_idx + offset) % slots.size()
		var candidate: Vector2 = slots[idx]
		var candidate_dx: int = absi(int(round((candidate.x - target_cell.x) / tile_size)))
		var candidate_dy: int = absi(int(round((candidate.y - target_cell.y) / tile_size)))
		if maxi(candidate_dx, candidate_dy) > engagement_ring:
			continue
		if not _melee_cell_in_weapon_range(candidate, target_cell, attack_range):
			continue
		if (not require_step_available or _is_melee_goal_step_available(candidate, own_cell)) and _is_melee_cell_available(candidate):
			_cache_melee_goal(target_id, candidate)
			return candidate
	if own_ring >= 1 and own_ring <= allowed_ring and _is_melee_cell_available(own_cell):
		_cache_melee_goal(target_id, own_cell)
		return own_cell
	for offset in range(slots.size()):
		var idx: int = (start_idx + offset) % slots.size()
		var candidate: Vector2 = slots[idx]
		var candidate_dx: int = absi(int(round((candidate.x - target_cell.x) / tile_size)))
		var candidate_dy: int = absi(int(round((candidate.y - target_cell.y) / tile_size)))
		if maxi(candidate_dx, candidate_dy) > allowed_ring:
			continue
		if (not require_step_available or _is_melee_goal_step_available(candidate, own_cell)) and _is_melee_cell_available(candidate):
			_cache_melee_goal(target_id, candidate)
			return candidate
	var fallback: Vector2 = own_cell
	for candidate in slots:
		var candidate_dx: int = absi(int(round((candidate.x - target_cell.x) / tile_size)))
		var candidate_dy: int = absi(int(round((candidate.y - target_cell.y) / tile_size)))
		if maxi(candidate_dx, candidate_dy) <= engagement_ring:
			if not _melee_cell_in_weapon_range(candidate, target_cell, attack_range):
				continue
			fallback = candidate
			break
	for candidate in slots:
		var candidate_dx: int = absi(int(round((candidate.x - target_cell.x) / tile_size)))
		var candidate_dy: int = absi(int(round((candidate.y - target_cell.y) / tile_size)))
		if maxi(candidate_dx, candidate_dy) <= allowed_ring:
			fallback = candidate
			break
	_cache_melee_goal(target_id, fallback)
	return fallback

func _try_reuse_cached_staging_goal(target: Node2D, attack_range: float) -> Vector2:
	var target_id: int = target.get_instance_id()
	if _melee_goal_cache_target_id != target_id:
		return Vector2.INF
	if _melee_goal_cache_cell == Vector2.INF or Time.get_ticks_msec() >= _melee_goal_cache_next_ms:
		return Vector2.INF
	var target_cell: Vector2 = _snap_to_tile(target.global_position)
	var own_cell: Vector2 = _snap_to_tile(global_position)
	var engagement_ring: int = _melee_engagement_ring(target_id, attack_range)
	var own_ring: int = _melee_cell_ring(own_cell, target_cell)
	if own_ring <= engagement_ring + 2:
		return Vector2.INF
	var cached_ring: int = _melee_cell_ring(_melee_goal_cache_cell, target_cell)
	if cached_ring <= engagement_ring + 1 or cached_ring > MELEE_SLOT_MAX_RING:
		return Vector2.INF
	if not _is_melee_cell_available(_melee_goal_cache_cell):
		return Vector2.INF
	_cache_melee_goal(target_id, _melee_goal_cache_cell)
	return _melee_goal_cache_cell

func _cache_melee_goal(target_id: int, cell: Vector2) -> void:
	_melee_goal_cache_target_id = target_id
	_melee_goal_cache_cell = _snap_to_tile(cell)
	_melee_goal_cache_next_ms = Time.get_ticks_msec() + MELEE_GOAL_CACHE_MS
	_register_melee_claim_for_current_frame(_melee_goal_cache_cell)

func _clear_melee_goal_cache() -> void:
	_melee_goal_cache_target_id = 0
	_melee_goal_cache_cell = Vector2.INF
	_melee_goal_cache_next_ms = 0
	_melee_step_claim_cell = Vector2.INF
	_melee_step_claim_next_ms = 0

func _order_melee_slots_by_distance(slots: Array[Vector2]) -> Array[Vector2]:
	var ordered: Array[Vector2] = slots.duplicate()
	ordered.sort_custom(Callable(self, "_compare_melee_slot_distance"))
	return ordered

func _compare_melee_slot_distance(a: Vector2, b: Vector2) -> bool:
	var dist_a: float = global_position.distance_squared_to(a)
	var dist_b: float = global_position.distance_squared_to(b)
	if not is_equal_approx(dist_a, dist_b):
		return dist_a < dist_b
	if not is_equal_approx(a.y, b.y):
		return a.y < b.y
	return a.x < b.x

func _build_melee_slot_cells(target_cell: Vector2, max_ring: int = MELEE_SLOT_MAX_RING) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	var capped_ring: int = clampi(max_ring, 1, MELEE_SLOT_MAX_RING)
	for ring in range(1, capped_ring + 1):
		for y in range(-ring, ring + 1):
			for x in range(-ring, ring + 1):
				if maxi(absi(x), absi(y)) != ring:
					continue
				slots.append(_snap_to_tile(target_cell + Vector2(float(x) * tile_size, float(y) * tile_size)))
	return slots

func _is_melee_cell_available(cell: Vector2) -> bool:
	var snapped: Vector2 = _snap_to_tile(cell)
	var coordinator: Node = _get_enemy_engagement_coordinator()
	if coordinator != null and is_instance_valid(coordinator) and coordinator.has_method("is_melee_cell_available"):
		return bool(coordinator.is_melee_cell_available(self, snapped))
	if _is_blocked_position(snapped):
		return false
	var self_on_cell: bool = _snap_to_tile(global_position).distance_to(snapped) <= 0.1
	var now_ms: int = Time.get_ticks_msec()
	_refresh_melee_cell_cache(now_ms)
	var key: int = _melee_cell_key(snapped)
	var occupied_ids: Array = _melee_occupied_ids_by_cell.get(key, [])
	for id_any in occupied_ids:
		if int(id_any) != get_instance_id():
			return false
	if not self_on_cell:
		var claim_ids: Array = _melee_claim_ids_by_cell.get(key, [])
		for id_any in claim_ids:
			if int(id_any) != get_instance_id():
				return false
	return true

func _refresh_melee_cell_cache(now_ms: int) -> void:
	var frame_id: int = Engine.get_physics_frames()
	if _melee_cell_cache_frame == frame_id:
		return
	_melee_cell_cache_frame = frame_id
	_melee_occupied_ids_by_cell.clear()
	_melee_claim_ids_by_cell.clear()
	var groups: Array[StringName] = [&"colonists", &"raiders", &"zombies"]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node):
				continue
			if not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			var node_id: int = node.get_instance_id()
			_add_id_to_melee_cell_cache(_melee_occupied_ids_by_cell, (node as Node2D).global_position, node_id)
			_add_node_melee_claims_to_cache(node, node_id, now_ms)

func _add_node_melee_claims_to_cache(node: Node, node_id: int, now_ms: int) -> void:
	if not _node_has_active_melee_goal(node):
		return
	var step_next_ms: int = _get_node_int(node, "_melee_step_claim_next_ms")
	if step_next_ms > now_ms:
		var step_cell_variant: Variant = node.get("_melee_step_claim_cell")
		if step_cell_variant is Vector2:
			_add_id_to_melee_cell_cache(_melee_claim_ids_by_cell, step_cell_variant, node_id)
	var cache_next_ms: int = _get_node_int(node, "_melee_goal_cache_next_ms")
	if cache_next_ms <= now_ms:
		return
	var cache_target_id: int = _get_node_int(node, "_melee_goal_cache_target_id")
	if cache_target_id == 0:
		return
	var cache_cell_variant: Variant = node.get("_melee_goal_cache_cell")
	if cache_cell_variant is Vector2:
		_add_id_to_melee_cell_cache(_melee_claim_ids_by_cell, cache_cell_variant, node_id)

func _register_melee_claim_for_current_frame(cell: Vector2) -> void:
	var coordinator: Node = _get_enemy_engagement_coordinator()
	if coordinator != null and is_instance_valid(coordinator) and coordinator.has_method("register_melee_claim"):
		coordinator.register_melee_claim(self, cell)
	if _melee_cell_cache_frame != Engine.get_physics_frames():
		return
	_add_id_to_melee_cell_cache(_melee_claim_ids_by_cell, cell, get_instance_id())

func _add_id_to_melee_cell_cache(cache: Dictionary, cell: Vector2, node_id: int) -> void:
	var key: int = _melee_cell_key(cell)
	var ids: Array = cache.get(key, [])
	if ids.find(node_id) < 0:
		ids.append(node_id)
	cache[key] = ids

func _melee_cell_key(world_pos: Vector2) -> int:
	var tile: Vector2i = _world_to_tile(world_pos)
	var packed_x: int = (tile.x + 32768) & 0xFFFF
	var packed_y: int = (tile.y + 32768) & 0xFFFF
	return (packed_x << 16) | packed_y

func _node_has_active_melee_goal(node: Node) -> bool:
	var job_variant: Variant = node.get("current_job")
	if job_variant is Dictionary:
		var job: Dictionary = job_variant
		if StringName(job.get("type", &"")) == &"CombatMelee":
			return true
	var lock_id: int = _get_node_int(node, "_melee_lock_target_id")
	if lock_id != 0:
		return true
	var target_id: int = _get_node_int(node, "_target_colonist_id")
	if target_id == 0:
		return false
	if node.has_method("get_current_weapon_mode"):
		return StringName(node.get_current_weapon_mode()) != &"Ranged"
	return true

func _get_node_int(node: Node, property_name: StringName, fallback: int = 0) -> int:
	var value: Variant = node.get(property_name)
	if value == null:
		return fallback
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	return fallback

func _melee_slot_index(target_id: int, slot_count: int) -> int:
	var attacker_ids: Array[int] = _get_melee_attacker_ids_for_target(target_id)
	var self_id: int = get_instance_id()
	var found: int = attacker_ids.find(self_id)
	if found >= 0:
		return found % maxi(1, slot_count)
	return absi(self_id + target_id) % maxi(1, slot_count)

func _ensure_unblocked_spawn() -> void:
	var snapped: Vector2 = _snap_to_tile(global_position)
	if not _is_blocked_position(snapped):
		global_position = snapped
		return
	var quick: Vector2 = _find_quick_unblocked_position(snapped)
	if quick != Vector2.INF:
		global_position = quick

func _find_quick_unblocked_position(origin: Vector2) -> Vector2:
	var snapped_origin: Vector2 = _snap_to_tile(origin)
	if not _is_blocked_position(snapped_origin):
		return snapped_origin
	var dirs: Array[Vector2] = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
		Vector2(1.0, 1.0).normalized(), Vector2(1.0, -1.0).normalized(),
		Vector2(-1.0, 1.0).normalized(), Vector2(-1.0, -1.0).normalized()
	]
	for ring in range(1, 4):
		for d in dirs:
			var probe: Vector2 = _snap_to_tile(snapped_origin + d * tile_size * float(ring))
			if not _is_blocked_position(probe):
				return probe
	return Vector2.INF

func _force_nudge_toward_goal(goal: Vector2, delta: float) -> bool:
	var dir: Vector2 = global_position.direction_to(goal)
	if dir == Vector2.ZERO:
		return false
	var nudge_dist: float = maxf(tile_size * 1.2, move_speed * maxf(0.5, external_move_speed_multiplier) * minf(delta, 0.06))
	var next_pos: Vector2 = global_position + dir * nudge_dist
	if _is_blocked_position(next_pos) or _is_move_segment_blocked(global_position, next_pos):
		return false
	global_position = next_pos
	_emit_moved_if_needed()
	return true

func _report_combat_event(hit: bool, damage: int, killed: bool, attack_mode: StringName) -> void:
	if _main_controller == null or not is_instance_valid(_main_controller):
		_main_controller = get_tree().get_first_node_in_group("main_controller")
	if _main_controller == null or not is_instance_valid(_main_controller):
		return
	if _main_controller.has_method("report_combat_event"):
		_main_controller.report_combat_event(&"Enemy", hit, damage, killed, attack_mode)

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _emit_moved_if_needed() -> void:
	var tile: Vector2i = _world_to_tile(global_position)
	if tile == _last_move_tile:
		return
	_last_move_tile = tile
	var bucket: Vector2i = _world_to_bucket(global_position)
	if bucket == _last_move_bucket:
		return
	_last_move_bucket = bucket
	moved.emit(self, bucket)

func _world_to_bucket(world_pos: Vector2) -> Vector2i:
	var bucket_size: float = tile_size * 4.0
	return Vector2i(
		int(floor(world_pos.x / bucket_size)),
		int(floor(world_pos.y / bucket_size))
	)

func _is_blocked_position(world_pos: Vector2) -> bool:
	var query_tile: Vector2 = _snap_to_tile(world_pos)
	if query_tile.distance_to(_snap_to_tile(global_position)) <= 0.1:
		return false
	if _is_combat_unit_blocking_tile(query_tile):
		return true
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("is_blocked_for_enemy"):
		return bool(_pathing_occupancy.is_blocked_for_enemy(world_pos))
	return false

func _is_move_segment_blocked(from_pos: Vector2, to_pos: Vector2) -> bool:
	var distance: float = from_pos.distance_to(to_pos)
	if distance <= 0.1:
		return false
	var sample_step: float = maxf(4.0, tile_size * 0.25)
	var steps: int = maxi(1, int(ceil(distance / sample_step)))
	var from_tile: Vector2 = _snap_to_tile(from_pos)
	for i in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var probe: Vector2 = from_pos.lerp(to_pos, t)
		if _snap_to_tile(probe).distance_to(from_tile) <= 0.1:
			continue
		if _is_blocked_position(probe):
			return true
	return false

func _is_combat_unit_blocking_tile(world_pos: Vector2) -> bool:
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("is_dynamic_combat_blocked"):
		return bool(_pathing_occupancy.is_dynamic_combat_blocked(world_pos, get_instance_id()))
	var snapped: Vector2 = _snap_to_tile(world_pos)
	var groups: Array[StringName] = [&"colonists", &"raiders", &"zombies"]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == null or not is_instance_valid(node) or node == self:
				continue
			if not (node is Node2D):
				continue
			if node.has_method("is_dead") and bool(node.is_dead()):
				continue
			if _snap_to_tile((node as Node2D).global_position).distance_to(snapped) > 0.1:
				continue
			if _is_node_in_combat_state(node):
				return true
	return false

func _is_node_in_combat_state(node: Node) -> bool:
	if node.get("combat_ready") == true:
		return true
	if node.has_method("is_melee_combat_locked") and bool(node.is_melee_combat_locked()):
		return true
	var job_variant: Variant = node.get("current_job")
	if job_variant is Dictionary:
		var job: Dictionary = job_variant
		var job_type: StringName = StringName(job.get("type", &""))
		if job_type == &"CombatRanged":
			return true
	var enemy_lock_variant: Variant = node.get("_melee_lock_target_id")
	if enemy_lock_variant != null and int(enemy_lock_variant) != 0:
		return true
	var enemy_target_variant: Variant = node.get("_target_colonist_id")
	if enemy_target_variant != null and int(enemy_target_variant) != 0 and node.has_method("get_current_weapon_mode") and StringName(node.get_current_weapon_mode()) == &"Ranged":
		return true
	return false

func _try_attack_structure(goal: Vector2 = Vector2.INF) -> bool:
	var target: Node = _get_structure_attack_target(global_position, structure_attack_range, goal)
	if target == null:
		return false
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_structure_attack_ms:
		return true
	var max_hp: float = float(target.get_meta("structure_max_health")) if target.has_meta("structure_max_health") else 0.0
	var hp: float = float(target.get_meta("structure_health")) if target.has_meta("structure_health") else max_hp
	if max_hp <= 0.0:
		return false
	hp = maxf(0.0, hp - structure_attack_damage)
	target.set_meta("structure_health", hp)
	target.set_meta("repair_job_queued", false)
	STRUCTURE_HEALTH_BAR.update_bar(target, hp, max_hp)
	if hp <= 0.0:
		_destroy_structure_target(target)
		if _enemy_pathing != null:
			_enemy_pathing.clear()
	_next_structure_attack_ms = now_ms + int(round(1000.0 * maxf(0.2, attack_cooldown_sec)))
	return true

func _get_structure_attack_target(center: Vector2, radius: float, goal: Vector2 = Vector2.INF) -> Node:
	var cached: Node = _get_cached_structure_attack_target(center, radius)
	if cached != null:
		return cached
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _structure_attack_target_refresh_ms:
		return null
	if not _can_scan_structure_attack_targets_this_frame():
		return null
	var target: Node = _find_blocking_structure_near(center, radius, goal)
	if target == null:
		_structure_attack_target_id = 0
		_structure_attack_target_refresh_ms = now_ms + STRUCTURE_ATTACK_TARGET_FAIL_REFRESH_MS
		return null
	_structure_attack_target_id = target.get_instance_id()
	_structure_attack_target_refresh_ms = now_ms + STRUCTURE_ATTACK_TARGET_REFRESH_MS
	return target

func _get_cached_structure_attack_target(center: Vector2, radius: float) -> Node:
	if _structure_attack_target_id == 0:
		return null
	var obj: Object = instance_from_id(_structure_attack_target_id)
	if obj == null or not is_instance_valid(obj) or not (obj is Node):
		_structure_attack_target_id = 0
		_structure_attack_target_refresh_ms = 0
		return null
	var target: Node = obj as Node
	if not _is_valid_structure_attack_target(target, center, radius):
		_structure_attack_target_id = 0
		_structure_attack_target_refresh_ms = 0
		return null
	return target

func _is_valid_structure_attack_target(target: Node, center: Vector2, radius: float) -> bool:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return false
	if not bool(target.get_meta("blocks_movement")):
		return false
	var max_hp: float = float(target.get_meta("structure_max_health")) if target.has_meta("structure_max_health") else 0.0
	if max_hp <= 0.0:
		return false
	var hp: float = float(target.get_meta("structure_health")) if target.has_meta("structure_health") else max_hp
	if hp <= 0.0:
		return false
	return _distance_sq_to_structure_footprint(center, target as Node2D) <= radius * radius

func _can_scan_structure_attack_targets_this_frame() -> bool:
	var fid: int = Engine.get_physics_frames()
	if _structure_attack_scan_frame != fid:
		_structure_attack_scan_frame = fid
		_structure_attack_scan_count = 0
	if _structure_attack_scan_count >= STRUCTURE_ATTACK_SCAN_BUDGET_PER_FRAME:
		return false
	_structure_attack_scan_count += 1
	return true

func _destroy_structure_target(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	_post_breach_flow_defer_until_ms = Time.get_ticks_msec() + POST_BREACH_FLOW_DEFER_MS
	if target.get_instance_id() == _structure_attack_target_id:
		_structure_attack_target_id = 0
		_structure_attack_target_refresh_ms = 0
	target.set_meta("blocks_movement", false)
	if target.is_in_group("blocking_structures"):
		target.remove_from_group("blocking_structures")
	_grp_blocking_ms = 0
	_notify_obstacle_layout_changed()
	target.queue_free()

func _notify_obstacle_layout_changed() -> void:
	if (_main_controller == null or not is_instance_valid(_main_controller)):
		_main_controller = get_tree().get_first_node_in_group("main_controller")
	if _main_controller != null and is_instance_valid(_main_controller) and _main_controller.has_method("_mark_pathing_dirty"):
		_main_controller._mark_pathing_dirty()
		return
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("notify_world_changed"):
		_pathing_occupancy.notify_world_changed()

func _find_blocking_structure_near(center: Vector2, radius: float, goal: Vector2 = Vector2.INF) -> Node:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= _grp_blocking_ms:
		_grp_blocking = get_tree().get_nodes_in_group("blocking_structures")
		_grp_blocking_ms = now_ms + 300
	var best: Node = null
	var best_score: float = INF
	var radius_sq: float = radius * radius
	var goal_dir: Vector2 = center.direction_to(goal) if goal != Vector2.INF else Vector2.ZERO
	for node in _grp_blocking:
		if node == null or not is_instance_valid(node):
			continue
		if not (node is Node2D):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		var dist_sq: float = _distance_sq_to_structure_footprint(center, node as Node2D)
		if dist_sq > radius_sq:
			continue
		var score: float = dist_sq
		if goal_dir != Vector2.ZERO:
			var to_node: Vector2 = center.direction_to((node as Node2D).global_position)
			score -= goal_dir.dot(to_node) * tile_size * tile_size
		var building_id: StringName = StringName(node.get_meta("building_id")) if node.has_meta("building_id") else &""
		if building_id == &"Wall" or building_id == &"Gate":
			score -= tile_size * tile_size * 0.5
		if score >= best_score:
			continue
		best_score = score
		best = node
	return best

func _distance_sq_to_structure_footprint(center: Vector2, structure: Node2D) -> float:
	var footprint: Vector2 = structure.get_meta("footprint_size") if structure.has_meta("footprint_size") else Vector2(tile_size, tile_size)
	var half: Vector2 = footprint * 0.5
	var dx: float = maxf(absf(center.x - structure.global_position.x) - half.x, 0.0)
	var dy: float = maxf(absf(center.y - structure.global_position.y) - half.y, 0.0)
	return dx * dx + dy * dy

func _refresh_label() -> void:
	if label == null:
		return
	label.text = _get_label_text(int(round(health)))

func _get_label_text(hp: int) -> String:
	return "Enemy HP:%d" % hp

func _resolve_unit_sprite_id() -> StringName:
	var script_ref: Script = get_script() as Script
	if script_ref != null:
		var script_name: String = script_ref.resource_path.get_file().get_basename().to_lower()
		if not script_name.is_empty():
			return StringName(script_name)
	return StringName(name.to_lower())

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
