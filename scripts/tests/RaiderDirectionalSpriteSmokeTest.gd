extends Node

const RAIDER_SCENE: PackedScene = preload("res://scenes/units/Raider.tscn")
const ZOMBIE_SCENE: PackedScene = preload("res://scenes/units/Zombie.tscn")
const GAME_SPRITE: Script = preload("res://scripts/core/GameSprite.gd")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1

const EXPECTED_FRAMES: Array[StringName] = [
	&"idle_front",
	&"idle_back",
	&"idle_left",
	&"idle_right",
	&"walk_front_0",
	&"walk_front_1",
	&"walk_back_0",
	&"walk_back_1",
	&"walk_left_0",
	&"walk_left_1",
	&"walk_right_0",
	&"walk_right_1"
]

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
	if not _assert_unit_frames(&"raider"):
		return
	if not _assert_unit_frames(&"zombie"):
		return

	var raider: Node2D = RAIDER_SCENE.instantiate()
	add_child(raider)
	await get_tree().process_frame

	var sprite: Sprite2D = raider.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null or sprite.texture == null:
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: raider sprite not initialized")
		return

	if not _assert_unit_direction_frame(raider, sprite, &"raider"):
		return

	var zombie: Node2D = ZOMBIE_SCENE.instantiate()
	add_child(zombie)
	await get_tree().process_frame

	var zombie_sprite: Sprite2D = zombie.get_node_or_null("Sprite2D") as Sprite2D
	if zombie_sprite == null or zombie_sprite.texture == null:
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: zombie sprite not initialized")
		return

	if not _assert_unit_direction_frame(zombie, zombie_sprite, &"zombie"):
		return

	_finish(true, "RAIDER_SPRITE_TEST_PASS: enemy directional frames load and apply")

func _assert_unit_frames(unit_id: StringName) -> bool:
	for frame_id in EXPECTED_FRAMES:
		var texture: Texture2D = GAME_SPRITE.get_unit_frame_texture(unit_id, frame_id)
		if texture == null:
			_finish(false, "RAIDER_SPRITE_TEST_FAIL: missing %s frame %s" % [String(unit_id), String(frame_id)])
			return false
		if texture.get_size() != Vector2(64.0, 64.0):
			_finish(false, "RAIDER_SPRITE_TEST_FAIL: %s frame %s has size %s" % [String(unit_id), String(frame_id), str(texture.get_size())])
			return false
		if not _assert_frame_has_padding(unit_id, frame_id, texture):
			return false
	if unit_id == &"raider" and not _assert_raider_frame_scale():
		return false
	return true

func _assert_frame_has_padding(unit_id: StringName, frame_id: StringName, texture: Texture2D) -> bool:
	var bbox: Rect2i = _alpha_bbox(texture)
	if bbox.size == Vector2i.ZERO:
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: %s frame %s is empty" % [String(unit_id), String(frame_id)])
		return false
	if bbox.position.x <= 0 or bbox.position.y <= 0 or bbox.end.x >= 64 or bbox.end.y >= 64:
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: %s frame %s touches frame edge %s" % [String(unit_id), String(frame_id), str(bbox)])
		return false
	return true

func _assert_raider_frame_scale() -> bool:
	var min_height: int = 999999
	var max_height: int = 0
	for frame_id in EXPECTED_FRAMES:
		var texture: Texture2D = GAME_SPRITE.get_unit_frame_texture(&"raider", frame_id)
		var bbox: Rect2i = _alpha_bbox(texture)
		min_height = mini(min_height, bbox.size.y)
		max_height = maxi(max_height, bbox.size.y)
	if max_height - min_height > 2:
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: raider frame scale drift min=%d max=%d" % [min_height, max_height])
		return false
	return true

func _alpha_bbox(texture: Texture2D) -> Rect2i:
	var image: Image = texture.get_image()
	if image == null:
		return Rect2i()
	var min_x: int = image.get_width()
	var min_y: int = image.get_height()
	var max_x: int = -1
	var max_y: int = -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _assert_unit_direction_frame(unit: Node2D, sprite: Sprite2D, unit_id: StringName) -> bool:
	unit.call("_update_body_sprite", Vector2.RIGHT * 8.0, 0.2)
	if sprite.texture != GAME_SPRITE.get_unit_frame_texture(unit_id, &"walk_right_1"):
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: %s right movement frame not applied" % String(unit_id))
		return false

	unit.call("_update_body_sprite", Vector2.UP * 8.0, 0.2)
	if sprite.texture != GAME_SPRITE.get_unit_frame_texture(unit_id, &"walk_back_0"):
		_finish(false, "RAIDER_SPRITE_TEST_FAIL: %s back movement frame not applied" % String(unit_id))
		return false
	return true
