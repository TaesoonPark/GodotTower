extends Node

const COLONIST_SCENE: PackedScene = preload("res://scenes/units/Colonist.tscn")
const RESOURCE_DROP_SCENE: PackedScene = preload("res://scenes/world/ResourceDrop.tscn")
const HANDCART_SCRIPT: Script = preload("res://scripts/core/Handcart.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

class DummyZone:
	extends Node2D

	func preview_acceptable_amount(_resource_type: StringName, request_amount: int) -> int:
		return maxi(0, request_amount)

	func get_drop_point() -> Vector2:
		return global_position

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
	var colonist: Node2D = COLONIST_SCENE.instantiate()
	add_child(colonist)
	colonist.global_position = Vector2.ZERO

	var drop: Node2D = RESOURCE_DROP_SCENE.instantiate()
	add_child(drop)
	drop.global_position = Vector2.ZERO
	if drop.has_method("setup_drop"):
		drop.setup_drop(&"Wood", 200)

	var zone := DummyZone.new()
	add_child(zone)
	zone.global_position = Vector2(440.0, 0.0)

	var handcart: Node2D = HANDCART_SCRIPT.new()
	add_child(handcart)
	handcart.global_position = Vector2(12.0, 0.0)

	await get_tree().process_frame
	await get_tree().process_frame

	var base_capacity: int = maxi(1, int(colonist.stats.haul_carry_capacity))
	var cart_bonus: int = int(handcart.get_carry_bonus()) if handcart.has_method("get_carry_bonus") else 0
	var owner_id: int = colonist.get_instance_id()
	if handcart.has_method("assign_owner"):
		if not bool(handcart.assign_owner(owner_id)):
			_finish(false, "HANDCART_HAUL_FAIL: failed to assign handcart owner")
			return
	else:
		handcart.set_meta("assigned_colonist_id", owner_id)
	colonist.assign_job({
		"type": &"HaulResource",
		"target": drop.global_position,
		"drop_id": drop.get_instance_id(),
		"zone_id": zone.get_instance_id(),
		"phase": &"to_drop",
		"base_priority": 8,
		"assigned_to": owner_id
	})

	await get_tree().process_frame
	var assigned_cart_id: int = int(colonist.current_job.get("handcart_id", 0))
	if assigned_cart_id != handcart.get_instance_id():
		_finish(false, "HANDCART_HAUL_FAIL: haul job did not reserve nearest handcart")
		return

	colonist.update_job_completion(0.0)
	var carried_amount: int = int(colonist.current_job.get("carried_amount", 0))
	var expected_amount: int = base_capacity + maxi(0, cart_bonus)
	if carried_amount != expected_amount:
		_finish(false, "HANDCART_HAUL_FAIL: expected carry %d, got %d" % [expected_amount, carried_amount])
		return

	var handcart_before: Vector2 = handcart.global_position
	colonist.global_position += Vector2(100.0, 0.0)
	for _i in range(8):
		await get_tree().process_frame
	var handcart_after: Vector2 = handcart.global_position
	if handcart_after.distance_to(handcart_before) < 8.0:
		_finish(false, "HANDCART_HAUL_FAIL: handcart did not follow colonist movement")
		return
	var colonist_after: Vector2 = colonist.global_position
	if handcart_after.distance_to(colonist_after) > 80.0:
		_finish(false, "HANDCART_HAUL_FAIL: handcart drifted too far from colonist")
		return

	colonist.global_position = Vector2(colonist.current_job.get("target", zone.global_position))
	colonist.update_job_completion(0.0)
	await get_tree().process_frame
	if handcart.has_method("is_owned_by") and not bool(handcart.is_owned_by(owner_id)):
		_finish(false, "HANDCART_HAUL_FAIL: manual owner link was lost after delivery")
		return
	if handcart.has_meta("assigned_colonist_id") and int(handcart.get_meta("assigned_colonist_id")) != owner_id:
		_finish(false, "HANDCART_HAUL_FAIL: owner metadata mismatch after delivery")
		return

	_finish(true, "HANDCART_HAUL_PASS: assigned handcart follows colonist and boosts haul capacity")
