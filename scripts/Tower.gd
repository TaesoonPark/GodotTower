extends Area2D

@export var range: float = 120.0
@export var damage: int = 25
@export var fire_rate: float = 1.0
@export var color: Color = Color(0.8, 0.2, 0.2)

var _cooldown: float = 0.0
var _enemies: Array = []

func _ready():
    collision_layer = 2
    collision_mask = 1
    _setup_range_visual()

func _setup_range_visual():
    var collision_shape = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = range
    collision_shape.shape = shape
    add_child(collision_shape)
    collision_shape.visible = false

func _process(delta):
    _cooldown -= delta
    if _cooldown <= 0:
        var target = _find_target()
        if target:
            _shoot(target)
            _cooldown = 1.0 / fire_rate

func _find_target() -> Node2D:
    _enemies.clear()
    for body in get_overlapping_bodies():
        if body.is_in_group("enemies"):
            _enemies.append(body)
    
    if _enemies.size() > 0:
        return _enemies[0]
    return null

func _shoot(target):
    if target and target.has_method("take_damage"):
        target.take_damage(damage)
        _create_projectile(global_position, target.global_position)

func _create_projectile(start_pos, end_pos):
    var projectile = Sprite2D.new()
    projectile.global_position = start_pos
    var texture = ImageTexture.new()
    var image = Image.create(4, 4, false, Image.FORMAT_R8G8B8A8)
    image.fill(Color(1, 1, 0))
    texture = ImageTexture.create_from_image(image)
    projectile.texture = texture
    add_child(projectile)
    
    var direction = (end_pos - start_pos).normalized()
    var speed = 300.0
    var distance = (end_pos - start_pos).length()
    var travel_time = distance / speed
    
    projectile.tween_property("global_position", end_pos, travel_time).start()
    await get_tree().create_timer(travel_time).timeout
    projectile.queue_free()
