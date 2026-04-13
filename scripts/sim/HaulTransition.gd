extends RefCounted
class_name HaulTransition

static func execute_pickup(
	job: Dictionary,
	drop_node: Object,
	zone_node: Object,
	carry_limit: int,
	pickup_more: Callable
) -> Dictionary:
	var pickup_amount: int = 0
	var pickup_type: StringName = &""
	var target_pickup: int = maxi(1, carry_limit)

	if drop_node != null and is_instance_valid(drop_node) and drop_node.has_method("take_amount"):
		pickup_type = StringName(drop_node.get("resource_type"))
		var requested_amount: int = int(drop_node.get("amount"))
		var accepted: int = mini(requested_amount, carry_limit)
		if zone_node != null and is_instance_valid(zone_node) and zone_node.has_method("preview_acceptable_amount"):
			target_pickup = int(zone_node.preview_acceptable_amount(pickup_type, carry_limit))
			accepted = mini(accepted, target_pickup)
		pickup_amount = int(drop_node.take_amount(accepted))
		if drop_node.has_method("is_empty") and bool(drop_node.is_empty()):
			(drop_node as Node).queue_free()
		elif drop_node.has_method("set_job_queued"):
			drop_node.set_job_queued(false)

	if pickup_type != &"" and pickup_amount > 0 and pickup_amount < target_pickup and pickup_more.is_valid():
		pickup_amount += int(pickup_more.call(pickup_type, target_pickup - pickup_amount))

	if pickup_amount <= 0 or pickup_type == &"":
		return {
			"status": &"empty"
		}

	var next_target: Vector2 = job.get("target", Vector2.ZERO)
	if zone_node != null and is_instance_valid(zone_node):
		next_target = zone_node.global_position if zone_node is Node2D else next_target
		if zone_node.has_method("get_drop_point"):
			next_target = zone_node.get_drop_point()

	var out: Dictionary = job.duplicate(true)
	out["carried_type"] = pickup_type
	out["carried_amount"] = pickup_amount
	out["phase"] = &"to_zone"
	out["target"] = next_target
	return {
		"status": &"to_zone",
		"job": out
	}

static func build_delivery_result(job: Dictionary) -> Dictionary:
	return {
		"resource_type": StringName(job.get("carried_type", &"")),
		"amount": int(job.get("carried_amount", 0))
	}
