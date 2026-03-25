extends Node2D

const TOWER_SCENE = preload("res://scenes/Tower.tscn")
const ENEMY_SCENE = preload("res://scenes/Enemy.tscn")
const PATH_SCENE = preload("res://scenes/Path.tscn")
const BASE_RESOLUTION := Vector2(2560, 1440)
const BASE_ROAD_HALF_WIDTH: float = 24.0
const BASE_TOWER_SPACING: float = 52.0

var money: int = 800
var tower_cost: int = 100
var wave_index: int = 0
var enemies_defeated: int = 0
var lives: int = 20
var road_half_width: float = BASE_ROAD_HALF_WIDTH
var min_tower_spacing: float = BASE_TOWER_SPACING

var _selected_tower: Node = null
var _spawning_wave: bool = false
var _active_enemies: int = 0
var _game_over: bool = false
var _next_wave_queued: bool = false
var _ui_scale: float = 1.0
var _world_scale: float = 1.0
var _resize_refresh_queued: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO

func _ready():
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    _recalculate_resolution_scale()
    _last_viewport_size = get_viewport_rect().size
    
    var path_inst = PATH_SCENE.instantiate()
    path_inst.name = "Path"
    add_child(path_inst)
    _ensure_path_setup(path_inst)
    
    call_deferred("_setup_ui")
    call_deferred("_start_next_wave")

func _ensure_path_setup(path_node: Node) -> void:
    var path2d := path_node as Path2D
    if path2d == null:
        return
    var followers: Array[PathFollow2D] = []
    var progress_ratios: Array[float] = []
    var old_length: float = 1.0
    if path2d.curve != null:
        old_length = maxf(path2d.curve.get_baked_length(), 1.0)
    for child in path2d.get_children():
        var follower := child as PathFollow2D
        if follower == null:
            continue
        followers.append(follower)
        progress_ratios.append(clampf(follower.progress / old_length, 0.0, 1.0))
    
    var viewport_size: Vector2 = get_viewport_rect().size
    var center := viewport_size * 0.5
    var radius: float = minf(viewport_size.x, viewport_size.y) * 0.28
    path2d.curve = _create_circular_curve(center, radius, 32)
    
    var new_length: float = maxf(path2d.curve.get_baked_length(), 1.0)
    for i in range(followers.size()):
        if is_instance_valid(followers[i]):
            followers[i].progress = progress_ratios[i] * new_length
    _setup_path_visual(path2d)

func _create_circular_curve(center: Vector2, radius: float, segments: int) -> Curve2D:
    var curve := Curve2D.new()
    var safe_segments := maxi(segments, 8)
    for i in range(safe_segments):
        var angle: float = TAU * float(i) / float(safe_segments)
        var point = center + Vector2(cos(angle), sin(angle)) * radius
        curve.add_point(point)
    curve.add_point(center + Vector2(radius, 0))
    return curve

func _setup_path_visual(path2d: Path2D) -> void:
    var line := path2d.get_node_or_null("PathLine") as Line2D
    if line == null:
        line = Line2D.new()
        line.name = "PathLine"
        path2d.add_child(line)
    line.clear_points()
    line.width = 36.0 * _world_scale
    line.default_color = Color(0.35, 0.35, 0.35, 0.8)
    line.z_index = -1
    var sampled_points = path2d.curve.get_baked_points()
    if sampled_points.is_empty():
        for i in range(path2d.curve.point_count):
            line.add_point(path2d.curve.get_point_position(i))
    else:
        for p in sampled_points:
            line.add_point(p)

