class_name WeaponManager extends Node
## Acts as the central brain for the player's weapon system.
## Handles a strict grid-based inventory, equipping/swapping, 
## input routing, and ballistic execution.


# TODO: Refactor all of this into a hierachical state machine / state machine
# like structure, because a lot of externam components are needing to repeat
# logic that is already executed here (like determining if dual wielding is happening)
# making everything harder to maintain and to scale. 

# ==============================================================================
# INVENTORY STATE SIGNALS (The Manager's own signals)
# ==============================================================================
signal inventory_changed() 
signal weapon_equipped(weapon_data: WeaponResource, is_primary_weapon: bool, is_dual_wielding: bool)
signal weapon_holstered(is_primary_weapon: bool)
signal ammo_scavenged(weapon_id: StringName, amount: int)

# ==============================================================================
# RELAY SIGNALS (Bubbled up from the WeaponInstances to the UI/Animation)
# ==============================================================================
signal active_weapon_ammo_updated(current_mag: int, current_reserve: int, is_primary_weapon: bool)
signal active_weapon_fired(is_primary_weapon: bool, is_primary_action: bool)
signal active_weapon_released(is_primary_weapon: bool, is_primary_action: bool)
signal active_weapon_reload_started(duration: float, is_empty: bool, is_primary_weapon: bool)
signal active_weapon_action_denied(reason: WeaponInstance.DENIAL_REASON, is_primary_weapon: bool)

signal actor_animation_requested(anim_name: StringName, is_primary_weapon: bool)

@export_group("Hack to avoid dealing with this problem right now")
@export var can_dual_wield: bool = false

@export_group("External Components")
@export var actor : Actor

@export_group("Weapon Placement")
@export var primary_attachment    : BoneAttachment3D 
@export var secondary_attachment  : BoneAttachment3D 

@export_group("Inventory")
@export var inventory_max_size : int = 2

# Active Pointers
var active_primary_weapon   : WeaponInstance = null
var active_secondary_weapon : WeaponInstance = null

var inventory : Array[WeaponInstance] = [] 
var active_slot_idx: int = 0

func _ready() -> void:
	inventory.resize(inventory_max_size)
	inventory.fill(null)

# ==============================================================================
# INPUT ROUTING
# ==============================================================================
func process_weapons() -> void:
	if actor.input:
		var input: ActorInput = actor.input
		process_triggers(input)
		process_reloads(input)
		process_swaps(input)

func process_triggers(input: ActorInput) -> void:
	# PRIMARY ACTION (Left Click) -> Always maps to the Right Hand (Primary Weapon)
	if active_primary_weapon: 
		if input.wants_primary_shoot:
			active_primary_weapon.pull_primary_trigger()
		else:
			active_primary_weapon.release_primary_trigger()
	
	# SECONDARY ACTION (Right Click) -> Maps to Left Hand IF dual wielding, else Alt-Fire
	if input.wants_secondary_shoot:
		if active_secondary_weapon:
			active_secondary_weapon.pull_primary_trigger() # Pulls the main trigger of the left gun
		elif active_primary_weapon: 
			active_primary_weapon.pull_secondary_trigger() # Alt-fire on the right gun
	else:
		if active_secondary_weapon:
			active_secondary_weapon.release_primary_trigger()
		elif active_primary_weapon:
			active_primary_weapon.release_secondary_trigger()

func process_reloads(input: ActorInput) -> void:
	if input.wants_reload:
		if active_primary_weapon: active_primary_weapon.reload()
		if active_secondary_weapon: active_secondary_weapon.reload()

func process_swaps(input: ActorInput) -> void:
	if   input.wants_next_slot : cycle_weapons(true)
	elif input.wants_prev_slot : cycle_weapons(false)
	elif input.wants_slot_1    : equip_slot(0)
	elif input.wants_slot_2    : equip_slot(1)
	elif input.wants_slot_3    : equip_slot(2)
	elif input.wants_slot_4    : equip_slot(3)
	elif input.wants_slot_5    : equip_slot(4)
	elif input.wants_slot_6    : equip_slot(5)
	elif input.wants_slot_7    : equip_slot(6)
	elif input.wants_slot_8    : equip_slot(7)
	elif input.wants_slot_9    : equip_slot(8)


