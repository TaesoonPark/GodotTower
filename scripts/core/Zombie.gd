extends EnemyUnitBase
class_name Zombie

func get_unit_profile() -> Dictionary:
	return {
		"max_health": 165.0,
		"move_speed": 78.0,
		"base_hit_chance": 0.56,
		"defense": 2.0,
		"melee_attack": 12.0,
		"ranged_attack": 0.0,
		"armor_penetration": 0.5,
		"melee_range": 28.0,
		"ranged_range": 180.0,
		"attack_cooldown_sec": 1.45,
		"structure_attack_damage": 16.0,
		"structure_attack_range": 30.0,
		"ranged_ratio": 0.0
	}

func get_enemy_groups() -> Array[StringName]:
	return [&"zombies"]

func _get_label_text(hp: int) -> String:
	return "Zombie HP:%d" % hp

func _get_combat_defender_profile() -> Dictionary:
	return {"defense": defense}
