extends RefCounted
class_name CommandSequenceRunner

const SNAPSHOT: Script = preload("res://scripts/debug/SimulationSnapshot.gd")

var main: Node = null

func _init(main_node: Node) -> void:
	main = main_node

func run(commands: Array) -> Dictionary:
	for cmd_any in commands:
		if not (cmd_any is Dictionary):
			return {"ok": false, "error": "invalid command"}
		var cmd: Dictionary = cmd_any
		var action: StringName = StringName(cmd.get("action", &""))
		match action:
			&"wait_frames":
				var frames: int = maxi(1, int(cmd.get("frames", 1)))
				for _i in range(frames):
					await main.get_tree().process_frame
			&"set_colonist_work":
				_apply_work_flags(int(cmd.get("index", 0)), cmd.get("flags", {}))
			&"place_stockpile":
				var rect: Rect2 = cmd.get("rect", Rect2())
				if not main.build_system.place_stockpile_zone(rect):
					return {"ok": false, "error": "place_stockpile failed"}
				main._mark_group_cache_dirty(&"stockpile_zones")
				main._mark_jobs_dirty()
			&"spawn_drop":
				main._spawn_resource_drop(
					StringName(cmd.get("resource_type", &"Wood")),
					int(cmd.get("amount", 0)),
					cmd.get("pos", Vector2.ZERO)
				)
			&"snapshot":
				print("COMMAND_SEQUENCE_SNAPSHOT")
				print(SNAPSHOT.to_text(SNAPSHOT.from_main(main)))
			&"wait_until_stock":
				var ok: bool = await _wait_until_stock(
					StringName(cmd.get("resource_type", &"Wood")),
					int(cmd.get("at_least", 1)),
					int(cmd.get("timeout_frames", 900))
				)
				if not ok:
					return {
						"ok": false,
						"error": "wait_until_stock timeout",
						"snapshot": SNAPSHOT.from_main(main)
					}
			_:
				return {"ok": false, "error": "unknown action: %s" % String(action)}
	return {"ok": true}

func run_from_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "failed to open scenario: %s" % path}
	var raw: String = file.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		return {"ok": false, "error": "scenario root must be an array"}
	var commands: Array = []
	for item in parsed:
		if item is Dictionary:
			commands.append(_decode_command(item))
	return await run(commands)

func _apply_work_flags(index: int, flags: Dictionary) -> void:
	var colonists: Array = main.get_tree().get_nodes_in_group("colonists")
	if index < 0 or index >= colonists.size():
		return
	var colonist = colonists[index]
	if colonist == null or not is_instance_valid(colonist):
		return
	if colonist.has_method("cancel_current_job"):
		colonist.cancel_current_job()
	for key_any in flags.keys():
		colonist.set_work_enabled(StringName(key_any), bool(flags[key_any]))
	main._mark_jobs_dirty()

func _wait_until_stock(resource_type: StringName, at_least: int, timeout_frames: int) -> bool:
	for _i in range(maxi(1, timeout_frames)):
		await main.get_tree().process_frame
		var total: int = 0
		for zone in main.get_tree().get_nodes_in_group("stockpile_zones"):
			if zone == null or not is_instance_valid(zone):
				continue
			if zone.has_method("get_stored_amount"):
				total += int(zone.get_stored_amount(resource_type))
		if total >= at_least:
			return true
	return false

func _decode_command(cmd: Dictionary) -> Dictionary:
	var out: Dictionary = cmd.duplicate(true)
	var action: StringName = StringName(out.get("action", &""))
	if action == &"place_stockpile" and out.has("rect"):
		var rect_def: Dictionary = out.get("rect", {})
		out["rect"] = Rect2(
			Vector2(float(rect_def.get("x", 0.0)), float(rect_def.get("y", 0.0))),
			Vector2(float(rect_def.get("w", 0.0)), float(rect_def.get("h", 0.0)))
		)
	if action == &"spawn_drop" and out.has("pos"):
		var pos_def: Dictionary = out.get("pos", {})
		out["pos"] = Vector2(float(pos_def.get("x", 0.0)), float(pos_def.get("y", 0.0)))
	return out
