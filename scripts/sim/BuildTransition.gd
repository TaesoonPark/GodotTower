extends RefCounted
class_name BuildTransition

static func can_start(site_obj: Object, current_pos: Vector2, target: Vector2, threshold: float, site_range: float) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	if current_pos.distance_to(target) > threshold:
		return false
	if site_obj is Node2D and current_pos.distance_to((site_obj as Node2D).global_position) > site_range:
		return false
	return true

static func begin_work(job: Dictionary, work_duration: float, speed_multiplier: float) -> Dictionary:
	var out: Dictionary = job.duplicate(true)
	out["work_started"] = true
	out["work_elapsed"] = 0.0
	out["work_duration"] = maxf(1.0, work_duration / maxf(0.1, speed_multiplier))
	return out

static func complete(site_obj: Object) -> bool:
	if site_obj == null or not is_instance_valid(site_obj):
		return false
	var target_work: float = float(site_obj.get("required_work"))
	var progressed: float = float(site_obj.get("work_progress"))
	site_obj.apply_work(maxf(0.0, target_work - progressed))
	if not bool(site_obj.get("complete")) and site_obj.has_method("set_job_queued"):
		site_obj.set_job_queued(false)
	return bool(site_obj.get("complete"))
