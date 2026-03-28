extends Resource
class_name ColonistLoadoutData

@export_group("Equipment")
@export var weapon: StringName = &""
@export var top: StringName = &""
@export var bottom: StringName = &""
@export var hat: StringName = &""

@export_group("Starting Inventory")
@export var starting_inventory: Dictionary = {}
