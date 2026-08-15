extends LimboState
## UNARMED STATE (WEAPON MANAGER)

var manager: WeaponManager
var input  : ActorInput

## Called once, when state is initialized.
func _setup() -> void:
	manager = agent as WeaponManager
	input   = manager.actor.input
