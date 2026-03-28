extends Node2D
class_name StockpileZone

signal stockpile_changed(zone: Node)

@export var min_zone_size: float = 32.0
@export var resource_keys: Array[StringName] = [
	&"Wood", &"Stone", &"Steel", &"FoodRaw", &"Meal", &"Bed",
	&"GatherTop", &"GatherBottom", &"StrawHat", &"Weapon",
	&"CombatTop", &"CombatBottom", &"CombatHat", &"Sword", &"Bow"
]

enum FilterMode {
	ALL = 0,
	ALLOW_ONLY = 1,
	DENY_LIST = 2
}

var zone_size: Vector2 = Vector2(120, 80)
var stored: Dictionary = {}
var filter_mode: int = FilterMode.ALL
var filter_types: Array[StringName] = []
var zone_priority: int = 0
var resource_limits: Dictionary = {}
var preset_id: StringName = &"All"

@onready var fill_polygon: Polygon2D = $Fill
@onready var outline: Line2D = $Outline
@onready var label: Label = $Label
var _stack_root: Node2D = null
var _stack_slots: Array[Dictionary] = []
var _stack_texture_cache: Dictionary = {}
var _last_stack_signature: String = ""

func setup_from_rect(rect: Rect2) -> void:
	var safe_rect := rect.abs()
	zone_size = Vector2(
		maxf(min_zone_size, safe_rect.size.x),
		maxf(min_zone_size, safe_rect.size.y)
	)
	global_position = safe_rect.get_center()
	if is_node_ready():
		_refresh_shape()
	stockpile_changed.emit(self)

func _ready() -> void:
	add_to_group("stockpile_zones")
	for k in resource_keys:
		if not resource_limits.has(k):
			resource_limits[k] = -1
	_refresh_shape()

func _refresh_shape() -> void:
	var half := zone_size * 0.5
	var p0 := Vector2(-half.x, -half.y)
	var p1 := Vector2(half.x, -half.y)
	var p2 := Vector2(half.x, half.y)
	var p3 := Vector2(-half.x, half.y)
	var fill_node: Polygon2D = fill_polygon if fill_polygon != null else get_node_or_null("Fill")
	var outline_node: Line2D = outline if outline != null else get_node_or_null("Outline")
	var label_node: Label = label if label != null else get_node_or_null("Label")
	if fill_node != null:
		fill_node.polygon = PackedVector2Array([p0, p1, p2, p3])
	if outline_node != null:
		outline_node.points = PackedVector2Array([p0, p1, p2, p3, p0])
	if label_node != null:
		label_node.text = "Stockpile"
		label_node.position = Vector2(-half.x + 8.0, -half.y - 22.0)
	_ensure_stack_root()
	_update_label()

func contains_point(world_point: Vector2) -> bool:
	var local: Vector2 = to_local(world_point)
	return absf(local.x) <= zone_size.x * 0.5 and absf(local.y) <= zone_size.y * 0.5

func get_drop_point() -> Vector2:
	return global_position

