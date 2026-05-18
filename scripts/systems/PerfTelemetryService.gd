extends Node
class_name PerfTelemetryService

var enabled: bool = false
var ring_size: int = 900
var _report_next_ms: int = 0
var _samples: Array[float] = []
var _samples_head: int = 0
var _samples_count: int = 0
var _last_ticks_usec: int = 0
var _combat_log_next_ms: int = 0
var _combat_window: Dictionary = {}

func setup(next_enabled: bool, next_ring_size: int) -> void:
	enabled = next_enabled
	ring_size = maxi(1, next_ring_size)
	reset_combat_window()

func start(now_ms: int, now_usec: int) -> void:
	_report_next_ms = now_ms + 5000
	_last_ticks_usec = now_usec
	reset_combat_window()

func record_frame(
	raid_state: StringName,
	enemy_count: int,
	colonist_count: int,
	engagement_coordinator: Node,
	pathing_occupancy: Node,
	enemy_flow_field_service: Node
) -> void:
	if not enabled:
		return
	var now_usec: int = Time.get_ticks_usec()
	var now_ms: int = Time.get_ticks_msec()
	_report_combat_window_if_due(now_ms, raid_state, enemy_count, colonist_count)
	if _last_ticks_usec <= 0:
		_last_ticks_usec = now_usec
		return
	var dt_real: float = float(now_usec - _last_ticks_usec) / 1000000.0
	_last_ticks_usec = now_usec
	if dt_real <= 0.0 or dt_real < 0.0015:
		return
	_store_frame_sample(dt_real)
	if now_ms < _report_next_ms:
		return
	if _samples_count <= 0:
		_report_next_ms = now_ms + 5000
		return
	_print_frame_report(raid_state)
	report_enemy_perf_snapshot(engagement_coordinator, pathing_occupancy, enemy_flow_field_service)
	_report_next_ms = now_ms + 5000

func report_enemy_perf_snapshot(engagement_coordinator: Node, pathing_occupancy: Node, enemy_flow_field_service: Node) -> void:
	var enemy_perf: Dictionary = EnemyUnitBase.consume_perf_stats()
	var coordinator_stats: Dictionary = {}
	if engagement_coordinator != null and is_instance_valid(engagement_coordinator) and engagement_coordinator.has_method("get_debug_stats"):
		coordinator_stats = engagement_coordinator.get_debug_stats()
	var occupancy_stats: Dictionary = {}
	if pathing_occupancy != null and is_instance_valid(pathing_occupancy) and pathing_occupancy.has_method("get_debug_stats"):
		occupancy_stats = pathing_occupancy.get_debug_stats()
	var flow_stats: Dictionary = {}
	if enemy_flow_field_service != null and is_instance_valid(enemy_flow_field_service) and enemy_flow_field_service.has_method("get_debug_stats"):
		flow_stats = enemy_flow_field_service.get_debug_stats()
	print("[Perf][Enemy] units=%d steps=%d move=%.2f ai=%.2f coord_req=%d coord_builds=%d coord_ms=%.2f dyn_block=%.2f dyn_units=%d flow_build=%.2f flow_exp=%d" % [
		int(enemy_perf.get("units", 0)),
		int(enemy_perf.get("steps", 0)),
		float(enemy_perf.get("move_ms", 0.0)),
		float(enemy_perf.get("ai_ms", 0.0)),
		int(coordinator_stats.get("requests", 0)),
		int(coordinator_stats.get("target_context_builds", 0)),
		float(coordinator_stats.get("total_request_ms", 0.0)),
		float(occupancy_stats.get("last_dynamic_ms", 0.0)),
		int(occupancy_stats.get("dynamic_units", 0)),
		float(flow_stats.get("last_build_ms", 0.0)),
		int(flow_stats.get("last_expansions", 0))
	])

func reset_combat_window() -> void:
	_combat_window = {
		"colonist_attempts": 0,
		"colonist_hits": 0,
		"colonist_damage": 0,
		"colonist_kills": 0,
		"colonist_ranged_attempts": 0,
		"colonist_ranged_hits": 0,
		"enemy_attempts": 0,
		"enemy_hits": 0,
		"enemy_damage": 0,
		"enemy_kills": 0
	}

