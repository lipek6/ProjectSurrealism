class_name FallState extends AirState
## [color=orange]Fall State.[/color]
## Active while the actor is dropping. Handles the landing transition.

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	
	if actor.is_on_floor():
		# Route to the correct ground state upon landing
		if not input.is_moving:
			state_machine.transition_to(&"IdleState")
		elif input.wants_sprint:
			state_machine.transition_to(&"SprintState")
		else:
			state_machine.transition_to(&"WalkState")
		return
