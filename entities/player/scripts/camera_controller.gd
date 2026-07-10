class_name PlayerCameraController extends Node                                # WARNING: Should be a Node3D
# =============================================================================
# COMPONENT: CAMERA CONTROLLER
## Responsibilities: Manages its own Finite State Machine for camera perspective 
## (FP, TP, Free Look). Handles aiming sensitivity, procedural headbob, and 
## dynamic crouch-smoothing independent of the physical body.
# =============================================================================
#TODO: ADD COMMENTS ABOVE ALL FUNCTIONS



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Enums & States
enum State {
	FIRST_PERSON,
	THIRD_PERSON,
	THIRD_PERSON_FREE_LOOK
	}
	
var current_state  : State = State.FIRST_PERSON
var previous_state : State = State.FIRST_PERSON
#endregion


#region Node References
@onready var player               : CharacterBody3D          = get_parent()
@onready var input                : PlayerInput              = %PlayerInput
@onready var movement_controller  : PlayerMovementController = %MovementController 

@onready var head                 : Node3D      = %Head
@onready var camera               : Camera3D    = %Camera3D
@onready var camera_smooth_point  : Node3D      = %CameraSmoothPoint
@onready var orbit_cam_yaw        : Node3D      = %ThirdPersonOrbitCamYaw   
@onready var orbit_cam_pitch      : Node3D      = %ThirdPersonOrbitCamPitch
@onready var orbit_cam_spring_arm : SpringArm3D = %ThirdPersonOrbitCamSpringArm3D
#endregion


#region Exported Parameters
@export_group("Camera Settings")
@export var tp_look_sensitivity            : float = 0.006                      ## [color=yellow]Third-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in TP.
@export var fp_look_sensitivity            : float = 0.006                      ## [color=yellow]First-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in FP. [br]Common range: [code]0.002[/code] to [code]0.01[/code].
@export var controller_fp_look_sensitivity : float = 0.075                      ## [color=yellow]FP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var controller_tp_look_sensitivity : float = 0.075                      ## [color=yellow]TP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var headbob                        : bool  = true                       ## [color=cyan]Enables camera bobbing.[/color] [br]Simulates realistic footsteps visually when walking/sprinting on the ground.
@export var smooth_headbob                 : bool  = true
#endregion


#region Internal Variables
const HEADBOB_MOVE_AMOUNT : float = 0.06
const HEADBOB_FREQUNCY    : float = 2.4
var headbob_time          : float = 0.0
var _saved_camera_global_position : Vector3 = Vector3.INF
#endregion



# ==============================================================================
# METHODS
# ==============================================================================


# ==========================================
# PUBLIC
# ==========================================
#region Core Execution
## Orchestrates camera states and smoothing logic during the physics frame.
func process_camera(delta: float) -> void:
	# Handle states
	previous_state = current_state
	_update_camera_state()
	
	# Handles states transitions
	if current_state != previous_state:
		_on_camera_state_transition(previous_state, current_state)
	
	# Apply effects
	_slide_camera_smooth_back_to_origin(delta)
	_handle_crouch_camera_smoothing(delta)
	_handle_headbob(delta)
#endregion


#region Input Handling
## Processes raw hardware mouse deltas and delegates them to the current camera state.
func handle_camera_input(event : InputEventMouseMotion) -> void:
	match current_state:
		State.FIRST_PERSON:
			_execute_fp_camera_state(event)
		State.THIRD_PERSON:
			_execute_tp_camera_state(event)
		State.THIRD_PERSON_FREE_LOOK:
			_execute_tp_free_look_camera_state(event)


## Applies lerp-smoothed look rotation when using an analog gamepad stick.      # TODO: Add a not 1 or 0 move speed on the left joystick
func handle_controller_look_input(delta: float) -> void:
	var target_look : Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	# Smooth
	if target_look.length() < input.controller_look.length():                                       #TODO: Add a ON/OFF on this smoothing
		input.controller_look = target_look
	else:
		input.controller_look = input.controller_look.lerp(target_look, 5.0 * delta)                #TODO : Turn this 5.0 into a global setting
	
	# Apply rotation (DEPRECATED! This is not enough for all the camera modes and is only meant for first person)
	# TODO: Update handle_controller_look_input.
	player.rotate_y(-input.controller_look.x * controller_fp_look_sensitivity)
	camera.rotate_x(input.controller_look.y * controller_fp_look_sensitivity)
	camera.rotation_degrees.x = clampf(camera.rotation_degrees.x, -90, +90)
#endregion


# ==========================================
# PRIVATE
# ==========================================
#region State Handling
func _update_camera_state() -> void:
	# Cycle through cameras based on input
	if input.next_camera_pressed:
		current_state = ((current_state + 1) % State.size()) as State
	# NOTE: I will add more conditions to handle cutscenes and everything else


