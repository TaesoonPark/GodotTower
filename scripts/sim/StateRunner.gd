extends RefCounted
class_name StateRunner

const JOB_SCORING: Script = preload("res://scripts/sim/JobScoring.gd")

var state: Dictionary = {}

func _init(initial_state: Dictionary = {}) -> void:
	state = _normalize_state(initial_state)

func run_ticks(ticks: int, delta: float = 0.1) -> Dictionary:
	for _i in range(maxi(0, ticks)):
		tick(delta)
	return snapshot()

func tick(delta: float) -> void:
	state["tick"] = int(state.get("tick", 0)) + 1
	_generate_gather_jobs()
	_generate_build_jobs()
	_generate_craft_jobs()
	_generate_research_jobs()
	_generate_repair_jobs()
	_generate_trap_jobs()
	_generate_haul_jobs()
	_assign_jobs()
	_step_colonists(delta)

func snapshot() -> Dictionary:
	return {
		"tick": int(state.get("tick", 0)),
		"colonists": _deep_copy_array(state.get("colonists", [])),
		"drops": _deep_copy_array(state.get("drops", [])),
		"gatherables": _deep_copy_array(state.get("gatherables", [])),
		"build_sites": _deep_copy_array(state.get("build_sites", [])),
		"craft_sites": _deep_copy_array(state.get("craft_sites", [])),
		"research": state.get("research", {}).duplicate(true),
		"structures": _deep_copy_array(state.get("structures", [])),
		"traps": _deep_copy_array(state.get("traps", [])),
		"enemies": _deep_copy_array(state.get("enemies", [])),
		"stockpiles": _deep_copy_array(state.get("stockpiles", [])),
		"jobs": _deep_copy_array(state.get("jobs", [])),
		"reservations": state.get("reservations", {}).duplicate(true)
	}

func _normalize_state(input: Dictionary) -> Dictionary:
	return {
		"tick": int(input.get("tick", 0)),
		"colonists": _deep_copy_array(input.get("colonists", [])),
		"drops": _deep_copy_array(input.get("drops", [])),
		"gatherables": _deep_copy_array(input.get("gatherables", [])),
		"build_sites": _deep_copy_array(input.get("build_sites", [])),
		"craft_sites": _deep_copy_array(input.get("craft_sites", [])),
		"research": input.get("research", {}).duplicate(true),
		"structures": _deep_copy_array(input.get("structures", [])),
		"traps": _deep_copy_array(input.get("traps", [])),
		"enemies": _deep_copy_array(input.get("enemies", [])),
		"stockpiles": _deep_copy_array(input.get("stockpiles", [])),
		"jobs": _deep_copy_array(input.get("jobs", [])),
		"reservations": input.get("reservations", {}).duplicate(true)
	}

func _generate_gather_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var gatherables: Array = state.get("gatherables", [])
	for i in range(gatherables.size()):
		var node: Dictionary = gatherables[i]
		if int(node.get("amount", 0)) <= 0:
			continue
		if not bool(node.get("designated", false)):
			continue
		if bool(node.get("job_queued", false)):
			continue
		node["job_queued"] = true
		gatherables[i] = node
		jobs.append({
			"type": &"Gather",
			"gatherable_id": int(node.get("id", 0)),
			"target": node.get("pos", Vector2.ZERO),
			"base_priority": 7,
			"assigned_to": 0,
			"work_duration": 5.0
		})
	state["gatherables"] = gatherables
	state["jobs"] = jobs

func _generate_build_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var build_sites: Array = state.get("build_sites", [])
	for i in range(build_sites.size()):
		var site: Dictionary = build_sites[i]
		if bool(site.get("complete", false)):
			continue
		if bool(site.get("job_queued", false)):
			continue
		site["job_queued"] = true
		build_sites[i] = site
		jobs.append({
			"type": &"BuildSite",
			"site_id": int(site.get("id", 0)),
			"target": site.get("work_pos", site.get("pos", Vector2.ZERO)),
			"base_priority": 11,
			"assigned_to": 0,
			"work_duration": float(site.get("required_work", 30.0))
		})
	state["build_sites"] = build_sites
	state["jobs"] = jobs

