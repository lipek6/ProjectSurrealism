## DUAL WIELD STATE (WEAPON MANAGER)
extends LimboState

var manager: WeaponManager
var input  : ActorInput

## Called once, when state is initialized.
func _setup() -> void:
	manager = agent as WeaponManager
	input   = manager.actor.input as ActorInput

func _exit() -> void:
	pass # DROP


## Called each frame when this state is active.
func _update(delta: float) -> void:
	manager.active_primary_weapon.wants_primary_shoot   = input.wants_primary_shoot
	manager.active_secondary_weapon.wants_primary_shoot = input.wants_secondary_shoot
	
	manager.active_primary_weapon.wants_reload          = input.wants_reload
	manager.active_secondary_weapon.wants_reload        = input.wants_reload
	
	manager.active_primary_weapon.wants_shoot           = input.wants_primary_shoot
	manager.active_secondary_weapon.wants_shoot         = input.wants_secondary_shoot

	manager.active_secondary_weapon.wants_unequip       = input.wanted_slot != -1 or input.wants_next_slot or input.wants_prev_slot
