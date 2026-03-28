extends Node2D
class_name FarmZone

signal zone_changed(zone: Node)
signal farm_job_needed(zone: Node)

@export var min_zone_size: float = 32.0
@export var tile_size: float = 40.0

var zone_size: Vector2 = Vector2(120, 80)
var crop_type: StringName = &""
var crop_catalog: Dictionary = {}
var growth_time_multiplier: float = 1.0
var zone_fertility: float = 1.0
var yield_multiplier: float = 1.0
var fertility_resilience: float = 1.0
var _plots: Dictionary = {}
var _plot_markers: Dictionary = {}
var _plot_marker_root: Node2D = null

@onready var fill_polygon: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var label: Label = $Label

func setup_from_rect(rect: Rect2) -> void:
	var safe_rect := rect.abs()
	zone_size = Vector2(
		maxf(min_zone_size, safe_rect.size.x),
		maxf(min_zone_size, safe_rect.size.y)
	)
	global_position = safe_rect.get_center()
	_rebuild_plots()
	if is_node_ready():
		_refresh_shape()
	zone_changed.emit(self)

func _ready() -> void:
	add_to_group("farm_zones")
	if zone_fertility <= 0.0:
		zone_fertility = randf_range(0.85, 1.15)
	_ensure_plot_marker_root()
	if _plots.is_empty():
		_rebuild_plots()
	_refresh_shape()
	_refresh_plot_markers()
	zone_changed.emit(self)

func contains_point(world_point: Vector2) -> bool:
	var local: Vector2 = to_local(world_point)
	return absf(local.x) <= zone_size.x * 0.5 and absf(local.y) <= zone_size.y * 0.5

func set_crop_type(next_crop: StringName) -> void:
	crop_type = next_crop
	for tile in _plots.keys():
		var plot: Dictionary = _plots[tile]
		plot["job_queued"] = false
		_plots[tile] = plot
	_refresh_label()
	_emit_zone_updates()

func get_crop_type() -> StringName:
	return crop_type

func set_crop_catalog(next_catalog: Dictionary) -> void:
	crop_catalog = next_catalog.duplicate(true)
	_refresh_label()

func set_growth_time_multiplier(value: float) -> void:
	growth_time_multiplier = maxf(0.1, value)

func set_yield_multiplier(value: float) -> void:
	yield_multiplier = clampf(value, 0.7, 2.0)

func set_fertility_resilience(value: float) -> void:
	fertility_resilience = clampf(value, 0.7, 1.8)

func get_crop_options() -> Array:
	var out: Array = []
	var keys: Array = crop_catalog.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		var key: StringName = StringName(key_any)
		var crop_def: Resource = crop_catalog[key]
		out.append({
			"id": key,
			"label": String(crop_def.display_name)
		})
	return out

func get_crop_def() -> Resource:
	if crop_type == &"":
		return null
	if crop_catalog.has(crop_type):
		return crop_catalog[crop_type]
	# Be tolerant to String/StringName key mismatch from serialized data.
	for key_any in crop_catalog.keys():
		if String(key_any) == String(crop_type):
			return crop_catalog[key_any]
	return null

func get_crop_display_name() -> String:
	var crop_def: Resource = get_crop_def()
	if crop_def == null:
		if crop_type != &"":
			return String(crop_type)
		return "미선택"
	return String(crop_def.display_name)

