extends RefCounted
class_name CombatMath

static func compute_effective_defense(defense: float, armor_penetration: float) -> float:
	return maxf(0.0, defense - armor_penetration)

static func compute_hit_chance(base_hit: float, attacker_bonus: float, distance: float, attack_range: float) -> float:
	var safe_range: float = maxf(1.0, attack_range)
	var distance_penalty: float = 0.0
	if distance > safe_range * 0.4:
		distance_penalty = ((distance - safe_range * 0.4) / safe_range) * 0.35
	return clampf(base_hit + attacker_bonus - distance_penalty, 0.12, 0.96)

static func resolve_attack(attacker: Dictionary, defender: Dictionary, distance: float) -> Dictionary:
	var attack_power: float = float(attacker.get("attack_power", 1.0))
	var armor_penetration: float = float(attacker.get("armor_penetration", 0.0))
	var base_hit: float = float(attacker.get("base_hit", 0.7))
	var accuracy_bonus: float = float(attacker.get("accuracy_bonus", 0.0))
	var attack_range: float = float(attacker.get("attack_range", 30.0))
	var defense: float = float(defender.get("defense", 0.0))
	var effective_defense: float = compute_effective_defense(defense, armor_penetration)
	var hit_chance: float = compute_hit_chance(base_hit, accuracy_bonus, distance, attack_range)
	var is_hit: bool = randf() <= hit_chance
	var damage: int = 0
	if is_hit:
		damage = maxi(1, int(round(attack_power - effective_defense)))
	return {
		"hit": is_hit,
		"hit_chance": hit_chance,
		"damage": damage,
		"effective_defense": effective_defense
	}
