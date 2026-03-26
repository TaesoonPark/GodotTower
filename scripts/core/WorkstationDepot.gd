extends Node2D
class_name WorkstationDepot

var workstation_id: StringName = &""
var stored: Dictionary = {}
var requested: Dictionary = {}
var pending: Dictionary = {}
var zone_priority: int = 40

func setup(id: StringName, pos: Vector2) -> void:
	workstation_id = id
	global_position = pos

func set_requested_ingredients(next_requested: Dictionary) -> void:
	requested = {}
	for k in next_requested.keys():
		var amount: int = maxi(0, int(next_requested[k]))
		if amount <= 0:
			continue
		requested[StringName(k)] = amount

func get_requested_amount(resource_type: StringName) -> int:
	return int(requested.get(resource_type, 0))

func get_pending_amount(resource_type: StringName) -> int:
	return int(pending.get(resource_type, 0))

func get_stored_amount(resource_type: StringName) -> int:
	return int(stored.get(resource_type, 0))

func get_zone_priority() -> int:
	return zone_priority

func get_drop_point() -> Vector2:
	return global_position

func accepts_resource(resource_type: StringName) -> bool:
	var need: int = int(requested.get(resource_type, 0))
	if need <= 0:
		return false
	return get_stored_amount(resource_type) < need

func preview_acceptable_amount(resource_type: StringName, request_amount: int) -> int:
	if request_amount <= 0:
		return 0
	if not requested.has(resource_type):
		return 0
	var need: int = int(requested[resource_type])
	var left: int = maxi(0, need - get_stored_amount(resource_type))
	return mini(left, request_amount)

func mark_supply_spawned(resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	pending[resource_type] = get_pending_amount(resource_type) + amount

func add_resource(resource_type: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var accepted: int = preview_acceptable_amount(resource_type, amount)
	if accepted <= 0:
		return 0
	stored[resource_type] = get_stored_amount(resource_type) + accepted
	var left_pending: int = maxi(0, get_pending_amount(resource_type) - accepted)
	if left_pending <= 0:
		pending.erase(resource_type)
	else:
		pending[resource_type] = left_pending
	return accepted

func can_start_recipe(ingredients: Dictionary) -> bool:
	for k in ingredients.keys():
		var need: int = int(ingredients[k])
		if get_stored_amount(StringName(k)) < need:
			return false
	return true

func consume_for_recipe(ingredients: Dictionary) -> void:
	for k in ingredients.keys():
		var key: StringName = StringName(k)
		var need: int = maxi(0, int(ingredients[k]))
		if need <= 0:
			continue
		var have: int = get_stored_amount(key)
		var next: int = maxi(0, have - need)
		if next <= 0:
			stored.erase(key)
		else:
			stored[key] = next
