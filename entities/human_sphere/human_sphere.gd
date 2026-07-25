class_name HumanSphere extends CharacterBody3D

@export_group("Variant Setup")
@export var enemy_material : Material                                           ## Drop colored/metallic ShaderMaterial or StandardMaterial her!
@export var brain          : EnemyBrain                                         ## Drop the specific AI component node here

@export_group("Stats")
@export var speed : float = 5.0
@export var vital_parts : Array[PhysicsProp] = []

var body_parts : Array[PhysicsProp] = []
var is_dead    : bool = false

@onready var anim_player : AnimationPlayer = %AnimationPlayer        

func _ready() -> void:
	# Setup the Brain
	if brain:
		brain.initialize(self)

	# Find and setup spheres
	for child : PhysicsProp in find_children("*", "PhysicsProp", true, false):
		body_parts.append(child)
		
		child.freeze = true                                                     
		child.tree_exiting.connect(_on_sphere_destroyed.bind(child))              
		child.add_collision_exception_with(self)
		
		for other_part : PhysicsProp in body_parts:
			child.add_collision_exception_with(other_part)
			
		# Apply the Variant Material
		if enemy_material and child.model is MeshInstance3D:
			child.model.set_surface_override_material(0, enemy_material)


func _physics_process(delta: float) -> void:
	if is_dead: return
	
	if not is_on_floor():
		self.velocity.y += get_gravity().y * delta

	# Delegate decision making to the Brain component
	if brain:
		brain.process_ai(delta)
		
	move_and_slide()




func _on_sphere_destroyed(destroyed_part: PhysicsProp) -> void:
	if is_dead: return
	
	if destroyed_part in vital_parts:
		trigger_collapse()
	else:
		pass

func trigger_collapse() -> void:
	is_dead = true
	
	for part : PhysicsProp in body_parts:
		if is_instance_valid(part) and part.is_inside_tree() and not part.is_queued_for_deletion():
			var saved_transform : Transform3D = part.global_transform           # Save its exact 3D position in the world before reparenting
			
			part.get_parent().remove_child(part)
			get_tree().root.add_child(part)
			
			part.global_transform = saved_transform
			part.freeze = false
			
			var random_push : Vector3 = Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2))
			part.apply_impulse(random_push)
	
	self.queue_free()
