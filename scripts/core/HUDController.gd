extends CanvasLayer
class_name HUDController

const CATALOG_NONE: StringName = &"None"
const CATALOG_BUILD: StringName = &"Build"
const CATALOG_RESEARCH: StringName = &"Research"
const CATALOG_FARM: StringName = &"Farm"
const CATALOG_CRAFT: StringName = &"Craft"
const GAME_TEXT: Script = preload("res://scripts/core/GameText.gd")

@onready var resources_label: Label = $TopResourceBar
@onready var time_flow_label: Label = $TimeFlowLabel
@onready var raid_status_label: Label = $RaidStatusLabel
@onready var raid_test_button: Button = $RaidTestButton
@onready var context_action_button: Button = $ContextActionButton

@onready var roster_panel: HUDRosterPanel = $LeftRosterPanel
@onready var selected_status_panel: PanelContainer = $SelectedStatusPanel
@onready var status_title: Label = $SelectedStatusPanel/VBox/StatusTitle
@onready var selected_label: Label = $SelectedStatusPanel/VBox/SelectedLabel
@onready var needs_label: Label = $SelectedStatusPanel/VBox/NeedsLabel
@onready var priority_label: Label = $SelectedStatusPanel/VBox/PriorityLabel
@onready var current_job_label: Label = $SelectedStatusPanel/VBox/CurrentJobLabel
@onready var carry_capacity_label: Label = $SelectedStatusPanel/VBox/CarryCapacityLabel
@onready var equipment_label: Label = $SelectedStatusPanel/VBox/EquipmentLabel
@onready var equipment_slots: HBoxContainer = $SelectedStatusPanel/VBox/EquipmentSlots
@onready var top_slot_label: Label = $SelectedStatusPanel/VBox/EquipmentSlots/TopSlot/TopSlotLabel
@onready var top_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/TopSlot/TopSlotIcon
@onready var bottom_slot_label: Label = $SelectedStatusPanel/VBox/EquipmentSlots/BottomSlot/BottomSlotLabel
@onready var bottom_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/BottomSlot/BottomSlotIcon
@onready var hat_slot_label: Label = $SelectedStatusPanel/VBox/EquipmentSlots/HatSlot/HatSlotLabel
@onready var hat_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/HatSlot/HatSlotIcon
@onready var weapon_slot_label: Label = $SelectedStatusPanel/VBox/EquipmentSlots/WeaponSlot/WeaponSlotLabel
@onready var weapon_slot_icon: ColorRect = $SelectedStatusPanel/VBox/EquipmentSlots/WeaponSlot/WeaponSlotIcon
@onready var stockpile_inventory_title: Label = $SelectedStatusPanel/VBox/StockpileInventoryTitle
@onready var stockpile_inventory_scroll: ScrollContainer = $SelectedStatusPanel/VBox/StockpileInventoryScroll
@onready var stockpile_inventory_list: VBoxContainer = $SelectedStatusPanel/VBox/StockpileInventoryScroll/StockpileInventoryList
@onready var selected_object_detail: Label = $SelectedStatusPanel/VBox/SelectedObjectDetail
@onready var selected_object_actions: HBoxContainer = $SelectedStatusPanel/VBox/SelectedObjectActions
@onready var work_toggle_title: Label = $SelectedStatusPanel/VBox/WorkToggleTitle
@onready var work_toggle_grid: GridContainer = $SelectedStatusPanel/VBox/WorkToggleGrid
@onready var haul_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/HaulCheck
@onready var build_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/BuildCheck
@onready var craft_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/CraftCheck
@onready var combat_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/CombatCheck
@onready var gather_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/GatherCheck
@onready var hunt_check: CheckBox = $SelectedStatusPanel/VBox/WorkToggleGrid/HuntCheck
@onready var designation_panel: PanelContainer = $SelectedStatusPanel/VBox/DesignationPanel
@onready var designation_desc: Label = $SelectedStatusPanel/VBox/DesignationPanel/VBox/DesignationDesc
@onready var designation_toggle_button: Button = $SelectedStatusPanel/VBox/DesignationPanel/VBox/DesignationToggleButton
@onready var bed_assign_panel: PanelContainer = $SelectedStatusPanel/VBox/BedAssignPanel
@onready var bed_assign_option: OptionButton = $SelectedStatusPanel/VBox/BedAssignPanel/VBox/BedAssignOption
@onready var bed_assign_auto_button: Button = $SelectedStatusPanel/VBox/BedAssignPanel/VBox/BedAssignAutoButton
@onready var stockpile_filter_title: Label = $SelectedStatusPanel/VBox/StockpileFilterTitle
@onready var stockpile_filter_mode_option: OptionButton = $SelectedStatusPanel/VBox/StockpileFilterMode
@onready var stock_priority_row: HBoxContainer = $SelectedStatusPanel/VBox/StockPriorityRow
@onready var stock_priority_text: Label = $SelectedStatusPanel/VBox/StockPriorityRow/StockPriorityText
@onready var stock_priority_spin: SpinBox = $SelectedStatusPanel/VBox/StockPriorityRow/StockPrioritySpin
@onready var stockpile_filter_grid: GridContainer = $SelectedStatusPanel/VBox/StockpileFilterGrid
@onready var stock_wood_check: CheckBox = $SelectedStatusPanel/VBox/StockpileFilterGrid/StockWoodCheck
@onready var stock_stone_check: CheckBox = $SelectedStatusPanel/VBox/StockpileFilterGrid/StockStoneCheck
@onready var stock_steel_check: CheckBox = $SelectedStatusPanel/VBox/StockpileFilterGrid/StockSteelCheck
@onready var stock_food_raw_check: CheckBox = $SelectedStatusPanel/VBox/StockpileFilterGrid/StockFoodRawCheck
@onready var stock_meal_check: CheckBox = $SelectedStatusPanel/VBox/StockpileFilterGrid/StockMealCheck
@onready var stock_limit_row: HBoxContainer = $SelectedStatusPanel/VBox/StockLimitRow
@onready var stock_limit_resource_option: OptionButton = $SelectedStatusPanel/VBox/StockLimitRow/StockLimitResourceOption
@onready var stock_limit_spin: SpinBox = $SelectedStatusPanel/VBox/StockLimitRow/StockLimitSpin
@onready var stock_apply_limit_button: Button = $SelectedStatusPanel/VBox/StockLimitRow/StockApplyLimitButton

