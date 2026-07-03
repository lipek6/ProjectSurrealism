extends CharacterBody3D

# ==========================================
# ENUMS & STATES
# ==========================================
enum PlayerState { IDLE, WALKING, SPRINTING, IN_AIR, SURFING }
var current_state : PlayerState = PlayerState.IDLE



# ==========================================
# NODE REFERENCES
# ==========================================
# Caching nodes here prevents expensive tree lookups every frame.
@onready var world_model : Node3D   = %WorldModel
@onready var head        : Node3D   = %Head
@onready var camera      : Camera3D = %Camera3D 
@onready var fps_label   : Label    = %FPS



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
#endregion


#region Air movement
@export_group("Air Movement")
@export var jump_velocity  : float = 6.0
@export var air_cap        : float = 0.85
@export var air_accel      : float = 800.0
@export var air_move_speed : float = 500.0
#endregion


# State Variables
var controller_look  : Vector2 = Vector2()           
var wished_direction : Vector3 = Vector3.ZERO


# ==========================================
# CORE LOOP
# ==========================================
#region Core Engine Functions
func _ready() -> void:
	# Hide the player model from the first-person camera using layer masks
	for child : VisualInstance3D in world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false) 
		child.set_layer_mask_value(2, true)


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
			head.rotate_x(-event.relative.y * look_sensitivity)
			head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, +90)


func _process(delta: float) -> void:
	_handle_controller_look_input(delta)
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())


func _physics_process(delta: float) -> void:
	# Gather Input
	var input_direction : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	wished_direction = self.global_basis * Vector3(input_direction.x, 0, input_direction.y)
	
	# Update State & Sprint Toggle
	if Input.is_action_just_pressed("toggle_sprint"): # PUT IN _update_player_state
		auto_sprint = !auto_sprint
	
	_update_player_state(input_direction)
	
	if self.is_on_floor():
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			velocity.y = jump_velocity       
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)	
	
	move_and_slide()
#endregion



# ==========================================
# MOVEMENT LOGIC
# ==========================================
#region Physics Handlers
func _update_player_state(input_dir: Vector2) -> void:
	# Surf Check
	if is_on_wall() and is_surface_too_steep(get_wall_normal()):
		current_state = PlayerState.SURFING
		self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	
	# Air Check
	elif not is_on_floor():
		current_state = PlayerState.IN_AIR
		self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	# Ground Idle Check
	elif input_dir == Vector2.ZERO:
		current_state = PlayerState.IDLE
		self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	# Ground Movement Check
	else:
		var is_sprinting : bool = Input.is_action_pressed("sprint") if not auto_sprint else not Input.is_action_pressed("sprint")
		current_state = PlayerState.SPRINTING if is_sprinting else PlayerState.WALKING
		self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	
	print(PlayerState.keys()[current_state]) # DEBUG


func get_move_speed() -> float:
	if current_state == PlayerState.SPRINTING:
		return sprint_speed
	else:
		return walk_speed



func _handle_ground_physics(delta: float) -> void:
	# Quake-style dot product projection to calculate acceleration room
	var current_speed_in_wished_direction : float = self.velocity.dot(wished_direction)
	var add_speed_till_cap : float = get_move_speed() - current_speed_in_wished_direction  # Determines how much room is left to accelerate before hitting the speed limit.
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = ground_accel * get_move_speed() * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		self.velocity += accelerated_speed * wished_direction
	
	# Apply friction
	var control   : float = max(self.velocity.length(), ground_decel)
	var drop      : float = control * ground_friction * delta
	var new_speed : float = max(self.velocity.length() - drop, 0.0)
	
	if self.velocity.length() > 0:
		new_speed /= self.velocity.length() # new_speed is now the ratio new_speed/old_speed
	self.velocity *= new_speed
	
	if headbob: _headbob_effect(delta)


func _handle_air_physics(delta: float) -> void:
	# Apply gravity
	self.velocity.y += get_gravity().y * delta                                  # Gravity is currently set to 12
	
	var current_speed_in_wished_direction : float = self.velocity.dot(wished_direction)
	var capped_speed : float = minf((air_move_speed * wished_direction).length(), air_cap)
	var add_speed_till_cap : float = capped_speed - current_speed_in_wished_direction
	
	if add_speed_till_cap > 0:
		var accelerated_speed : float = air_accel * air_move_speed * delta
		accelerated_speed = minf(accelerated_speed, add_speed_till_cap)
		self.velocity += accelerated_speed * wished_direction
	
	# Surf Logic
	if current_state == PlayerState.SURFING:
		clip_velocity(get_wall_normal(), 1, delta) # Allows surf
#endregion


# ==========================================
# UTILITIES & EFFECTS
# ==========================================
#region Utilities
func clip_velocity(normal : Vector3, overbounce : float, delta : float) -> void:
	var backoff : float = self.velocity.dot(normal) * overbounce
	if backoff >= 0: return
	
	var change : Vector3 = normal * backoff
	self.velocity -= change
	
	var adjust : float = self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust
	# floor_max_angle of CharacterBody3D is what defines how steep we are able to surf


func is_surface_too_steep(normal : Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle


# TODO: Add a not 1 or 0 move speed on the left joystick
func _handle_controller_look_input(delta: float) -> void:
	var target_look : Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	if target_look.length() < controller_look.length():                          #TODO: Add a ON/OFF on this smoothing
		controller_look = target_look
	else:
		controller_look = controller_look.lerp(target_look, 5.0 * delta)        #TODO : Turn this 5.0 into a global setting
	
	self.rotate_y(-controller_look.x * controller_look_sensitivity)
	head.rotate_x(controller_look.y * controller_look_sensitivity)
	head.rotation_degrees.x = clampf(head.rotation_degrees.x, -90, +90)


func _headbob_effect(delta : float) -> void:
	headbob_time += delta * self.velocity.length()
	camera.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       # X axis
		sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             # Y axis
		0                                                                       # Z axis
	) 
#endregion
