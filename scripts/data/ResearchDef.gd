extends Resource
class_name ResearchDef

@export var id: StringName = &""
@export var display_name: String = ""
@export var required_points: float = 100.0
@export var unlock_buildings: Array[StringName] = []
@export var bonus_type: StringName = &""
@export var bonus_value: float = 0.0
