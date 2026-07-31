class_name PhysicsInteractor extends Node 

# ==============================================================================
# COMPONENT: PHYSICS INTERACTOR
# ==============================================================================

var _current_floor_prop : Node3D = null                                         

@onready var actor                    : CharacterBody3D  = $"../.." 
@onready var collision_feet_for_props : CollisionShape3D = %CollisionFeetForProps
@onready var stairs_below_ray         : RayCast3D        = %StairsBelowRayCast3D

@export_group("Physics Interaction")
@export var apply_impulse_at_center : bool = false                              

func process_physics() -> void:
	_update_floor_prop_notification()
	_apply_weight_to_floor_prop()

func _apply_weight_to_floor_prop() -> void:
	if _current_floor_prop == null: return 
	
	if _current_floor_prop is PhysicsProp and actor.is_on_floor():
		var downward_force : Vector3 = actor.get_gravity() * actor.weight
		if stairs_below_ray.is_colliding():
			var collision_point : Vector3 = stairs_below_ray.get_collision_point()
			_current_floor_prop.apply_resting_weight(downward_force, collision_point)
		else:
			_current_floor_prop.apply_resting_weight(downward_force, actor.global_position)

func _update_floor_prop_notification() -> void:
	var detected_floor_prop : Node3D = null
	if actor.is_on_floor():
		stairs_below_ray.force_raycast_update()                                 
		if stairs_below_ray.is_colliding():
			detected_floor_prop = stairs_below_ray.get_collider()
		else:                                                                   
			for i : int in actor.get_slide_collision_count():
				var collision : KinematicCollision3D = actor.get_slide_collision(i)
				if not _is_surface_too_steep(collision.get_normal()):
					detected_floor_prop = collision.get_collider()
					break
					
	# NOTIFY PHYSICS PROPS
	if detected_floor_prop != null:
		if _current_floor_prop != null:
			if detected_floor_prop != _current_floor_prop:
				if _current_floor_prop is PhysicsProp:                               
					_current_floor_prop.notify_stepped_off(actor)
				if detected_floor_prop is PhysicsProp:                               
					detected_floor_prop.notify_stepped_on(actor)
		_current_floor_prop = detected_floor_prop

func activate_collision_feet_for_props() -> void:
	collision_feet_for_props.set_deferred("disabled", false)

func deactivate_collision_feet_for_props() -> void:
	collision_feet_for_props.set_deferred("disabled", true)

func push_away_rigid_bodies(pre_slide_velocity : Vector3) -> void:
	for i : int in actor.get_slide_collision_count():
		var collision : KinematicCollision3D = actor.get_slide_collision(i)
		var collider  : RigidBody3D = collision.get_collider() if collision.get_collider() is RigidBody3D else null
		if collider == null: continue
		if collider == _current_floor_prop: continue                                                 
		
		var push_direction : Vector3 = -collision.get_normal()
		push_direction.y = 0.0                                                                      
		if push_direction.length_squared() < 0.001: continue                                         
		push_direction = push_direction.normalized()

		var player_velocity_into_object : float = pre_slide_velocity.dot(push_direction)
		var object_velocity_into_player : float = collider.linear_velocity.dot(push_direction)       
		var velocity_difference : float = player_velocity_into_object - object_velocity_into_player
		if velocity_difference <= 0.0: continue                                                      
		
		var required_impuse : float = collider.mass * velocity_difference
		var max_push_impulse: float = actor.weight * 2.0                                           
		var applied_impulse : float = min(required_impuse, max_push_impulse)                         
		var push_force : Vector3 = push_direction * applied_impulse
		
		if apply_impulse_at_center:
			collider.apply_central_impulse(push_force)
		else:
			collider.apply_impulse(push_force, collision.get_position() - collider.global_position)

## [color=gray]Helper:[/color] Replaces the old MovementController check!
func _is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > actor.floor_max_angle
