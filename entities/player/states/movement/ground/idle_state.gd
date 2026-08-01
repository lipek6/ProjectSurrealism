class_name IdleState extends GroundState

func physics_update(delta: float) -> void:
	# Horizontal Transitions
	if input.is_moving:
		state_machine.transition_to(&"WalkState")
		return
	
	if input.wants_crouch:
		state_machine.transition_to(&"CrouchState")
		return

	# Execute Universal Ground Physics
	super.physics_update(delta)


func get_state_speed() -> float:
	return 0.0