@onready var catalog_panel: HUDCatalogPanel = $BottomCatalogPanel
@onready var craft_panel: VBoxContainer = $BottomCatalogPanel/VBox/CraftPanel
@onready var craft_queue_title: Label = $BottomCatalogPanel/VBox/CraftPanel/CraftQueueTitle
@onready var workstation_text: Label = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/WorkstationRow/WorkstationText
@onready var workstation_option: OptionButton = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/WorkstationRow/WorkstationOption
@onready var recipe_option: OptionButton = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/CraftControls/RecipeOption
@onready var queue_craft_button: Button = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/CraftControls/QueueCraftButton
@onready var queue_front_button: Button = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/CraftControls/QueueFrontButton
@onready var craft_queue_buttons: HBoxContainer = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/CraftQueueButtons
@onready var clear_queue_button: Button = $BottomCatalogPanel/VBox/CraftPanel/CraftTopRow/CraftQueueButtons/ClearQueueButton
@onready var craft_queue_list: VBoxContainer = $BottomCatalogPanel/VBox/CraftPanel/CraftQueueScroll/CraftQueueList

@onready var drag_stockpile_button: Button = $BottomActionPanel/CommandGrid/DragStockpileButton
@onready var drag_gather_button: Button = $BottomActionPanel/CommandGrid/DragGatherButton
@onready var drag_farm_button: Button = $BottomActionPanel/CommandGrid/DragFarmButton
@onready var build_catalog_button: Button = $BottomActionPanel/CommandGrid/BuildCatalogButton
@onready var outfit_toggle_button: Button = $BottomActionPanel/CommandGrid/OutfitToggleButton
@onready var rally_flag_button: Button = $BottomActionPanel/CommandGrid/RallyFlagButton

signal priority_changed(job_type: StringName, value: int)
signal action_changed(action: StringName)
signal building_selected(building_id: StringName)
signal work_toggle_changed(work_type: StringName, enabled: bool)
signal craft_recipe_queued(recipe_id: StringName, workstation_id: StringName)
signal craft_recipe_repeat_queued(recipe_id: StringName, workstation_id: StringName)
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
signal stockpile_delete_requested()
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
signal portrait_selected(colonist_id: int)
signal action_button_pressed(action_id: StringName)
signal catalog_item_activated(mode: StringName, item_id: StringName)

var _active_action: StringName = &"Interact"
var _selected_building_id: StringName = &""
var _building_defs_cache: Array = []
var _catalog_mode: StringName = CATALOG_NONE
var _catalog_visible: bool = false
var _catalog_description: String = ""

var _recipe_id_by_index: Array[StringName] = []
var _workstation_ids_by_index: Array[StringName] = []
var _selected_workstation_id: StringName = &""
var _recipe_name_lookup: Dictionary = {}
var _last_craft_queue_items: Array[String] = []
var _craft_queue_paused: bool = false
var _craft_pause_button: Button = null
var _queue_repeat_button: Button = null

var _stock_filter_checks: Dictionary = {}
var _stock_signal_mute: bool = false
var _stock_limit_lookup: Dictionary = {}
var _stock_preset_row: HBoxContainer = null
var _stock_preset_option: OptionButton = null
var _stock_preset_apply_button: Button = null
var _stock_delete_button: Button = null
var _bed_signal_mute: bool = false
var _selected_object_buttons: Array[Button] = []

var _research_entries: Array[Dictionary] = []
var _research_lock_map: Dictionary = {}
var _research_prereq_map: Dictionary = {}
var _research_selected_id: StringName = &""

var _farm_entries: Array[Dictionary] = []
var _farm_selected_crop_id: StringName = &""
var _craft_recipe_entries: Array[Dictionary] = []
var _research_status_text: String = ""

var _outfit_mode: StringName = &"Work"
var _context_action_id: StringName = &""
var _last_resource_stock_text: String = ""
var _defense_status_label: Label = null
var _work_toggle_signal_mute: bool = false
func _ready() -> void:
	_catalog_description = _t("hud.catalog.description.default")
	_research_status_text = _t("hud.research.status.none")
	_apply_static_texts()
	roster_panel.set_title(_t("hud.roster.title"))
	roster_panel.portrait_selected.connect(func(colonist_id: int):
		portrait_selected.emit(colonist_id)
	)
	catalog_panel.set_title(_t("hud.catalog.title"))
	catalog_panel.set_mode(CATALOG_NONE, _t("hud.catalog.mode.none"))
	catalog_panel.set_description(_catalog_description)
	catalog_panel.item_pressed.connect(_on_catalog_item_pressed)
	catalog_panel.visible = false
	craft_panel.visible = false

	drag_stockpile_button.pressed.connect(func():
		drag_stockpile_mode_requested.emit()
		action_button_pressed.emit(&"StockpileZone")
	)
	drag_gather_button.pressed.connect(func():
		drag_gather_mode_requested.emit()
		action_button_pressed.emit(&"DragGather")
	)
	drag_farm_button.pressed.connect(func():
		drag_farm_mode_requested.emit()
		action_button_pressed.emit(&"FarmZone")
	)
	build_catalog_button.pressed.connect(_on_build_catalog_button_pressed)
	outfit_toggle_button.pressed.connect(_on_outfit_toggle_button_pressed)
	rally_flag_button.pressed.connect(func():
		rally_flag_mode_requested.emit()
		action_button_pressed.emit(&"SetRallyFlag")
	)

	haul_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Haul", v))
	build_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Build", v))
	craft_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Craft", v))
	combat_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Combat", v))
	gather_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Gather", v))
	hunt_check.toggled.connect(func(v: bool): _emit_work_toggle_changed(&"Hunt", v))

	designation_toggle_button.pressed.connect(func(): designation_toggle_requested.emit())
	bed_assign_option.item_selected.connect(_on_bed_assign_selected)
	bed_assign_auto_button.pressed.connect(func(): bed_auto_assign_requested.emit())

	queue_craft_button.pressed.connect(_on_queue_craft_button_pressed)
	_queue_repeat_button = Button.new()
	_queue_repeat_button.custom_minimum_size = Vector2(112, 0)
	_queue_repeat_button.text = _t("hud.craft.queue_repeat", {}, "Repeat Add")
	_queue_repeat_button.focus_mode = Control.FOCUS_NONE
	_queue_repeat_button.pressed.connect(_on_queue_craft_repeat_button_pressed)
	var craft_controls: HBoxContainer = queue_craft_button.get_parent() as HBoxContainer
	if craft_controls != null:
		craft_controls.add_child(_queue_repeat_button)
		craft_controls.move_child(_queue_repeat_button, queue_front_button.get_index())
	queue_front_button.pressed.connect(_on_queue_craft_front_button_pressed)
	clear_queue_button.pressed.connect(func(): craft_queue_clear_requested.emit())
	workstation_option.item_selected.connect(_on_workstation_selected)

	_craft_pause_button = Button.new()
	_craft_pause_button.text = _t("hud.craft.pause")
	_craft_pause_button.custom_minimum_size = Vector2(96, 0)
	_craft_pause_button.focus_mode = Control.FOCUS_NONE
	_craft_pause_button.pressed.connect(func():
		_craft_queue_paused = not _craft_queue_paused
		_refresh_craft_pause_button()
		craft_queue_pause_toggled.emit(_selected_workstation_id, _craft_queue_paused)
	)
	craft_queue_buttons.add_child(_craft_pause_button)
	_refresh_craft_pause_button()

	_setup_stockpile_filter_widgets()
	context_action_button.pressed.connect(_on_context_action_button_pressed)
	raid_test_button.pressed.connect(func(): raid_test_warning_requested.emit())

	_defense_status_label = Label.new()
	_defense_status_label.text = _t("hud.defense.status.empty")
	_defense_status_label.position = Vector2(16.0, 106.0)
	add_child(_defense_status_label)
	_disable_focus_for_controls(self)

	set_outfit_mode(&"Work")
	set_selected_status_visible(false)
	set_stockpile_filter_state(false, 0, {}, 0, {})
	set_active_action(_active_action)

