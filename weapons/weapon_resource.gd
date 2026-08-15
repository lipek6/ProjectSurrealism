class_name WeaponResource extends Resource

enum FIRE_MODE { MELEE, SEMI_AUTOMATIC, AUTOMATIC }

@export_group("Identification")
@export var id_name : StringName

@export_group("Visual Data")
@export var view_model  : PackedScene                                           ## Used by Actors
@export var world_model : PackedScene                                           ## Spawned in the world and dropped by Actors
@export var case_model  : PackedScene                                           ## The shell or bullet case to be spawned when shooting

@export_group("UI Assets")
@export var icon                  : Texture2D                                   ## Standard single-wield icon
@export var dual_icon             : Texture2D                                   ## Icon showing two guns
@export var bullet_icon           : Texture2D                                   ## Used for the Ammo Slot
@export var alt_fire_bullet_icon  : Texture2D
@export var reticle               : Texture2D                                   ## Used for the Crosshair

@export_group("Hand Placement fix")
@export var placement_fix : PlacementFixTransform

@export_group("Actor Animation")
@export var equip_animation                     : StringName
@export var unequip_animation                   : StringName
@export var idle_animation                      : StringName
@export var inspect_animation                   : StringName
@export var reload_animation                    : StringName
@export var reload_empty_animation              : StringName
@export var primary_trigger_pull_animation      : StringName
@export var secondary_trigger_pull_animation    : StringName
@export var primary_trigger_release_animation   : StringName
@export var secondary_trigger_release_animation : StringName
@export var sway                                : float


@export_group("Audio Data")
@export var idle_sound         : AudioStream
@export var reload_sound       : AudioStream
@export var reload_empty_sound : AudioStream
@export var shoot_sound        : AudioStream
@export var dry_shoot_sound    : AudioStream
@export var equip_sound        : AudioStream
@export var unequip_sound      : AudioStream

@export_group("Combat & Limits")
@export var damage : int = 25 

@export_subgroup("Firing")
@export var fire_mode : FIRE_MODE = FIRE_MODE.SEMI_AUTOMATIC
@export var fire_rate : float = 7.5                                             ## Bullets fired per second (5.0 = 1 shot every 0.2 seconds). fire_rate * 60 = rounds per minute

@export_subgroup("Ammo")
@export var uses_primary_ammo    : bool = true   # TODO: SETUP THIS EXPORT TO REALLY WORK INSIDE THE WEAPON STATE MACHINE. IF SET TO FALSE, SHOOTING/ACTING WON'T CONSUME AMMO.
@export var uses_secondary_ammo  : bool = false

@export_subgroup("Primary")
@export var primary_pickable_ground_ammo : bool = true
@export var primary_ammo_cost            : int = 1
@export var primary_max_mag_ammo         : int = 12
@export var primary_max_reserve_ammo     : int = 144
@export var primary_ammo_to_scav         : int = 24

@export_subgroup("Secondary")
@export var secondary_pickable_ground_ammo : bool = false
@export var secondary_ammo_cost            : int = 1
@export var secondary_max_mag_ammo         : int = 1
@export var secondary_max_reserve_ammo     : int = 6
@export var secondary_ammo_to_scav         : int = 1

@export_group("Equip behaviour")
@export var is_dual_wieldable : bool = false
