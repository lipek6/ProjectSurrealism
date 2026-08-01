class_name SprintState extends GroundState

func enter() -> void:
	super.enter()

func exit() -> void:
	super.exit()

func physics_update(delta: float) -> void:
	# Horizontal Transitions
	if not input.is_moving:
		state_machine.transition_to(&"IdleState")
		return
		
	if input.wants_crouch:
		state_machine.transition_to(&"CrouchState")
		return
		
	if not input.wants_sprint:
		state_machine.transition_to(&"WalkState")
		return
	
	super.physics_update(delta)

func get_state_speed() -> float:
	return actor.movement_stats.sprint_speed
