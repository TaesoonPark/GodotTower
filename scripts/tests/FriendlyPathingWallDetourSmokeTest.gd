extends Node

const FRIENDLY_PATHING: Script = preload("res://scripts/core/pathing/FriendlyPathing.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 40.0

var _use_long_wall: bool = false

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _is_blocked(world_pos: Vector2) -> bool:
	var tile := Vector2i(
		int(round(world_pos.x / TILE_SIZE)),
		int(round(world_pos.y / TILE_SIZE))
	)
	if _use_long_wall:
		return tile.x == 2 and tile.y >= -20 and tile.y <= 20
	return tile.y == 0 and tile.x >= 1 and tile.x <= 3

func _run_test() -> void:
	var pathing = FRIENDLY_PATHING.new()
	pathing.setup(TILE_SIZE)
	var current := Vector2.ZERO
	var goal := Vector2(160.0, 0.0)
	var result: Dictionary = pathing.move_step(current, goal, 80.0, 0.1, Callable(self, "_is_blocked"))
	var first_pos: Vector2 = result.get("position", current)
	if bool(result.get("blocked", false)):
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: first step reported blocked")
		return
	if absf(first_pos.y) <= 0.1:
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: first step did not detour around wall pos=%s" % str(first_pos))
		return
	current = first_pos
	for _step in range(180):
		pathing.tick(0.05)
		result = pathing.move_step(current, goal, 80.0, 0.05, Callable(self, "_is_blocked"))
		current = result.get("position", current)
		if bool(result.get("blocked", false)):
			_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: detour became blocked pos=%s" % str(current))
			return
		if current.distance_to(goal) <= 0.75:
			break
	if current.distance_to(goal) > 0.75:
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: did not reach goal pos=%s" % str(current))
		return

	_use_long_wall = true
	pathing.clear()
	current = Vector2.ZERO
	for _step in range(700):
		pathing.tick(0.05)
		result = pathing.move_step(current, goal, 80.0, 0.05, Callable(self, "_is_blocked"))
		current = result.get("position", current)
		if bool(result.get("blocked", false)):
			_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: expanded detour became blocked pos=%s" % str(current))
			return
		if current.distance_to(goal) <= 0.75:
			_finish(true, "FRIENDLY_PATHING_WALL_DETOUR_PASS: pathing detours around blocking walls")
			return
	_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: expanded detour did not reach goal pos=%s" % str(current))