func _apply_static_texts() -> void:
	resources_label.text = _t("hud.resource.title")
	time_flow_label.text = _t("hud.time.default")
	raid_status_label.text = _t("hud.raid.idle", {"kind": ""})
	raid_test_button.text = _t("hud.raid.test_button")
	context_action_button.text = _t("hud.context.action.default")
	status_title.text = _t("hud.status.title")
	selected_label.text = _t("hud.selected.none")
	needs_label.text = _t("hud.needs.empty")
	priority_label.text = _t("hud.priority.empty")
	current_job_label.text = _t("hud.current_job.empty")
	carry_capacity_label.text = _t("hud.carry.empty")
	equipment_label.text = _t("hud.equipment.empty")
	top_slot_label.text = _t("hud.slot.top")
	bottom_slot_label.text = _t("hud.slot.bottom")
	hat_slot_label.text = _t("hud.slot.hat")
	weapon_slot_label.text = _t("hud.slot.weapon")
	stockpile_inventory_title.text = _t("hud.stockpile.title")
	selected_object_detail.text = _t("hud.common.dash")
	work_toggle_title.text = _t("hud.work_toggle.title")
	haul_check.text = _t("hud.work.haul")
	build_check.text = _t("hud.work.build")
	craft_check.text = _t("hud.work.craft")
	combat_check.text = _t("hud.work.combat")
	gather_check.text = _t("hud.work.gather")
	hunt_check.text = _t("hud.work.hunt")
	designation_desc.text = _t("hud.common.dash")
	designation_toggle_button.text = _t("hud.designation.toggle")
	bed_assign_auto_button.text = _t("hud.bed.auto_assign")
	stockpile_filter_title.text = _t("hud.stock.filter.title")
	stock_priority_text.text = _t("hud.stock.priority")
	stock_wood_check.text = _t("hud.stock.resource.wood")
	stock_stone_check.text = _t("hud.stock.resource.stone")
	stock_steel_check.text = _t("hud.stock.resource.steel")
	stock_food_raw_check.text = _t("hud.stock.resource.food_raw")
	stock_meal_check.text = _t("hud.stock.resource.meal")
	stock_apply_limit_button.text = _t("hud.stock.apply")
	if _stock_delete_button != null:
		_stock_delete_button.text = _t("hud.stock.delete")
	craft_queue_title.text = _t("hud.craft.title")
	workstation_text.text = _t("hud.craft.workstation")
	queue_craft_button.text = _t("hud.craft.queue_add")
	if _queue_repeat_button != null:
		_queue_repeat_button.text = _t("hud.craft.queue_repeat", {}, "Repeat Add")
	queue_front_button.text = _t("hud.craft.queue_front")
	clear_queue_button.text = _t("hud.craft.clear")
	drag_stockpile_button.text = _t("hud.action.drag_stockpile")
	drag_gather_button.text = _t("hud.action.drag_gather")
	drag_farm_button.text = _t("hud.action.drag_farm")
	build_catalog_button.text = _t("hud.action.build")
	outfit_toggle_button.text = _t("hud.action.outfit")
	rally_flag_button.text = _t("hud.action.rally")

func set_colonist_roster(entries: Array) -> void:
	roster_panel.set_entries(entries)

func open_bottom_catalog(mode: StringName, description: String = "") -> void:
	_set_catalog_mode(mode)
	if not description.is_empty():
		_catalog_description = description
	catalog_panel.set_description(_catalog_description)
	_set_catalog_visible(true)

func close_bottom_catalog() -> void:
	_set_catalog_visible(false)

func reset_bottom_catalog_state() -> void:
	_selected_building_id = &""
	_research_selected_id = &""
	_farm_selected_crop_id = &""
	_catalog_description = _t("hud.catalog.description.default")
	_set_catalog_mode(CATALOG_NONE)
	_set_catalog_visible(false)

func is_bottom_catalog_visible() -> bool:
	return _catalog_visible

func get_bottom_catalog_mode() -> StringName:
	return _catalog_mode

func set_bottom_catalog_description(text: String) -> void:
	_catalog_description = text
	catalog_panel.set_description(text)

func set_farm_catalog(crop_options: Array, selected_crop_id: StringName = &"", description: String = "") -> void:
	var normalized_entries: Array[Dictionary] = []
	for opt_any in crop_options:
		if not (opt_any is Dictionary):
			continue
		var opt: Dictionary = opt_any
		var crop_id: StringName = StringName(opt.get("id", &""))
		if crop_id == &"":
			continue
		var label_text: String = String(opt.get("label", String(crop_id)))
		normalized_entries.append({
			"id": crop_id,
			"label": label_text,
			"tooltip": String(opt.get("tooltip", label_text)),
			"disabled": false
		})
	var entries_changed: bool = _farm_entries != normalized_entries or _farm_selected_crop_id != selected_crop_id
	if entries_changed:
		_farm_entries.clear()
		for entry in normalized_entries:
			_farm_entries.append(entry)
		_farm_selected_crop_id = selected_crop_id
	if not description.is_empty():
		if _catalog_description != description:
			_catalog_description = description
			if _catalog_mode == CATALOG_FARM:
				catalog_panel.set_description(_catalog_description)
	if entries_changed and _catalog_mode == CATALOG_FARM:
		_refresh_catalog_items()

