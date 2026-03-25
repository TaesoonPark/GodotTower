extends Area2D

@export var attack_range: float = 120.0
@export var damage: int = 25
@export var fire_rate: float = 1.0
@export var color: Color = Color(0.8, 0.2, 0.2)
@export var sell_refund_ratio: float = 0.7
@export var visual_height: float = 72.0

var _cooldown: float = 0.0
var _selected: bool = false
var _level: int = 1
var _base_cost: int = 100
var _base_attack_range: float = 120.0
var _range_bonus: float = 0.0
var _base_visual_height: float = 72.0
var _world_scale: float = 1.0

func _ready() -> void:
    _base_attack_range = attack_range
    _base_visual_height = visual_height
    collision_layer = 2
    collision_mask = 1
    add_to_group("towers")
    _setup_placeholder_sprite()
    _fit_sprite_to_height(visual_height)
    _setup_range_visual()
    _apply_world_scale()

func _setup_placeholder_sprite() -> void:
    var sprite = get_node_or_null("Sprite")
    if sprite == null or not (sprite is Sprite2D):
        return
    if sprite.texture:
        return
    var loaded_texture = _load_texture_from_file("res://assets/tower.png")
    if loaded_texture == null:
        loaded_texture = _load_texture_from_file("res://assets/tower.jpg")
    if loaded_texture != null:
        sprite.texture = loaded_texture
        return
    var image = Image.create(24, 32, false, Image.FORMAT_RGBA8)
    image.fill(color)
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

func _setup_range_visual() -> void:
    var collision_shape := get_node_or_null("RangeCollision") as CollisionShape2D
    if collision_shape == null:
        collision_shape = CollisionShape2D.new()
        collision_shape.name = "RangeCollision"
        add_child(collision_shape)
        collision_shape.visible = false
    var shape := collision_shape.shape as CircleShape2D
    if shape == null:
        shape = CircleShape2D.new()
        collision_shape.shape = shape
    shape.radius = attack_range

func _process(delta: float) -> void:
    _cooldown -= delta
    if _cooldown <= 0:
        var target = _find_target()
        if target:
            _shoot(target)
            _cooldown = 1.0 / fire_rate

func _find_target() -> Node2D:
    var nearest: Node2D = null
    var nearest_dist := INF
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy == null or not (enemy is Node2D):
            continue
        var dist = global_position.distance_to(enemy.global_position)
        if dist <= attack_range and dist < nearest_dist:
            nearest_dist = dist
            nearest = enemy
    return nearest

func _shoot(target: Node2D) -> void:
    if target and target.has_method("take_damage"):
        target.take_damage(damage)
        _create_projectile(global_position, target.global_position)

func _create_projectile(start_pos: Vector2, end_pos: Vector2) -> void:
    var projectile = Sprite2D.new()
    projectile.top_level = true
    projectile.global_position = start_pos
    var texture = ImageTexture.new()
    var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
    image.fill(Color(1, 1, 0))
    texture = ImageTexture.create_from_image(image)
    projectile.texture = texture
    var scene_root: Node = get_tree().current_scene
    if scene_root != null:
        scene_root.add_child(projectile)
    else:
        add_child(projectile)
    
    var speed = 300.0
    var distance = (end_pos - start_pos).length()
    var travel_time = maxf(distance / speed, 0.03)
    
    var tween = projectile.create_tween()
    tween.tween_property(projectile, "global_position", end_pos, travel_time)
    await tween.finished
    projectile.queue_free()

func configure_base_cost(cost: int) -> void:
    _base_cost = cost

func set_selected(selected: bool) -> void:
    _selected = selected
    queue_redraw()

func upgrade_stats() -> int:
    _level += 1
    damage += 12
    _range_bonus += 14.0
    fire_rate += 0.12
    _apply_world_scale()
    queue_redraw()
    return _level

func get_upgrade_cost() -> int:
    return int(_base_cost * (0.6 + float(_level) * 0.55))

func get_sell_value() -> int:
    return int(float(_base_cost) * sell_refund_ratio + float(get_upgrade_cost()) * float(_level - 1) * 0.35)

func _draw() -> void:
    if not _selected:
        return
    draw_circle(Vector2.ZERO, attack_range, Color(0.3, 0.8, 1.0, 0.15))
    draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(0.4, 0.95, 1.0, 0.8), 2.0)

func set_world_scale(scale_factor: float) -> void:
    _world_scale = maxf(scale_factor, 0.6)
    _apply_world_scale()

func _apply_world_scale() -> void:
    attack_range = (_base_attack_range + _range_bonus) * _world_scale
    _fit_sprite_to_height(_base_visual_height * _world_scale)
    _setup_range_visual()
    queue_redraw()
