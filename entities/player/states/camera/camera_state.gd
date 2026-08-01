class_name CameraState extends State
## [color=cyan]Generic Base State.[/color]
## Uses true Dependency Injection. The State Machine provides all necessary 
## references on boot, preventing pointer-chasing and Demeter violations.

var player: Player
var state_machine: CameraStateMachine
var input: PlayerInput
var stats: CameraStats

## Injects all required decoupled dependencies.
func setup(player_ref: Player, state_machine_ref: CameraStateMachine, input_ref: PlayerInput, stats_ref: CameraStats) -> void:
	player = player_ref
	state_machine = state_machine_ref
	input = input_ref
	stats = stats_ref


func input_update(event : InputEventMouseMotion) -> void:
	pass



func physics_update(delta: float) -> void:
	pass

func enter() -> void:
	pass

func exit() -> void:
	pass
