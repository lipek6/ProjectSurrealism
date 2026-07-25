class_name WeaponResource extends Resource

enum FIRE_MODE { SEMI_AUTOMATIC, AUTOMATIC }



@export_group("Misc")
@export var weapon_name : String


@export_group("Stats")
@export var damage       : int
@export var impact_force : float

@export_group("Gunplay Mechanics")
@export var fire_mode    : FIRE_MODE                  
@export var fire_rate    : float                        ## Bullets fired per second (5.0 = 1 shot every 0.2 seconds)
@export var hybrid_ballistics_distance : float          ## Meters. Targets closer than this take instant Hitscan damage. Targets further spawn a physical bullet.


@export_subgroup("Ammo")
@export var pickable_ground_ammo : bool = true
@export var max_on_mag_ammo      : int
@export var on_mag_ammo          : int
@export var max_on_reserve_ammo  : int
@export var on_reserve_ammo      : int
@export var ammo_cost            : int


@export_group("Visual Data")
@export var weapon_scene   : PackedScene
@export var casing_scene   : PackedScene
@export var shoot_effect: PackedScene

@export_group("Audio Data")
@export var shoot_sound     : AudioStream
@export var reload_sound    : AudioStream
@export var equip_sound     : AudioStream
@export var unequip_sound   : AudioStream
