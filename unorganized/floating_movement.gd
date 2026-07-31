@tool
class_name FloatingMovement extends Node3D
## Procedurally animates a visual node with hovering, spinning, and orbiting math.

@export_group("Editor Preview")
@export var preview_in_editor : bool = false                        ## Toggle ON to preview animation. Toggle OFF to move the object manually.

@export_group("Hover Settings")
@export var hover_speed : float = 2.0
@export var hover_amplitude : Vector3 = Vector3(0.0, 0.5, 0.0)      ## Meters to drift on each axis

@export_group("Spin Settings")
@export var local_spin_speed : Vector3 = Vector3(0.0, 1.0, 0.0)     ## Radians per second

@export_group("Orbit Settings")
@export var orbit_speed : float = 0.0                               ## Radians per second around the center
@export var orbit_center : Vector3 = Vector3.ZERO                   ## The world coordinate to orbit around

var _initial_position : Vector3
var _initial_rotation : Vector3
var _time_passed : float = 0.0
var _current_orbit_angle : float = 0.0
var _orbit_radius : float = 0.0

func _ready() -> void:
	_initial_position = self.global_position
	_initial_rotation = self.rotation
	_recalculate_orbit()

func _recalculate_orbit() -> void:
	_orbit_radius = Vector2(_initial_position.x - orbit_center.x, _initial_position.z - orbit_center.z).length()
	_current_orbit_angle = atan2(_initial_position.z - orbit_center.z, _initial_position.x - orbit_center.x)

func _process(delta: float) -> void:
	# --- EDITOR SAFETY LOGIC ---
	if Engine.is_editor_hint():
		if not preview_in_editor:
			# Track manual editor movements so we know where to animate from later
			_initial_position = self.global_position
			_initial_rotation = self.rotation
			_recalculate_orbit()
			_time_passed = 0.0
			return
			
	_time_passed += delta * hover_speed

	# 1. LOCAL SPIN
	if local_spin_speed != Vector3.ZERO:
		rotate_x(local_spin_speed.x * delta)
		rotate_y(local_spin_speed.y * delta)
		rotate_z(local_spin_speed.z * delta)

	# 2. ORBIT & HOVER MATH
	var target_pos = _initial_position
	
	if orbit_speed != 0.0:
		_current_orbit_angle += orbit_speed * delta
		target_pos.x = orbit_center.x + cos(_current_orbit_angle) * _orbit_radius
		target_pos.z = orbit_center.z + sin(_current_orbit_angle) * _orbit_radius

	target_pos.x += sin(_time_passed) * hover_amplitude.x
	target_pos.y += sin(_time_passed) * hover_amplitude.y
	target_pos.z += sin(_time_passed) * hover_amplitude.z

	self.global_position = target_pos
