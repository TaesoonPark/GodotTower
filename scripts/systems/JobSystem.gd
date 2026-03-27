extends Node
class_name JobSystem

const HAUL_QUEUE_TIMEOUT_MS: int = 5000
const HAUL_ASSIGN_TIMEOUT_MS: int = 12000
const WORK_ADJACENT_OFFSET: float = 40.0

var _jobs: Array[Dictionary] = []
var _craft_queues: Dictionary = {}
var _reserved_craft_slot_ids: Dictionary = {}
var _reserved_drop_ids: Dictionary = {}

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
	var work_target: Vector2 = site.global_position
	if site is Node2D:
		work_target = _find_adjacent_work_position(site)
	var job: Dictionary = {
		"type": &"BuildSite",
		"target": work_target,
		"site_id": site.get_instance_id(),
		"work_duration": float(site.get("required_work")),
		"base_priority": 11,
		"assigned_to": 0
	}
	_jobs.append(job)

func queue_repair_job(structure: Node, work_duration: float = 8.0) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	if bool(structure.get_meta("repair_job_queued")):
		return
	structure.set_meta("repair_job_queued", true)
	var target_pos: Vector2 = structure.global_position if structure is Node2D else Vector2.ZERO
	_jobs.append({
		"type": &"RepairStructure",
		"target": target_pos,
		"structure_id": structure.get_instance_id(),
		"work_duration": maxf(0.2, work_duration),
		"base_priority": 10,
		"assigned_to": 0
	})

func queue_demolish_job(structure: Node, work_duration: float = 4.0, replace_building_id: StringName = &"") -> void:
	if structure == null or not is_instance_valid(structure):
		return
	if bool(structure.get_meta("demolish_job_queued")):
		return
	structure.set_meta("demolish_job_queued", true)
	var target_pos: Vector2 = structure.global_position if structure is Node2D else Vector2.ZERO
	_jobs.append({
		"type": &"DemolishStructure",
		"target": target_pos,
		"structure_id": structure.get_instance_id(),
		"replace_building_id": replace_building_id,
		"work_duration": maxf(0.2, work_duration),
		"base_priority": 10,
		"assigned_to": 0
	})

func queue_gather_job(gatherable: Node, assigned_to: int = 0) -> void:
	if gatherable == null or not is_instance_valid(gatherable):
		return
	if gatherable.has_method("is_depleted") and gatherable.is_depleted():
		return
	if gatherable.has_method("set_job_queued"):
		gatherable.set_job_queued(true)
	var job: Dictionary = {
		"type": &"Gather",
		"target": gatherable.global_position,
		"gatherable_id": gatherable.get_instance_id(),
		"base_priority": 7,
		"assigned_to": assigned_to
	}
	_jobs.append(job)

func queue_hunt_job(huntable: Node, assigned_to: int = 0) -> void:
	if huntable == null or not is_instance_valid(huntable):
		return
	if huntable.has_method("is_dead") and huntable.is_dead():
		return
	if huntable.has_method("set_job_queued"):
		huntable.set_job_queued(true)
	var job: Dictionary = {
		"type": &"Hunt",
		"target": huntable.global_position,
		"huntable_id": huntable.get_instance_id(),
		"base_priority": 7,
		"assigned_to": assigned_to
	}
	_jobs.append(job)

func queue_farm_plant_job(farm_zone: Node, tile: Vector2i, crop_type: StringName, work_duration: float = 2.0, assigned_to: int = 0) -> void:
	if farm_zone == null or not is_instance_valid(farm_zone):
		return
	var target: Vector2 = farm_zone.global_position
	if farm_zone.has_method("get_plot_world"):
		target = farm_zone.get_plot_world(tile)
	_jobs.append({
		"type": &"PlantCrop",
		"target": target,
		"zone_id": farm_zone.get_instance_id(),
		"tile": tile,
		"crop_type": crop_type,
		"work_duration": maxf(0.1, work_duration),
		"base_priority": 9,
		"assigned_to": assigned_to
	})

