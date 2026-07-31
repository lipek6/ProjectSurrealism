class_name AirCrouchState extends AirState
## [color=pink]Air Crouch State.[/color]
## Retracts the legs for extra jump clearance (Crouch-Jumping).

func enter() -> void:
	super.enter()
	actor.crouch_midair()
	
func exit() -> void:
	super.exit()
	actor.uncrouch_midair()

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	
	if not input.wants_crouch:
		if actor.velocity.y > 0:
			state_machine.transition_to(&"JumpState")
		else:
			state_machine.transition_to(&"FallState")
		return
		
	if actor.is_on_floor():
		state_machine.transition_to(&"CrouchState")
		return
