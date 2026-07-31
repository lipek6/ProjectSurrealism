class_name AirState extends State
## [color=cyan]Base Air Movement State.[/color]
## Handles universal airborne physics: Gravity, air-strafing, and wall-surfing checks.

func physics_update(delta: float) -> void:
	if input.is_noclipping:
		state_machine.transition_to("NoClipState")
		return
	
	# Universal Air Physics
	var physics : PhysicsInteractor = actor.physics_interactor
	_handle_air_physics(delta)                                                  
	
	# Execute Movement
	var pre_slide_velocity : Vector3 = actor.velocity                          
	actor.move_and_slide()
	physics.push_away_rigid_bodies(pre_slide_velocity)

	# Universal Air Transitions
	if input.wants_crouch: # Should go before checking SurfState, since surf state would make this be ignored
		state_machine.transition_to(&"AirCrouchState")
		return
	
	if actor.is_on_wall() and is_surface_too_steep(actor.get_wall_normal()):
		state_machine.transition_to(&"SurfState")
		return
	

func _handle_air_physics(delta: float) -> void:
	actor.velocity.y += actor.get_gravity().y * delta                                   
	
	var current_speed_in_wished_direction : float = actor.velocity.dot(input.flat_camera_aligned_wished_direction)
	var capped_speed : float = minf((stats.air_move_speed * input.flat_camera_aligned_wished_direction).length(), stats.air_cap)
	var add_speed_till_cap : float = capped_speed - current_speed_in_wished_direction
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = stats.air_accel * stats.air_move_speed * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		actor.velocity += accelerated_speed * input.flat_camera_aligned_wished_direction

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > actor.floor_max_angle
