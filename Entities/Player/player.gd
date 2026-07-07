extends CharacterBody3D
#TODO: Jumping into stairs makes the player go to the SURFING state. This makes the player unable to go up the stairs without moving around a little bit.
#TODO: Maybe I should remove the surfing thing... I don't really pretend on using it as a mechanic. Or I could turn its functionality everytime the player is in air by calling the clip_velocity function, because having SURFING as a state is kinda being a pain in the ass.
#TODO: Add something like a PlayerGround enum to know where the player is walking on.

# ==========================================
# ENUMS & STATES
# ==========================================
enum PlayerState { IDLE, WALKING, SPRINTING, CROUCHING_IDLE, CROUCHING, CROUCHING_SPRINTING, IN_AIR, IN_AIR_CROUCHING, SURFING, NOCLIPING, NOCLIPING_SPRINTING }
var current_state  : PlayerState = PlayerState.IDLE
var previous_state : PlayerState = PlayerState.IDLE



# ==========================================
# INPUT STRUCTURE 
# ==========================================
## A pure data container. Holds the player's exact hardware input for the current frame.
class PlayerInput:
	# Movement
	var move_direction                  : Vector2 = Vector2.ZERO
	var wished_direction                : Vector3 = Vector3.ZERO
	var camera_aligned_wished_direction : Vector3 = Vector3.ZERO
	var controller_look                 : Vector2 = Vector2.ZERO
	var jump_pressed                    : bool    = false
	var jump_held                       : bool    = false
	var sprint_held                     : bool    = false
	var crouch_held                     : bool    = false
	
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
@onready var collision_shape         : CollisionShape3D = %CollisionShape3D
@onready var world_model             : Node3D           = %WorldModel
@onready var head                    : Node3D           = %Head
@onready var camera_smooth_point     : Node3D           = %CameraSmoothPoint
@onready var camera                  : Camera3D         = %Camera3D 
@onready var stairs_ahead_ray        : RayCast3D        = %StairsAheadRayCast3D
@onready var stairs_below_ray        : RayCast3D        = %StairsBelowRayCast3D
@onready var debug_label             : Label            = %DebugLabel           #DEBUG
@onready var player_input            : PlayerInput      = PlayerInput.new()
@onready var _origina_capsule_height : float            = collision_shape.shape.height
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
@export var auto_bhop               : bool  = false
@export var auto_sprint             : bool  = true
@export var walk_speed              : float = 7.0
@export var sprint_speed            : float = 8.5
@export var ground_accel            : float = 14.0
@export var ground_decel            : float = 10.0
@export var ground_friction         : float = 6.0
@export var max_step_height         : float = 0.5
@export var crouch_translate        : float = 0.7
@export var crouch_jump_add         : float = 0.7 * 0.9                         ## Always set as crouch_translate * something. In this case crouch_jump_add = crouch_translate * 0.9
@export var crouch_speed_multiplier : float = 0.8
@export var weight                  : float = 80.0                              ## For physics interaction. Define in editor
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

@onready var noclip_reset_speed_multiplier   : float = noclip_speed_multiplier 
#endregion



# ==========================================
# CORE LOOP
# ==========================================
#region Core Engine Functions
## Called when the node enters the scene tree for the first time.
## Sets up visual masking so the player doesn't see their own 3D model clipping through the camera.
## Forces self.safe_margin = 0.0001 to prevent jittering when pushing objects.
func _ready() -> void:
	self.safe_margin = 0.0001
	for child : VisualInstance3D in world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false) 
		child.set_layer_mask_value(2, true)


## Listens for hardware events that aren't tied to the physics tick (like mouse movement).
## Handles mouse capture and direct camera rotation.
func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture logic (TODO: Needs to be upgraded later when adding UI)
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Mouse look logic (TODO: Add an invert mouse option and quality of life stuff like that)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * look_sensitivity)
			camera.rotate_x(-event.relative.y * look_sensitivity)
			camera.rotation_degrees.x = clampf(camera.rotation_degrees.x, -90, +90)


