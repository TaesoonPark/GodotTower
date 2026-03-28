extends Node2D
class_name Zombie

const COMBAT_MATH: Script = preload("res://scripts/core/CombatMath.gd")
const ENEMY_PATHING: Script = preload("res://scripts/core/pathing/EnemyPathing.gd")

signal died(zombie: Node)
signal moved(zombie: Node, tile: Vector2i)

@export var max_health: float = 165.0
@export var move_speed: float = 78.0
@export var base_hit_chance: float = 0.56
@export var defense: float = 2.0
@export var melee_attack: float = 12.0
@export var armor_penetration: float = 0.5
@export var melee_range: float = 28.0
@export var attack_cooldown_sec: float = 1.45
@export var structure_attack_damage: float = 16.0
@export var structure_attack_range: float = 30.0
const UPDATE_NEAR_RADIUS: float = 900.0
const UPDATE_NEAR_INTERVAL_SEC: float = 0.1
const UPDATE_FAR_INTERVAL_SEC: float = 0.24
const TARGET_REFRESH_SEC: float = 0.35
const AI_STEP_SEC: float = 0.16
const LOD_REFRESH_SEC: float = 0.3

var health: float = 0.0
var _target_colonist_id: int = 0
var _next_attack_ms: int = 0
var _next_structure_attack_ms: int = 0
var _target_refresh_left: float = 0.0
var _ai_phase_left: float = 0.0
var tile_size: float = 40.0
var _enemy_pathing: EnemyPathing = null
var _pathing_occupancy: Node = null
var _main_controller: Node = null
var _sim_accum: float = 0.0
var external_move_speed_multiplier: float = 1.0
var external_accuracy_bonus: float = 0.0
var _cached_lod_interval: float = UPDATE_NEAR_INTERVAL_SEC
var _next_lod_refresh_ms: int = 0
var _sim_interval_scale: float = 1.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
var _move_goal: Vector2 = Vector2.INF
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

func _ready() -> void:
	health = max_health
	add_to_group("zombies")
	add_to_group("raiders")
	_enemy_pathing = ENEMY_PATHING.new()
	_enemy_pathing.setup(tile_size)
	_is_blocked_callable = Callable(self, "_is_blocked_position")
	_ai_phase_left = fmod(float(get_instance_id()) * 0.017, AI_STEP_SEC)
	_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	_main_controller = get_tree().get_first_node_in_group("main_controller")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_signal("revision_changed"):
		_pathing_occupancy.connect("revision_changed", Callable(self, "_on_pathing_revision_changed"))
	if nav != null:
		nav.set_physics_process(false)
	if sprite != null and sprite.texture == null:
		sprite.texture = _make_texture(30, 36, Color(0.26, 0.68, 0.31, 1.0))
	_ensure_unblocked_spawn()
	_last_move_tile = _world_to_tile(global_position)
	_last_move_bucket = _world_to_bucket(global_position)
	_refresh_label()

func _physics_process(delta: float) -> void:
	_spawn_unclip_left = maxf(0.0, _spawn_unclip_left - delta)
	_spawn_unclip_retry_left = maxf(0.0, _spawn_unclip_retry_left - delta)
	_sim_accum += delta
	var tick_interval: float = _lod_tick_interval()
	if _sim_accum < tick_interval:
		return
	var sim_delta: float = _sim_accum
	_sim_accum = 0.0
	if _enemy_pathing != null:
		_enemy_pathing.tick(sim_delta)
	_process_movement(sim_delta)
	_ai_phase_left = maxf(0.0, _ai_phase_left - sim_delta)
	if _ai_phase_left <= 0.0:
		_ai_tick(sim_delta)
		_ai_phase_left = AI_STEP_SEC

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

func get_combat_defender_profile() -> Dictionary:
	return {"defense": defense}

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

