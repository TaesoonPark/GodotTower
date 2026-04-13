extends RefCounted
class_name ScenarioTraceRunner

const COMMAND_RUNNER: Script = preload("res://scripts/debug/CommandSequenceRunner.gd")
const SNAPSHOT: Script = preload("res://scripts/debug/SimulationSnapshot.gd")

var main: Node = null

func _init(main_node: Node) -> void:
	main = main_node

func run_with_trace(commands: Array, emit_every_command: bool = true) -> Dictionary:
	var runner = COMMAND_RUNNER.new(main)
	if emit_every_command:
		for index in range(commands.size()):
			var result: Dictionary = await runner.run([commands[index]])
			print("SCENARIO_TRACE_STEP %d" % index)
			print(SNAPSHOT.to_text(SNAPSHOT.from_main(main)))
			if not bool(result.get("ok", false)):
				return result
		return {"ok": true}
	return await runner.run(commands)
