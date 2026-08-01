class_name PlayerAnimationController extends Node

@export var actor          : CharacterBody3D
@export var state_machine  : MovementStateMachine
@export var animation_tree : AnimationTree

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

var _previous_state_name    : StringName = &"IdleState"
var _current_blend_position : Vector2 = Vector2.ZERO 

func _physics_process(delta: float) -> void:
	if not animation_tree or not base_movement_state_machine_playback or not state_machine.current_state: return
	_update_blend_spaces(delta)
	
	var current_state_name : StringName = state_machine.current_state.name
	if current_state_name != _previous_state_name:
		_on_movement_state_changed(_previous_state_name, current_state_name)
		_previous_state_name = current_state_name
		
	_enforce_animation_loops(current_state_name)

func _update_blend_spaces(delta: float) -> void:
	var target_blend_pos : Vector2 = _get_relative_horizontal_velocity()
	_current_blend_position = _current_blend_position.lerp(target_blend_pos, 10.0 * delta)
	animation_tree[stand_blend_position_path] = _current_blend_position
	animation_tree[crouch_blend_position_path] = _current_blend_position

func _on_movement_state_changed(old_state: StringName, new_state: StringName) -> void:
	var was_in_air : bool = old_state in [&"AirState", &"JumpState", &"FallState", &"AirCrouchState", &"SurfState"]
	var is_in_air  : bool = new_state in [&"AirState", &"JumpState", &"FallState", &"AirCrouchState", &"SurfState"]

	if is_in_air and not was_in_air: 
		if actor.velocity.y > -1.0:                                            
			base_movement_state_machine_playback.travel(jump_start_name)
		else:
			base_movement_state_machine_playback.travel(jump_name)              
	elif was_in_air and not is_in_air: 
		base_movement_state_machine_playback.travel(jump_land_name)

func _enforce_animation_loops(current_state: StringName) -> void:
	var current_anim : StringName = base_movement_state_machine_playback.get_current_node()
	if current_anim == jump_start_name or current_anim == jump_land_name: return 

	match current_state:
		&"IdleState", &"WalkState", &"SprintState":
			if current_anim != stand_blend_space_2d_name:
				base_movement_state_machine_playback.travel(stand_blend_space_2d_name)
		&"CrouchState":
			if current_anim != crouch_blend_space_2d_name:
				base_movement_state_machine_playback.travel(crouch_blend_space_2d_name)
		&"JumpState", &"FallState", &"SurfState", &"AirState":
			if current_anim != jump_name:
				base_movement_state_machine_playback.travel(jump_name)
		&"AirCrouchState":
			if current_anim != in_air_crouch_name:
				base_movement_state_machine_playback.travel(in_air_crouch_name)

func _get_relative_horizontal_velocity() -> Vector2:
	var horizontal_velocity : Vector3 = actor.velocity * Vector3(1.0, 0.0, 1.0)
	var current_speed : float = horizontal_velocity.length()
	if current_speed < 0.1: return Vector2.ZERO
	
	var relative_dir_3d : Vector3 = actor.global_basis.inverse() * (horizontal_velocity / current_speed)
	var relative_dir_2d : Vector2 = Vector2(relative_dir_3d.x, -relative_dir_3d.z).normalized()
	
	var is_crouching : bool = state_machine.current_state.name in [&"CrouchState", &"AirCrouchState"]
	var stats : MovementStats = actor.movement_stats
	
	var walk_limit   : float = stats.walk_speed
	var sprint_limit : float = stats.sprint_speed
	if is_crouching:
		walk_limit *= stats.crouch_speed_multiplier
		sprint_limit *= stats.crouch_speed_multiplier
		
	var mapped_speed : float = 0.0
	if current_speed <= walk_limit:
		mapped_speed = current_speed / max(0.01, walk_limit)
	else:
		var over_walk : float = current_speed - walk_limit
		var sprint_diff : float = sprint_limit - walk_limit
		mapped_speed = 1.0 + (over_walk / max(0.01, sprint_diff))
		
	return relative_dir_2d * minf(mapped_speed, 2.0)
