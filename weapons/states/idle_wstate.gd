## IDLE WEAPON STATE 
extends LimboState

var weapon     : WeaponInstance
var animation  : AnimationPlayer

func _setup() -> void:
	weapon     = agent as WeaponInstance
	animation  = weapon.animation as AnimationPlayer


func _enter() -> void:
	# NOTIFY ACTOR
	var anim_length: float = animation.get_animation(weapon.anim_idle).length
	weapon.request_actor_animation.emit(&"Idle", false, anim_length, weapon)
	
	# PLAY ITS OWN ANIMATION
	if animation and weapon.anim_idle:
		animation.play(weapon.anim_idle)


func _update(delta: float) -> void:
	if weapon.wants_shoot:
		dispatch(WeaponHSM.EVENT_ACTION_STARTED)
	elif weapon.wants_reload:
		dispatch(WeaponHSM.EVENT_RELOAD_STARTED)
	elif weapon.wants_unequip:
		dispatch(WeaponHSM.EVENT_UNEQUIP_STARTED)