func _generate_craft_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var craft_sites: Array = state.get("craft_sites", [])
	for i in range(craft_sites.size()):
		var site: Dictionary = craft_sites[i]
		if not bool(site.get("queued", false)):
			continue
		if bool(site.get("job_queued", false)):
			continue
		site["job_queued"] = true
		craft_sites[i] = site
		jobs.append({
			"type": &"CraftRecipe",
			"target": site.get("pos", Vector2.ZERO),
			"work_duration": float(site.get("work_duration", 5.0)),
			"products": site.get("products", {}),
			"base_priority": 11,
			"assigned_to": 0
		})
	state["craft_sites"] = craft_sites
	state["jobs"] = jobs

func _generate_research_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var research: Dictionary = state.get("research", {})
	if not bool(research.get("running", false)):
		return
	if StringName(research.get("project_id", &"")) == &"":
		return
	if bool(research.get("job_queued", false)):
		return
	research["job_queued"] = true
	jobs.append({
		"type": &"ResearchTask",
		"target": research.get("pos", Vector2.ZERO),
		"project_id": StringName(research.get("project_id", &"")),
		"work_duration": float(research.get("work_duration", 0.5)),
		"research_points": float(research.get("points_per_job", 1.0)),
		"base_priority": 9,
		"assigned_to": 0
	})
	state["research"] = research
	state["jobs"] = jobs

func _generate_repair_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var structures: Array = state.get("structures", [])
	for i in range(structures.size()):
		var structure: Dictionary = structures[i]
		if bool(structure.get("repair_job_queued", false)):
			continue
		var max_hp: float = float(structure.get("max_health", 0.0))
		var hp: float = float(structure.get("health", max_hp))
		if hp >= max_hp:
			continue
		structure["repair_job_queued"] = true
		structures[i] = structure
		jobs.append({
			"type": &"RepairStructure",
			"structure_id": int(structure.get("id", 0)),
			"target": structure.get("pos", Vector2.ZERO),
			"work_duration": float(structure.get("repair_work", 0.2)),
			"base_priority": 10,
			"assigned_to": 0
		})
	state["structures"] = structures
	state["jobs"] = jobs

func _generate_trap_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var traps: Array = state.get("traps", [])
	for i in range(traps.size()):
		var trap: Dictionary = traps[i]
		if bool(trap.get("job_queued", false)):
			continue
		var max_charges: int = int(trap.get("max_charges", 0))
		var charges: int = int(trap.get("charges", 0))
		if charges >= max_charges:
			continue
		trap["job_queued"] = true
		traps[i] = trap
		jobs.append({
			"type": &"MaintainTrap",
			"structure_id": int(trap.get("id", 0)),
			"target": trap.get("pos", Vector2.ZERO),
			"work_duration": float(trap.get("work_duration", 0.2)),
			"base_priority": 10,
			"assigned_to": 0
		})
	state["traps"] = traps
	state["jobs"] = jobs

func _generate_haul_jobs() -> void:
	var jobs: Array = state.get("jobs", [])
	var reservations: Dictionary = state.get("reservations", {})
	var drops: Array = state.get("drops", [])
	var stockpiles: Array = state.get("stockpiles", [])
	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		if int(drop.get("amount", 0)) <= 0:
			continue
		var drop_id: int = int(drop.get("id", 0))
		if bool(drop.get("job_queued", false)):
			continue
		if reservations.has(drop_id):
			continue
		var zone: Dictionary = _find_best_stockpile(drop, stockpiles)
		if zone.is_empty():
			continue
		drop["job_queued"] = true
		drops[i] = drop
		jobs.append({
			"type": &"HaulResource",
			"drop_id": drop_id,
			"zone_id": int(zone.get("id", 0)),
			"target": drop.get("pos", Vector2.ZERO),
			"phase": &"to_drop",
			"base_priority": 8,
			"urgency": 0.0,
			"drop_amount": int(drop.get("amount", 0)),
			"assigned_to": 0
		})
		reservations[drop_id] = {"assigned_to": 0, "reserved_at_tick": int(state.get("tick", 0))}
	state["jobs"] = jobs
	state["drops"] = drops
	state["reservations"] = reservations

