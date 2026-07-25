class_name FootstepsController extends Node3D
## Procedurally handles footstep audio based on actual distance travelled.
## MUST BE DRIVEN BY AN EXTERNAL MANAGER. Does not use _process directly.

@export var player : Player
@export var audio_player : AudioStreamPlayer3D

@export_group("Footstep Settings")
@export var footstep_sounds : Array[AudioStream] = []                           ## Populate this with 3-5 different gravel/floor step variations
@export var step_distance   : float = 2.0                                       ## The distance in meters the player must travel to trigger a step
@export var sprint_distance : float = 2.5                                       ## Increase distance slightly when sprinting for a natural cadence
						
var _distance_travelled : float = 0.0


## Called by the Player's main _process or _physics_process loop.
func process_footsteps(delta: float) -> void:
	# Don't play steps if we are jumping, falling, or standing still
	if not player.is_on_floor(): return
		
	# Extract only flat horizontal velocity (ignore gravity/slopes)
	var flat_velocity : Vector2 = Vector2(player.velocity.x, player.velocity.z)
	
	# If the player is barely moving (e.g., sliding into a wall), don't step
	if flat_velocity.length() < 0.5: 
		# Reset the cycle when they stop so the first step out of a standstill is immediate
		_distance_travelled = step_distance * 0.8 
		return

	# Accumulate distance
	_distance_travelled += flat_velocity.length() * delta
	
	# Determine the target distance based on whether the player is sprinting
	var current_target_distance : float = step_distance
	if player.input.sprint_held:
		current_target_distance = sprint_distance

	# Play the sound and reset the accumulator
	if _distance_travelled >= current_target_distance:
		_play_step()
		# Modulo prevents us from dropping extra distance if the frame drops!
		_distance_travelled = fmod(_distance_travelled, current_target_distance) 


func _play_step() -> void:
	if footstep_sounds.is_empty() or not audio_player: 
		return
		
	audio_player.stream = footstep_sounds.pick_random()
	# High pitch variation for footsteps keeps them organic
	audio_player.pitch_scale = randf_range(0.8, 1.2) 
	audio_player.play()