## The visual frame loop. Used exclusively for updating UI and controller-based camera smoothing.
func _process(delta: float) -> void:
	_handle_controller_look_input(delta)
	debug_label.text  = "FPS: " + str(Engine.get_frames_per_second())           + "\n"              # For DEBUG purpouses. TODO: Need to find a way to enable/disable these things
	debug_label.text += "STATE: " + str(PlayerState.keys()[current_state])      + "\n"              # For DEBUG purpouses.
	debug_label.text += "VELOCITY: " + str(("%.2f" % self.velocity.length()))   + "\n"              # For DEBUG purpouses.
	debug_label.text += "POSITION: (" + str("%.2f" % self.global_position.x) + "," + str("%.2f" % self.global_position.y) + "," + str("%.2f" % self.global_position.z) + ")\n"              # For DEBUG purpouses.

## The rigid physics loop. Orchestrates the input gathering, state evaluation, and physics execution pipeline.
func _physics_process(delta: float) -> void:
	_gather_inputs()                                                            # Updates the player_input data structure
	_handle_toggles_and_settings()                                              # Process non-state settings (noclip speed multipliers/UI toggles)
	
	# Process State Machine and Transitions
	previous_state = current_state
	_update_player_state()          
	
	if previous_state != current_state: 
		_on_state_transition(previous_state, current_state)
	
	# Execute Physics based strictly on FSM
	match current_state: 
		PlayerState.IDLE, PlayerState.WALKING, PlayerState.SPRINTING, PlayerState.CROUCHING_IDLE, PlayerState.CROUCHING, PlayerState.CROUCHING_SPRINTING:
			_execute_ground_state(delta)
		PlayerState.IN_AIR, PlayerState.SURFING, PlayerState.IN_AIR_CROUCHING:
			_execute_air_state(delta)
		PlayerState.NOCLIPING, PlayerState.NOCLIPING_SPRINTING:
			_handle_noclip()
			move_and_slide()
			
	_slide_camera_smooth_back_to_origin(delta)
	_handle_crouch_camera_smoothing(delta) 
	
	# Update frame tracking for the downward stair raycast
	if is_on_floor():
		_last_frame_was_on_floor = Engine.get_physics_frames()
#endregion



# ==========================================
# ARCHITECTURE METHODS
# ==========================================
#region Architecture Handlers
#region Physics Encapsulation Calls
## Abstracted ground execution to keep the match statement on _physics_process perfectly readable
func _execute_ground_state(delta: float) -> void:
	# Handles Jump
	if player_input.jump_pressed or (auto_bhop and player_input.jump_held):
		velocity.y = jump_velocity
		_snapped_to_stairs_last_frame = false                                   # Jumping intentionally breaks stair logic 
	
	_handle_ground_physics(delta)                                               # First thing to do
	if not _snap_up_stairs_check(delta):                                        # We shall not call move_and_slide when snappin up stairs (TODO: Check if this messes up with pushing objects up stairs)
		var pre_slide_velocity : Vector3 = self.velocity                        # Needs to be registered in order to push away rigid bodies after move_and_slide. move_and_slide zeros out the velocity.
		move_and_slide()
		_push_away_rigid_bodies(pre_slide_velocity)
		_snap_down_to_stairs_check()


## Abstracted air execution  to keep the match statement on _physics_process perfectly readable
func _execute_air_state(delta: float) -> void:
	_handle_air_physics(delta)                                                  # First thing to do
	var pre_slide_velocity : Vector3 = self.velocity                            # Needs to be registered in order to push away rigid bodies after move_and_slide. move_and_slide zeros out the velocity.
	move_and_slide()
	_push_away_rigid_bodies(pre_slide_velocity)
#endregion


#region Inputs
## Polls the OS/Engine for hardware state and populates the PlayerInput struct.
## Does ZERO logic or mathematical mutation.
func _gather_inputs() -> void:
	# Hardware Polling
	player_input.move_direction          = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	player_input.jump_pressed            = Input.is_action_just_pressed("jump")
	player_input.jump_held               = Input.is_action_pressed("jump")
	player_input.sprint_held             = Input.is_action_pressed("sprint")
	player_input.crouch_held             = Input.is_action_pressed("crouch")
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
#endregion


