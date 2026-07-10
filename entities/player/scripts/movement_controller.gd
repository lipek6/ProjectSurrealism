class_name PlayerMovementController extends Node
# ==============================================================================
# COMPONENT: MOVEMENT CONTROLLER
## Responsibilities: Manages the Finite State Machine (FSM) for kinematic traversal.
## Handles acceleration, friction, stair-snapping, and state transitions (crouching, sprinting).
# ==============================================================================



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Enums & States
enum State {
	IDLE,
	WALKING,
	SPRINTING,
	CROUCHING_IDLE,
	CROUCHING,
	CROUCHING_SPRINTING,
	IN_AIR,
	IN_AIR_CROUCHING,
	SURFING,
	NOCLIPING,
	NOCLIPING_SPRINTING
	}

var current_state  : State = State.IDLE
var previous_state : State = State.IDLE
#endregion


#region Node References
@onready var player             : CharacterBody3D        = get_parent()
@onready var input              : PlayerInput            = %PlayerInput
@onready var physics_interactor : PhysicsInteractor      = %PhysicsInteractor

@onready var collision_shape         : CollisionShape3D = %CollisionShape3D
@onready var head                    : Node3D           = %Head
@onready var stairs_ahead_ray        : RayCast3D        = %StairsAheadRayCast3D
@onready var stairs_below_ray        : RayCast3D        = %StairsBelowRayCast3D
@onready var _origina_capsule_height : float            = collision_shape.shape.height
#endregion


#region Exported Parameters 
#region Ground Movement
@export_group("Ground Movement")
@export var auto_bhop               : bool  = false                             ## [color=green]Hold jump to continuously bounce.[/color] [br]If true, holding the jump button automatically triggers a jump on the exact frame the player lands.
@export var auto_sprint             : bool  = true                              ## [color=cyan]Inverts sprint key logic.[/color] [br]If true, the player sprints by default and walks only when holding the sprint key.
@export var walk_speed              : float = 7.0                               ## [color=yellow]Base walking velocity (m/s).[/color] [br]Standard speed for normal ground traversal.
@export var sprint_speed            : float = 8.5                               ## [color=orange]Maximum running velocity (m/s).[/color] [br]Achieved when sprinting.
@export var ground_accel            : float = 14.0                              ## [color=cyan]Acceleration rate.[/color] [br]How quickly the player reaches max speed from a standstill. Higher values = snappier movement.
@export var ground_decel            : float = 10.0                              ## [color=cyan]Deceleration rate.[/color] [br]How quickly the player comes to a halt when releasing the movement keys.
@export var ground_friction         : float = 6.0                               ## [color=orange]Friction multiplier.[/color] [br]Applied against deceleration. Lower values make the floor feel like ice.
@export var max_step_height         : float = 0.5                               ## [color=pink]Stair snap height (m).[/color] [br]Maximum height of a ledge/stair the player will automatically step onto without jumping.
@export var crouch_translate        : float = 0.7                               ## [color=pink]Crouch depth (m).[/color] [br]How much the physical collision capsule shrinks and the camera lowers when crouching.
@export var crouch_jump_add         : float = 0.7 * 0.9                         ## [color=pink]Crouch-jump clearance (m).[/color] [br]Usually [code]crouch_translate * 0.9[/code]. Extra height gained by pulling legs up mid-air.
@export var crouch_speed_multiplier : float = 0.8                               ## [color=yellow]Crouch speed penalty.[/color] [br]Multiplies base speed. [code]0.8[/code] means moving at 80% speed while crouching.
#endregion


#region Air movement
@export_group("Air Movement")
@export var jump_velocity  : float = 6.0                                        ## [color=green]Initial jump burst (m/s).[/color] [br]Upward impulse instantly applied when jumping.
@export var air_cap        : float = 0.85                                       ## [color=yellow]Air strafe speed limit.[/color] [br]Caps how fast you can accelerate purely from air strafing vectors.
@export var air_accel      : float = 800.0                                      ## [color=orange]Air acceleration force.[/color] [br]Source-engine style high air accel for crisp mid-air directional changes and surfing.
@export var air_move_speed : float = 500.0                                      ## [color=orange]Base air move speed.[/color] [br]Used in conjunction with [code]air_accel[/code] to define the air-strafing handling curve.
#endregion


