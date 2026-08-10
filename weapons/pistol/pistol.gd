class_name Pistol extends WeaponInstance

# ==============================================================================
# OVERRIDES
# ==============================================================================
func pull_primary_trigger() -> void:
	# If semi-auto, refuse to fire if the trigger was already held down.
	if data.fire_mode == WeaponResource.FIRE_MODE.SEMI_AUTOMATIC and primary_trigger_held:
		return
	
	# Mark the trigger as mechanically squeezed for future frames
	primary_trigger_held = true
	
	# Check Cooldown fire-rate
	if current_fire_cooldown > 0.0:
		return
	
	if current_mag_ammo > 0:
		current_mag_ammo -= data.ammo_cost 
		current_fire_cooldown = 1.0 / data.fire_rate
		
		primary_fired.emit()
		ammo_updated.emit(current_mag_ammo, current_reserve_ammo)
		
		if current_mag_ammo <= 0:
			animation.stop()
			animation.play("pistol_shoot_last")
		else:
			animation.stop()
			animation.play("pistol_shoot")
			audio.stream = data.shoot_sound
			audio.pitch_scale = clampf(randf(), 1.0, 4.0)
			audio.play()
	else:
		audio.stop()
		audio.stream = data.dry_shoot_sound
		audio.play()
		current_fire_cooldown = 1.0 / data.fire_rate # If we don't, holding full-auto on an empty mag will emit 60 "action_denied" signals per second
		action_denied.emit(DENIAL_REASON.OUT_OF_AMMO)


func release_primary_trigger() -> void:
	primary_trigger_held = false
	primary_released.emit()


func pull_secondary_trigger() -> void:
	pass # Optional to override


func release_secondary_trigger() -> void:
	pass # Optional to override


func reload() -> void:
	# FULL MAG -> NO RELOAD NEEDED
	if current_mag_ammo == data.max_mag_ammo:
		action_denied.emit(DENIAL_REASON.MAG_FULL)
		return
	
	# NO RESERVE AMMO -> NO RELOAD NEEDED
	if current_reserve_ammo <= 0:
		action_denied.emit(DENIAL_REASON.NO_RESERVE)
		return
	
	# IMPORTANT: We must check if the mag is empty BEFORE we do the math!
	var is_empty_reload : bool = (current_mag_ammo <= 0)
	
	# Math execution
	if current_reserve_ammo > (data.max_mag_ammo - current_mag_ammo):
		current_reserve_ammo -= (data.max_mag_ammo - current_mag_ammo)
		current_mag_ammo = data.max_mag_ammo
	else:
		current_mag_ammo += current_reserve_ammo
		current_reserve_ammo = 0
		
	# Broadcast the reload start state (using the boolean we safely cached above)
	if is_empty_reload:
		animation.play("pistol_reload_empty")
		reload_started.emit(85.0, true)
	else: 
		animation.play("pistol_reload")
		reload_started.emit(70.0, false)
		
	# Update the UI to reflect the newly calculated ammo pools
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)


func equip() -> void:
	super.equip() # Calls the base class to emit the ammo_updated signal!
	
	if animation:
		animation.play(&"pistol_equip")
		audio.stop()
		audio.stream = data.equip_sound
		audio.play()


func unequip() -> void:
	if animation:
		animation.play(&"pistol_unequip")
		#audio.stop()
		#audio.stream = data.unequip_sound
		#audio.play()
