extends CanvasLayer
class_name HUDController

@onready var selected_status_panel: PanelContainer = $SelectedStatusPanel
@onready var left_vbox: VBoxContainer = $LeftPanel/VBox
@onready var context_action_button: Button = $ContextActionButton
@onready var status_title: Label = $SelectedStatusPanel/VBox/StatusTitle
@onready var selected_label: Label = $SelectedStatusPanel/VBox/SelectedLabel
@onready var mode_label: Label = $LeftPanel/VBox/ModeLabel
@onready var resources_label: Label = $TopResourceBar
@onready var time_flow_label: Label = $TimeFlowLabel
@onready var raid_status_label: Label = $RaidStatusLabel
@onready var raid_test_button: Button = $RaidTestButton
@onready var needs_label: Label = $SelectedStatusPanel/VBox/NeedsLabel
@onready var priority_label: Label = $SelectedStatusPanel/VBox/PriorityLabel
@onready var current_job_label: Label = $SelectedStatusPanel/VBox/CurrentJobLabel
@onready var carry_capacity_label: Label = $SelectedStatusPanel/VBox/CarryCapacityLabel
@onready var equipment_label: Label = $SelectedStatusPanel/VBox/EquipmentLabel
@onready var equipment_slots: HBoxContainer = $SelectedStatusPanel/VBox/EquipmentSlots
@onready var top_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/TopSlot/TopSlotIcon
@onready var bottom_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/BottomSlot/BottomSlotIcon
@onready var hat_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/HatSlot/HatSlotIcon
@onready var weapon_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/WeaponSlot/WeaponSlotIcon
@onready var stockpile_inventory_title: Label = $SelectedStatusPanel/VBox/StockpileInventoryTitle
@onready var stockpile_inventory_scroll: ScrollContainer = $SelectedStatusPanel/VBox/StockpileInventoryScroll
@onready var stockpile_inventory_list: VBoxContainer = $SelectedStatusPanel/VBox/StockpileInventoryScroll/StockpileInventoryList
@onready var selected_object_detail: Label = $SelectedStatusPanel/VBox/SelectedObjectDetail
@onready var selected_object_actions: HBoxContainer = $SelectedStatusPanel/VBox/SelectedObjectActions
@onready var work_toggle_title: Label = $SelectedStatusPanel/VBox/WorkToggleTitle
@onready var work_toggle_grid: GridContainer = $SelectedStatusPanel/VBox/WorkToggleGrid
@onready var priority_rule_label: Label = $LeftPanel/VBox/PriorityRuleLabel
@onready var action_title: Label = $LeftPanel/VBox/ActionTitle
@onready var command_grid: GridContainer = $LeftPanel/VBox/CommandGrid
@onready var mode_cycle_button: Button = $LeftPanel/VBox/CommandGrid/ModeCycleButton
@onready var drag_gather_button: Button = $LeftPanel/VBox/CommandGrid/DragGatherButton
@onready var drag_stockpile_button: Button = $LeftPanel/VBox/CommandGrid/DragStockpileButton
@onready var drag_farm_button: Button = $LeftPanel/VBox/CommandGrid/DragFarmButton
@onready var clear_state_button: Button = $LeftPanel/VBox/CommandGrid/ClearStateButton
@onready var command_hint_label: Label = $LeftPanel/VBox/CommandHintLabel
@onready var designation_panel: PanelContainer = $LeftPanel/VBox/DesignationPanel
@onready var designation_desc: Label = $LeftPanel/VBox/DesignationPanel/VBox/DesignationDesc
@onready var designation_toggle_button: Button = $LeftPanel/VBox/DesignationPanel/VBox/DesignationToggleButton
@onready var bed_assign_panel: PanelContainer = $LeftPanel/VBox/BedAssignPanel
@onready var bed_assign_option: OptionButton = $LeftPanel/VBox/BedAssignPanel/VBox/BedAssignOption
@onready var bed_assign_auto_button: Button = $LeftPanel/VBox/BedAssignPanel/VBox/BedAssignAutoButton
@onready var haul_slider: HSlider = $LeftPanel/VBox/PriorityGrid/HaulSlider
@onready var build_slider: HSlider = $LeftPanel/VBox/PriorityGrid/BuildSlider
@onready var craft_slider: HSlider = $LeftPanel/VBox/PriorityGrid/CraftSlider
@onready var combat_slider: HSlider = $LeftPanel/VBox/PriorityGrid/CombatSlider
@onready var gather_slider: HSlider = $LeftPanel/VBox/PriorityGrid/GatherSlider
@onready var hunt_slider: HSlider = $LeftPanel/VBox/PriorityGrid/HuntSlider
@onready var haul_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/HaulCheck
@onready var build_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/BuildCheck
@onready var craft_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/CraftCheck
@onready var combat_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/CombatCheck
@onready var gather_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/GatherCheck
@onready var hunt_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/HuntCheck
@onready var recipe_option: OptionButton = $LeftPanel/VBox/CraftControls/RecipeOption
@onready var queue_craft_button: Button = $LeftPanel/VBox/CraftControls/QueueCraftButton
@onready var queue_front_button: Button = $LeftPanel/VBox/CraftControls/QueueFrontButton
@onready var dequeue_button: Button = $LeftPanel/VBox/CraftQueueButtons/DequeueButton
@onready var clear_queue_button: Button = $LeftPanel/VBox/CraftQueueButtons/ClearQueueButton
@onready var craft_queue_scroll: ScrollContainer = $LeftPanel/VBox/CraftQueueScroll
@onready var craft_queue_list: VBoxContainer = $LeftPanel/VBox/CraftQueueScroll/CraftQueueList
@onready var workstation_option: OptionButton = $LeftPanel/VBox/WorkstationRow/WorkstationOption
@onready var separator_c: HSeparator = $LeftPanel/VBox/SeparatorC
@onready var craft_queue_title: Label = $LeftPanel/VBox/CraftQueueTitle
@onready var workstation_row: HBoxContainer = $LeftPanel/VBox/WorkstationRow
@onready var craft_controls: HBoxContainer = $LeftPanel/VBox/CraftControls
@onready var craft_queue_buttons: HBoxContainer = $LeftPanel/VBox/CraftQueueButtons
@onready var research_panel: PanelContainer = $LeftPanel/VBox/ResearchPanel
@onready var research_option: OptionButton = $LeftPanel/VBox/ResearchPanel/VBox/ResearchOption
@onready var research_start_button: Button = $LeftPanel/VBox/ResearchPanel/VBox/ResearchStartButton
@onready var research_progress_label: Label = $LeftPanel/VBox/ResearchPanel/VBox/ResearchProgressLabel
@onready var stockpile_filter_mode_option: OptionButton = $LeftPanel/VBox/StockpileFilterMode
@onready var stock_priority_spin: SpinBox = $LeftPanel/VBox/StockPriorityRow/StockPrioritySpin
@onready var stockpile_filter_title: Label = $LeftPanel/VBox/StockpileFilterTitle
@onready var stockpile_filter_grid: GridContainer = $LeftPanel/VBox/StockpileFilterGrid
@onready var stock_priority_row: HBoxContainer = $LeftPanel/VBox/StockPriorityRow
@onready var stock_limit_row: HBoxContainer = $LeftPanel/VBox/StockLimitRow
@onready var separator_d: HSeparator = $LeftPanel/VBox/SeparatorD
@onready var stock_wood_check: CheckBox = $LeftPanel/VBox/StockpileFilterGrid/StockWoodCheck
@onready var stock_stone_check: CheckBox = $LeftPanel/VBox/StockpileFilterGrid/StockStoneCheck
@onready var stock_steel_check: CheckBox = $LeftPanel/VBox/StockpileFilterGrid/StockSteelCheck
@onready var stock_food_raw_check: CheckBox = $LeftPanel/VBox/StockpileFilterGrid/StockFoodRawCheck
@onready var stock_meal_check: CheckBox = $LeftPanel/VBox/StockpileFilterGrid/StockMealCheck
@onready var stock_limit_resource_option: OptionButton = $LeftPanel/VBox/StockLimitRow/StockLimitResourceOption
@onready var stock_limit_spin: SpinBox = $LeftPanel/VBox/StockLimitRow/StockLimitSpin
@onready var stock_apply_limit_button: Button = $LeftPanel/VBox/StockLimitRow/StockApplyLimitButton
@onready var building_list: HBoxContainer = $BottomBuildPanel/BottomVBox/BuildScroll/BuildingList

