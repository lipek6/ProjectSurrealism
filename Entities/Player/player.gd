extends CharacterBody3D

# ==========================================
# ENUMS & STATES
# ==========================================
enum PlayerState { IDLE, WALKING, SPRINTING, IN_AIR, SURFING, NOCLIPING }
var current_state  : PlayerState = PlayerState.IDLE
var previous_state : PlayerState = PlayerState.IDLE



# ==========================================
# INPUT STRUCTURE 
# ==========================================
# A pure data container. Holds the player's exact hardware input for the current frame.
class PlayerInput:
	# Movement
	var move_direction                  : Vector2 = Vector2.ZERO
	var wished_direction                : Vector3 = Vector3.ZERO
	var camera_aligned_wished_direction : Vector3 = Vector3.ZERO
	var controller_look                 : Vector2 = Vector2.ZERO
	var jump_pressed                    : bool    = false
	var jump_held                       : bool    = false       
	
	# Settings & Toggles
	var toggle_sprint_pressed           : bool    = false
	var toggle_noclip_pressed           : bool    = false
	var noclip_increase_pressed         : bool    = false
	var noclip_decrease_pressed         : bool    = false



# ==========================================
# NODE REFERENCES
# ==========================================
# Caching nodes here prevents expensive tree lookups every frame.
#region Node References
@onready var collision           : CollisionShape3D = %CollisionShape3D
@onready var world_model         : Node3D           = %WorldModel
@onready var head                : Node3D           = %Head
@onready var camera_smooth_point : Node3D           = %CameraSmoothPoint
@onready var camera              : Camera3D         = %Camera3D 
@onready var stairs_ahead_ray    : RayCast3D        = %StairsAheadRayCast3D
@onready var stairs_below_ray    : RayCast3D        = %StairsBelowRayCast3D
@onready var fps_label           : Label            = %FPS
@onready var player_input        : PlayerInput      = PlayerInput.new()
#endregion



# ==========================================
# EXPORTED PARAMETERS
# ==========================================
#region Camera Settings
@export_group("Camera")
@export var look_sensitivity            : float = 0.006
@export var controller_look_sensitivity : float = 0.075
@export var headbob                     : bool  = true

const HEADBOB_MOVE_AMOUNT : float = 0.06
const HEADBOB_FREQUNCY    : float = 2.4
var headbob_time          : float = 0.0

var _saved_camera_global_position : Vector3 = Vector3.INF
#endregion


#region Ground Movement
@export_group("Ground Movement")
@export var auto_bhop       : bool  = true
@export var auto_sprint     : bool  = true
@export var walk_speed      : float = 7.0
@export var sprint_speed    : float = 8.5
@export var ground_accel    : float = 14.0
@export var ground_decel    : float = 10.0
@export var ground_friction : float = 6.0
@export var max_step_height : float = 0.5          # NEW CODE
var _snapped_to_stairs_last_frame : bool  = false
var _last_frame_was_on_floor      : float = -INF
#endregion


#region Air movement
@export_group("Air Movement")
@export var jump_velocity  : float = 6.0
@export var air_cap        : float = 0.85
@export var air_accel      : float = 800.0
@export var air_move_speed : float = 500.0
#endregion


#region Degub
@export_group("Debug")
@export var can_noclip                       : bool  = false
@export var noclip                           : bool  = false
@export var noclip_max_speed                 : float = 100.0
@export var noclip_min_speed                 : float = 0.1
@export var noclip_speed_multiplier          : float = 3.0
@export var noclip_speed_increase_multiplier : float = 1.1
@export var noclip_speed_decrease_multiplier : float = 0.9

@onready var noclip_reset_speed_multiplier   : float   = noclip_speed_multiplier 
#endregion



# ==========================================
# CORE LOOP
# ==========================================
#region Core Engine Functions
## Called when the node enters the scene tree for the first time.
## Sets up visual masking so the player doesn't see their own 3D model clipping through the camera.
func _ready() -> void:
	for child : VisualInstance3D in world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false) 
		child.set_layer_mask_value(2, true)