func _assign_jobs() -> void:
	var colonists: Array = state.get("colonists", [])
	var jobs: Array = state.get("jobs", [])
	var reservations: Dictionary = state.get("reservations", {})
	for c_idx in range(colonists.size()):
		var colonist: Dictionary = colonists[c_idx]
		if not _is_idle(colonist):
			continue
		var best_index: int = -1
		var best_score: float = -INF
		for j_idx in range(jobs.size()):
			var job: Dictionary = jobs[j_idx]
			if int(job.get("assigned_to", 0)) != 0:
				continue
			var score: float = JOB_SCORING.score_job(
				job,
				colonist.get("pos", Vector2.ZERO),
				_job_priority_for(colonist, StringName(job.get("type", &"Idle"))),
				int(colonist.get("build_priority", 0)),
				0,
				0,
				int(colonist.get("gather_priority", 0))
			)
			if score > best_score:
				best_score = score
				best_index = j_idx
		if best_index < 0:
			continue
		var chosen: Dictionary = jobs[best_index]
		jobs.remove_at(best_index)
		chosen["assigned_to"] = int(colonist.get("id", 0))
		colonist["current_job"] = chosen
		colonists[c_idx] = colonist
		var drop_id: int = int(chosen.get("drop_id", 0))
		if reservations.has(drop_id):
			reservations[drop_id] = {
				"assigned_to": int(colonist.get("id", 0)),
				"reserved_at_tick": int(state.get("tick", 0))
			}
	state["colonists"] = colonists
	state["jobs"] = jobs
	state["reservations"] = reservations

func _step_colonists(delta: float) -> void:
	var colonists: Array = state.get("colonists", [])
	for i in range(colonists.size()):
		var colonist: Dictionary = colonists[i]
		var job: Dictionary = colonist.get("current_job", {})
		if job.is_empty():
			continue
		var target: Vector2 = job.get("target", colonist.get("pos", Vector2.ZERO))
		var pos: Vector2 = colonist.get("pos", Vector2.ZERO)
		var speed: float = float(colonist.get("move_speed", 120.0))
		var step_dist: float = speed * delta
		var to_target: Vector2 = target - pos
		if to_target.length() > step_dist and to_target.length() > 0.0:
			pos += to_target.normalized() * step_dist
			colonist["pos"] = pos
			colonists[i] = colonist
			continue
		colonist["pos"] = target
		colonist = _advance_job(colonist)
		colonists[i] = colonist
	state["colonists"] = colonists

