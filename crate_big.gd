extends RigidBody3D

@export var speed: float = 4000.0

func _physics_process(delta: float) -> void:
	# Example global direction (X-axis)
	var direction = Vector3(1, 0, 0) 
	
	# Apply continuous movement force
	apply_central_force(direction * speed)