func _setup_ui():
    var hud = get_node_or_null("CanvasLayer")
    if not hud:
        hud = CanvasLayer.new()
        hud.name = "CanvasLayer"
        add_child(hud)
    
    var s: float = _ui_scale
    var title_size: int = maxi(18, int(26.0 * s))
    var body_size: int = maxi(14, int(20.0 * s))
    
    var money_label = get_node_or_null("CanvasLayer/MoneyLabel")
    if not money_label:
        money_label = Label.new()
        money_label.name = "MoneyLabel"
        hud.add_child(money_label)
    money_label.position = Vector2(24, 20) * s
    money_label.add_theme_font_size_override("font_size", title_size)
    money_label.text = "Money: %d" % money
    
    var wave_label = get_node_or_null("CanvasLayer/WaveLabel")
    if not wave_label:
        wave_label = Label.new()
        wave_label.name = "WaveLabel"
        hud.add_child(wave_label)
    wave_label.position = Vector2(24, 60) * s
    wave_label.add_theme_font_size_override("font_size", body_size)
    wave_label.text = "Wave: %d" % wave_index
    
    var lives_label = get_node_or_null("CanvasLayer/LivesLabel")
    if not lives_label:
        lives_label = Label.new()
        lives_label.name = "LivesLabel"
        hud.add_child(lives_label)
    lives_label.position = Vector2(24, 96) * s
    lives_label.add_theme_font_size_override("font_size", body_size)
    lives_label.text = "Lives: %d" % lives
    
    var upgrade_btn = get_node_or_null("CanvasLayer/UpgradeBtn")
    if not upgrade_btn:
        upgrade_btn = Button.new()
        upgrade_btn.name = "UpgradeBtn"
        upgrade_btn.connect("pressed", Callable(self, "_on_upgrade_pressed"))
        hud.add_child(upgrade_btn)
    upgrade_btn.position = Vector2(24, 142) * s
    upgrade_btn.size = Vector2(130, 42) * s
    upgrade_btn.add_theme_font_size_override("font_size", body_size)
    upgrade_btn.text = "Upgrade"
    
    var sell_btn = get_node_or_null("CanvasLayer/SellBtn")
    if not sell_btn:
        sell_btn = Button.new()
        sell_btn.name = "SellBtn"
        sell_btn.connect("pressed", Callable(self, "_on_sell_pressed"))
        hud.add_child(sell_btn)
    sell_btn.position = Vector2(164, 142) * s
    sell_btn.size = Vector2(110, 42) * s
    sell_btn.add_theme_font_size_override("font_size", body_size)
    sell_btn.text = "Sell"
    
    var info_label = get_node_or_null("CanvasLayer/InfoLabel")
    if not info_label:
        info_label = Label.new()
        info_label.name = "InfoLabel"
        hud.add_child(info_label)
    info_label.position = Vector2(24, 196) * s
    info_label.add_theme_font_size_override("font_size", body_size)
    info_label.text = ""
    
    _update_labels()

func _update_labels():
    var money_label = get_node_or_null("CanvasLayer/MoneyLabel")
    if money_label:
        money_label.text = "Money: %d" % money
    
    var wave_label = get_node_or_null("CanvasLayer/WaveLabel")
    if wave_label:
        wave_label.text = "Wave: %d" % wave_index
    
    var lives_label = get_node_or_null("CanvasLayer/LivesLabel")
    if lives_label:
        lives_label.text = "Lives: %d" % lives
    
    var info_label = get_node_or_null("CanvasLayer/InfoLabel")
    if info_label:
        if _game_over:
            info_label.text = "Defeat: press F5 to restart"
        elif _spawning_wave:
            info_label.text = "Wave %d incoming..." % wave_index
        elif _active_enemies > 0:
            info_label.text = "Enemies left: %d" % _active_enemies
        else:
            info_label.text = "Build towers with left click"

func _unhandled_input(event):
    if _game_over:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var world_pos = get_global_mouse_position()
        var clicked_tower = _find_tower_at_position(world_pos)
        if clicked_tower:
            _select_tower(clicked_tower)
            return
        _select_tower(null)
        _try_place_tower(world_pos)

func _find_tower_at_position(world_pos: Vector2) -> Node:
    for tower in get_tree().get_nodes_in_group("towers"):
        if not (tower is Node2D):
            continue
        if tower.global_position.distance_to(world_pos) <= 24.0:
            return tower
    return null

func _try_place_tower(world_pos: Vector2) -> void:
    if money < tower_cost:
        return
    if not _is_valid_tower_position(world_pos):
        return
    var tower = TOWER_SCENE.instantiate()
    tower.global_position = world_pos
    if tower.has_method("configure_base_cost"):
        tower.configure_base_cost(tower_cost)
    if tower.has_method("set_world_scale"):
        tower.set_world_scale(_world_scale)
    add_child(tower)
    money -= tower_cost
    _select_tower(tower)
    _update_labels()

func _is_valid_tower_position(world_pos: Vector2) -> bool:
    var path_node := get_node_or_null("Path") as Path2D
    if path_node and path_node.curve:
        var closest = path_node.curve.get_closest_point(world_pos)
        if world_pos.distance_to(closest) <= road_half_width:
            return false
    for tower in get_tree().get_nodes_in_group("towers"):
        if tower is Node2D and tower.global_position.distance_to(world_pos) < min_tower_spacing:
            return false
    return true

func _select_tower(tower: Node) -> void:
    if _selected_tower and _selected_tower.has_method("set_selected"):
        _selected_tower.set_selected(false)
    _selected_tower = tower
    if _selected_tower and _selected_tower.has_method("set_selected"):
        _selected_tower.set_selected(true)
    _update_labels()

func _start_next_wave() -> void:
    if _game_over:
        return
    _next_wave_queued = false
    if _spawning_wave or _active_enemies > 0:
        return
    await get_tree().create_timer(1.5).timeout
    if _game_over:
        return
    _spawning_wave = true
    wave_index += 1
    _update_labels()
    
    var path_node := get_node_or_null("Path") as Path2D
    if path_node == null:
        _spawning_wave = false
        return
    
    var enemy_count = 6 + wave_index * 2
    for i in range(enemy_count):
        if _game_over:
            return
        _spawn_enemy(path_node)
        var interval: float = maxf(0.25, 0.65 - float(wave_index) * 0.03)
        await get_tree().create_timer(interval).timeout
    
    _spawning_wave = false
    _update_labels()

