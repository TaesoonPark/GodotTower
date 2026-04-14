extends PanelContainer
class_name HUDCatalogPanel

signal item_pressed(mode: StringName, item_id: StringName)

@onready var title_label: Label = $VBox/HeaderRow/CatalogTitle
@onready var mode_label: Label = $VBox/HeaderRow/CatalogMode
@onready var item_list: HBoxContainer = $VBox/ItemScroll/ItemList
@onready var description_label: Label = $VBox/CatalogDescription

var _mode: StringName = &"None"
var _items: Array[Dictionary] = []
var _selected_id: StringName = &""
var _button_by_id: Dictionary = {}

func set_mode(mode: StringName, mode_text: String) -> void:
	_mode = mode
	mode_label.text = mode_text

func set_title(text: String) -> void:
	title_label.text = text

func set_description(text: String) -> void:
	description_label.text = text

func set_items(items: Array, selected_id: StringName = &"") -> void:
	var normalized_items: Array[Dictionary] = []
	for item_any in items:
		if not (item_any is Dictionary):
			continue
		var item_id: StringName = StringName(item_any.get("id", &""))
		if item_id == &"":
			continue
		var item: Dictionary = {
			"id": item_id,
			"label": String(item_any.get("label", String(item_id))),
			"tooltip": String(item_any.get("tooltip", "")),
			"disabled": bool(item_any.get("disabled", false))
		}
		normalized_items.append(item)
	if _items == normalized_items and _selected_id == selected_id:
		return
	_items.clear()
	for item in normalized_items:
		_items.append(item)
	_selected_id = selected_id
	_rebuild_items()

func get_item_button_rect(item_id: StringName) -> Rect2:
	var button: Button = _button_by_id.get(item_id, null)
	if button == null or not is_instance_valid(button):
		return Rect2()
	return button.get_global_rect()

func _rebuild_items() -> void:
	for child in item_list.get_children():
		child.queue_free()
	_button_by_id.clear()
	for item in _items:
		var item_id: StringName = StringName(item["id"])
		var button := Button.new()
		button.custom_minimum_size = Vector2(180.0, 64.0)
		button.text = String(item["label"])
		button.tooltip_text = String(item["tooltip"])
		button.disabled = bool(item["disabled"]) or item_id == _selected_id
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func():
			item_pressed.emit(_mode, item_id)
		)
		item_list.add_child(button)
		_button_by_id[item_id] = button
