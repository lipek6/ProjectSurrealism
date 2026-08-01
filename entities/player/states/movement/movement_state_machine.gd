class_name MovementStateMachine extends Node
# CLASS DESCRIPTION ------------------------------------------------------------
## [color=cyan]Generic FSM Router.[/color]
## Orchestrates the execution and transitioning of States. 
## Can be attached to Players, Enemies, or NPCs, as long as a velocity,
## movement_stats and input components are present inside them. 
# ------------------------------------------------------------------------------


@export var initial_state: MovementState

var current_state: MovementState
var states: Dictionary = {}



func _ready() -> void:
	await owner.ready                                                           
	
	# Fetch dependencies from the root owner
	var actor_input : ActorInput    = owner.input
	var actor_stats : MovementStats = actor_input.movement_stats
	
	# Inject into all children
	for child_state: MovementState in find_children("*", "MovementState"):
		child_state.setup(owner, self, actor_input, actor_stats)
		states[child_state.name] = child_state
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


## [color=cyan]State Router.[/color]
## Uses StringName (&"Name") to avoid memory allocation on lookup.
func transition_to(target_state_name: StringName) -> void:
	if not states.has(target_state_name):
		push_error("State Machine transition failed. Unknown target state: " + target_state_name + "\n Current State when the the error occurred: " + current_state.name)
		return
	
	var next_state: MovementState = states[target_state_name]
	if next_state == current_state:
		return
	
	# Actual transition
	current_state.exit()
	current_state = next_state
	current_state.enter()