func queue_farm_harvest_job(farm_zone: Node, tile: Vector2i, crop_type: StringName, work_duration: float = 2.0, assigned_to: int = 0) -> void:
	if farm_zone == null or not is_instance_valid(farm_zone):
		return
	var target: Vector2 = farm_zone.global_position
	if farm_zone.has_method("get_plot_world"):
		target = farm_zone.get_plot_world(tile)
	_jobs.append({
		"type": &"HarvestCrop",
		"target": target,
		"zone_id": farm_zone.get_instance_id(),
		"tile": tile,
		"crop_type": crop_type,
		"work_duration": maxf(0.1, work_duration),
		"base_priority": 11,
		"assigned_to": assigned_to
	})

func queue_combat_job(colonist: Node, enemy: Node, use_ranged: bool) -> void:
	if colonist == null or not is_instance_valid(colonist):
		return
	if enemy == null or not is_instance_valid(enemy):
		return
	var colonist_id: int = colonist.get_instance_id()
	if _has_pending_combat_job(colonist_id):
		return
	var job_type: StringName = &"CombatRanged" if use_ranged else &"CombatMelee"
	_jobs.append({
		"type": job_type,
		"target": enemy.global_position,
		"target_id": enemy.get_instance_id(),
		"base_priority": 13,
		"assigned_to": colonist_id
	})

func queue_haul_job(drop_node: Node, zone_node: Node, assigned_to: int = 0, base_priority: int = 8, as_craft_supply: bool = false) -> void:
	if drop_node == null or not is_instance_valid(drop_node):
		return
	if zone_node == null or not is_instance_valid(zone_node):
		return
	if drop_node.has_method("is_empty") and drop_node.is_empty():
		return
	var drop_id: int = drop_node.get_instance_id()
	if _reserved_drop_ids.has(drop_id):
		return
	if _has_queued_haul_job(drop_id):
		return
	if drop_node.has_method("set_job_queued"):
		drop_node.set_job_queued(true)
	var job: Dictionary = {
		"type": &"HaulResource",
		"target": drop_node.global_position,
		"drop_id": drop_id,
		"zone_id": zone_node.get_instance_id(),
		"base_priority": base_priority,
		"assigned_to": assigned_to,
		"as_craft_supply": as_craft_supply,
		"urgency": 0.0,
		"drop_amount": int(drop_node.get("amount")),
		"queued_at_ms": Time.get_ticks_msec()
	}
	_jobs.append(job)
	_reserved_drop_ids[drop_id] = {
		"assigned_to": 0,
		"reserved_at_ms": Time.get_ticks_msec()
	}

func enqueue_craft_recipe(recipe_id: StringName, workstation_id: StringName) -> void:
	if recipe_id == &"" or workstation_id == &"":
		return
	if not _craft_queues.has(workstation_id):
		_craft_queues[workstation_id] = []
	var queue: Array = _craft_queues[workstation_id]
	queue.append({
		"recipe_id": recipe_id,
		"workstation_id": workstation_id
	})
	_craft_queues[workstation_id] = queue

func enqueue_craft_recipe_front(recipe_id: StringName, workstation_id: StringName) -> void:
	if recipe_id == &"" or workstation_id == &"":
		return
	if not _craft_queues.has(workstation_id):
		_craft_queues[workstation_id] = []
	var queue: Array = _craft_queues[workstation_id]
	queue.insert(0, {
		"recipe_id": recipe_id,
		"workstation_id": workstation_id
	})
	_craft_queues[workstation_id] = queue

func dequeue_craft_recipe(workstation_id: StringName) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	var queue: Array = _craft_queues[workstation_id]
	if queue.is_empty():
		return
	queue.remove_at(0)
	_craft_queues[workstation_id] = queue

func clear_craft_queue(workstation_id: StringName) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	_craft_queues[workstation_id] = []

