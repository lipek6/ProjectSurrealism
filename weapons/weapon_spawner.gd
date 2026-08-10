class_name WeaponSpawner extends Marker3D
## Only uses the _ready function when it enter the tree to spawn the given weapon.
## The given weapon resource needs to have a world model scene attatched to it.

@export var weapon_data: WeaponResource

func _ready() -> void:
	if not weapon_data or not weapon_data.world_model: return
	
	var world_item: WeaponWorldInstance = weapon_data.world_model.instantiate() as WeaponWorldInstance
	world_item.data = weapon_data # Injects the data. This solves the circular dependency to happen in editor.
	
	get_parent().call_deferred("add_child", world_item)
	world_item.global_transform = self.global_transform
	
	self.queue_free()
