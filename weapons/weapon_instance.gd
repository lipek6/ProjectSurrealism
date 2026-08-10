class_name WeaponInstance extends Node3D
## Abstract Base Class for all weapons.

enum DENIAL_REASON { OUT_OF_AMMO, MAG_FULL, NO_RESERVE, OVERHEATED }

# --- COMBAT / ACTION SIGNALS ---
signal primary_fired()
signal secondary_fired()
signal primary_pulled()
signal secondary_pulled()
signal primary_released()
signal secondary_released()

# --- AMMO & RELOAD SIGNALS ---
# Emitted immediately after firing, reloading, or scavenging
signal ammo_updated(current_mag: int, current_reserve: int) 

# duration allows the AnimationTree to scale the animation speed perfectly
signal reload_started(duration: float, is_empty: bool) 
signal reload_finished()

# --- EDGE CASE SIGNALS ---
# Used for UI "click" sounds or flashing red text
signal action_denied(reason: DENIAL_REASON)




@export var animation : AnimationPlayer
@export var audio     : AudioStreamPlayer3D

@export_group("State Machine")
@export var hsm: LimboHSM
@export var idle_state: LimboState
@export var action_state: LimboState
@export var primary_action_state: LimboState
@export var secondary_action_state: LimboState
@export var equip_state: LimboState
@export var unequip_state: LimboState
@export var reload_state: LimboState
@export var primary_reload_state: LimboState
@export var secondary_reload_state: LimboState








var data: WeaponResource

# Volatile State (Unique to this specific gun in the world)
var current_mag_ammo      : int
var current_reserve_ammo  : int
var current_fire_cooldown : float
var primary_trigger_held   : bool = false
var secondary_trigger_held : bool = false

func _ready() -> void:
	if not data:
		push_warning("Weapon spawned without data injection!")
		return
	
	# Initialize our unique pool from the blueprint limits
	current_mag_ammo     = data.max_mag_ammo
	current_reserve_ammo = data.max_reserve_ammo
	set_process(false) # The gun does not process time while holstered or on the ground.
	
	# Initialize State Machine
	hsm.initialize(self)
	hsm.set_active(true)


func _process(delta: float) -> void:
	if current_fire_cooldown > 0.0: current_fire_cooldown -= delta


# ==============================================================================
# VIRTUAL INTERFACE (Must be overridden by specific guns)
# ==============================================================================
func pull_primary_trigger() -> void:
	push_warning("pull_primary_trigger() not implemented in " + self.name)

func release_primary_trigger() -> void:
	push_warning("release_primary_trigger() not implemented in " + self.name)

func pull_secondary_trigger() -> void:
	pass # Optional to override

func release_secondary_trigger() -> void:
	pass # Optional to override

func reload() -> void:
	pass

func equip() -> void:
	# Emitting this here ensures the UI always updates the exact frame a new gun is drawn! 
	ammo_updated.emit(current_mag_ammo, current_reserve_ammo)

func unequip() -> void:
	pass # Optional to override
