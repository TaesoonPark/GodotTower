extends Node2D
class_name Handcart

const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")

@export var carry_bonus: int = 80
@export var follow_distance: float = 18.0
@export var side_offset: float = 10.0

var _owner_id: int = 0

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var _label: Label = get_node_or_null("Label")

func _ready() -> void:
	add_to_group("structures")
	add_to_group("handcarts")
	_apply_meta()
	_ensure_visuals()
	_refresh_visuals()

func get_carry_bonus() -> int:
	return maxi(0, carry_bonus)

func assign_owner(owner_id: int) -> bool:
	if owner_id == 0:
		return false
	var current_owner: int = int(get_meta("assigned_colonist_id")) if has_meta("assigned_colonist_id") else 0
	if current_owner != 0 and current_owner != owner_id:
		return false
	_owner_id = owner_id
	set_meta("assigned_colonist_id", owner_id)
	return true

func clear_owner(owner_id: int = 0) -> void:
	var current_owner: int = int(get_meta("assigned_colonist_id")) if has_meta("assigned_colonist_id") else 0
	if owner_id != 0 and current_owner != owner_id:
		return
	_owner_id = 0
	set_meta("assigned_colonist_id", 0)

func is_owned_by(owner_id: int) -> bool:
	if owner_id == 0:
		return false
	var current_owner: int = int(get_meta("assigned_colonist_id")) if has_meta("assigned_colonist_id") else _owner_id
	return current_owner == owner_id

func update_follow(owner_pos: Vector2, owner_velocity: Vector2 = Vector2.RIGHT) -> void:
	var dir: Vector2 = owner_velocity
	if dir.length_squared() <= 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	global_position = owner_pos - dir * follow_distance + side * side_offset

func _apply_meta() -> void:
	set_meta("building_id", &"InstalledHandcart")
	set_meta("carry_bonus", get_carry_bonus())
	set_meta("required_work", 1.0)
	set_meta("blocks_movement", false)
	set_meta("passable_for_friendly", true)
	set_meta("structure_max_health", 90.0)
	if not has_meta("structure_health"):
		set_meta("structure_health", 90.0)
	set_meta("repair_work", 2.0)
	if not has_meta("assigned_colonist_id"):
		set_meta("assigned_colonist_id", 0)

func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.position = Vector2(-28.0, -26.0)
		add_child(_label)
	if _label != null:
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_visuals() -> void:
	if _sprite != null:
		var tex: Texture2D = GAME_SPRITE.get_drop_texture(&"Handcart")
		if tex != null:
			_sprite.texture = tex
		elif _sprite.texture == null:
			_sprite.texture = _make_texture(30, 18, Color(0.58, 0.44, 0.28, 1.0))
	if _label != null:
		_label.text = "Handcart +%d" % get_carry_bonus()

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
