extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")
const EXIT_PASS: int = 0
const EXIT_FAIL: int = 1
const TEST_SLOT: String = "save_reset_smoke_test"

func _ready() -> void:
	call_deferred("_run_test")

func _finish(success: bool, message: String) -> void:
	_delete_test_save()
	if success:
		print(message)
		get_tree().quit(EXIT_PASS)
		return
	printerr(message)
	get_tree().quit(EXIT_FAIL)

func _run_test() -> void:
	_delete_test_save()
	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	for _i in range(20):
		await get_tree().process_frame

	var hud: HUDController = main.get("hud") as HUDController
	if hud == null or not is_instance_valid(hud):
		_finish(false, "SAVE_RESET_TEST_FAIL: hud missing")
		return
	var raid_button: Button = hud.get_node_or_null("RaidTestButton") as Button
	var reset_button: Button = hud.get_node_or_null("SaveResetButton") as Button
	if raid_button == null or reset_button == null:
		_finish(false, "SAVE_RESET_TEST_FAIL: debug buttons missing")
		return
	if reset_button.text.is_empty():
		_finish(false, "SAVE_RESET_TEST_FAIL: reset button text is empty")
		return
	if reset_button.global_position.x <= raid_button.global_position.x:
		_finish(false, "SAVE_RESET_TEST_FAIL: reset button is not next to raid button")
		return

	main.resource_stock = main._empty_resource_stock()
	main.resource_stock[&"Wood"] = 42
	if not bool(main.save_game_to_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: save setup failed")
		return
	if not bool(main.has_save_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: test save missing before delete")
		return
	if not bool(main.delete_save_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: delete_save_slot returned false")
		return
	if bool(main.has_save_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: test save still exists after delete")
		return

	main.resource_stock[&"Wood"] = 99
	if not bool(main.save_game_to_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: reload save setup failed")
		return

	main._mark_pathing_dirty()
	main._mark_maintenance_dirty()
	get_tree().current_scene = main
	var old_main_id: int = main.get_instance_id()
	if not bool(main.reset_save_and_reload_game_scene(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: reset reload returned false")
		return

	var reloaded: Node = null
	for _i in range(120):
		await get_tree().process_frame
		var current: Node = get_tree().current_scene
		if current != null and is_instance_valid(current) and current.name == "Main" and current.get_instance_id() != old_main_id:
			reloaded = current
			break
	if reloaded == null:
		_finish(false, "SAVE_RESET_TEST_FAIL: current scene did not reload")
		return
	if bool(reloaded.has_save_slot(TEST_SLOT)):
		_finish(false, "SAVE_RESET_TEST_FAIL: test save survived reset reload")
		return

	_finish(true, "SAVE_RESET_TEST_PASS: save reset button deletes save and reloads game scene")

func _delete_test_save() -> void:
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return
	var file_name := "%s_autosave.json" % TEST_SLOT
	if dir.file_exists(file_name):
		dir.remove(file_name)
