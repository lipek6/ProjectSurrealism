class_name WeaponInstance extends Node3D

@export var anim_player    : AnimationPlayer
@export var muzzle_point   : Marker3D
@export var ejection_point : Marker3D
@export var audio_player   : AudioStreamPlayer3D

func play_shoot_effects(muzzle_flash_scene: PackedScene, casing_scene: PackedScene, shoot_sound: AudioStream) -> void:
	if muzzle_flash_scene:
		var muzzle_flash_instance : Node3D = muzzle_flash_scene.instantiate()
		muzzle_point.add_child(muzzle_flash_instance)
	
	if casing_scene:
		var casing_instance : Node3D = casing_scene.instantiate()
		get_tree().root.add_child(casing_instance)
		casing_instance.global_transform = ejection_point.global_transform
	
		# Apply physics impulse (Right and Up relative to the gun)
		if casing_instance is RigidBody3D:
			var eject_dir   : Vector3 = (-ejection_point.global_basis.x + (ejection_point.global_basis.y * 0.5)).normalized()
			var eject_force : float = randf_range(2.0, 4.0) * 100
			casing_instance.apply_impulse(eject_dir * eject_force)
			casing_instance.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	
	if audio_player and shoot_sound:
		audio_player.stream = shoot_sound
		audio_player.pitch_scale = randf_range(0.95, 1.05)
		audio_player.play()


func play_equip_effects(equip_sound : AudioStream) -> void:
	if equip_sound:
		audio_player.stream = equip_sound
		audio_player.play()


func play_unequip_effects(unequip_sound : AudioStream) -> void:
	if unequip_sound:
		audio_player.stream = unequip_sound
		audio_player.play()


func play_reload_effects(reload_sound : AudioStream) -> void:
	if reload_sound:
		audio_player.stream = reload_sound
		audio_player.play()
