class_name WeaponManager extends Node
## Acts as the central brain for the player's weapon system.
## Handles a strict grid-based inventory, equipping/swapping, 
## input routing, and ballistic execution.


#region signals
signal weapon_equipped(weapon_data: WeaponResource, is_primary_weapon: bool, is_dual_wielding: bool)
signal weapon_holstered(is_primary_weapon: bool)
signal request_conextual_actor_animation(state_name: StringName, force_restart: bool, duration: float, is_secondary: bool)

#endregion


@export_group("External Components")
@export var actor : Actor

@export_group("Weapon Placement")
@export var primary_attachment    : BoneAttachment3D 
@export var secondary_attachment  : BoneAttachment3D 

@export_group("Inventory")
@export var inventory_max_size : int = 2

@export_group("Internal HSM")
@export var hsm: WeaponManagerHSM


# Active Pointers
var active_primary_weapon   : WeaponInstance = null
var active_secondary_weapon : WeaponInstance = null

var inventory : Array[WeaponInstance] = [] 
var active_slot_idx: int = 0


func _ready() -> void:
	inventory.resize(inventory_max_size)
	inventory.fill(null)
	hsm.init_machine(self)


# TODO: Needs to distinguish between auto equip, primary and secondary equiping
func add_weapon(world_weapon: WeaponWorldInstance) -> bool:
	# SCAVENGING (Already have this weapon)
	var inventory_weapon: WeaponInstance = _find_weapon(world_weapon.data.id_name)
	if inventory_weapon != null:
		_scav_ammo(world_weapon, inventory_weapon)
		return true
	
	
	# PICKING UP A NEW WEAPON (There is free inventory space)
	var free_slot: int = _find_empty_inventory_slot()
	if free_slot != -1:
		_setup_new_weapon(world_weapon, free_slot) # Will throw the state machine into the SwapState to finish the job
		return true
	
	# SWAPPING CURRENT WEAPON (Inventory is full and this weapon is not in inventory)
	# TODO
	
	
	return false # Inventory is full


func _find_weapon(target_id_name: StringName) -> WeaponInstance:
	for weapon: WeaponInstance in inventory:
		if weapon != null and weapon.data.id_name == target_id_name:
			return weapon
	return null


func _find_empty_inventory_slot() -> int:
	for i: int in range(inventory.size()):
		if inventory[i] == null:
			return i
	return -1


func _setup_new_weapon(world_weapon: WeaponWorldInstance, slot_idx: int) -> void:
	# Instantiate the high-fidelity view model
	var new_weapon: WeaponInstance = world_weapon.data.view_model.instantiate()
	new_weapon.data = world_weapon.data # Data injection
	
	# TRANSFER THE VOLATILE DATA
	new_weapon.current_primary_mag_ammo = world_weapon.prim_mag_ammo
	new_weapon.current_primary_reserve_ammo = world_weapon.prim_res_ammo
	new_weapon.current_secondary_mag_ammo = world_weapon.sec_mag_ammo
	new_weapon.current_secondary_reserve_ammo = world_weapon.sec_res_ammo
	new_weapon._is_ammo_initialized = true # Prevent _ready() from overwriting
	
	inventory[slot_idx] = new_weapon
	add_child(new_weapon) # Adding as holstered
	
	new_weapon.hide()
	if new_weapon.hsm: 
		new_weapon.hsm.set_active(false)
	
	# SIGNALS
	new_weapon.request_actor_animation.connect(_on_weapon_to_actor_animation_request)
	
	# Destroy the world model
	world_weapon.queue_free()
	
	# Auto-Equip logic
	hsm.blackboard.set_var(&"pending_swap_slot", slot_idx)
	weapon_equipped.emit(new_weapon, true, false)
	hsm.dispatch(WeaponManagerHSM.EVENT_SWAP_REQ)


func _scav_ammo(world_weapon: WeaponWorldInstance, inventory_weapon: WeaponInstance) -> void:
	inventory_weapon.current_primary_reserve_ammo   = clampi(world_weapon.prim_mag_ammo + world_weapon.prim_res_ammo + inventory_weapon.current_primary_reserve_ammo, 0, inventory_weapon.data.primary_max_reserve_ammo)
	inventory_weapon.current_secondary_reserve_ammo = clampi(world_weapon.sec_mag_ammo + world_weapon.sec_res_ammo + inventory_weapon.current_secondary_reserve_ammo, 0, inventory_weapon.data.secondary_max_reserve_ammo)
	
	# Destroy the world model
	world_weapon.queue_free()


## Works as a Middle-man for the Actor animations. Necessary to distinguish which weapon equipped is requesting animation.
func _on_weapon_to_actor_animation_request(state_name: StringName, force_restart: bool, duration: float, requester: WeaponInstance) -> void:
	
	print("REQUEST: ")
	print("- Requester: " + str(requester.data.id_name))
	print("- State    : " + str(state_name))
	print("- Duration : " + str(duration))
	print("- Restart  : " + str(force_restart))
	
	if requester == active_primary_weapon:
		request_conextual_actor_animation.emit(state_name, force_restart, duration, false)
	elif requester == active_secondary_weapon:
		request_conextual_actor_animation.emit(state_name, force_restart, duration, true)
	else:
		push_error(str(requester.data.id_name) + " requested an animation when it shouldn't. REQ: " + str(requester.name) + ". MANAGER: " + str(self.name))
