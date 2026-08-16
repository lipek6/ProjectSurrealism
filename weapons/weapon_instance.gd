class_name WeaponInstance extends Node3D
## Base class for all weapons. Acts purely as a hardware interface and data container.

enum DENIAL_REASON { OUT_OF_AMMO, MAG_FULL, NO_RESERVE, OVERHEATED }

# --- SIGNALS ---
signal request_actor_animation(state_name: StringName, force_restart: bool, duration: float)


# --- HARDWARE REFERENCES ---
@export var animation : AnimationPlayer
@export var audio     : AudioStreamPlayer3D



# --- WEAPON ANIMATIONS ---
@export_group("Mechanical Animations")
@export var anim_idle                 : StringName = &""
@export var anim_equip                : StringName = &""
@export var anim_unequip              : StringName = &""
@export var anim_primary_shoot        : StringName = &""
@export var anim_primary_shoot_last   : StringName = &""
@export var anim_primary_reload       : StringName = &""
@export var anim_primary_reload_empty : StringName = &""


# --- STATE MACHINE NODES ---
@onready var hsm: WeaponHSM = %WeaponHSM

# --- CORE DATA ---
var data: WeaponResource
var current_primary_mag_ammo       : int
var current_primary_reserve_ammo   : int
var current_secondary_mag_ammo     : int
var current_secondary_reserve_ammo : int
var _is_ammo_initialized           : bool = false 


# --- VOLATILE INPUT STATE ---
# The WeaponManager will update these directly
var wants_shoot           : bool = false
var wants_primary_shoot   : bool = false
var wants_secondary_shoot : bool = false
var wants_reload          : bool = false
var wants_unequip         : bool = false # TODO: Make the weapon manger actually use this, it's currently using a unequip() function that doesn't exist anymore.

func _ready() -> void:
	if not data:
		push_warning("Weapon spawned without data injection!")
		return
	
	# SETUP AMMO (ONLY IF NOT INJECTED BY THE MANAGER)
	if not _is_ammo_initialized:
		if data.uses_primary_ammo:
			current_primary_mag_ammo     = data.primary_max_mag_ammo
			current_primary_reserve_ammo = data.primary_max_reserve_ammo
		else:
			current_primary_mag_ammo     = 1_000_000_000
			current_primary_reserve_ammo = 1_000_000_000
		
		if data.uses_secondary_ammo:
			current_secondary_mag_ammo     = data.secondary_max_mag_ammo
			current_secondary_reserve_ammo = data.secondary_max_reserve_ammo
		else:
			current_secondary_mag_ammo     = 1_000_000_000
			current_secondary_reserve_ammo = 1_000_000_000
	
	hsm.init_machine(self)
