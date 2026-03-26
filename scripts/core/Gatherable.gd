extends Node2D
class_name Gatherable

@export var resource_type: StringName = &"Wood"
@export var display_name: String = "Tree"
@export var max_amount: int = 80
@export var gather_per_tick: int = 10
@export var tint: Color = Color(0.3, 0.65, 0.35, 1.0)

var current_amount: int = 0
var job_queued: bool = false
var designated: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	current_amount = max_amount
	add_to_group("gatherables")
	_refresh_visual()

func is_depleted() -> bool:
	return current_amount <= 0

func set_job_queued(v: bool) -> void:
	job_queued = v

func set_designated(v: bool) -> void:
	designated = v
	_refresh_visual()

func is_designated() -> bool:
	return designated

func gather_once(work_amount: float) -> Dictionary:
	if is_depleted():
		job_queued = false
		designated = false
		return {"resource_type": resource_type, "amount": 0}
	var gain: int = maxi(1, int(round(gather_per_tick * (work_amount / 25.0))))
	gain = mini(gain, current_amount)
	current_amount -= gain
	job_queued = false
	if is_depleted():
		designated = false
	_refresh_visual()
	return {"resource_type": resource_type, "amount": gain}

func _refresh_visual() -> void:
	if sprite.texture == null:
		sprite.texture = _make_texture(32, 32, tint)
	var ratio: float = clampf(float(current_amount) / maxf(1.0, float(max_amount)), 0.0, 1.0)
	sprite.modulate = tint.lerp(Color(0.22, 0.22, 0.24, 1.0), 1.0 - ratio)
	if label != null:
		var marker: String = " [G]" if designated else ""
		label.text = "%s %d%s" % [display_name, current_amount, marker]
		label.visible = not is_depleted()
	visible = not is_depleted()

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
