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

	var colonist: Node2D = main.colonists[0]
	colonist.cancel_current_job()
	var bike: Node2D = main._spawn_vehicle(&"Bicycle", colonist.global_position)
	if bike == null or not bool(main._request_vehicle_use(bike, colonist)):
		_finish(false, "VEHICLE_DAMAGE_FAIL: setup mount failed")
		return
	await get_tree().process_frame
	var colonist_health: float = float(colonist.health)
	colonist.apply_combat_damage(15)
	await get_tree().process_frame
	if not is_equal_approx(float(colonist.health), colonist_health):
		_finish(false, "VEHICLE_DAMAGE_FAIL: rider health changed while mounted")
		return
	if not is_equal_approx(float(bike.get("health")), 65.0):
		_finish(false, "VEHICLE_DAMAGE_FAIL: vehicle health did not absorb damage")
		return

	colonist.apply_combat_damage(999)
	await get_tree().process_frame
	if bool(colonist.is_mounted()):
		_finish(false, "VEHICLE_DAMAGE_FAIL: rider stayed mounted after vehicle destruction")
		return
	if not bool(colonist.is_stunned()):
		_finish(false, "VEHICLE_DAMAGE_FAIL: rider was not stunned after vehicle destruction")
		return
	if float(colonist.get_stun_remaining_seconds()) < 2.5:
		_finish(false, "VEHICLE_DAMAGE_FAIL: destroy stun duration too short")
		return
	if not is_equal_approx(float(colonist.health), colonist_health):
		_finish(false, "VEHICLE_DAMAGE_FAIL: overflow damage leaked to rider")
		return

	_finish(true, "VEHICLE_DAMAGE_PASS: mounted damage redirects to bicycle and destruction stuns rider")
