class_name TracerBullet extends Area3D

@export var speed : float = 150.0
var damage : int = 10

func _ready() -> void:
	self.body_entered.connect(_on_body_entered)
	# Failsafe: Destroy bullet after 2 seconds if it hits the sky
	get_tree().create_timer(2.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Move strictly forward on its local Z axis
	global_position += -global_transform.basis.z * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# TODO: Spawn a spark particle here before freeing
	queue_free()
