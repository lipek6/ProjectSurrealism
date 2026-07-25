extends Node3D

@export var shatter_sounds : Array[AudioStream]  = []
@onready var particles     : GPUParticles3D      = %GPUParticles3D
@onready var audio_player  : AudioStreamPlayer3D = %AudioStreamPlayer3D

func _ready() -> void:
	if particles != null:
		particles.emitting = true
	
	if audio_player != null and not shatter_sounds.is_empty():
		audio_player.stream = shatter_sounds.pick_random()
		audio_player.pitch_scale = randf_range(0.9, 1.1)
		audio_player.play()
		
	# Destroy this node after the particles die
	await get_tree().create_timer(particles.lifetime).timeout
	queue_free()