signal priority_changed(job_type: StringName, value: int)
signal action_changed(action: StringName)
signal building_selected(building_id: StringName)
signal work_toggle_changed(work_type: StringName, enabled: bool)
signal craft_recipe_queued(recipe_id: StringName, workstation_id: StringName)
signal craft_recipe_front_queued(recipe_id: StringName, workstation_id: StringName)
signal craft_queue_clear_requested()
signal craft_queue_remove_requested(workstation_id: StringName, index: int)
signal craft_queue_pause_toggled(workstation_id: StringName, paused: bool)
signal workstation_changed(workstation_id: StringName)
signal stockpile_filter_mode_changed(mode: int)
signal stockpile_filter_item_changed(resource_type: StringName, enabled: bool)
signal stockpile_priority_changed(value: int)
signal stockpile_limit_changed(resource_type: StringName, limit: int)
signal stockpile_preset_apply_requested(preset_id: StringName)
signal designation_toggle_requested()
signal mouse_mode_cycle_requested()
signal drag_gather_mode_requested()
signal drag_stockpile_mode_requested()
signal drag_farm_mode_requested()
signal clear_state_requested()
signal rally_flag_mode_requested()
signal bed_assignee_changed(colonist_id: int)
signal bed_auto_assign_requested()
signal context_action_requested(action_id: StringName)
signal selected_object_action_requested(action_id: StringName)
signal outfit_mode_changed(mode: StringName)
signal raid_test_warning_requested()
signal research_project_changed(project_id: StringName)
signal research_start_requested()

var _active_action: StringName = &"Interact"
var _selected_building_id: StringName = &""
var _building_button_map: Dictionary = {}
var _recipe_id_by_index: Array[StringName] = []
var _workstation_ids_by_index: Array[StringName] = []
var _selected_workstation_id: StringName = &""
var _stock_filter_checks: Dictionary = {}
var _stock_signal_mute: bool = false
var _stock_limit_lookup: Dictionary = {}
var _bed_signal_mute: bool = false
var _order_panel_visible: bool = false
var _context_action_id: StringName = &""
var _selected_object_buttons: Array[Button] = []
var _outfit_mode: StringName = &"Work"
var _recipe_name_lookup: Dictionary = {}
var _last_craft_queue_items: Array[String] = []
var _last_selected_object_title: String = ""
var _last_selected_object_detail: String = ""
var _last_selected_object_actions_sig: String = ""
var _research_ids_by_index: Array[StringName] = []
var _rally_flag_button: Button = null
var _craft_pause_button: Button = null
var _craft_queue_paused: bool = false
var _stock_preset_row: HBoxContainer = null
var _stock_preset_option: OptionButton = null
var _stock_preset_apply_button: Button = null
var _defense_status_label: Label = null
var _priority_signal_mute: bool = false
var _last_resource_stock_text: String = ""
var _last_building_catalog_sig: String = ""
var _research_lock_map: Dictionary = {}
var _research_prereq_map: Dictionary = {}
var _research_tree_label: RichTextLabel = null