# ==============================================================================
# INVENTORY LIFECYCLE
# ==============================================================================
func interact_pickup_weapon(world_weapon: WeaponWorldInstance, wants_dual_wield: bool = false) -> void:
	if not world_weapon or not world_weapon.data: return
	var weapon_data : WeaponResource = world_weapon.data
	
	# Dual Wield Request
	if can_dual_wield:
		var is_primary_one_handed: bool = active_primary_weapon and not active_primary_weapon.data.two_handed
		if wants_dual_wield and not weapon_data.two_handed and is_primary_one_handed: 
			if active_secondary_weapon:
				drop_weapon(active_secondary_weapon)
			_spawn_and_equip_direct(weapon_data, false) 
			world_weapon.queue_free()
			return
	
	# Ammo scavenging
	if weapon_data.pickable_ground_ammo:
		for weapon: WeaponInstance in inventory:
			if weapon and weapon.data.id_name == weapon_data.id_name:
				if weapon.current_reserve_ammo < weapon.data.max_reserve_ammo:
					weapon.current_reserve_ammo = clampi(weapon_data.max_mag_ammo + weapon.current_reserve_ammo, 0, weapon.data.max_reserve_ammo)
					world_weapon.queue_free()
					ammo_scavenged.emit(weapon_data.id_name, weapon_data.max_mag_ammo)
				
				# Update the HUD immediately if we just added ammo to our active gun!
				if weapon == active_primary_weapon:
					_on_active_weapon_ammo_updated(weapon.current_mag_ammo, weapon.current_reserve_ammo, true)
				elif weapon == active_secondary_weapon:
					_on_active_weapon_ammo_updated(weapon.current_mag_ammo, weapon.current_reserve_ammo, false)
				return

	# Free inventory space
	for slot: int in range(inventory_max_size):
		if inventory[slot] == null:
			add_weapon_to_inventory(weapon_data, slot, true)
			world_weapon.queue_free()
			return
	
	# 4. Inventory Full (Swap primary)
	if active_primary_weapon:
		drop_weapon(active_primary_weapon)
		add_weapon_to_inventory(weapon_data, active_slot_idx, true) 
		world_weapon.queue_free()


func try_auto_pickup(world_weapon: WeaponWorldInstance) -> void:
	if not world_weapon or not world_weapon.data: return
	var new_weapon_data: WeaponResource = world_weapon.data
	
	if new_weapon_data.pickable_ground_ammo:
		for weapon: WeaponInstance in inventory:
			if weapon and weapon.data.id_name == new_weapon_data.id_name:
				if weapon.current_reserve_ammo < weapon.data.max_reserve_ammo:
					weapon.current_reserve_ammo = clampi(new_weapon_data.max_mag_ammo + weapon.current_reserve_ammo, 0, weapon.data.max_reserve_ammo)
					world_weapon.queue_free()
					ammo_scavenged.emit(new_weapon_data.id_name, new_weapon_data.max_mag_ammo)
				
				if weapon == active_primary_weapon:
					_on_active_weapon_ammo_updated(weapon.current_mag_ammo, weapon.current_reserve_ammo, true)
				elif weapon == active_secondary_weapon:
					_on_active_weapon_ammo_updated(weapon.current_mag_ammo, weapon.current_reserve_ammo, false)
				return
	
	for slot: int in range(inventory_max_size):
		if inventory[slot] == null:
			add_weapon_to_inventory(new_weapon_data, slot, true)
			world_weapon.queue_free()
			return


func add_weapon_to_inventory(weapon_data: WeaponResource, target_slot: int, auto_equip: bool = false) -> void:
	if target_slot < 0 or target_slot >= inventory.size(): return
	if inventory[target_slot] != null: return 
	
	var new_weapon_instance : WeaponInstance = weapon_data.view_model.instantiate() as WeaponInstance
	new_weapon_instance.data = weapon_data                                      
	
	self.add_child(new_weapon_instance)
	new_weapon_instance.hide()
	
	inventory[target_slot] = new_weapon_instance
	inventory_changed.emit()
	
	if auto_equip:
		equip_slot(target_slot)