func _advance_job(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	if job.is_empty():
		return colonist
	match StringName(job.get("type", &"")):
		&"Gather":
			return _complete_gather(colonist)
		&"BuildSite":
			return _complete_build(colonist)
		&"CraftRecipe":
			return _complete_craft(colonist)
		&"ResearchTask":
			return _complete_research(colonist)
		&"RepairStructure":
			return _complete_repair(colonist)
		&"MaintainTrap":
			return _complete_trap(colonist)
		&"CombatMelee", &"CombatRanged":
			return _complete_combat(colonist)
		&"HaulResource":
			pass
		_:
			colonist["current_job"] = {}
			return colonist
	var phase: StringName = StringName(job.get("phase", &"to_drop"))
	if phase == &"to_drop":
		return _pickup_drop(colonist)
	return _deliver_to_stockpile(colonist)

func _complete_gather(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var gatherable_id: int = int(job.get("gatherable_id", 0))
	var gatherables: Array = state.get("gatherables", [])
	for i in range(gatherables.size()):
		var node: Dictionary = gatherables[i]
		if int(node.get("id", 0)) != gatherable_id:
			continue
		var amount: int = mini(int(node.get("gather_per_tick", 10)), int(node.get("amount", 0)))
		node["amount"] = int(node.get("amount", 0)) - amount
		node["job_queued"] = false
		if int(node.get("amount", 0)) <= 0:
			node["designated"] = false
		gatherables[i] = node
		if amount > 0:
			var drops: Array = state.get("drops", [])
			drops.append({
				"id": _next_drop_id(drops),
				"resource_type": StringName(node.get("resource_type", &"Wood")),
				"amount": amount,
				"job_queued": false,
				"pos": node.get("pos", Vector2.ZERO)
			})
			state["drops"] = drops
		break
	state["gatherables"] = gatherables
	colonist["current_job"] = {}
	return colonist

func _complete_build(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var site_id: int = int(job.get("site_id", 0))
	var build_sites: Array = state.get("build_sites", [])
	for i in range(build_sites.size()):
		var site: Dictionary = build_sites[i]
		if int(site.get("id", 0)) != site_id:
			continue
		site["work_progress"] = float(site.get("required_work", 30.0))
		site["complete"] = true
		site["job_queued"] = false
		build_sites[i] = site
		break
	state["build_sites"] = build_sites
	colonist["current_job"] = {}
	return colonist

func _complete_craft(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var drops: Array = state.get("drops", [])
	var pos: Vector2 = colonist.get("pos", Vector2.ZERO)
	var products: Dictionary = job.get("products", {})
	for key_any in products.keys():
		var amount: int = int(products[key_any])
		if amount <= 0:
			continue
		drops.append({
			"id": _next_drop_id(drops),
			"resource_type": StringName(key_any),
			"amount": amount,
			"job_queued": false,
			"pos": pos
		})
	state["drops"] = drops
	var craft_sites: Array = state.get("craft_sites", [])
	for i in range(craft_sites.size()):
		var site: Dictionary = craft_sites[i]
		if site.get("pos", Vector2.INF) == job.get("target", Vector2.ZERO) and bool(site.get("queued", false)):
			site["queued"] = false
			site["job_queued"] = false
			craft_sites[i] = site
			break
	state["craft_sites"] = craft_sites
	colonist["current_job"] = {}
	return colonist

func _complete_research(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var research: Dictionary = state.get("research", {})
	research["points"] = float(research.get("points", 0.0)) + float(job.get("research_points", 1.0))
	research["job_queued"] = false
	state["research"] = research
	colonist["current_job"] = {}
	return colonist

func _complete_repair(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var structures: Array = state.get("structures", [])
	for i in range(structures.size()):
		var structure: Dictionary = structures[i]
		if int(structure.get("id", 0)) != int(job.get("structure_id", 0)):
			continue
		structure["health"] = float(structure.get("max_health", structure.get("health", 0.0)))
		structure["repair_job_queued"] = false
		structures[i] = structure
		break
	state["structures"] = structures
	colonist["current_job"] = {}
	return colonist

func _complete_trap(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var traps: Array = state.get("traps", [])
	for i in range(traps.size()):
		var trap: Dictionary = traps[i]
		if int(trap.get("id", 0)) != int(job.get("structure_id", 0)):
			continue
		trap["charges"] = int(trap.get("max_charges", trap.get("charges", 0)))
		trap["job_queued"] = false
		traps[i] = trap
		break
	state["traps"] = traps
	colonist["current_job"] = {}
	return colonist

func _complete_combat(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var enemies: Array = state.get("enemies", [])
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if int(enemy.get("id", 0)) != int(job.get("target_id", 0)):
			continue
		enemy["health"] = 0.0
		enemy["dead"] = true
		enemies[i] = enemy
		break
	state["enemies"] = enemies
	colonist["current_job"] = {}
	return colonist

func _pickup_drop(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var drop_id: int = int(job.get("drop_id", 0))
	var carry_capacity: int = int(colonist.get("carry_capacity", 75))
	var drops: Array = state.get("drops", [])
	for i in range(drops.size()):
		var drop: Dictionary = drops[i]
		if int(drop.get("id", 0)) != drop_id:
			continue
		var amount: int = int(drop.get("amount", 0))
		var taken: int = mini(amount, carry_capacity)
		if taken <= 0:
			colonist["current_job"] = {}
			return colonist
		drop["amount"] = amount - taken
		drop["job_queued"] = false
		drops[i] = drop
		job["phase"] = &"to_zone"
		job["carried_type"] = StringName(drop.get("resource_type", &"Wood"))
		job["carried_amount"] = taken
		var stockpile: Dictionary = _find_stockpile_by_id(int(job.get("zone_id", 0)))
		job["target"] = stockpile.get("pos", colonist.get("pos", Vector2.ZERO))
		colonist["current_job"] = job
		state["drops"] = drops
		return colonist
	colonist["current_job"] = {}
	return colonist

func _deliver_to_stockpile(colonist: Dictionary) -> Dictionary:
	var job: Dictionary = colonist.get("current_job", {})
	var zone_id: int = int(job.get("zone_id", 0))
	var carried_type: StringName = StringName(job.get("carried_type", &""))
	var carried_amount: int = int(job.get("carried_amount", 0))
	var stockpiles: Array = state.get("stockpiles", [])
	for i in range(stockpiles.size()):
		var zone: Dictionary = stockpiles[i]
		if int(zone.get("id", 0)) != zone_id:
			continue
		var stored: Dictionary = zone.get("stored", {}).duplicate(true)
		stored[carried_type] = int(stored.get(carried_type, 0)) + carried_amount
		zone["stored"] = stored
		stockpiles[i] = zone
		break
	var reservations: Dictionary = state.get("reservations", {})
	reservations.erase(int(job.get("drop_id", 0)))
	state["stockpiles"] = stockpiles
	state["reservations"] = reservations
	colonist["current_job"] = {}
	return colonist

func _find_best_stockpile(drop: Dictionary, stockpiles: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = INF
	var drop_pos: Vector2 = drop.get("pos", Vector2.ZERO)
	for zone_any in stockpiles:
		if not (zone_any is Dictionary):
			continue
		var zone: Dictionary = zone_any
		var dist: float = drop_pos.distance_to(zone.get("pos", Vector2.ZERO))
		if dist < best_dist:
			best_dist = dist
			best = zone
	return best

func _find_stockpile_by_id(zone_id: int) -> Dictionary:
	for zone_any in state.get("stockpiles", []):
		if not (zone_any is Dictionary):
			continue
		var zone: Dictionary = zone_any
		if int(zone.get("id", 0)) == zone_id:
			return zone
	return {}

func _is_idle(colonist: Dictionary) -> bool:
	return (colonist.get("current_job", {}) as Dictionary).is_empty()

func _job_priority_for(colonist: Dictionary, job_type: StringName) -> int:
	match job_type:
		&"HaulResource":
			return int(colonist.get("haul_priority", 0))
		&"Gather":
			return int(colonist.get("gather_priority", 0))
		&"BuildSite":
			return int(colonist.get("build_priority", 0))
		&"CraftRecipe":
			return int(colonist.get("craft_priority", 0))
		&"ResearchTask":
			return int(colonist.get("craft_priority", 0))
		&"RepairStructure", &"MaintainTrap":
			return int(colonist.get("build_priority", 0))
		&"CombatMelee", &"CombatRanged":
			return int(colonist.get("combat_priority", 0))
		_:
			return 0

func _next_drop_id(drops: Array) -> int:
	var best: int = 0
	for drop_any in drops:
		if not (drop_any is Dictionary):
			continue
		best = maxi(best, int(drop_any.get("id", 0)))
	return best + 1

func _deep_copy_array(input: Array) -> Array:
	var out: Array = []
	for item in input:
		if item is Dictionary:
			out.append((item as Dictionary).duplicate(true))
		else:
			out.append(item)
	return out
