@tool
class_name MenuCameraPan extends Camera3D
## Creates a cinematic, infinitely sweeping camera for the main menu.

@export_group("Editor Preview")
@export var preview_in_editor : bool = false                    ## Toggle ON to preview camera pan. Toggle OFF to move the camera.

@export_group("Pan Settings")
@export var look_target : Vector3 = Vector3.ZERO                ## What the camera should always point at
@export var pan_speed : float = 0.3                             ## How fast it drifts
@export var pan_distance : Vector3 = Vector3(3.0, 1.0, 2.0)     ## Maximum drift distance on X, Y, Z

var _base_position : Vector3
var _time_passed : float = 0.0

func _ready() -> void:
	_base_position = self.global_position

func _process(delta: float) -> void:
	# --- EDITOR SAFETY LOGIC ---
	if Engine.is_editor_hint():
		if not preview_in_editor:
			# Track the camera while you drag it around the editor
			_base_position = self.global_position
			_time_passed = 0.0
			return

	_time_passed += delta * pan_speed
	
	var offset = Vector3(
		sin(_time_passed * 1.0) * pan_distance.x,
		sin(_time_passed * 1.3) * pan_distance.y,  
		sin(_time_passed * 0.7) * pan_distance.z   
	)
	
	self.global_position = _base_position + offset
	self.look_at(look_target, Vector3.UP)
