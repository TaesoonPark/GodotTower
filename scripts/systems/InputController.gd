extends Node
class_name InputController

signal left_click(world_pos: Vector2)
signal drag_selection(start_pos: Vector2, end_pos: Vector2)
signal command_move(world_pos: Vector2)

var dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_end: Vector2 = Vector2.ZERO

func process_unhandled_input(event: InputEvent, world: Node2D) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = world.get_global_mouse_position()
			drag_end = drag_start
		else:
			if dragging and drag_start.distance_to(drag_end) < 12.0:
				left_click.emit(world.get_global_mouse_position())
			else:
				drag_selection.emit(drag_start, drag_end)
			dragging = false
	if event is InputEventMouseMotion and dragging:
		drag_end = world.get_global_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		command_move.emit(world.get_global_mouse_position())
