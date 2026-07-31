class_name CrouchState extends GroundState
## [color=pink]Crouch State.[/color]
## Lowers the collision capsule and modifies speed.
## [br][b]NOTE:[/b] Currently coupled to the actor's collision shape. In a true decoupled 
## system, the actor would have an [code]actor.crouch()[/code] function so the state doesn't manipulate heights directly.

func enter() -> void:
	super.enter()
	actor.crouch()

func exit() -> void:
	super.exit()
	actor.uncrouch()


func physics_update(delta: float) -> void:
	super.physics_update(delta)
	
	# Transition logic
	if _can_exit_crouch() and not input.wants_crouch:
		if not input.is_moving:
			state_machine.transition_to(&"IdleState")
		elif input.wants_sprint:
			state_machine.transition_to(&"SprintState")
		else:
			state_machine.transition_to(&"WalkState")
		return

func get_state_speed() -> float:
	if input.wants_sprint:
		return stats.sprint_speed * stats.crouch_speed_multiplier  
	else:
		return stats.walk_speed  * stats.crouch_speed_multiplier

func _can_exit_crouch() -> bool:
	return not actor.test_move(actor.transform, Vector3(0.0, stats.crouch_translate, 0.0))