func drop_weapon(weapon: WeaponInstance) -> void:
	if not weapon: return
	
	if weapon == active_primary_weapon: 
		active_primary_weapon = null
		_holster_weapon(weapon) # Ensures signals are disconnected!
	elif weapon == active_secondary_weapon: 
		active_secondary_weapon = null  # WARNING: This needs to be done before calling _holster_weapon to unsure the primary arm does back to the single wield state
		_holster_weapon(weapon)
	
	var slot_idx: int = inventory.find(weapon)
	if slot_idx != -1:
		inventory[slot_idx] = null 
		inventory_changed.emit()
	
	if weapon.data.world_model:
		var dropped_item: WeaponWorldInstance = weapon.data.world_model.instantiate() as WeaponWorldInstance
		dropped_item.data = weapon.data 
		self.get_tree().root.add_child(dropped_item)
		dropped_item.global_position = secondary_attachment.global_position
		dropped_item.apply_central_impulse(dropped_item.to_local(Vector3(0.0, 0.0, 0.00005)))
		# TODO: ADD DROP IMPULSE
		
	weapon.queue_free()


func _spawn_and_equip_direct(weapon_data: WeaponResource, is_primary_weapon: bool) -> void:
	var temp_weapon: WeaponInstance = weapon_data.view_model.instantiate() as WeaponInstance
	temp_weapon.data = weapon_data
	
	self.add_child(temp_weapon)
	equip_weapon(temp_weapon, is_primary_weapon)

# ==============================================================================
# EQUIPPING LOGIC
# ==============================================================================
func equip_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory.size(): return
	if inventory[slot_index] == null: return
	if slot_index == active_slot_idx and active_primary_weapon != null: return
	
	if active_primary_weapon:
		_holster_weapon(active_primary_weapon)
	
	active_slot_idx = slot_index
	equip_weapon(inventory[active_slot_idx], true)


func equip_weapon(weapon: WeaponInstance, is_primary_weapon: bool) -> void:
	if not weapon: return
	var target_attachment : BoneAttachment3D
	
	if is_primary_weapon:
		if active_primary_weapon: _holster_weapon(active_primary_weapon)
		active_primary_weapon = weapon
		target_attachment = primary_attachment
		if weapon.data.placement_fix:
			weapon.position = weapon.data.placement_fix.primary_pos
			weapon.rotation = weapon.data.placement_fix.primary_rot
			weapon.scale    = weapon.data.placement_fix.primary_scl
	else:
		if active_secondary_weapon: drop_weapon(active_secondary_weapon)
		active_secondary_weapon = weapon
		target_attachment = secondary_attachment
		if weapon.data.placement_fix:
			weapon.position = weapon.data.placement_fix.secondary_pos
			weapon.rotation = weapon.data.placement_fix.secondary_rot
			weapon.scale    = weapon.data.placement_fix.secondary_scl
		

	
	weapon.get_parent().remove_child(weapon)
	target_attachment.add_child(weapon)
	_connect_weapon_signals(weapon, is_primary_weapon)
	
	# Determine dual-wield state dynamically
	var is_dual_wielding : bool = active_primary_weapon != null and active_secondary_weapon != null
	weapon_equipped.emit(weapon.data, is_primary_weapon, is_dual_wielding) 
	
	weapon.show()
	weapon.equip()
	weapon.set_process(true) # Wake up the gun's internal cooldown timers TODO: PUT THIS LOGIC INSIDE weapon.equip()


func _holster_weapon(weapon: WeaponInstance) -> void:
	if not weapon: return
	
	# We must figure out if it was the primary or secondary weapon to disconnect cleanly
	var was_primary: bool = (weapon == active_primary_weapon)
	
	_disconnect_weapon_signals(weapon, was_primary)
	
	weapon.unequip()
	weapon.hide()
	weapon.set_process(false) # Put the gun's logic to sleep
	
	weapon.get_parent().remove_child(weapon)
	self.add_child(weapon)
	weapon_holstered.emit(was_primary)


func cycle_weapons(towards_next: bool) -> void:
	if active_secondary_weapon: 
		drop_weapon(active_secondary_weapon)
		return
	
	# Uses posmod to safely loop backward without going into negative indices
	var step : int = 1 if towards_next else -1
	for i: int in range(1, inventory_max_size):
		var check_idx: int = posmod(active_slot_idx + (i * step), inventory_max_size)
		if inventory[check_idx] != null:
			equip_slot(check_idx)
			return


func execute_ballistics(weapon_data: WeaponResource) -> void:
	pass


# ==============================================================================
# SIGNAL ENCAPSULATION & RELAYS
# ==============================================================================

