## ACTION ROUTER STATE
extends LimboState

var weapon: WeaponInstance

func _setup() -> void:
	weapon = agent as WeaponInstance

func _update(delta: float) -> void:
	if weapon.wants_primary_shoot:
		dispatch(WeaponHSM.ROUTE_PRIMARY)
	elif weapon.wants_secondary_shoot:
		dispatch(WeaponHSM.ROUTE_SECONDARY)
	else:
		dispatch(WeaponHSM.EVENT_SEQ_COMPLETED)
