extends Node
class_name BuildSystem

const BUILDING_SITE_SCENE: PackedScene = preload("res://scenes/world/BuildingSite.tscn")
const STOCKPILE_ZONE_SCENE: PackedScene = preload("res://scenes/world/StockpileZone.tscn")
const FARM_ZONE_SCENE: PackedScene = preload("res://scenes/world/FarmZone.tscn")

signal build_site_added(site: Node)
signal build_site_removed(site: Node)
signal structure_added(structure: Node)
signal stockpile_zone_added(zone: Node)
signal farm_zone_added(zone: Node)

var _world_root: Node2D = null
var _sites: Array = []
var _zones: Array = []
var _building_defs: Dictionary = {}
var _selected_building_id: StringName = &""
var grid_size: float = 40.0
var _cached_structures: Array = []
var _structures_cache_dirty: bool = true

func configure(world_root: Node2D, building_defs: Array = []) -> void:
	_world_root = world_root
	_set_building_defs(building_defs)

func set_selected_building(building_id: StringName) -> void:
	_selected_building_id = building_id

func place_building(world_pos: Vector2, as_blueprint: bool) -> bool:
	if _world_root == null:
		return false
	var def: Resource = get_selected_building()
	if def == null:
		return false
	var snapped_pos: Vector2 = _snap_world_to_grid(world_pos)
	if _is_footprint_occupied(snapped_pos, def.footprint_size):
		return false
	if as_blueprint:
		_place_blueprint(def, snapped_pos)
		return true
	_place_direct(def, snapped_pos)
	return true

func get_selected_building() -> Resource:
	if _selected_building_id == &"":
		return null
	if _building_defs.has(_selected_building_id):
		return _building_defs[_selected_building_id]
	return null

func can_afford_selected(stock: Dictionary) -> bool:
	var def: Resource = get_selected_building()
	if def == null:
		return false
	return _can_afford_cost(def.build_cost, stock)

func consume_selected_cost(stock: Dictionary) -> bool:
	var def: Resource = get_selected_building()
	if def == null:
		return false
	if not _can_afford_cost(def.build_cost, stock):
		return false
	_apply_cost(def.build_cost, stock)
	return true

func get_building_defs() -> Array:
	var defs: Array = []
	for key in _building_defs.keys():
		defs.append(_building_defs[key])
	return defs

func _set_building_defs(building_defs: Array) -> void:
	_building_defs.clear()
	for def in building_defs:
		if def == null:
			continue
		_building_defs[def.id] = def

func _place_blueprint(def: Resource, world_pos: Vector2) -> void:
	var site = BUILDING_SITE_SCENE.instantiate()
	site.global_position = world_pos
	_world_root.add_child(site)
	if site.has_method("setup_building"):
		site.setup_building(def, false)
	_sites.append(site)
	_structures_cache_dirty = true
	build_site_added.emit(site)

func cancel_build_site(site: Node) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	_sites.erase(site)
	if site.has_method("set_job_queued"):
		site.set_job_queued(false)
	_structures_cache_dirty = true
	build_site_removed.emit(site)
	site.queue_free()
	return true

func _place_direct(def: Resource, world_pos: Vector2) -> void:
	var placed := Node2D.new()
	placed.name = "Built_%s" % String(def.id)
	placed.global_position = world_pos
	placed.add_to_group("structures")
	_apply_structure_metas(placed, def)

	var sprite := Sprite2D.new()
	sprite.texture = _make_block_texture(int(def.footprint_size.x), int(def.footprint_size.y), def.direct_place_color)
	placed.add_child(sprite)

	var label := Label.new()
	label.text = def.display_name
	label.position = Vector2(-def.footprint_size.x * 0.48, -def.footprint_size.y * 0.9)
	placed.add_child(label)
	_world_root.add_child(placed)
	_structures_cache_dirty = true
	structure_added.emit(placed)

func _apply_structure_metas(node: Node2D, def: Resource) -> void:
	node.set_meta("building_id", def.id)
	node.set_meta("required_work", float(def.required_work))
	node.set_meta("footprint_size", def.footprint_size)
	node.set_meta("blocks_movement", bool(def.blocks_movement))
	node.set_meta("passable_for_friendly", bool(def.passable_for_friendly))
	node.set_meta("cover_bonus", float(def.cover_bonus))
	node.set_meta("trap_damage", int(def.trap_damage))
	node.set_meta("trap_cooldown_sec", float(def.trap_cooldown_sec))
	node.set_meta("trap_charges", int(def.trap_charges))
	node.set_meta("trap_max_charges", int(def.trap_charges))
	node.set_meta("trap_cooldown_left", 0.0)
	node.set_meta("trap_maint_job_queued", false)
	node.set_meta("command_aura_bonus", float(def.command_aura_bonus))
	node.set_meta("command_aura_defense_bonus", float(def.command_aura_defense_bonus))
	node.set_meta("command_aura_move_bonus", float(def.command_aura_move_bonus))
	node.set_meta("command_aura_range", float(def.command_aura_range))
	node.set_meta("farm_growth_bonus", float(def.farm_growth_bonus))
	node.set_meta("farm_yield_bonus", float(def.farm_yield_bonus))
	node.set_meta("farm_support_range", float(def.farm_support_range))
	var max_health: float = maxf(10.0, float(def.max_health))
	node.set_meta("structure_max_health", max_health)
	node.set_meta("structure_health", max_health)
	node.set_meta("repair_work", maxf(0.1, float(def.repair_work)))
	node.set_meta("repair_job_queued", false)
	node.set_meta("demolish_job_queued", false)
	node.add_to_group("repairable_structures")
	if bool(def.blocks_movement):
		node.add_to_group("blocking_structures")
	if float(def.cover_bonus) > 0.0:
		node.add_to_group("cover_structures")
	if int(def.trap_damage) > 0:
		node.add_to_group("trap_structures")
	if float(def.command_aura_bonus) > 0.0 or float(def.command_aura_defense_bonus) > 0.0 or float(def.command_aura_move_bonus) > 0.0:
		node.add_to_group("command_structures")
	if float(def.farm_growth_bonus) > 0.0 or float(def.farm_yield_bonus) > 0.0:
		node.add_to_group("farm_support_structures")

