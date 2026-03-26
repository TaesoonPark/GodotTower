extends Node2D

const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")

@onready var world_root: Node2D = $WorldRoot
@onready var units_root: Node2D = $UnitsRoot
@onready var camera: Camera2D = $Camera2D
@onready var input_controller: Node = $Systems/InputController
@onready var need_system: Node = $Systems/NeedSystem
@onready var job_system: Node = $Systems/JobSystem
@onready var build_system: Node = $Systems/BuildSystem
@onready var hud: CanvasLayer = $HUD

var colonists: Array = []
var selected_colonists: Array = []
var camera_speed: float = 750.0
var build_mode: bool = false

func _ready() -> void:
	_spawn_initial_colonists()
	build_system.configure(world_root)
	input_controller.left_click.connect(_on_left_click)
	input_controller.drag_selection.connect(_on_drag_selection)
	input_controller.command_move.connect(_on_command_move)
	hud.priority_changed.connect(_on_priority_changed)
	hud.build_mode_toggled.connect(_on_build_mode_toggled)
	hud.set_selected_count(0)
	hud.set_needs_preview(null)
	hud.set_priority_preview(null)
	hud.set_build_mode(build_mode)

func _process(delta: float) -> void:
	_process_camera(delta)
	need_system.process_needs(delta, colonists)
	for colonist in colonists:
		colonist.update_job_completion()
		job_system.queue_need_jobs(colonist)
	build_system.request_build_jobs(job_system)
	job_system.assign_jobs(colonists)
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		build_mode = not build_mode
		hud.set_build_mode(build_mode)
		return
	input_controller.process_unhandled_input(event, world_root)
	if event is InputEventMouseMotion and input_controller.dragging:
		queue_redraw()

func _draw() -> void:
	if not input_controller.dragging:
		return
	var rect: Rect2 = Rect2(input_controller.drag_start, input_controller.drag_end - input_controller.drag_start).abs()
	draw_rect(rect, Color(0.3, 0.8, 1.0, 0.15), true)
	draw_rect(rect, Color(0.3, 0.8, 1.0), false, 2.0)

func _spawn_initial_colonists() -> void:
	var positions := [
		Vector2(1200, 650),
		Vector2(1260, 700),
		Vector2(1320, 650),
		Vector2(1200, 760)
	]
	for pos in positions:
		var c := COLONIST_SCENE.instantiate()
		c.global_position = pos
		c.status_changed.connect(_on_colonist_status_changed)
		units_root.add_child(c)
		colonists.append(c)

func _on_left_click(world_pos: Vector2) -> void:
	if build_mode:
		build_system.place_blueprint(world_pos)
		return
	var clicked: Node = _find_colonist_near(world_pos, 30.0)
	if clicked == null:
		_set_selected([])
	else:
		_set_selected([clicked])

func _on_drag_selection(start_pos: Vector2, end_pos: Vector2) -> void:
	var rect := Rect2(start_pos, end_pos - start_pos).abs()
	var picked: Array = []
	for colonist in colonists:
		if rect.has_point(colonist.global_position):
			picked.append(colonist)
	_set_selected(picked)
	queue_redraw()

func _on_command_move(world_pos: Vector2) -> void:
	if selected_colonists.is_empty():
		return
	var spacing: float = 34.0
	for i in range(selected_colonists.size()):
		var offset := Vector2((i % 3) - 1, int(i / 3.0)) * spacing
		job_system.issue_immediate_move(selected_colonists[i], world_pos + offset)

func _set_selected(new_selection: Array) -> void:
	for c in selected_colonists:
		if c != null:
			c.set_selected(false)
	selected_colonists = new_selection
	for c in selected_colonists:
		c.set_selected(true)
	_refresh_hud()

func _find_colonist_near(world_pos: Vector2, radius: float) -> Node:
	for colonist in colonists:
		if colonist.global_position.distance_to(world_pos) <= radius:
			return colonist
	return null

func _refresh_hud() -> void:
	hud.set_selected_count(selected_colonists.size())
	var focus: Node = selected_colonists[0] if not selected_colonists.is_empty() else null
	hud.set_needs_preview(focus)
	hud.set_priority_preview(focus)

func _on_priority_changed(job_type: StringName, value: int) -> void:
	for c in selected_colonists:
		match job_type:
			&"Haul":
				c.priorities.haul = value
			&"Build":
				c.priorities.build = value
			&"Craft":
				c.priorities.craft = value
			&"Combat":
				c.priorities.combat = value

func _on_colonist_status_changed(_colonist: Node) -> void:
	if selected_colonists.is_empty():
		return
	_refresh_hud()

func _on_build_mode_toggled(enabled: bool) -> void:
	build_mode = enabled

func _process_camera(delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	if input_vec != Vector2.ZERO:
		camera.global_position += input_vec.normalized() * camera_speed * delta
