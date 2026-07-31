class_name NoClipState extends State

func enter() -> void:
	actor.collision_shape.set_deferred("disabled", true)

func exit() -> void:
	actor.collision_shape.set_deferred("disabled", false)


func physics_update(delta: float) -> void:
	
	if not input.is_noclipping:
		state_machine.transition_to(&"IdleState")
	
	actor.velocity = input.camera_aligned_wished_direction * stats.walk_speed
	actor.move_and_slide()