func remove_craft_recipe_at(workstation_id: StringName, index: int) -> void:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return
	var queue: Array = _craft_queues[workstation_id]
	if index < 0 or index >= queue.size():
		return
	queue.remove_at(index)
	_craft_queues[workstation_id] = queue

func get_craft_queue(workstation_id: StringName) -> Array[Dictionary]:
	if workstation_id == &"" or not _craft_queues.has(workstation_id):
		return []
	var queue: Array = _craft_queues[workstation_id]
	var out: Array[Dictionary] = []
	for item in queue:
		if item is Dictionary:
			out.append(item)
	return out

func notify_craft_job_finished(craft_slot_id: int = 0) -> void:
	if craft_slot_id != 0:
		_reserved_craft_slot_ids.erase(craft_slot_id)

func request_designated_gather_jobs(gatherables: Array) -> void:
	for node in gatherables:
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.get("job_queued")):
			continue
		if node.has_method("is_depleted") and node.is_depleted():
			continue
		if node.has_method("is_designated") and not bool(node.is_designated()):
			continue
		queue_gather_job(node)

func request_designated_hunt_jobs(huntables: Array) -> void:
	for node in huntables:
		if node == null or not is_instance_valid(node):
			continue
		if bool(node.get("job_queued")):
			continue
		if node.has_method("is_dead") and node.is_dead():
			continue
		if node.has_method("is_designated") and not bool(node.is_designated()):
			continue
		queue_hunt_job(node)

func request_haul_jobs(drops: Array, stockpile_zones: Array, current_stock: Dictionary, target_stock: Dictionary) -> void:
	if stockpile_zones.is_empty():
		return
	_cleanup_haul_reservations()
	for drop_node in drops:
		if drop_node == null or not is_instance_valid(drop_node):
			continue
		if bool(drop_node.get("job_queued")):
			continue
		if drop_node.has_method("is_empty") and drop_node.is_empty():
			continue
		var resource_type: StringName = StringName(drop_node.get("resource_type"))
		var drop_amount: int = int(drop_node.get("amount"))
		var nearest_zone: Node = _find_nearest_zone(drop_node.global_position, stockpile_zones, resource_type, drop_amount)
		if nearest_zone == null:
			continue
		var need: int = int(target_stock.get(resource_type, 0))
		var have: int = int(current_stock.get(resource_type, 0))
		var urgency: float = maxf(0.0, float(need - have))
		var as_craft_supply: bool = bool(drop_node.get_meta("craft_supply")) if drop_node.has_meta("craft_supply") else false
		var base_priority: int = 12 if as_craft_supply else 8
		queue_haul_job(drop_node, nearest_zone, 0, base_priority, as_craft_supply)
		_set_latest_haul_meta(drop_node.get_instance_id(), urgency, drop_amount)

