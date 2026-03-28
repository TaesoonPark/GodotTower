extends Node2D

signal site_changed(site: Node)
signal site_completed(site: Node)
signal site_removed(site: Node)
signal site_retry_due(site: Node)

var building_id: StringName = &""
var building_name: String = "Blueprint"
var required_work: float = 30.0
var work_progress: float = 0.0
var complete: bool = false
var job_queued: bool = false
var footprint_size: Vector2 = Vector2(40, 40)
var complete_color: Color = Color(0.35, 0.75, 0.35, 1.0)
var blueprint_color: Color = Color(0.45, 0.55, 0.85, 0.7)
var blocks_movement: bool = false
var passable_for_friendly: bool = false
var cover_bonus: float = 0.0
var trap_damage: int = 0
var trap_cooldown_sec: float = 0.0
var trap_charges: int = 0
var command_aura_bonus: float = 0.0
var command_aura_defense_bonus: float = 0.0
var command_aura_move_bonus: float = 0.0
var command_aura_range: float = 140.0
var farm_growth_bonus: float = 0.0
var farm_yield_bonus: float = 0.0
var farm_support_range: float = 160.0
var structure_max_health: float = 180.0
var repair_work: float = 8.0
var build_cost: Dictionary = {}
var materials_delivered: bool = false

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var progress_sprite: Sprite2D = $ProgressSprite

func _ready() -> void:
	add_to_group("build_sites")
	if base_sprite.texture == null:
		base_sprite.texture = _make_texture(int(footprint_size.x), int(footprint_size.y), blueprint_color)
	if progress_sprite.texture == null:
		progress_sprite.texture = _make_texture(max(12, int(footprint_size.x - 4.0)), 6, Color(0.3, 0.95, 0.4, 0.85))
	_update_visual()
	site_changed.emit(self)

func setup_building(def: Resource, start_complete: bool = false) -> void:
	if def == null:
		return
	building_id = def.id
	building_name = def.display_name
	required_work = maxf(1.0, def.required_work)
	footprint_size = def.footprint_size
	complete_color = def.direct_place_color
	blueprint_color = def.blueprint_color
	blocks_movement = bool(def.blocks_movement)
	passable_for_friendly = bool(def.passable_for_friendly)
	cover_bonus = float(def.cover_bonus)
	trap_damage = int(def.trap_damage)
	trap_cooldown_sec = float(def.trap_cooldown_sec)
	trap_charges = int(def.trap_charges)
	command_aura_bonus = float(def.command_aura_bonus)
	command_aura_defense_bonus = float(def.command_aura_defense_bonus)
	command_aura_move_bonus = float(def.command_aura_move_bonus)
	command_aura_range = float(def.command_aura_range)
	farm_growth_bonus = float(def.farm_growth_bonus)
	farm_yield_bonus = float(def.farm_yield_bonus)
	farm_support_range = float(def.farm_support_range)
	structure_max_health = maxf(10.0, float(def.max_health))
	repair_work = maxf(0.1, float(def.repair_work))
	build_cost = def.build_cost.duplicate(true)
	materials_delivered = false
	set_meta("building_id", building_id)
	set_meta("required_work", required_work)
	set_meta("footprint_size", footprint_size)
	set_meta("blocks_movement", blocks_movement)
	set_meta("passable_for_friendly", passable_for_friendly)
	set_meta("cover_bonus", cover_bonus)
	set_meta("trap_damage", trap_damage)
	set_meta("trap_cooldown_sec", trap_cooldown_sec)
	set_meta("trap_charges", trap_charges)
	set_meta("trap_max_charges", trap_charges)
	set_meta("trap_cooldown_left", 0.0)
	set_meta("trap_maint_job_queued", false)
	set_meta("command_aura_bonus", command_aura_bonus)
	set_meta("command_aura_defense_bonus", command_aura_defense_bonus)
	set_meta("command_aura_move_bonus", command_aura_move_bonus)
	set_meta("command_aura_range", command_aura_range)
	set_meta("farm_growth_bonus", farm_growth_bonus)
	set_meta("farm_yield_bonus", farm_yield_bonus)
	set_meta("farm_support_range", farm_support_range)
	set_meta("structure_max_health", structure_max_health)
	set_meta("structure_health", structure_max_health)
	set_meta("repair_work", repair_work)
	set_meta("repair_job_queued", false)
	set_meta("demolish_job_queued", false)
	set_meta("materials_delivered", materials_delivered)
	if is_node_ready():
		base_sprite.texture = _make_texture(int(footprint_size.x), int(footprint_size.y), blueprint_color)
		progress_sprite.texture = _make_texture(max(12, int(footprint_size.x - 4.0)), 6, Color(0.3, 0.95, 0.4, 0.85))
	if start_complete:
		work_progress = required_work
		complete = true
		_on_completed()
		_build_complete_visual()
	if is_node_ready():
		_update_visual()
	site_changed.emit(self)

