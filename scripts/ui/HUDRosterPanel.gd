extends PanelContainer
class_name HUDRosterPanel

signal portrait_selected(colonist_id: int)

@onready var title_label: Label = $VBox/RosterTitle
@onready var list_box: VBoxContainer = $VBox/RosterScroll/RosterList

var _entries: Array[Dictionary] = []
var _button_by_id: Dictionary = {}

func set_title(text: String) -> void:
	title_label.text = text

func set_entries(entries: Array) -> void:
	var normalized_entries: Array[Dictionary] = []
	for entry_any in entries:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = {
			"id": int(entry_any.get("id", 0)),
			"name": String(entry_any.get("name", "Colonist")),
			"selected": bool(entry_any.get("selected", false)),
			"alive": bool(entry_any.get("alive", true))
		}
		if entry["id"] == 0:
			continue
		normalized_entries.append(entry)
	if _entries == normalized_entries:
		return
	_entries.clear()
	for entry in normalized_entries:
		_entries.append(entry)
	_rebuild_buttons()

func _rebuild_buttons() -> void:
	for child in list_box.get_children():
		child.queue_free()
	_button_by_id.clear()
	for entry in _entries:
		var colonist_id: int = int(entry["id"])
		var colonist_name: String = String(entry["name"])
		var selected: bool = bool(entry["selected"])
		var alive: bool = bool(entry["alive"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(60.0, 60.0)
		button.text = _portrait_text(colonist_name)
		button.tooltip_text = colonist_name
		button.disabled = not alive
		button.focus_mode = Control.FOCUS_NONE
		if selected:
			button.modulate = Color(1.0, 0.9, 0.45, 1.0)
		button.pressed.connect(func():
			portrait_selected.emit(colonist_id)
		)
		list_box.add_child(button)
		_button_by_id[colonist_id] = button

func _portrait_text(colonist_name: String) -> String:
	var clean_name: String = colonist_name.strip_edges()
	if clean_name.is_empty():
		return "?"
	return clean_name.substr(0, 1)
