class_name HumanSphere extends CharacterBody3D

@export var corpse_despawn_time : float = 10.0
@export_group("Variant Setup")
@export var enemy_material : Material
@export var secondary_enemy_material : Material
@export var secondary_material_limbs : Array[PhysicsProp]
@export var brain          : EnemyBrain

@export_group("Stats")
@export var speed : float = 5.0
@export var vital_parts : Array[PhysicsProp] = []
@export var explode_on_death : bool = true            

var body_parts : Array[PhysicsProp] = []
var is_dead    : bool = false

# Track exact missing limbs for the AI Brain
var missing_left_arm  : bool = false
var missing_right_arm : bool = false
var missing_left_leg  : bool = false
var missing_right_leg : bool = false
var is_crawling       : bool = false

@onready var anim_player : AnimationPlayer = %AnimationPlayer        
@onready var footstep_controller : FootstepController = %FootstepController 

func _ready() -> void:
	if brain: brain.initialize(self)

	for child : PhysicsProp in find_children("*", "PhysicsProp", true, false):
		body_parts.append(child)
		child.freeze = true                                                     
		child.tree_exiting.connect(_on_sphere_destroyed.bind(child))              
		child.add_collision_exception_with(self)
		
		for other_part : PhysicsProp in body_parts:
			child.add_collision_exception_with(other_part)
			
		if enemy_material and child.model is MeshInstance3D:
			child.model.set_surface_override_material(0, enemy_material)
		if secondary_enemy_material and child.model is MeshInstance3D and child in secondary_material_limbs:
			child.model.set_surface_override_material(0, secondary_enemy_material)


func _physics_process(delta: float) -> void:
	if is_dead: return
	
	if not is_on_floor():
		self.velocity.y += get_gravity().y * delta

	if brain: brain.process_ai(delta)
		
	move_and_slide()
	
	if footstep_controller:
		footstep_controller.process_footsteps(delta)


func _on_sphere_destroyed(destroyed_part: PhysicsProp) -> void:
	if is_dead: return
	
	var part_name : String = destroyed_part.name
	
	if destroyed_part in vital_parts:
		trigger_collapse()
		return
		
	_process_dismemberment(part_name)
	
	if brain:
		brain.trigger_hit_reaction(part_name)


func _process_dismemberment(part_name: String) -> void:
	var parts_to_drop : Array[String] = []
	
	# --- RIGHT ARM LOGIC ---
	if "ArmR" in part_name or "HandR" in part_name:
		missing_right_arm = true
		if "UpperArmR" in part_name:
			parts_to_drop.append_array(["LowerArmR", "HandR"])
		elif "LowerArmR" in part_name:
			parts_to_drop.append("HandR")
			
	# --- LEFT ARM LOGIC ---
	if "ArmL" in part_name or "HandL" in part_name:
		missing_left_arm = true
		if "UpperArmL" in part_name:
			parts_to_drop.append_array(["LowerArmL", "HandL"])
		elif "LowerArmL" in part_name:
			parts_to_drop.append("HandL")
			
	# --- RIGHT LEG LOGIC ---
	if "LegR" in part_name or "FootR" in part_name:
		missing_right_leg = true
		is_crawling = true
		speed = 1.5 
		if "UpperLegR" in part_name:
			parts_to_drop.append_array(["LowerLegR", "FootR"])
		elif "LowerLegR" in part_name:
			parts_to_drop.append("FootR")
			
	# --- LEFT LEG LOGIC ---
	if "LegL" in part_name or "FootL" in part_name:
		missing_left_leg = true
		is_crawling = true
		speed = 1.5 
		if "UpperLegL" in part_name:
			parts_to_drop.append_array(["LowerLegL", "FootL"])
		elif "LowerLegL" in part_name:
			parts_to_drop.append("FootL")
			
	# Drop the calculated children spheres
	for part : PhysicsProp in body_parts:
		if is_instance_valid(part) and part.is_inside_tree() and not part.is_queued_for_deletion():
			for drop_name : String in parts_to_drop:
				if drop_name in part.name:
					_drop_single_part(part)


func trigger_collapse() -> void:
	is_dead = true
	for part : PhysicsProp in body_parts:
		# CRITICAL FIX: Ensure part is completely valid before touching it
		if not is_instance_valid(part) or not part.is_inside_tree() or part.is_queued_for_deletion():
			continue
		else:
			_drop_single_part(part)
	self.queue_free()


func _drop_single_part(part: PhysicsProp) -> void:
	# Tell Godot to wait until the physics step is totally finished before running the logic
	call_deferred("_execute_deferred_drop", part)


func _execute_deferred_drop(part: PhysicsProp) -> void:
	# Failsafe: Make sure the part didn't get deleted while we were waiting!
	if not is_instance_valid(part) or part.is_queued_for_deletion(): 
		return
		
	var saved_transform : Transform3D = part.global_transform           
	
	# Now it is perfectly safe to do immediate tree modifications
	part.get_parent().remove_child(part)
	get_tree().root.add_child(part)
	
	part.global_transform = saved_transform
	part.freeze = false
	
	if explode_on_death:
		part.is_fragile = true
		part.kinetic_break_threshold = 2.0 
	
	var random_push : Vector3 = Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2))
	part.apply_impulse(random_push)
	
	# GARBAGE COLLECTION
	get_tree().create_timer(corpse_despawn_time).timeout.connect(func():
		if is_instance_valid(part):
			part.queue_free()
	)
