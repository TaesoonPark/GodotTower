extends Node

const LOGIC: Script = preload("res://scripts/sim/HaulReservationLogic.gd")
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
	var jobs: Array = [{
		"type": &"HaulResource",
		"drop_id": 101,
		"queued_at_ms": 1000
	}, {
		"type": &"HaulResource",
		"drop_id": 202,
		"queued_at_ms": 6000
	}]
	var reservations: Dictionary = {
		101: {"assigned_to": 0, "reserved_at_ms": 1000},
		202: {"assigned_to": 777, "reserved_at_ms": 1000},
		303: {"assigned_to": 0, "reserved_at_ms": 1000}
	}
	var drop_states: Dictionary = {
		101: {"job_queued": true, "is_empty": false},
		202: {"job_queued": true, "is_empty": false}
	}

	var queue_result: Dictionary = LOGIC.collect_stale_queue_jobs(jobs, reservations, drop_states, 7005, 5000)
	var reservation_result: Dictionary = LOGIC.collect_stale_reservations(reservations, drop_states, 14050, 12000)

	if not queue_result.get("remove_indexes", []).has(0):
		_finish(false, "HAUL_RES_LOGIC_TEST_FAIL: stale queued haul not detected")
		return
	if not reservation_result.get("cancel_colonist_ids", []).has(777):
		_finish(false, "HAUL_RES_LOGIC_TEST_FAIL: stale assigned reservation not detected")
		return
	if not reservation_result.get("stale_drop_ids", []).has(303):
		_finish(false, "HAUL_RES_LOGIC_TEST_FAIL: missing drop reservation not detected")
		return

	_finish(true, "HAUL_RES_LOGIC_TEST_PASS: stale haul reservation rules match expectations")
