extends Node2D
class_name VehicleInstance

const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")

@export var vehicle_def: Resource

var vehicle_id: StringName = &""
var display_name: String = ""
var item_resource_id: StringName = &""
var max_health: float = 80.0
var health: float = 80.0
var move_speed: float = 250.0
var carry_capacity_bonus: int = 0
var can_work: bool = false
var rider_can_attack: bool = false
var participates_in_scheduling: bool = false
var destroy_stun_seconds: float = 3.0

var _rider_id: int = 0

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _label: Label = get_node_or_null("Label")

func _ready() -> void:
	add_to_group("vehicles")
	if vehicle_def != null:
		_apply_def(vehicle_def)
	_apply_meta()
	_ensure_visuals()
	_refresh_visuals()

func setup(def: Resource) -> void:
	vehicle_def = def
	_apply_def(def)
	_apply_meta()
	if is_node_ready():
		_ensure_visuals()
		_refresh_visuals()

func assign_rider(rider_id: int) -> bool:
	if rider_id == 0:
		return false
	var current_rider: int = get_rider_id()
	if current_rider != 0 and current_rider != rider_id:
		return false
	_rider_id = rider_id
	set_meta("rider_colonist_id", rider_id)
	_refresh_visuals()
	return true

func clear_rider(rider_id: int = 0) -> void:
	var current_rider: int = get_rider_id()
	if rider_id != 0 and current_rider != rider_id:
		return
	_rider_id = 0
	set_meta("rider_colonist_id", 0)
	_refresh_visuals()

func get_rider_id() -> int:
	if has_meta("rider_colonist_id"):
		return int(get_meta("rider_colonist_id"))
	return _rider_id

func is_ridden() -> bool:
	return get_rider_id() != 0

func is_ridden_by(rider_id: int) -> bool:
	return rider_id != 0 and get_rider_id() == rider_id

func get_move_speed() -> float:
	return maxf(1.0, move_speed)

func get_carry_capacity_bonus() -> int:
	return maxi(0, carry_capacity_bonus)

func apply_vehicle_damage(amount: int) -> void:
	if amount <= 0 or health <= 0.0:
		return
	health = maxf(0.0, health - float(amount))
	set_meta("vehicle_health", health)
	_refresh_visuals()
	if health <= 0.0:
		_destroy_vehicle()

func update_mount_position(owner_pos: Vector2, _owner_velocity: Vector2 = Vector2.RIGHT) -> void:
	global_position = owner_pos

func _apply_def(def: Resource) -> void:
	if def == null:
		return
	vehicle_id = StringName(def.get("id"))
	display_name = String(def.get("display_name"))
	item_resource_id = StringName(def.get("item_resource_id"))
	max_health = maxf(1.0, float(def.get("max_health")))
	health = max_health
	move_speed = maxf(1.0, float(def.get("move_speed")))
	carry_capacity_bonus = maxi(0, int(def.get("carry_capacity_bonus")))
	can_work = bool(def.get("can_work"))
	rider_can_attack = bool(def.get("rider_can_attack"))
	participates_in_scheduling = bool(def.get("participates_in_scheduling"))
	destroy_stun_seconds = maxf(0.0, float(def.get("destroy_stun_seconds")))

func _apply_meta() -> void:
	set_meta("vehicle_id", vehicle_id)
	set_meta("item_resource_id", item_resource_id)
	set_meta("vehicle_health", health)
	set_meta("vehicle_max_health", max_health)
	set_meta("vehicle_move_speed", move_speed)
	set_meta("vehicle_carry_capacity_bonus", carry_capacity_bonus)
	set_meta("vehicle_can_work", can_work)
	set_meta("vehicle_rider_can_attack", rider_can_attack)
	set_meta("vehicle_participates_in_scheduling", participates_in_scheduling)
	set_meta("vehicle_destroy_stun_seconds", destroy_stun_seconds)
	if not has_meta("rider_colonist_id"):
		set_meta("rider_colonist_id", _rider_id)

func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.position = Vector2(-30.0, -32.0)
		add_child(_label)
	if _label != null:
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_visuals() -> void:
	if _sprite != null:
		var tex: Texture2D = GAME_SPRITE.get_drop_texture(item_resource_id)
		if tex != null:
			_sprite.texture = tex
		elif _sprite.texture == null:
			_sprite.texture = _make_texture(34, 20, Color(0.24, 0.56, 0.86, 1.0))
	if _label != null:
		var rider_suffix: String = " (탑승)" if is_ridden() else ""
		_label.text = "%s HP %.0f/%.0f%s" % [_vehicle_label_name(), health, max_health, rider_suffix]

func _vehicle_label_name() -> String:
	if not display_name.is_empty():
		return display_name
	if vehicle_id != &"":
		return String(vehicle_id)
	return "Vehicle"

func _destroy_vehicle() -> void:
	var rider_id: int = get_rider_id()
	if rider_id != 0:
		var rider_obj: Object = instance_from_id(rider_id)
		if rider_obj != null and is_instance_valid(rider_obj) and rider_obj.has_method("dismount_vehicle"):
			rider_obj.dismount_vehicle(destroy_stun_seconds)
		else:
			clear_rider(rider_id)
	queue_free()

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
