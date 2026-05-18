extends Node
class_name SimulationDispatchService

func report_hitch(
	enabled: bool,
	raid_state: StringName,
	total_us: int,
	pathing_us: int,
	combat_us: int,
	traps_us: int,
	farm_us: int,
	maintenance_us: int,
	economy_us: int,
	jobs_us: int,
	hud_us: int,
	enemy_count: int
) -> void:
	if not enabled or raid_state != &"Active" or total_us < 40000:
		return
	print("[Perf][Hitch][Dispatch] total=%.2f pathing=%.2f combat=%.2f traps=%.2f farm=%.2f maintenance=%.2f economy=%.2f jobs=%.2f hud=%.2f enemies=%d" % [
		float(total_us) / 1000.0,
		float(pathing_us) / 1000.0,
		float(combat_us) / 1000.0,
		float(traps_us) / 1000.0,
		float(farm_us) / 1000.0,
		float(maintenance_us) / 1000.0,
		float(economy_us) / 1000.0,
		float(jobs_us) / 1000.0,
		float(hud_us) / 1000.0,
		enemy_count
	])
