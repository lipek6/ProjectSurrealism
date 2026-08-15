## PRIMARY ACTION RECOVERY STATE
extends LimboState

var weapon: WeaponInstance
var cooldown_timer: float = 0.0

func _setup() -> void:
	weapon = agent as WeaponInstance

func _enter() -> void:
	if weapon.data.fire_rate > 0.0:
		cooldown_timer = 1.0 / weapon.data.fire_rate
	else:
		cooldown_timer = 0.0

func _update(delta: float) -> void:
	# Enforce Fire Rate
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		return 
		
	# Enforce Fire Mode (The Latch)
	if weapon.data.fire_mode == WeaponResource.FIRE_MODE.SEMI_AUTOMATIC:
		if weapon.wants_primary_shoot:
			return # Gun refuses to reset until the trigger is released
		
	# Sequence Complete
	# This bubbles up to the root machine, which pulls us out of ActionHSM and back to Idle.
	dispatch(WeaponHSM.EVENT_SEQ_COMPLETED)
	
