extends RefCounted
class_name GatherTransition

static func build_start_job(job: Dictionary, duration: float = 5.0) -> Dictionary:
	var out: Dictionary = job.duplicate(true)
	out["work_started"] = true
	out["work_elapsed"] = 0.0
	out["work_duration"] = duration
	return out

static func complete(gatherable: Object, world_pos: Vector2) -> Dictionary:
	if gatherable == null or not is_instance_valid(gatherable) or not gatherable.has_method("gather_once"):
		return {"resource_type": &"", "amount": 0}
	var result: Dictionary = gatherable.gather_once(25.0)
	if gatherable.has_method("set_job_queued"):
		gatherable.set_job_queued(false)
	return {
		"resource_type": StringName(result.get("resource_type", &"")),
		"amount": int(result.get("amount", 0)),
		"world_pos": world_pos
	}