#region Debug
@export_group("Debug")
@export var can_noclip                       : bool  = false                    ## [color=red][DEBUG][/color] [color=cyan]Enables noclip toggle.[/color] [br]If true, allows the player to enter a flying ghost-cam mode.
@export var noclip                           : bool  = false                    ## [color=red][DEBUG][/color] [color=red]Current Noclip state.[/color] [br]If true, player flies and ignores all collisions.
@export var noclip_max_speed                 : float = 100.0                    ## [color=red][DEBUG][/color] [color=gray]Max fly speed.[/color] [br]Absolute limit for scroll-wheel speed increases in noclip.
@export var noclip_min_speed                 : float = 0.1                      ## [color=red][DEBUG][/color] [color=gray]Min fly speed.[/color] [br]Absolute limit for scroll-wheel speed decreases in noclip.
@export var noclip_speed_multiplier          : float = 3.0                      ## [color=red][DEBUG][/color] [color=yellow]Current fly speed multiplier.[/color] [br]Modifies base walk speed when flying.
@export var noclip_speed_increase_multiplier : float = 1.1                      ## [color=red][DEBUG][/color] [color=gray]Scroll-up scale.[/color] [br]How much speed increases per mouse scroll tick.
@export var noclip_speed_decrease_multiplier : float = 0.9                      ## [color=red][DEBUG][/color] [color=gray]Scroll-down scale.[/color] [br]How much speed decreases per mouse scroll tick.

#endregion
#endregion


#region Internal Variables
var _snapped_to_stairs_last_frame : bool  = false
@onready var _noclip_reset_speed_multiplier   : float = noclip_speed_multiplier 
#endregion



# ==============================================================================
# METHODS
# ==============================================================================


# ==========================================
# PUBLIC
# ==========================================
#region Core Execution
## Analyzes states and triggers appropriate physics updates
func process_movement(delta: float) -> void:
	previous_state = current_state
	_update_player_state()          
	
	if previous_state != current_state: 
		_on_state_transition(previous_state, current_state)
	
	# Execute Physics based strictly on FSM
	match current_state: 
		State.IDLE, State.WALKING, State.SPRINTING, State.CROUCHING_IDLE, State.CROUCHING, State.CROUCHING_SPRINTING:
			_execute_ground_state(delta)
		State.IN_AIR, State.SURFING, State.IN_AIR_CROUCHING:
			_execute_air_state(delta)
		State.NOCLIPING, State.NOCLIPING_SPRINTING:
			_handle_noclip()
			player.move_and_slide()


func handle_toggles_and_settings() -> void:
	if input.toggle_sprint_pressed:
		auto_sprint = not auto_sprint
	
	if can_noclip and input.toggle_noclip_pressed:
		noclip_speed_multiplier = _noclip_reset_speed_multiplier
		noclip = not noclip
	
	if can_noclip and noclip:
		if input.noclip_increase_pressed:
			noclip_speed_multiplier = minf(noclip_max_speed, noclip_speed_multiplier * noclip_speed_increase_multiplier) 
		elif input.noclip_decrease_pressed:
			noclip_speed_multiplier = maxf(noclip_min_speed, noclip_speed_multiplier * noclip_speed_decrease_multiplier)
#endregion


#region State Machine
## Pure logic tree that determines what the player *is doing* based on physics flags and input intent.[br]
func _update_player_state() -> void:
	var is_grounded   : bool = player.is_on_floor() or _snapped_to_stairs_last_frame
	var is_sprinting  : bool = (input.sprint_held and not auto_sprint) or (auto_sprint and not input.sprint_held)
	var was_crouching : bool = current_state in [State.CROUCHING_IDLE, State.CROUCHING, State.CROUCHING_SPRINTING, State.IN_AIR_CROUCHING]
	var is_crouching  : bool = input.crouch_held or (was_crouching and not _can_exit_crouch())
	
	# WARNING: The order of this if/elif/else statement matters!
	if can_noclip and noclip:
		current_state = State.NOCLIPING_SPRINTING if is_sprinting else State.NOCLIPING
	
	elif not is_grounded:
		if is_crouching:
			current_state = State.IN_AIR_CROUCHING
		elif player.is_on_wall() and is_surface_too_steep(player.get_wall_normal()):
			current_state = State.SURFING
		else:
			current_state = State.IN_AIR
		
	elif input.move_direction == Vector2.ZERO:
		current_state = State.CROUCHING_IDLE if is_crouching else State.IDLE
	
	else:
		if is_crouching and is_sprinting:
			current_state = State.CROUCHING_SPRINTING
		elif is_crouching:
			current_state = State.CROUCHING
		elif is_sprinting:
			current_state = State.SPRINTING
		else:
			current_state = State.WALKING


