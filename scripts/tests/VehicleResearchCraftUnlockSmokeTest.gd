extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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
	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(24):
		await get_tree().process_frame

	var bench_id: StringName = &"SimpleBenchStation"
	var recipe_id: StringName = &"MakeBicycle"
	if not main.recipe_lookup.has(recipe_id):
		_finish(false, "VEHICLE_RESEARCH_CRAFT_FAIL: bicycle recipe definition missing")
		return

	var before_recipes: Array = main._filter_recipes_for_workstation(bench_id)
	for recipe in before_recipes:
		if recipe != null and StringName(recipe.id) == recipe_id:
			_finish(false, "VEHICLE_RESEARCH_CRAFT_FAIL: bicycle recipe unlocked before research")
			return

	main.job_system.clear_craft_queue(bench_id)
	main._on_craft_recipe_queued(recipe_id, bench_id)
	if not main.job_system.get_craft_queue(bench_id).is_empty():
		_finish(false, "VEHICLE_RESEARCH_CRAFT_FAIL: locked bicycle recipe was queued")
		return

	main._research_completed[&"BicycleI"] = true
	var after_recipes: Array = main._filter_recipes_for_workstation(bench_id)
	var unlocked: bool = false
	for recipe in after_recipes:
		if recipe != null and StringName(recipe.id) == recipe_id:
			unlocked = true
			break
	if not unlocked:
		_finish(false, "VEHICLE_RESEARCH_CRAFT_FAIL: bicycle recipe not unlocked after research")
		return

	main._on_craft_recipe_queued(recipe_id, bench_id)
	var queued: Array = main.job_system.get_craft_queue(bench_id)
	if queued.is_empty() or StringName(queued[0].get("recipe_id", &"")) != recipe_id:
		_finish(false, "VEHICLE_RESEARCH_CRAFT_FAIL: unlocked bicycle recipe was not queued")
		return

	_finish(true, "VEHICLE_RESEARCH_CRAFT_PASS: bicycle recipe is research-gated and queueable")
