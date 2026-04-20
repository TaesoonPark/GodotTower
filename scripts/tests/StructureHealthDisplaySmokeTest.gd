extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

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
	for _i in range(16):
		await get_tree().process_frame

	main.build_system.set_selected_building(&"Wall")
	var direct_pos := Vector2(5200.0, 2400.0)
	if not main.build_system.place_building(direct_pos, false):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: direct wall placement failed")
		return
	var structure: Node = _find_structure_at(direct_pos)
	if structure == null:
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: direct wall missing")
		return
	if _has_label_descendant(structure):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: direct structure label still exists")
		return

	main._refresh_structure_integrity()
	if _visible_health_bar(structure):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: full health displayed a bar")
		return

	var max_hp: float = float(structure.get_meta("structure_max_health"))
	structure.set_meta("structure_health", max_hp * 0.4)
	main._refresh_structure_integrity()
	var bar: Node2D = structure.get_node_or_null("StructureHealthBar") as Node2D
	if bar == null or not bar.visible:
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: damaged health bar missing")
		return
	var fill: Sprite2D = bar.get_node_or_null("Fill") as Sprite2D
	var background: Sprite2D = bar.get_node_or_null("Background") as Sprite2D
	if fill == null or background == null:
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: health bar sprites missing")
		return
	if absf(fill.scale.x - 0.4) > 0.03:
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: fill ratio %.2f" % fill.scale.x)
		return

	structure.set_meta("structure_health", max_hp)
	main._refresh_structure_integrity()
	if _visible_health_bar(structure):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: repaired full health bar remained visible")
		return

	var site_pos := Vector2(5320.0, 2400.0)
	if not main.build_system.place_building(site_pos, true):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: blueprint wall placement failed")
		return
	var site: Node = _find_build_site_at(site_pos)
	if site == null or not site.has_method("apply_work"):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: build site missing")
		return
	site.apply_work(9999.0)
	await get_tree().process_frame
	if _has_label_descendant(site):
		_finish(false, "STRUCTURE_HEALTH_DISPLAY_FAIL: completed site label still exists")
		return

	_finish(true, "STRUCTURE_HEALTH_DISPLAY_PASS: labels removed and health bar visibility is correct")

func _find_structure_at(pos: Vector2) -> Node:
	for structure in get_tree().get_nodes_in_group("structures"):
		if structure == null or not is_instance_valid(structure):
			continue
		if not (structure is Node2D):
			continue
		if (structure as Node2D).global_position.distance_to(pos) <= 0.2:
			return structure
	return null

func _find_build_site_at(pos: Vector2) -> Node:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if not (site is Node2D):
			continue
		if (site as Node2D).global_position.distance_to(pos) <= 0.2:
			return site
	return null

func _has_label_descendant(node: Node) -> bool:
	for child in node.get_children():
		if child is Label:
			return true
		if _has_label_descendant(child):
			return true
	return false

func _visible_health_bar(structure: Node) -> bool:
	var bar: Node2D = structure.get_node_or_null("StructureHealthBar") as Node2D
	return bar != null and bar.visible
