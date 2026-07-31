class_name State extends Node
## [color=cyan]Generic Base State.[/color]
## Uses true Dependency Injection. The State Machine provides all necessary 
## references on boot, preventing pointer-chasing and Demeter violations.

var actor: Actor
var state_machine: MovementStateMachine
var input: ActorInput
var stats: MovementStats

## Injects all required decoupled dependencies.
func setup(actor_ref: Actor, state_machine_ref: MovementStateMachine, input_ref: ActorInput, stats_ref: MovementStats) -> void:
	actor = actor_ref
	state_machine = state_machine_ref
	input = input_ref
	stats = stats_ref

func physics_update(delta: float) -> void:
	pass

func enter() -> void:
	pass

func exit() -> void:
	pass