func set_selected_count(count: int) -> void:
	selected_label.text = _t("hud.selected.count", {"count": count})

func set_active_action(action: StringName) -> void:
	_active_action = action
	set_command_button_states(action)
	action_changed.emit(_active_action)

func set_command_button_states(mode: StringName) -> void:
	drag_gather_button.disabled = mode == &"DragGather"
	drag_stockpile_button.disabled = mode == &"StockpileZone"
	drag_farm_button.disabled = mode == &"FarmZone"
	rally_flag_button.disabled = mode == &"SetRallyFlag"
func set_resource_stock(stock: Dictionary) -> void:
	var keys := [
		&"Wood", &"Stone", &"Steel", &"FoodRaw", &"Meal", &"Bed",
		&"Handcart", &"GatherTop", &"GatherBottom", &"StrawHat",
		&"CombatTop", &"CombatBottom", &"CombatHat", &"Sword", &"Bow"
	]
	var chunks: Array[String] = []
	for key in keys:
		chunks.append("%s:%d" % [String(key), int(stock.get(key, 0))])
	var next_text: String = _t("hud.resource.stock", {"chunks": ", ".join(chunks)})
	if next_text == _last_resource_stock_text:
		return
	_last_resource_stock_text = next_text
	resources_label.text = next_text

func set_outfit_mode(mode: StringName) -> void:
	_outfit_mode = &"Combat" if mode == &"Combat" else &"Work"
	outfit_toggle_button.text = _t("hud.outfit.combat") if _outfit_mode == &"Combat" else _t("hud.outfit.work")

func set_raid_state(state: StringName, warning_seconds: float = 0.0, wave_kind: StringName = &"") -> void:
	var kind_text: String = ""
	match wave_kind:
		&"ZombieHorde":
			kind_text = _t("hud.raid.kind.zombie")
		&"Mixed":
			kind_text = _t("hud.raid.kind.mixed")
		&"RaiderOnly":
			kind_text = _t("hud.raid.kind.raider")
		_:
			kind_text = ""
	match state:
		&"Warning":
			raid_status_label.text = _t("hud.raid.warning", {"kind": kind_text, "seconds": "%.0f" % ceil(warning_seconds)})
			raid_status_label.modulate = Color(1.0, 0.78, 0.32, 1.0)
		&"Active":
			raid_status_label.text = _t("hud.raid.active", {"kind": kind_text})
			raid_status_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
		&"Resolved":
			raid_status_label.text = _t("hud.raid.resolved", {"kind": kind_text})
			raid_status_label.modulate = Color(0.68, 0.96, 0.68, 1.0)
		_:
			raid_status_label.text = _t("hud.raid.idle", {"kind": kind_text})
			raid_status_label.modulate = Color(0.8, 0.86, 0.95, 1.0)

func set_defense_status(text: String) -> void:
	if _defense_status_label != null:
		_defense_status_label.text = _t("hud.defense.status", {"text": text})

func set_time_flow_state(paused: bool, speed_scale: float, elapsed_game_seconds: float) -> void:
	var elapsed_text: String = _format_elapsed_time(elapsed_game_seconds)
	if paused:
		time_flow_label.text = _t("hud.time.paused", {"elapsed": elapsed_text})
		return
	time_flow_label.text = _t("hud.time.running", {"speed": "%.1f" % speed_scale, "elapsed": elapsed_text})

func set_equipment_preview(colonist: Node) -> void:
	if colonist == null:
		equipment_label.text = _t("hud.equipment.empty")
		_set_equipment_slot_icon(top_slot_icon, false, Color(0.36, 0.63, 0.9))
		_set_equipment_slot_icon(bottom_slot_icon, false, Color(0.55, 0.74, 0.95))
		_set_equipment_slot_icon(hat_slot_icon, false, Color(0.93, 0.74, 0.4))
		_set_equipment_slot_icon(weapon_slot_icon, false, Color(0.92, 0.38, 0.38))
		return
	var slots := {&"Top": &"", &"Bottom": &"", &"Hat": &"", &"Weapon": &""}
	if colonist.has_method("get_equipment_snapshot"):
		slots = colonist.get_equipment_snapshot()
	var parts: Array[String] = []
	for key in [&"Top", &"Bottom", &"Hat", &"Weapon"]:
		var item_id: StringName = StringName(slots.get(key, &""))
		if item_id != &"":
			parts.append("%s:%s" % [String(key), String(item_id)])
	var equipment_text: String = _t("common.none") if parts.is_empty() else ", ".join(parts)
	equipment_label.text = _t("hud.equipment.summary", {"items": equipment_text})
	_set_equipment_slot_icon(top_slot_icon, StringName(slots.get(&"Top", &"")) != &"", Color(0.36, 0.63, 0.9))
	_set_equipment_slot_icon(bottom_slot_icon, StringName(slots.get(&"Bottom", &"")) != &"", Color(0.55, 0.74, 0.95))
	_set_equipment_slot_icon(hat_slot_icon, StringName(slots.get(&"Hat", &"")) != &"", Color(0.93, 0.74, 0.4))
	_set_equipment_slot_icon(weapon_slot_icon, StringName(slots.get(&"Weapon", &"")) != &"", Color(0.92, 0.38, 0.38))

func set_needs_preview(colonist: Node) -> void:
	if colonist == null:
		needs_label.text = _t("hud.needs.empty")
		return
	needs_label.text = _t("hud.needs.status", {
		"hunger": "%.0f" % colonist.hunger,
		"rest": "%.0f" % colonist.rest,
		"mood": "%.0f" % colonist.mood
	})

func set_priority_preview(colonist: Node) -> void:
	if colonist == null:
		priority_label.text = _t("hud.priority.empty")
		return
	priority_label.text = _t("hud.priority.status", {
		"combat": colonist.priorities.combat,
		"build": colonist.priorities.build,
		"craft": colonist.priorities.craft,
		"gather": colonist.priorities.gather,
		"hunt": colonist.priorities.hunt,
		"haul": colonist.priorities.haul
	})

