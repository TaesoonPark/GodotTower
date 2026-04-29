extends Node

const FRIENDLY_PATHING: Script = preload("res://scripts/core/pathing/FriendlyPathing.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

var _block_mode: StringName = &"short_wall"
var _blocked_probe_count: int = 0

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
	_blocked_probe_count += 1
	var tile := Vector2i(
		int(round(world_pos.x / TILE_SIZE)),
		int(round(world_pos.y / TILE_SIZE))
	)
	if _block_mode == &"long_wall":
		return tile.x == 2 and tile.y >= -20 and tile.y <= 20
	if _block_mode == &"sealed_wall":
		return tile.x == 2 and tile.y >= -60 and tile.y <= 60
	if _block_mode == &"boxed_goal":
		var goal_tile := Vector2i(8, 0)
		return tile == goal_tile + Vector2i(1, 0) \
			or tile == goal_tile + Vector2i(-1, 0) \
			or tile == goal_tile + Vector2i(0, 1) \
			or tile == goal_tile + Vector2i(0, -1)
	return tile.y == 0 and tile.x >= 1 and tile.x <= 3

func _run_no_path_cache_test() -> bool:
	_block_mode = &"sealed_wall"
	var pathing = FRIENDLY_PATHING.new()
	pathing.setup(TILE_SIZE)
	var current := Vector2.ZERO
	var goal := Vector2(TILE_SIZE * 5.0, 0.0)
	var result: Dictionary = pathing.move_step(current, goal, 80.0, 0.1, Callable(self, "_is_blocked"))
	if not bool(result.get("blocked", false)):
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: sealed wall did not report blocked")
		return false
	pathing.tick(0.65)
	_blocked_probe_count = 0
	result = pathing.move_step(current, goal, 80.0, 0.1, Callable(self, "_is_blocked"))
	if not bool(result.get("blocked", false)):
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: cached sealed wall did not report blocked")
		return false
	if _blocked_probe_count > 80:
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: no-path retry probed too many tiles count=%d" % _blocked_probe_count)
		return false

	_block_mode = &"boxed_goal"
	pathing = FRIENDLY_PATHING.new()
	pathing.setup(TILE_SIZE)
	goal = Vector2(TILE_SIZE * 8.0, 0.0)
	_blocked_probe_count = 0
	result = pathing.move_step(current, goal, 80.0, 0.1, Callable(self, "_is_blocked"))
	if not bool(result.get("blocked", false)):
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: boxed goal did not report blocked")
		return false
	if _blocked_probe_count > 80:
		_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: boxed goal probed too many tiles count=%d" % _blocked_probe_count)
		return false
	return true

func _run_test() -> void:
	var pathing = FRIENDLY_PATHING.new()
	pathing.setup(TILE_SIZE)
	var current := Vector2.ZERO
	var goal := Vector2(TILE_SIZE * 4.0, 0.0)
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

	_block_mode = &"long_wall"
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
			if not _run_no_path_cache_test():
				return
			_finish(true, "FRIENDLY_PATHING_WALL_DETOUR_PASS: pathing detours around blocking walls and throttles no-path retries")
			return
	_finish(false, "FRIENDLY_PATHING_WALL_DETOUR_FAIL: expanded detour did not reach goal pos=%s" % str(current))
