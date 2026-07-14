class_name PlayerAnimationController extends Node
# ==============================================================================
# COMPONENT: ANIMATION CONTROLLER
## Responsibilities: Acts as the bridge between the physics logic and visual representation.
# ==============================================================================

# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Node References
@export var player              : CharacterBody3D
@export var movement_controller : PlayerMovementController
@export var animation_tree      : AnimationTree
#endregion

#region Animation Paths & Names
@export_group("Animation Paths & Names")
@export var base_movement_state_machine_playback_path: StringName = "parameters/BaseMovementStateMachine/playback"
@export var stand_blend_position_path                : StringName = "parameters/BaseMovementStateMachine/StandBlendSpace2D/blend_position"
@export var crouch_blend_position_path               : StringName = "parameters/BaseMovementStateMachine/CrouchBlendSpace2D/blend_position"

@export var stand_blend_space_2d_name                : StringName = "StandBlendSpace2D"
@export var crouch_blend_space_2d_name               : StringName = "CrouchBlendSpace2D"
@export var jump_start_name                          : StringName = "JumpStartAnimation"
@export var jump_name                                : StringName = "JumpAnimation"
@export var jump_land_name                           : StringName = "JumpLandAnimation"
@export var in_air_crouch_name                       : StringName = "InAirCrouchAnimation"

@onready var base_movement_state_machine_playback : AnimationNodeStateMachinePlayback = animation_tree.get(base_movement_state_machine_playback_path)
#endregion

#region Internal Variables
var _previous_movement_state : PlayerMovementController.State = PlayerMovementController.State.IDLE
var _current_blend_position  : Vector2 = Vector2.ZERO 
#endregion


# ==============================================================================
# METHODS
# ==============================================================================
#region Core Execution
func process_animation(delta: float) -> void:
	if not animation_tree or not base_movement_state_machine_playback: return
	
	_update_blend_spaces(delta)
	
	# Check for State Changes (Trigger Transients like Jump Start / Land)
	var current_state : PlayerMovementController.State = movement_controller.current_state
	if current_state != _previous_movement_state:
		_on_movement_state_changed(_previous_movement_state, current_state)
		_previous_movement_state = current_state
		
	# Enforce Continuous Loops (Stand, Crouch, JumpLoop)
	_enforce_animation_loops()


func _update_blend_spaces(delta: float) -> void:
	var target_blend_pos : Vector2 = _get_relative_horizontal_velocity()
	
	# Smoothly interpolate the 2D vector to prevent animation snapping when stopping/starting
	_current_blend_position = _current_blend_position.lerp(target_blend_pos, 10.0 * delta)
	
	animation_tree[stand_blend_position_path] = _current_blend_position
	animation_tree[crouch_blend_position_path] = _current_blend_position
#endregion


#region State Machine Logic
## Fires exactly ONCE when the physics state changes. Perfect for one-shot transient animations!
func _on_movement_state_changed(old_state: PlayerMovementController.State, new_state: PlayerMovementController.State) -> void:
	var was_in_air : bool = old_state in [movement_controller.State.IN_AIR, movement_controller.State.IN_AIR_CROUCHING]
	var is_in_air  : bool = new_state in [movement_controller.State.IN_AIR, movement_controller.State.IN_AIR_CROUCHING]
	
	# JUMP START (Or falling off a ledge)
	if is_in_air and not was_in_air: 
		if player.velocity.y > -1.0:                                            # -1.0 To avoid jumping animation when sliding down a little hill
			base_movement_state_machine_playback.travel(jump_start_name)
		else:
			base_movement_state_machine_playback.travel(jump_name)              # Skip start animation if walking off a ledge
	# JUMP LAND
	elif was_in_air and not is_in_air: 
		base_movement_state_machine_playback.travel(jump_land_name)


## Runs continuously, but pauses itself if a transient animation is playing.
func _enforce_animation_loops() -> void:
	var current_anim : StringName = base_movement_state_machine_playback.get_current_node()
	
	# GUARD: If we are playing a one-shot animation, do not interrupt it.
	# The AnimationTree "Auto Advance" will safely move us to the next state when it finishes.
	if current_anim == jump_start_name or current_anim == jump_land_name: return 
	
	# If we are not playing a transient, enforce the correct looping animation
	match movement_controller.current_state:
		movement_controller.State.IDLE, movement_controller.State.WALKING, movement_controller.State.SPRINTING:
			if current_anim != stand_blend_space_2d_name:
				base_movement_state_machine_playback.travel(stand_blend_space_2d_name)
			
		movement_controller.State.CROUCHING_IDLE, movement_controller.State.CROUCHING, movement_controller.State.CROUCHING_SPRINTING:
			if current_anim != crouch_blend_space_2d_name:
				base_movement_state_machine_playback.travel(crouch_blend_space_2d_name)
			
		movement_controller.State.IN_AIR:
			if current_anim != jump_name:
				base_movement_state_machine_playback.travel(jump_name)
			
		movement_controller.State.IN_AIR_CROUCHING:
			if current_anim != in_air_crouch_name:
				base_movement_state_machine_playback.travel(in_air_crouch_name)
#endregion


#region Math Utilities
func _get_relative_horizontal_velocity() -> Vector2:
	var horizontal_velocity : Vector3 = player.velocity * Vector3(1.0, 0.0, 1.0)
	var current_speed : float = horizontal_velocity.length()
	
	if current_speed < 0.1: return Vector2.ZERO
	
	# Get the direction relative to the player's body
	var relative_dir_3d : Vector3 = player.global_basis.inverse() * (horizontal_velocity / current_speed)
	var relative_dir_2d : Vector2 = Vector2(relative_dir_3d.x, -relative_dir_3d.z).normalized()
	
	# Check if the player is in a crouching state to apply the speed multiplier
	var is_crouching : bool = movement_controller.current_state in [
		movement_controller.State.CROUCHING_IDLE,
		movement_controller.State.CROUCHING,
		movement_controller.State.CROUCHING_SPRINTING,
	]
	
	# Determine the dynamic speed limits
	var walk_limit   : float = movement_controller.walk_speed
	var sprint_limit : float = movement_controller.sprint_speed
	
	if is_crouching:
		walk_limit *= movement_controller.crouch_speed_multiplier
		sprint_limit *= movement_controller.crouch_speed_multiplier
	
	# Map absolute physics speed to the 0, 1, and 2 positions in your BlendSpaces
	var mapped_speed : float = 0.0
	
	if current_speed <= walk_limit:
		# Map 0 -> walk_limit to 0.0 -> 1.0 (Idle to Walk)
		mapped_speed = current_speed / max(0.01, walk_limit)
	else:
		# Map walk_limit -> sprint_limit to 1.0 -> 2.0 (Walk to Run)
		var over_walk : float = current_speed - walk_limit
		var sprint_diff : float = sprint_limit - walk_limit
		mapped_speed = 1.0 + (over_walk / max(0.01, sprint_diff))
		
	# Cap it at 2.0 just in case the player is moving ultra-fast (falling/physics glitch)
	mapped_speed = minf(mapped_speed, 2.0)
	
	return relative_dir_2d * mapped_speed
#endregion