## Listens for hardware events that aren't tied to the physics tick (like mouse movement).
## Handles mouse capture and direct camera rotation.
func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture logic
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Mouse look logic
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * look_sensitivity)
			camera.rotate_x(-event.relative.y * look_sensitivity)
			camera.rotation_degrees.x = clampf(camera.rotation_degrees.x, -90, +90)


## The visual frame loop. Used exclusively for updating UI and controller-based camera smoothing.
func _process(delta: float) -> void:
	_handle_controller_look_input(delta)
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


## The rigid physics loop. Orchestrates the input gathering, state evaluation, and physics execution pipeline.
func _physics_process(delta: float) -> void:
	print(_last_frame_was_on_floor)
	_gather_inputs()                # Update the player_input data structure
	_handle_toggles_and_settings()  # Process non-state settings (noclip speed multipliers/UI toggles)
	
	# Process State Machine and Transitions
	previous_state = current_state
	_update_player_state()          
	
	if previous_state != current_state: 
		_on_state_transition(previous_state, current_state)
	
	
	# Execute Physics 
	match current_state: 
		PlayerState.IDLE, PlayerState.WALKING, PlayerState.SPRINTING: # should have a "or _snapped_to_stairs_last_frame" here
			if player_input.jump_pressed or (auto_bhop and player_input.jump_held):
				velocity.y = jump_velocity       
			_handle_ground_physics(delta)
		
		PlayerState.IN_AIR, PlayerState.SURFING:
			_handle_air_physics(delta)
			
		PlayerState.NOCLIPING:
			_handle_noclip()
	if _snapped_to_stairs_last_frame:
		if player_input.jump_pressed or (auto_bhop and player_input.jump_held):
			velocity.y = jump_velocity       
		_handle_ground_physics(delta)

			
			
	if not _snap_up_stairs_check(delta):
		move_and_slide()
		_snap_down_to_stairs_check()
	
	_slide_camera_smooth_back_to_origin(delta)
#endregion



# ==========================================
# ARCHITECTURE METHODS
# ==========================================
#region Architecture Handlers
## Polls the OS/Engine for hardware state and populates the PlayerInput struct.
## Does ZERO logic or mathematical mutation.
func _gather_inputs() -> void:
	# Hardware Polling
	player_input.move_direction          = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	player_input.jump_pressed            = Input.is_action_just_pressed("jump")
	player_input.jump_held               = Input.is_action_pressed("jump")
	player_input.toggle_sprint_pressed   = Input.is_action_just_pressed("toggle_sprint")
	player_input.toggle_noclip_pressed   = Input.is_action_just_pressed("_noclip")
	player_input.noclip_increase_pressed = Input.is_action_just_pressed("_increase_noclip_speed")
	player_input.noclip_decrease_pressed = Input.is_action_just_pressed("_decrease_noclip_speed")
	
	# Vector Translations
	player_input.wished_direction = self.global_basis * Vector3(player_input.move_direction.x, 0, player_input.move_direction.y)
	player_input.camera_aligned_wished_direction = camera.global_basis * Vector3(player_input.move_direction.x, 0, player_input.move_direction.y)


## Reads the PlayerInput struct and applies any changes to global settings or debugging variables.
func _handle_toggles_and_settings() -> void:
	# Sprint Toggle
	if player_input.toggle_sprint_pressed:
		auto_sprint = not auto_sprint
	
	# Noclip Activation
	if can_noclip and player_input.toggle_noclip_pressed:
		noclip_speed_multiplier = noclip_reset_speed_multiplier
		noclip = not noclip
	
	# Noclip Speed Tuning
	if can_noclip and noclip:
		if player_input.noclip_increase_pressed:
			noclip_speed_multiplier = minf(noclip_max_speed, noclip_speed_multiplier * noclip_speed_increase_multiplier) 
		elif player_input.noclip_decrease_pressed:
			noclip_speed_multiplier = maxf(noclip_min_speed, noclip_speed_multiplier * noclip_speed_decrease_multiplier)


