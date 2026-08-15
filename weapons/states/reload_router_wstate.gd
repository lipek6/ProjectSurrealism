## RELOAD ROUTER STATE
extends LimboState

var weapon: WeaponInstance
var parent_hsm: WeaponHSM

func _setup() -> void:
	weapon = agent as WeaponInstance
	# Grab the root HSM so we can access those routing constants
	parent_hsm = weapon.hsm

func _update(_delta: float) -> void:
	# Prioritize Primary Reload
	if weapon.current_primary_mag_ammo < weapon.data.primary_max_mag_ammo and weapon.current_primary_reserve_ammo > 0:
		dispatch(parent_hsm.ROUTE_PRIMARY_RELOAD)
		return
		
	# Fallback to Secondary Reload
	if weapon.current_secondary_mag_ammo < weapon.data.secondary_max_mag_ammo and weapon.current_secondary_reserve_ammo > 0:
		dispatch(parent_hsm.ROUTE_SECONDARY_RELOAD)
		return
		
	# If neither needed a reload (or we have no reserve ammo), exit the HSM immediately
	dispatch(parent_hsm.EVENT_SEQ_COMPLETED)
