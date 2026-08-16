## ARMED HSM (WEAPON MANAGER)
extends LimboHSM

var manager: WeaponManager
var input  : ActorInput

## Called once, when state is initialized.
func _setup() -> void:
	manager = agent as WeaponManager
	input   = manager.actor.input as ActorInput

## Called each frame when this state is active.
var old_name: StringName = &""
func _update(delta: float) -> void:
	# Global Swapping
	var target_slot: int = input.wanted_slot # -1 if no swap requested via number keys
	if input.wants_next_slot:
		target_slot = posmod(manager.active_slot_idx + 1, manager.inventory_max_size)
	elif input.wants_prev_slot:
		target_slot = posmod(manager.active_slot_idx - 1, manager.inventory_max_size)
	
	if target_slot !=- 1 and target_slot < manager.inventory.size() and manager.inventory[target_slot] != null and target_slot != manager.active_slot_idx:
		# Updates blackboard
		blackboard.set_var(&"pending_swap_slot", target_slot)
		# Move to the SwapState
		dispatch(WeaponManagerHSM.EVENT_SWAP_REQ)
		
	if self.get_active_state().name != old_name:
		print("ArmedHSM -> " + self.get_active_state().name)
		old_name = self.get_active_state().name
