extends RefCounted
class_name SimulationSnapshot

static func from_main(main: Node) -> Dictionary:
	var snapshot: Dictionary = {
		"colonists": [],
		"jobs": [],
		"drops": [],
		"stockpiles": [],
		"resources": {},
		"reservations": {}
	}
	if main == null or not is_instance_valid(main):
		return snapshot

	if "resource_stock" in main:
		snapshot["resources"] = _sorted_dict(main.resource_stock)

	var job_system: Node = main.get("job_system")
	if job_system != null and is_instance_valid(job_system):
		snapshot["jobs"] = _job_rows(job_system.get("_jobs"))
		snapshot["reservations"] = _sorted_dict(job_system.get("_reserved_drop_ids"))

	for colonist in main.get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		snapshot["colonists"].append({
			"name": String(colonist.name),
			"pos": _vec2_string(colonist.global_position),
			"job": String(colonist.current_job.get("type", &"Idle")),
			"phase": String(colonist.current_job.get("phase", &"")),
			"target": _value_string(colonist.current_job.get("target", null))
		})

	for drop in main.get_tree().get_nodes_in_group("resource_drops"):
		if drop == null or not is_instance_valid(drop):
			continue
		snapshot["drops"].append({
			"type": String(drop.get("resource_type")),
			"amount": int(drop.get("amount")),
			"queued": bool(drop.get("job_queued")),
			"pos": _vec2_string(drop.global_position)
		})

	for zone in main.get_tree().get_nodes_in_group("stockpile_zones"):
		if zone == null or not is_instance_valid(zone):
			continue
		var stored: Dictionary = {}
		if zone.has_method("get_stored_snapshot"):
			stored = zone.get_stored_snapshot()
		snapshot["stockpiles"].append({
			"pos": _vec2_string(zone.global_position),
			"priority": int(zone.get("zone_priority")),
			"stored": _sorted_dict(stored)
		})

	return snapshot

static func to_text(snapshot: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[resources] %s" % JSON.stringify(snapshot.get("resources", {})))
	lines.append("[reservations] %s" % JSON.stringify(snapshot.get("reservations", {})))
	lines.append("[jobs]")
	for row_any in snapshot.get("jobs", []):
		lines.append("  %s" % JSON.stringify(row_any))
	lines.append("[colonists]")
	for row_any in snapshot.get("colonists", []):
		lines.append("  %s" % JSON.stringify(row_any))
	lines.append("[drops]")
	for row_any in snapshot.get("drops", []):
		lines.append("  %s" % JSON.stringify(row_any))
	lines.append("[stockpiles]")
	for row_any in snapshot.get("stockpiles", []):
		lines.append("  %s" % JSON.stringify(row_any))
	return "\n".join(lines)

static func _job_rows(jobs_any: Variant) -> Array:
	var rows: Array = []
	if not (jobs_any is Array):
		return rows
	for job_any in jobs_any:
		if not (job_any is Dictionary):
			continue
		var job: Dictionary = job_any
		rows.append({
			"type": String(job.get("type", &"")),
			"assigned_to": int(job.get("assigned_to", 0)),
			"drop_id": int(job.get("drop_id", 0)),
			"zone_id": int(job.get("zone_id", 0)),
			"phase": String(job.get("phase", &"")),
			"target": _value_string(job.get("target", null))
		})
	return rows

static func _sorted_dict(input: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = input.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		out[String(key_any)] = input[key_any]
	return out

static func _vec2_string(value: Vector2) -> String:
	return "(%.1f, %.1f)" % [value.x, value.y]

static func _value_string(value: Variant) -> String:
	if value is Vector2:
		return _vec2_string(value)
	return str(value)