func tick_growth(delta: float) -> void:
	var changed: bool = false
	var empty_count: int = 0
	var growing_count: int = 0
	var support_growth: float = _nearby_farm_support_growth_bonus()
	for tile in _plots.keys():
		var plot: Dictionary = _plots[tile]
		var state: StringName = StringName(plot.get("state", &"Empty"))
		if state == &"Empty":
			empty_count += 1
		elif state == &"Growing":
			growing_count += 1
		if state != &"Growing":
			continue
		var elapsed: float = float(plot.get("elapsed", 0.0)) + delta
		plot["elapsed"] = elapsed
		var growth_crop: StringName = StringName(plot.get("crop", &""))
		var growth_seconds: float = 180.0
		if crop_catalog.has(growth_crop):
			growth_seconds = float(crop_catalog[growth_crop].growth_seconds)
		var rotation_mult: float = float(plot.get("rotation_mult", 1.0))
		var effective_growth: float = growth_seconds * growth_time_multiplier * rotation_mult / maxf(0.2, zone_fertility + support_growth)
		if elapsed >= effective_growth:
			plot["state"] = &"Mature"
			changed = true
		_plots[tile] = plot
	var total_plots: float = float(maxi(1, _plots.size()))
	var idle_ratio: float = float(empty_count) / total_plots
	var stress_ratio: float = float(growing_count) / total_plots
	if idle_ratio >= 0.55:
		zone_fertility = minf(1.3, zone_fertility + delta * 0.01 * fertility_resilience)
	elif stress_ratio >= 0.7:
		zone_fertility = maxf(0.7, zone_fertility - delta * 0.008 / maxf(0.5, fertility_resilience))
	if changed:
		_refresh_plot_markers()
		_emit_zone_updates()
	_refresh_label()

func request_jobs(job_system: Node) -> void:
	var job: Dictionary = claim_next_job()
	if job.is_empty():
		return
	var tile: Vector2i = job.get("tile", Vector2i.ZERO)
	var crop_id: StringName = StringName(job.get("crop_type", crop_type))
	var duration: float = float(job.get("work_duration", 2.0))
	var t: StringName = StringName(job.get("type", &""))
	if t == &"HarvestCrop":
		job_system.queue_farm_harvest_job(self, tile, crop_id, duration)
	elif t == &"PlantCrop":
		job_system.queue_farm_plant_job(self, tile, crop_id, duration)
	else:
		clear_plot_job(tile)
	_emit_zone_updates()

func claim_next_job() -> Dictionary:
	var crop_def: Resource = get_crop_def()
	var plant_work: float = 2.0
	var harvest_work: float = 2.0
	if crop_def != null:
		plant_work = float(crop_def.plant_work_seconds)
		harvest_work = float(crop_def.harvest_work_seconds)
	for tile in _plots.keys():
		var plot: Dictionary = _plots[tile]
		if bool(plot.get("job_queued", false)):
			continue
		if StringName(plot.get("state", &"Empty")) != &"Mature":
			continue
		plot["job_queued"] = true
		_plots[tile] = plot
		var harvested_crop: StringName = StringName(plot.get("crop", crop_type))
		return {
			"type": &"HarvestCrop",
			"target": get_plot_world(tile),
			"zone_id": get_instance_id(),
			"tile": tile,
			"crop_type": harvested_crop,
			"work_duration": harvest_work
		}
	if crop_type == &"":
		return {}
	for tile in _plots.keys():
		var plot: Dictionary = _plots[tile]
		if bool(plot.get("job_queued", false)):
			continue
		var state: StringName = StringName(plot.get("state", &"Empty"))
		if state != &"Empty":
			continue
		plot["job_queued"] = true
		_plots[tile] = plot
		return {
			"type": &"PlantCrop",
			"target": get_plot_world(tile),
			"zone_id": get_instance_id(),
			"tile": tile,
			"crop_type": crop_type,
			"work_duration": plant_work
		}
	return {}

func clear_plot_job(tile: Vector2i) -> void:
	if not _plots.has(tile):
		return
	var plot: Dictionary = _plots[tile]
	plot["job_queued"] = false
	_plots[tile] = plot
	_emit_zone_updates()

func plant_crop(tile: Vector2i, planted_crop: StringName) -> bool:
	if not _plots.has(tile):
		return false
	var plot: Dictionary = _plots[tile]
	var state: StringName = StringName(plot.get("state", &"Empty"))
	if state != &"Empty":
		plot["job_queued"] = false
		_plots[tile] = plot
		return false
	plot["state"] = &"Growing"
	plot["elapsed"] = 0.0
	var last_crop: StringName = StringName(plot.get("last_crop", &""))
	var consecutive: int = int(plot.get("consecutive_crop", 0))
	if planted_crop == last_crop:
		consecutive += 1
	else:
		consecutive = 0
	plot["consecutive_crop"] = consecutive
	plot["last_crop"] = planted_crop
	plot["rotation_mult"] = clampf(0.92 + float(consecutive) * 0.07, 0.85, 1.35)
	plot["crop"] = planted_crop
	plot["job_queued"] = false
	_plots[tile] = plot
	_refresh_label()
	_refresh_plot_markers()
	_emit_zone_updates()
	return true

