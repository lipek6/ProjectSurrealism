class_name FirstPersonState extends CameraState

#region Internal Variables
const HEADBOB_MOVE_AMOUNT : float = 0.06
const HEADBOB_FREQUNCY    : float = 2.4
var headbob_time          : float = 0.0
var _saved_camera_global_position : Vector3 = Vector3.INF
#endregion


func enter() -> void:
	player.fp_camera.make_current()
	state_machine.active_camera = player.fp_camera
	player.stepped_on_stair.connect(_save_camera_position_for_smoothing)

func exit() -> void:
	player.stepped_on_stair.disconnect(_save_camera_position_for_smoothing)


func input_update(event : InputEventMouseMotion) -> void:
	player.rotate_y(-event.relative.x * stats.fp_look_sensitivity)
	player.fp_camera.rotate_x(-event.relative.y * stats.fp_look_sensitivity)
	player.fp_camera.rotation_degrees.x = clampf(player.fp_camera.rotation_degrees.x, -89, +89)

func physics_update(delta: float) -> void:
	# Check for swaps
	if input.wants_camera_swap:
		state_machine.transition_to(&"ThirdPersonState")
		return
	
	_slide_camera_smooth_back_to_origin(delta)
	_handle_crouch_camera_smoothing(delta)
	_handle_headbob(delta)
	

func _handle_headbob(delta : float) -> void:
	if not stats.headbob: return
	
	if input.is_moving and player.is_on_floor():                   # Check this way or check through the MovementStateMachine. Should State Machines communicate with each other??? I guess not...
		headbob_time += delta * player.velocity.length()
		player.fp_camera.transform.origin = Vector3(
			cos(headbob_time * HEADBOB_FREQUNCY * 0.5) * HEADBOB_MOVE_AMOUNT,       
			sin(headbob_time * HEADBOB_FREQUNCY) * HEADBOB_MOVE_AMOUNT,             
			0.0                                                                       
		)
	else:
		if stats.smooth_headbob:
			player.fp_camera.transform.origin = player.fp_camera.transform.origin.lerp(Vector3.ZERO, 10.0 * delta)


func _slide_camera_smooth_back_to_origin(delta : float) -> void:
	if _saved_camera_global_position == Vector3.INF: return 
	
	var global_diff : float = _saved_camera_global_position.y - player.camera_smooth_point.global_position.y
	
	# FIXED: Apply the difference to LOCAL position, preventing matrix skewing!
	player.camera_smooth_point.position.y += global_diff
	player.camera_smooth_point.position.y = clampf(player.camera_smooth_point.position.y, -0.7, 0.7)       
	
	var move_amount : float = maxf(player.velocity.length() * delta, player.movement_stats.walk_speed / 2.0 * delta)  
	player.camera_smooth_point.position.y = move_toward(player.camera_smooth_point.position.y, 0.0, move_amount)
	
	if player.camera_smooth_point.position.y == 0.0:
		_saved_camera_global_position = Vector3.INF 


func _handle_crouch_camera_smoothing(delta : float) -> void:
	var target_y : float = -stats.crouch_camera_offset if player.is_crouched else 0.0
	player.head.position.y = move_toward(player.head.position.y, target_y, 7.0 * delta)


func _save_camera_position_for_smoothing() -> void:
	if _saved_camera_global_position == Vector3.INF:
		_saved_camera_global_position = player.camera_smooth_point.global_position
