extends Node2D
class_name ResourceDrop

signal drop_changed(drop: Node)
signal drop_emptied(drop: Node)
signal drop_removed(drop: Node)

@export var resource_type: StringName = &"Wood"
@export var amount: int = 0

var job_queued: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("resource_drops")
	_refresh()

func setup_drop(t: StringName, v: int) -> void:
	resource_type = t
	amount = max(0, v)
	if is_node_ready():
		_refresh()
	drop_changed.emit(self)

func is_empty() -> bool:
	return amount <= 0

func set_job_queued(v: bool) -> void:
	job_queued = v
	drop_changed.emit(self)

func take_all() -> int:
	var out := amount
	amount = 0
	job_queued = false
	_refresh()
	drop_emptied.emit(self)
	drop_changed.emit(self)
	return out

func take_amount(v: int) -> int:
	if v <= 0:
		return 0
	var out: int = mini(v, amount)
	amount -= out
	if amount <= 0:
		amount = 0
		job_queued = false
		drop_emptied.emit(self)
	_refresh()
	drop_changed.emit(self)
	return out

func _refresh() -> void:
	var sprite_node: Sprite2D = sprite if sprite != null else get_node_or_null("Sprite2D")
	var label_node: Label = label if label != null else get_node_or_null("Label")
	if sprite_node != null and sprite_node.texture == null:
		sprite_node.texture = _make_texture(22, 22, Color(0.92, 0.78, 0.36))
	if label_node != null:
		label_node.text = "%s x%d" % [String(resource_type), amount]
	visible = amount > 0

func _exit_tree() -> void:
	drop_removed.emit(self)

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
