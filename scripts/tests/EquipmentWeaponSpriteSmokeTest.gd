extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
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
	for _i in range(20):
		await get_tree().process_frame

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: no colonist spawned")
		return
	var colonist: Node2D = colonists[0] as Node2D
	if colonist == null:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: colonist is not Node2D")
		return
	var weapon_sprite: Sprite2D = colonist.get_node_or_null("WeaponSprite") as Sprite2D
	if weapon_sprite == null:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: WeaponSprite node missing")
		return

	colonist.cancel_current_job()
	colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &""})
	await get_tree().process_frame
	if weapon_sprite.visible:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: weapon visible while idle without weapon")
		return

	var zombie = ZOMBIE_SCENE.instantiate()
	zombie.global_position = colonist.global_position + Vector2(80.0, 0.0)
	main.units_root.add_child(zombie)

	colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Sword"})
	colonist.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": 0
	})
	await get_tree().process_frame
	if weapon_sprite.visible:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: sword overlay visible during combat")
		return

	colonist.cancel_current_job()
	await get_tree().process_frame
	if weapon_sprite.visible:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: weapon overlay visible after combat cancel")
		return

	zombie.global_position = colonist.global_position + Vector2(-80.0, 0.0)
	colonist.set_equipment_slots({&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &"Rifle"})
	colonist.assign_job({
		"type": &"CombatMelee",
		"target": zombie.global_position,
		"target_id": zombie.get_instance_id(),
		"base_priority": 13,
		"assigned_to": 0
	})
	await get_tree().process_frame
	if weapon_sprite.visible:
		_finish(false, "EQUIPMENT_WEAPON_SPRITE_FAIL: rifle overlay visible during combat")
		return

	_finish(true, "EQUIPMENT_WEAPON_SPRITE_PASS: weapon overlay remains hidden while equipment data is active")
