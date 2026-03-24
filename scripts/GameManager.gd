extends Node2D

const TOWER_SCENE = preload("res://scenes/Tower.tscn")
const ENEMY_SCENE = preload("res://scenes/Enemy.tscn")
const PATH_SCENE = preload("res://scenes/Path.tscn")

var money: int = 200
var selected_for_placement: bool = false
var tower_cost: int = 100
var upgrade_cost: int = 75
var wave_active: bool = false
var wave_index: int = 0
var enemies_defeated: int = 0
var lives: int = 20

func _ready():
    var path_inst = PATH_SCENE.instantiate()
    path_inst.name = "Path"
    add_child(path_inst)
    
    call_deferred("_setup_ui")
    call_deferred("_spawn_enemy_wave")

func _setup_ui():
    var hud = get_node_or_null("CanvasLayer")
    if not hud:
        hud = CanvasLayer.new()
        hud.name = "CanvasLayer"
        add_child(hud)
    
    var money_label = get_node_or_null("CanvasLayer/MoneyLabel")
    if not money_label:
        money_label = Label.new()
        money_label.name = "MoneyLabel"
        money_label.position = Vector2(20, 20)
        money_label.text = "Money: %d" % money
        hud.add_child(money_label)
    
    var wave_label = get_node_or_null("CanvasLayer/WaveLabel")
    if not wave_label:
        wave_label = Label.new()
        wave_label.name = "WaveLabel"
        wave_label.position = Vector2(20, 50)
        wave_label.text = "Wave: %d" % (wave_index + 1)
        hud.add_child(wave_label)
    
    var lives_label = get_node_or_null("CanvasLayer/LivesLabel")
    if not lives_label:
        lives_label = Label.new()
        lives_label.name = "LivesLabel"
        lives_label.position = Vector2(20, 80)
        lives_label.text = "Lives: %d" % lives
        hud.add_child(lives_label)
    
    var upgrade_btn = get_node_or_null("CanvasLayer/UpgradeBtn")
    if not upgrade_btn:
        upgrade_btn = Button.new()
        upgrade_btn.name = "UpgradeBtn"
        upgrade_btn.position = Vector2(20, 120)
        upgrade_btn.text = "Upgrade"
        upgrade_btn.connect("pressed", Callable(self, "_on_upgrade_pressed"))
        hud.add_child(upgrade_btn)
    
    var sell_btn = get_node_or_null("CanvasLayer/SellBtn")
    if not sell_btn:
        sell_btn = Button.new()
        sell_btn.name = "SellBtn"
        sell_btn.position = Vector2(100, 120)
        sell_btn.text = "Sell"
        sell_btn.connect("pressed", Callable(self, "_on_sell_pressed"))
        hud.add_child(sell_btn)
    
    _update_labels()

func _update_labels():
    var money_label = get_node_or_null("CanvasLayer/MoneyLabel")
    if money_label:
        money_label.text = "Money: %d" % money
    
    var wave_label = get_node_or_null("CanvasLayer/WaveLabel")
    if wave_label:
        wave_label.text = "Wave: %d" % (wave_index + 1)
    
    var lives_label = get_node_or_null("CanvasLayer/LivesLabel")
    if lives_label:
        lives_label.text = "Lives: %d" % lives

func _spawn_enemy_wave() -> void:
    await get_tree().process_frame
    
    var path_node = get_node_or_null("Path")
    if not path_node:
        return
    
    var enemy_count = 5 + wave_index * 2
    for i in range(enemy_count):
        var enemy = ENEMY_SCENE.instantiate()
        enemy.position = Vector2.ZERO
        enemy.set_path(path_node)
        enemy.max_hp = 100 + wave_index * 20
        enemy.hp = enemy.max_hp
        enemy.speed = 80.0 + wave_index * 5
        add_child(enemy)
        await get_tree().create_timer(0.8).timeout
    
    wave_active = true
    wave_index += 1

func _input(event):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var world_pos = get_global_mouse_position()
        if selected_for_placement:
            if money >= tower_cost:
                var tower = TOWER_SCENE.instantiate()
                tower.global_position = world_pos
                add_child(tower)
                money -= tower_cost
                _update_labels()
            selected_for_placement = false
        else:
            selected_for_placement = true

func _on_upgrade_pressed():
    var tower = get_node_or_null("Tower")
    if tower and money >= upgrade_cost:
        tower.damage += 10
        tower.range += 20
        money -= upgrade_cost
        _update_labels()

func _on_sell_pressed():
    var tower = get_node_or_null("Tower")
    if tower:
        money += tower_cost / 2
        tower.queue_free()
        _update_labels()

func _on_enemy_killed():
    money += 25
    enemies_defeated += 1
    _update_labels()

func _on_enemy_reached_end():
    lives -= 1
    _update_labels()
    if lives <= 0:
        _game_over()

func _game_over():
    var label = Label.new()
    label.position = Vector2(400, 200)
    label.text = "GAME OVER"
    label.align = Label.ALIGN_CENTER
    label.add_to_group("game_over")
    add_child(label)
    get_tree().set_pause(true)
