extends Resource
class_name JobPriorityData

@export_range(0, 10, 1) var haul: int = 5
@export_range(0, 10, 1) var build: int = 9
@export_range(0, 10, 1) var craft: int = 8
@export_range(0, 10, 1) var gather: int = 7
@export_range(0, 10, 1) var hunt: int = 6
@export_range(0, 10, 1) var combat: int = 10
@export_range(0, 10, 1) var idle: int = 1
@export_range(0, 10, 1) var eat: int = 8

func get_priority(job_type: StringName) -> int:
	match job_type:
		&"Haul", &"HaulResource":
			return haul
		&"Gather", &"PlantCrop", &"HarvestCrop":
			return gather
		&"Hunt":
			return hunt
		&"Build", &"BuildSite", &"RepairStructure", &"DemolishStructure":
			return build
		&"Craft", &"CraftRecipe", &"ResearchTask":
			return craft
		&"Combat":
			return combat
		&"EatStub":
			return eat
		_:
			return idle
