extends Node
class_name CombatRaidService

var day_night_cycle_seconds: float = 240.0

func setup(next_day_night_cycle_seconds: float) -> void:
	day_night_cycle_seconds = maxf(0.01, next_day_night_cycle_seconds)

func compute_enemy_sim_interval_scale(raid_state: StringName, enemy_count: int) -> float:
	if raid_state != &"Active":
		return 1.0
	if enemy_count <= 16:
		return 1.0
	if enemy_count <= 32:
		return 1.25
	if enemy_count <= 56:
		return 1.55
	if enemy_count <= 84:
		return 1.9
	return 2.3

func compute_friendly_pathing_budget_scale(raid_state: StringName, enemy_count: int) -> float:
	if raid_state != &"Active":
		return 1.0
	if enemy_count <= 0:
		return 1.0
	if enemy_count <= 8:
		return 2.5
	if enemy_count <= 16:
		return 3.0
	return 3.5

func apply_enemy_sim_budget(enemies: Array, interval_scale: float) -> void:
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_sim_interval_scale"):
			enemy.set_sim_interval_scale(interval_scale)

func apply_friendly_pathing_budget(colonists: Array, scale: float) -> void:
	for colonist in colonists:
		if colonist == null or not is_instance_valid(colonist):
			continue
		if colonist.has_method("set_pathing_budget_scale"):
			colonist.set_pathing_budget_scale(scale)

func apply_day_night_to_enemies(enemies: Array, elapsed_game_seconds: float, night_slow_bonus: float) -> void:
	var t: float = _day_night_lerp(elapsed_game_seconds)
	var move_mul: float = lerpf(0.95, 1.05, t)
	if _is_night_time(elapsed_game_seconds):
		move_mul /= maxf(1.0, night_slow_bonus)
	var acc_bonus: float = lerpf(-0.02, 0.02, t)
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.has_method("set_external_move_speed_multiplier"):
			enemy.set_external_move_speed_multiplier(move_mul)
		if enemy.has_method("set_external_accuracy_bonus"):
			enemy.set_external_accuracy_bonus(acc_bonus)

func _is_night_time(elapsed_game_seconds: float) -> bool:
	var phase: float = fmod(elapsed_game_seconds, day_night_cycle_seconds)
	return phase >= (day_night_cycle_seconds * 0.5)

func _day_night_lerp(elapsed_game_seconds: float) -> float:
	var phase: float = fmod(elapsed_game_seconds, day_night_cycle_seconds) / day_night_cycle_seconds
	return 0.5 + 0.5 * cos(phase * TAU)
