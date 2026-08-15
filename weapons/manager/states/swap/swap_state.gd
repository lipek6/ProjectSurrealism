## SWAP STATE (WEAPON MANAGER)
extends LimboState

var manager: WeaponManager

func _setup() -> void:
	manager = agent as WeaponManager

func _enter() -> void:
	var target_slot: int = blackboard.get_var(&"pending_swap_slot", -1) as int
	blackboard.set_var(&"pending_swap_slot", -1)
	
	if target_slot != -1 and target_slot < manager.inventory.size() and manager.inventory[target_slot] != null:
		# Put away old weapon
		if manager.active_primary_weapon:
			manager.active_primary_weapon.hide()
			manager.active_primary_weapon.hsm.set_active(false)
			manager.active_primary_weapon.reparent(manager)
			
		# Update Manager Pointers
		manager.active_primary_weapon = manager.inventory[target_slot]
		manager.active_slot_idx = target_slot
		
		# Mount the new weapon
		if manager.primary_attachment:
			manager.active_primary_weapon.reparent(manager.primary_attachment)
		else:
			push_error("WeaponManager is missing primary_attachment BoneAttachment3D!")
		
		# ------------------------------------------------------------------------------------------
		# CORRECTING POSITION (CRITICAL: THIS NEEDS TO BE DONE IN ORDER TO PROPERLY SEE THE WEAPON AND NEEDS TO BE DONE EXACTLY HERE!!!!!!!!!!!!!!!!)
		manager.active_primary_weapon.position = manager.active_primary_weapon.data.placement_fix.primary_pos
		manager.active_primary_weapon.rotation = manager.active_primary_weapon.data.placement_fix.primary_rot
		manager.active_primary_weapon.scale    = manager.active_primary_weapon.data.placement_fix.primary_scl
		# ------------------------------------------------------------------------------------------
		
		manager.active_primary_weapon.show()
		manager.active_primary_weapon.hsm.set_active(true)
		
		# Tell the Root HSM we are done!
		call_deferred("dispatch", WeaponManagerHSM.EVENT_EQUIP_FIN)
	else:
		# UNEQUIP LOGIC (e.g. Dropping the only weapon)
		if manager.active_primary_weapon:
			manager.active_primary_weapon.hide()
			manager.active_primary_weapon.hsm.set_active(false)
			manager.active_primary_weapon.reparent(manager)
			manager.active_primary_weapon = null
			# TODO: Add a _disconnect_signals() function to be called here.
		call_deferred("dispatch", WeaponManagerHSM.EVENT_UNEQUIP_FIN)
