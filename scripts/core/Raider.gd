extends Node2D
class_name Raider

const COMBAT_MATH: Script = preload("res://scripts/core/CombatMath.gd")

signal died(raider: Node)

@export var max_health: float = 95.0
@export var move_speed: float = 145.0
@export var base_hit_chance: float = 0.68
@export var defense: float = 3.0
@export var melee_attack: float = 10.0
@export var ranged_attack: float = 8.0
@export var armor_penetration: float = 1.0
@export var melee_range: float = 32.0
@export var ranged_range: float = 180.0
@export var attack_cooldown_sec: float = 1.2
@export var ranged_ratio: float = 0.4

var health: float = 0.0
var _target_colonist_id: int = 0
var _next_attack_ms: int = 0
var _weapon_mode: StringName = &"Melee"
var tile_size: float = 40.0

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	health = max_health
	_weapon_mode = &"Ranged" if randf() < ranged_ratio else &"Melee"
	add_to_group("raiders")
	if sprite != null and sprite.texture == null:
		sprite.texture = _make_texture(28, 34, Color(0.86, 0.22, 0.22, 1.0))
	_refresh_label()

func _physics_process(delta: float) -> void:
	_process_movement(delta)
	_ai_tick()

func set_tile_size(value: float) -> void:
	tile_size = maxf(4.0, value)

func _snap_to_tile(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / tile_size) * tile_size,
		round(world_pos.y / tile_size) * tile_size
	)

func get_combat_defender_profile() -> Dictionary:
	return {"defense": defense + _nearby_cover_bonus()}

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
		return
	_target_colonist_id = target.get_instance_id()
	var attack_range: float = ranged_range if _weapon_mode == &"Ranged" else melee_range
	var dist: float = global_position.distance_to(target.global_position)
	if dist > attack_range:
		nav.target_position = _snap_to_tile(target.global_position)
		return
	nav.target_position = global_position
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _next_attack_ms:
		return
	var attack_power: float = ranged_attack if _weapon_mode == &"Ranged" else melee_attack
	var attacker: Dictionary = {
		"attack_power": attack_power,
		"armor_penetration": armor_penetration,
		"base_hit": base_hit_chance,
		"accuracy_bonus": 0.0,
		"attack_range": attack_range
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
	if nav.is_navigation_finished():
		return
	var next_pos: Vector2 = nav.get_next_path_position()
	var dir: Vector2 = global_position.direction_to(next_pos)
	var proposed: Vector2 = global_position + dir * move_speed * delta
	if _is_blocked_position(proposed):
		nav.target_position = global_position
		return
	global_position = proposed
	if global_position.distance_to(next_pos) < 4.0 and not _is_blocked_position(next_pos):
		global_position = next_pos

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

func _refresh_label() -> void:
	if label == null:
		return
	var weapon_text: String = "활" if _weapon_mode == &"Ranged" else "칼"
	label.text = "Raider(%s) HP:%d" % [weapon_text, int(round(health))]

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