func report_combat_event(source_side: StringName, hit: bool, damage: int, kill: bool, attack_mode: StringName = &"") -> void:
	if _combat_window.is_empty():
		reset_combat_window()
	if source_side == &"Colonist":
		_combat_window["colonist_attempts"] = int(_combat_window.get("colonist_attempts", 0)) + 1
		if attack_mode == &"CombatRanged" or attack_mode == &"Ranged":
			_combat_window["colonist_ranged_attempts"] = int(_combat_window.get("colonist_ranged_attempts", 0)) + 1
		if hit:
			_combat_window["colonist_hits"] = int(_combat_window.get("colonist_hits", 0)) + 1
			_combat_window["colonist_damage"] = int(_combat_window.get("colonist_damage", 0)) + maxi(0, damage)
			if attack_mode == &"CombatRanged" or attack_mode == &"Ranged":
				_combat_window["colonist_ranged_hits"] = int(_combat_window.get("colonist_ranged_hits", 0)) + 1
		if kill:
			_combat_window["colonist_kills"] = int(_combat_window.get("colonist_kills", 0)) + 1
		return
	if source_side == &"Enemy":
		_combat_window["enemy_attempts"] = int(_combat_window.get("enemy_attempts", 0)) + 1
		if hit:
			_combat_window["enemy_hits"] = int(_combat_window.get("enemy_hits", 0)) + 1
			_combat_window["enemy_damage"] = int(_combat_window.get("enemy_damage", 0)) + maxi(0, damage)
		if kill:
			_combat_window["enemy_kills"] = int(_combat_window.get("enemy_kills", 0)) + 1

func _store_frame_sample(dt_real: float) -> void:
	if _samples.size() < ring_size:
		_samples.append(dt_real)
		_samples_count = _samples.size()
	else:
		_samples[_samples_head] = dt_real
		_samples_head = (_samples_head + 1) % ring_size
		_samples_count = ring_size

func _print_frame_report(raid_state: StringName) -> void:
	var sorted_samples: Array = _samples.duplicate()
	sorted_samples.sort()
	var sum: float = 0.0
	for v_any in sorted_samples:
		sum += float(v_any)
	var sample_count: int = sorted_samples.size()
	var avg_dt: float = sum / float(sample_count)
	var p95_index: int = int(floor(float(sample_count - 1) * 0.95))
	var p95_dt: float = float(sorted_samples[clampi(p95_index, 0, sample_count - 1)])
	var p99_index: int = int(floor(float(sample_count - 1) * 0.99))
	var p99_dt: float = float(sorted_samples[clampi(p99_index, 0, sample_count - 1)])
	var fast_index: int = int(floor(float(sample_count - 1) * 0.02))
	var fast_dt: float = float(sorted_samples[clampi(fast_index, 0, sample_count - 1)])
	var max_dt: float = float(sorted_samples[sample_count - 1])
	var hitch_33: int = 0
	var hitch_100: int = 0
	var hitch_250: int = 0
	for sample_any in sorted_samples:
		var sample: float = float(sample_any)
		if sample >= (1.0 / 30.0):
			hitch_33 += 1
		if sample >= 0.1:
			hitch_100 += 1
		if sample >= 0.25:
			hitch_250 += 1
	var avg_fps: float = 1.0 / maxf(0.0001, avg_dt)
	var p95_fps: float = 1.0 / maxf(0.0001, p95_dt)
	var p99_fps: float = 1.0 / maxf(0.0001, p99_dt)
	var max_fps: float = 1.0 / maxf(0.0001, fast_dt)
	var render_fps: float = Engine.get_frames_per_second()
	print("[Perf][Wave] render_fps=%.1f avg_fps=%.1f p95_fps=%.1f p99_fps=%.1f peak_fps=%.1f max_dt_ms=%.1f hitch33=%d hitch100=%d hitch250=%d samples=%d raid=%s" % [
		render_fps, avg_fps, p95_fps, p99_fps, max_fps, max_dt * 1000.0, hitch_33, hitch_100, hitch_250, sample_count, String(raid_state)
	])

func _report_combat_window_if_due(now_ms: int, raid_state: StringName, enemy_count: int, colonist_count: int) -> void:
	if raid_state != &"Active":
		_combat_log_next_ms = 0
		reset_combat_window()
		return
	if _combat_log_next_ms <= 0:
		_combat_log_next_ms = now_ms + 5000
		return
	if now_ms < _combat_log_next_ms:
		return
	print("[Combat][Window] raid=%s enemies=%d colonists=%d c_att=%d c_hit=%d c_dmg=%d c_kill=%d c_rng_att=%d c_rng_hit=%d e_att=%d e_hit=%d e_dmg=%d e_kill=%d" % [
		String(raid_state),
		enemy_count,
		colonist_count,
		int(_combat_window.get("colonist_attempts", 0)),
		int(_combat_window.get("colonist_hits", 0)),
		int(_combat_window.get("colonist_damage", 0)),
		int(_combat_window.get("colonist_kills", 0)),
		int(_combat_window.get("colonist_ranged_attempts", 0)),
		int(_combat_window.get("colonist_ranged_hits", 0)),
		int(_combat_window.get("enemy_attempts", 0)),
		int(_combat_window.get("enemy_hits", 0)),
		int(_combat_window.get("enemy_damage", 0)),
		int(_combat_window.get("enemy_kills", 0))
	])
	reset_combat_window()
	_combat_log_next_ms = now_ms + 5000
