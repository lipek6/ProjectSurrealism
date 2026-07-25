@tool
class_name PhysicsProp extends RigidBody3D
# ==============================================================================
# PHYSICS PROP CLASS
## Provides a standardized, scalable architecture for all dynamic world objects 
## (crates, barrels, cans). Handles safe scaling, automatic mass calculation, 
## and stable player-riding mechanics without relying on fragile node structures.
#
# NOTICE: To make a great physics prop, you will need to tweak it in the editor
# until you find the neat spot for it. Don't fear messing around the values! 
# ==============================================================================

## Defines the behavioral category of this physics prop.
enum PropType {
	SMALL_DEBRIS, ## Tiny objects (bottles, mugs). Cannot be stood upon. Easily kicked around.
	INTERACTIVE,  ## Standard objects (crates, barrels). Can be stood upon. Dampens/locks rotation to stabilize the player.
	# INFO: More will be added for explosives and everything else (or maybe I should create inherited classes for those)
}



# ==========================================
# EXPORTED NODE REFERENCES
# ==========================================
#region Node References
@export_group("Internal Nodes") 
@export var model            : Node3D                                                 ## The visual 3D mesh of the object. We scale this instead of the root RigidBody to prevent engine glitches.
@export var collision        : CollisionShape3D                                       ## The physical bounds of the object. We scale this instead of the root RigidBody to prevent engine glitches.
@export var audio_player     : AudioStreamPlayer3D
@export var life_timer       : Timer 
#endregion



# ==========================================
# PROP SETTINGS
# ==========================================
#region Prop Configuration
@export_group("Prop Settings")
@export var health    : int = 100
@export var lifetime  : int = -1
@export var prop_type : PropType = PropType.INTERACTIVE               ## Categorizes how this object interacts with the world and the player.
@export var prop_scale: Vector3  = Vector3.ONE:                       ## Safely scales the visual mesh and colliders without breaking RigidBody3D physics calculations.[br] Standard RigidBody3D nodes break if their Transform Scale is modified directly.
	set(value):
		prop_scale = value
		_update_scale_and_mass()
@export var auto_calculate_mass : bool     = true:                              ## If true, tmasshe prop's  will automatically recalculate based on its volumetric scale.
	set(value):
		auto_calculate_mass = value
		_update_scale_and_mass()
@export var base_mass           : float    = 10.0:                              ## The baseline weight of this object at a scale of (1, 1, 1). [br] If auto_calculate_mass is true, scaling the object by (2, 2, 2) will multiply this mass by 8. 
	set(value):
		base_mass = value
		_update_scale_and_mass()

@export_group("Destructibility")
@export var is_fragile              : bool = false                              ## If true, the prop will shatter into VFX when health is 0 or it hits a wall too hard.
@export var shatter_vfx             : PackedScene                               ## The GPU Particle or broken mesh scene to spawn on destruction.
@export var impact_decal           : PackedScene
@export var kinetic_break_threshold : float = 15.0                              ## How fast the object must be moving when it hits a wall to shatter automatically.
#endregion



# ==========================================
# RIDING SETTINGS
# ==========================================
#region Riding Settings
@export_group("Riding Mechanics")
@export var allow_edge_teetering        : bool  = true                          ## If true, ONLY locks the Y-axis to prevent turntable spinning, allowing the box to teeter and fall off ledges (Source Engine style). [br] If false, completely locks X, Y and Z to act as an immovable perfect floating platform.
@export var damp_when_on_top            : bool  = false
@export var on_top_linear_damp          : float = 10.0                          ## The drag applied to the object's sliding movement when stood upon.[br](Common use case: Prevents the crate from acting like an ice-skate under the player's feet. Values around 10.0 are standard).
@export var on_top_angular_damp         : float = 50.0                          ## The massive drag applied to the object's rotation when stood upon.[br](Common use case: Source Engine/Half-Life 2 style interactions. Values between 30.0 and 60.0 prevent extreme tumbling while keeping physics "alive").
#endregion

# ==========================================
# AUDIO SETTINGS
# ==========================================
#region Audio Settings
@export_group("Audio")
@export var hit_sounds     : Array[AudioStream] = []                            ## Array of sounds to play when taking non-lethal damage.
#endregion




# ==========================================
# STATE VARIABLES
# ==========================================
#region State
var bodies_on_top  : int = 0
var _is_shattering : bool = false

@onready var _original_angular_damp : float = self.angular_damp                 ## Store original dampening values so we can restore them if we use the "Damp" method instead of "Lock Rotation".
@onready var _original_linear_damp  : float = self.linear_damp                  ## Store original dampening values so we can restore them if we use the "Damp" method instead of "Lock Rotation".                 
#endregion



# ==========================================
# CORE LIFECYCLE
# ==========================================
#region Lifecycle
func _ready() -> void:
	_update_scale_and_mass()
	if Engine.is_editor_hint(): return                                          # EDITOR GUARD: Stop executing logic if we are just building the level.
	
	# Apply Safe Scaling (NOTICE: We scale the children instead of the RigidBody3D itself to avoid physics engine glitches)
	if model:      model.scale = prop_scale
	if collision:  collision.scale = prop_scale
	
	if lifetime > 0 and life_timer != null:
		life_timer.timeout.connect(_on_life_timer_timeout)
		life_timer.wait_time = lifetime
		life_timer.one_shot = true
		life_timer.start(lifetime)
		
	# Setup impact monitoring if the object is glass/fragile
	if is_fragile:
		self.contact_monitor = true
		self.max_contacts_reported = 1
		self.body_entered.connect(_on_body_entered)

