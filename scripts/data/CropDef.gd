extends Resource
class_name CropDef

@export var id: StringName = &""
@export var display_name: String = ""
@export var growth_seconds: float = 180.0
@export var plant_work_seconds: float = 2.0
@export var harvest_work_seconds: float = 2.0
@export var yield_resource_type: StringName = &"FoodRaw"
@export var yield_amount: int = 4
