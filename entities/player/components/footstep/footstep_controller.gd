class_name FootstepController extends Node3D
## Procedurally handles footstep audio for ANY CharacterBody3D.

@export var body : CharacterBody3D
@export var audio_player : AudioStreamPlayer3D

@export_group("Footstep Settings")
@export var footstep_sounds : Array[AudioStream] = []
@export var step_distance   : float = 2.0               
@export var velocity_threshold : float = 0.1            ## NEW: How fast the body must be moving to count as "walking"

var _distance_travelled : float = 0.0

func process_footsteps(delta: float) -> void:
	
	if not body.is_on_floor() or footstep_sounds.is_empty() or not audio_player: 
		return
		
	var flat_velocity := Vector2(body.velocity.x, body.velocity.z)
	var speed := flat_velocity.length()
	
	# CRITICAL FIX: The threshold is now 0.1 instead of 0.5! 
	# Slow enemies will now properly accumulate distance.
	if speed < velocity_threshold: 
		_distance_travelled = step_distance * 0.8 
		return

	_distance_travelled += speed * delta
	if _distance_travelled >= step_distance:
		_play_step()
		_distance_travelled = fmod(_distance_travelled, step_distance) 


func _play_step() -> void:
	audio_player.stream = footstep_sounds.pick_random()
	audio_player.pitch_scale = randf_range(0.8, 1.2) 
	audio_player.play()