func _ready() -> void:
	haul_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Haul", int(v))
	)
	build_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Build", int(v))
	)
	craft_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Craft", int(v))
	)
	combat_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Combat", int(v))
	)
	gather_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Gather", int(v))
	)
	hunt_slider.value_changed.connect(func(v: float):
		if _priority_signal_mute:
			return
		priority_changed.emit(&"Hunt", int(v))
	)
	haul_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Haul", v))
	build_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Build", v))
	craft_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Craft", v))
	combat_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Combat", v))
	gather_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Gather", v))
	hunt_check.toggled.connect(func(v: bool): work_toggle_changed.emit(&"Hunt", v))
	queue_craft_button.pressed.connect(_on_queue_craft_button_pressed)
	queue_front_button.pressed.connect(_on_queue_craft_front_button_pressed)
	clear_queue_button.pressed.connect(func(): craft_queue_clear_requested.emit())
	_craft_pause_button = Button.new()
	_craft_pause_button.text = "일시정지"
	_craft_pause_button.custom_minimum_size = Vector2(96, 0)
	_craft_pause_button.pressed.connect(func():
		_craft_queue_paused = not _craft_queue_paused
		_refresh_craft_pause_button()
		craft_queue_pause_toggled.emit(_selected_workstation_id, _craft_queue_paused)
	)
	craft_queue_buttons.add_child(_craft_pause_button)
	workstation_option.item_selected.connect(_on_workstation_selected)
	_setup_stockpile_filter_widgets()
	designation_toggle_button.pressed.connect(func(): designation_toggle_requested.emit())
	drag_gather_button.pressed.connect(func(): drag_gather_mode_requested.emit())
	drag_stockpile_button.pressed.connect(func(): drag_stockpile_mode_requested.emit())
	drag_farm_button.pressed.connect(func(): drag_farm_mode_requested.emit())
	mode_cycle_button.pressed.connect(_on_order_toggle_pressed)
	clear_state_button.pressed.connect(_on_outfit_mode_pressed)
	_rally_flag_button = Button.new()
	_rally_flag_button.name = "RallyFlagButton"
	_rally_flag_button.custom_minimum_size = Vector2(186, 34)
	_rally_flag_button.text = "집합 깃발 설정"
	_rally_flag_button.tooltip_text = "클릭 후 맵에서 집합 위치를 지정합니다."
	_rally_flag_button.pressed.connect(func(): rally_flag_mode_requested.emit())
	command_grid.add_child(_rally_flag_button)
	raid_test_button.pressed.connect(func(): raid_test_warning_requested.emit())
	research_option.item_selected.connect(_on_research_selected)
	research_start_button.pressed.connect(func(): research_start_requested.emit())
	context_action_button.pressed.connect(_on_context_action_button_pressed)
	bed_assign_option.item_selected.connect(_on_bed_assign_selected)
	bed_assign_auto_button.pressed.connect(func(): bed_auto_assign_requested.emit())
	mode_label.text = "Order"
	action_title.text = "Action"
	priority_rule_label.text = "Order: Combat > Build > Craft > Gather > Hunt (haul is support)"
	selected_status_panel.visible = false
	action_title.visible = true
	command_grid.visible = true
	mode_cycle_button.text = "Order ON/OFF"
	mode_cycle_button.tooltip_text = "Toggle Order panel"
	set_outfit_mode(&"Work")
	clear_state_button.tooltip_text = "작업/전투 복장 선호도를 전환합니다."
	raid_test_button.text = "습격 테스트"
	raid_test_button.tooltip_text = "습격 경고(카운트다운)부터 시작"
	_defense_status_label = Label.new()
	_defense_status_label.text = "방어 상태: -"
	_defense_status_label.position = Vector2(16.0, 86.0)
	add_child(_defense_status_label)
	queue_craft_button.text = "실행"
	clear_queue_button.text = "초기화"
	queue_front_button.visible = true
	queue_front_button.text = "앞에 추가"
	dequeue_button.visible = false
	_refresh_craft_pause_button()
	_reorder_command_buttons()
	_reorder_left_panel_sections()
	_set_order_panel_visible(false)
	set_raid_state(&"Idle", 0.0)
	research_progress_label.text = "연구: 없음"
	_research_tree_label = RichTextLabel.new()
	_research_tree_label.name = "ResearchTreeLabel"
	_research_tree_label.bbcode_enabled = true
	_research_tree_label.fit_content = true
	_research_tree_label.scroll_active = false
	_research_tree_label.text = "[b]연구 트리[/b]\n없음"
	_research_tree_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_research_tree_label.add_theme_font_size_override("font_size", 11)
	var research_vbox: Node = research_panel.get_node("VBox")
	if research_vbox != null:
		research_vbox.add_child(_research_tree_label)
	set_craft_panel_visible(false)
	set_research_panel_visible(false)
	set_designation_panel_visible(false)
	set_bed_assignment_visible(false)
	set_active_action(_active_action)

func _reorder_command_buttons() -> void:
	var ordered_buttons: Array[Node] = [
		drag_gather_button,
		drag_stockpile_button,
		drag_farm_button,
		_rally_flag_button,
		mode_cycle_button,
		clear_state_button
	]
	var next_index: int = 0
	for node in ordered_buttons:
		if node != null and node.get_parent() == command_grid:
			command_grid.move_child(node, next_index)
			next_index += 1

func _reorder_left_panel_sections() -> void:
	var next_index: int = 0
	var title_node: Node = left_vbox.get_node("Title")
	left_vbox.move_child(title_node, next_index)
	next_index += 1
	var ordered_nodes: Array[Node] = [
		action_title,
		command_grid,
		command_hint_label,
		left_vbox.get_node("SeparatorA"),
		mode_label,
		priority_rule_label,
		left_vbox.get_node("PriorityGrid"),
		separator_c,
		craft_queue_title,
		workstation_row,
		craft_controls,
		craft_queue_buttons,
		craft_queue_scroll,
		research_panel
	]
	for node in ordered_nodes:
		if node != null and node.get_parent() == left_vbox:
			left_vbox.move_child(node, next_index)
			next_index += 1

func _on_order_toggle_pressed() -> void:
	_set_order_panel_visible(not _order_panel_visible)

func _on_outfit_mode_pressed() -> void:
	var next_mode: StringName = &"Combat" if _outfit_mode == &"Work" else &"Work"
	set_outfit_mode(next_mode)
	outfit_mode_changed.emit(next_mode)

func show_context_action_button(action_id: StringName, label_text: String, pointer_screen_pos: Vector2) -> void:
	_context_action_id = action_id
	context_action_button.text = label_text
	context_action_button.position = pointer_screen_pos + Vector2(18.0, 18.0)
	context_action_button.visible = true

func hide_context_action_button() -> void:
	_context_action_id = &""
	context_action_button.visible = false

func _on_context_action_button_pressed() -> void:
	if _context_action_id == &"":
		return
	context_action_requested.emit(_context_action_id)
	hide_context_action_button()

func _set_order_panel_visible(visible: bool) -> void:
	_order_panel_visible = visible
	mode_label.visible = visible
	priority_rule_label.visible = visible
	var priority_grid: Node = left_vbox.get_node_or_null("PriorityGrid")
	if priority_grid != null:
		priority_grid.visible = visible

func set_selected_count(count: int) -> void:
	selected_label.text = "Selected: %d" % count

func set_active_action(action: StringName) -> void:
	_active_action = action
	set_command_button_states(action)

func set_command_button_states(mode: StringName) -> void:
	drag_gather_button.disabled = mode == &"DragGather"
	drag_stockpile_button.disabled = mode == &"StockpileZone"
	drag_farm_button.disabled = mode == &"FarmZone"
	if _rally_flag_button != null:
		_rally_flag_button.disabled = mode == &"SetRallyFlag"
	match mode:
		&"DragGather":
			command_hint_label.text = "드래그한 범위를 채집/사냥 대상으로 지정합니다."
		&"StockpileZone":
			command_hint_label.text = "드래그한 범위를 저장구역으로 만듭니다."
		&"FarmZone":
			command_hint_label.text = "드래그한 범위를 농경지로 지정합니다."
		&"SetRallyFlag":
			command_hint_label.text = "집합 깃발 위치 지정: 원하는 타일을 클릭하세요."
		_:
			command_hint_label.text = "상호작용 모드: 클릭 대상에 따라 선택/설정 UI를 엽니다."

func set_resource_stock(stock: Dictionary) -> void:
	var keys := [
		&"Wood", &"Stone", &"Steel", &"FoodRaw", &"Meal", &"Bed",
		&"GatherTop", &"GatherBottom", &"StrawHat",
		&"CombatTop", &"CombatBottom", &"CombatHat",
		&"Sword", &"Bow"
	]
	var chunks: Array[String] = []
	for key in keys:
		chunks.append("%s:%d" % [String(key), int(stock.get(key, 0))])
	var next_text: String = "Resources: %s" % ", ".join(chunks)
	if next_text == _last_resource_stock_text:
		return
	_last_resource_stock_text = next_text
	resources_label.text = next_text

