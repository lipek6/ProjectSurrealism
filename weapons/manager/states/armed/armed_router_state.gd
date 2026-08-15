## ARMED ROUTER STATE (WEAPON MANAGER)
extends LimboState

var manager: WeaponManager
var input  : ActorInput

## Called once, when state is initialized.
func _setup() -> void:
	manager = agent as WeaponManager
	input   = manager.actor.input as ActorInput


## Called when state is entered.
func _enter() -> void:
	# Determine which child state to drop into (active weapons are set up at the SwapState/).
	if manager.active_primary_weapon:
		if manager.active_secondary_weapon:
			call_deferred("dispatch", WeaponManagerHSM.EVENT_DUAL_EQ) # NOTE: There is no situation where there is a secondary weapon without a primary one.
		else:
			call_deferred("dispatch", WeaponManagerHSM.EVENT_SINGLE_EQ)
	else:
		push_error("WARNING: No active_primary_weapon found, but WeaponManagerHSM is at the ArmedState")
		call_deferred("dispatch", WeaponManagerHSM.EVENT_SWAP_REQ) # Go back if somehow we don't have any weapons and got here.
