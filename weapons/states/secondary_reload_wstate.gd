## SECONDARY RELOAD STATE

# WARNING: THIS IS JUST A COPY OF PRIMARY RELOAD STATE AND NEEDS TO BE UPDATED!!!

extends LimboState

var weapon: WeaponInstance
var animation: AnimationPlayer

var duration_timer: float = 0.0
var is_empty_reload: bool = false

func _setup() -> void:
	weapon = agent as WeaponInstance
	animation = weapon.animation

func _enter() -> void:
	is_empty_reload = weapon.current_primary_mag_ammo == 0
	
	# Determine which string to use
	var anim_name: StringName = weapon.anim_primary_reload_empty if is_empty_reload else weapon.anim_primary_reload
	
	# Safely extract the exact time duration from the Animation Resource
	if animation and anim_name != &"" and animation.has_animation(anim_name):
		var anim_data: Animation = animation.get_animation(anim_name)
		duration_timer = anim_data.length 
		animation.play(anim_name)
	else:
		duration_timer = 1.0 # Failsafe duration
		
	# Tell the UI we started!
	weapon.reload_started.emit(duration_timer, is_empty_reload)

func _update(delta: float) -> void:
	# Tick the timer down!
	duration_timer -= delta
	
	if duration_timer <= 0.0:
		_execute_ammo_math()
		# Tell the root HSM to pull us back to Idle
		dispatch(WeaponHSM.EVENT_SEQ_COMPLETED)

func _execute_ammo_math() -> void:
	var missing_ammo: int = weapon.data.primary_max_mag_ammo - weapon.current_primary_mag_ammo
	var ammo_to_load: int = mini(missing_ammo, weapon.current_primary_reserve_ammo)
	
	weapon.current_primary_mag_ammo += ammo_to_load
	weapon.current_primary_reserve_ammo -= ammo_to_load
	
	weapon.ammo_updated.emit(weapon.current_primary_mag_ammo, weapon.current_primary_reserve_ammo)
	weapon.reload_finished.emit()
