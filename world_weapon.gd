extends RigidBody3D

@export var weapon_data : WeaponResource

func _on_pickup_radius_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if body.weapon_manager.add_weapon_to_inventory(weapon_data) == true:
			self.queue_free()
			return
		else:
			prompt_swap(body) 

func _on_pickup_radius_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		print("I shall unprompt the weapon swap") 

func prompt_swap(body: Node3D) -> void: 
	body.weapon_manager.prompt_ground_weapon_swap(weapon_data)