func request_craft_jobs(recipe_lookup: Dictionary, workstation_slots: Dictionary, colonists: Array, can_start_callback: Callable = Callable(), on_start_callback: Callable = Callable()) -> void:
	_cleanup_craft_slot_reservations(colonists)
	if _craft_queues.is_empty():
		return
	var ws_keys: Array = _craft_queues.keys()
	ws_keys.sort_custom(func(a, b): return String(a) < String(b))
	for ws_id_any in ws_keys:
		var workstation_id: StringName = StringName(ws_id_any)
		var queue: Array = _craft_queues[workstation_id]
		if queue.is_empty():
			continue
		var slots: Array = workstation_slots.get(workstation_id, [])
		if slots.is_empty():
			continue
		var free_slots: Array[Dictionary] = []
		for slot_any in slots:
			if not (slot_any is Dictionary):
				continue
			var slot: Dictionary = slot_any
			var slot_id: int = int(slot.get("slot_id", 0))
			if slot_id == 0:
				continue
			if _reserved_craft_slot_ids.has(slot_id):
				continue
			free_slots.append(slot)
		if free_slots.is_empty():
			continue
		for slot in free_slots:
			if queue.is_empty():
				break
			var order: Dictionary = queue[0]
			var recipe_id: StringName = order.get("recipe_id", &"")
			if not recipe_lookup.has(recipe_id):
				queue.remove_at(0)
				_craft_queues[workstation_id] = queue
				continue
			var recipe: Resource = recipe_lookup[recipe_id]
			var can_start: bool = true
			if can_start_callback.is_valid():
				can_start = bool(can_start_callback.call(workstation_id, recipe))
			if not can_start:
				break
			if on_start_callback.is_valid():
				on_start_callback.call(workstation_id, recipe)
			var slot_id: int = int(slot.get("slot_id", 0))
			var station_pos: Vector2 = slot.get("pos", Vector2.INF)
			if slot_id == 0 or station_pos == Vector2.INF:
				continue
			_jobs.append({
				"type": &"CraftRecipe",
				"target": station_pos,
				"recipe_id": recipe.id,
				"workstation_id": workstation_id,
				"recipe_name": recipe.display_name,
				"work_duration": maxf(0.1, float(recipe.work_required)),
				"products": recipe.products,
				"craft_slot_id": slot_id,
				"base_priority": 11,
				"assigned_to": 0
			})
			_reserved_craft_slot_ids[slot_id] = {
				"assigned_to": 0,
				"reserved_at_ms": Time.get_ticks_msec()
			}
			queue.remove_at(0)
			_craft_queues[workstation_id] = queue

func request_research_jobs(colonists: Array, target_pos: Vector2, project_id: StringName, work_duration: float = 6.0) -> void:
	if project_id == &"":
		return
	if target_pos == Vector2.INF:
		return
	if _has_any_active_or_pending_research_job(colonists):
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if not colonist.current_job.is_empty():
			continue
		if colonist.has_method("can_do_job") and not colonist.can_do_job(&"ResearchTask"):
			continue
		var colonist_id: int = colonist.get_instance_id()
		if _has_pending_research_job(colonist_id):
			continue
		_jobs.append({
			"type": &"ResearchTask",
			"target": target_pos,
			"project_id": project_id,
			"work_duration": maxf(0.5, work_duration),
			"research_points": 1.0,
			"base_priority": 9,
			"assigned_to": colonist_id
		})
		return

func request_repair_jobs(structures: Array) -> void:
	for structure in structures:
		if structure == null or not is_instance_valid(structure):
			continue
		var max_hp: float = float(structure.get_meta("structure_max_health")) if structure.has_meta("structure_max_health") else 0.0
		if max_hp <= 0.0:
			continue
		var hp: float = float(structure.get_meta("structure_health")) if structure.has_meta("structure_health") else max_hp
		if hp >= max_hp - 0.5:
			continue
		var work_duration: float = float(structure.get_meta("repair_work")) if structure.has_meta("repair_work") else 8.0
		queue_repair_job(structure, work_duration)

func request_combat_jobs(colonists: Array, enemies: Array, rally_pos: Vector2 = Vector2.INF, rally_radius: float = 120.0) -> void:
	_cleanup_stale_combat_jobs()
	if enemies.is_empty():
		return
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("can_do_job") and not colonist.can_do_job(&"CombatMelee"):
			continue
		var colonist_id: int = colonist.get_instance_id()
		if _has_pending_combat_job(colonist_id):
			continue
		if _has_pending_move_job(colonist_id):
			continue
		if not colonist.current_job.is_empty():
			continue
		if rally_pos != Vector2.INF:
			var dist_to_rally: float = colonist.global_position.distance_to(rally_pos)
			if dist_to_rally > maxf(20.0, rally_radius):
				var dir: Vector2 = rally_pos - colonist.global_position
				var normalized: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
				var move_target: Vector2 = rally_pos - normalized * minf(rally_radius * 0.55, 72.0)
				_jobs.append({
					"type": &"MoveTo",
					"target": move_target,
					"base_priority": 14,
					"assigned_to": colonist_id
				})
				continue
		var nearest_enemy: Node = null
		var best_dist: float = INF
		for enemy in enemies:
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.has_method("is_dead") and bool(enemy.is_dead()):
				continue
			var d: float = colonist.global_position.distance_to(enemy.global_position)
			if d < best_dist:
				best_dist = d
				nearest_enemy = enemy
		if nearest_enemy == null:
			continue
		var use_ranged: bool = false
		if colonist.has_method("get_equipment_snapshot"):
			var gear: Dictionary = colonist.get_equipment_snapshot()
			use_ranged = StringName(gear.get(&"Weapon", &"")) == &"Bow"
		queue_combat_job(colonist, nearest_enemy, use_ranged)

