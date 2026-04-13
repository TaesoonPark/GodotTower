extends RefCounted
class_name HaulReservationLogic

static func collect_stale_queue_jobs(
	jobs: Array,
	reservations: Dictionary,
	drop_states: Dictionary,
	now_ms: int,
	queue_timeout_ms: int
) -> Dictionary:
	var remove_indexes: Array[int] = []
	var release_drop_ids: Array[int] = []
	for i in range(jobs.size() - 1, -1, -1):
		var job_any = jobs[i]
		if not (job_any is Dictionary):
			continue
		var job: Dictionary = job_any
		if StringName(job.get("type", &"")) != &"HaulResource":
			continue
		var drop_id: int = int(job.get("drop_id", 0))
		if drop_id == 0:
			remove_indexes.append(i)
			continue
		if not drop_states.has(drop_id):
			remove_indexes.append(i)
			release_drop_ids.append(drop_id)
			continue
		var queued_at_ms: int = int(job.get("queued_at_ms", now_ms))
		var age_ms: int = now_ms - queued_at_ms
		var reservation: Dictionary = reservations.get(drop_id, {})
		var assigned_to: int = int(reservation.get("assigned_to", 0))
		if assigned_to == 0 and age_ms > queue_timeout_ms:
			remove_indexes.append(i)
			release_drop_ids.append(drop_id)
	return {
		"remove_indexes": remove_indexes,
		"release_drop_ids": release_drop_ids
	}

static func collect_stale_reservations(
	reservations: Dictionary,
	drop_states: Dictionary,
	now_ms: int,
	assign_timeout_ms: int
) -> Dictionary:
	var stale_drop_ids: Array[int] = []
	var cancel_colonist_ids: Array[int] = []
	for drop_id_any in reservations.keys():
		var drop_id: int = int(drop_id_any)
		if not drop_states.has(drop_id):
			stale_drop_ids.append(drop_id)
			continue
		var drop_state: Dictionary = drop_states[drop_id]
		if bool(drop_state.get("is_empty", false)):
			stale_drop_ids.append(drop_id)
			continue
		var reservation: Dictionary = reservations[drop_id]
		var assigned_to: int = int(reservation.get("assigned_to", 0))
		var reserved_at_ms: int = int(reservation.get("reserved_at_ms", now_ms))
		if assigned_to == 0 and not bool(drop_state.get("job_queued", false)):
			stale_drop_ids.append(drop_id)
			continue
		if assigned_to != 0 and now_ms - reserved_at_ms > assign_timeout_ms:
			stale_drop_ids.append(drop_id)
			cancel_colonist_ids.append(assigned_to)
	return {
		"stale_drop_ids": stale_drop_ids,
		"cancel_colonist_ids": cancel_colonist_ids
	}
