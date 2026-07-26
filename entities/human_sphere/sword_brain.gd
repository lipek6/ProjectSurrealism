class_name SwordEnemyBrain extends Node

enum State { IDLE, SURPRISED, CHASE, ATTACK, HIT_REACTION, CRAWL }

@export_group("Brain Settings")
@export var target_player   : Player
@export var attack_range    : float = 2.2
@export var attack_cooldown : float = 1.2

@export_group("Senses")
@export var sight_range       : float = 25.0
@export var field_of_view     : float = 90.0                            
@export var proximity_hearing : float = 5.0                             

@onready var nav_agent : NavigationAgent3D = %NavigationAgent3D
@onready var sight_ray : RayCast3D = %SightRayCast

var current_state : State = State.IDLE
var body : HumanSphere                                                          
var _cooldown_timer : float = 0.0
var _animation_locked : bool = false
var _failsafe_timer : float = 0.0

func initialize(brain_body: HumanSphere) -> void:
	body = brain_body
	if not target_player:
		target_player = get_tree().get_first_node_in_group("Player")
	sight_ray.target_position = Vector3(0, 0, -sight_range) 
	
	body.anim_player.animation_finished.connect(_on_animation_finished)
	
	if target_player:
		_enter_state(State.SURPRISED)
		current_state = State.SURPRISED

func process_ai(delta: float) -> void:
	if not target_player or not body: return
	if _cooldown_timer > 0.0: _cooldown_timer -= delta
	
	if _animation_locked:
		_failsafe_timer += delta
		if not body.anim_player.is_playing() or _failsafe_timer > 2.0:
			_animation_locked = false
	else:
		_failsafe_timer = 0.0
	
	var next_state = _get_next_state()
	if next_state != current_state:
		_enter_state(next_state)
		current_state = next_state
		
	_process_state(delta)

func trigger_hit_reaction(part_name: String) -> void:
	if body.is_dead or body.is_crawling: return
	
	_animation_locked = true
	_failsafe_timer = 0.0
	current_state = State.HIT_REACTION
	_apply_friction()
	
	if "L" in part_name:
		body.anim_player.play("ua1/Hit_Shoulder_L", 0.1)
	elif "R" in part_name:
		body.anim_player.play("ua1/Hit_Shoulder_R", 0.1)
	else:
		body.anim_player.play("ua1/Hit_Chest", 0.1)

func _on_animation_finished(_anim_name: StringName) -> void:
	_animation_locked = false

func _get_next_state() -> State:
	if _animation_locked: return current_state
	
	var distance_to_player : float = body.global_position.distance_to(target_player.global_position)
	
	if body.is_crawling:
		if distance_to_player <= attack_range and _cooldown_timer <= 0.0:
			return State.ATTACK
		return State.CRAWL
	
	match current_state:
		State.IDLE:
			if _can_see_or_hear_player(distance_to_player):
				return State.SURPRISED
		State.SURPRISED, State.HIT_REACTION:
			return State.CHASE
		State.CHASE:
			if distance_to_player <= attack_range and _cooldown_timer <= 0.0:
				return State.ATTACK
		State.ATTACK:
			return State.CHASE
	return current_state

func _enter_state(new_state: State) -> void:
	match new_state:
		State.IDLE:
			body.anim_player.play("ua1/Idle", 0.2)
		State.SURPRISED:
			_animation_locked = true
			_failsafe_timer = 0.0
			body.anim_player.play("ua2/Surprise", 0.1)
		State.CHASE:
			body.anim_player.play("ua1/Sprint", 0.2)
		State.CRAWL:
			body.anim_player.play("ua1/Crawl_Fwd", 0.3)
		State.ATTACK:
			_animation_locked = true
			_failsafe_timer = 0.0
			_cooldown_timer = attack_cooldown
			
			var damage_windup : float = 0.4 
			var damage_amount : int = 30 # Swords hurt!
			
			# --- SWORD VS KICK LOGIC ---
			if not body.missing_right_arm:
				body.anim_player.play("ua2/Sword_Regular_A", 0.1) 
			elif not body.missing_left_arm:
				body.anim_player.play("ua2/Sword_Regular_B", 0.1) 
			else:
				# No arms? KICK THEM. Never surrender.
				body.anim_player.play("ua1/Kick", 0.1)
				damage_windup = 0.5
				damage_amount = 15
				
			get_tree().create_timer(damage_windup).timeout.connect(func():
				if is_instance_valid(body) and not body.is_dead and is_instance_valid(target_player):
					if body.global_position.distance_to(target_player.global_position) <= attack_range + 0.5:
						if target_player.has_method("take_damage"):
							target_player.take_damage(damage_amount, body.global_position)
			)

func _process_state(_delta: float) -> void:
	match current_state:
		State.IDLE, State.SURPRISED, State.HIT_REACTION, State.ATTACK:
			_apply_friction()
			_look_at_flat(target_player.global_position)
		State.CHASE, State.CRAWL:
			_navigate_towards(target_player.global_position)

func _navigate_towards(target_pos: Vector3) -> void:
	nav_agent.target_position = target_pos
	var next_path_pos : Vector3 = nav_agent.get_next_path_position()
	var direction = body.global_position.direction_to(next_path_pos)
	direction.y = 0.0 
	direction = direction.normalized()
	
	var look_pos = body.global_position + direction
	if body.global_position.distance_squared_to(look_pos) > 0.01:
		_look_at_flat(look_pos)
	
	body.velocity.x = direction.x * body.speed
	body.velocity.z = direction.z * body.speed

func _look_at_flat(target: Vector3) -> void:
	var look_pos = target
	look_pos.y = body.global_position.y
	body.look_at(look_pos, Vector3.UP)

func _apply_friction() -> void:
	body.velocity.x = lerpf(body.velocity.x, 0.0, 0.2)
	body.velocity.z = lerpf(body.velocity.z, 0.0, 0.2)

func _can_see_or_hear_player(distance: float) -> bool:
	if distance <= proximity_hearing: return true
	if distance > sight_range: return false
	var dir_to_player = body.global_position.direction_to(target_player.global_position)
	var forward_dir = -body.global_transform.basis.z
	var flat_dir_to_player = Vector3(dir_to_player.x, 0.0, dir_to_player.z).normalized()
	var flat_forward = Vector3(forward_dir.x, 0.0, forward_dir.z).normalized()
	var angle_to_player = rad_to_deg(flat_forward.angle_to(flat_dir_to_player))
	
	if angle_to_player <= (field_of_view / 2.0):
		var aim_target = target_player.global_position
		aim_target.y += 1.0 
		sight_ray.look_at(aim_target, Vector3.UP)
		sight_ray.force_raycast_update()
		if sight_ray.is_colliding() and sight_ray.get_collider() == target_player:
			return true
	return false
