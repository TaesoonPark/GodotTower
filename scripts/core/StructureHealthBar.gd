extends RefCounted
class_name StructureHealthBar

const BAR_NAME: String = "StructureHealthBar"
const BACK_NAME: String = "Background"
const FILL_NAME: String = "Fill"
const BAR_HEIGHT: int = 5

static func update_bar(structure: Node, hp: float, max_hp: float) -> void:
	if structure == null or not is_instance_valid(structure) or not (structure is Node2D):
		return
	var bar: Node2D = _get_bar(structure)
	if max_hp <= 0.0 or hp >= max_hp - 0.01:
		if bar != null:
			bar.visible = false
		return
	bar = _ensure_bar(structure as Node2D)
	var ratio: float = clampf(hp / max_hp, 0.0, 1.0)
	var footprint: Vector2 = structure.get_meta("footprint_size") if structure.has_meta("footprint_size") else Vector2(64.0, 64.0)
	var width: float = _bar_width(footprint)
	bar.visible = true
	bar.position = Vector2(0.0, -footprint.y * 0.5 - 8.0)
	var fill: Sprite2D = bar.get_node_or_null(FILL_NAME) as Sprite2D
	if fill != null:
		fill.scale.x = ratio
		fill.position.x = -width * (1.0 - ratio) * 0.5

static func _get_bar(structure: Node) -> Node2D:
	return structure.get_node_or_null(BAR_NAME) as Node2D

static func _ensure_bar(structure: Node2D) -> Node2D:
	var existing: Node2D = _get_bar(structure)
	if existing != null:
		return existing
	var footprint: Vector2 = structure.get_meta("footprint_size") if structure.has_meta("footprint_size") else Vector2(64.0, 64.0)
	var width: int = int(round(_bar_width(footprint)))
	var bar := Node2D.new()
	bar.name = BAR_NAME
	bar.z_index = 20
	bar.position = Vector2(0.0, -footprint.y * 0.5 - 8.0)
	var background := Sprite2D.new()
	background.name = BACK_NAME
	background.texture = _make_texture(width, BAR_HEIGHT, Color(0.72, 0.04, 0.03, 0.95))
	bar.add_child(background)
	var fill := Sprite2D.new()
	fill.name = FILL_NAME
	fill.texture = _make_texture(width, BAR_HEIGHT, Color(0.12, 0.82, 0.23, 0.95))
	bar.add_child(fill)
	structure.add_child(bar)
	return bar

static func _bar_width(footprint: Vector2) -> float:
	return clampf(footprint.x * 0.8, 28.0, 96.0)

static func _make_texture(width: int, height: int, color: Color) -> Texture2D:
	var image := Image.create(maxi(1, width), maxi(1, height), false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
