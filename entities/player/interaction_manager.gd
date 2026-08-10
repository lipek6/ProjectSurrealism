class_name InteractionManager extends Node

signal promt_pickup(weapon_id_name: StringName)

@export var actor: Actor
@export var interaction_ray: RayCast3D
@export var auto_pickup_area: Area3D


func _ready() -> void:
	if auto_pickup_area:
		auto_pickup_area.body_entered.connect(on_auto_pickup_area_body_entered)


func on_auto_pickup_area_body_entered(body: Node3D) -> void:
	if body is WeaponWorldInstance and actor.weapon_manager:
		actor.weapon_manager.try_auto_pickup(body)


func process_interaction() -> void:
	if not interaction_ray or not interaction_ray.is_colliding(): return
	
	if interaction_ray.get_collider() is WeaponWorldInstance:
		var world_weapon: WeaponWorldInstance = interaction_ray.get_collider() as WeaponWorldInstance
	
		if actor.input.wants_interact:   actor.weapon_manager.interact_pickup_weapon(world_weapon, false)
		if actor.input.wants_dual_wield: actor.weapon_manager.interact_pickup_weapon(world_weapon, true)
