class_name WeaponManager extends Node3D
## Acts as the central brain for the player's weapon system.
## Handles inventory management, equipping/swapping, input routing, and ballistic execution.

# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region System Setup
@export_group("System Setup")
@export var player     : Player                                                 ## Reference to the root Player node to access movement state, inputs, and the camera.
@export var auto_equip : bool = true                                            ## If true, automatically equips a weapon the moment it is picked up into an empty slot.
#endregion

#region Inventory Configuration
@export_group("Inventory")
@export var max_slots : int = 2                                                 ## Maximum number of weapons the player can carry at once.
var inventory : Array[WeaponResource] = []                                      ## Array of unique, duplicated weapon data structures owned by the player.
var weapon_instances : Array[WeaponInstance] = []                               ## Array of cached 3D WeaponInstance nodes currently attached to the player's hand.
var active_index : int = 0                                                      ## The array index of the currently equipped weapon.
#endregion

#region Internal State
var fire_cooldown : float = 0.0                                                 ## Internal timer tracking the cooldown between shots based on the active weapon's fire rate.
#endregion

#region Node References
@onready var hands_animation         : AnimationPlayer = $FpArms/AnimationPlayer
@onready var right_hand_offset_point : Node3D          = %RightWeaponOffsetFix
#endregion


# ==============================================================================
# CORE EXECUTION
# ==============================================================================
#region Core Lifecycle
## Called by the Player's physics process to tick down timers and check for firing input.
func process_weapons(delta: float) -> void:
	handle_shoot(delta)
	handle_reload()
	handle_swap()


## Processes input and cooldowns to determine if the weapon should fire this frame.
func handle_shoot(delta: float) -> void:
	if fire_cooldown > 0.0: fire_cooldown -= delta
	if inventory.size() <= 0: return
	
	var weapon    : WeaponResource = inventory[active_index]
	var try_shoot : bool = false
	
	# Determine firing logic based on the FIRE_MODE enum
	match weapon.fire_mode:
		weapon.FIRE_MODE.SEMI_AUTOMATIC:
			try_shoot = player.input.wants_primary_shoot
		weapon.FIRE_MODE.AUTOMATIC:
			try_shoot = player.input.wants_primary_shoot
	
	if try_shoot and fire_cooldown <= 0.0:
		if weapon.on_mag_ammo >= weapon.ammo_cost:
			primary_shoot(weapon)
		else:
			# TODO: Play an empty "Click" sound and animation here
			pass


func handle_reload() -> void:
	if player.input.wants_reload:
		var weapon : WeaponResource = inventory[active_index]
		var free_mag_space : int = weapon.max_on_mag_ammo - weapon.on_mag_ammo
		
		if free_mag_space > 0 and weapon.on_reserve_ammo > 0:
			
			match weapon.weapon_name:
				"Pistol", "PistolAutomatic":
					weapon_instances[active_index].anim_player.play("pistol_reload")
					hands_animation.play("fp_pistol_reload")
				_:
					print("UNKOWN WEAPON TO RELOAD")
			
			if weapon.on_reserve_ammo >= free_mag_space:
				weapon.on_reserve_ammo -= free_mag_space
				weapon.on_mag_ammo = weapon.max_on_mag_ammo
			else:
				weapon.on_mag_ammo += weapon.on_reserve_ammo
				weapon.on_reserve_ammo = 0


func handle_swap() -> void:
	# GUARD CLAUSE: Prevent modulo-by-zero crashes, and don't swap if we only have 1 gun!
	if inventory.size() <= 1: 
		return
		
	if player.input.wants_weapon_swap:
		var next_index = (active_index + 1) % inventory.size()
		equip_weapon(next_index)

#endregion


# ==============================================================================
# INVENTORY MANAGEMENT
# ==============================================================================
#region Inventory & Equipping
## Attempts to add a ground weapon to the player's inventory or pool its ammo.
## Returns true if successfully picked up, false if inventory/ammo is full.
## If true is returned, the ground weapon will queue_free()
func add_weapon_to_inventory(new_weapon : WeaponResource) -> bool:
	# Weapon is already in inventory. Try to extract its ammo
	var inventory_index : int = get_inventory_index(new_weapon)
	if inventory_index != -1:                                                          
		return add_ammo(inventory_index, new_weapon)
	
	# Weapon is not in inventory. Try to equip it
	elif inventory.size() < max_slots:
		print("GOT NEW WEAPON!!!!")
		# Create a unique clone of the resource so we don't edit the global file
		var local_weapon_data : WeaponResource = new_weapon.duplicate() 
		
		# Instantiate the physical weapon scene
		var new_weapon_node : WeaponInstance = local_weapon_data.weapon_scene.instantiate()
		
		# Add to hand and hide it immediately
		right_hand_offset_point.add_child(new_weapon_node)
		new_weapon_node.hide()
		
		# Cache the data and the instance
		inventory.append(local_weapon_data)
		weapon_instances.append(new_weapon_node)
		
		if auto_equip: 
			equip_weapon(inventory.size() - 1)
			
		return true
		
	return false


