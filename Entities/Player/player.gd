extends CharacterBody3D

#TODO: Upgrade these exported parameters using sliders and @export_category()


@export var look_sensitivity      : float = 0.006
@export var controller_look_sensitivity : float = 0.05
@export var jump_velocity         : float = 6.0
@export var headbob               : bool  = true
@export var auto_bhop             : bool  = true
@export var auto_sprint           : bool  = true
@export var walk_speed            : float = 7.0
@export var sprint_speed          : float = 8.5


const HEADBOB_MOVE_AMOUNT    : float = 0.06
const HEADBOB_FREQUNCY       : float = 2.4
var headbob_time             : float = 0.0

var controller_look  : Vector2 = Vector2()           
var wished_direction : Vector3 = Vector3.ZERO

# Air movement settings. TWEAK!!!
@export var air_cap          : float = 0.85
@export var air_acceleration : float = 800.0
@export var air_move_speed   : float = 500.0



func get_move_speed() -> float:
	if auto_sprint:
		return walk_speed if Input.is_action_pressed("sprint") else sprint_speed
	else:
		return sprint_speed if Input.is_action_pressed("sprint") else walk_speed





func _ready() -> void:
	# Places WorldModel meshes in layer 2, so we can hide it from the camera
	for child : VisualInstance3D in %WorldModel.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, false) 
		child.set_layer_mask_value(2, true)





func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			self.rotate_y(-event.relative.x * look_sensitivity)
			%Head.rotate_x(-event.relative.y * look_sensitivity)
			%Head.rotation_degrees.x = clampf(%Head.rotation_degrees.x, -90, +90)





func _physics_process(delta: float) -> void:
	var input_direction : Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	wished_direction = self.global_basis * Vector3(input_direction.x, 0, input_direction.y)
	
	if Input.is_action_just_pressed("toggle_sprint"):
		auto_sprint = !auto_sprint
	
	if self.is_on_floor():
		if Input.is_action_just_pressed("jump") or (auto_bhop and Input.is_action_pressed("jump")):
			wished_direction.y += jump_velocity       # += or = might make a difference on complex physics enviromnent. I should test it
		_handle_ground_physics(delta)
	else:
		_handle_air_physics(delta)
	
	move_and_slide()
	print(self.velocity * self.global_basis)




func _process(delta: float) -> void:
	_handle_controller_look_input(delta)





func _handle_air_physics(delta: float) -> void:
	self.velocity.y += get_gravity().y * delta                                 # Gravity is currently set to 12
	




func _handle_ground_physics(delta: float) -> void:
	self.velocity.x = wished_direction.x * get_move_speed() 
	self.velocity.z = wished_direction.z * get_move_speed()
	self.velocity.y = wished_direction.y 
	
	if headbob: _headbob_effect(delta)





func _handle_controller_look_input(delta: float) -> void:
	var target_look : Vector2 = Input.get_vector("look_left", "look_right", "look_down", "look_up").normalized()
	
	if target_look.length() < controller_look.length():                          #TODO: Add a ON/OFF on this smoothing
		controller_look = target_look
	else:
		controller_look = controller_look.lerp(target_look, 5.0 * delta)        #TODO : Turn this 5.0 into a global setting
	
	self.rotate_y(-controller_look.x * controller_look_sensitivity)
	%Head.rotate_x(-controller_look.y * controller_look_sensitivity)
	%Head.rotation_degrees.x = clampf(%Head.rotation_degrees.x, -90, +90)





func _headbob_effect(delta : float) -> void:
	headbob_time += delta * self.velocity.length()
	%Camera3D.transform.origin = Vector3(
		cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       # X axis
		sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             # Y axis
		0                                                                       # Z axis
	) 