## Triggered exactly once per state change. 
func _on_state_transition(old_state: State, new_state: State) -> void:
	var was_nocliping : bool = old_state in [State.NOCLIPING, State.NOCLIPING_SPRINTING]
	var is_nocliping  : bool = new_state in [State.NOCLIPING, State.NOCLIPING_SPRINTING]
	
	if is_nocliping:
		collision_shape.set_deferred("disabled", true)
	elif was_nocliping:
		collision_shape.set_deferred("disabled", false)
	
	if new_state == State.SURFING:
		player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	elif old_state == State.SURFING:
		player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	var was_crouching : bool = old_state in [State.CROUCHING_IDLE, State.CROUCHING, State.CROUCHING_SPRINTING, State.IN_AIR_CROUCHING]
	var is_crouching  : bool = new_state in [State.CROUCHING_IDLE, State.CROUCHING, State.CROUCHING_SPRINTING, State.IN_AIR_CROUCHING]
	var is_grounded   : bool = player.is_on_floor() or _snapped_to_stairs_last_frame
	
	if is_crouching and not was_crouching:
		if not is_grounded: _enter_air_crouch()
		else: _enter_crouch()
	elif was_crouching and not is_crouching:
		if not is_grounded: _exir_air_crouch()
		else: _exit_crouch()
#endregion


#region Physics Handlers
## Abstracted ground execution to keep the match statement on _physics_process perfectly readable
func _execute_ground_state(delta: float) -> void:
	if input.jump_pressed or (auto_bhop and input.jump_held):
		player.velocity.y = jump_velocity
		_snapped_to_stairs_last_frame = false                                   # Jumping intentionally breaks stair logic 
	
	_handle_ground_physics(delta)                                               # First thing to do
	if not _snap_up_stairs_check(delta):                                        # We shall not call move_and_slide when snappin up stairs (TODO: Check if this messes up with pushing objects up stairs)
		var pre_slide_velocity : Vector3 = player.velocity                      # Needs to be registered in order to push away rigid bodies after move_and_slide. move_and_slide zeros out the velocity.  
		player.move_and_slide()
		physics_interactor.push_away_rigid_bodies(pre_slide_velocity)
		_snap_down_to_stairs_check()


## Abstracted air execution  to keep the match statement on _physics_process perfectly readable
func _execute_air_state(delta: float) -> void:
	_handle_air_physics(delta)                                                  # First thing to do            
	var pre_slide_velocity : Vector3 = player.velocity                          # Needs to be registered in order to push away rigid bodies after move_and_slide. move_and_slide zeros out the velocity.              
	player.move_and_slide()
	physics_interactor.push_away_rigid_bodies(pre_slide_velocity)


## Helper to fetch the current scalar speed limit based on state.
func get_move_speed() -> float:
	match current_state:
		State.IDLE, State.CROUCHING_IDLE:
			return 0.0                                                          # WARNING: Probably won't be an issue, but might impact on sliding on ice like surfaces
		State.WALKING:
			return walk_speed
		State.SPRINTING:
			return sprint_speed
		State.CROUCHING:
			return walk_speed * crouch_speed_multiplier
		State.CROUCHING_SPRINTING:
			return sprint_speed * crouch_speed_multiplier
		State.NOCLIPING:
			return walk_speed * noclip_speed_multiplier
		State.NOCLIPING_SPRINTING:
			return sprint_speed * noclip_speed_multiplier
		_:
			print("WARNING: There is no mapped speed for the current state")
			return 0.0


## Handles friction and vector-projected acceleration while the player is on solid geometry.
func _handle_ground_physics(delta: float) -> void:
	# Quake-style dot product projection to calculate acceleration room
	var current_speed_in_wished_direction : float = player.velocity.dot(input.wished_direction)
	var add_speed_till_cap : float = get_move_speed() - current_speed_in_wished_direction  
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = ground_accel * get_move_speed() * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		player.velocity += accelerated_speed * input.wished_direction
	
	# Apply friction
	var control   : float = max(player.velocity.length(), ground_decel)
	var drop      : float = control * ground_friction * delta
	var new_speed : float = max(player.velocity.length() - drop, 0.0)
	
	if player.velocity.length() > 0:
		new_speed /= player.velocity.length() # new_speed is now the ratio new_speed/old_speed
	player.velocity *= new_speed


## Handles gravity and high-maneuverability air-strafing acceleration.
func _handle_air_physics(delta: float) -> void:
	player.velocity.y += player.get_gravity().y * delta                                  
	
	var current_speed_in_wished_direction : float = player.velocity.dot(input.wished_direction)
	var capped_speed : float = minf((air_move_speed * input.wished_direction).length(), air_cap)
	var add_speed_till_cap : float = capped_speed - current_speed_in_wished_direction
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = air_accel * air_move_speed * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		player.velocity += accelerated_speed * input.wished_direction
	
	# Allows Surf execution WARNING: Surf is causing some headaches. Caution with it
	if current_state == State.SURFING:
		clip_velocity(player.get_wall_normal(), 1.0)