## Swaps the active weapon to the requested inventory index and plays equip animations.
func equip_weapon(index: int) -> void:
	# Hide the old weapon
	if weapon_instances.size() > active_index and weapon_instances[active_index] != null:
		weapon_instances[active_index].hide()
		
	# Show the new weapon
	weapon_instances[index].show()
	active_index = index
	
	# Play dynamic equip animations
	match inventory[index].weapon_name:
		"Pistol", "PistolAutomatic":
			# CRITICAL FIX: Stop the animation players first so the equip animation is forced to override whatever was playing!
			hands_animation.stop()
			weapon_instances[index].anim_player.stop()
			
			hands_animation.play("fp_pistol_equip")
			weapon_instances[index].anim_player.play("pistol_equip")
			weapon_instances[index].play_equip_effects(inventory[index].equip_sound)
		_:
			print("WARNING: Missing equip animation logic for: ", inventory[index].weapon_name)

## Returns the array index of the weapon if the player owns it, or -1 if they don't.
func get_inventory_index(weapon: WeaponResource) -> int:
	for index : int in range(inventory.size()):
		if inventory[index].weapon_name == weapon.weapon_name:
			return index
	return -1


## Attempts to transfer ammo from a ground weapon to the player's inventory.
func add_ammo(index : int, ground_weapon : WeaponResource) -> bool:
	if not ground_weapon.pickable_ground_ammo:                                         
		return false
	
	var player_weapon : WeaponResource = inventory[index]
	
	# Check if there is room for more reserve ammo
	if player_weapon.on_reserve_ammo < player_weapon.max_on_reserve_ammo:        
		var ammo_to_add : int = ground_weapon.on_mag_ammo + ground_weapon.on_reserve_ammo
		player_weapon.on_reserve_ammo = clampi(player_weapon.on_reserve_ammo + ammo_to_add, 0, player_weapon.max_on_reserve_ammo)
		return true
	
	# Ammo is completely full
	return false


## Called when walking over a weapon with a full inventory.
func prompt_ground_weapon_swap(ground_weapon : WeaponResource) -> void:
	print("Press [Interact] to swap currently held weapon for: ", ground_weapon.weapon_name)
#endregion


# ==============================================================================
# COMBAT & BALLISTICS
# ==============================================================================
#region Combat Execution
## Deducts ammo, resets cooldowns, plays effects, and calculates ballistics.
func primary_shoot(weapon : WeaponResource) -> void:
	# Math & State
	weapon.on_mag_ammo -= weapon.ammo_cost
	fire_cooldown = 1.0 / weapon.fire_rate                                      
	
	var current_instance : WeaponInstance = weapon_instances[active_index]
	
	# Animations
	current_instance.anim_player.stop()
	current_instance.anim_player.play("pistol_shoot")
	hands_animation.stop()
	hands_animation.play("fp_pistol_shoot")
	
	# VFX & Sound
	current_instance.play_shoot_effects(weapon.shoot_effect, weapon.casing_scene, weapon.shoot_sound)
	
	# Ballistics
	execute_ballistics(weapon)


## Triggers secondary fire behavior (Aim Down Sights, Grenade Launcher, etc).
func secondary_shoot() -> void:
	pass


## Projects a raycast to determine Hitscan damage or physical Projectile spawning.
func execute_ballistics(weapon : WeaponResource) -> void:
	var raycast : RayCast3D = player.aim_raycast
	raycast.force_raycast_update()
	
	var target_point : Vector3
	var distance     : float
	
	if raycast.is_colliding():
		target_point = raycast.get_collision_point()
		distance = raycast.global_position.distance_to(target_point)
		var hit_object = raycast.get_collider()
		
		# HITSCAN CONDITION
		if distance <= weapon.hybrid_ballistics_distance:
			# Apply generic damage
			if hit_object.has_method("take_damage"):
				hit_object.take_damage(weapon.damage)
				
			# Apply physics impact
			if hit_object.has_method("take_impact"):
				var hit_direction : Vector3 = (target_point - raycast.global_position).normalized()
				hit_object.take_impact(target_point, hit_direction, weapon.impact_force) 
			
			# TODO: Spawn a Hitscan bullet hole decal/spark at 'target_point'
			return
			
		# PROJECTILE CONDITION
		else:
			# Target is too far, rely on physical bullet drop/travel time
			pass 
	
	# If we hit nothing (aiming at the sky), pick a point far in the distance
	if not raycast.is_colliding():
		target_point = raycast.global_position + (raycast.global_transform.basis.z * -1000.0)
	
	# TODO: Instantiate weapon.shoot_effect (Physical Projectile) here. 
	# Place it at the current_instance.muzzle_point position, and use `look_at(target_point)`!
#endregion
