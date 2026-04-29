extends Node2D
class_name AsphaltBackground

const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const TILE_IDS: Array[StringName] = [&"asphalt_0", &"asphalt_1", &"asphalt_2", &"asphalt_3"]

@export var world_size: Vector2 = Vector2(7680.0, 4352.0)
@export var tile_size: float = 64.0
@export var random_seed: int = 0

var _textures: Array[Texture2D] = []
var _tile_indices: PackedInt32Array = PackedInt32Array()
var _columns: int = 0
var _rows: int = 0

func _ready() -> void:
	setup(world_size, tile_size, random_seed)

func setup(next_world_size: Vector2, next_tile_size: float, next_seed: int = 0) -> void:
	world_size = next_world_size
	tile_size = maxf(4.0, next_tile_size)
	random_seed = next_seed
	_load_textures()
	_randomize_tiles()
	queue_redraw()

func get_tile_count() -> int:
	return _tile_indices.size()

func get_texture_count() -> int:
	return _textures.size()

func get_grid_size() -> Vector2i:
	return Vector2i(_columns, _rows)

func _draw() -> void:
	if _textures.is_empty() or _tile_indices.is_empty():
		draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.12, 0.14, 0.16, 1.0), true)
		return
	for y in range(_rows):
		for x in range(_columns):
			var index: int = y * _columns + x
			var texture_index: int = int(_tile_indices[index])
			var texture: Texture2D = _textures[texture_index]
			var pos := Vector2(float(x) * tile_size, float(y) * tile_size)
			draw_texture_rect(texture, Rect2(pos, Vector2(tile_size, tile_size)), false)

func _load_textures() -> void:
	_textures.clear()
	for tile_id in TILE_IDS:
		var texture: Texture2D = GAME_SPRITE.get_terrain_texture(tile_id)
		if texture != null:
			_textures.append(texture)

func _randomize_tiles() -> void:
	_columns = maxi(1, int(ceil(world_size.x / tile_size)))
	_rows = maxi(1, int(ceil(world_size.y / tile_size)))
	_tile_indices.resize(_columns * _rows)
	if _textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	for y in range(_rows):
		for x in range(_columns):
			var previous_left: int = int(_tile_indices[y * _columns + x - 1]) if x > 0 else -1
			var previous_up: int = int(_tile_indices[(y - 1) * _columns + x]) if y > 0 else -1
			var next_index: int = rng.randi_range(0, _textures.size() - 1)
			if _textures.size() > 1 and next_index == previous_left and next_index == previous_up:
				next_index = (next_index + 1 + rng.randi_range(0, _textures.size() - 2)) % _textures.size()
			_tile_indices[y * _columns + x] = next_index