func set_outfit_mode(mode: StringName) -> void:
	_outfit_mode = &"Combat" if mode == &"Combat" else &"Work"
	if clear_state_button != null:
		clear_state_button.text = "복장: %s" % ("전투" if _outfit_mode == &"Combat" else "작업")

func set_raid_state(state: StringName, warning_seconds: float = 0.0, wave_kind: StringName = &"") -> void:
	if raid_status_label == null:
		return
	var kind_text: String = ""
	match wave_kind:
		&"ZombieHorde":
			kind_text = " [좀비]"
		&"Mixed":
			kind_text = " [혼합]"
		&"RaiderOnly":
			kind_text = " [약탈자]"
		_:
			kind_text = ""
	match state:
		&"Warning":
			raid_status_label.text = "습격 경고%s: %.0fs" % [kind_text, ceil(warning_seconds)]
			raid_status_label.modulate = Color(1.0, 0.78, 0.32, 1.0)
		&"Active":
			raid_status_label.text = "습격 진행중%s" % kind_text
			raid_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
		&"Resolved":
			raid_status_label.text = "습격 종료%s" % kind_text
			raid_status_label.modulate = Color(0.68, 0.96, 0.68, 1.0)
		_:
			raid_status_label.text = "습격 대기%s" % kind_text
			raid_status_label.modulate = Color(0.8, 0.86, 0.95, 1.0)

func set_defense_status(text: String) -> void:
	if _defense_status_label == null:
		return
	_defense_status_label.text = "방어 상태: %s" % text

func set_time_flow_state(paused: bool, speed_scale: float, elapsed_game_seconds: float) -> void:
	var elapsed_text: String = _format_elapsed_time(elapsed_game_seconds)
	if paused:
		time_flow_label.text = "Time: Paused | %s" % elapsed_text
		return
	time_flow_label.text = "Time: x%.1f | %s" % [speed_scale, elapsed_text]

func set_equipment_preview(colonist: Node) -> void:
	if colonist == null:
		equipment_label.text = "Equipment: -"
		_set_equipment_slot_icon(top_slot_icon, false, Color(0.36, 0.63, 0.9))
		_set_equipment_slot_icon(bottom_slot_icon, false, Color(0.55, 0.74, 0.95))
		_set_equipment_slot_icon(hat_slot_icon, false, Color(0.93, 0.74, 0.4))
		_set_equipment_slot_icon(weapon_slot_icon, false, Color(0.92, 0.38, 0.38))
		return
	var slots := {
		&"Top": &"",
		&"Bottom": &"",
		&"Hat": &"",
		&"Weapon": &""
	}
	if colonist.has_method("get_equipment_snapshot"):
		slots = colonist.get_equipment_snapshot()
	var top_name: StringName = StringName(slots.get(&"Top", &""))
	var bottom_name: StringName = StringName(slots.get(&"Bottom", &""))
	var hat_name: StringName = StringName(slots.get(&"Hat", &""))
	var weapon_name: StringName = StringName(slots.get(&"Weapon", &""))
	var equipped_parts: Array[String] = []
	if top_name != &"":
		equipped_parts.append("Top:%s" % String(top_name))
	if bottom_name != &"":
		equipped_parts.append("Bottom:%s" % String(bottom_name))
	if hat_name != &"":
		equipped_parts.append("Hat:%s" % String(hat_name))
	if weapon_name != &"":
		equipped_parts.append("Weapon:%s" % String(weapon_name))
	equipment_label.text = "Equipment: %s" % ("None" if equipped_parts.is_empty() else ", ".join(equipped_parts))
	_set_equipment_slot_icon(top_slot_icon, top_name != &"", Color(0.36, 0.63, 0.9))
	_set_equipment_slot_icon(bottom_slot_icon, bottom_name != &"", Color(0.55, 0.74, 0.95))
	_set_equipment_slot_icon(hat_slot_icon, hat_name != &"", Color(0.93, 0.74, 0.4))
	_set_equipment_slot_icon(weapon_slot_icon, weapon_name != &"", Color(0.92, 0.38, 0.38))

func _format_elapsed_time(total_seconds: float) -> String:
	var total: int = maxi(0, int(floor(total_seconds)))
	var hours: int = int(total / 3600)
	var minutes: int = int((total % 3600) / 60)
	var seconds: int = int(total % 60)
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

func _set_equipment_slot_icon(icon: ColorRect, equipped: bool, equipped_color: Color) -> void:
	if icon == null:
		return
	icon.color = equipped_color if equipped else Color(0.14, 0.14, 0.14, 1.0)

func set_needs_preview(colonist: Node) -> void:
	if colonist == null:
		needs_label.text = "Needs: -"
		return
	needs_label.text = "Needs H:%.0f R:%.0f M:%.0f" % [colonist.hunger, colonist.rest, colonist.mood]

func set_stockpile_inventory_preview(stockpile_zone: Node) -> void:
	var is_stockpile_selected: bool = stockpile_zone != null and is_instance_valid(stockpile_zone)
	if is_stockpile_selected:
		status_title.text = "Selected Stockpile"
		selected_label.text = "Selected: Stockpile"
		needs_label.visible = false
		priority_label.visible = false
		current_job_label.visible = false
		carry_capacity_label.visible = false
		equipment_label.visible = false
		equipment_slots.visible = false
		work_toggle_title.visible = false
		work_toggle_grid.visible = false
		stockpile_inventory_title.visible = true
		stockpile_inventory_scroll.visible = true
		selected_object_detail.visible = false
		selected_object_actions.visible = false
		_rebuild_selected_object_actions([])
		var snapshot: Dictionary = {}
		if stockpile_zone.has_method("get_stored_snapshot"):
			snapshot = stockpile_zone.get_stored_snapshot()
		_rebuild_stockpile_inventory_items(snapshot)
		return
	status_title.text = "Selected Unit"
	needs_label.visible = true
	priority_label.visible = true
	current_job_label.visible = true
	carry_capacity_label.visible = true
	equipment_label.visible = true
	equipment_slots.visible = true
	work_toggle_title.visible = true
	work_toggle_grid.visible = true
	stockpile_inventory_title.visible = false
	stockpile_inventory_scroll.visible = false
	selected_object_detail.visible = false
	selected_object_actions.visible = false
	_rebuild_selected_object_actions([])
	_rebuild_stockpile_inventory_items({})

func _rebuild_stockpile_inventory_items(stored_map: Dictionary) -> void:
	for child in stockpile_inventory_list.get_children():
		child.queue_free()
	if stored_map.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Empty"
		stockpile_inventory_list.add_child(empty_label)
		return
	var keys: Array = stored_map.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for k in keys:
		var amount: int = int(stored_map.get(k, 0))
		if amount <= 0:
			continue
		var row := Label.new()
		row.text = "%s x%d" % [String(k), amount]
		stockpile_inventory_list.add_child(row)

