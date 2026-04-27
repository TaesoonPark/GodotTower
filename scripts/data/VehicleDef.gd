extends Resource
class_name VehicleDef

@export var id: StringName = &""
@export var display_name: String = ""
@export var item_resource_id: StringName = &""
@export var max_health: float = 80.0
@export var move_speed: float = 250.0
@export var carry_capacity_bonus: int = 0
@export var can_work: bool = false
@export var rider_can_attack: bool = false
@export var participates_in_scheduling: bool = false
@export var destroy_stun_seconds: float = 3.0
