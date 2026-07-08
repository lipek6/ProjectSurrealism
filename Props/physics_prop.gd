@tool
class_name PhysicsProp extends RigidBody3D
# NOTICE: TWEAK THE self.linear_damp and self.angular_damp until we find reasonable values.
# The idea is find something that gets really close to a half life 2 crate.
# TWEAK everything!! It's hard to get a perfect code for these props, so to achieve the intended 
# effect, tweak evetything in the editor!


# ==========================================
# EXPORTED NODE REFERENCES
# ==========================================
#region Node References
@export_group("Internal Nodes")
@export var model      : Node3D
@export var collision  : CollisionShape3D
#endregion



# ==========================================
# PROP SETTINGS
# ==========================================
#region Prop Configuration
# TODO: Is there any way to make it clearer and easier to tweak these values? Maybe use an ENUM with the states for lock_rotation_when_stood_on or use the damping, and them show some options that only work for certain modes? Yeah, I think we can do it with the @tool things 
@export_group("Prop Settings")
@export var lock_rotation_when_stood_on : bool = true                           ## If true, the prop becomes a perfectly stable platform. If false, it just becomes "heavy" (dampened) when stood upon.
@export var always_lock_y_axis          : bool = false                          ## When stood upon, if using "lock_rotation_when_stood_on", will always lock all the 3 axis, no matter the weight of the character on top.
@export var lock_y_axis_on_overweight   : bool = true
@export var on_top_angular_damp : float = 50.0
@export var on_top_linear_damp  : float = 10.0
@export var prop_scale   : Vector3 = Vector3.ONE:                               ## Safely scales the visual mesh and colliders without breaking RigidBody3D physics calculations.
	set(value):
		prop_scale = value
		_update_scale()
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
	_update_scale()
	if Engine.is_editor_hint(): return                                          # EDITOR GUARD 
	
	# Apply Safe Scaling (NOTICE: We scale the children instead of the RigidBody3D itself to avoid physics engine glitches)
	if model:      
		model.scale = prop_scale
		## Should I force it to be on the layer 4 "Physics props Layer"?
		#for child : VisualInstance3D in model.get_children():
			#child.set_layer_mask_value()
		
	if collision:  collision.scale = prop_scale



## Applies the scale to the children nodes safely.
func _update_scale() -> void:
	if model:      model.scale      = prop_scale
	if collision:  collision.scale  = prop_scale
#endregion



# ==========================================
# INTERACTION HANDLERS
# ==========================================
#region Interaction Logic
## Called by the Player script when it detects it is standing on this prop.
func notify_stepped_on(body : Node3D) -> void:
	if not body.is_in_group("Entity"): return                                   # Only react to valid entities (Player, NPCs, etc)
	
	bodies_on_top += 1
	
	if bodies_on_top > 0:
		if lock_rotation_when_stood_on:                                         # Platformer Approach (Easier to be on top)
			self.axis_lock_angular_x = true
			self.axis_lock_angular_z = true
			
			var body_weight : float = body.get("weight") if body.get("weight") != null else 0.0
			if (self.mass > body_weight and lock_y_axis_on_overweight) or always_lock_y_axis: self.axis_lock_angular_y = true         
		else:                                                                   # Dampening Approach: Make the box incredibly sluggish to rotate
			self.angular_damp = on_top_angular_damp
			self.linear_damp  = on_top_linear_damp


## Called by the Player script when it stops standing on this prop.
func notify_stepped_off(body : Node3D) -> void:
	if not body.is_in_group("Entity"): return
	bodies_on_top = max(0, bodies_on_top - 1) 
	
	if bodies_on_top == 0:
		if lock_rotation_when_stood_on:                                         # Platformer Approach (Easier to be on top)
			self.axis_lock_angular_x = false
			self.axis_lock_angular_z = false

			var body_weight : float = body.get("weight") if body.get("weight") != null else 0.0
			if self.mass > body_weight:
				self.axis_lock_angular_y = false
				
		else:                                                                   # Dampening Approach: Make the box incredibly sluggish to rotate
			self.angular_damp = _original_angular_damp
			self.linear_damp  = _original_linear_damp
#endregion