func set_selected_object_preview(title: String, detail: String, actions: Array) -> void:
	status_title.text = "Selected Object"
	selected_label.text = title
	needs_label.visible = false
	priority_label.visible = false
	current_job_label.visible = false
	carry_capacity_label.visible = false
	equipment_label.visible = false
	equipment_slots.visible = false
	work_toggle_title.visible = false
	work_toggle_grid.visible = false
	stockpile_inventory_title.visible = false
	stockpile_inventory_scroll.visible = false
	selected_object_detail.visible = true
	selected_object_actions.visible = true
	selected_object_detail.text = detail
	var actions_sig: String = _selected_object_actions_signature(actions)
	if _last_selected_object_title == title and _last_selected_object_detail == detail and _last_selected_object_actions_sig == actions_sig:
		return
	_last_selected_object_title = title
	_last_selected_object_detail = detail
	_last_selected_object_actions_sig = actions_sig
	_rebuild_selected_object_actions(actions)

func _selected_object_actions_signature(actions: Array) -> String:
	var parts: Array[String] = []
	for entry_any in actions:
		if not (entry_any is Dictionary):
			parts.append("non-dict")
			continue
		var entry: Dictionary = entry_any
		var line: String = "type=%s|id=%s|label=%s|selected=%s|apply=%s" % [
			String(entry.get("type", &"button")),
			String(entry.get("id", &"")),
			String(entry.get("label", "")),
			String(entry.get("selected_id", &"")),
			String(entry.get("apply_action", &""))
		]
		var opts: Array = entry.get("options", [])
		for opt_any in opts:
			if not (opt_any is Dictionary):
				continue
			var opt: Dictionary = opt_any
			line += "|opt:%s:%s" % [String(opt.get("id", &"")), String(opt.get("label", ""))]
		parts.append(line)
	return "||".join(parts)

func _rebuild_selected_object_actions(actions: Array) -> void:
	for child in selected_object_actions.get_children():
		child.queue_free()
	_selected_object_buttons.clear()
	if actions.is_empty():
		selected_object_actions.visible = false
		return
	selected_object_actions.visible = true
	for entry in actions:
		if not (entry is Dictionary):
			continue
		var entry_type: StringName = StringName(entry.get("type", &"button"))
		if entry_type == &"crop_selector":
			var selector_row := HBoxContainer.new()
			selector_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var option := OptionButton.new()
			option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var options: Array = entry.get("options", [])
			for i in range(options.size()):
				var opt: Dictionary = options[i]
				var opt_id: StringName = StringName(opt.get("id", &""))
				var opt_label: String = String(opt.get("label", String(opt_id)))
				if opt_id == &"":
					continue
				option.add_item(opt_label)
				option.set_item_metadata(option.item_count - 1, opt_id)
			var selected_id: StringName = StringName(entry.get("selected_id", &""))
			for i in range(option.item_count):
				if StringName(option.get_item_metadata(i)) == selected_id:
					option.select(i)
					break
			if option.item_count > 0 and option.selected < 0:
				option.select(0)
			var apply_text: String = String(entry.get("apply_label", "적용"))
			var apply_action: StringName = StringName(entry.get("apply_action", &""))
			var apply_button := Button.new()
			apply_button.text = apply_text
			apply_button.disabled = apply_action == &"" or option.item_count <= 0
			apply_button.pressed.connect(func():
				if apply_action == &"" or option.item_count <= 0:
					return
				var picked_idx: int = option.selected
				if picked_idx < 0:
					picked_idx = 0
				var picked: StringName = StringName(option.get_item_metadata(picked_idx))
				selected_object_action_requested.emit(StringName("%s:%s" % [String(apply_action), String(picked)]))
			)
			selector_row.add_child(option)
			selector_row.add_child(apply_button)
			selected_object_actions.add_child(selector_row)
			continue
		var action_id: StringName = StringName(entry.get("id", &""))
		if action_id == &"":
			continue
		var label_text: String = String(entry.get("label", String(action_id)))
		var button := Button.new()
		button.text = label_text
		button.pressed.connect(func(): selected_object_action_requested.emit(action_id))
		selected_object_actions.add_child(button)
		_selected_object_buttons.append(button)

func set_priority_preview(colonist: Node) -> void:
	if colonist == null:
		priority_label.text = "Global Priority: -"
		current_job_label.text = "Current Job: -"
		return
	priority_label.text = "Priority Cb:%d B:%d C:%d G:%d Hu:%d Ha:%d" % [
		colonist.priorities.combat,
		colonist.priorities.build,
		colonist.priorities.craft,
		colonist.priorities.gather,
		colonist.priorities.hunt,
		colonist.priorities.haul
	]
	set_current_job_preview(colonist)
	_priority_signal_mute = true
	haul_slider.value = colonist.priorities.haul
	build_slider.value = colonist.priorities.build
	craft_slider.value = colonist.priorities.craft
	combat_slider.value = colonist.priorities.combat
	gather_slider.value = colonist.priorities.gather
	hunt_slider.value = colonist.priorities.hunt
	_priority_signal_mute = false

func set_current_job_preview(colonist: Node) -> void:
	if colonist == null:
		current_job_label.text = "Current Job: -"
		return
	if not colonist.current_job.is_empty():
		var job_type: StringName = colonist.current_job.get("type", &"Idle")
		current_job_label.text = "Current Job: %s" % String(job_type)
		return
	current_job_label.text = "Current Job: Idle"

func set_carry_capacity_preview(colonist: Node) -> void:
	if colonist == null or colonist.stats == null:
		carry_capacity_label.text = "Carry: -"
		return
	carry_capacity_label.text = "Carry: %d" % int(colonist.stats.haul_carry_capacity)

func set_building_catalog(building_defs: Array) -> void:
	var sig_parts: Array[String] = []
	for def_sig in building_defs:
		if def_sig == null:
			continue
		sig_parts.append("%s|%s" % [String(def_sig.id), _compact_cost_text(def_sig.build_cost)])
	sig_parts.sort()
	var catalog_sig: String = "||".join(sig_parts)
	if catalog_sig == _last_building_catalog_sig:
		_refresh_building_selection()
		return
	_last_building_catalog_sig = catalog_sig
	var seen_ids: Dictionary = {}
	for def in building_defs:
		if def == null:
			continue
		var building_id: StringName = def.id
		seen_ids[building_id] = true
		var button: Button = _building_button_map.get(building_id, null)
		if button == null:
			button = Button.new()
			button.custom_minimum_size = Vector2(180, 64)
			button.pressed.connect(_on_building_button_pressed.bind(building_id))
			building_list.add_child(button)
			_building_button_map[building_id] = button
		button.text = _format_building_button_text(def)
		button.tooltip_text = _format_building_tooltip(def)
	var stale_ids: Array = _building_button_map.keys()
	for id_any in stale_ids:
		var stale_id: StringName = StringName(id_any)
		if seen_ids.has(stale_id):
			continue
		var stale_button: Button = _building_button_map[stale_id]
		if stale_button != null and is_instance_valid(stale_button):
			stale_button.queue_free()
		_building_button_map.erase(stale_id)
	_refresh_building_selection()

