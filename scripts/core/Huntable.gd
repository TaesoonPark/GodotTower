extends Node2D
class_name Huntable

@export var display_name: String = "Animal"
@export var max_health: int = 70
@export var hunt_damage_per_tick: int = 25
@export var meat_type: StringName = &"FoodRaw"
@export var meat_yield: int = 35
@export var tint: Color = Color(0.78, 0.56, 0.36, 1.0)

var health: int = 0
var job_queued: bool = false
var designated: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	health = maxi(1, max_health)
	add_to_group("huntables")
	_refresh_visual()

func is_dead() -> bool:
	return health <= 0

func set_job_queued(v: bool) -> void:
	job_queued = v

func set_designated(v: bool) -> void:
	designated = v
	_refresh_visual()

func is_designated() -> bool:
	return designated

func hunt_once(work_amount: float) -> Dictionary:
	if is_dead():
		job_queued = false
		designated = false
		return {"resource_type": meat_type, "amount": 0}
	var damage: int = maxi(1, int(round(float(hunt_damage_per_tick) * (work_amount / 25.0))))
	health = maxi(0, health - damage)
	var dropped: int = 0
	if health <= 0:
		dropped = maxi(1, meat_yield)
		designated = false
	job_queued = false
	_refresh_visual()
	return {"resource_type": meat_type, "amount": dropped}

func _refresh_visual() -> void:
	if sprite.texture == null:
		sprite.texture = _make_texture(30, 20, tint)
	var ratio: float = clampf(float(health) / maxf(1.0, float(max_health)), 0.0, 1.0)
	sprite.modulate = tint.lerp(Color(0.25, 0.2, 0.2, 1.0), 1.0 - ratio)
	if label != null:
		var marker: String = " [H]" if designated else ""
		label.text = "%s %d%s" % [display_name, health, marker]
		label.visible = not is_dead()
	visible = not is_dead()

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
