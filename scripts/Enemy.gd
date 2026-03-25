extends PathFollow2D

signal died(reward: int)
signal escaped

@export var speed: float = 90.0
@export var hp: int = 100
@export var max_hp: int = 100
@export var reward: int = 20
@export var visual_height: float = 56.0

var _health_bar: Node2D = null
var _is_removed: bool = false
var _base_speed: float = -1.0
var _base_visual_height: float = 56.0
var _world_scale: float = 1.0

func _ready() -> void:
    if _base_speed < 0.0:
        _base_speed = speed
    _base_visual_height = visual_height
    loop = true
    add_to_group("enemies")
    _setup_placeholder_sprite()
    _fit_sprite_to_height(visual_height)
    _setup_health_bar()
    _apply_world_scale()

func _setup_placeholder_sprite() -> void:
    var sprite = get_node_or_null("Sprite")
    if sprite == null or not (sprite is Sprite2D):
        return
    if sprite.texture:
        return
    var loaded_texture = _load_texture_from_file("res://assets/enemy.png")
    if loaded_texture == null:
        loaded_texture = _load_texture_from_file("res://assets/enemy.jpeg")
    if loaded_texture != null:
        sprite.texture = loaded_texture
        return
    var image = Image.create(20, 24, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.2, 0.8, 0.3))
    var texture = ImageTexture.create_from_image(image)
    sprite.texture = texture

func _load_texture_from_file(path: String) -> Texture2D:
    var image := Image.new()
    var err := image.load(path)
    if err != OK:
        return null
    return ImageTexture.create_from_image(image)

func _fit_sprite_to_height(target_height: float) -> void:
    var sprite := get_node_or_null("Sprite") as Sprite2D
    if sprite == null or sprite.texture == null:
        return
    var tex_size: Vector2 = sprite.texture.get_size()
    if tex_size.y <= 0.0:
        return
    var scale_factor: float = target_height / tex_size.y
    sprite.scale = Vector2(scale_factor, scale_factor)

func set_world_scale(scale_factor: float) -> void:
    if _base_speed < 0.0:
        _base_speed = speed
    _world_scale = maxf(scale_factor, 0.6)
    _apply_world_scale()

func _apply_world_scale() -> void:
    speed = _base_speed * _world_scale
    _fit_sprite_to_height(_base_visual_height * _world_scale)
    if _health_bar != null:
        _health_bar.scale = Vector2(_world_scale, _world_scale)

func _setup_health_bar() -> void:
    _health_bar = Node2D.new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    
    var max_bar = Sprite2D.new()
    max_bar.name = "MaxBar"
    var texture = ImageTexture.new()
    var image = Image.create(40, 4, false, Image.FORMAT_RGBA8)
    image.fill(Color(0.8, 0, 0))
    texture = ImageTexture.create_from_image(image)
    max_bar.texture = texture
    max_bar.position = Vector2(-20, -20)
    _health_bar.add_child(max_bar)
    
    var current_bar = Sprite2D.new()
    current_bar.name = "CurrentBar"
    current_bar.texture = texture
    current_bar.modulate = Color(0, 1, 0)
    current_bar.position = Vector2(-20, -20)
    _health_bar.add_child(current_bar)
    current_bar.scale = Vector2(1, 1)
    _health_bar.scale = Vector2(_world_scale, _world_scale)

func _process(delta: float) -> void:
    if _is_removed:
        return
    
    if progress < 0.0:
        progress = 0.0
    progress += speed * delta
    
    _update_health_bar()

func _update_health_bar() -> void:
    if _health_bar == null:
        return
    var current_bar = _health_bar.get_node_or_null("CurrentBar")
    if current_bar == null:
        return
    var ratio: float = float(hp) / maxf(float(max_hp), 1.0)
    current_bar.scale = Vector2(clamp(ratio, 0.0, 1.0), 1.0)

func take_damage(amount: int) -> void:
    if _is_removed:
        return
    hp -= amount
    if hp <= 0:
        hp = 0
        _die()

func _die() -> void:
    if _is_removed:
        return
    _is_removed = true
    died.emit(reward)
    queue_free()

func _escape() -> void:
    if _is_removed:
        return
    _is_removed = true
    escaped.emit()
    queue_free()
