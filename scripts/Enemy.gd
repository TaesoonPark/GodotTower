extends PathFollow2D

@export var speed: float = 80.0
@export var hp: int = 100
@export var max_hp: int = 100
@export var reward: int = 25

var _game_manager: Node = null
var _health_bar: Node2D = null

func _ready() -> void:
    add_to_group("enemies")
    _game_manager = get_node_or_null("/root/Main")
    _setup_health_bar()

func _setup_health_bar():
    _health_bar = Node2D.new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    
    var max_bar = Sprite2D.new()
    max_bar.name = "MaxBar"
    var texture = ImageTexture.new()
    var image = Image.create(40, 4, false, Image.FORMAT_R8G8B8A8)
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

func _process(delta: float) -> void:
    if offset < 0:
        offset = 0
    offset += speed * delta
    
    var path_node = get_parent()
    if path_node and path_node.has_method("get_curve"):
        var curve = path_node.curve
        if curve and offset >= curve.get_baked_length():
            queue_free()
    
    if _health_bar:
        var current_bar = _health_bar.get_node_or_null("CurrentBar")
        if current_bar:
            var max_bar = _health_bar.get_node_or_null("MaxBar")
            if max_bar:
                var max_width = max_bar.position.x * 2
                var current_width = (hp / max_hp) * max_width
                current_bar.scale = Vector2(current_width / 40, 1)

func take_damage(amount: int) -> void:
    hp -= amount
    if hp <= 0:
        hp = 0
        queue_free()
        if _game_manager and _game_manager.has_method("_on_enemy_killed"):
            _game_manager._on_enemy_killed()

func _on_enemy_reached_end():
    queue_free()
    if _game_manager and _game_manager.has_method("_on_enemy_reached_end"):
        _game_manager._on_enemy_reached_end()
