class_name PlayerInput extends ActorInput
## [color=green]Player-Specific Input Reader.[/color]
## Translates raw OS hardware events (Keyboard/Mouse) into generic Actor Intents.
## Also dynamically modifies the player's MovementStats resource based on toggles.

# ==============================================================================
# VECTORS
# ==============================================================================
var controller_look                 : Vector2 = Vector2.ZERO
var camera_aligned_wished_direction : Vector3 = Vector3.ZERO                    ## [color=yellow]Camera-Aligned Wished Velocity.[/color] [br]The movement intent rotated to match where the camera is currently looking (useful for noclip).
# ==============================================================================
# DEBUG & TOGGLE INTENTS (Usually only used by the Player)
# ==============================================================================
var wants_camera_swap            : bool = false
var wants_noclip                 : bool = false
var wants_noclip_speed_increase  : bool = false
var wants_noclip_speed_decrease  : bool = false

var is_noclipping : bool = false

var stats: MovementStats

func _ready() -> void:
	await owner.ready
	stats = owner.movement_stats


func gather_inputs(actor_basis: Basis, camera_basis: Basis) -> void:
	# HARDWARE POLLING (Raw OS Input)
	move_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	
	var sprint_held : bool = Input.is_action_pressed("sprint")
	var jump_held   : bool = Input.is_action_pressed("jump")
	
	# --- TOGGLES & SETTINGS ---
	if Input.is_action_just_pressed("toggle_sprint"):
		stats.auto_sprint = not stats.auto_sprint
		
	if stats.can_noclip and Input.is_action_just_pressed("_noclip"):
		stats.noclip = not stats.noclip
		stats.noclip_speed_multiplier = 3.0 # Reset to base multiplier
		
	if stats.can_noclip and stats.noclip:
		if Input.is_action_just_pressed("_increase_noclip_speed"):
			stats.noclip_speed_multiplier = minf(stats.noclip_max_speed, stats.noclip_speed_multiplier * stats.noclip_speed_increase_multiplier) 
		elif Input.is_action_just_pressed("_decrease_noclip_speed"):
			stats.noclip_speed_multiplier = maxf(stats.noclip_min_speed, stats.noclip_speed_multiplier * stats.noclip_speed_decrease_multiplier)
	
	# --------------------------
	# RESOLVE MOVEMENT INTENTS
	wants_crouch = Input.is_action_pressed("crouch")
	wants_jump   = Input.is_action_just_pressed("jump") or (stats.auto_bhop and jump_held)
	wants_sprint = (sprint_held and not stats.auto_sprint) or (stats.auto_sprint and not sprint_held)

	# RESOLVE COMBAT & INTERACTION INTENTS
	wants_primary_shoot   = Input.is_action_pressed("primary_shoot")
	wants_secondary_shoot = Input.is_action_pressed("secondary_shoot")
	wants_reload          = Input.is_action_just_pressed("reload")
	wants_weapon_swap     = Input.is_action_just_pressed("swap_weapon")
	wants_interact        = Input.is_action_just_pressed("interact")

	# RESOLVE DEBUG INTENTS
	wants_camera_swap           = Input.is_action_just_pressed("next_camera")
	wants_noclip                = Input.is_action_just_pressed("_noclip")
	wants_noclip_speed_increase = Input.is_action_just_pressed("_increase_noclip_speed")
	wants_noclip_speed_decrease = Input.is_action_just_pressed("_decrease_noclip_speed")

	# VECTOR TRANSLATIONS
	wished_direction = actor_basis * Vector3(move_direction.x, 0, move_direction.y)
	camera_aligned_wished_direction = camera_basis * Vector3(move_direction.x, 0, move_direction.y)

	var camera_forward : Vector3 = -camera_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	
	var camera_right : Vector3 = camera_basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	
	if move_direction.length_squared() > 0.01:
		flat_camera_aligned_wished_direction = (camera_right * move_direction.x - camera_forward * move_direction.y).normalized()
		is_moving = true
	else:
		flat_camera_aligned_wished_direction = Vector3.ZERO
		is_moving = false
	
	if stats.can_noclip:
		if wants_noclip and stats.can_noclip:
			is_noclipping = true
		else:
			is_noclipping = false
