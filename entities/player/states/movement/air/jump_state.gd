class_name JumpState extends AirState
## [color=green]Jump State.[/color]
## Active while the actor's vertical velocity is moving upward.

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	
	if actor.velocity.y <= 0:
		state_machine.transition_to(&"FallState")
		return
	
	# Head-bonk check: If we hit a ceiling, immediately start falling
	if actor.is_on_ceiling():
		state_machine.transition_to(&"FallState")
		return
