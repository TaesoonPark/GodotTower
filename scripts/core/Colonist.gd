extends Node2D

signal status_changed(colonist: Node)

@export var stats: Resource
@export var priorities: Resource
@export var sprite_height: float = 72.0

var health: float = 100.0
var hunger: float = 100.0
var rest: float = 100.0
var mood: float = 100.0

var selected: bool = false
var current_job: Dictionary = {}

@onready var nav: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("colonists")
	if stats == null:
		stats = load("res://scripts/data/ColonistStatsData.gd").new()
	if priorities == null:
		priorities = load("res://scripts/data/JobPriorityData.gd").new()
	health = stats.max_health
	_fit_sprite()
	emit_status()

func _physics_process(delta: float) -> void:
	_process_movement(delta)

func _process_movement(delta: float) -> void:
	if nav.is_navigation_finished():
		return
	var next_pos: Vector2 = nav.get_next_path_position()
	var dir: Vector2 = global_position.direction_to(next_pos)
	global_position += dir * stats.move_speed * delta
	if global_position.distance_to(next_pos) < 4.0:
		global_position = next_pos

func tick_needs(delta: float) -> void:
	hunger = clampf(hunger - stats.hunger_decay_per_sec * delta, 0.0, 100.0)
	rest = clampf(rest - stats.rest_decay_per_sec * delta, 0.0, 100.0)
	var mood_penalty: float = (100.0 - hunger) * 0.01 + (100.0 - rest) * 0.008
	mood = clampf(mood - (stats.mood_decay_per_sec + mood_penalty) * delta, 0.0, 100.0)
	emit_status()

func get_priority(job_type: StringName) -> int:
	return priorities.get_priority(job_type)

func assign_job(job: Dictionary) -> void:
	current_job = job
	var job_type: StringName = job.get("type", &"Idle")
	match job_type:
		&"MoveTo":
			var target: Vector2 = job.get("target", global_position)
			nav.target_position = target
		&"BuildSite":
			var build_target: Vector2 = job.get("target", global_position)
			nav.target_position = build_target
		&"EatStub":
			hunger = clampf(hunger + 35.0, 0.0, 100.0)
			mood = clampf(mood + 10.0, 0.0, 100.0)
			current_job.clear()
		&"IdleRecover":
			rest = clampf(rest + 20.0, 0.0, 100.0)
			current_job.clear()
	emit_status()

func cancel_current_job() -> void:
	if current_job.is_empty():
		nav.target_position = global_position
		return
	var job_type: StringName = current_job.get("type", &"")
	if job_type == &"BuildSite":
		var site_id: int = int(current_job.get("site_id", 0))
		if site_id != 0:
			var site: Object = instance_from_id(site_id)
			if site != null and is_instance_valid(site):
				site.set_job_queued(false)
	current_job.clear()
	nav.target_position = global_position
	emit_status()

func is_idle() -> bool:
	return current_job.is_empty() and nav.is_navigation_finished()

func update_job_completion() -> void:
	if current_job.is_empty():
		return
	var job_type: StringName = current_job.get("type", &"")
	if job_type == &"MoveTo" and nav.is_navigation_finished():
		current_job.clear()
		emit_status()
	elif job_type == &"BuildSite" and nav.is_navigation_finished():
		var site_id: int = int(current_job.get("site_id", 0))
		if site_id != 0:
			var site: Object = instance_from_id(site_id)
			if site != null and is_instance_valid(site):
				site.apply_work(55.0)
				if not site.complete:
					site.set_job_queued(false)
		current_job.clear()
		emit_status()

func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()

func emit_status() -> void:
	status_changed.emit(self)

func _draw() -> void:
	if not selected:
		return
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 48, Color(0.35, 0.9, 1.0), 2.0)

func _fit_sprite() -> void:
	if sprite.texture == null:
		return
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.y <= 0.0:
		return
	var scale_factor: float = sprite_height / tex_size.y
	sprite.scale = Vector2(scale_factor, scale_factor)