func set_job_queued(v: bool) -> void:
	job_queued = v
	site_changed.emit(self)

func set_retry_after_ms(at_ms: int) -> void:
	var safe_ms: int = maxi(0, at_ms)
	set_meta("build_retry_after_ms", safe_ms)
	site_changed.emit(self)
	var delay_sec: float = maxf(0.02, float(safe_ms - Time.get_ticks_msec()) / 1000.0)
	var timer := get_tree().create_timer(delay_sec)
	timer.timeout.connect(func():
		if self == null or not is_instance_valid(self):
			return
		var retry_after_ms: int = int(get_meta("build_retry_after_ms")) if has_meta("build_retry_after_ms") else 0
		if retry_after_ms > Time.get_ticks_msec():
			return
		site_retry_due.emit(self)
	)

func get_build_cost() -> Dictionary:
	return build_cost.duplicate(true)

func requires_material_delivery() -> bool:
	return not materials_delivered

func mark_materials_delivered() -> void:
	materials_delivered = true
	set_meta("materials_delivered", true)
	if is_node_ready():
		_update_visual()
	site_changed.emit(self)

func apply_work(amount: float) -> void:
	if complete:
		return
	work_progress = clampf(work_progress + amount, 0.0, required_work)
	if work_progress >= required_work:
		complete = true
		job_queued = false
		_on_completed()
		_build_complete_visual()
		site_completed.emit(self)
	_update_visual()
	site_changed.emit(self)

func _update_visual() -> void:
	var ratio: float = 0.0
	if required_work > 0.0:
		ratio = work_progress / required_work
	progress_sprite.scale.x = clampf(ratio, 0.05, 1.0)
	if complete:
		base_sprite.modulate = complete_color
		progress_sprite.visible = false
	else:
		if materials_delivered:
			base_sprite.modulate = blueprint_color
		else:
			base_sprite.modulate = blueprint_color.darkened(0.28)
		progress_sprite.visible = true

func _build_complete_visual() -> void:
	var roof := Sprite2D.new()
	roof.texture = _make_texture(int(footprint_size.x), max(6, int(footprint_size.y * 0.25)), complete_color.darkened(0.25))
	roof.position = Vector2(0, -footprint_size.y * 0.5)
	add_child(roof)

	var label := Label.new()
	label.text = building_name
	label.position = Vector2(-footprint_size.x * 0.48, -footprint_size.y * 1.05)
	add_child(label)

func _on_completed() -> void:
	add_to_group("structures")
	add_to_group("repairable_structures")
	if blocks_movement:
		add_to_group("blocking_structures")
	if cover_bonus > 0.0:
		add_to_group("cover_structures")
	if trap_damage > 0:
		add_to_group("trap_structures")
	if command_aura_bonus > 0.0 or command_aura_defense_bonus > 0.0 or command_aura_move_bonus > 0.0:
		add_to_group("command_structures")
	if farm_growth_bonus > 0.0 or farm_yield_bonus > 0.0:
		add_to_group("farm_support_structures")

func _exit_tree() -> void:
	site_removed.emit(self)

func _make_texture(w: int, h: int, color: Color) -> Texture2D:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
