extends Node2D

var required_work: float = 100.0
var work_progress: float = 0.0
var complete: bool = false
var job_queued: bool = false

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var progress_sprite: Sprite2D = $ProgressSprite

func _ready() -> void:
	add_to_group("build_sites")
	if base_sprite.texture == null:
		base_sprite.texture = _make_texture(40, 40, Color(0.45, 0.55, 0.85, 0.7))
	if progress_sprite.texture == null:
		progress_sprite.texture = _make_texture(36, 6, Color(0.3, 0.95, 0.4, 0.85))
	_update_visual()

func set_job_queued(v: bool) -> void:
	job_queued = v

func apply_work(amount: float) -> void:
	if complete:
		return
	work_progress = clampf(work_progress + amount, 0.0, required_work)
	if work_progress >= required_work:
		complete = true
		job_queued = false
		_build_complete_visual()
	_update_visual()

func _update_visual() -> void:
	var ratio: float = 0.0
	if required_work > 0.0:
		ratio = work_progress / required_work
	progress_sprite.scale.x = clampf(ratio, 0.05, 1.0)
	if complete:
		base_sprite.modulate = Color(0.35, 0.75, 0.35, 1.0)
		progress_sprite.visible = false
	else:
		base_sprite.modulate = Color(0.45, 0.55, 0.85, 0.7)
		progress_sprite.visible = true

func _build_complete_visual() -> void:
	var roof := Sprite2D.new()
	roof.texture = _make_texture(40, 12, Color(0.25, 0.3, 0.35))
	roof.position = Vector2(0, -20)
	add_child(roof)

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
