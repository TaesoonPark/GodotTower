extends Node2D
class_name Zombie

const COMBAT_MATH: Script = preload("res://scripts/core/CombatMath.gd")
const ENEMY_PATHING: Script = preload("res://scripts/core/pathing/EnemyPathing.gd")

signal died(zombie: Node)

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
const UPDATE_FAR_INTERVAL_SEC: float = 0.14
const OBSTACLE_SIG_INTERVAL_SEC: float = 0.28

var health: float = 0.0
var _target_colonist_id: int = 0
var _next_attack_ms: int = 0
var _next_structure_attack_ms: int = 0
var tile_size: float = 40.0
var _enemy_pathing: EnemyPathing = null
var _sim_accum: float = 0.0
var _obstacle_sig_left: float = 0.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	health = max_health
	add_to_group("zombies")
	add_to_group("raiders")
	_enemy_pathing = ENEMY_PATHING.new()
	_enemy_pathing.setup(tile_size)
	if sprite != null and sprite.texture == null:
		sprite.texture = _make_texture(30, 36, Color(0.26, 0.68, 0.31, 1.0))
	_refresh_label()

func _physics_process(delta: float) -> void:
	_sim_accum += delta
	var tick_interval: float = _lod_tick_interval()
	if _sim_accum < tick_interval:
		return
	var sim_delta: float = _sim_accum
	_sim_accum = 0.0
	if _enemy_pathing != null:
		_enemy_pathing.tick(sim_delta)
	_update_local_obstacle_signature(sim_delta)
	_process_movement(sim_delta)
	_ai_tick()

func _lod_tick_interval() -> float:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	if global_position.distance_to(cam.global_position) <= UPDATE_NEAR_RADIUS:
		return 0.0
	return UPDATE_FAR_INTERVAL_SEC

func _update_local_obstacle_signature(delta: float) -> void:
	if _enemy_pathing == null:
		return
	_obstacle_sig_left = maxf(0.0, _obstacle_sig_left - delta)
	if _obstacle_sig_left > 0.0:
		return
	_obstacle_sig_left = OBSTACLE_SIG_INTERVAL_SEC
	var radius: float = tile_size * 3.2
	var sig: int = 17
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		if global_position.distance_to(node.global_position) > radius:
			continue
		sig = int((sig * 131 + node.get_instance_id()) % 2147483647)
	_enemy_pathing.notify_obstacle_signature(sig)

func set_tile_size(value: float) -> void:
	tile_size = maxf(4.0, value)
	if _enemy_pathing != null:
		_enemy_pathing.setup(tile_size)

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

func _ai_tick() -> void:
	if is_dead():
		return
	var target: Node2D = _resolve_target()
	if target == null:
		_target_colonist_id = 0
		_try_attack_structure()
		return
	_target_colonist_id = target.get_instance_id()
	var dist: float = global_position.distance_to(target.global_position)
	if dist > melee_range:
		nav.target_position = _snap_to_tile(target.global_position)
		return
	nav.target_position = global_position
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_attack_ms:
		return
	var attacker: Dictionary = {
		"attack_power": melee_attack,
		"armor_penetration": armor_penetration,
		"base_hit": base_hit_chance,
		"accuracy_bonus": 0.0,
		"attack_range": melee_range
	}
	var defender: Dictionary = {"defense": 0.0}
	if target.has_method("get_combat_defender_profile"):
		defender = target.get_combat_defender_profile()
	var result: Dictionary = COMBAT_MATH.resolve_attack(attacker, defender, dist)
	if bool(result.get("hit", false)) and target.has_method("apply_combat_damage"):
		target.apply_combat_damage(int(result.get("damage", 0)))
	_next_attack_ms = now_ms + int(round(1000.0 * maxf(0.1, attack_cooldown_sec)))

func _resolve_target() -> Node2D:
	var explicit: Object = instance_from_id(_target_colonist_id) if _target_colonist_id != 0 else null
	if explicit != null and is_instance_valid(explicit) and explicit is Node2D:
		return explicit
	var best_target: Node2D = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("colonists"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.is_dead()):
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < best_dist:
			best_dist = d
			best_target = node
	return best_target

func _process_movement(delta: float) -> void:
	var goal: Vector2 = _snap_to_tile(nav.target_position)
	if goal == Vector2.INF:
		if _enemy_pathing != null:
			_enemy_pathing.clear()
		return
	var result: Dictionary = {}
	if _enemy_pathing != null:
		result = _enemy_pathing.move_step(
			global_position,
			goal,
			move_speed,
			delta,
			Callable(self, "_is_blocked_position")
		)
	if bool(result.get("reached_goal", false)):
		return
	if bool(result.get("blocked", false)):
		_try_attack_structure()
		return
	global_position = result.get("position", global_position)

func _is_blocked_position(world_pos: Vector2) -> bool:
	var tile: Vector2 = _snap_to_tile(world_pos)
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(tile_size, tile_size)
		var dx: float = absf(tile.x - node.global_position.x)
		var dy: float = absf(tile.y - node.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	return false


func _try_attack_structure() -> void:
	var target: Node = _find_blocking_structure_near(global_position, structure_attack_range)
	if target == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_structure_attack_ms:
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
	var best: Node = null
	var best_dist: float = radius
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var dist: float = center.distance_to(node.global_position)
		if dist > best_dist:
			continue
		best_dist = dist
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