func set_selected_building(building_id: StringName) -> void:
	_selected_building_id = building_id
	_refresh_building_selection()

func _on_building_button_pressed(building_id: StringName) -> void:
	set_selected_building(building_id)
	building_selected.emit(building_id)

func _refresh_building_selection() -> void:
	for id_key in _building_button_map.keys():
		var button: Button = _building_button_map[id_key]
		button.disabled = id_key == _selected_building_id

func _format_building_button_text(def: Resource) -> String:
	var cost_text: String = _compact_cost_text(def.build_cost)
	if cost_text.is_empty():
		return "%s\nNoCost" % def.display_name
	return "%s\n%s" % [def.display_name, cost_text]

func _format_building_tooltip(def: Resource) -> String:
	var cost_text: String = _compact_cost_text(def.build_cost)
	if cost_text.is_empty():
		cost_text = "No resource cost"
	return "%s (%s)\nWork: %.0f\nCost: %s" % [
		def.display_name,
		def.category,
		def.required_work,
		cost_text
	]

func _compact_cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array[String] = []
	for k in cost.keys():
		parts.append("%s:%d" % [String(k), int(cost[k])])
	return ", ".join(parts)

func set_work_toggles(toggle_map: Dictionary) -> void:
	var safe_map := {
		&"Haul": true,
		&"Build": true,
		&"Craft": true,
		&"Combat": true,
		&"Gather": true,
		&"Hunt": true
	}
	for k in safe_map.keys():
		if toggle_map.has(k):
			safe_map[k] = bool(toggle_map[k])
	haul_check.button_pressed = safe_map[&"Haul"]
	build_check.button_pressed = safe_map[&"Build"]
	craft_check.button_pressed = safe_map[&"Craft"]
	combat_check.button_pressed = safe_map[&"Combat"]
	gather_check.button_pressed = safe_map[&"Gather"]
	hunt_check.button_pressed = safe_map[&"Hunt"]

func set_selected_status_visible(visible: bool) -> void:
	selected_status_panel.visible = visible

func set_designation_panel_visible(visible: bool) -> void:
	designation_panel.visible = visible

func set_research_panel_visible(visible: bool) -> void:
	research_panel.visible = visible

func set_designation_target_preview(target_name: String, enabled: bool, kind: String) -> void:
	designation_panel.visible = true
	var state_text: String = "ON" if enabled else "OFF"
	designation_desc.text = "%s (%s)\n현재 지정: %s" % [target_name, kind, state_text]
	designation_toggle_button.text = "지정 해제" if enabled else "지정 활성화"

func set_bed_assignment_visible(visible: bool) -> void:
	bed_assign_panel.visible = visible

func set_bed_assignment_options(colonist_options: Array, selected_colonist_id: int) -> void:
	_bed_signal_mute = true
	bed_assign_option.clear()
	for opt in colonist_options:
		if not (opt is Dictionary):
			continue
		var label: String = String(opt.get("name", "Unknown"))
		var cid: int = int(opt.get("id", 0))
		var idx: int = bed_assign_option.item_count
		bed_assign_option.add_item(label)
		bed_assign_option.set_item_metadata(idx, cid)
		if cid == selected_colonist_id:
			bed_assign_option.select(idx)
	if bed_assign_option.item_count > 0 and bed_assign_option.get_selected() < 0:
		bed_assign_option.select(0)
	_bed_signal_mute = false

func set_craft_panel_visible(visible: bool, workstation_name: String = "") -> void:
	separator_c.visible = visible
	craft_queue_title.visible = visible
	workstation_row.visible = visible
	craft_controls.visible = visible
	craft_queue_buttons.visible = visible
	craft_queue_scroll.visible = visible
	if not visible:
		craft_queue_title.text = "Queue"
		_last_craft_queue_items.clear()
		_rebuild_queue_items([])
		return
	if workstation_name.is_empty():
		craft_queue_title.text = "Queue"
	else:
		craft_queue_title.text = "Queue (%s)" % workstation_name

func set_recipe_catalog(recipes: Array) -> void:
	recipe_option.clear()
	_recipe_id_by_index.clear()
	_recipe_name_lookup.clear()
	for recipe in recipes:
		if recipe == null:
			continue
		var idx: int = recipe_option.item_count
		recipe_option.add_item(recipe.display_name)
		recipe_option.set_item_tooltip(idx, _format_recipe_tooltip(recipe))
		_recipe_id_by_index.append(recipe.id)
		_recipe_name_lookup[recipe.id] = recipe.display_name
	if recipe_option.item_count > 0:
		recipe_option.select(0)

func set_craft_queue_preview(order_list: Array) -> void:
	var items: Array[String] = []
	for order in order_list:
		if order is Dictionary:
			var recipe_id: StringName = order.get("recipe_id", &"")
			var recipe_name: String = String(_recipe_name_lookup.get(recipe_id, ""))
			if recipe_name.is_empty():
				recipe_name = _humanize_recipe_id(recipe_id)
			items.append(recipe_name)
		else:
			items.append(String(order))
	if items == _last_craft_queue_items:
		return
	_last_craft_queue_items = items.duplicate()
	_rebuild_queue_items(items)

func _rebuild_queue_items(items: Array[String]) -> void:
	for child in craft_queue_list.get_children():
		child.queue_free()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Queue: -"
		craft_queue_list.add_child(empty_label)
		return
	for i in range(items.size()):
		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Label.new()
		row.text = "%d. %s" % [i + 1, items[i]]
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove_button := Button.new()
		remove_button.text = "X"
		remove_button.custom_minimum_size = Vector2(26, 0)
		remove_button.pressed.connect(_on_queue_item_remove_pressed.bind(i))
		row_box.add_child(row)
		row_box.add_child(remove_button)
		craft_queue_list.add_child(row_box)

func _on_queue_craft_button_pressed() -> void:
	var idx: int = recipe_option.get_selected()
	if idx < 0 and recipe_option.item_count > 0:
		recipe_option.select(0)
		idx = 0
	if idx < 0 or idx >= _recipe_id_by_index.size():
		return
	var ws_index: int = workstation_option.get_selected()
	if ws_index >= 0 and ws_index < _workstation_ids_by_index.size():
		_selected_workstation_id = _workstation_ids_by_index[ws_index]
	elif _selected_workstation_id == &"" and not _workstation_ids_by_index.is_empty():
		_selected_workstation_id = _workstation_ids_by_index[0]
	if _selected_workstation_id == &"":
		return
	craft_recipe_queued.emit(_recipe_id_by_index[idx], _selected_workstation_id)

