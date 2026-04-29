extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

const BUILDING_IDS: Array[StringName] = [
	&"AbandonedClinic",
	&"LootedMarket",
	&"RustedGarage",
	&"RadioOutpost"
]

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
	for _i in range(12):
		await get_tree().process_frame

	_clear_world_resource_blockers()
	for building_id in BUILDING_IDS:
		var def: Resource = main._find_building_def(building_id)
		if def == null:
			_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: missing def %s" % String(building_id))
			return
		if def.footprint_size != Vector2(192, 256):
			_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: unexpected base footprint for %s" % String(building_id))
			return
		if not bool(def.get("rotatable")):
			_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: %s is not rotatable" % String(building_id))
			return
		for rotation in range(4):
			var tex: Texture2D = GAME_SPRITE.get_building_texture(building_id, rotation)
			if tex == null:
				_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: missing texture %s rot=%d" % [String(building_id), rotation])
				return
			var expected_size: Vector2 = Vector2(256, 192) if rotation % 2 == 1 else Vector2(192, 256)
			if tex.get_size() != expected_size:
				_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: texture %s rot=%d size=%s expected=%s" % [String(building_id), rotation, str(tex.get_size()), str(expected_size)])
				return

	main._on_building_selected(&"AbandonedClinic")
	main._rotate_pending_building()
	if int(main.pending_building_rotation) != 1:
		_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: R rotation did not advance placement state")
		return
	var site_pos: Vector2 = main._snap_building_to_grid(Vector2(3456.0, 2304.0), &"AbandonedClinic", 1)
	if not main._try_place_building_by_id(site_pos, &"AbandonedClinic", 1):
		_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: rotated clinic placement failed")
		return
	for _i in range(2):
		await get_tree().process_frame
	var site: Node = _find_build_site(&"AbandonedClinic", site_pos)
	if site == null:
		_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: rotated clinic site missing")
		return
	if int(site.get("building_rotation")) != 1 or site.get("footprint_size") != Vector2(256, 192):
		_finish(false, "EXPLORATION_BUILDING_ROTATION_FAIL: rotated clinic site did not keep 3x4 footprint")
		return

	_finish(true, "EXPLORATION_BUILDING_ROTATION_PASS: 4 exploration buildings load and place with rotated footprints")

func _clear_world_resource_blockers() -> void:
	for group_name in [&"gatherables", &"huntables", &"resource_drops"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if node != null and is_instance_valid(node):
				node.queue_free()

func _find_build_site(building_id: StringName, world_pos: Vector2) -> Node:
	for site in get_tree().get_nodes_in_group("build_sites"):
		if site == null or not is_instance_valid(site):
			continue
		if StringName(site.get("building_id")) != building_id:
			continue
		if site is Node2D and (site as Node2D).global_position.distance_to(world_pos) <= 0.2:
			return site
	return null