func set_current_job_preview(colonist: Node) -> void:
	if colonist == null:
		current_job_label.text = _t("hud.current_job.empty")
		return
	if colonist.current_job.is_empty():
		current_job_label.text = _t("hud.current_job.idle")
		return
	current_job_label.text = _t("hud.current_job.status", {"job": StringName(colonist.current_job.get("type", &"Idle"))})

func set_carry_capacity_preview(colonist: Node) -> void:
	if colonist == null or colonist.stats == null:
		carry_capacity_label.text = _t("hud.carry.empty")
		return
	carry_capacity_label.text = _t("hud.carry.status", {"capacity": int(colonist.stats.haul_carry_capacity)})
func set_stockpile_inventory_preview(stockpile_zone: Node) -> void:
	var selected: bool = stockpile_zone != null and is_instance_valid(stockpile_zone)
	if selected:
		status_title.text = _t("hud.status.title")
		selected_label.text = _t("hud.selected.stockpile")
		_set_unit_info_visible(false)
		stockpile_inventory_title.visible = true
		stockpile_inventory_scroll.visible = true
		selected_object_detail.visible = false
		selected_object_actions.visible = false
		var snapshot: Dictionary = stockpile_zone.get_stored_snapshot() if stockpile_zone.has_method("get_stored_snapshot") else {}
		_rebuild_stockpile_inventory_items(snapshot)
		return
	_set_unit_info_visible(true)
	stockpile_inventory_title.visible = false
	stockpile_inventory_scroll.visible = false
	selected_object_detail.visible = false
	selected_object_actions.visible = false
	_rebuild_stockpile_inventory_items({})

func set_selected_object_preview(title: String, detail: String, actions: Array) -> void:
	status_title.text = _t("hud.status.title")
	selected_label.text = title
	_set_unit_info_visible(false)
	stockpile_inventory_title.visible = false
	stockpile_inventory_scroll.visible = false
	selected_object_detail.visible = true
	selected_object_actions.visible = true
	selected_object_detail.text = detail
	_rebuild_selected_object_actions(actions)

func set_work_toggles(toggle_map: Dictionary) -> void:
	var has_focus: bool = not toggle_map.is_empty()
	work_toggle_title.visible = has_focus
	work_toggle_grid.visible = has_focus
	var safe_map := {&"Haul": true, &"Build": true, &"Craft": true, &"Combat": true, &"Gather": true, &"Hunt": true}
	for key in safe_map.keys():
		if toggle_map.has(key):
			safe_map[key] = bool(toggle_map[key])
	_work_toggle_signal_mute = true
	haul_check.button_pressed = safe_map[&"Haul"]
	build_check.button_pressed = safe_map[&"Build"]
	craft_check.button_pressed = safe_map[&"Craft"]
	combat_check.button_pressed = safe_map[&"Combat"]
	gather_check.button_pressed = safe_map[&"Gather"]
	hunt_check.button_pressed = safe_map[&"Hunt"]
	_work_toggle_signal_mute = false

func _emit_work_toggle_changed(work_type: StringName, enabled: bool) -> void:
	if _work_toggle_signal_mute:
		return
	work_toggle_changed.emit(work_type, enabled)

func set_selected_status_visible(visible: bool) -> void:
	selected_status_panel.visible = visible

func set_designation_panel_visible(visible: bool) -> void:
	designation_panel.visible = visible

func set_research_panel_visible(_visible: bool) -> void:
	pass

func set_designation_target_preview(target_name: String, enabled: bool, kind: String) -> void:
	designation_panel.visible = true
	designation_desc.text = _t("hud.designation.preview", {
		"target": target_name,
		"kind": kind,
		"state": _t("common.on") if enabled else _t("common.off")
	})
	designation_toggle_button.text = _t("hud.designation.toggle.off") if enabled else _t("hud.designation.toggle.on")

func set_bed_assignment_visible(visible: bool) -> void:
	bed_assign_panel.visible = visible

func set_bed_assignment_options(colonist_options: Array, selected_colonist_id: int) -> void:
	_bed_signal_mute = true
	bed_assign_option.clear()
	for opt_any in colonist_options:
		if not (opt_any is Dictionary):
			continue
		var opt: Dictionary = opt_any
		var idx: int = bed_assign_option.item_count
		var cid: int = int(opt.get("id", 0))
		bed_assign_option.add_item(String(opt.get("name", _t("hud.bed.option.unknown"))))
		bed_assign_option.set_item_metadata(idx, cid)
		if cid == selected_colonist_id:
			bed_assign_option.select(idx)
	if bed_assign_option.item_count > 0 and bed_assign_option.get_selected() < 0:
		bed_assign_option.select(0)
	_bed_signal_mute = false

func set_craft_panel_visible(visible: bool, workstation_name: String = "") -> void:
	craft_panel.visible = visible
	if not visible:
		craft_queue_title.text = _t("hud.queue.title")
		if _catalog_mode == CATALOG_CRAFT and _catalog_visible:
			close_bottom_catalog()
		return
	open_bottom_catalog(CATALOG_CRAFT)
	craft_queue_title.text = _t("hud.queue.title") if workstation_name.is_empty() else _t("hud.queue.title.with_ws", {"name": workstation_name})

func set_recipe_catalog(recipes: Array) -> void:
	recipe_option.clear()
	_recipe_id_by_index.clear()
	_recipe_name_lookup.clear()
	_craft_recipe_entries.clear()
	for recipe in recipes:
		if recipe == null:
			continue
		var tip: String = _format_recipe_tooltip(recipe)
		recipe_option.add_item(recipe.display_name)
		recipe_option.set_item_tooltip(recipe_option.item_count - 1, tip)
		_recipe_id_by_index.append(recipe.id)
		_recipe_name_lookup[recipe.id] = recipe.display_name
		_craft_recipe_entries.append({"id": recipe.id, "label": String(recipe.display_name), "tooltip": tip, "disabled": false})
	if recipe_option.item_count > 0:
		recipe_option.select(0)
	if _catalog_mode == CATALOG_CRAFT:
		_refresh_catalog_items()

func set_craft_queue_preview(order_list: Array) -> void:
	var items: Array[String] = []
	for order in order_list:
		if order is Dictionary:
			var recipe_id: StringName = order.get("recipe_id", &"")
			var recipe_name: String = String(_recipe_name_lookup.get(recipe_id, ""))
			var label: String = recipe_name if not recipe_name.is_empty() else _humanize_recipe_id(recipe_id)
			if bool(order.get("repeat", false)):
				label += _t("hud.queue.repeat_suffix", {}, " (Repeat)")
			items.append(label)
		else:
			items.append(String(order))
	if items == _last_craft_queue_items:
		return
	_last_craft_queue_items = items.duplicate()
	_rebuild_queue_items(items)
