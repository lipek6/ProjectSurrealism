class_name PlayerHUDController extends CanvasLayer

# TODO: Refactor dual-icon concept. The number of dual-icons I will need to make will explode
# 2^n combinations of dual wieldable weapons. I will later create a special inventory slot just for 
# the temporary secondary weapon

@export_group("Managers (Data-Providers)")
@export var weapon_manager: WeaponManager

@export_group("UI Containers")
@export var inventory_container : Control                                       
@export var reticle             : TextureRect                                       
@export var primary_ammo_slot   : HudSlot
@export var secondary_ammo_slot : HudSlot

@export_group("Default elements (Fallback)")
@export var default_reticle     : Texture2D
@export var default_bullet_icon : Texture2D

@export_group("Prefabs")
@export var weapon_slot_scene   : PackedScene                                      

@export_group("Settings")
@export var fade_delay     : float = 3.0      
@export var fade_speed     : float = 5.0      
@export var scale_active   : Vector2 = Vector2(1.1, 1.1)
@export var scale_inactive : Vector2 = Vector2(0.9, 0.9)

# Internal State
var _spawned_slots : Array[HudSlot] = []
var _fade_timer    : float = 0.0

func _ready() -> void:
	if not weapon_manager:
		push_error("HUD Controller cannot function without a WeaponManager")
		return
	
	weapon_manager.inventory_changed.connect(_on_inventory_changed)
	weapon_manager.weapon_equipped.connect(_on_weapon_equipped)
	weapon_manager.weapon_holstered.connect(_on_weapon_holstered)
	weapon_manager.active_weapon_ammo_updated.connect(_on_ammo_updated)
	
	# Initialize HUD State
	_initialize_inventory_slots()
	_initialize_ammo_slots()
	_initialize_stats_slots()
	
	# Ensure the secondary ammo slot is hidden by default
	if secondary_ammo_slot:
		secondary_ammo_slot.modulate.a = 0.0
	

func _process(delta: float) -> void:
	if _fade_timer > 0.0:
		_fade_timer -= delta
		inventory_container.modulate.a = lerpf(inventory_container.modulate.a, 1.0, fade_speed * delta)
	else:
		inventory_container.modulate.a = lerpf(inventory_container.modulate.a, 0.0, (fade_speed * 0.5) * delta)


# ==============================================================================
# INITIALIZATION
# ==============================================================================
func _initialize_inventory_slots() -> void:
	for child: Control in inventory_container.get_children():
		child.queue_free()
	
	for i: int in range(weapon_manager.inventory_max_size):
		var new_slot: HudSlot = weapon_slot_scene.instantiate() as HudSlot
		inventory_container.add_child(new_slot)
		_spawned_slots.append(new_slot)
		
		
		new_slot.set_text("*" + str(i + 1))
		new_slot.set_icon(null)
		new_slot.scale = scale_inactive


func _initialize_ammo_slots() -> void:
	if primary_ammo_slot:
		primary_ammo_slot.set_icon(null)
		primary_ammo_slot.set_text("")
	if secondary_ammo_slot:
		secondary_ammo_slot.set_text("")
		secondary_ammo_slot.set_icon(null)


func _initialize_stats_slots() -> void:
	pass

# ==============================================================================
# SIGNAL RECEIVERS
# ==============================================================================
func _on_inventory_changed() -> void:
	_wake_up_inventory()
	
	for i: int in range(weapon_manager.inventory_max_size):
		var weapon : WeaponInstance = weapon_manager.inventory[i]
		var slot_ui: HudSlot        = _spawned_slots[i]
		
		if weapon != null and weapon.data != null:
			slot_ui.set_icon(weapon.data.icon)
		else:
			slot_ui.set_icon(null)


func _on_weapon_equipped(weapon_data: WeaponResource, is_primary_weapon: bool, is_dual_wielding: bool) -> void:
	_wake_up_inventory()
	
	# Update Reticle
	if reticle:
		reticle.texture = weapon_data.reticle if weapon_data.reticle else default_reticle
	
	# Update Ammo Slots
	if is_primary_weapon and primary_ammo_slot:
		var texture: Texture2D = weapon_data.bullet_icon if weapon_data.bullet_icon else default_bullet_icon
		primary_ammo_slot.set_icon(texture)
		
		# Alt-Fire Logic for Primary Hand
		if not is_dual_wielding and weapon_data.uses_secondary_ammo:
			_toggle_secondary_ammo_slot(true)
			secondary_ammo_slot.set_icon(weapon_data.alt_fire_icon)
			secondary_ammo_slot.set_text("ALT") # Will be updated by ammo signals later
	
	# Dual Wield Logic for Secondary Hand
	if not is_primary_weapon:
		_toggle_secondary_ammo_slot(true)
		var texture: Texture2D = weapon_data.bullet_icon if weapon_data.bullet_icon else default_bullet_icon
		secondary_ammo_slot.set_icon(texture)
	
	# Update Grid Icon & Highlight
	var active_slot_ui: HudSlot = _spawned_slots[weapon_manager.active_slot_idx]
	active_slot_ui.set_icon(weapon_data.dual_icon if is_dual_wielding and weapon_data.dual_icon else weapon_data.icon)
	_highlight_active_slot(weapon_manager.active_slot_idx)


func _on_weapon_holstered(was_primary: bool) -> void:
	_wake_up_inventory()
	
	if was_primary:
		if reticle: reticle.texture = null
		if primary_ammo_slot: primary_ammo_slot.set_text("- | -")
		_toggle_secondary_ammo_slot(false)
	else:
		# If we holstered the secondary weapon, hide its ammo UI
		_toggle_secondary_ammo_slot(false)


func _on_ammo_updated(current_mag: int, current_reserve: int, is_primary_weapon: bool) -> void:
	var target_slot: HudSlot = primary_ammo_slot if is_primary_weapon else secondary_ammo_slot
	
	if target_slot:
		var formatted_ammo: String = "%02d / %03d" % [current_mag, current_reserve]
		print(formatted_ammo)
		target_slot.set_text(str(current_mag) + "/" + str(current_reserve))


# ==============================================================================
# VISUAL HELPERS
# ==============================================================================
func _wake_up_inventory() -> void:
	_fade_timer = fade_delay


func _toggle_secondary_ammo_slot(show_slot: bool) -> void:
	if not secondary_ammo_slot: return
	
	var target_alpha: float = 1.0 if show_slot else 0.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(secondary_ammo_slot, "modulate:a", target_alpha, 0.3)


func _highlight_active_slot(active_index: int) -> void:
	if active_index < 0 or active_index >= weapon_manager.inventory_max_size: return
	
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	for i: int in range(_spawned_slots.size()):
		var slot: HudSlot = _spawned_slots[i]
		slot.pivot_offset = slot.size / 2.0
		
		if i == active_index:
			tween.tween_property(slot, "scale", scale_active, 0.25)
			tween.tween_property(slot, "modulate:a", 1.0, 0.25)
		else:
			tween.tween_property(slot, "scale", scale_inactive, 0.25)
			tween.tween_property(slot, "modulate:a", 0.5, 0.25)
