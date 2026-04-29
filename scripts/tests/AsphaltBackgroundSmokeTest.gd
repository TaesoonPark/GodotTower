extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

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
	var main = MAIN_SCENE.instantiate()
	add_child(main)

	for _i in range(8):
		await get_tree().process_frame

	var background: Node = main.world_root.get_node_or_null("AsphaltBackground")
	if background == null:
		_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: background node missing")
		return
	if int(background.get_texture_count()) != 4:
		_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: expected 4 asphalt textures")
		return
	var grid_size: Vector2i = background.get_grid_size()
	if grid_size != Vector2i(120, 68):
		_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: unexpected grid size %s" % str(grid_size))
		return
	if int(background.get_tile_count()) != grid_size.x * grid_size.y:
		_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: tile count does not cover grid")
		return
	for i in range(4):
		var texture: Texture2D = GAME_SPRITE.get_terrain_texture(StringName("asphalt_%d" % i))
		if texture == null:
			_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: missing asphalt_%d texture" % i)
			return
		if texture.get_size() != Vector2(64.0, 64.0):
			_finish(false, "ASPHALT_BACKGROUND_TEST_FAIL: asphalt_%d is not 64x64" % i)
			return

	_finish(true, "ASPHALT_BACKGROUND_TEST_PASS: asphalt tiles cover the world background")
