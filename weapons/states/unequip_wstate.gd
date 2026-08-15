## UNEQUIP WEAPON STATE 
extends LimboState

var weapon     : WeaponInstance
var animation  : AnimationPlayer

func _setup() -> void:
	weapon     = agent as WeaponInstance
	animation  = weapon.animation as AnimationPlayer


func _enter() -> void:
	# NOTIFY ACTOR
	var anim_length: float = animation.get_animation(weapon.anim_unequip).length
	weapon.request_actor_animation.emit(&"Unequip", false, anim_length, weapon)
	
	# PLAY ITS OWN ANIMATION
	if animation and weapon.anim_unequip:
		animation.play(weapon.anim_unequip)


func _update(delta: float) -> void:
	if not animation.is_playing():
		dispatch(EVENT_FINISHED)
