class_name WeaponManager extends Node3D

#region Setup
@export var player : Player
@export var auto_equip : bool = true
var fire_cooldown : float = 0.0
#endregion

#region Inventory
@export var max_slots : int = 2
var inventory         : Array[WeaponResource] = []
var weapon_instances  : Array[Node3D] = []                                      # Caches the physical 3D models
var weapon_anims      : Array[AnimationPlayer] = []                             # Caches the animation pointers
var weapon_effects    : Array[Node3D] = []
var active_index      : int = 0                                                 # Weapon currently in hands
#endregion

@onready var hands_animation : AnimationPlayer = $FpArms/AnimationPlayer
@onready var right_hand_offset_point : Node3D = %RightWeaponOffsetFix

func prompt_ground_weapon_swap(ground_weapon : WeaponResource) -> void:
	print("Press E to swap weapon for: ", ground_weapon.weapon_name)


# Always adds the weapon to the end of the array
func add_weapon_to_inventory(new_weapon : WeaponResource) -> bool:
	# Weapon already in inventory
	var invetory_index : int = get_inventory_index(new_weapon)
	if invetory_index != -1:                                                    # -1 = not in inventory                                        
		if add_ammo(invetory_index, new_weapon):                                # returns true if ammo fits
			return true
		return false
	
	# Weapon not in inventory
	elif inventory.size() < max_slots:
		var local_weapon_data : WeaponResource = new_weapon.duplicate()         # Local clone
		var new_weapon_node : Node3D = local_weapon_data.weapon_scene.instantiate()
		
		right_hand_offset_point.add_child(new_weapon_node)
		new_weapon_node.hide()
		
		# Append the local clone, not the global ground weapon
		inventory.append(local_weapon_data)
		weapon_instances.append(new_weapon_node)
		weapon_effects.append(local_weapon_data.shooting_effect)
		weapon_anims.append(new_weapon_node.get_node("AnimationPlayer"))
		
		if auto_equip: equip_weapon(inventory.size() - 1)
		return true
	return false



func equip_weapon(index: int) -> void:
	if weapon_instances.size() > active_index and weapon_instances[active_index] != null:
		weapon_instances[active_index].hide()
		
	weapon_instances[index].show()
	
	match inventory[index].weapon_name:
		"Pistol":
			hands_animation.play("fp_pistol_equip")
			weapon_anims[index].play("pistol_equip")
		_:
			print("THIS WEAPON DOESN'T HAVE A NAME. NAME IT!!!!")
	
	active_index = index



func get_inventory_index(weapon: WeaponResource) -> int:
	for index : int in inventory.size():
		if inventory[index].name == weapon.name:
			return index
	
	return -1



func add_ammo(index : int, weapon : WeaponResource) -> bool:
	# Check if the weapon allows the player to get the ammo
	if not weapon.pickable_ground_ammo:                                         # NOTE: This could be checked early, but I guess that placing it here makes it easy to maintain for now
		return false
	
	var player_weapon : WeaponResource = inventory[index]
	
	# HAS SPACE
	if player_weapon.on_reserve_ammo < player_weapon.max_on_reserve_ammo:       
		var ammo_to_add : int = weapon.on_mag_ammo + weapon.on_reserve_ammo
		player_weapon.on_reserve_ammo = clampi(player_weapon.on_reserve_ammo + ammo_to_add, 0, player_weapon.max_on_reserve_ammo)
		return true
	
	# IS FULL
	return false



func primary_shoot(weapon : WeaponResource) -> void:
	weapon.on_mag_ammo -= weapon.ammo_cost
	fire_cooldown = 1.0 / weapon.fire_rate                                      # Cooldown reset
	
	weapon_anims[active_index].stop()
	weapon_anims[active_index].play("pistol_shoot")
	hands_animation.stop()
	hands_animation.play("fp_pistol_shoot")
	
	weapon_effects[active_index].play()
	
	execute_ballistics(weapon)

func secondary_shoot() -> void:
	pass

func execute_ballistics(weapon : WeaponResource) -> void:
	var raycast : RayCast3D = player.aim_raycast
	raycast.force_raycast_update()
	
	var target_point : Vector3
	var distance     : float
	
	if raycast.is_colliding():
		target_point = raycast.get_collision_point()
		distance = raycast.global_position.distance_to(target_point)
		var hitted_object :  = raycast.get_collider()
		
		# HITSCAN
		if distance <= weapon.hybrid_ballistics_distance:
			if hitted_object.has_method("take_damage"):
				hitted_object.take_damage(weapon.damage)
			if hitted_object.has_method("take_impact"):
				var hit_direction : Vector3 = (target_point - raycast.global_position).normalized()
				hitted_object.take_impact(target_point, hit_direction, weapon.impact_force)
			# TODO: Spawn a Hitscan bullet hole decal/spark at 'target_point'
			return
		# PROJECTILE
		else:
			return # Spawn projectile
	
	if not raycast.is_colliding():
		# Calculate a point 1000 meters forward in the exact center of the screen
		target_point = raycast.global_position + (raycast.global_transform.basis.z * -1000.0)
	
	# TODO: Instantiate weapon.shooting_effect (Projectile) here. 
	# Place it at the gun's barrel position, and use `look_at(target_point)` to angle it correctly!


func process_weapons(delta: float) -> void:
	handle_shoot(delta)




func handle_shoot(delta: float) -> void:
	if fire_cooldown > 0.0: fire_cooldown -= delta                              # Fire cooldown delta handling
	if inventory.size() <= 0.0: return
	
	var weapon    : WeaponResource = inventory[active_index]
	var try_shoot : bool = false
	
	match weapon.fire_mode:
		weapon.FIRE_MODE.SEMI_AUTOMATIC:
			try_shoot = player.input.primary_shoot_pressed
		weapon.FIRE_MODE.AUTOMATIC:
			try_shoot = player.input.primary_shoot_held
	
	if try_shoot and fire_cooldown <= 0.0:
		if weapon.on_mag_ammo >= weapon.ammo_cost:
			primary_shoot(weapon)
		else:
			# TODO: Play an empty "Click" sound here and a animation
			pass


func match_animation(weapon :WeaponResource) -> void:
	pass

func play_shoot_animation(weapon : WeaponResource) -> void:
	pass

func play_shoot_last_animation(weapon : WeaponResource) -> void:
	pass

func play_shoot_empty_animation(weapon : WeaponResource) -> void:
	pass

func play_reload_animation(weapon : WeaponResource) -> void:
	pass

func play_equip_animation(weapon : WeaponResource) -> void:
	pass

func play_unequip_animation(weapon : WeaponResource) -> void:
	pass

func play_empty_reload_animation(weapon : WeaponResource) -> void:
	pass

func play_idle_animation(weapon : WeaponResource) -> void:
	pass