#region State Handling
## Pure logic tree that determines what the player *is doing* based on physics flags and input intent.[br]
## Modifies `current_state` but does not execute movement.
func _update_player_state() -> void:
	var is_grounded   : bool = is_on_floor() or _snapped_to_stairs_last_frame
	var is_sprinting  : bool = (player_input.sprint_held and not auto_sprint) or (auto_sprint and not player_input.sprint_held)
	var was_crouching : bool = current_state in [PlayerState.CROUCHING_IDLE, PlayerState.CROUCHING, PlayerState.CROUCHING_SPRINTING, PlayerState.IN_AIR_CROUCHING]
	var is_crouching  : bool = player_input.crouch_held or (was_crouching and not _can_exit_crouch())
	
	# WARNING: The order of this if/elif/else statement matters!
	if can_noclip and noclip:
		current_state = PlayerState.NOCLIPING_SPRINTING if is_sprinting else PlayerState.NOCLIPING
	
	elif not is_grounded:
		if is_crouching:
			current_state = PlayerState.IN_AIR_CROUCHING
		elif is_on_wall() and is_surface_too_steep(get_wall_normal()):
			current_state = PlayerState.SURFING
		else:
			current_state = PlayerState.IN_AIR
		
	elif player_input.move_direction == Vector2.ZERO:
		current_state = PlayerState.CROUCHING_IDLE if is_crouching else PlayerState.IDLE
	
	else:
		if is_crouching and is_sprinting:
			current_state = PlayerState.CROUCHING_SPRINTING
		elif is_crouching:
			current_state = PlayerState.CROUCHING
		elif is_sprinting:
			current_state = PlayerState.SPRINTING
		else:
			current_state = PlayerState.WALKING


## Triggered exactly once per state change. 
## Used to safely toggle environmental properties (like hitboxes or motion modes) without spamming the engine.
func _on_state_transition(old_state: PlayerState, new_state: PlayerState) -> void:
	# Noclip hitboxes
	var was_nocliping : bool = old_state in [PlayerState.NOCLIPING, PlayerState.NOCLIPING_SPRINTING]
	var is_nocliping  : bool = new_state in [PlayerState.NOCLIPING, PlayerState.NOCLIPING_SPRINTING]
	
	if is_nocliping:
		collision_shape.set_deferred("disabled", true)
	elif was_nocliping:
		collision_shape.set_deferred("disabled", false)
	
	# Surf gravity anchor overrides
	if new_state == PlayerState.SURFING:
		self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	elif old_state == PlayerState.SURFING:
		self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	# Crouching
	var was_crouching : bool = old_state in [PlayerState.CROUCHING_IDLE, PlayerState.CROUCHING, PlayerState.CROUCHING_SPRINTING, PlayerState.IN_AIR_CROUCHING]
	var is_crouching  : bool = new_state in [PlayerState.CROUCHING_IDLE, PlayerState.CROUCHING, PlayerState.CROUCHING_SPRINTING, PlayerState.IN_AIR_CROUCHING]
	var is_grounded   : bool = is_on_floor() or _snapped_to_stairs_last_frame
	
	if is_crouching and not was_crouching:
		if not is_grounded: _enter_air_crouch()
		else: _enter_crouch()                                           
	elif was_crouching and not is_crouching:
		if not is_grounded: _exir_air_crouch()
		else: _exit_crouch()
#endregion
#endregion



# ==========================================
# MOVEMENT LOGIC
# ==========================================
#region Physics Handlers
## Helper to fetch the current scalar speed limit based on state.
func get_move_speed() -> float:
	match current_state:
		PlayerState.IDLE, PlayerState.CROUCHING_IDLE:
			return 0.0                                                          # WARNING: Probably won't be an issue, but might impact on sliding on ice like surfaces
		PlayerState.WALKING:
			return walk_speed
		PlayerState.SPRINTING:
			return sprint_speed
		PlayerState.CROUCHING:
			return walk_speed * crouch_speed_multiplier
		PlayerState.CROUCHING_SPRINTING:
			return sprint_speed * crouch_speed_multiplier
		PlayerState.NOCLIPING:
			return walk_speed * noclip_speed_multiplier
		PlayerState.NOCLIPING_SPRINTING:
			return sprint_speed * noclip_speed_multiplier
		_:
			print("WARNING: There is no mapped speed for the current state")
			return 0.0


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
	
	if headbob: _headbob_effect(delta) 


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
	
	# Allows Surf execution WARNING: Surf is causing some headaches. Caution with it
	if current_state == PlayerState.SURFING:
		clip_velocity(get_wall_normal(), 1.0)


