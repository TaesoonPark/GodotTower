extends RefCounted
class_name JobScoring

static func score_job(
	job: Dictionary,
	colonist_pos: Vector2,
	job_priority: int,
	build_priority: int,
	craft_priority: int,
	combat_priority: int,
	gather_priority: int
) -> float:
	var score: float = (float(job.get("base_priority", 0)) + float(job_priority)) * 10.0
	var job_type: StringName = StringName(job.get("type", &"Idle"))
	var target: Vector2 = job.get("target", colonist_pos)

	match job_type:
		&"BuildSite":
			score += _distance_bonus(colonist_pos, target, 140.0, 0.003)
		&"RepairStructure":
			score += _distance_bonus(colonist_pos, target, 180.0, 0.003)
			score += float(build_priority) * 10.0
		&"DemolishStructure":
			score += _distance_bonus(colonist_pos, target, 180.0, 0.003)
			score += float(build_priority) * 10.0
		&"MaintainTrap":
			score += _distance_bonus(colonist_pos, target, 180.0, 0.003)
			score += float(build_priority) * 10.0
		&"Gather":
			score += _distance_bonus(colonist_pos, target, 180.0, 0.003)
		&"Hunt":
			score += _distance_bonus(colonist_pos, target, 220.0, 0.003)
		&"PlantCrop", &"HarvestCrop":
			score += _distance_bonus(colonist_pos, target, 220.0, 0.003)
			score += float(gather_priority) * 10.0
		&"ResearchTask":
			score += _distance_bonus(colonist_pos, target, 220.0, 0.003)
			score += float(craft_priority) * 10.0
		&"HaulResource":
			score += _distance_bonus(colonist_pos, target, 180.0, 0.003)
			score += float(job.get("urgency", 0.0)) * 0.08
			score += float(job.get("drop_amount", 0)) * 0.03
			if bool(job.get("as_craft_supply", false)):
				score += float(craft_priority) * 10.0
		&"CombatMelee", &"CombatRanged":
			score += _distance_bonus(colonist_pos, target, 260.0, 0.004)
			score += float(combat_priority) * 10.0

	return score

static func _distance_bonus(from_pos: Vector2, to_pos: Vector2, clamp_max: float, scale: float) -> float:
	var dist: float = from_pos.distance_to(to_pos)
	return clampf(clamp_max - dist, 0.0, clamp_max) * scale
