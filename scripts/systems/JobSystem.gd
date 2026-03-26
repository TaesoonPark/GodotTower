extends Node
class_name JobSystem

var _jobs: Array[Dictionary] = []

func queue_move_job(colonist: Node, target: Vector2) -> void:
	var job: Dictionary = {
		"type": &"MoveTo",
		"target": target,
		"base_priority": 10,
		"assigned_to": colonist.get_instance_id()
	}
	_jobs.append(job)

func issue_immediate_move(colonist: Node, target: Vector2) -> void:
	_remove_jobs_for_colonist(colonist.get_instance_id())
	if colonist.has_method("cancel_current_job"):
		colonist.cancel_current_job()
	colonist.assign_job({
		"type": &"MoveTo",
		"target": target,
		"base_priority": 100,
		"assigned_to": colonist.get_instance_id()
	})

func queue_build_job(site: Node) -> void:
	var job: Dictionary = {
		"type": &"BuildSite",
		"target": site.global_position,
		"site_id": site.get_instance_id(),
		"base_priority": 8,
		"assigned_to": 0
	}
	_jobs.append(job)

func queue_need_jobs(colonist: Node) -> void:
	if colonist.hunger < 45.0:
		_jobs.append({
			"type": &"EatStub",
			"base_priority": 7,
			"assigned_to": colonist.get_instance_id()
		})
	elif colonist.rest < 35.0:
		_jobs.append({
			"type": &"IdleRecover",
			"base_priority": 6,
			"assigned_to": colonist.get_instance_id()
		})

func assign_jobs(colonists: Array) -> void:
	for colonist in colonists:
		if colonist == null or not colonist.is_idle():
			continue
		var chosen_index: int = _pick_best_job_index(colonist)
		if chosen_index < 0:
			continue
		var job: Dictionary = _jobs[chosen_index]
		_jobs.remove_at(chosen_index)
		colonist.assign_job(job)

func _pick_best_job_index(colonist: Node) -> int:
	var best_idx: int = -1
	var best_score: float = -INF
	for i in range(_jobs.size()):
		var job: Dictionary = _jobs[i]
		var assigned_to: int = int(job.get("assigned_to", 0))
		if assigned_to != 0 and assigned_to != colonist.get_instance_id():
			continue
		var job_type: StringName = job.get("type", &"Idle")
		var score: float = float(job.get("base_priority", 0)) + float(colonist.get_priority(job_type))
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx

func _remove_jobs_for_colonist(colonist_id: int) -> void:
	if colonist_id == 0:
		return
	var filtered: Array[Dictionary] = []
	for job in _jobs:
		var assigned_to: int = int(job.get("assigned_to", 0))
		if assigned_to == colonist_id:
			continue
		filtered.append(job)
	_jobs = filtered
