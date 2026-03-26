extends Resource
class_name BuildingDef

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: String = "Structure"
@export var required_work: float = 30.0
@export var footprint_size: Vector2 = Vector2(40, 40)
@export var build_cost: Dictionary = {}
@export var direct_place_color: Color = Color(0.38, 0.7, 0.45, 1.0)
@export var blueprint_color: Color = Color(0.45, 0.55, 0.85, 0.7)
@export var required_research: StringName = &""
@export var blocks_movement: bool = false
@export var cover_bonus: float = 0.0
@export var trap_damage: int = 0
@export var trap_cooldown_sec: float = 0.0
@export var trap_charges: int = 0