func queue_need_jobs(colonist: Node, food_available: int) -> void:
	var colonist_id: int = colonist.get_instance_id()
	if colonist.hunger < 45.0 and food_available > 0:
		if _has_pending_need_job(colonist_id, &"EatStub"):
			return
		_jobs.append({
			"type": &"EatStub",
			"base_priority": 7,
			"assigned_to": colonist_id
		})
	elif colonist.rest < 35.0:
		if _has_pending_need_job(colonist_id, &"IdleRecover"):
			return
		_jobs.append({
			"type": &"IdleRecover",
			"base_priority": 6,
			"assigned_to": colonist_id
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
		if job.get("type", &"") == &"HaulResource":
			_reserved_drop_ids[int(job.get("drop_id", 0))] = {
				"assigned_to": colonist.get_instance_id(),
				"reserved_at_ms": Time.get_ticks_msec()
			}
		if job.get("type", &"") == &"CraftRecipe":
			var slot_id: int = int(job.get("craft_slot_id", 0))
			if slot_id != 0:
				_reserved_craft_slot_ids[slot_id] = {
					"assigned_to": colonist.get_instance_id(),
					"reserved_at_ms": Time.get_ticks_msec()
				}
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
		if colonist.has_method("can_do_job") and not colonist.can_do_job(job_type):
			continue
		var score: float = (float(job.get("base_priority", 0)) + float(colonist.get_priority(job_type))) * 10.0
		if job_type == &"BuildSite" and colonist is Node2D:
			var bdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(140.0 - bdist, 0.0, 140.0) * 0.003
		if job_type == &"RepairStructure" and colonist is Node2D:
			var rdist2: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(180.0 - rdist2, 0.0, 180.0) * 0.003
			score += float(colonist.get_priority(&"Build")) * 10.0
		if job_type == &"DemolishStructure" and colonist is Node2D:
			var ddist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(180.0 - ddist, 0.0, 180.0) * 0.003
			score += float(colonist.get_priority(&"Build")) * 10.0
		if job_type == &"Gather" and colonist is Node2D:
			var gdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(180.0 - gdist, 0.0, 180.0) * 0.003
		if job_type == &"Hunt" and colonist is Node2D:
			var hdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(220.0 - hdist, 0.0, 220.0) * 0.003
		if (job_type == &"PlantCrop" or job_type == &"HarvestCrop") and colonist is Node2D:
			var fdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(220.0 - fdist, 0.0, 220.0) * 0.003
			score += float(colonist.get_priority(&"Gather")) * 10.0
		if job_type == &"ResearchTask" and colonist is Node2D:
			var rdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(220.0 - rdist, 0.0, 220.0) * 0.003
			score += float(colonist.get_priority(&"Craft")) * 10.0
		if job_type == &"HaulResource" and colonist is Node2D:
			var dist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(180.0 - dist, 0.0, 180.0) * 0.003
			score += float(job.get("urgency", 0.0)) * 0.08
			score += float(job.get("drop_amount", 0)) * 0.03
			if bool(job.get("as_craft_supply", false)):
				score += float(colonist.get_priority(&"Craft")) * 10.0
		if (job_type == &"CombatMelee" or job_type == &"CombatRanged") and colonist is Node2D:
			var cdist: float = colonist.global_position.distance_to(job.get("target", colonist.global_position))
			score += clampf(260.0 - cdist, 0.0, 260.0) * 0.004
			score += float(colonist.get_priority(&"Combat")) * 10.0
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx

func release_haul_reservation(drop_id: int) -> void:
	if drop_id == 0:
		return
	_reserved_drop_ids.erase(drop_id)

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

func _find_nearest_zone(world_pos: Vector2, zones: Array, resource_type: StringName, amount: int) -> Node:
	var best_zone: Node = null
	var best_score: float = -INF
	for zone in zones:
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.has_method("accepts_resource") and not zone.accepts_resource(resource_type):
			continue
		if zone.has_method("preview_acceptable_amount"):
			var can_take: int = int(zone.preview_acceptable_amount(resource_type, amount))
			if can_take <= 0:
				continue
		var d: float = world_pos.distance_to(zone.global_position)
		var zone_priority: int = 0
		if zone.has_method("get_zone_priority"):
			zone_priority = int(zone.get_zone_priority())
		var score: float = float(zone_priority) * 100.0 - d
		if score > best_score:
			best_score = score
			best_zone = zone
	return best_zone

func _can_consume(stock: Dictionary, cost: Dictionary) -> bool:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		if have < need:
			return false
	return true

func _consume(stock: Dictionary, cost: Dictionary) -> void:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		stock[k] = maxi(0, have - need)

func _has_queued_haul_job(drop_id: int) -> bool:
	for job in _jobs:
		if job.get("type", &"") != &"HaulResource":
			continue
		if int(job.get("drop_id", 0)) == drop_id:
			return true
	return false

func _cleanup_haul_reservations() -> void:
	var now_ms: int = Time.get_ticks_msec()
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		if job.get("type", &"") != &"HaulResource":
			continue
		var drop_id: int = int(job.get("drop_id", 0))
		if drop_id == 0:
			_jobs.remove_at(i)
			continue
		var obj: Object = instance_from_id(drop_id)
		if obj == null or not is_instance_valid(obj):
			_jobs.remove_at(i)
			_reserved_drop_ids.erase(drop_id)
			continue
		var queued_at_ms: int = int(job.get("queued_at_ms", now_ms))
		var age_ms: int = now_ms - queued_at_ms
		var reservation: Dictionary = _reserved_drop_ids.get(drop_id, {})
		var assigned_to: int = int(reservation.get("assigned_to", 0))
		if assigned_to == 0 and age_ms > HAUL_QUEUE_TIMEOUT_MS:
			_set_drop_job_queued(drop_id, false)
			_jobs.remove_at(i)
			_reserved_drop_ids.erase(drop_id)

	var stale_keys: Array[int] = []
	for drop_id in _reserved_drop_ids.keys():
		var obj: Object = instance_from_id(int(drop_id))
		if obj == null or not is_instance_valid(obj):
			stale_keys.append(int(drop_id))
			continue
		if obj.has_method("is_empty") and obj.is_empty():
			stale_keys.append(int(drop_id))
			continue
		var reservation: Dictionary = _reserved_drop_ids[drop_id]
		var assigned_to: int = int(reservation.get("assigned_to", 0))
		var reserved_at_ms: int = int(reservation.get("reserved_at_ms", now_ms))
		if assigned_to == 0 and not bool(obj.get("job_queued")):
			stale_keys.append(int(drop_id))
			continue
		if assigned_to != 0 and now_ms - reserved_at_ms > HAUL_ASSIGN_TIMEOUT_MS:
			var colonist: Object = instance_from_id(assigned_to)
			if colonist != null and is_instance_valid(colonist) and colonist.has_method("cancel_current_job"):
				colonist.cancel_current_job()
			_set_drop_job_queued(int(drop_id), false)
			stale_keys.append(int(drop_id))
	for drop_id in stale_keys:
		_reserved_drop_ids.erase(drop_id)

func _set_latest_haul_meta(drop_id: int, urgency: float, drop_amount: int) -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		if _jobs[i].get("type", &"") != &"HaulResource":
			continue
		if int(_jobs[i].get("drop_id", 0)) != drop_id:
			continue
		_jobs[i]["urgency"] = urgency
		_jobs[i]["drop_amount"] = drop_amount
		return

func _set_drop_job_queued(drop_id: int, value: bool) -> void:
	if drop_id == 0:
		return
	var obj: Object = instance_from_id(drop_id)
	if obj == null or not is_instance_valid(obj):
		return
	if obj.has_method("set_job_queued"):
		obj.set_job_queued(value)

func _has_pending_need_job(colonist_id: int, job_type: StringName) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == job_type:
			return true
	return false

func _has_pending_combat_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		var t: StringName = StringName(job.get("type", &""))
		if t == &"CombatMelee" or t == &"CombatRanged":
			return true
	return false

func _has_pending_move_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == &"MoveTo":
			return true
	return false

func _has_pending_research_job(colonist_id: int) -> bool:
	for job in _jobs:
		if int(job.get("assigned_to", 0)) != colonist_id:
			continue
		if StringName(job.get("type", &"")) == &"ResearchTask":
			return true
	return false

func _has_any_active_or_pending_research_job(colonists: Array) -> bool:
	for job in _jobs:
		if StringName(job.get("type", &"")) == &"ResearchTask":
			return true
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.current_job.is_empty():
			continue
		if StringName(colonist.current_job.get("type", &"")) == &"ResearchTask":
			return true
	return false

func _cleanup_stale_combat_jobs() -> void:
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		if StringName(job.get("type", &"")) != &"BuildSite":
			continue
		var site_id: int = int(job.get("site_id", 0))
		if site_id == 0:
			_jobs.remove_at(i)
			continue
		var site_obj: Object = instance_from_id(site_id)
		if site_obj == null or not is_instance_valid(site_obj):
			_jobs.remove_at(i)
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		var t: StringName = StringName(job.get("type", &""))
		if t != &"CombatMelee" and t != &"CombatRanged":
			continue
		var target_id: int = int(job.get("target_id", 0))
		if target_id == 0:
			_jobs.remove_at(i)
			continue
		var obj: Object = instance_from_id(target_id)
		if obj == null or not is_instance_valid(obj):
			_jobs.remove_at(i)
			continue
		if obj.has_method("is_dead") and bool(obj.is_dead()):
			_jobs.remove_at(i)
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		var t: StringName = StringName(job.get("type", &""))
		if t != &"PlantCrop" and t != &"HarvestCrop":
			continue
		var zone_id: int = int(job.get("zone_id", 0))
		if zone_id == 0:
			_jobs.remove_at(i)
			continue
		var zone_obj: Object = instance_from_id(zone_id)
		if zone_obj == null or not is_instance_valid(zone_obj):
			_jobs.remove_at(i)
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		var t: StringName = StringName(job.get("type", &""))
		if t != &"ResearchTask":
			continue
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			_jobs.remove_at(i)
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		if StringName(job.get("type", &"")) != &"RepairStructure":
			continue
		var structure_id: int = int(job.get("structure_id", 0))
		if structure_id == 0:
			_jobs.remove_at(i)
			continue
		var obj: Object = instance_from_id(structure_id)
		if obj == null or not is_instance_valid(obj):
			_jobs.remove_at(i)
			continue
	for i in range(_jobs.size() - 1, -1, -1):
		var job: Dictionary = _jobs[i]
		if StringName(job.get("type", &"")) != &"DemolishStructure":
			continue
		var structure_id: int = int(job.get("structure_id", 0))
		if structure_id == 0:
			_jobs.remove_at(i)
			continue
		var obj: Object = instance_from_id(structure_id)
		if obj == null or not is_instance_valid(obj):
			_jobs.remove_at(i)
			continue

func _cleanup_craft_slot_reservations(colonists: Array) -> void:
	var active_slots: Dictionary = {}
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		var current_job: Dictionary = colonist.current_job
		if current_job.is_empty():
			continue
		if StringName(current_job.get("type", &"")) != &"CraftRecipe":
			continue
		var active_slot_id: int = int(current_job.get("craft_slot_id", 0))
		if active_slot_id != 0:
			active_slots[active_slot_id] = colonist.get_instance_id()
	for job in _jobs:
		if StringName(job.get("type", &"")) != &"CraftRecipe":
			continue
		var queued_slot_id: int = int(job.get("craft_slot_id", 0))
		if queued_slot_id != 0:
			active_slots[queued_slot_id] = 0
	var stale_slot_ids: Array[int] = []
	for slot_id_any in _reserved_craft_slot_ids.keys():
		var slot_id: int = int(slot_id_any)
		if active_slots.has(slot_id):
			continue
		stale_slot_ids.append(slot_id)
	for slot_id in stale_slot_ids:
		_reserved_craft_slot_ids.erase(slot_id)

func _find_adjacent_work_position(site: Node2D) -> Vector2:
	var center: Vector2 = site.global_position
	var candidates: Array[Vector2] = [
		center + Vector2(WORK_ADJACENT_OFFSET, 0.0),
		center + Vector2(-WORK_ADJACENT_OFFSET, 0.0),
		center + Vector2(0.0, WORK_ADJACENT_OFFSET),
		center + Vector2(0.0, -WORK_ADJACENT_OFFSET),
		center + Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET),
		center + Vector2(WORK_ADJACENT_OFFSET, -WORK_ADJACENT_OFFSET),
		center + Vector2(-WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET),
		center + Vector2(-WORK_ADJACENT_OFFSET, -WORK_ADJACENT_OFFSET)
	]
	var site_id: int = site.get_instance_id()
	for pos in candidates:
		if _is_blocked_by_structure(pos):
			continue
		if _is_work_position_reserved(pos, site_id):
			continue
		return pos
	return candidates[0]

func _is_work_position_reserved(world_pos: Vector2, for_site_id: int) -> bool:
	for job in _jobs:
		if StringName(job.get("type", &"")) != &"BuildSite":
			continue
		var job_site_id: int = int(job.get("site_id", 0))
		if job_site_id == 0 or job_site_id == for_site_id:
			continue
		var target: Vector2 = job.get("target", Vector2.INF)
		if target == Vector2.INF:
			continue
		if target.distance_to(world_pos) <= 8.0:
			return true
	for colonist in get_tree().get_nodes_in_group("colonists"):
		if colonist == null or not is_instance_valid(colonist):
			continue
		var active_job: Dictionary = colonist.get("current_job")
		if active_job.is_empty():
			continue
		if StringName(active_job.get("type", &"")) != &"BuildSite":
			continue
		var job_site_id: int = int(active_job.get("site_id", 0))
		if job_site_id == 0 or job_site_id == for_site_id:
			continue
		var active_target: Vector2 = active_job.get("target", Vector2.INF)
		if active_target == Vector2.INF:
			continue
		if active_target.distance_to(world_pos) <= 10.0:
			return true
	return false

func _is_blocked_by_structure(world_pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("blocking_structures"):
		if node == null or not is_instance_valid(node):
			continue
		if not bool(node.get_meta("blocks_movement")):
			continue
		var footprint: Vector2 = node.get_meta("footprint_size") if node.has_meta("footprint_size") else Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET)
		var dx: float = absf(world_pos.x - node.global_position.x)
		var dy: float = absf(world_pos.y - node.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if bool(site.get("complete")):
			continue
		var footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(WORK_ADJACENT_OFFSET, WORK_ADJACENT_OFFSET)
		var dx: float = absf(world_pos.x - site.global_position.x)
		var dy: float = absf(world_pos.y - site.global_position.y)
		if dx <= footprint.x * 0.5 and dy <= footprint.y * 0.5:
			return true
	return false