## Applies unhindered, camera-aligned freecam movement for debugging.
func _handle_noclip() -> void:
	player.velocity = input.camera_aligned_wished_direction * get_move_speed()
#endregion


#region Utilities
## Redirects momentum away from steep normals to prevent dead-stops, allowing for Source-style sliding.
func clip_velocity(normal : Vector3, overbounce : float) -> void:
	var backoff : float = player.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	var change : Vector3 = normal * backoff
	player.velocity -= change
	var adjust : float = player.velocity.dot(normal)
	if adjust < 0.0:
		player.velocity -= normal * adjust


## Evaluates if a given geometric normal is too steep for the CharacterBody to stand on.
func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > player.floor_max_angle


## Checks if we are going to collide with the next step
func _run_body_test_motion(from : Transform3D, motion : Vector3, result : PhysicsTestMotionResult3D = null) -> bool:
	if not result:
		result = PhysicsTestMotionResult3D.new()
	var parameters : PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	return PhysicsServer3D.body_test_motion(player.get_rid(), parameters, result)
#endregion


# ==========================================
# PRIVATE
# ==========================================
#region Crouch Handlers
func _enter_crouch() -> void:
	collision_shape.shape.height = _origina_capsule_height - crouch_translate
	collision_shape.position.y   = collision_shape.shape.height / 2.0  


func _exit_crouch() -> void:
	collision_shape.shape.height = _origina_capsule_height
	collision_shape.position.y   = collision_shape.shape.height / 2.0 


func _enter_air_crouch() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	player.test_move(player.transform, Vector3(0.0, +crouch_jump_add, 0.0), collision_result)
	
	player.position.y += collision_result.get_travel().y   
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -crouch_translate, 0) 
	_enter_crouch()


func _exir_air_crouch() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	player.test_move(player.transform, Vector3(0.0, -crouch_jump_add, 0.0), collision_result)
	
	player.position.y += collision_result.get_travel().y   
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -crouch_translate, 0)
	_exit_crouch()


func _can_exit_crouch() -> bool:
	return not player.test_move(player.transform, Vector3(0.0, crouch_translate, 0.0))
#endregion


#region Stair Handlers
func _snap_down_to_stairs_check() -> void:
	var did_snap                : bool  = false
	var floor_below             : bool  = stairs_below_ray.is_colliding() and not is_surface_too_steep(stairs_below_ray.get_collision_normal())
	# We request physics frames from Engine directly
	# Note: This relies on the _last_frame_was_on_floor tracking done in player.gd manager
	var was_on_floor_last_frame : float = Engine.get_physics_frames() - player._last_frame_was_on_floor == 1
	
	if not player.is_on_floor() and player.velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result : PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(player.global_transform, Vector3(0, -max_step_height, 0), body_test_result):
			var camera_controller : PlayerCameraController = $"../CameraController"
			camera_controller._save_camera_position_for_smoothing()
			var translate_y : float = body_test_result.get_travel().y
			player.position.y += translate_y
			player.apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap


func _snap_up_stairs_check(delta : float) -> bool:
	if not player.is_on_floor() and not _snapped_to_stairs_last_frame: return false
	if player.velocity.y > 0 or (player.velocity * Vector3(1,0,1)).length() == 0: return false
	
	var expected_move_motion : Vector3= player.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance : Transform3D = player.global_transform.translated(expected_move_motion + Vector3(0, max_step_height * 2, 0))
	var down_check_result : KinematicCollision3D = KinematicCollision3D.new()
	
	if (player.test_move(step_pos_with_clearance, Vector3(0,-max_step_height*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height : float = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - player.global_position).y
		if step_height > max_step_height or step_height <= 0.01 or (down_check_result.get_position() - player.global_position).y > max_step_height: return false
		stairs_ahead_ray.global_position = down_check_result.get_position() + Vector3(0,max_step_height,0) + expected_move_motion.normalized() * 0.1
		stairs_ahead_ray.force_raycast_update()
		
		if stairs_ahead_ray.is_colliding() and not is_surface_too_steep(stairs_ahead_ray.get_collision_normal()):
			var camera_controller : PlayerCameraController = $"../CameraController"
			camera_controller._save_camera_position_for_smoothing()
			player.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			player.apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false
#endregion