func _on_queue_craft_front_button_pressed() -> void:
	var idx: int = recipe_option.get_selected()
	if idx < 0 and recipe_option.item_count > 0:
		recipe_option.select(0)
		idx = 0
	if idx < 0 or idx >= _recipe_id_by_index.size():
		return
	var ws_index: int = workstation_option.get_selected()
	if ws_index >= 0 and ws_index < _workstation_ids_by_index.size():
		_selected_workstation_id = _workstation_ids_by_index[ws_index]
	elif _selected_workstation_id == &"" and not _workstation_ids_by_index.is_empty():
		_selected_workstation_id = _workstation_ids_by_index[0]
	if _selected_workstation_id == &"":
		return
	craft_recipe_front_queued.emit(_recipe_id_by_index[idx], _selected_workstation_id)

func _on_queue_item_remove_pressed(index: int) -> void:
	var ws_id: StringName = _selected_workstation_id
	var ws_index: int = workstation_option.get_selected()
	if ws_index >= 0 and ws_index < _workstation_ids_by_index.size():
		ws_id = _workstation_ids_by_index[ws_index]
	if ws_id == &"":
		return
	craft_queue_remove_requested.emit(ws_id, index)

func _humanize_recipe_id(recipe_id: StringName) -> String:
	var raw: String = String(recipe_id)
	if raw.is_empty():
		return "-"
	var out: String = ""
	for i in range(raw.length()):
		var ch: String = raw.substr(i, 1)
		var upper: bool = ch == ch.to_upper() and ch != ch.to_lower()
		if i > 0 and upper:
			out += " "
		out += ch
	return out.strip_edges()

func _format_recipe_tooltip(recipe: Resource) -> String:
	return "%s\nInput: %s\nOutput: %s" % [
		recipe.display_name,
		_compact_cost_text(recipe.ingredients),
		_compact_cost_text(recipe.products)
	]

func set_workstation_catalog(workstations: Array) -> void:
	workstation_option.clear()
	_workstation_ids_by_index.clear()
	for ws in workstations:
		if ws == null:
			continue
		var idx: int = workstation_option.item_count
		workstation_option.add_item(ws.display_name)
		workstation_option.set_item_tooltip(idx, "%s -> %s" % [String(ws.id), String(ws.linked_building_id)])
		_workstation_ids_by_index.append(ws.id)
	if workstation_option.item_count > 0:
		workstation_option.select(0)
		_selected_workstation_id = _workstation_ids_by_index[0]
		workstation_changed.emit(_selected_workstation_id)

func set_selected_workstation(workstation_id: StringName) -> void:
	_selected_workstation_id = workstation_id
	for i in range(_workstation_ids_by_index.size()):
		if _workstation_ids_by_index[i] == workstation_id:
			workstation_option.select(i)
			return

func set_research_catalog(
	research_defs: Array,
	selected_id: StringName = &"",
	lock_map: Dictionary = {},
	prereq_map: Dictionary = {},
	tree_rows: Array[Dictionary] = []
) -> void:
	research_option.clear()
	_research_ids_by_index.clear()
	_research_lock_map = lock_map.duplicate(true)
	_research_prereq_map = prereq_map.duplicate(true)
	for def in research_defs:
		if def == null:
			continue
		var idx: int = research_option.item_count
		research_option.add_item(def.display_name)
		var rid: StringName = def.id
		var req: StringName = StringName(_research_prereq_map.get(rid, &""))
		var unlocked: bool = bool(_research_lock_map.get(rid, true))
		var state_text: String = "가능" if unlocked else "잠김"
		var tip: String = "%s\n필요 포인트: %.0f\n상태: %s" % [String(def.id), float(def.required_points), state_text]
		if req != &"":
			tip += "\n선행 연구: %s" % String(req)
		research_option.set_item_tooltip(idx, tip)
		research_option.set_item_disabled(idx, not unlocked)
		_research_ids_by_index.append(def.id)
	var target_id: StringName = selected_id
	if target_id == &"" and not _research_ids_by_index.is_empty():
		for rid in _research_ids_by_index:
			if bool(_research_lock_map.get(rid, true)):
				target_id = rid
				break
		if target_id == &"":
			target_id = _research_ids_by_index[0]
	for i in range(_research_ids_by_index.size()):
		if _research_ids_by_index[i] == target_id:
			research_option.select(i)
			break
	if target_id != &"":
		research_project_changed.emit(target_id)
	if _research_tree_label != null:
		_research_tree_label.text = _build_research_tree_bbcode(tree_rows)

func set_research_state(active_id: StringName, points: float, required_points: float, completed_map: Dictionary = {}) -> void:
	if active_id == &"":
		research_progress_label.text = "연구: 없음"
	else:
		var done_text: String = "완료" if bool(completed_map.get(active_id, false)) else "진행중"
		research_progress_label.text = "연구 %s [%s] %.0f / %.0f" % [String(active_id), done_text, points, required_points]
	var selected_idx: int = research_option.get_selected()
	var selected_id: StringName = &""
	if selected_idx >= 0 and selected_idx < _research_ids_by_index.size():
		selected_id = _research_ids_by_index[selected_idx]
	var selected_unlocked: bool = bool(_research_lock_map.get(selected_id, true))
	research_start_button.disabled = selected_id == &"" or bool(completed_map.get(selected_id, false)) or not selected_unlocked

func _on_research_selected(index: int) -> void:
	if index < 0 or index >= _research_ids_by_index.size():
		return
	var rid: StringName = _research_ids_by_index[index]
	if not bool(_research_lock_map.get(rid, true)):
		return
	research_project_changed.emit(rid)

func _build_research_tree_bbcode(tree_rows: Array[Dictionary]) -> String:
	if tree_rows.is_empty():
		return "[b]연구 트리[/b]\n없음"
	var lines: Array[String] = ["[b]연구 트리[/b]"]
	for row_any in tree_rows:
		if not (row_any is Dictionary):
			continue
		var row: Dictionary = row_any
		var depth: int = int(row.get("depth", 0))
		var rid: StringName = StringName(row.get("id", &""))
		var name: String = String(row.get("name", rid))
		var state: StringName = StringName(row.get("state", &"locked"))
		var prereq: StringName = StringName(row.get("prereq", &""))
		var indent: String = ""
		for _i in range(depth):
			indent += "  "
		var symbol: String = "○"
		var color: String = "#9ca3af"
		match state:
			&"done":
				symbol = "●"
				color = "#34d399"
			&"active":
				symbol = "◆"
				color = "#fbbf24"
			&"ready":
				symbol = "◉"
				color = "#60a5fa"
			_:
				symbol = "○"
				color = "#9ca3af"
		var tail: String = ""
		if state == &"locked" and prereq != &"":
			tail = "  [color=#fca5a5](선행: %s)[/color]" % String(prereq)
		lines.append("%s[color=%s]%s[/color] [b]%s[/b]%s" % [indent, color, symbol, name, tail])
	return "\n".join(lines)