## Safely applies scale to children and dynamically calculates real-world mass.
## WARNING: Because this is bound to the setters, it runs continuously in the Godot Editor viewport!
func _update_scale_and_mass() -> void:
	if model:      model.scale      = prop_scale
	if collision:  collision.scale  = prop_scale
	if auto_calculate_mass:
		var volume_multiplier : float = prop_scale.x * prop_scale.y * prop_scale.z
		self.mass = abs(base_mass * volume_multiplier)
#endregion



# ==========================================
# STAND ON TOP HANDLERS
# ==========================================
#region Stand On Top Logic
## Called by the Player script when it detects its floor raycast is hitting this prop.
func notify_stepped_on(body : Node3D) -> void:
	# Ignore non-entities, and completely ignore SMALL_DEBRIS (like soda cans)
	if not body.is_in_group("Entity") or prop_type == PropType.SMALL_DEBRIS: return
	
	bodies_on_top += 1
	
	if body.has_method("activate_collision_feet_for_props"):
		body.activate_collision_feet_for_props()
	
	if bodies_on_top == 1:                                                      # The moment the first entity steps onto the prop, stabilize it.
		if not allow_edge_teetering:                                         
			self.axis_lock_angular_x = true
			self.axis_lock_angular_z = true
			self.axis_lock_angular_y = true
		if damp_when_on_top:                                                                   
			self.angular_damp = on_top_angular_damp
			self.linear_damp  = on_top_linear_damp


## Called by the Player script when it stops standing on this prop.
func notify_stepped_off(body : Node3D) -> void:
	# Ignore non-entities, and completely ignore SMALL_DEBRIS (like soda cans)
	if not body.is_in_group("Entity") or prop_type == PropType.SMALL_DEBRIS: return
	# Safely decrement, clamping at 0 to prevent negative math glitches
	bodies_on_top = max(0, bodies_on_top - 1) 
	
	if body.has_method("deactivate_collision_feet_for_props"):
		body.deactivate_collision_feet_for_props()
	
	# When the last entity steps off, restore normal physics.
	if bodies_on_top == 0:
		if not allow_edge_teetering: 
			self.axis_lock_angular_x = false
			self.axis_lock_angular_z = false
			self.axis_lock_angular_y = false
		if damp_when_on_top:
			self.angular_damp = _original_angular_damp
			self.linear_damp  = _original_linear_damp

## Allows the player to inject artificial gravity into the prop, allowing it to realistically teeter off edges.[br]
## - `force`: The continuous downward Vector3 (gravity * player weight).[br]
## - `point`: The global 3D coordinate where the player's foot is touching the box.
func apply_resting_weight(force : Vector3, point: Vector3) -> void:
	apply_force(force, point - self.global_position)                            # NOTE: apply_force is a continuous, time-dependent function meant to be called every physics frame.
#endregion



# ==========================================
# PICKUP HANDLERS
# ==========================================



# ==========================================
# DESTRUCTIBILITY & DAMAGE
# ==========================================
func take_damage(damage: int) -> void:
	health -= damage
	if health <= 0:
		if is_fragile:
			self.shatter()
		else:
			self.queue_free()

func take_impact(hit_point: Vector3, hit_direction: Vector3, impact_force: float) -> void:
	var impulse : Vector3 = hit_direction * impact_force
	var offset_from_center : Vector3 = hit_point - self.global_position         # Makes shooting in the corner spin things
	self.apply_impulse(impulse, offset_from_center)
	
	if health > 0: 
		play_hit_sound()
		spawn_decal(hit_point, hit_direction)

func spawn_decal(hit_point: Vector3, hit_direction: Vector3) -> void:
	if not impact_decal or not model: return
	
	var decal_instance : Node3D = impact_decal.instantiate()
	model.add_child(decal_instance)
	decal_instance.global_position = hit_point
	
	# Godot Decals project strictly along their local -Z axis. 
	# By looking AWAY from the bullet's trajectory, we project the sticker perfectly onto the surface.
	if hit_direction.is_normalized():
		decal_instance.look_at(hit_point - hit_direction, Vector3.UP)

func play_hit_sound() -> void:
	if hit_sounds.is_empty() or not audio_player: return
	
	audio_player.stream = hit_sounds.pick_random()                              # Grab a random sound from the array
	audio_player.pitch_scale = randf_range(0.9, 1.1)                            # Slightly randomize the pitch so repetitive shots don't sound like a machine gun glitch
	audio_player.play()

func shatter() -> void:
	if _is_shattering: return
	_is_shattering = true
	
	# Spawn the EFFECT (TODO: Correct the naming from VFX to EFX, since this thing handles both sound and visuals)
	if shatter_vfx:
		var vfx_instance : Node3D = shatter_vfx.instantiate()
		# Add to the root scene tree so the particles don't delete when the prop deletes
		get_tree().root.add_child(vfx_instance)
		vfx_instance.global_transform = self.global_transform
	
	# Delete the physical object, not the VFX!
	self.queue_free()

func _on_body_entered(body : Node) -> void:
	if not is_fragile: return
	# If the object hits something while moving extremely fast, it shatters
	if self.linear_velocity.length() >= kinetic_break_threshold:
		shatter()


func _on_life_timer_timeout() -> void:
	self.queue_free()
