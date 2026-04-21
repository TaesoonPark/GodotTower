extends Resource
class_name ResourceDef

@export var id: StringName = &""
@export var display_name: String = ""
@export var stack_limit: int = 75
@export var category: String = "Raw"

@export_group("Equipment Combat")
@export var equipment_weapon_mode: StringName = &""
@export var equipment_melee_attack: float = -1.0
@export var equipment_ranged_attack: float = -1.0
@export var equipment_melee_range: float = -1.0
@export var equipment_ranged_range: float = -1.0
@export var equipment_attack_cooldown_sec: float = -1.0
@export var equipment_armor_penetration_bonus: float = 0.0
@export var equipment_accuracy_bonus: float = 0.0
@export var equipment_defense_bonus: float = 0.0
