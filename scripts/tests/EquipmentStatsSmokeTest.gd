extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EQUIPMENT_STATS: Script = preload("res://scripts/core/EquipmentStats.gd")
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
	var bow_def: Resource = EQUIPMENT_STATS.get_resource_def(&"Bow")
	var sword_def: Resource = EQUIPMENT_STATS.get_resource_def(&"Sword")
	if bow_def == null or sword_def == null:
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: weapon resource definitions missing")
		return

	var fake_base: Dictionary = EQUIPMENT_STATS.make_colonist_base_profile(0.74, 4.0, 1.0)
	fake_base["ranged_range"] = 12.0
	fake_base["attack_cooldown_sec"] = 9.0
	var fake_bow: Dictionary = EQUIPMENT_STATS.apply_equipment_to_profile(fake_base, {&"Weapon": &"Bow"})
	if not is_equal_approx(float(fake_bow.get("ranged_range", 0.0)), float(bow_def.get("equipment_ranged_range"))):
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: bow range did not override base profile")
		return
	if not is_equal_approx(float(fake_bow.get("attack_cooldown_sec", 0.0)), float(bow_def.get("equipment_attack_cooldown_sec"))):
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: bow cooldown did not override base profile")
		return

	var main = MAIN_SCENE.instantiate()
	add_child(main)
	for _i in range(24):
		await get_tree().process_frame
	main._apply_passive_item_bonuses()
	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: no colonist spawned")
		return
	var colonist: Node = colonists[0]
	colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Bow"})
	var bow_profile: Dictionary = colonist.get_combat_profile()
	if StringName(bow_profile.get("weapon_mode", &"")) != &"Ranged":
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: bow did not set ranged mode")
		return
	if not is_equal_approx(float(bow_profile.get("ranged_range", 0.0)), float(bow_def.get("equipment_ranged_range"))):
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: colonist bow range was not resource-driven")
		return

	colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
	var sword_profile: Dictionary = colonist.get_combat_profile()
	if StringName(sword_profile.get("weapon_mode", &"")) != &"Melee":
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: sword did not set melee mode")
		return
	if not is_equal_approx(float(sword_profile.get("melee_range", 0.0)), float(sword_def.get("equipment_melee_range"))):
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: sword melee range was not resource-driven")
		return
	if not is_equal_approx(float(sword_profile.get("attack_cooldown_sec", 0.0)), float(sword_def.get("equipment_attack_cooldown_sec"))):
		_finish(false, "EQUIPMENT_STATS_TEST_FAIL: sword cooldown was not resource-driven")
		return

	_finish(true, "EQUIPMENT_STATS_TEST_PASS: equipment controls combat range and attack speed")