## Binds the boolean `is_primary_weapon` directly into the connection.
## When the weapon fires, it passes its own arguments, and Godot appends the bound boolean at the end!
func _connect_weapon_signals(weapon: WeaponInstance, is_primary_weapon: bool) -> void:
	if not weapon.ammo_updated.is_connected(_on_active_weapon_ammo_updated):
		weapon.ammo_updated.connect(_on_active_weapon_ammo_updated.bind(is_primary_weapon))
	
	# Bind true for Primary Action
	if not weapon.primary_fired.is_connected(_on_active_weapon_fired): 
		weapon.primary_fired.connect(_on_active_weapon_fired.bind(is_primary_weapon, true))
		
	# Bind false for Secondary Action
	if weapon.has_signal("secondary_fired") and not weapon.secondary_fired.is_connected(_on_active_weapon_fired):
		weapon.secondary_fired.connect(_on_active_weapon_fired.bind(is_primary_weapon, false))
		
	# Actions (Releasing)
	if not weapon.primary_released.is_connected(_on_active_weapon_released):
		weapon.primary_released.connect(_on_active_weapon_released.bind(is_primary_weapon, true))
		
	if weapon.has_signal("secondary_released") and not weapon.secondary_released.is_connected(_on_active_weapon_released):
		weapon.secondary_released.connect(_on_active_weapon_released.bind(is_primary_weapon, false))
	
	if not weapon.reload_started.is_connected(_on_active_weapon_reload_started):
		weapon.reload_started.connect(_on_active_weapon_reload_started.bind(is_primary_weapon))
	
	if not weapon.action_denied.is_connected(_on_active_weapon_action_denied):
		weapon.action_denied.connect(_on_active_weapon_action_denied.bind(is_primary_weapon))


func _disconnect_weapon_signals(weapon: WeaponInstance, is_primary_weapon: bool) -> void:
	if weapon.ammo_updated.is_connected(_on_active_weapon_ammo_updated):
		weapon.ammo_updated.disconnect(_on_active_weapon_ammo_updated)
	
	if weapon.primary_fired.is_connected(_on_active_weapon_fired):
		weapon.primary_fired.disconnect(_on_active_weapon_fired)
		
	if weapon.has_signal("secondary_fired") and weapon.secondary_fired.is_connected(_on_active_weapon_fired):
		weapon.secondary_fired.disconnect(_on_active_weapon_fired)
		
	if weapon.primary_released.is_connected(_on_active_weapon_released):
		weapon.primary_released.disconnect(_on_active_weapon_released)
		
	if weapon.has_signal("secondary_released") and weapon.secondary_released.is_connected(_on_active_weapon_released):
		weapon.secondary_released.disconnect(_on_active_weapon_released)
	
	if weapon.reload_started.is_connected(_on_active_weapon_reload_started):
		weapon.reload_started.disconnect(_on_active_weapon_reload_started)
	
	if weapon.action_denied.is_connected(_on_active_weapon_action_denied):
		weapon.action_denied.disconnect(_on_active_weapon_action_denied)


# --- THE RELAYS ---
func _on_active_weapon_ammo_updated(current_mag: int, current_reserve: int, is_primary_weapon: bool) -> void:
	active_weapon_ammo_updated.emit(current_mag, current_reserve, is_primary_weapon)

func _on_active_weapon_fired(is_primary_weapon: bool, is_primary_action: bool) -> void:
	var active_gun = active_primary_weapon if is_primary_weapon else active_secondary_weapon
	
	# Execute physical logic
	execute_ballistics(active_gun.data)
	
	# Bubble up for the UI
	active_weapon_fired.emit(is_primary_weapon, is_primary_action)
	
	# Tell the animation controller which generic state to play
	var state_to_play : StringName = &"PrimaryPull" if is_primary_action else &"SecondaryPull"
	actor_animation_requested.emit(state_to_play, is_primary_weapon, true)

func _on_active_weapon_released(is_primary_weapon: bool, is_primary_action: bool) -> void:
	active_weapon_released.emit(is_primary_weapon, is_primary_action)

func _on_active_weapon_reload_started(duration: float, is_empty: bool, is_primary_weapon: bool) -> void:
	active_weapon_reload_started.emit(duration, is_empty, is_primary_weapon)
	
	var state_to_play : StringName = &"ReloadEmpty" if is_empty else &"Reload"
	actor_animation_requested.emit(state_to_play, is_primary_weapon, false)

func _on_active_weapon_action_denied(reason: WeaponInstance.DENIAL_REASON, is_primary_weapon: bool) -> void:
	active_weapon_action_denied.emit(reason, is_primary_weapon)
