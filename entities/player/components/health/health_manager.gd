class_name HealthManager extends Node
## Manages health logic and broadcasts changes to the Orchestrator.

signal health_changed(new_health: int)
signal died

@export var max_health : int = 100
@onready var current_health : int = max_health

func take_damage(amount: int) -> void:
	# Ignore damage if already dead
	if current_health <= 0: return
	
	current_health -= amount
	current_health = max(0, current_health) # Prevent negative numbers
	
	health_changed.emit(current_health)
	
	if current_health == 0:
		died.emit()
		await get_tree().create_timer(3.0).timeout
		
		# CRITICAL: Unlock the mouse before going to the menu!
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Ensure this matches your EXACT Main Menu file path
		get_tree().change_scene_to_file("res://main_menu.tscn")


func heal(amount: int) -> void:
	if current_health <= 0: return
	
	current_health += amount
	current_health = min(max_health, current_health) # Prevent overhealing
	
	health_changed.emit(current_health)