func add_resource(resource_type: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var accepted: int = preview_acceptable_amount(resource_type, amount)
	if accepted <= 0:
		return 0
	if not stored.has(resource_type):
		stored[resource_type] = 0
	stored[resource_type] += accepted
	_update_label()
	stockpile_changed.emit(self)
	return accepted

func remove_resource(resource_type: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var current: int = int(stored.get(resource_type, 0))
	if current <= 0:
		return 0
	var removed: int = mini(current, amount)
	stored[resource_type] = current - removed
	if int(stored[resource_type]) <= 0:
		stored.erase(resource_type)
	_update_label()
	stockpile_changed.emit(self)
	return removed

func get_stored_amount(resource_type: StringName) -> int:
	return int(stored.get(resource_type, 0))

func get_stored_snapshot() -> Dictionary:
	return stored.duplicate(true)

func get_resource_at_point(world_point: Vector2) -> StringName:
	var local_point: Vector2 = to_local(world_point)
	for i in range(_stack_slots.size() - 1, -1, -1):
		var slot: Dictionary = _stack_slots[i]
		var slot_rect: Rect2 = slot.get("rect", Rect2())
		if slot_rect.has_point(local_point):
			return StringName(slot.get("resource_type", &""))
	return &""

func accepts_resource(resource_type: StringName) -> bool:
	match filter_mode:
		FilterMode.ALL:
			return true
		FilterMode.ALLOW_ONLY:
			# Treat empty allow-list as "not configured yet", so hauling does not stall.
			if filter_types.is_empty():
				return true
			return filter_types.has(resource_type)
		FilterMode.DENY_LIST:
			return not filter_types.has(resource_type)
		_:
			return true

func preview_acceptable_amount(resource_type: StringName, request_amount: int) -> int:
	if request_amount <= 0:
		return 0
	if not accepts_resource(resource_type):
		return 0
	var limit: int = int(resource_limits.get(resource_type, -1))
	if limit < 0:
		return request_amount
	var current: int = int(stored.get(resource_type, 0))
	var left: int = maxi(0, limit - current)
	return mini(request_amount, left)

func get_zone_priority() -> int:
	return zone_priority

func set_zone_priority(value: int) -> void:
	zone_priority = clampi(value, -10, 10)
	_update_label()
	stockpile_changed.emit(self)

func set_resource_limit(resource_type: StringName, limit: int) -> void:
	resource_limits[resource_type] = max(-1, limit)
	_update_label()
	stockpile_changed.emit(self)

func set_filter_mode(new_mode: int) -> void:
	filter_mode = clampi(new_mode, FilterMode.ALL, FilterMode.DENY_LIST)
	_update_label()
	stockpile_changed.emit(self)

func set_filter_item(resource_type: StringName, enabled: bool) -> void:
	if enabled:
		if not filter_types.has(resource_type):
			filter_types.append(resource_type)
	else:
		filter_types = filter_types.filter(func(v: StringName): return v != resource_type)
	_update_label()
	stockpile_changed.emit(self)

func get_filter_snapshot() -> Dictionary:
	var map: Dictionary = {}
	var limits: Dictionary = {}
	for k in resource_keys:
		map[k] = filter_types.has(k)
		limits[k] = int(resource_limits.get(k, -1))
	return {
		"mode": filter_mode,
		"items": map,
		"limits": limits,
		"priority": zone_priority,
		"preset_id": preset_id
	}

func apply_preset(next_preset: StringName) -> void:
	preset_id = next_preset
	filter_types.clear()
	filter_mode = FilterMode.ALL
	match next_preset:
		&"Food":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [&"FoodRaw", &"Meal"]
			zone_priority = 4
		&"War":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [
				&"CombatTop", &"CombatBottom", &"CombatHat",
				&"Sword", &"Bow", &"Steel", &"Wood"
			]
			zone_priority = 2
		&"Build":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [&"Wood", &"Stone", &"Steel", &"Bed"]
			zone_priority = 3
		&"Industry":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [&"Steel", &"Stone", &"Wood", &"Weapon", &"Sword", &"Bow"]
			zone_priority = 1
		&"Emergency":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [&"Meal", &"FoodRaw", &"CombatTop", &"CombatBottom", &"CombatHat", &"Bow", &"Sword"]
			zone_priority = 6
		&"Harvest":
			filter_mode = FilterMode.ALLOW_ONLY
			filter_types = [&"FoodRaw", &"Meal"]
			zone_priority = 3
		_:
			preset_id = &"All"
			filter_mode = FilterMode.ALL
			zone_priority = 0
	_update_label()
	stockpile_changed.emit(self)

func _update_label() -> void:
	var label_node: Label = label if label != null else get_node_or_null("Label")
	if label_node != null:
		label_node.text = "Stockpile"
	var sig: String = _stack_signature()
	if sig == _last_stack_signature:
		return
	_last_stack_signature = sig
	_rebuild_stack_visuals()

func _ensure_stack_root() -> void:
	if _stack_root != null and is_instance_valid(_stack_root):
		return
	_stack_root = Node2D.new()
	_stack_root.name = "StackRoot"
	add_child(_stack_root)

func _rebuild_stack_visuals() -> void:
	_ensure_stack_root()
	_stack_slots.clear()
	for child in _stack_root.get_children():
		child.queue_free()
	var non_empty: Array[StringName] = []
	for k in stored.keys():
		if int(stored[k]) > 0:
			non_empty.append(StringName(k))
	non_empty.sort_custom(func(a, b): return String(a) < String(b))
	var half: Vector2 = zone_size * 0.5
	var cols: int = maxi(1, int(floor(zone_size.x / 78.0)))
	for i in range(non_empty.size()):
		var key: StringName = non_empty[i]
		var amount: int = int(stored.get(key, 0))
		var row: int = int(i / cols)
		var col: int = i % cols
		var cell_pos: Vector2 = Vector2(
			-half.x + 28.0 + col * 76.0,
			-half.y + 22.0 + row * 42.0
		)
		var holder := Node2D.new()
		holder.position = cell_pos
		var cube := Sprite2D.new()
		cube.texture = _make_texture(16, 16, _resource_color(key))
		holder.add_child(cube)
		var txt := Label.new()
		txt.text = "%s x%d" % [_resource_short_name(key), amount]
		txt.position = Vector2(-30, 8)
		txt.custom_minimum_size = Vector2(64, 16)
		txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		txt.add_theme_font_size_override("font_size", 11)
		holder.add_child(txt)
		_stack_root.add_child(holder)
		_stack_slots.append({
			"resource_type": key,
			"rect": Rect2(cell_pos - Vector2(34.0, 16.0), Vector2(68.0, 34.0))
		})

func _resource_color(resource_type: StringName) -> Color:
	match resource_type:
		&"Wood":
			return Color(0.66, 0.45, 0.27, 1.0)
		&"Stone":
			return Color(0.58, 0.60, 0.64, 1.0)
		&"Steel":
			return Color(0.63, 0.72, 0.84, 1.0)
		&"FoodRaw":
			return Color(0.86, 0.36, 0.52, 1.0)
		&"Meal":
			return Color(0.93, 0.78, 0.44, 1.0)
		&"Bed":
			return Color(0.73, 0.54, 0.36, 1.0)
		&"GatherTop":
			return Color(0.32, 0.64, 0.82, 1.0)
		&"GatherBottom":
			return Color(0.26, 0.52, 0.72, 1.0)
		&"CombatTop":
			return Color(0.72, 0.28, 0.28, 1.0)
		&"CombatBottom":
			return Color(0.58, 0.23, 0.23, 1.0)
		&"CombatHat":
			return Color(0.82, 0.48, 0.22, 1.0)
		&"Sword":
			return Color(0.74, 0.74, 0.86, 1.0)
		&"Bow":
			return Color(0.56, 0.42, 0.24, 1.0)
		_:
			return Color(0.8, 0.8, 0.8, 1.0)

func _resource_short_name(resource_type: StringName) -> String:
	match resource_type:
		&"FoodRaw":
			return "Food"
		&"StoneBlock":
			return "Block"
		&"GatherTop":
			return "Top"
		&"GatherBottom":
			return "Bottom"
		&"CombatTop":
			return "C.Top"
		&"CombatBottom":
			return "C.Bottom"
		&"CombatHat":
			return "C.Hat"
		_:
			return String(resource_type)

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var key: String = "%d|%d|%.3f|%.3f|%.3f|%.3f" % [w, h, color.r, color.g, color.b, color.a]
	if _stack_texture_cache.has(key):
		return _stack_texture_cache[key]
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var tex: Texture2D = ImageTexture.create_from_image(image)
	_stack_texture_cache[key] = tex
	return tex

func _stack_signature() -> String:
	var base_sig: String = "w%d|h%d" % [int(round(zone_size.x)), int(round(zone_size.y))]
	if stored.is_empty():
		return base_sig
	var keys: Array = stored.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var parts: Array[String] = []
	for key_any in keys:
		var key: StringName = StringName(key_any)
		parts.append("%s:%d" % [String(key), int(stored.get(key, 0))])
	return "%s|%s" % [base_sig, "|".join(parts)]
