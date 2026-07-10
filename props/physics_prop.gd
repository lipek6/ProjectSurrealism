@tool
class_name PhysicsProp extends RigidBody3D
# ==============================================================================
# PHYSICS PROP CLASS
## Provides a standardized, scalable architecture for all dynamic world objects 
## (crates, barrels, cans). Handles safe scaling, automatic mass calculation, 
## and stable player-riding mechanics without relying on fragile node structures.
#
# NOTICE: To make a great physics prop, you will need to tweak it in the editor
# until you find the neat spot for it. Don't fear messing around the values! 
# ==============================================================================

## Defines the behavioral category of this physics prop.
enum PropType {
	SMALL_DEBRIS, ## Tiny objects (bottles, mugs). Cannot be stood upon. Easily kicked around.
	INTERACTIVE,  ## Standard objects (crates, barrels). Can be stood upon. Dampens/locks rotation to stabilize the player.
	# INFO: More will be added for explosives and everything else (or maybe I should create inherited classes for those)
}



# ==========================================
# EXPORTED NODE REFERENCES
# ==========================================
#region Node References
@export_group("Internal Nodes") 
@export var model      : Node3D                                                 ## The visual 3D mesh of the object. We scale this instead of the root RigidBody to prevent engine glitches.
@export var collision  : CollisionShape3D                                       ## The physical bounds of the object. We scale this instead of the root RigidBody to prevent engine glitches.
#endregion



# ==========================================
# PROP SETTINGS
# ==========================================
#region Prop Configuration
@export_group("Prop Settings")
@export var prop_type           : PropType = PropType.INTERACTIVE               ## Categorizes how this object interacts with the world and the player.
@export var prop_scale          : Vector3  = Vector3.ONE:                       ## Safely scales the visual mesh and colliders without breaking RigidBody3D physics calculations.[br] Standard RigidBody3D nodes break if their Transform Scale is modified directly.
	set(value):
		prop_scale = value
		_update_scale_and_mass()
@export var auto_calculate_mass : bool     = true:                              ## If true, tmasshe prop's  will automatically recalculate based on its volumetric scale.
	set(value):
		auto_calculate_mass = value
		_update_scale_and_mass()
@export var base_mass           : float    = 10.0:                              ## The baseline weight of this object at a scale of (1, 1, 1). [br] If auto_calculate_mass is true, scaling the object by (2, 2, 2) will multiply this mass by 8. 
	set(value):
		base_mass = value
		_update_scale_and_mass()
#endregion



# ==========================================
# RIDING SETTINGS
# ==========================================
#region Riding Settings
@export_group("Riding Mechanics")
@export var allow_edge_teetering        : bool  = true                          ## If true, ONLY locks the Y-axis to prevent turntable spinning, allowing the box to teeter and fall off ledges (Source Engine style). [br] If false, completely locks X, Y and Z to act as an immovable perfect floating platform.
@export var damp_when_on_top            : bool  = false
@export var on_top_linear_damp          : float = 10.0                          ## The drag applied to the object's sliding movement when stood upon.[br](Common use case: Prevents the crate from acting like an ice-skate under the player's feet. Values around 10.0 are standard).
@export var on_top_angular_damp         : float = 50.0                          ## The massive drag applied to the object's rotation when stood upon.[br](Common use case: Source Engine/Half-Life 2 style interactions. Values between 30.0 and 60.0 prevent extreme tumbling while keeping physics "alive").
#endregion



# ==========================================
# STATE VARIABLES
# ==========================================
#region State
var bodies_on_top : int = 0

@onready var _original_angular_damp : float = self.angular_damp                 ## Store original dampening values so we can restore them if we use the "Damp" method instead of "Lock Rotation".
@onready var _original_linear_damp  : float = self.linear_damp                  ## Store original dampening values so we can restore them if we use the "Damp" method instead of "Lock Rotation".                 
#endregion



# ==========================================
# CORE LIFECYCLE
# ==========================================
#region Lifecycle
func _ready() -> void:
	_update_scale_and_mass()
	if Engine.is_editor_hint(): return                                          # EDITOR GUARD: Stop executing logic if we are just building the level.
	
	# Apply Safe Scaling (NOTICE: We scale the children instead of the RigidBody3D itself to avoid physics engine glitches)
	if model:      model.scale = prop_scale
	if collision:  collision.scale = prop_scale


## Safely applies scale to children and dynamically calculates real-world mass.
## WARNING: Because this is bound to the setters, it runs continuously in the Godot Editor viewport!
func _update_scale_and_mass() -> void:
	if model:      model.scale      = prop_scale
	if collision:  collision.scale  = prop_scale
	if auto_calculate_mass:
		var volume_multiplier : float = prop_scale.x * prop_scale.y * prop_scale.z
		self.mass = abs(base_mass * volume_multiplier)
#endregion



# ==========================================
# STAND ON TOP HANDLERS
# ==========================================
#region Stand On Top Logic
## Called by the Player script when it detects its floor raycast is hitting this prop.
func notify_stepped_on(body : Node3D) -> void:
	# Ignore non-entities, and completely ignore SMALL_DEBRIS (like soda cans)
	if not body.is_in_group("Entity") or prop_type == PropType.SMALL_DEBRIS: return
	
	bodies_on_top += 1
	
	if body.has_method("activate_collision_feet_for_props"):
		body.activate_collision_feet_for_props()
	
	if bodies_on_top == 1:                                                      # The moment the first entity steps onto the prop, stabilize it.
		if not allow_edge_teetering:                                         
			self.axis_lock_angular_x = true
			self.axis_lock_angular_z = true
			self.axis_lock_angular_y = true
		if damp_when_on_top:                                                                   
			self.angular_damp = on_top_angular_damp
			self.linear_damp  = on_top_linear_damp


## Called by the Player script when it stops standing on this prop.
func notify_stepped_off(body : Node3D) -> void:
	# Ignore non-entities, and completely ignore SMALL_DEBRIS (like soda cans)
	if not body.is_in_group("Entity") or prop_type == PropType.SMALL_DEBRIS: return
	# Safely decrement, clamping at 0 to prevent negative math glitches
	bodies_on_top = max(0, bodies_on_top - 1) 
	
	if body.has_method("deactivate_collision_feet_for_props"):
		body.deactivate_collision_feet_for_props()
	
	# When the last entity steps off, restore normal physics.
	if bodies_on_top == 0:
		if not allow_edge_teetering: 
			self.axis_lock_angular_x = false
			self.axis_lock_angular_z = false
			self.axis_lock_angular_y = false
		if damp_when_on_top:
			self.angular_damp = _original_angular_damp
			self.linear_damp  = _original_linear_damp

## Allows the player to inject artificial gravity into the prop, allowing it to realistically teeter off edges.[br]
## - `force`: The continuous downward Vector3 (gravity * player weight).[br]
## - `point`: The global 3D coordinate where the player's foot is touching the box.
func apply_resting_weight(force : Vector3, point: Vector3) -> void:
	apply_force(force, point - self.global_position)                            # NOTE: apply_force is a continuous, time-dependent function meant to be called every physics frame.
#endregion



# ==========================================
# PICKUP HANDLERS
# ==========================================