func request_build_jobs(job_system: Node) -> void:
	for i in range(_sites.size() - 1, -1, -1):
		if _is_active_site(_sites[i]):
			continue
		_sites.remove_at(i)
	var now_ms: int = Time.get_ticks_msec()
	for site in _sites:
		if site.complete:
			continue
		if site.job_queued:
			continue
		var retry_after_ms: int = int(site.get_meta("build_retry_after_ms")) if site.has_meta("build_retry_after_ms") else 0
		if retry_after_ms > now_ms:
			continue
		var queued: bool = bool(job_system.queue_build_job(site))
		if queued:
			site.set_job_queued(true)

func place_stockpile_zone(area_rect: Rect2) -> bool:
	if _world_root == null:
		return false
	var safe_rect: Rect2 = _snap_rect_to_grid(area_rect.abs())
	if safe_rect.size.x < 24.0 or safe_rect.size.y < 24.0:
		return false
	var zone := STOCKPILE_ZONE_SCENE.instantiate()
	_world_root.add_child(zone)
	if zone.has_method("setup_from_rect"):
		zone.setup_from_rect(safe_rect)
	_zones.append(zone)
	stockpile_zone_added.emit(zone)
	return true

func place_farm_zone(area_rect: Rect2) -> bool:
	if _world_root == null:
		return false
	var safe_rect: Rect2 = _snap_rect_to_grid(area_rect.abs())
	if safe_rect.size.x < 24.0 or safe_rect.size.y < 24.0:
		return false
	var zone := FARM_ZONE_SCENE.instantiate()
	_world_root.add_child(zone)
	if zone.has_method("setup_from_rect"):
		zone.setup_from_rect(safe_rect)
	_zones.append(zone)
	farm_zone_added.emit(zone)
	return true

func _has_site_near(pos: Vector2, radius: float) -> bool:
	for site in _sites:
		if not _is_active_site(site):
			continue
		if site.global_position.distance_to(pos) <= radius:
			return true
	return false

func _is_active_site(site: Object) -> bool:
	if site == null or not is_instance_valid(site):
		return false
	if not (site is Node):
		return false
	var site_node: Node = site
	if site_node.is_queued_for_deletion():
		return false
	if not site_node.is_inside_tree():
		return false
	return true

func _is_footprint_occupied(center: Vector2, footprint_size: Vector2) -> bool:
	var half: Vector2 = footprint_size * 0.5
	var candidate_rect := Rect2(center - half, footprint_size)
	for site in _sites:
		if not _is_active_site(site):
			continue
		var site_footprint: Vector2 = site.get("footprint_size") if site.get("footprint_size") != null else Vector2(grid_size, grid_size)
		var site_rect := Rect2(site.global_position - site_footprint * 0.5, site_footprint)
		if candidate_rect.intersects(site_rect):
			return true
	if _structures_cache_dirty:
		_structures_cache_dirty = false
		_cached_structures = get_tree().get_nodes_in_group("structures")
	for structure in _cached_structures:
		if structure == null or not is_instance_valid(structure):
			continue
		var structure_footprint: Vector2 = structure.get_meta("footprint_size") if structure.has_meta("footprint_size") else Vector2(grid_size, grid_size)
		var structure_rect := Rect2(structure.global_position - structure_footprint * 0.5, structure_footprint)
		if candidate_rect.intersects(structure_rect):
			return true
	return false

func _make_block_texture(w: int, h: int, color: Color) -> Texture2D:
	var width: int = max(8, w)
	var height: int = max(8, h)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _snap_world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		round(world_pos.x / grid_size) * grid_size,
		round(world_pos.y / grid_size) * grid_size
	)

func _snap_rect_to_grid(rect: Rect2) -> Rect2:
	var start: Vector2 = _snap_world_to_grid(rect.position)
	var end: Vector2 = _snap_world_to_grid(rect.position + rect.size)
	var min_x: float = minf(start.x, end.x)
	var min_y: float = minf(start.y, end.y)
	var max_x: float = maxf(start.x, end.x)
	var max_y: float = maxf(start.y, end.y)
	var snapped_size := Vector2(maxf(grid_size, max_x - min_x), maxf(grid_size, max_y - min_y))
	return Rect2(Vector2(min_x, min_y), snapped_size)

func _can_afford_cost(cost: Dictionary, stock: Dictionary) -> bool:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		if have < need:
			return false
	return true

func _apply_cost(cost: Dictionary, stock: Dictionary) -> void:
	for k in cost.keys():
		var need: int = int(cost[k])
		var have: int = int(stock.get(k, 0))
		stock[k] = maxi(0, have - need)