func set_workstation_catalog(workstations: Array) -> void:
	workstation_option.clear()
	_workstation_ids_by_index.clear()
	for ws in workstations:
		if ws == null:
			continue
		workstation_option.add_item(ws.display_name)
		workstation_option.set_item_tooltip(workstation_option.item_count - 1, "%s -> %s" % [String(ws.id), String(ws.linked_building_id)])
		_workstation_ids_by_index.append(ws.id)
	if workstation_option.item_count > 0:
		workstation_option.select(0)
		_selected_workstation_id = _workstation_ids_by_index[0]

func set_selected_workstation(workstation_id: StringName) -> void:
	_selected_workstation_id = workstation_id
	for i in range(_workstation_ids_by_index.size()):
		if _workstation_ids_by_index[i] == workstation_id:
			workstation_option.select(i)
			return

func set_craft_queue_paused_state(paused: bool) -> void:
	_craft_queue_paused = paused
	_refresh_craft_pause_button()

func set_research_catalog(research_defs: Array, selected_id: StringName = &"", lock_map: Dictionary = {}, prereq_map: Dictionary = {}, _tree_rows: Array[Dictionary] = []) -> void:
	_research_entries.clear()
	_research_lock_map = lock_map.duplicate(true)
	_research_prereq_map = prereq_map.duplicate(true)
	_research_selected_id = selected_id
	for def in research_defs:
		if def == null:
			continue
		var rid: StringName = def.id
		var req: StringName = StringName(_research_prereq_map.get(rid, &""))
		var unlocked: bool = bool(_research_lock_map.get(rid, true))
		var tip: String = _t("hud.research.tip.required", {"id": String(def.id), "points": "%.0f" % float(def.required_points)})
		if req != &"":
			tip += _t("hud.research.tip.prereq", {"id": String(req)})
		if not unlocked:
			tip += _t("hud.research.tip.locked")
		_research_entries.append({"id": rid, "label": String(def.display_name), "tooltip": tip, "disabled": not unlocked})
	if _catalog_mode == CATALOG_RESEARCH:
		_refresh_catalog_items()

func set_research_state(active_id: StringName, points: float, required_points: float, completed_map: Dictionary = {}) -> void:
	if active_id == &"":
		_research_status_text = _t("hud.research.status.none")
		if _catalog_mode == CATALOG_RESEARCH:
			set_bottom_catalog_description(_research_status_text)
		return
	var done_text: String = _t("hud.research.state.done") if bool(completed_map.get(active_id, false)) else _t("hud.research.state.progress")
	_research_status_text = _t("hud.research.status", {
		"id": String(active_id),
		"state": done_text,
		"points": "%.0f" % points,
		"required": "%.0f" % required_points
	})
	if _catalog_mode == CATALOG_RESEARCH:
		set_bottom_catalog_description(_research_status_text)

func set_stockpile_filter_state(selected: bool, mode: int, item_map: Dictionary, priority: int = 0, limit_map: Dictionary = {}) -> void:
	_stock_signal_mute = true
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
	for key in _stock_filter_checks.keys():
		var check: CheckBox = _stock_filter_checks[key]
		check.disabled = not selected
		check.button_pressed = bool(item_map.get(key, false))
	stock_limit_resource_option.disabled = not selected
	stock_limit_spin.editable = selected
	stock_apply_limit_button.disabled = not selected
	if _stock_delete_button != null:
		_stock_delete_button.visible = selected
		_stock_delete_button.disabled = not selected
	_stock_limit_lookup = limit_map.duplicate(true)
	_refresh_limit_spin_by_selected_resource()
	_stock_signal_mute = false

func set_stockpile_presets(preset_options: Array, selected_id: StringName = &"") -> void:
	if _stock_preset_row == null:
		_stock_preset_row = HBoxContainer.new()
		_stock_preset_option = OptionButton.new()
		_stock_preset_option.custom_minimum_size = Vector2(120, 0)
		_stock_preset_option.focus_mode = Control.FOCUS_NONE
		_stock_preset_apply_button = Button.new()
		_stock_preset_apply_button.text = _t("hud.stock.preset.apply")
		_stock_preset_apply_button.custom_minimum_size = Vector2(98, 0)
		_stock_preset_apply_button.focus_mode = Control.FOCUS_NONE
		_stock_preset_apply_button.pressed.connect(func():
			if _stock_preset_option == null or _stock_preset_option.item_count <= 0:
				return
			var idx: int = maxi(0, _stock_preset_option.get_selected())
			stockpile_preset_apply_requested.emit(StringName(_stock_preset_option.get_item_metadata(idx)))
		)
		_stock_delete_button = Button.new()
		_stock_delete_button.text = _t("hud.stock.delete")
		_stock_delete_button.custom_minimum_size = Vector2(98, 0)
		_stock_delete_button.focus_mode = Control.FOCUS_NONE
		_stock_delete_button.pressed.connect(func():
			stockpile_delete_requested.emit()
		)
		_stock_preset_row.add_child(_stock_preset_option)
		_stock_preset_row.add_child(_stock_preset_apply_button)
		_stock_preset_row.add_child(_stock_delete_button)
		$SelectedStatusPanel/VBox.add_child(_stock_preset_row)
	if _stock_delete_button != null:
		_stock_delete_button.text = _t("hud.stock.delete")
	_stock_preset_option.clear()
	for opt_any in preset_options:
		if not (opt_any is Dictionary):
			continue
		var opt: Dictionary = opt_any
		var id: StringName = StringName(opt.get("id", &""))
		if id == &"":
			continue
		_stock_preset_option.add_item(String(opt.get("label", String(id))))
		_stock_preset_option.set_item_metadata(_stock_preset_option.item_count - 1, id)
	if _stock_preset_option.item_count > 0:
		var selected_idx: int = 0
		for i in range(_stock_preset_option.item_count):
			if StringName(_stock_preset_option.get_item_metadata(i)) == selected_id:
				selected_idx = i
				break
		_stock_preset_option.select(selected_idx)

func set_building_catalog(building_defs: Array) -> void:
	_building_defs_cache = building_defs.duplicate()
	if _catalog_mode == CATALOG_BUILD:
		_refresh_catalog_items()

func set_selected_building(building_id: StringName) -> void:
	_selected_building_id = building_id
	if _catalog_mode == CATALOG_BUILD:
		_refresh_catalog_items()

