class_name ThirdPersonFreeLookState extends CameraState
var _saved_camera_global_position : Vector3 = Vector3.INF

func enter() -> void:
	player.tp_camera.make_current()
	state_machine.active_camera = player.tp_camera

func exit() -> void:
	pass


func input_update(event : InputEventMouseMotion) -> void:
	player.orbit_cam_yaw.rotate_y(-event.relative.x * stats.tp_look_sensitivity)
	player.orbit_cam_pitch.rotate_x(-event.relative.y * stats.tp_look_sensitivity)
	player.orbit_cam_pitch.rotation_degrees.x = clampf(player.orbit_cam_pitch.rotation_degrees.x, -89, +89)        # Don't use 90, it will make the controls work backawards when on a 90 degrees angle


func physics_update(delta: float) -> void:
	if input.wants_camera_swap:
		state_machine.transition_to(&"FirstPersonState")
		return
	_handle_third_person_free_look_player_alignment(delta)

func _handle_third_person_free_look_player_alignment(delta : float) -> void:
	if input.flat_camera_aligned_wished_direction.length_squared() > 0.01:           # If the player is actively pressing movement keys
		var add_rotation_y : float = (-player.global_basis.z).signed_angle_to(input.flat_camera_aligned_wished_direction, Vector3.UP)
		var rotate_towards : float = lerp_angle(player.global_rotation.y, player.global_rotation.y + add_rotation_y, max(0.1,  abs(add_rotation_y/TAU))) - player.global_rotation.y
		
		player.rotation.y += rotate_towards
		player.orbit_cam_yaw.rotation.y -= rotate_towards                              # Counter-rotate the camera yaw so the camera's world-view remains completely stable
