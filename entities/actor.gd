class_name Actor extends CharacterBody3D

## [color=cyan]Abstract Base Actor.[/color]
## The universal blueprint for any moving entity in the game.
## Owns the physical nodes and provides the FSM with a guaranteed interface.

# ==============================================================================
# CORE COMPONENTS (Required by FSM)
# ==============================================================================
@export_group("Core Components")
@export var input                  : ActorInput
@export var movement_stats         : MovementStats
@export var movement_state_machine : MovementStateMachine
@export var physics_interactor     : PhysicsInteractor

# ==============================================================================
# PHYSICAL NODES
# ==============================================================================
@export_group("Physical Nodes")
@export var collision_shape    : CollisionShape3D
@export var aim_raycast        : RayCast3D
@export var head               : Node3D
@export var stairs_ahead_ray   : RayCast3D
@export var stairs_below_ray   : RayCast3D

@onready var _original_capsule_height : float = collision_shape.shape.height

var is_crouched : bool = false

# ==============================================================================
# UNIVERSAL ACTOR LOGIC
# ==============================================================================

func crouch() -> void:
	if is_crouched: return
	collision_shape.shape.height = _original_capsule_height - movement_stats.crouch_translate
	collision_shape.position.y   = collision_shape.shape.height / 2.0  
	is_crouched = true
	
func uncrouch() -> void:
	if not is_crouched: return
	collision_shape.shape.height = _original_capsule_height
	collision_shape.position.y   = collision_shape.shape.height / 2.0 
	is_crouched = false

func crouch_midair() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	self.test_move(self.transform, Vector3(0.0, +movement_stats.crouch_jump_add, 0.0), collision_result)
	
	self.position.y += collision_result.get_travel().y   
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -movement_stats.crouch_translate, 0) 
	crouch()

func uncrouch_midair() -> void:
	var collision_result : KinematicCollision3D = KinematicCollision3D.new()
	self.test_move(self.transform, Vector3(0.0, -movement_stats.crouch_jump_add, 0.0), collision_result)
	
	self.position.y += collision_result.get_travel().y   
	head.position.y -= collision_result.get_travel().y
	head.position.y = clampf(head.position.y, -movement_stats.crouch_translate, 0)
	uncrouch()
