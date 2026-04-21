extends RefCounted
class_name EquipmentStats

const DEFAULT_MELEE_ATTACK: float = 11.0
const DEFAULT_RANGED_ATTACK: float = 7.0
const DEFAULT_MELEE_RANGE: float = 34.0
const DEFAULT_RANGED_RANGE: float = 210.0
const DEFAULT_ATTACK_COOLDOWN_SEC: float = 1.05

static var _resource_cache: Dictionary = {}

static func make_colonist_base_profile(base_hit: float, defense: float, armor_penetration: float, accuracy_bonus: float = 0.0) -> Dictionary:
	return {
		"base_hit": base_hit,
		"defense": defense,
		"melee_attack": DEFAULT_MELEE_ATTACK,
		"ranged_attack": DEFAULT_RANGED_ATTACK,
		"armor_penetration": armor_penetration,
		"melee_range": DEFAULT_MELEE_RANGE,
		"ranged_range": DEFAULT_RANGED_RANGE,
		"attack_cooldown_sec": DEFAULT_ATTACK_COOLDOWN_SEC,
		"accuracy_bonus": accuracy_bonus,
		"weapon_mode": &"Melee"
	}

static func apply_equipment_to_profile(base_profile: Dictionary, slots: Dictionary) -> Dictionary:
	var profile: Dictionary = base_profile.duplicate(true)
	var weapon_def: Resource = get_resource_def(StringName(slots.get(&"Weapon", &"")))
	if weapon_def != null:
		_apply_weapon_profile(profile, weapon_def)
	for slot_key in [&"Top", &"Bottom", &"Hat"]:
		var apparel_def: Resource = get_resource_def(StringName(slots.get(slot_key, &"")))
		if apparel_def == null:
			continue
		profile["defense"] = float(profile.get("defense", 0.0)) + maxf(0.0, _get_def_float(apparel_def, "equipment_defense_bonus", 0.0))
	return profile

static func get_resource_def(item_id: StringName) -> Resource:
	if item_id == &"":
		return null
	if _resource_cache.has(item_id):
		return _resource_cache[item_id]
	var path: String = _resource_path_for(item_id)
	if path.is_empty():
		_resource_cache[item_id] = null
		return null
	var res: Resource = load(path)
	_resource_cache[item_id] = res
	return res

static func _apply_weapon_profile(profile: Dictionary, weapon_def: Resource) -> void:
	var weapon_mode: StringName = StringName(weapon_def.get("equipment_weapon_mode"))
	if weapon_mode == &"Melee" or weapon_mode == &"Ranged":
		profile["weapon_mode"] = weapon_mode
	_apply_absolute(profile, "melee_attack", _get_def_float(weapon_def, "equipment_melee_attack", -1.0))
	_apply_absolute(profile, "ranged_attack", _get_def_float(weapon_def, "equipment_ranged_attack", -1.0))
	_apply_absolute(profile, "melee_range", _get_def_float(weapon_def, "equipment_melee_range", -1.0))
	_apply_absolute(profile, "ranged_range", _get_def_float(weapon_def, "equipment_ranged_range", -1.0))
	var cooldown: float = _get_def_float(weapon_def, "equipment_attack_cooldown_sec", -1.0)
	if cooldown > 0.0:
		profile["attack_cooldown_sec"] = cooldown
	profile["armor_penetration"] = float(profile.get("armor_penetration", 0.0)) + _get_def_float(weapon_def, "equipment_armor_penetration_bonus", 0.0)
	profile["accuracy_bonus"] = float(profile.get("accuracy_bonus", 0.0)) + _get_def_float(weapon_def, "equipment_accuracy_bonus", 0.0)

static func _apply_absolute(profile: Dictionary, key: String, value: float) -> void:
	if value >= 0.0:
		profile[key] = value

static func _get_def_float(def: Resource, property: StringName, fallback: float) -> float:
	var value = def.get(property)
	if value == null:
		return fallback
	return float(value)

static func _resource_path_for(item_id: StringName) -> String:
	match item_id:
		&"Bow":
			return "res://data/resources/bow.tres"
		&"Sword":
			return "res://data/resources/sword.tres"
		&"Weapon":
			return "res://data/resources/weapon.tres"
		&"CombatTop":
			return "res://data/resources/combat_top.tres"
		&"CombatBottom":
			return "res://data/resources/combat_bottom.tres"
		&"CombatHat":
			return "res://data/resources/combat_hat.tres"
		&"GatherTop":
			return "res://data/resources/gather_top.tres"
		&"GatherBottom":
			return "res://data/resources/gather_bottom.tres"
		&"StrawHat":
			return "res://data/resources/straw_hat.tres"
	return ""