func get_building_button_rect(building_id: StringName) -> Rect2:
	if building_id == &"":
		return Rect2()
	if _catalog_mode != CATALOG_BUILD:
		_set_catalog_mode(CATALOG_BUILD)
	if not _catalog_visible:
		_set_catalog_visible(true)
	return catalog_panel.get_item_button_rect(building_id)
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

func _on_build_catalog_button_pressed() -> void:
	action_button_pressed.emit(&"BuildCatalogToggle")
	if _catalog_visible and _catalog_mode == CATALOG_BUILD:
		close_bottom_catalog()
		return
	_catalog_description = _t("hud.catalog.description.build")
	open_bottom_catalog(CATALOG_BUILD)

func _on_outfit_toggle_button_pressed() -> void:
	var next_mode: StringName = &"Combat" if _outfit_mode == &"Work" else &"Work"
	set_outfit_mode(next_mode)
	outfit_mode_changed.emit(next_mode)
	action_button_pressed.emit(&"OutfitToggle")

func _on_catalog_item_pressed(mode: StringName, item_id: StringName) -> void:
	if item_id == &"":
		return
	catalog_item_activated.emit(mode, item_id)
	match mode:
		CATALOG_BUILD:
			set_selected_building(item_id)
			building_selected.emit(item_id)
		CATALOG_RESEARCH:
			research_project_changed.emit(item_id)
			research_start_requested.emit()
		CATALOG_FARM:
			selected_object_action_requested.emit(StringName("SetFarmCrop:%s" % String(item_id)))
		CATALOG_CRAFT:
			_resolve_selected_workstation_from_option()
			if _selected_workstation_id != &"":
				craft_recipe_queued.emit(item_id, _selected_workstation_id)

func _set_catalog_mode(mode: StringName) -> void:
	_catalog_mode = mode
	match mode:
		CATALOG_BUILD:
			catalog_panel.set_mode(mode, _t("hud.catalog.mode.build"))
		CATALOG_RESEARCH:
			catalog_panel.set_mode(mode, _t("hud.catalog.mode.research"))
			_catalog_description = _research_status_text
		CATALOG_FARM:
			catalog_panel.set_mode(mode, _t("hud.catalog.mode.farm"))
		CATALOG_CRAFT:
			catalog_panel.set_mode(mode, _t("hud.catalog.mode.craft"))
		_:
			catalog_panel.set_mode(CATALOG_NONE, _t("hud.catalog.mode.none"))
	_refresh_catalog_items()
	craft_panel.visible = mode == CATALOG_CRAFT

func _set_catalog_visible(visible: bool) -> void:
	_catalog_visible = visible
	catalog_panel.visible = visible

func _refresh_catalog_items() -> void:
	match _catalog_mode:
		CATALOG_BUILD:
			var build_items: Array = []
			for def in _building_defs_cache:
				if def == null:
					continue
				build_items.append({"id": def.id, "label": _format_building_button_text(def), "tooltip": _format_building_tooltip(def), "disabled": false})
			catalog_panel.set_items(build_items, _selected_building_id)
		CATALOG_RESEARCH:
			catalog_panel.set_items(_research_entries, _research_selected_id)
		CATALOG_FARM:
			catalog_panel.set_items(_farm_entries, _farm_selected_crop_id)
		CATALOG_CRAFT:
			catalog_panel.set_items(_craft_recipe_entries)
		_:
			catalog_panel.set_items([])
	catalog_panel.set_description(_catalog_description)
func _rebuild_stockpile_inventory_items(stored_map: Dictionary) -> void:
	for child in stockpile_inventory_list.get_children():
		child.queue_free()
	if stored_map.is_empty():
		var empty_label := Label.new()
		empty_label.text = _t("hud.stockpile.empty")
		stockpile_inventory_list.add_child(empty_label)
		return
	var keys: Array = stored_map.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key_any in keys:
		var amount: int = int(stored_map.get(key_any, 0))
		if amount <= 0:
			continue
		var row := Label.new()
		row.text = "%s x%d" % [String(key_any), amount]
		stockpile_inventory_list.add_child(row)

func _rebuild_selected_object_actions(actions: Array) -> void:
	for child in selected_object_actions.get_children():
		child.queue_free()
	_selected_object_buttons.clear()
	if actions.is_empty():
		selected_object_actions.visible = false
		return
	selected_object_actions.visible = true
	for entry_any in actions:
		if not (entry_any is Dictionary):
			continue
		var entry: Dictionary = entry_any
		var action_id: StringName = StringName(entry.get("id", &""))
		if action_id == &"":
			continue
		var button := Button.new()
		button.text = String(entry.get("label", String(action_id)))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func(): selected_object_action_requested.emit(action_id))
		selected_object_actions.add_child(button)
		_selected_object_buttons.append(button)

func _rebuild_queue_items(items: Array[String]) -> void:
	for child in craft_queue_list.get_children():
		child.queue_free()
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = _t("hud.queue.empty")
		craft_queue_list.add_child(empty_label)
		return
	for i in range(items.size()):
		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Label.new()
		row.text = "%d. %s" % [i + 1, items[i]]
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var remove_button := Button.new()
		remove_button.text = _t("hud.queue.remove")
		remove_button.custom_minimum_size = Vector2(26, 0)
		remove_button.focus_mode = Control.FOCUS_NONE
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
	_resolve_selected_workstation_from_option()
	if _selected_workstation_id == &"":
		return
	craft_recipe_queued.emit(_recipe_id_by_index[idx], _selected_workstation_id)

func _on_queue_craft_repeat_button_pressed() -> void:
	var idx: int = recipe_option.get_selected()
	if idx < 0 and recipe_option.item_count > 0:
		recipe_option.select(0)
		idx = 0
	if idx < 0 or idx >= _recipe_id_by_index.size():
		return
	_resolve_selected_workstation_from_option()
	if _selected_workstation_id == &"":
		return
	craft_recipe_repeat_queued.emit(_recipe_id_by_index[idx], _selected_workstation_id)

func _on_queue_craft_front_button_pressed() -> void:
	var idx: int = recipe_option.get_selected()
	if idx < 0 and recipe_option.item_count > 0:
		recipe_option.select(0)
		idx = 0
	if idx < 0 or idx >= _recipe_id_by_index.size():
		return
	_resolve_selected_workstation_from_option()
	if _selected_workstation_id == &"":
		return
	craft_recipe_front_queued.emit(_recipe_id_by_index[idx], _selected_workstation_id)

