class_name PhysicsInteractor extends Node 
# ==============================================================================
# COMPONENT: PHYSICS INTERACTOR
## Responsibilities: Handles all Kinematic-to-Dynamic physics interactions.
## This includes momentum conservation when pushing RigidBodies, the dynamic flat-feet 
## glitch fix, and applying artificial gravity to props for edge-teetering.
# ==============================================================================
# TODO: Change the @onready vars to @export so we can reuse this code in other entities



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Enums & States
var _current_floor_prop : Node3D = null                                         ## Tracks the physics object we are currently standing on
#endregion


#region Node References
@onready var player                   : CharacterBody3D          = get_parent()
@onready var movement_controller      : PlayerMovementController = %MovementController
@onready var collision_feet_for_props : CollisionShape3D         = %CollisionFeetForProps
@onready var stairs_below_ray         : RayCast3D                = %StairsBelowRayCast3D
#endregion


#region Exported Parameters
@export_group("Physics Interaction")
@export var apply_impulse_at_center : bool = false                              ## [color=cyan]Push mechanics mode.[/color] [br]If true, pushes props from their center of mass (avoids wild spinning). If false, applies force at the exact knee/foot contact point.
#endregion



# ==============================================================================
# METHODS
# ==============================================================================
#region Core Execution
## Analyzes the environment and injects forces into dynamic physics objects
func process_physics() -> void:
	_update_floor_prop_notification()
	_apply_weight_to_floor_prop()
#endregion


#region Prop Riding
func _apply_weight_to_floor_prop() -> void:
	if _current_floor_prop is PhysicsProp and player.is_on_floor():
		var downward_force : Vector3 = player.get_gravity() * player.weight
		if stairs_below_ray.is_colliding():
			var collision_point : Vector3 = stairs_below_ray.get_collision_point()
			_current_floor_prop.apply_resting_weight(downward_force, collision_point)
		else:
			# Fallback: Apply weight directly under our center if the raycast missed for some reason.
			_current_floor_prop.apply_resting_weight(downward_force, player.global_position)


## Checks what the player is standing on and notifies the object so it can stabilize itself.
func _update_floor_prop_notification() -> void:
	var detected_floor_prop : Node3D = null
	if player.is_on_floor():
		stairs_below_ray.force_raycast_update()                                 # get_slide_collision often misses the floor when moving perfectly parallel to it.
		if stairs_below_ray.is_colliding():
			detected_floor_prop = stairs_below_ray.get_collider()
		else:                                                                   # FALLBACK CHECK: Slide Collisions
			for i : int in player.get_slide_collision_count():
				var collision : KinematicCollision3D = player.get_slide_collision(i)
				if not movement_controller.is_surface_too_steep(collision.get_normal()):
					detected_floor_prop = collision.get_collider()
					break
			
	# NOTIFY PHYSICS PROPS
	if detected_floor_prop != null:
		if detected_floor_prop != _current_floor_prop:
			if _current_floor_prop is PhysicsProp:                              
				_current_floor_prop.notify_stepped_off(player)
			if detected_floor_prop is PhysicsProp:                              
				detected_floor_prop.notify_stepped_on(player)
			_current_floor_prop = detected_floor_prop


## Dynamically activates flat feet to prevent the capsule curve from shooting out props (called by the PhysicsProp)
func activate_collision_feet_for_props() -> void:
	collision_feet_for_props.set_deferred("disabled", false)


## Dynamically restores the standard round capsule bottom for smooth stairs/slope movement (called by the PhysicsProp)
func deactivate_collision_feet_for_props() -> void:
	collision_feet_for_props.set_deferred("disabled", true)
#endregion


#region Momentum Conservation
## Calculates mass ratios and momentum transfer to realistically push dynamic bodies.
func push_away_rigid_bodies(pre_slide_velocity : Vector3) -> void:
	for i : int in player.get_slide_collision_count():
		var collision : KinematicCollision3D = player.get_slide_collision(i)
		var collider  : RigidBody3D = collision.get_collider() if collision.get_collider() is RigidBody3D else null
		
		if collider == null: continue
		
		# FLOOR GUARD
		if collider == _current_floor_prop: continue                                                
		
		# DIRECTIONAL CALCULATION
		var push_direction : Vector3 = -collision.get_normal()
		push_direction.y = 0.0                                                                      # Zero out Y, because pushing objects downward into the floor causes physics glitches.
		
		# SAFE NORMALIZATION
		if push_direction.length_squared() < 0.001: continue                                        
		push_direction = push_direction.normalized()
		
		# VELOCITY DIFFERENTIAL 
		var player_velocity_into_object : float = pre_slide_velocity.dot(push_direction)
		var object_velocity_into_player : float = collider.linear_velocity.dot(push_direction)      
		var velocity_difference : float = player_velocity_into_object - object_velocity_into_player
		if velocity_difference <= 0.0: continue                                                     
		
		# MOMENTUM CONSERVATION
		var required_impuse : float = collider.mass * velocity_difference
		var max_push_impulse: float = player.weight * 2.0                                           # TODO: Magic number that defines our force
		var applied_impulse : float = min(required_impuse, max_push_impulse)                        
		
		var push_force : Vector3 = push_direction * applied_impulse
		
		if apply_impulse_at_center:
			collider.apply_central_impulse(push_force)
		else:
			collider.apply_impulse(push_force, collision.get_position() - collider.global_position)
#endregion


#region Pick-up

#endregion
