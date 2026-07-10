#TODO: Expand this to be a full scene that can handle an arbitray number of characters.
extends Node3D

@export var is_active  : bool = false
@export var character_1: Player
@export var character_2: Player

var active_character: Player

func _ready() -> void:
	if not is_active: 
		self.set_process(false) 
		self.set_process_input(false)
		return
		
	# Avoids problems
	if not character_1.is_in_group("Player") or not character_2.is_in_group("Player"):
		print("Fatal error, you assigned a non player character to the Character handler")
		print("Check groups")
		get_tree().exit()
	
	# Set Character 1 as the starting actor
	active_character = character_1
	character_1.set_activity(true)
	character_2.set_activity(false)

## CAUTION: Lots of unsafe accesses here. All of this needs to be refactored later!
func _process(delta: float) -> void:
	$Label.text = "Player state:  "  + str(character_1.movement_controller.State.keys()[character_1.movement_controller.current_state]) + "\n"  
	$Label.text += "Player2 state: " + str(character_2.movement_controller.State.keys()[character_2.movement_controller.current_state])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("swap"):
		character_1.set_activity(not character_1.is_active)
		character_2.set_activity(not character_2.is_active)