func _on_camera_state_transition(old_state : State, new_state : State) -> void:
	# TODO: This look kinda messy, I migth be able to make it cleaner
	# TODO: 
	# reparent() can cause micro-stutters.
	# For polish, I will use two separate Camera3D nodes and toggling their `current` property instead of reparenting one node.
	_reset_camera_before_transition()
	if old_state == State.FIRST_PERSON:
		if new_state == State.THIRD_PERSON:
			camera.reparent(orbit_cam_spring_arm, true)
			camera.set_cull_mask_value(2, true)
		if new_state == State.THIRD_PERSON_FREE_LOOK:
			camera.reparent(orbit_cam_spring_arm, true)
			camera.set_cull_mask_value(2, true)
			
	elif old_state in [State.THIRD_PERSON, State.THIRD_PERSON_FREE_LOOK]:
		if new_state == State.FIRST_PERSON:
			camera.reparent(camera_smooth_point, true)
			camera.set_cull_mask_value(2, false)


func _reset_camera_before_transition() -> void:
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	orbit_cam_pitch.rotation = Vector3.ZERO
	orbit_cam_yaw.rotation = Vector3.ZERO
#endregion


#region Execute States
func _execute_fp_camera_state(event : InputEventMouseMotion) -> void:
	player.rotate_y(-event.relative.x * fp_look_sensitivity)
	camera.rotate_x(-event.relative.y * fp_look_sensitivity)
	camera.rotation_degrees.x = clampf(camera.rotation_degrees.x, -90, +90)


func _execute_tp_camera_state(event : InputEventMouseMotion) -> void:
	orbit_cam_yaw.rotation.y = 0.0
	player.rotate_y(-event.relative.x * tp_look_sensitivity)
	orbit_cam_pitch.rotate_x(-event.relative.y * tp_look_sensitivity)
	orbit_cam_pitch.rotation_degrees.x = clampf(orbit_cam_pitch.rotation_degrees.x, -90, +90)


func _execute_tp_free_look_camera_state(event : InputEventMouseMotion) -> void:
	orbit_cam_yaw.rotate_y(-event.relative.x * tp_look_sensitivity)
	orbit_cam_pitch.rotate_x(-event.relative.y * tp_look_sensitivity)
	orbit_cam_pitch.rotation_degrees.x = clampf(orbit_cam_pitch.rotation_degrees.x, -90, +90)
#endregion


#region Effects & Smoothing 
func _handle_headbob(delta : float) -> void:
	if not headbob: return
	
	# Ask the MovementController if we are currently moving on the ground
	var is_moving_on_ground : bool = movement_controller.current_state in [
		movement_controller.State.WALKING, 
		movement_controller.State.SPRINTING, 
		movement_controller.State.CROUCHING, 
		movement_controller.State.CROUCHING_SPRINTING
	]
	
	# Only advance the sine wave if we are grounded and actually moving
	if is_moving_on_ground and player.velocity.length() > 0.1:                  #TODO: MAGIC NUMBER
		headbob_time += delta * player.velocity.length()
		camera.transform.origin = Vector3(
			cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       # X axis
			sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             # Y axis
			0                                                                       # Z axis
		) 
	# Smoothly apply the bob. If we stop or jump, this safely glides the camera back to (0,0,0)
	if smooth_headbob: camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, 10.0 * delta)


func _save_camera_position_for_smoothing() -> void:
	if _saved_camera_global_position == Vector3.INF:
		_saved_camera_global_position = camera_smooth_point.global_position


func _slide_camera_smooth_back_to_origin(delta : float) -> void:
	if _saved_camera_global_position == Vector3.INF: return 
	camera_smooth_point.global_position.y = _saved_camera_global_position.y
	camera_smooth_point.position.y        = clampf(camera_smooth_point.position.y, -0.7, 0.7)       # Avoid teleporting
	var move_amount :float = maxf(player.velocity.length() * delta, movement_controller.walk_speed/2 * delta) 
	camera_smooth_point.position.y = move_toward(camera_smooth_point.position.y, 0.0, move_amount)
	
	if camera_smooth_point.position.y == 0:
		_saved_camera_global_position = Vector3.INF # Stop smoothing


func _handle_crouch_camera_smoothing(delta : float) -> void:
	var is_crouching : bool = movement_controller.current_state in [
	movement_controller.State.CROUCHING_IDLE, 
	movement_controller.State.CROUCHING, 
	movement_controller.State.CROUCHING_SPRINTING, 
	movement_controller.State.IN_AIR_CROUCHING
	]
	
	var target_y : float = -movement_controller.crouch_translate if is_crouching else 0.0
	head.position.y = move_toward(head.position.y, target_y, 7.0 * delta)
#endregion
