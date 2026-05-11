extends Node

const JOB_PRIORITY_SCRIPT: Script = preload("res://scripts/data/JobPriorityData.gd")
const JOB_SCORING: Script = preload("res://scripts/sim/JobScoring.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	var priorities = JOB_PRIORITY_SCRIPT.new()
	if priorities.get_priority(&"CombatMelee") != priorities.combat:
		_finish(false, "COMBAT_PRIORITY_ALIAS_FAIL: melee combat uses wrong priority")
		return
	if priorities.get_priority(&"CombatRanged") != priorities.combat:
		_finish(false, "COMBAT_PRIORITY_ALIAS_FAIL: ranged combat uses wrong priority")
		return

	var origin := Vector2.ZERO
	var combat_score: float = JOB_SCORING.score_job(
		{
			"type": &"CombatMelee",
			"target": origin,
			"base_priority": 13
		},
		origin,
		priorities.get_priority(&"CombatMelee"),
		priorities.get_priority(&"Build"),
		priorities.get_priority(&"Craft"),
		priorities.get_priority(&"Combat"),
		priorities.get_priority(&"Gather")
	)
	var trap_score: float = JOB_SCORING.score_job(
		{
			"type": &"MaintainTrap",
			"target": origin,
			"base_priority": 10
		},
		origin,
		priorities.get_priority(&"MaintainTrap"),
		priorities.get_priority(&"Build"),
		priorities.get_priority(&"Craft"),
		priorities.get_priority(&"Combat"),
		priorities.get_priority(&"Gather")
	)
	if combat_score <= trap_score:
		_finish(false, "COMBAT_PRIORITY_ALIAS_FAIL: combat did not outrank trap maintenance")
		return
	_finish(true, "COMBAT_PRIORITY_ALIAS_PASS: combat job aliases outrank trap maintenance")
