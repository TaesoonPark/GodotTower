extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
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

	for _i in range(20):
		await get_tree().process_frame

	var hud = main.hud
	if hud == null or not is_instance_valid(hud):
		_finish(false, "HUD_SPACE_FOCUS_TEST_FAIL: hud missing")
		return
	var build_button: Button = hud.build_catalog_button
	if build_button == null or not is_instance_valid(build_button):
		_finish(false, "HUD_SPACE_FOCUS_TEST_FAIL: build button missing")
		return

	if build_button.focus_mode != Control.FOCUS_NONE:
		_finish(false, "HUD_SPACE_FOCUS_TEST_FAIL: build button focus mode is not NONE")
		return

	var catalog_visible_before: bool = bool(hud.is_bottom_catalog_visible())
	var paused_before: bool = bool(main._game_paused)

	var key_down := InputEventKey.new()
	key_down.keycode = KEY_SPACE
	key_down.physical_keycode = KEY_SPACE
	key_down.pressed = true
	get_viewport().push_input(key_down)
	var key_up := InputEventKey.new()
	key_up.keycode = KEY_SPACE
	key_up.physical_keycode = KEY_SPACE
	key_up.pressed = false
	get_viewport().push_input(key_up)
	for _i in range(4):
		await get_tree().process_frame

	if bool(hud.is_bottom_catalog_visible()) != catalog_visible_before:
		_finish(false, "HUD_SPACE_FOCUS_TEST_FAIL: space toggled UI catalog due to focus")
		return
	if bool(main._game_paused) == paused_before:
		_finish(false, "HUD_SPACE_FOCUS_TEST_FAIL: space did not toggle pause")
		return

	_finish(true, "HUD_SPACE_FOCUS_TEST_PASS: no button focus interference on space pause")
