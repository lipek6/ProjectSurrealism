class_name Actor extends CharacterBody3D
## [color=cyan]Abstract Base Actor.[/color]
## Defines the standard interface and core components required for the 
## MovementStateMachine to function. All moving entities (Players, NPCs) must inherit from this.

@export_group("Core Actor Components")
@export var input              : ActorInput
@export var movement_stats     : MovementStats
@export var physics_interactor : PhysicsInteractor

# ==============================================================================
# VIRTUAL METHODS (To be overridden by children)
# ==============================================================================
func crouch() -> void:
	push_warning("crouch() called on base Actor. Child class forgot to override.")

func uncrouch() -> void:
	push_warning("uncrouch() called on base Actor. Child class forgot to override.")

func crouch_midair() -> void:
	push_warning("crouch_midair() called on base Actor. Child class forgot to override.")

func uncrouch_midair() -> void:
	push_warning("uncrouch_midair() called on base Actor. Child class forgot to override.")
