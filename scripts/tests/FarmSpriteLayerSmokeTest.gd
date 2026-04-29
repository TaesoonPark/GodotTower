extends Node

const FARM_SCENE: PackedScene = preload("res://scenes/world/FarmZone.tscn")
const CROP_DEF: Resource = preload("res://data/crops/potato.tres")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	var zone: FarmZone = FARM_SCENE.instantiate()
	add_child(zone)
	zone.setup_from_rect(Rect2(Vector2.ZERO, Vector2(TILE_SIZE * 3.0, TILE_SIZE * 2.0)))
	zone.set_crop_catalog({&"Potato": CROP_DEF})
	zone.set_crop_type(&"Potato")
	for _i in range(3):
		await get_tree().process_frame

	var fill: Polygon2D = zone.get_node_or_null("Fill") as Polygon2D
	if fill == null:
		_finish(false, "FARM_SPRITE_LAYER_FAIL: fill node missing")
		return
	if fill.visible or fill.color.a > 0.001:
		_finish(false, "FARM_SPRITE_LAYER_FAIL: green fill still visible")
		return
	var label: Label = zone.get_node_or_null("Label") as Label
	if label != null and label.visible:
		_finish(false, "FARM_SPRITE_LAYER_FAIL: farm label still visible")
		return

	var ground: Node = zone.get_node_or_null("PlotGround")
	if ground == null or ground.get_child_count() == 0:
		_finish(false, "FARM_SPRITE_LAYER_FAIL: plot ground sprites missing")
		return
	for child in ground.get_children():
		if not (child is Sprite2D):
			_finish(false, "FARM_SPRITE_LAYER_FAIL: plot ground child is not Sprite2D")
			return
		if (child as Sprite2D).texture == null:
			_finish(false, "FARM_SPRITE_LAYER_FAIL: plot ground texture missing")
			return

	var plots: Dictionary = zone.get("_plots")
	var tiles: Array = plots.keys()
	if tiles.is_empty():
		_finish(false, "FARM_SPRITE_LAYER_FAIL: no plots")
		return
	var tile: Vector2i = tiles[0]
	if not zone.plant_crop(tile, &"Potato"):
		_finish(false, "FARM_SPRITE_LAYER_FAIL: plant crop failed")
		return
	for _i in range(2):
		await get_tree().process_frame
	if not _has_marker_texture(zone, "potato_planted.png"):
		_finish(false, "FARM_SPRITE_LAYER_FAIL: planted potato texture missing")
		return

	var plot: Dictionary = zone.get("_plots")[tile]
	plot["elapsed"] = 180.0
	zone.get("_plots")[tile] = plot
	zone.tick_growth(0.1)
	for _i in range(2):
		await get_tree().process_frame
	if not _has_marker_texture(zone, "potato_mature.png"):
		_finish(false, "FARM_SPRITE_LAYER_FAIL: mature potato texture missing")
		return

	_finish(true, "FARM_SPRITE_LAYER_PASS: farm ground and potato stage sprites are layered dynamically")

func _has_marker_texture(zone: FarmZone, file_name: String) -> bool:
	var markers: Node = zone.get_node_or_null("PlotMarkers")
	if markers == null:
		return false
	for child in markers.get_children():
		if not (child is Sprite2D):
			continue
		var tex: Texture2D = (child as Sprite2D).texture
		if tex == null:
			continue
		if tex.resource_path.ends_with(file_name):
			return true
	return false
