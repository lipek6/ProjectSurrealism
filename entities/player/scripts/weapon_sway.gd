class_name WeaponSway extends Node3D
## Procedurally animates the weapon container to simulate weight, momentum, and landing impact.
## MUST BE DRIVEN BY AN EXTERNAL MANAGER. Does not use _process directly.

enum SWAY_MODE { 
	DRAG_BACK,                                                                  ## The weapon lags behind the camera movement. Creates a feeling of heavy mass and drag.
	POINT_TOWARDS                                                               ## The weapon leads the camera movement. Feels snappy, arcade-like, and matches Halo CE.
} 

# ==============================================================================
# ATTRIBUTES
# ==============================================================================
@export var player : Player

@export_group("Sway Settings")
@export var sway_mode        : SWAY_MODE = SWAY_MODE.POINT_TOWARDS
@export var sway_speed       : float     = 4.0                                  ## How fast the weapon snaps back to the center via lerp
@export var pos_sway_amount  : float     = 0.005                                ## How much the weapon shifts side-to-side (position)
@export var pos_sway_max     : float     = 0.05                                 ## Maximum positional shift distance
@export var rot_sway_amount  : float     = 0.005                                ## How much the weapon rotates/angles
@export var rot_sway_max     : float     = 0.1                                  ## Maximum rotational shift angle

@export_group("Impact Settings")
@export var landing_dip_multiplier : float = 0.01                               ## How much the gun dips based on fall speed
@export var max_landing_dip_pos    : float = 1.0                                ## The absolute maximum meters the gun can dip downwards
@export var max_landing_dip_rot    : float = 0.3                                ## The absolute maximum radians the gun can tilt downwards
@export var impact_decay_speed     : float = 12.0                               ## How fast the gun springs back up after hitting the ground

# Internal State
var _mouse_delta       : Vector2 = Vector2.ZERO
var _last_y_velocity   : float = 0.0
var _was_on_floor      : bool = true

# Spring State for smoothing impacts
var _current_impact_pos : float = 0.0
var _current_impact_rot : float = 0.0


# ==============================================================================
# METHODS
# ==============================================================================

## Called from the Player's input gathering pipeline _unhandled_input() on player.gd.
func handle_sway_input(event: InputEventMouseMotion) -> void:
	_mouse_delta = event.relative


## Called from the Player processing loop _process() (after camera updates).
func process_sway(delta: float) -> void:
	_handle_landing_impact()
	
	# DECAY THE IMPACT SPRING (landing)
	_current_impact_pos = lerpf(_current_impact_pos, 0.0, impact_decay_speed * delta)
	_current_impact_rot = lerpf(_current_impact_rot, 0.0, impact_decay_speed * delta)

	# CALCULATE SWAY TARGETS
	var target_pos_x : float = 0.0
	var target_pos_y : float = 0.0
	var target_rot_x : float = 0.0
	var target_rot_y : float = 0.0
	
	match sway_mode:
		SWAY_MODE.DRAG_BACK:
			target_pos_x = clampf(-_mouse_delta.x * pos_sway_amount, -pos_sway_max, pos_sway_max) 
			target_pos_y = clampf(-_mouse_delta.y * pos_sway_amount, -pos_sway_max, pos_sway_max) 
			target_rot_x = clampf(_mouse_delta.y * rot_sway_amount, -rot_sway_max, rot_sway_max)
			target_rot_y = clampf(_mouse_delta.x * rot_sway_amount, -rot_sway_max, rot_sway_max)
		SWAY_MODE.POINT_TOWARDS:
			target_pos_x = clampf(_mouse_delta.x * pos_sway_amount, -pos_sway_max, pos_sway_max) 
			target_pos_y = clampf(_mouse_delta.y * pos_sway_amount, -pos_sway_max, pos_sway_max) 
			target_rot_x = clampf(-_mouse_delta.y * rot_sway_amount, -rot_sway_max, rot_sway_max)
			target_rot_y = clampf(-_mouse_delta.x * rot_sway_amount, -rot_sway_max, rot_sway_max)

	# Add the smooth impact offset to the target Y axes
	target_pos_y -= _current_impact_pos
	target_rot_x -= _current_impact_rot

	# LERP TOWARDS COMBINED TARGETS
	position.x = lerpf(position.x, target_pos_x, sway_speed * delta)
	position.y = lerpf(position.y, target_pos_y, sway_speed * delta)
	
	rotation.x = lerp_angle(rotation.x, target_rot_x, sway_speed * delta)
	rotation.y = lerp_angle(rotation.y, target_rot_y, sway_speed * delta)
	
	# RESET INPUT DELTA
	_mouse_delta = Vector2.ZERO


func _handle_landing_impact() -> void:
	if not player:
		push_error("WeaponSway requires a Player reference!")
		return
	
	var is_grounded : bool = player.is_on_floor()
	
	# If we just hit the ground this frame
	if is_grounded and not _was_on_floor:
		var impact : float = abs(_last_y_velocity)
		
		# Instantly spike the spring variables, clamped by exported limits
		_current_impact_pos = clampf(impact * landing_dip_multiplier, 0.0, max_landing_dip_pos)
		_current_impact_rot = clampf(impact * landing_dip_multiplier, 0.0, max_landing_dip_rot)
		
	# Cache values for the next frame's check
	_last_y_velocity = player.velocity.y
	_was_on_floor = is_grounded
