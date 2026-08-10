class_name HealthController extends Node
# Hacky class at the moment, intended just for quick testing 

var health: int = 100


func take_damage(damage: int) -> void:
	health -= damage
	print("AHHHHHHH")
