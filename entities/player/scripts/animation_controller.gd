class_name AnimationController extends Node
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

@export_group("Animation Paths")
@export var base_movement_state_machine_playback_path: String = "parameters/BaseMovementStateMachine/playback"
@export var stand_blend_space_2d_name                : String = "StandBlendSpace2D"
@export var crouch_blend_space_2d_name               : String = "CrouchBlendSpace2D"
@export var jump_name                                : String = "JumpAnimation"
@export var jump_start_name                          : String = "JumpStartAnimation"
@export var jump_land_name                           : String = "JumpLandAnimation"
@export var stand_blend_space_2d_path                : String = "parameters/BaseMovementStateMachine/StandBlendSpace2D"
@export var crouch_blend_space_2d_path               : String = "parameters/BaseMovementStateMachine/CrouchBlendSpace2D"
@export var stand_blend_position_path                : String = "parameters/BaseMovementStateMachine/StandBlendSpace2D/blend_position"
@export var crouch_blend_position_path               : String = "parameters/BaseMovementStateMachine/CrouchBlendSpace2D/blend_position"

@onready var base_movement_state_machine_playback : AnimationNodeStateMachinePlayback = animation_tree.get(base_movement_state_machine_playback_path)
#endregion



# ==============================================================================
# METHODS
# ==============================================================================
#region Core Execution
func _ready() -> void:
	var stand_blend_space_2d : AnimationNodeBlendSpace2D = get("res://entities/commons/human/arts/animations/states/stand_blend_space_2d.tres")
	
	for i : int in stand_blend_space_2d.get_blend_point_count():
		var blend_point : AnimationNodeAnimation = stand_blend_space_2d.get_blend_point_node(i)
		blend_point.stretch_time_scale = true
		blend_point.timeline_length = 0.2
	


func process_animation(delta: float) -> void:
	_update_animation_state_machine(delta)


## Triggers discrete animation states (like jumping, crouching, or falling)
func _update_animation_state_machine(delta: float) -> void:
	_handle_air_state(delta)
	
	match movement_controller.current_state:
		movement_controller.State.IDLE, movement_controller.State.WALKING, movement_controller.State.SPRINTING:
			_handle_stand_state(delta)
		movement_controller.State.CROUCHING_IDLE, movement_controller.State.CROUCHING, movement_controller.State.CROUCHING_SPRINTING:
			_handle_crouch_state(delta)
		#movement_controller.State.IN_AIR, movement_controller.State.SURFING, movement_controller.State.NOCLIPING, movement_controller.State.NOCLIPING_SPRINTING:
		#	_handle_air_state(delta)


func _handle_stand_state(delta: float) -> void:
	if base_movement_state_machine_playback.get_current_node() != stand_blend_space_2d_name: # Is this better than just traveling without checking?
		base_movement_state_machine_playback.travel(stand_blend_space_2d_name)
	_update_stand_blend_space(delta)


func _handle_crouch_state(delta: float) -> void:
	if base_movement_state_machine_playback.get_current_node() != crouch_blend_space_2d_name:
		base_movement_state_machine_playback.travel(crouch_blend_space_2d_name)
	_update_crouch_blend_space(delta)


func _handle_air_state(delta: float) -> void:
	var was_in_air : bool = movement_controller.previous_state in [movement_controller.State.IN_AIR, movement_controller.State.IN_AIR_CROUCHING]
	var is_in_air  : bool = movement_controller.current_state  in [movement_controller.State.IN_AIR, movement_controller.State.IN_AIR_CROUCHING]
	
	if is_in_air and not was_in_air: # START JUMP
		base_movement_state_machine_playback.travel(jump_start_name)
	if was_in_air and not is_in_air: # LAND
		base_movement_state_machine_playback.travel(jump_land_name)
	if is_in_air and was_in_air: # MIDDLE JUMP
		base_movement_state_machine_playback.travel(jump_name)



## Smoothly blends the walking/running animations based on actual velocity
func _update_stand_blend_space(delta: float) -> void:
	animation_tree[stand_blend_position_path] = _get_relative_horizontal_velocity()

func _update_crouch_blend_space(delta: float) -> void:
	animation_tree[crouch_blend_position_path] = _get_relative_horizontal_velocity()


#endregion


func _get_relative_horizontal_velocity() -> Vector2:
	if movement_controller.get_move_speed() == 0: return Vector2.ZERO
	
	var normalized_velocity  : Vector3 = (player.velocity * Vector3(1.0, 0.0, 1.0)) / movement_controller.get_move_speed() 
	var relative_velocity    : Vector3 =  player.global_basis.inverse() * normalized_velocity
	var relative_velocity_h : Vector2 = Vector2(relative_velocity.x, -relative_velocity.z)
	print(relative_velocity_h)
	return relative_velocity_h

# Right    = +X
# Left     = -X
# Forward  = +Y
# Backward = -Y
