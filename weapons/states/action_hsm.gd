## ACTION HSM
class_name ActionHSM extends LimboHSM

var old_name: StringName = &""
func _update(delta: float) -> void:
	if get_parent().debug_print:
		if self.get_active_state().name != old_name:
			print("ActionHSM -> " + self.get_active_state().name + "     " + str(agent.current_primary_mag_ammo) + "/" + str(agent.current_primary_reserve_ammo))
			old_name = self.get_active_state().name
		
