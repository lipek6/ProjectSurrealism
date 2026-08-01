class_name CameraStateMachine extends Node

@export var initial_state: CameraState

var current_state: CameraState
var states: Dictionary = {}


# The Player script reads this to determine the movement input basis
var active_camera: Camera3D

func _ready() -> void:
	await owner.ready                                                           
	
	# Fetch dependencies from the root owner
	var player_input       : PlayerInput     = owner.input
	var player_camera_stats: CameraStats     = owner.camera_stats
	
	# Inject into all children
	for child_state: CameraState in find_children("*", "CameraState"):
		child_state.setup(owner, self, player_input, player_camera_stats)
		states[child_state.name] = child_state
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

## CRITICAL: Should be called on the _unhandled_input() function of the player!!!
func process_input(event : InputEventMouseMotion) -> void:
	if current_state:
		current_state.input_update(event)

## CRITICAL: Called by the player's _physics_process() AFTER movement!!!
func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## [color=cyan]State Router.[/color]
## Uses StringName (&"Name") to avoid memory allocation on lookup.
func transition_to(target_state_name: StringName) -> void:
	if not states.has(target_state_name):
		push_error("State Machine transition failed. Unknown target state: " + target_state_name + "\n Current State when the the error occurred: " + current_state.name)
		return
	
	var next_state: CameraState = states[target_state_name]
	if next_state == current_state:
		return
	
	# Actual transition
	current_state.exit()
	current_state = next_state
	current_state.enter()
