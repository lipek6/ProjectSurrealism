class_name SurfState extends AirState

## [color=yellow]Surf State.[/color]
## Deflects velocity against steep normals to allow Source-Engine sliding.

func physics_update(delta: float) -> void:
	super.physics_update(delta)
	
	if actor.get_slide_collision_count() > 0:
		var normal : Vector3 = actor.get_wall_normal()
		if is_surface_too_steep(normal):
			clip_velocity(normal, 1.0)
		else:
			# We hit a flat ground while surfing, drop out
			state_machine.transition_to(&"FallState")
			return
			
	if actor.is_on_floor(): # Add other states routing
		state_machine.transition_to(&"IdleState")
		return

func clip_velocity(normal : Vector3, overbounce : float) -> void:
	var backoff : float = actor.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change : Vector3 = normal * backoff
	actor.velocity -= change
	
	var adjust : float = actor.velocity.dot(normal)
	if adjust < 0.0:
		actor.velocity -= normal * adjust