## Pure logic tree that determines what the player *is doing* based on physics flags and input intent.
## Modifies `current_state` but does not execute movement.
func _update_player_state() -> void:
	if can_noclip and noclip:
		current_state = PlayerState.NOCLIPING
	elif is_on_wall() and is_surface_too_steep(get_wall_normal()):
		current_state = PlayerState.SURFING
	elif not is_on_floor():
		current_state = PlayerState.IN_AIR
	elif player_input.move_direction == Vector2.ZERO:
		current_state = PlayerState.IDLE
	else:
		var is_sprinting : bool = Input.is_action_pressed("sprint") if not auto_sprint else not Input.is_action_pressed("sprint")
		current_state = PlayerState.SPRINTING if is_sprinting else PlayerState.WALKING
	
	#print(PlayerState.keys()[current_state]) # DEBUG


## Triggered exactly once per state change. 
## Used to safely toggle environmental properties (like hitboxes or motion modes) without spamming the engine.
func _on_state_transition(old_state: PlayerState, new_state: PlayerState) -> void:
	# Noclip hitboxes
	if new_state == PlayerState.NOCLIPING:
		collision.set_deferred("disabled", true)
	elif old_state == PlayerState.NOCLIPING:
		collision.set_deferred("disabled", false)
	
	# Surf gravity anchor overrides
	if new_state == PlayerState.SURFING:
		self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	elif old_state == PlayerState.SURFING:
		self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
#endregion



# ==========================================
# MOVEMENT LOGIC
# ==========================================
#region Physics Handlers
## Helper to fetch the current scalar speed limit based on state.
func get_move_speed() -> float:
	if current_state == PlayerState.SPRINTING:
		return sprint_speed
	else:
		return walk_speed


## Handles friction and vector-projected acceleration while the player is on solid geometry.
func _handle_ground_physics(delta: float) -> void:
	# Quake-style dot product projection to calculate acceleration room
	var current_speed_in_wished_direction : float = self.velocity.dot(player_input.wished_direction)
	var add_speed_till_cap : float = get_move_speed() - current_speed_in_wished_direction  # Determines how much room is left to accelerate before hitting the speed limit.
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = ground_accel * get_move_speed() * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		self.velocity += accelerated_speed * player_input.wished_direction
	
	# Apply friction
	var control   : float = max(self.velocity.length(), ground_decel)
	var drop      : float = control * ground_friction * delta
	var new_speed : float = max(self.velocity.length() - drop, 0.0)
	
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length() # new_speed is now the ratio new_speed/old_speed
	self.velocity *= new_speed
	
	if headbob: _headbob_effect(delta) #TODO
	
	_last_frame_was_on_floor = Engine.get_physics_frames() # Is this suppoused to be here in this function? I think it's better than putting it on _physics_process
	
## Handles gravity and high-maneuverability air-strafing acceleration.
func _handle_air_physics(delta: float) -> void:
	# Apply gravity
	self.velocity.y += get_gravity().y * delta                                  # Gravity is currently set to 12
	
	var current_speed_in_wished_direction : float = self.velocity.dot(player_input.wished_direction)
	var capped_speed : float = minf((air_move_speed * player_input.wished_direction).length(), air_cap)
	var add_speed_till_cap : float = capped_speed - current_speed_in_wished_direction
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = air_accel * air_move_speed * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		self.velocity += accelerated_speed * player_input.wished_direction
	
	# Allows Surf execution
	if current_state == PlayerState.SURFING:
		clip_velocity(get_wall_normal(), 1.0)


func _snap_down_to_stairs_check() -> void:
	var did_snap                : bool  = false
	var floor_below             : bool  = stairs_below_ray.is_colliding() and not is_surface_too_steep(stairs_below_ray.get_collision_normal())
	var was_on_floor_last_frame : float = Engine.get_physics_frames() - _last_frame_was_on_floor == 1
	
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result : PhysicsTestMotionResult3D = PhysicsTestMotionResult3D.new()
		if _run_body_test_motion(self.global_transform, Vector3(0, -max_step_height, 0), body_test_result):
			_save_camera_position_for_smoothing()
			var translate_y : float = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap

