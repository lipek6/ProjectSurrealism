class_name ThirdPersonState extends CameraState
var _saved_camera_global_position : Vector3 = Vector3.INF

func enter() -> void:
	player.tp_camera.make_current()
	state_machine.active_camera = player.tp_camera

func exit() -> void:
	pass


func input_update(event : InputEventMouseMotion) -> void:
	player.orbit_cam_yaw.rotation.y = 0.0
	player.rotate_y(-event.relative.x * stats.tp_look_sensitivity)
	player.orbit_cam_pitch.rotate_x(-event.relative.y * stats.tp_look_sensitivity)
	player.orbit_cam_pitch.rotation_degrees.x = clampf(player.orbit_cam_pitch.rotation_degrees.x, -89, +89)

func physics_update(delta: float) -> void:
	if input.wants_camera_swap:
		state_machine.transition_to(&"ThirdPersonFreeLookState")
		return