func harvest_crop(tile: Vector2i) -> Dictionary:
	if not _plots.has(tile):
		return {"resource_type": &"", "amount": 0}
	var plot: Dictionary = _plots[tile]
	var state: StringName = StringName(plot.get("state", &"Empty"))
	if state != &"Mature":
		plot["job_queued"] = false
		_plots[tile] = plot
		return {"resource_type": &"", "amount": 0}
	var harvested_crop: StringName = StringName(plot.get("crop", crop_type))
	plot["state"] = &"Empty"
	plot["elapsed"] = 0.0
	plot["crop"] = &""
	plot["job_queued"] = false
	_plots[tile] = plot
	_refresh_label()
	_refresh_plot_markers()
	_emit_zone_updates()
	if crop_catalog.has(harvested_crop):
		var crop_def: Resource = crop_catalog[harvested_crop]
		var support_yield_bonus: float = _nearby_farm_support_yield_bonus()
		var fertility_yield_mult: float = clampf(0.85 + (zone_fertility - 0.8) * 0.9, 0.75, 1.25)
		var final_amount: int = maxi(1, int(round(float(crop_def.yield_amount) * fertility_yield_mult * yield_multiplier * (1.0 + support_yield_bonus))))
		return {
			"resource_type": StringName(crop_def.yield_resource_type),
			"amount": final_amount
		}
	return {"resource_type": &"FoodRaw", "amount": 1}

func has_pending_job() -> bool:
	for tile in _plots.keys():
		var plot: Dictionary = _plots[tile]
		if bool(plot.get("job_queued", false)):
			continue
		var state: StringName = StringName(plot.get("state", &"Empty"))
		if state == &"Mature":
			return true
		if state == &"Empty" and crop_type != &"":
			return true
	return false

func _emit_zone_updates() -> void:
	zone_changed.emit(self)
	if has_pending_job():
		farm_job_needed.emit(self)

func _nearby_farm_support_growth_bonus() -> float:
	var bonus: float = 0.0
	for node in get_tree().get_nodes_in_group("farm_support_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var value: float = float(node.get_meta("farm_growth_bonus")) if node.has_meta("farm_growth_bonus") else 0.0
		if value <= 0.0:
			continue
		var support_range: float = float(node.get_meta("farm_support_range")) if node.has_meta("farm_support_range") else 160.0
		if global_position.distance_to(node.global_position) > support_range:
			continue
		bonus += value
	return clampf(bonus, 0.0, 0.6)

func _nearby_farm_support_yield_bonus() -> float:
	var bonus: float = 0.0
	for node in get_tree().get_nodes_in_group("farm_support_structures"):
		if node == null or not is_instance_valid(node):
			continue
		var value: float = float(node.get_meta("farm_yield_bonus")) if node.has_meta("farm_yield_bonus") else 0.0
		if value <= 0.0:
			continue
		var support_range: float = float(node.get_meta("farm_support_range")) if node.has_meta("farm_support_range") else 160.0
		if global_position.distance_to(node.global_position) > support_range:
			continue
		bonus += value
	return clampf(bonus, 0.0, 0.7)

func get_plot_world(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x) * tile_size, float(tile.y) * tile_size)

func get_plot_tile_from_world(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),
		int(round(world_pos.y / tile_size))
	)

func _refresh_shape() -> void:
	var half := zone_size * 0.5
	var p0 := Vector2(-half.x, -half.y)
	var p1 := Vector2(half.x, -half.y)
	var p2 := Vector2(half.x, half.y)
	var p3 := Vector2(-half.x, half.y)
	if fill_polygon != null:
		fill_polygon.polygon = PackedVector2Array([p0, p1, p2, p3])
	if outline != null:
		outline.points = PackedVector2Array([p0, p1, p2, p3, p0])
	_refresh_label()

