class_name NoClipState extends MovementState
## [color=red]NoClip State.[/color]
## Disables the collision capsule and allows unhindered 3D flight.

func enter() -> void:
	# Disable collisions safely
	actor.collision_shape.set_deferred("disabled", true)

func exit() -> void:
	# Re-enable collisions safely
	actor.collision_shape.set_deferred("disabled", false)

func physics_update(delta: float) -> void:
	# FSM Transition: If toggled off, drop out of the sky
	if not input.is_noclipping:
		# Always transition to AirState from NoClip, never Idle. 
		# If you are 100 meters up, you need gravity to take over
		state_machine.transition_to(&"AirState")
		return
		
	# Calculate Speed
	var base_speed  : float = stats.sprint_speed if input.wants_sprint else stats.walk_speed
	var final_speed : float = base_speed * stats.noclip_speed_multiplier
	
	# Apply flying velocity directly
	actor.velocity = input.camera_aligned_wished_direction * final_speed
	actor.move_and_slide()