## Applies unhindered, camera-aligned freecam movement for debugging.
func _handle_noclip() -> void:
	self.velocity = player_input.camera_aligned_wished_direction * get_move_speed()



# TODO: If the player runs in circles on top of a box, it will start spinning because the players friction is applied on the box.
# We will need a custom code in the props so that they can handle these kind of edge cases.
## Call after move_and_slide() so get_slide_collision is populated.
func _push_away_rigid_bodies(pre_slide_velocity : Vector3) -> void:
	for i : int in get_slide_collision_count():
		var collision : KinematicCollision3D = get_slide_collision(i)
		var collider  : RigidBody3D = collision.get_collider() if collision.get_collider() is RigidBody3D else null
		
		if collider == null: continue
		
		# HEIGHT THRESHOLD CHECK
		var contact_height_from_feet : float = collision.get_position().y - self.global_position.y  # Check where the collision happened on the Y axis relative to our feet.
		if contact_height_from_feet < 0.25: continue                                                # If the contact point is less than 25cm from feet, we are stepping on the collider. Completely ignore lateral pushes for feet, preventing the capsule from kicking boxes out from under itself when walking near the edge.
		
		# DIRECTIONAL CALCULATION
		var push_direction : Vector3 = -collision.get_normal()
		push_direction.y = 0.0                                                                      # Zero out Y, because pushing objects downward into the floor causes physics glitches.
		push_direction = push_direction.normalized()
		
		# VELOCITY DIFFERENTIAL
		var player_velocity_into_object : float = pre_slide_velocity.dot(push_direction)
		var object_velocity_into_player : float = collider.linear_velocity.dot(push_direction)      
		var velocity_difference : float = player_velocity_into_object - object_velocity_into_player
		if velocity_difference <= 0.0: continue                                                     # If difference <= 0, the box is already moving away faster than we are walking
		
		# MOMENTUM CONSERVATION
		var required_impuse : float = collider.mass * velocity_difference
		var max_push_impulse: float = self.weight * 2.0                                             # TODO: Magic number that defines our force
		var applied_impulse : float = min(required_impuse, max_push_impulse)                        # We get the min so we don't use the required_push_impulse if we are too weak compared to the object
		
		var push_force : Vector3 = push_direction * applied_impulse
		
		collider.apply_central_impulse(push_force)
		#collider.apply_impulse(push_force, collision.get_position() - collider.global_position)    # DEPRECATED: Incocsiten as fuck

#region Crouch Handlers
func _enter_crouch() -> void:
	# Shrink the capsule and shift it downward so the bottom stays on the floor
	collision_shape.shape.height = _origina_capsule_height - crouch_translate
	collision_shape.position.y   = collision_shape.shape.height / 2.0  #TODO: Magic number


func _exit_crouch() -> void:
	# Restore the capsule and shift it upward
	collision_shape.shape.height = _origina_capsule_height
	collision_shape.position.y   = collision_shape.shape.height / 2.0 #TODO: Magic number


func _enter_air_crouch() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	self.test_move(self.transform, Vector3(0.0, +crouch_jump_add, 0.0), collision_result)
	
	self.position.y += collision_result.get_travel().y   # Avoids going through the ceil/ground
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -crouch_translate, 0) 
	_enter_crouch()


func _exir_air_crouch() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	self.test_move(self.transform, Vector3(0.0, -crouch_jump_add, 0.0), collision_result)
	
	self.position.y += collision_result.get_travel().y   # Avoids going through the ceil/ground
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -crouch_translate, 0)
	_exit_crouch()


func _can_exit_crouch() -> bool:
	return not self.test_move(self.transform, Vector3(0.0, crouch_translate, 0.0))
#endregion
#endregion




# ==========================================
# KINEMATIC STAIR LOGIC
# ==========================================
#region Stair Handling
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

func _handle_crouch_camera_smoothing(delta : float) -> void:
	var is_crouching : bool = current_state in [PlayerState.CROUCHING_IDLE, PlayerState.CROUCHING, PlayerState.CROUCHING_SPRINTING, PlayerState.IN_AIR_CROUCHING]
	var target_y : float = -crouch_translate if is_crouching else 0.0
	head.position.y = move_toward(head.position.y, target_y, 7.0 * delta)

#endregion
