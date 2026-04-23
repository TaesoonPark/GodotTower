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

	var colonists: Array = get_tree().get_nodes_in_group("colonists")
	if colonists.is_empty():
		_finish(false, "HUD_EQUIPMENT_MULTILINE_FAIL: no colonists")
		return
	var colonist: Node = colonists[0]
	colonist.set_equipment_slots({
		&"Top": &"CombatTop",
		&"Bottom": &"CombatBottom",
		&"Hat": &"CombatHat",
		&"Weapon": &"Bow"
	})
	main._set_selected([colonist])
	main._refresh_hud()
	await get_tree().process_frame

	var label: Label = main.hud.get_node("SelectedStatusPanel/VBox/EquipmentLabel") as Label
	if label == null:
		_finish(false, "HUD_EQUIPMENT_MULTILINE_FAIL: equipment label missing")
		return
	var text: String = label.text
	var lines: PackedStringArray = text.split("\n", false)
	if lines.size() < 5:
		_finish(false, "HUD_EQUIPMENT_MULTILINE_FAIL: equipment text not multiline text=%s" % text)
		return
	for expected in ["상의: Combat Top", "하의: Combat Bottom", "모자: Combat Hat", "무기: Bow"]:
		if not text.contains(expected):
			_finish(false, "HUD_EQUIPMENT_MULTILINE_FAIL: missing '%s' in text=%s" % [expected, text])
			return
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		_finish(false, "HUD_EQUIPMENT_MULTILINE_FAIL: equipment label autowrap is off")
		return

	_finish(true, "HUD_EQUIPMENT_MULTILINE_PASS: equipment preview uses vertical multiline text")
