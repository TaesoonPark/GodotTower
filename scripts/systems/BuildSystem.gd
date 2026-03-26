extends Node
class_name BuildSystem

const BUILDING_SITE_SCENE: PackedScene = preload("res://scenes/world/BuildingSite.tscn")

var _world_root: Node2D = null
var _sites: Array = []
var grid_size: float = 40.0

func configure(world_root: Node2D) -> void:
	_world_root = world_root

func place_blueprint(world_pos: Vector2) -> void:
	if _world_root == null:
		return
	var snapped_pos := Vector2(
		round(world_pos.x / grid_size) * grid_size,
		round(world_pos.y / grid_size) * grid_size
	)
	if _has_site_near(snapped_pos, 16.0):
		return
	var site = BUILDING_SITE_SCENE.instantiate()
	site.global_position = snapped_pos
	_world_root.add_child(site)
	_sites.append(site)

func request_build_jobs(job_system: Node) -> void:
	_sites = _sites.filter(func(s): return s != null and is_instance_valid(s))
	for site in _sites:
		if site.complete:
			continue
		if site.job_queued:
			continue
		job_system.queue_build_job(site)
		site.set_job_queued(true)

func _has_site_near(pos: Vector2, radius: float) -> bool:
	for site in _sites:
		if site == null or not is_instance_valid(site):
			continue
		if site.global_position.distance_to(pos) <= radius:
			return true
	return false