func _spawn_enemy(path_node: Path2D) -> void:
    var enemy = ENEMY_SCENE.instantiate()
    enemy.progress = 0.0
    enemy.max_hp = 80 + wave_index * 22
    enemy.hp = enemy.max_hp
    enemy.speed = 80.0 + wave_index * 4.5
    enemy.reward = 16 + wave_index * 2
    if enemy.has_method("set_world_scale"):
        enemy.set_world_scale(_world_scale)
    enemy.died.connect(_on_enemy_died)
    enemy.escaped.connect(_on_enemy_escaped)
    _active_enemies += 1
    path_node.add_child(enemy)

func _on_upgrade_pressed():
    if _selected_tower == null:
        return
    if not _selected_tower.has_method("upgrade_stats"):
        return
    if not _selected_tower.has_method("get_upgrade_cost"):
        return
    var cost: int = _selected_tower.get_upgrade_cost()
    if money < cost:
        return
    money -= cost
    _selected_tower.upgrade_stats()
    _update_labels()

func _on_sell_pressed():
    if _selected_tower == null:
        return
    if _selected_tower.has_method("get_sell_value"):
        money += _selected_tower.get_sell_value()
    _selected_tower.queue_free()
    _selected_tower = null
    _update_labels()

func _on_enemy_died(reward: int) -> void:
    money += reward
    enemies_defeated += 1
    _active_enemies = max(0, _active_enemies - 1)
    _update_labels()
    _try_schedule_next_wave()

func _on_enemy_escaped() -> void:
    lives = max(0, lives - 1)
    _active_enemies = max(0, _active_enemies - 1)
    _update_labels()
    if lives <= 0:
        _show_game_over()
    else:
        _try_schedule_next_wave()

func _try_schedule_next_wave() -> void:
    if _game_over:
        return
    if _active_enemies == 0 and not _spawning_wave and not _next_wave_queued:
        _next_wave_queued = true
        call_deferred("_start_next_wave")

func _show_game_over():
    if _game_over:
        return
    _game_over = true
    var label = Label.new()
    label.position = Vector2(400, 200)
    label.text = "GAME OVER"
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_to_group("game_over")
    add_child(label)
    get_tree().paused = true

func _on_viewport_size_changed() -> void:
    if _resize_refresh_queued:
        return
    _resize_refresh_queued = true
    call_deferred("_apply_viewport_resize_refresh")

func _apply_viewport_resize_refresh() -> void:
    _resize_refresh_queued = false
    var old_size: Vector2 = _last_viewport_size
    var new_size: Vector2 = get_viewport_rect().size
    _reposition_towers_for_resize(old_size, new_size)
    _recalculate_resolution_scale()
    var path_node: Node = get_node_or_null("Path")
    if path_node != null:
        _ensure_path_setup(path_node)
    _setup_ui()
    _apply_scale_to_existing_entities()
    _last_viewport_size = new_size

func _recalculate_resolution_scale() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        _ui_scale = 1.0
        _world_scale = 1.0
    else:
        var sx: float = viewport_size.x / BASE_RESOLUTION.x
        var sy: float = viewport_size.y / BASE_RESOLUTION.y
        _ui_scale = clampf(minf(sx, sy), 0.65, 2.5)
        _world_scale = _ui_scale
    road_half_width = BASE_ROAD_HALF_WIDTH * _world_scale
    min_tower_spacing = BASE_TOWER_SPACING * _world_scale

func _apply_scale_to_existing_entities() -> void:
    for tower in get_tree().get_nodes_in_group("towers"):
        if tower != null and tower.has_method("set_world_scale"):
            tower.set_world_scale(_world_scale)
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy != null and enemy.has_method("set_world_scale"):
            enemy.set_world_scale(_world_scale)

func _reposition_towers_for_resize(old_size: Vector2, new_size: Vector2) -> void:
    if old_size.x <= 0.0 or old_size.y <= 0.0 or new_size.x <= 0.0 or new_size.y <= 0.0:
        return
    if old_size.is_equal_approx(new_size):
        return
    var old_center: Vector2 = old_size * 0.5
    var new_center: Vector2 = new_size * 0.5
    var old_radius_base: float = minf(old_size.x, old_size.y)
    var new_radius_base: float = minf(new_size.x, new_size.y)
    var position_scale: float = 1.0
    if old_radius_base > 0.0:
        position_scale = new_radius_base / old_radius_base
    for tower in get_tree().get_nodes_in_group("towers"):
        var tower_node := tower as Node2D
        if tower_node == null:
            continue
        var offset_from_center: Vector2 = tower_node.global_position - old_center
        tower_node.global_position = new_center + offset_from_center * position_scale
