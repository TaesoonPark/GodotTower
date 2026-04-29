extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "BUILD_SITE_ACCESSIBLE_RETARGET_FAIL: missing colonist")
		return
	var lead = colonists[0]
	if lead == null or not is_instance_valid(lead):
		_finish(false, "BUILD_SITE_ACCESSIBLE_RETARGET_FAIL: invalid colonist")
		return
	if lead.has_method("cancel_current_job"):
		lead.cancel_current_job()
	lead.set("hunger", 100.0)
	lead.set("rest", 100.0)
	lead.set_work_enabled(&"Build", true)

	var center: Vector2 = main._snap_to_tile(Vector2(3840.0, 2160.0))
	lead.global_position = center + Vector2(-TILE_SIZE * 2.0, 0.0)
	main.build_system.set_selected_building(&"Wall")
	if not bool(main.build_system.place_building(center, true)):
		_finish(false, "BUILD_SITE_ACCESSIBLE_RETARGET_FAIL: build site placement failed")
		return
	_place_separating_wall(main, center)
	main._mark_pathing_dirty()
	main._dispatch_event_updates()
	for _i in range(4):
		await get_tree().process_frame

	var site: Node = _find_site_at(center)
	if site == null:
		_finish(false, "BUILD_SITE_ACCESSIBLE_RETARGET_FAIL: missing build site")
		return
	if site.has_method("mark_materials_delivered"):
		site.mark_materials_delivered()
	site.set_job_queued(true)
	var bad_target: Vector2 = center + Vector2(TILE_SIZE, 0.0)
	lead.assign_job({
		"type": &"BuildSite",
		"target": bad_target,
		"site_id": site.get_instance_id(),
		"work_duration": float(site.get("required_work")),
		"base_priority": 11,
		"assigned_to": lead.get_instance_id()
	})

	for _step in range(360):
		await get_tree().process_frame
		if bool(site.get("complete")):
			_finish(true, "BUILD_SITE_ACCESSIBLE_RETARGET_PASS: build job retargeted from blocked side to accessible side")
			return
		var current_target: Vector2 = lead.current_job.get("target", bad_target) if not lead.current_job.is_empty() else bad_target
		if current_target.distance_to(bad_target) > 0.1 and current_target.x < center.x:
			if bool(lead.current_job.get("work_started", false)):
				_finish(true, "BUILD_SITE_ACCESSIBLE_RETARGET_PASS: build job retargeted and started work")
				return

	_finish(false, "BUILD_SITE_ACCESSIBLE_RETARGET_FAIL: colonist stayed on inaccessible build target target=%s pos=%s" % [str(lead.current_job.get("target", Vector2.INF)), str(lead.global_position)])

func _place_separating_wall(main: Node, center: Vector2) -> void:
	main.build_system.set_selected_building(&"Wall")
	for y in range(-60, 61):
		if y == 0:
			continue
		main.build_system.place_building(center + Vector2(0.0, float(y) * TILE_SIZE), false)

func _find_site_at(pos: Vector2) -> Node:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if (site as Node2D).global_position.distance_to(pos) <= 0.1:
			return site
	return null
