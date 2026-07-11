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
enum Style {
	FIRST_PERSON,
	THIRD_PERSON,
	THIRD_PERSON_FREE_LOOK
	}

var current_style  : Style = default_camera_style
var previous_style : Style = default_camera_style
var current_camera : Camera3D
#endregion


#region Node References
@onready var player               : CharacterBody3D          = get_parent()
@onready var input                : PlayerInput              = %PlayerInput
@onready var movement_controller  : PlayerMovementController = %MovementController 

@onready var head                 : Node3D      = %Head
@onready var fp_camera            : Camera3D    = %FirstPersonCamera3D
@onready var tp_camera            : Camera3D    = %ThirdPersonCamera3D
@onready var camera_smooth_point  : Node3D      = %CameraSmoothPoint
@onready var orbit_cam_yaw        : Node3D      = %ThirdPersonOrbitCamYaw   
@onready var orbit_cam_pitch      : Node3D      = %ThirdPersonOrbitCamPitch
@onready var orbit_cam_spring_arm : SpringArm3D = %ThirdPersonOrbitCamSpringArm3D
#endregion


#region Exported Parameters
@export_group("Camera Settings")
@export var default_camera_style           : Style = Style.FIRST_PERSON
@export var tp_look_sensitivity            : float = 0.006                      ## [color=yellow]Third-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in TP.
@export var fp_look_sensitivity            : float = 0.006                      ## [color=yellow]First-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in FP. [br]Common range: [code]0.002[/code] to [code]0.01[/code].
@export var controller_fp_look_sensitivity : float = 0.075                      ## [color=yellow]FP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var controller_tp_look_sensitivity : float = 0.075                      ## [color=yellow]TP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var headbob                        : bool  = true                       ## [color=cyan]Enables fp_camera bobbing.[/color] [br]Simulates realistic footsteps visually when walking/sprinting on the ground.
@export var smooth_headbob                 : bool  = false
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
## Orchestrates fp_camera states and smoothing logic during the physics frame.
func process_camera(delta: float) -> void:
	# Handle states
	previous_style = current_style
	_update_camera_style()
	
	# Handles states transitions
	if current_style != previous_style:
		_on_camera_style_transition(previous_style, current_style)
	
	# Apply effects
	_slide_camera_smooth_back_to_origin(delta)
	_handle_crouch_camera_smoothing(delta)
	_handle_headbob(delta)
	_handle_third_person_free_look_player_alignment(delta)
#endregion


#region Input Handling
## Processes raw hardware mouse deltas and delegates them to the current fp_camera state.
func handle_camera_input(event : InputEventMouseMotion) -> void:
	match current_style:
		Style.FIRST_PERSON:
			_execute_fp_camera_style(event)
		Style.THIRD_PERSON:
			_execute_tp_camera_style(event)
		Style.THIRD_PERSON_FREE_LOOK:
			_execute_tp_free_look_camera_style(event)


## Applies lerp-smoothed look rotation when using an analog gamepad stick.      # TODO: Add a not 1 or 0 move speed on the left joystick
func handle_controller_look_input(delta: float) -> void:
	var target_look : Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	# Smooth
	if target_look.length() < input.controller_look.length():                                       #TODO: Add a ON/OFF on this smoothing
		input.controller_look = target_look
	else:
		input.controller_look = input.controller_look.lerp(target_look, 5.0 * delta)                #TODO : Turn this 5.0 into a global setting
	
	# Apply rotation (DEPRECATED! This is not enough for all the fp_camera modes and is only meant for first person)
	# TODO: Update handle_controller_look_input.
	player.rotate_y(-input.controller_look.x * controller_fp_look_sensitivity)
	fp_camera.rotate_x(input.controller_look.y * controller_fp_look_sensitivity)
	fp_camera.rotation_degrees.x = clampf(fp_camera.rotation_degrees.x, -89, +89)
#endregion


# ==========================================
# PRIVATE
# ==========================================
func _ready() -> void:
	match default_camera_style:
		Style.FIRST_PERSON:
			current_camera = fp_camera
		Style.THIRD_PERSON, Style.THIRD_PERSON_FREE_LOOK:
			current_camera = tp_camera


#region Style Handling
func _update_camera_style() -> void:
	# Cycle through cameras based on input
	if input.next_camera_pressed:
		current_style = ((current_style + 1) % Style.size()) as Style
	# NOTE: I will add more conditions to handle cutscenes and everything else


func _on_camera_style_transition(old_style : Style, new_style : Style) -> void:
	if new_style in [Style.THIRD_PERSON, Style.THIRD_PERSON_FREE_LOOK] and old_style == Style.FIRST_PERSON:
		current_camera = tp_camera
		tp_camera.make_current()
	elif new_style == Style.FIRST_PERSON and old_style in [Style.THIRD_PERSON, Style.THIRD_PERSON_FREE_LOOK]:
		current_camera = fp_camera
		fp_camera.make_current()
#endregion


#region Execute States
func _execute_fp_camera_style(event : InputEventMouseMotion) -> void:
	player.rotate_y(-event.relative.x * fp_look_sensitivity)
	fp_camera.rotate_x(-event.relative.y * fp_look_sensitivity)
	fp_camera.rotation_degrees.x = clampf(fp_camera.rotation_degrees.x, -89, +89)


func _execute_tp_camera_style(event : InputEventMouseMotion) -> void:
	orbit_cam_yaw.rotation.y = 0.0
	player.rotate_y(-event.relative.x * tp_look_sensitivity)
	orbit_cam_pitch.rotate_x(-event.relative.y * tp_look_sensitivity)
	orbit_cam_pitch.rotation_degrees.x = clampf(orbit_cam_pitch.rotation_degrees.x, -89, +89)


func _execute_tp_free_look_camera_style(event : InputEventMouseMotion) -> void:
	orbit_cam_yaw.rotate_y(-event.relative.x * tp_look_sensitivity)
	orbit_cam_pitch.rotate_x(-event.relative.y * tp_look_sensitivity)
	orbit_cam_pitch.rotation_degrees.x = clampf(orbit_cam_pitch.rotation_degrees.x, -89, +89)        # Don't use 90, it will make the controls work backawards when on a 90 degrees angle
#endregion


#region Effects & Smoothing 
func _handle_third_person_free_look_player_alignment(delta : float) -> void:
	if current_style != Style.THIRD_PERSON_FREE_LOOK: return
	
	if input.flat_camera_aligned_wished_direction.length_squared() > 0.01:           # If the player is actively pressing movement keys
		var add_rotation_y : float = (-player.global_basis.z).signed_angle_to(input.flat_camera_aligned_wished_direction, Vector3.UP)
		var rotate_towards : float = lerp_angle(player.global_rotation.y, player.global_rotation.y + add_rotation_y, max(0.1,  abs(add_rotation_y/TAU))) - player.global_rotation.y
		
		player.rotation.y += rotate_towards
		orbit_cam_yaw.rotation.y -= rotate_towards                              # Counter-rotate the camera yaw so the camera's world-view remains completely stable



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
		fp_camera.transform.origin = Vector3(
			cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       # X axis
			sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             # Y axis
			0                                                                       # Z axis
		) 
	# Smoothly apply the bob. If we stop or jump, this safely glides the fp_camera back to (0,0,0)
	if smooth_headbob: fp_camera.transform.origin = fp_camera.transform.origin.lerp(Vector3.ZERO, 10.0 * delta)


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
