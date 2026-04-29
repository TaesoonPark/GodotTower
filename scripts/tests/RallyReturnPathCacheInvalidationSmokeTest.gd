extends Node

const FRIENDLY_PATHING: Script = preload("res://scripts/core/pathing/FriendlyPathing.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

var _block_cached_first_step: bool = false

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
	if not _block_cached_first_step:
		return false
	var tile := Vector2i(
		int(round(world_pos.x / TILE_SIZE)),
		int(round(world_pos.y / TILE_SIZE))
	)
	return tile == Vector2i(1, 0)

func _run_test() -> void:
	var start := Vector2.ZERO
	var rally_target := Vector2(160.0, 0.0)

	var warm_pathing = FRIENDLY_PATHING.new()
	warm_pathing.setup(TILE_SIZE)
	var warm_result: Dictionary = warm_pathing.move_step(start, rally_target, 80.0, 0.1, Callable(self, "_is_blocked"))
	if bool(warm_result.get("blocked", false)):
		_finish(false, "RALLY_RETURN_PATH_CACHE_INVALIDATION_FAIL: warm path unexpectedly blocked")
		return

	_block_cached_first_step = true
	var return_pathing = FRIENDLY_PATHING.new()
	return_pathing.setup(TILE_SIZE)
	var result: Dictionary = return_pathing.move_step(start, rally_target, 80.0, 0.1, Callable(self, "_is_blocked"))
	var next_pos: Vector2 = result.get("position", start)
	if bool(result.get("blocked", false)):
		_finish(false, "RALLY_RETURN_PATH_CACHE_INVALIDATION_FAIL: cached blocker caused blocked return")
		return
	if absf(next_pos.y) <= 0.1:
		_finish(false, "RALLY_RETURN_PATH_CACHE_INVALIDATION_FAIL: return reused stale straight cache pos=%s" % str(next_pos))
		return

	for _step in range(240):
		return_pathing.tick(0.05)
		result = return_pathing.move_step(next_pos, rally_target, 80.0, 0.05, Callable(self, "_is_blocked"))
		next_pos = result.get("position", next_pos)
		if bool(result.get("blocked", false)):
			_finish(false, "RALLY_RETURN_PATH_CACHE_INVALIDATION_FAIL: detour became blocked pos=%s" % str(next_pos))
			return
		if next_pos.distance_to(rally_target) <= 0.75:
			_finish(true, "RALLY_RETURN_PATH_CACHE_INVALIDATION_PASS: rally return invalidates stale cached blocker path")
			return

	_finish(false, "RALLY_RETURN_PATH_CACHE_INVALIDATION_FAIL: detour did not reach rally target pos=%s" % str(next_pos))
