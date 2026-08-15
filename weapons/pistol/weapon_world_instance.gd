class_name WeaponWorldInstance extends RigidBody3D

var data: WeaponResource

var use_default_ammo_amount: bool = true

var prim_mag_ammo: int
var prim_res_ammo: int
var sec_mag_ammo : int 
var sec_res_ammo : int 


func _ready() -> void:
	if data and use_default_ammo_amount:
		prim_mag_ammo = data.primary_max_mag_ammo
		prim_res_ammo = data.primary_ammo_to_scav
		sec_mag_ammo  = data.secondary_max_mag_ammo
		sec_res_ammo  = data.secondary_ammo_to_scav


func set_ammo(new_prim_mag_ammo: int = 0, new_prim_res_ammo: int = 0, new_sec_mag_ammo: int = 0, new_sec_res_ammo: int = 0) -> void:
	use_default_ammo_amount = false
	prim_mag_ammo = new_prim_mag_ammo
	prim_res_ammo = new_prim_res_ammo
	sec_mag_ammo  = new_sec_mag_ammo
	sec_res_ammo  = new_sec_res_ammo
