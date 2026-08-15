## PRIMARY ACTION STATE
extends LimboState

var weapon: WeaponInstance
var animation: AnimationPlayer

## Called once, when state is initialized.
func _setup() -> void:
	weapon = agent as WeaponInstance
	animation = weapon.animation


func _update(delta: float) -> void:
	if weapon.current_primary_mag_ammo > 0:
		weapon.current_primary_mag_ammo -= weapon.data.primary_ammo_cost
		
		if animation:
			if weapon.current_primary_mag_ammo <= 0:
				animation.stop()
				animation.play(weapon.anim_primary_shoot)
			else:
				animation.stop()
				animation.play(weapon.anim_primary_shoot_last) 
		
		var anim_length: float = animation.get_animation(weapon.anim_primary_shoot).length
		weapon.request_actor_animation.emit(&"Shoot", true, anim_length, weapon)
		
		# Move to cooldown
		dispatch(EVENT_FINISHED)
	else:
		
		dispatch(EVENT_FINISHED)
