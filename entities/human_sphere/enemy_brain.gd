class_name EnemyBrain extends Node
## A modular AI component for enemies. 
## Currently implements a basic Berserker logic using a State Machine.

enum State { IDLE, CHASE, ATTACK}

@export_group("Brain Settings")
@export var target_player   : Player                                              ## Who are we hunting
@export var attack_range    : float = 1.8                                         ## How close before swinging
@export var attack_cooldown : float = 1.5

var current_state : State = State.IDLE
var body : HumanSphere                                                          ## Reference back to the parent body. Called when the node enters the scene tree for the first time.
var _cooldown_timer : float = 0.0

func initialize(brain_body: HumanSphere) -> void:
	body = brain_body
	
	# Fallback if target isn't set: try to find the player in the tree
	if not target_player:
		target_player = get_tree().get_first_node_in_group("Player")

func process_ai(delta: float) -> void:
	if _cooldown_timer > 0.0: _cooldown_timer -= delta
	var distance_to_player : float = body.global_position.distance_to(target_player.global_position)
	
	# STATE MACHINE EVALUATION
	match current_state:
		State.IDLE:
			body.velocity.x = lerpf(body.velocity.x, 0.0, 0.1)
			body.velocity.z = lerpf(body.velocity.z, 0.0, 0.1)
			body.anim_player.play("ua1/Idle")
			
			if distance_to_player < 5.0: current_state = State.CHASE
		
		
		State.CHASE:
			# Look at the player (ignoring Y height)
			var look_pos : Vector3 = target_player.global_position
			look_pos.y = body.global_position.y
			body.look_at(look_pos, Vector3.UP)
			
			# Move forward
			var forward_dir : Vector3 = -body.global_transform.basis.z.normalized()
			body.velocity.x = forward_dir.x * body.speed
			body.velocity.z = forward_dir.z * body.speed

			body.anim_player.play("ua1/Sprint")
			
			# If close enough, attack!
			if distance_to_player <= attack_range and _cooldown_timer <= 0.0: current_state = State.ATTACK
			
			
		State.ATTACK:
			# Stop moving to punch
			body.velocity.x = 0.0
			body.velocity.z = 0.0
			
			body.anim_player.play("ua1/Punch_Jab")
			_cooldown_timer = attack_cooldown
			
			# TODO: Actually deal damage to the player here via an area or raycast!
			
			# Immediately go back to chase, but the cooldown timer prevents attacking again
			current_state = State.CHASE
