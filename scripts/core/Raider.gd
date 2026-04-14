extends EnemyUnitBase
class_name Raider

var _cached_cover_val: float = 0.0
var _cached_cover_ms: int = 0

func get_unit_profile() -> Dictionary:
	return {
		"max_health": 95.0,
		"move_speed": 145.0,
		"base_hit_chance": 0.68,
		"defense": 3.0,
		"melee_attack": 10.0,
		"ranged_attack": 8.0,
		"armor_penetration": 1.0,
		"melee_range": 32.0,
		"ranged_range": 180.0,
		"attack_cooldown_sec": 1.2,
		"ranged_ratio": 0.0,
		"structure_attack_damage": 10.0,
		"structure_attack_range": 30.0
	}

func get_enemy_groups() -> Array[StringName]:
	return [&"raiders"]

func get_initial_weapon_mode() -> StringName:
	return &"Melee"

func _get_label_text(hp: int) -> String:
	var weapon_text: String = "활" if get_current_weapon_mode() == &"Ranged" else "칼"
	return "Raider(%s) HP:%d" % [weapon_text, hp]

func _get_combat_defender_profile() -> Dictionary:
	return {"defense": defense + _nearby_cover_bonus()}

func _nearby_cover_bonus() -> float:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms < _cached_cover_ms:
		return _cached_cover_val
	_cached_cover_ms = now_ms + 400
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
	_cached_cover_val = best_bonus
	return best_bonus
