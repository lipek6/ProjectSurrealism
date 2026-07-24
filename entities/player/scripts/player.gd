class_name Player extends CharacterBody3D
#TODO: Jumping into stairs makes the player go to the SURFING state. This makes the player unable to go up the stairs without moving around a little bit.
#TODO: Maybe I should remove the surfing thing... I don't really pretend on using it as a mechanic. Or I could turn its functionality everytime the player is in air by calling the clip_velocity function, because having SURFING as a state is kinda being a pain in the ass.
#TODO: Add something like a PlayerGround enum to know where the player is walking on. (That doesn't look right... it is simpler for the floor to handle it... Whatever, why did I think that? lol)
#TODO: PATCH ON LEAVE!!!!!! CAUTION CAUTION CAUTION WARNING
# ==============================================================================
# COMPONENT: PLAYER MANAGER (ROOT)
## Responsibilities: Acts as the Master Controller for the Component Architecture.
## Defines global base variables (weight, active state) and orchestrates the execution 
## order of all attached components during the physics frame.
# ==============================================================================



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Node References
@onready var input                : PlayerInput               = %PlayerInput
@onready var movement_controller  : PlayerMovementController  = %MovementController
@onready var camera_controller    : PlayerCameraController    = %CameraController
@onready var physics_interactor   : PhysicsInteractor         = %PhysicsInteractor
@onready var animation_controller : PlayerAnimationController = %AnimationController
@onready var world_model : Node3D = %WorldModel
@onready var debug_label : Label  = %DebugLabel          

#endregion


#region Exported Parameters
@export_group("General")
@export var is_active : bool = true                                             ## [color=green]Toggles player control.[/color] [br]If false, ignores all inputs and physics processing. Highly useful for cutscenes or swapping characters.
@export var weight    : float = 80.0                                            ## [color=orange]Player's physical mass (kg).[/color] [br]Defines how hard the player can push dynamic PhysicsProps, and applies downward gravity when riding them. [br]Standard: [code]80.0[/code].

@export_group("Visual Models")
@export var first_person_model : Node3D                                         ## Container for headless bodies/floating arms.
@export var third_person_model : Node3D                                         ## Container for the full body / shadow caster.
#endregion


#region Internal Variables
var _last_frame_was_on_floor : float = -INF
#endregion



# ==============================================================================
# METHODS
# ==============================================================================


# ==========================================
# PRIVATE
# ==========================================
#region Core Engine Functions
## Called when the node enters the scene tree for the first time.
## - Sets up visual masking so the player doesn't see their own 3D model clipping through the camera.
## - By default, Godot adds the extreme rotational velocity of tumbling boxes to the player when they slip off.
##   We disable this entirely by setting self.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING.
## - Forces self.safe_margin = 0.0001 to prevent jittering when pushing objects.
func _ready() -> void:
	self.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	self.safe_margin = 0.0001
	
	_update_model_layers(is_active)

## Safely manages visibility layers so First Person cameras don't see full bodies, 
## while ensuring inactive players/NPCs remain visible to everyone!
func _update_model_layers(active: bool) -> void:
	# First Person Meshes (Headless body, floating arms)
	if first_person_model:
		# Note: The 'false' parameter at the end ensures we find nodes inside instanced scenes too
		for child : VisualInstance3D in first_person_model.find_children("*", "VisualInstance3D", true, false):
			# Only active players see their FP model. It goes on Layer 2.
			child.set_layer_mask_value(1, false)
			child.set_layer_mask_value(2, active)
			child.set_layer_mask_value(3, false)
	
	# Third Person Meshes (Full body, shadow caster)
	if third_person_model:
		for child : VisualInstance3D in third_person_model.find_children("*", "VisualInstance3D", true, false):
		# If active player, put on Layer 3 (Local TP). If inactive (NPC/Other), put on Layer 1 (World)
			child.set_layer_mask_value(1, not active)
			child.set_layer_mask_value(2, false)
			child.set_layer_mask_value(3, active)



