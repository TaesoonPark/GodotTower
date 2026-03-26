extends CanvasLayer
class_name HUDController

@onready var selected_label: Label = $PanelContainer/VBox/SelectedLabel
@onready var mode_label: Label = $PanelContainer/VBox/ModeLabel
@onready var needs_label: Label = $PanelContainer/VBox/NeedsLabel
@onready var priority_label: Label = $PanelContainer/VBox/PriorityLabel
@onready var build_button: Button = $PanelContainer/VBox/BuildButton
@onready var haul_slider: HSlider = $PanelContainer/VBox/PriorityGrid/HaulSlider
@onready var build_slider: HSlider = $PanelContainer/VBox/PriorityGrid/BuildSlider
@onready var craft_slider: HSlider = $PanelContainer/VBox/PriorityGrid/CraftSlider
@onready var combat_slider: HSlider = $PanelContainer/VBox/PriorityGrid/CombatSlider

signal priority_changed(job_type: StringName, value: int)
signal build_mode_toggled(enabled: bool)

var _build_mode: bool = false

func _ready() -> void:
	haul_slider.value_changed.connect(func(v: float): priority_changed.emit(&"Haul", int(v)))
	build_slider.value_changed.connect(func(v: float): priority_changed.emit(&"Build", int(v)))
	craft_slider.value_changed.connect(func(v: float): priority_changed.emit(&"Craft", int(v)))
	combat_slider.value_changed.connect(func(v: float): priority_changed.emit(&"Combat", int(v)))
	build_button.pressed.connect(_on_build_button_pressed)

func set_selected_count(count: int) -> void:
	selected_label.text = "Selected: %d" % count

func set_build_mode(enabled: bool) -> void:
	_build_mode = enabled
	mode_label.text = "Mode: %s" % ("Build" if enabled else "Command")
	build_button.text = "Build ON" if enabled else "Build OFF"

func set_needs_preview(colonist: Node) -> void:
	if colonist == null:
		needs_label.text = "Needs: -"
		return
	needs_label.text = "Needs H:%.0f R:%.0f M:%.0f" % [colonist.hunger, colonist.rest, colonist.mood]

func set_priority_preview(colonist: Node) -> void:
	if colonist == null:
		priority_label.text = "Priority: -"
		return
	priority_label.text = "Priority H:%d B:%d C:%d Cb:%d" % [
		colonist.priorities.haul,
		colonist.priorities.build,
		colonist.priorities.craft,
		colonist.priorities.combat
	]
	haul_slider.value = colonist.priorities.haul
	build_slider.value = colonist.priorities.build
	craft_slider.value = colonist.priorities.craft
	combat_slider.value = colonist.priorities.combat

func _on_build_button_pressed() -> void:
	set_build_mode(not _build_mode)
	build_mode_toggled.emit(_build_mode)
