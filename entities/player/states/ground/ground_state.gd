class_name GroundState extends State
## [color=cyan]Base Ground Movement State.[/color]
## Acts as the parent class for Idle, Walk, and Sprint. 
## Handles universal ground physics like Quake-style friction, stair-stepping, and jumping.
## [br]
## [b]Note:[/b] This class expects its children to override the [code]get_state_speed()[/code] function.



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
var _snapped_to_stairs_last_frame: bool = false

# ==============================================================================
# CORE EXECUTION
# ==============================================================================
func physics_update(delta: float) -> void:
	# UNIVERSAL GROUND TRANSITIONS: Check for no_clip input
	if input.is_noclipping:
		state_machine.transition_to("NoClipState")
		return
	
	
	# UNIVERSAL GROUND TRANSITIONS: Check for jumps
	if input.wants_jump:
		actor.velocity.y = stats.jump_velocity
		_snapped_to_stairs_last_frame = false                                   # Jumping intentionally breaks stair logic 
		state_machine.transition_to(&"JumpState")
		return                                                                  # CRITICAL: Stop executing ground physics. All transition_to() calls shall be immediately proceeded by a return (for now there is no exception to it).
	
	if not actor.is_on_floor() and not _snapped_to_stairs_last_frame:
		state_machine.transition_to(&"FallState")
		return
	
	
	# Apply acceleration and friction using the child's target speed
	_handle_ground_physics(delta)                                               
	
	# Movement and Stair Snapping
	if not _snap_up_stairs_check(delta):                                        # We shall not call move_and_slide when snapping up stairs (TODO: Check if this messes up with pushing objects up stairs)
		var pre_slide_velocity : Vector3 = actor.velocity                      # Needs to be registered in order to push away rigid bodies after move_and_slide. move_and_slide zeros out the velocity.  
		actor.move_and_slide()
		actor.physics_interactor.push_away_rigid_bodies(pre_slide_velocity)
		_snap_down_to_stairs_check()


# ==============================================================================
# VIRTUAL FUNCTIONS
# ==============================================================================

## [color=yellow]Virtual Function:[/color] Must be overridden by child states (Idle, Walk, Sprint) 
## to provide the correct target speed for the current frame.
func get_state_speed() -> float:
	push_warning("get_state_speed() was called on the base GroundState! A child state forgot to override it.")
	return 0.0

# ==============================================================================
# PHYSICS MATH
# ==============================================================================

func _handle_ground_physics(delta: float) -> void:
	# Quake-style dot product projection to calculate acceleration room
	var current_speed_in_wished_direction: float = actor.velocity.dot(input.flat_camera_aligned_wished_direction)
	var add_speed_till_cap: float = get_state_speed() - current_speed_in_wished_direction  
	
	if add_speed_till_cap > 0:
		var accelerated_speed: float = stats.ground_accel * get_state_speed() * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		actor.velocity += accelerated_speed * input.flat_camera_aligned_wished_direction
	
	# Apply friction
	var control  : float = max(actor.velocity.length(), stats.ground_decel)
	var drop     : float = control * stats.ground_friction * delta
	var new_speed: float = max(actor.velocity.length() - drop, 0.0)
	
	if actor.velocity.length() > 0:
		new_speed /= actor.velocity.length()                                   # new_speed is now the ratio new_speed/old_speed
	actor.velocity *= new_speed

# ==============================================================================
# STAIR HANDLERS
# ==============================================================================
#region Stair Handlers

func _snap_down_to_stairs_check() -> void:
	var did_snap                : bool  = false
	var floor_below             : bool  = actor.stairs_below_ray.is_colliding() and not is_surface_too_steep(actor.stairs_below_ray.get_collision_normal())
	
	# We request physics frames from Engine directly
	# NOTE: This relies on the _last_frame_was_on_floor tracking done in actor.gd manager
	var was_on_floor_last_frame : float = Engine.get_physics_frames() - actor._last_frame_was_on_floor == 1
	
	if not actor.is_on_floor() and actor.velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result : PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
		
		if _run_body_test_motion(actor.global_transform, Vector3(0, -actor.movement_stats.max_step_height, 0), body_test_result):
			# Decoupled Camera Call
			if actor.camera_controller:
				actor.camera_controller._save_camera_position_for_smoothing()
				
			var translate_y : float = body_test_result.get_travel().y
			actor.position.y += translate_y
			actor.apply_floor_snap()
			did_snap = true
			
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta : float) -> bool:
	if not actor.is_on_floor() and not _snapped_to_stairs_last_frame: return false
	if actor.velocity.y > 0 or (actor.velocity * Vector3(1,0,1)).length() == 0: return false
	
	var expected_move_motion : Vector3= actor.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance : Transform3D = actor.global_transform.translated(expected_move_motion + Vector3(0, stats.max_step_height * 2, 0))
	var down_check_result : KinematicCollision3D = KinematicCollision3D.new()
	
	if (actor.test_move(step_pos_with_clearance, Vector3(0, -stats.max_step_height * 2, 0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		
		var step_height : float = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - actor.global_position).y
		
		# Prevent snapping up walls or tiny bumps
		if step_height > stats.max_step_height or step_height <= 0.01 or (down_check_result.get_position() - actor.global_position).y > stats.max_step_height: 
			return false
			
		actor.stairs_ahead_ray.global_position = down_check_result.get_position() + Vector3(0, stats.max_step_height, 0) + expected_move_motion.normalized() * 0.1
		actor.stairs_ahead_ray.force_raycast_update()
		
		if actor.stairs_ahead_ray.is_colliding() and not is_surface_too_steep(actor.stairs_ahead_ray.get_collision_normal()):
			# Decoupled Camera Call
			if actor.camera_controller:
				actor.camera_controller._save_camera_position_for_smoothing()
				
			actor.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			actor.apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
		
	return false

#endregion

# ==============================================================================
# UTILITIES
# ==============================================================================

func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > actor.floor_max_angle

## [color=gray]Helper:[/color] Engine-level sweep test for step collision detection. [br]
## Checks if we are going to collide with the next step
func _run_body_test_motion(from : Transform3D, motion : Vector3, result : PhysicsTestMotionResult3D = null) -> bool:
	if not result:
		result = PhysicsTestMotionResult3D.new()
	var parameters : PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	return PhysicsServer3D.body_test_motion(actor.get_rid(), parameters, result)