func _ai_tick(delta: float) -> void:
	if is_dead():
		return
	_target_refresh_left = maxf(0.0, _target_refresh_left - delta)
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
		_try_attack_structure()
		var structure_target: Node2D = _resolve_structure_target()
		if structure_target != null:
			_move_goal = _snap_to_tile(structure_target.global_position)
		return
	_target_colonist_id = target.get_instance_id()
	var dist: float = global_position.distance_to(target.global_position)
	if dist > melee_range:
		_move_goal = _snap_to_tile(target.global_position)
		return
	_move_goal = global_position
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_attack_ms:
		return
	var attacker: Dictionary = {
		"attack_power": melee_attack,
		"armor_penetration": armor_penetration,
		"base_hit": base_hit_chance,
		"accuracy_bonus": external_accuracy_bonus,
		"attack_range": melee_range
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
	_report_combat_event(hit, damage, killed, &"Melee")
	_next_attack_ms = now_ms + int(round(1000.0 * maxf(0.1, attack_cooldown_sec)))

func _resolve_target() -> Node2D:
	var explicit: Object = instance_from_id(_target_colonist_id) if _target_colonist_id != 0 else null
	if explicit != null and is_instance_valid(explicit) and explicit is Node2D:
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
	var goal: Vector2 = _snap_to_tile(_move_goal)
	if goal == Vector2.INF:
		if _enemy_pathing != null:
			_enemy_pathing.clear()
		return
	var result: Dictionary = {}
	if _enemy_pathing != null:
		result = _enemy_pathing.move_step(
			global_position,
			goal,
			move_speed * maxf(0.5, external_move_speed_multiplier),
			delta,
			_is_blocked_callable
		)
	if bool(result.get("reached_goal", false)):
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
		_try_attack_structure()
		return
	var current: Vector2 = global_position
	var next_pos: Vector2 = result.get("position", current)
	# Fallback for rare empty/no-op pathing result: move directly when target tile is not blocked.
	if next_pos.distance_squared_to(current) <= 0.0001:
		var fallback_dir: Vector2 = current.direction_to(goal)
		if fallback_dir != Vector2.ZERO:
			var fallback_step: Vector2 = current + fallback_dir * move_speed * maxf(0.5, external_move_speed_multiplier) * minf(delta, 0.05)
			if not _is_blocked_position(fallback_step):
				next_pos = fallback_step
	global_position = next_pos
	_emit_moved_if_needed()

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
	global_position = global_position + dir * nudge_dist
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
	if (_pathing_occupancy == null or not is_instance_valid(_pathing_occupancy)):
		_pathing_occupancy = get_tree().get_first_node_in_group("pathing_occupancy")
	if _pathing_occupancy != null and is_instance_valid(_pathing_occupancy) and _pathing_occupancy.has_method("is_blocked_for_enemy"):
		return bool(_pathing_occupancy.is_blocked_for_enemy(world_pos))
	return false


func _try_attack_structure() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_structure_attack_ms:
		return
	var target: Node = _find_blocking_structure_near(global_position, structure_attack_range)
	if target == null:
		return
	var max_hp: float = float(target.get_meta("structure_max_health")) if target.has_meta("structure_max_health") else 0.0
	var hp: float = float(target.get_meta("structure_health")) if target.has_meta("structure_health") else max_hp
	if max_hp <= 0.0:
		return
	hp = maxf(0.0, hp - structure_attack_damage)
	target.set_meta("structure_health", hp)
	target.set_meta("repair_job_queued", false)
	if hp <= 0.0:
		target.queue_free()
	_next_structure_attack_ms = now_ms + int(round(1000.0 * maxf(0.2, attack_cooldown_sec)))

func _find_blocking_structure_near(center: Vector2, radius: float) -> Node:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms >= _grp_blocking_ms:
		_grp_blocking = get_tree().get_nodes_in_group("blocking_structures")
		_grp_blocking_ms = now_ms + 300
	var best: Node = null
	var best_dist_sq: float = radius * radius
	for node in _grp_blocking:
		if node == null or not is_instance_valid(node):
			continue
		var dist_sq: float = center.distance_squared_to(node.global_position)
		if dist_sq > best_dist_sq:
			continue
		best_dist_sq = dist_sq
		best = node
	return best

func _refresh_label() -> void:
	if label == null:
		return
	label.text = "Zombie HP:%d" % int(round(health))

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