func _snap_up_stairs_check(delta : float) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion : Vector3= self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance : Transform3D = self.global_transform.translated(expected_move_motion + Vector3(0, max_step_height * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result : KinematicCollision3D = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-max_step_height*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height : float = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > max_step_height or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > max_step_height: return false
		stairs_ahead_ray.global_position = down_check_result.get_position() + Vector3(0,max_step_height,0) + expected_move_motion.normalized() * 0.1
		stairs_ahead_ray.force_raycast_update()
		if stairs_ahead_ray.is_colliding() and not is_surface_too_steep(stairs_ahead_ray.get_collision_normal()):
			_save_camera_position_for_smoothing()
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false





## Applies unhindered, camera-aligned freecam movement for debugging.
func _handle_noclip() -> void:
	collision.disabled = true
	var noclip_speed : float = get_move_speed() * noclip_speed_multiplier
	self.velocity = player_input.camera_aligned_wished_direction * noclip_speed
#endregion



# ==========================================
# UTILITIES & EFFECTS
# ==========================================
#region Utilities
## Redirects momentum away from steep normals to prevent dead-stops, allowing for Source-style sliding.
func clip_velocity(normal : Vector3, overbounce : float) -> void:
	var backoff : float = self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change : Vector3 = normal * backoff
	self.velocity -= change
	
	var adjust : float = self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust
	# floor_max_angle of CharacterBody3D is what defines how steep we are able to surf


## Evaluates if a given geometric normal is too steep for the CharacterBody to stand on.
func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle

# Checks if we are going to collide with the next step
func _run_body_test_motion(from : Transform3D, motion : Vector3, result : PhysicsTestMotionResult3D = null) -> bool:
	if not result:
		result = PhysicsTestMotionResult3D.new()
	
	var parameters : PhysicsTestMotionParameters3D = PhysicsTestMotionParameters3D.new()
	parameters.from = from
	parameters.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), parameters, result)


## Applies lerp-smoothed look rotation when using an analog gamepad stick.      # TODO: Add a not 1 or 0 move speed on the left joystick
func _handle_controller_look_input(delta: float) -> void:
	var target_look : Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	if target_look.length() < player_input.controller_look.length():                                      #TODO: Add a ON/OFF on this smoothing
		player_input.controller_look = target_look
	else:
		player_input.controller_look = player_input.controller_look.lerp(target_look, 5.0 * delta)        #TODO : Turn this 5.0 into a global setting
	
	self.rotate_y(-player_input.controller_look.x * controller_look_sensitivity)
	camera.rotate_x(player_input.controller_look.y * controller_look_sensitivity)
	camera.rotation_degrees.x = clampf(camera.rotation_degrees.x, -90, +90)


## Applies a procedural sine-wave translation to the camera to simulate footsteps.
func _headbob_effect(delta : float) -> void:
	headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       # X axis
		sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             # Y axis
		0                                                                       # Z axis
	) 
#endregion


func _save_camera_position_for_smoothing() -> void:
	if _saved_camera_global_position == Vector3.INF:
		_saved_camera_global_position = camera_smooth_point.global_position


func _slide_camera_smooth_back_to_origin(delta : float) -> void:
	if _saved_camera_global_position == Vector3.INF: return 
	
	camera_smooth_point.global_position.y = _saved_camera_global_position.y
	camera_smooth_point.position.y        = clampf(camera_smooth_point.position.y, -0.7, 0.7)       # Avoid teleporting
	var move_amount :float = maxf(self.velocity.length() * delta, walk_speed/2 * delta) 
	camera_smooth_point.position.y = move_toward(camera_smooth_point.position.y, 0.0, move_amount)
	
	if camera_smooth_point.position.y == 0:
		_saved_camera_global_position = Vector3.INF # Stop smoothing