func _on_queue_item_remove_pressed(index: int) -> void:
	_resolve_selected_workstation_from_option()
	if _selected_workstation_id == &"":
		return
	craft_queue_remove_requested.emit(_selected_workstation_id, index)

func _on_workstation_selected(index: int) -> void:
	if index < 0 or index >= _workstation_ids_by_index.size():
		return
	_selected_workstation_id = _workstation_ids_by_index[index]
	workstation_changed.emit(_selected_workstation_id)

func _resolve_selected_workstation_from_option() -> void:
	var ws_index: int = workstation_option.get_selected()
	if ws_index >= 0 and ws_index < _workstation_ids_by_index.size():
		_selected_workstation_id = _workstation_ids_by_index[ws_index]
	elif _selected_workstation_id == &"" and not _workstation_ids_by_index.is_empty():
		_selected_workstation_id = _workstation_ids_by_index[0]

func _on_bed_assign_selected(index: int) -> void:
	if _bed_signal_mute or index < 0:
		return
	bed_assignee_changed.emit(int(bed_assign_option.get_item_metadata(index)))
func _setup_stockpile_filter_widgets() -> void:
	stockpile_filter_mode_option.clear()
	stockpile_filter_mode_option.add_item(_t("hud.stock.filter.mode.all"))
	stockpile_filter_mode_option.add_item(_t("hud.stock.filter.mode.allow_only"))
	stockpile_filter_mode_option.add_item(_t("hud.stock.filter.mode.deny_list"))
	stockpile_filter_mode_option.item_selected.connect(_on_stockpile_filter_mode_selected)
	stock_priority_spin.value_changed.connect(_on_stockpile_priority_spin_changed)
	_stock_filter_checks = {
		&"Wood": stock_wood_check,
		&"Stone": stock_stone_check,
		&"Steel": stock_steel_check,
		&"FoodRaw": stock_food_raw_check,
		&"Meal": stock_meal_check
	}
	for key in _stock_filter_checks.keys():
		var check: CheckBox = _stock_filter_checks[key]
		check.toggled.connect(_on_stock_filter_check_toggled.bind(key))
		stock_limit_resource_option.add_item(String(key))
	stock_limit_resource_option.item_selected.connect(_on_stock_limit_resource_selected)
	stock_apply_limit_button.pressed.connect(_on_stock_apply_limit_pressed)

func _on_stockpile_filter_mode_selected(index: int) -> void:
	if not _stock_signal_mute:
		stockpile_filter_mode_changed.emit(index)

func _on_stock_filter_check_toggled(enabled: bool, resource_key: StringName) -> void:
	if not _stock_signal_mute:
		stockpile_filter_item_changed.emit(resource_key, enabled)

func _on_stockpile_priority_spin_changed(value: float) -> void:
	if not _stock_signal_mute:
		stockpile_priority_changed.emit(int(value))

func _on_stock_limit_resource_selected(_index: int) -> void:
	_refresh_limit_spin_by_selected_resource()

func _on_stock_apply_limit_pressed() -> void:
	if _stock_signal_mute:
		return
	var idx: int = stock_limit_resource_option.get_selected()
	if idx < 0:
		return
	var key: StringName = StringName(stock_limit_resource_option.get_item_text(idx))
	var limit: int = int(stock_limit_spin.value)
	stockpile_limit_changed.emit(key, limit)
	_stock_limit_lookup[key] = limit

func _refresh_limit_spin_by_selected_resource() -> void:
	var idx: int = stock_limit_resource_option.get_selected()
	if idx < 0:
		return
	var key: StringName = StringName(stock_limit_resource_option.get_item_text(idx))
	stock_limit_spin.value = int(_stock_limit_lookup.get(key, -1))

func _refresh_craft_pause_button() -> void:
	if _craft_pause_button != null:
		_craft_pause_button.text = _t("hud.craft.resume") if _craft_queue_paused else _t("hud.craft.pause")

func _disable_focus_for_controls(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		var control: Control = root as Control
		control.focus_mode = Control.FOCUS_NONE
	for child in root.get_children():
		_disable_focus_for_controls(child)

func _format_elapsed_time(total_seconds: float) -> String:
	var total: int = maxi(0, int(floor(total_seconds)))
	var h: int = int(total / 3600)
	var m: int = int((total % 3600) / 60)
	var s: int = int(total % 60)
	return "%02d:%02d:%02d" % [h, m, s]

func _set_equipment_slot_icon(icon: ColorRect, equipped: bool, equipped_color: Color) -> void:
	icon.color = equipped_color if equipped else Color(0.14, 0.14, 0.14, 1.0)

func _set_unit_info_visible(visible: bool) -> void:
	needs_label.visible = visible
	priority_label.visible = visible
	current_job_label.visible = visible
	carry_capacity_label.visible = visible
	equipment_label.visible = visible
	equipment_slots.visible = visible

func _humanize_recipe_id(recipe_id: StringName) -> String:
	var raw: String = String(recipe_id)
	if raw.is_empty():
		return "-"
	var out: String = ""
	for i in range(raw.length()):
		var ch: String = raw.substr(i, 1)
		if i > 0 and ch == ch.to_upper() and ch != ch.to_lower():
			out += " "
		out += ch
	return out.strip_edges()

func _format_recipe_tooltip(recipe: Resource) -> String:
	return _t("hud.recipe.tooltip", {
		"name": String(recipe.display_name),
		"input": _compact_cost_text(recipe.ingredients),
		"output": _compact_cost_text(recipe.products)
	})

func _format_building_button_text(def: Resource) -> String:
	var cost_text: String = _compact_cost_text(def.build_cost)
	if cost_text.is_empty():
		return _t("hud.building.button.no_cost", {"name": String(def.display_name)})
	return "%s\n%s" % [def.display_name, cost_text]

func _format_building_tooltip(def: Resource) -> String:
	var cost_text: String = _compact_cost_text(def.build_cost)
	if cost_text.is_empty():
		cost_text = _t("hud.building.tooltip.no_cost")
	return _t("hud.building.tooltip", {
		"name": String(def.display_name),
		"category": String(def.category),
		"work": "%.0f" % def.required_work,
		"cost": cost_text
	})

func _t(key: String, params: Dictionary = {}, fallback: String = "") -> String:
	return GAME_TEXT.get_text(key, params, fallback)

func _compact_cost_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return ""
	var parts: Array[String] = []
	for key_any in cost.keys():
		parts.append("%s:%d" % [String(key_any), int(cost[key_any])])
	return ", ".join(parts)