func _refresh_label() -> void:
	if label == null:
		return
	var empty_count: int = 0
	var grow_count: int = 0
	var mature_count: int = 0
	for tile in _plots.keys():
		var state: StringName = StringName(_plots[tile].get("state", &"Empty"))
		if state == &"Mature":
			mature_count += 1
		elif state == &"Growing":
			grow_count += 1
		else:
			empty_count += 1
	label.text = "Farm (%s)\nE:%d G:%d M:%d F:%.2f" % [get_crop_display_name(), empty_count, grow_count, mature_count, zone_fertility]
	label.position = Vector2(-zone_size.x * 0.5 + 8.0, -zone_size.y * 0.5 - 36.0)

func _rebuild_plots() -> void:
	_plots.clear()
	var half: Vector2 = zone_size * 0.5
	var min_x: float = global_position.x - half.x
	var max_x: float = global_position.x + half.x
	var min_y: float = global_position.y - half.y
	var max_y: float = global_position.y + half.y
	var sx: int = int(round(min_x / tile_size))
	var ex: int = int(round(max_x / tile_size))
	var sy: int = int(round(min_y / tile_size))
	var ey: int = int(round(max_y / tile_size))
	for y in range(sy, ey + 1):
		for x in range(sx, ex + 1):
			var tile := Vector2i(x, y)
			var world: Vector2 = get_plot_world(tile)
			if world.x < min_x - 0.1 or world.x > max_x + 0.1:
				continue
			if world.y < min_y - 0.1 or world.y > max_y + 0.1:
				continue
			_plots[tile] = {
				"state": &"Empty",
				"crop": &"",
				"elapsed": 0.0,
				"job_queued": false,
				"last_crop": &"",
				"consecutive_crop": 0,
				"rotation_mult": 1.0
			}
	_refresh_plot_markers()

func _ensure_plot_marker_root() -> void:
	if _plot_marker_root != null and is_instance_valid(_plot_marker_root):
		return
	_plot_marker_root = Node2D.new()
	_plot_marker_root.name = "PlotMarkers"
	_plot_marker_root.z_index = 2
	add_child(_plot_marker_root)

func _refresh_plot_markers() -> void:
	_ensure_plot_marker_root()
	var stale_tiles: Array[Vector2i] = []
	for tile_any in _plot_markers.keys():
		var tile: Vector2i = tile_any
		if not _plots.has(tile):
			stale_tiles.append(tile)
			continue
		var plot: Dictionary = _plots[tile]
		var state: StringName = StringName(plot.get("state", &"Empty"))
		if state != &"Growing" and state != &"Mature":
			stale_tiles.append(tile)
	for tile in stale_tiles:
		var old_marker: Polygon2D = _plot_markers.get(tile, null)
		if old_marker != null and is_instance_valid(old_marker):
			old_marker.queue_free()
		_plot_markers.erase(tile)
	for tile_any in _plots.keys():
		var tile: Vector2i = tile_any
		var plot: Dictionary = _plots[tile]
		var state: StringName = StringName(plot.get("state", &"Empty"))
		if state != &"Growing" and state != &"Mature":
			continue
		var marker: Polygon2D = _plot_markers.get(tile, null)
		if marker == null or not is_instance_valid(marker):
			marker = Polygon2D.new()
			marker.name = "PlotMarker_%d_%d" % [tile.x, tile.y]
			_plot_marker_root.add_child(marker)
			_plot_markers[tile] = marker
		marker.position = to_local(get_plot_world(tile))
		_apply_plot_marker_style(marker, state)

func _apply_plot_marker_style(marker: Polygon2D, state: StringName) -> void:
	var size: float = 8.0
	var color: Color = Color(0.35, 0.86, 0.38, 0.88)
	if state == &"Mature":
		size = 12.0
		color = Color(0.96, 0.84, 0.26, 0.95)
	marker.polygon = PackedVector2Array([
		Vector2(0.0, -size),
		Vector2(size, 0.0),
		Vector2(0.0, size),
		Vector2(-size, 0.0)
	])
	marker.color = color
