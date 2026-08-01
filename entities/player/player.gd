class_name Player extends Actor

# ==============================================================================
# COMPONENT: PLAYER MANAGER (ROOT)
# ==============================================================================

@export_group("Player-Specific Components")
@export var camera_state_machine : CameraStateMachine
@export var footstep_controller  : FootstepController
@export var weapon_manager       : WeaponManager          
@export var weapon_sway          : WeaponSway            

@export_group("Player Camera Nodes")
@export var fp_camera            : Camera3D   
@export var tp_camera            : Camera3D   
@export var camera_smooth_point  : Node3D     
@export var orbit_cam_yaw        : Node3D        
@export var orbit_cam_pitch      : Node3D     
@export var orbit_cam_spring_arm : SpringArm3D

@export_group("Player-Specific Resources")
@export var camera_stats : CameraStats

@export_group("General")
@export var is_active : bool = true                                             
@export var weight    : float = 80.0                                            

@export_group("Visual Models")
@export var first_person_model : Node3D                                         
@export var third_person_model : Node3D                                         

@onready var world_model : Node3D = %WorldModel
@onready var debug_label : Label  = %DebugLabel          

var _last_frame_was_on_floor : float = -INF

func _ready() -> void:
	self.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	self.safe_margin = 0.0001
	_update_model_layers(is_active)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_active:
		if event is InputEventMouseMotion:
			if camera_state_machine: camera_state_machine.process_input(event)
			if weapon_sway: weapon_sway.handle_sway_input(event)

func _process(delta: float) -> void:
	if get_tree().paused: return 
	
	if is_active:
		#WARNING: Controllers are currently out of support while I am working on the refactoring: if camera_controller: camera_controller.handle_controller_look_input(delta)
		if weapon_sway: weapon_sway.process_sway(delta)
		
	_update_debug_ui()

func _physics_process(delta: float) -> void:
	if is_active and input:
		var active_cam : Camera3D = camera_state_machine.active_camera if camera_state_machine else null
		var cam_basis  : Basis    = active_cam.global_basis if active_cam else self.global_basis
	
		input.gather_inputs(self.global_basis, cam_basis)       
		if movement_state_machine: movement_state_machine.process_physics(delta)
	
	if physics_interactor: physics_interactor.process_physics()
	# Snap the camera after the physics interactor has pushed objects away
	if camera_state_machine: camera_state_machine.process_physics(delta)
	
	if is_active and weapon_manager: weapon_manager.process_weapons(delta)
	
	if footstep_controller: footstep_controller.process_footsteps(delta)
	
	if is_on_floor():
		_last_frame_was_on_floor = Engine.get_physics_frames()

#region Private Utilities
func _update_model_layers(active: bool) -> void:
	if first_person_model:
		for child : VisualInstance3D in first_person_model.find_children("*", "VisualInstance3D", true, false):
			child.set_layer_mask_value(1, false)
			child.set_layer_mask_value(2, active)
			child.set_layer_mask_value(3, false)
	
	if third_person_model:
		for child : VisualInstance3D in third_person_model.find_children("*", "VisualInstance3D", true, false):
			child.set_layer_mask_value(1, not active) 
			child.set_layer_mask_value(2, false)
			child.set_layer_mask_value(3, active)

func _update_debug_ui() -> void:
	debug_label.text  = "FPS: " + str(Engine.get_frames_per_second()) + "\n"
	
	if movement_state_machine and movement_state_machine.current_state:
		debug_label.text += "STATE: " + str(movement_state_machine.current_state.name) + "\n"
	else:
		debug_label.text += "STATE: NULL\n"
		
	if camera_state_machine and camera_state_machine.current_state:
		debug_label.text += "CAM_STATE: " + str(camera_state_machine.current_state.name) + "\n"
		var cam: Camera3D = camera_state_machine.active_camera
		if cam:
			debug_label.text += "CAM_POSITION: (" + str("%.2f" % cam.position.x) + "," + str("%.2f" % cam.position.y) + "," + str("%.2f" % cam.position.z) + ")\n"              
	
	debug_label.text += "VELOCITY: " + str(("%.2f" % self.velocity.length())) + "\n"        
	debug_label.text += "POSITION: (" + str("%.2f" % self.global_position.x) + "," + str("%.2f" % self.global_position.y) + "," + str("%.2f" % self.global_position.z) + ")\n"#endregion

#region External Interfaces
func activate_collision_feet_for_props() -> void:
	physics_interactor.activate_collision_feet_for_props()

func deactivate_collision_feet_for_props() -> void:
	physics_interactor.deactivate_collision_feet_for_props()

func set_activity(active_mode: bool) -> void:
	self.is_active = active_mode
	self.set_process_input(active_mode)
	self.set_process_unhandled_input(active_mode)
	self.set_process_unhandled_key_input(active_mode)
	self.set_process(active_mode)
	debug_label.text = ""
	
	if camera_state_machine and camera_state_machine.active_camera:
		camera_state_machine.active_camera.current = active_mode
	
	for child : VisualInstance3D in world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, not active_mode) 
		child.set_layer_mask_value(2, active_mode)
#endregion