func set_stockpile_filter_state(selected: bool, mode: int, item_map: Dictionary, priority: int = 0, limit_map: Dictionary = {}) -> void:
	_stock_signal_mute = true
	separator_d.visible = selected
	stockpile_filter_title.visible = selected
	stockpile_filter_mode_option.visible = selected
	stock_priority_row.visible = selected
	stockpile_filter_grid.visible = selected
	stock_limit_row.visible = selected
	if _stock_preset_row != null:
		_stock_preset_row.visible = selected
	stockpile_filter_mode_option.disabled = not selected
	stockpile_filter_mode_option.select(clampi(mode, 0, 2))
	stock_priority_spin.editable = selected
	stock_priority_spin.value = priority
	for resource_key in _stock_filter_checks.keys():
		var check: CheckBox = _stock_filter_checks[resource_key]
		check.disabled = not selected
		check.button_pressed = bool(item_map.get(resource_key, false))
	stock_limit_resource_option.disabled = not selected
	stock_limit_spin.editable = selected
	stock_apply_limit_button.disabled = not selected
	_stock_limit_lookup = limit_map.duplicate(true)
	_refresh_limit_spin_by_selected_resource()
	_stock_signal_mute = false

func _on_workstation_selected(index: int) -> void:
	if index < 0 or index >= _workstation_ids_by_index.size():
		return
	_selected_workstation_id = _workstation_ids_by_index[index]
	workstation_changed.emit(_selected_workstation_id)

func _setup_stockpile_filter_widgets() -> void:
	stockpile_filter_mode_option.clear()
	stockpile_filter_mode_option.add_item("All")
	stockpile_filter_mode_option.add_item("AllowOnly")
	stockpile_filter_mode_option.add_item("DenyList")
	stockpile_filter_mode_option.item_selected.connect(_on_stockpile_filter_mode_selected)
	stock_priority_spin.value_changed.connect(_on_stockpile_priority_spin_changed)
	_stock_filter_checks = {
		&"Wood": stock_wood_check,
		&"Stone": stock_stone_check,
		&"Steel": stock_steel_check,
		&"FoodRaw": stock_food_raw_check,
		&"Meal": stock_meal_check
	}
	for resource_key in _stock_filter_checks.keys():
		var check: CheckBox = _stock_filter_checks[resource_key]
		check.toggled.connect(_on_stock_filter_check_toggled.bind(resource_key))
		stock_limit_resource_option.add_item(String(resource_key))
	stock_limit_resource_option.item_selected.connect(_on_stock_limit_resource_selected)
	stock_apply_limit_button.pressed.connect(_on_stock_apply_limit_pressed)

func _on_stockpile_filter_mode_selected(index: int) -> void:
	if _stock_signal_mute:
		return
	stockpile_filter_mode_changed.emit(index)

func _on_bed_assign_selected(index: int) -> void:
	if _bed_signal_mute:
		return
	if index < 0:
		return
	var cid: int = int(bed_assign_option.get_item_metadata(index))
	bed_assignee_changed.emit(cid)

func _on_stock_filter_check_toggled(enabled: bool, resource_key: StringName) -> void:
	if _stock_signal_mute:
		return
	stockpile_filter_item_changed.emit(resource_key, enabled)

func _on_stockpile_priority_spin_changed(value: float) -> void:
	if _stock_signal_mute:
		return
	stockpile_priority_changed.emit(int(value))

func _on_stock_limit_resource_selected(_index: int) -> void:
	_refresh_limit_spin_by_selected_resource()

func _on_stock_apply_limit_pressed() -> void:
	if _stock_signal_mute:
		return
	var idx: int = stock_limit_resource_option.get_selected_id()
	if idx < 0:
		return
	var key: StringName = StringName(stock_limit_resource_option.get_item_text(idx))
	var limit: int = int(stock_limit_spin.value)
	stockpile_limit_changed.emit(key, limit)
	_stock_limit_lookup[key] = limit

func _refresh_limit_spin_by_selected_resource() -> void:
	var idx: int = stock_limit_resource_option.get_selected_id()
	if idx < 0:
		return
	var key: StringName = StringName(stock_limit_resource_option.get_item_text(idx))
	stock_limit_spin.value = int(_stock_limit_lookup.get(key, -1))

func set_craft_queue_paused_state(paused: bool) -> void:
	_craft_queue_paused = paused
	_refresh_craft_pause_button()

func _refresh_craft_pause_button() -> void:
	if _craft_pause_button == null:
		return
	_craft_pause_button.text = "재개" if _craft_queue_paused else "일시정지"

func set_stockpile_presets(preset_options: Array, selected_id: StringName = &"") -> void:
	if _stock_preset_row == null:
		_stock_preset_row = HBoxContainer.new()
		_stock_preset_row.name = "StockPresetRow"
		_stock_preset_option = OptionButton.new()
		_stock_preset_option.custom_minimum_size = Vector2(120, 0)
		_stock_preset_apply_button = Button.new()
		_stock_preset_apply_button.text = "Preset 적용"
		_stock_preset_apply_button.custom_minimum_size = Vector2(98, 0)
		_stock_preset_apply_button.pressed.connect(func():
			if _stock_preset_option == null or _stock_preset_option.item_count <= 0:
				return
			var idx: int = _stock_preset_option.get_selected()
			if idx < 0:
				idx = 0
			var preset_id: StringName = StringName(_stock_preset_option.get_item_metadata(idx))
			stockpile_preset_apply_requested.emit(preset_id)
		)
		_stock_preset_row.add_child(_stock_preset_option)
		_stock_preset_row.add_child(_stock_preset_apply_button)
		left_vbox.add_child(_stock_preset_row)
	_stock_preset_option.clear()
	for opt_any in preset_options:
		if not (opt_any is Dictionary):
			continue
		var opt: Dictionary = opt_any
		var id: StringName = StringName(opt.get("id", &""))
		if id == &"":
			continue
		var label_text: String = String(opt.get("label", String(id)))
		_stock_preset_option.add_item(label_text)
		_stock_preset_option.set_item_metadata(_stock_preset_option.item_count - 1, id)
	if _stock_preset_option.item_count > 0:
		var selected_idx: int = 0
		for i in range(_stock_preset_option.item_count):
			if StringName(_stock_preset_option.get_item_metadata(i)) == selected_id:
				selected_idx = i
				break
		_stock_preset_option.select(selected_idx)
