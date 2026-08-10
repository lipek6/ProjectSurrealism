class_name ActorInput extends Node
## [color=cyan]Generic Input Provider (The Brain).[/color]
## Acts as a universal contract for FSMs and Managers.
## It is populated by either a Player's keyboard (PlayerInput) or an NPC's AI (NPCBrain).

# ==============================================================================
# VECTORS
# ==============================================================================
var flat_camera_aligned_wished_direction : Vector3 = Vector3.ZERO
var wished_direction                     : Vector3 = Vector3.ZERO
var move_direction                       : Vector2 = Vector2.ZERO

# ==============================================================================
# MOVEMENT INTENTS
# ==============================================================================
var is_moving     : bool = false
var is_noclipping : bool = false
var wants_jump    : bool = false
var wants_sprint  : bool = false
var wants_crouch  : bool = false

# ==============================================================================
# COMBAT & INTERACTION INTENTS
# ==============================================================================
var wants_primary_shoot   : bool = false
var wants_secondary_shoot : bool = false
var wants_reload          : bool = false
var wants_interact        : bool = false
var wants_dual_wield      : bool = false

# ==============================================================================
# INVENTORY INTENTS
# ==============================================================================
var wants_slot_1    : bool = false
var wants_slot_2    : bool = false
var wants_slot_3    : bool = false
var wants_slot_4    : bool = false
var wants_slot_5    : bool = false
var wants_slot_6    : bool = false
var wants_slot_7    : bool = false
var wants_slot_8    : bool = false
var wants_slot_9    : bool = false
var wants_slot_0    : bool = false
var wants_next_slot : bool = false
var wants_prev_slot : bool = false

## Virtual function to be overridden by children
func gather_inputs(_actor_basis: Basis, _camera_basis: Basis) -> void:
	pass