## Listens for hardware events that aren't tied to the physics tick (like mouse movement).
func _unhandled_input(event: InputEvent) -> void:
	# Mouse capture logic (TODO: Needs to be upgraded later when adding UI)
	if event is InputEventMouseButton:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Mouse look logic
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and is_active:
		if event is InputEventMouseMotion:
			camera_controller.handle_camera_input(event)


## The visual frame loop. Used exclusively for updating UI and controller-based camera smoothing.
func _process(delta: float) -> void:
	if is_active:
		camera_controller.handle_controller_look_input(delta)
		animation_controller.process_animation(delta)
		
	debug_label.text  = "FPS: " + str(Engine.get_frames_per_second())                 + "\n"        # For DEBUG purpouses. TODO: Need to find a way to enable/disable these things
	debug_label.text += "STATE: " + str(movement_controller.State.keys()[movement_controller.current_state])            + "\n"        
	debug_label.text += "CAM_STYLE: " + str(camera_controller.Style.keys()[camera_controller.current_style]) + "\n"        
	debug_label.text += "CAM_POSITION: (" + str("%.2f" % camera_controller.current_camera.position.x) + "," + str("%.2f" % camera_controller.current_camera.position.y) + "," + str("%.2f" % camera_controller.current_camera.position.z) + ")\n"          
	debug_label.text += "VELOCITY: " + str(("%.2f" % self.velocity.length()))         + "\n"        
	debug_label.text += "POSITION: (" + str("%.2f" % self.global_position.x) + "," + str("%.2f" % self.global_position.y) + "," + str("%.2f" % self.global_position.z) + ")\n"              


## The rigid physics loop. Orchestrates the input gathering, state evaluation, and physics execution pipeline.
func _physics_process(delta: float) -> void:
	if is_active:
		input.gather_inputs(self.global_basis, camera_controller.current_camera.global_basis)       # Instead of current_camera maybe I should use its style state? Don't know :(
		movement_controller.handle_toggles_and_settings()                  
	
	var anim : AnimationPlayer = $HeadOriginalPosition/Head/CameraSmoothPoint/FirstPersonCamera3D/FirstPersonModel/arms_rig/AnimationPlayer
	if input.crouch_held:
		anim.play("fp_pistol_reload")
	else:
		anim.play("fp_pistol_idle")
	# Delegate exact execution order to the underlying components
	
	movement_controller.process_movement(delta)
	camera_controller.process_camera(delta)
	physics_interactor.process_physics()
	
	# Update frame tracking for the downward stair raycast
	if is_on_floor():
		_last_frame_was_on_floor = Engine.get_physics_frames()
#endregion



# ==========================================
# PUBLIC
# ==========================================
#region External Interfaces
# ATTENTION: Migth be unecessary
## Dynamically activates flat feet to prevent the capsule curve from shooting out props (called by the PhysicsProp)
func activate_collision_feet_for_props() -> void:
	physics_interactor.activate_collision_feet_for_props()


# ATTENTION: Migth be unecessary
## Dynamically restores the standard round capsule bottom for smooth stairs/slope movement (called by the PhysicsProp)
func deactivate_collision_feet_for_props() -> void:
	physics_interactor.deactivate_collision_feet_for_props()


## CAUTION: BEING USED ONLY FOR DEBUGGING 
## NOTICE: Might be close to a function structure to support local coop
func set_activity(active_mode: bool) -> void:
	self.is_active = active_mode
	self.set_process_input(active_mode)
	self.set_process_unhandled_input(active_mode)
	self.set_process_unhandled_key_input(active_mode)
	self.set_process(active_mode)
	debug_label.text = ""
	
	# We safely toggle the component camera
	if camera_controller and camera_controller.current_camera:
		camera_controller.current_camera.current = active_mode
	
	for child : VisualInstance3D in world_model.find_children("*", "VisualInstance3D"):
		child.set_layer_mask_value(1, not active_mode) 
		child.set_layer_mask_value(2, active_mode)
#endregion
