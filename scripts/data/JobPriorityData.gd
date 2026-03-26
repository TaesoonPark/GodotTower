extends Resource
class_name JobPriorityData

@export_range(0, 10, 1) var haul: int = 3
@export_range(0, 10, 1) var build: int = 4
@export_range(0, 10, 1) var craft: int = 3
@export_range(0, 10, 1) var combat: int = 5
@export_range(0, 10, 1) var idle: int = 1
@export_range(0, 10, 1) var eat: int = 8

func get_priority(job_type: StringName) -> int:
	match job_type:
		&"Haul":
			return haul
		&"Build":
			return build
		&"Craft":
			return craft
		&"Combat":
			return combat
		&"EatStub":
			return eat
		_:
			return idle
