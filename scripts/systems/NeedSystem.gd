extends Node
class_name NeedSystem

@export var tick_interval: float = 0.25

var _accum: float = 0.0

func process_needs(delta: float, colonists: Array) -> void:
	_accum += delta
	if _accum < tick_interval:
		return
	var tick_delta: float = _accum
	_accum = 0.0
	for colonist in colonists:
		if colonist != null:
			colonist.tick_needs(tick_delta)
