class_name ActorWeaponAnimationController extends Node

@export var weapon_manager : WeaponManager
@export var anim_tree      : AnimationTree

@export_group("Animation Settings")
@export var anim_prefix    : String = "fp_" 

var primary_playback   : AnimationNodeStateMachinePlayback
var secondary_playback : AnimationNodeStateMachinePlayback


func _ready() -> void:
	if not weapon_manager:
		push_error("Motherfucker, why did you put a WEAPON ANIMATION CONTROLLER into something that doesn't have a weapon manager?")
		return
		
	weapon_manager.weapon_equipped.connect(_on_weapon_equipped)
	weapon_manager.weapon_holstered.connect(_on_weapon_holstered)
	weapon_manager.request_conextual_actor_animation.connect(_on_animation_requested)
	
	if anim_tree and anim_tree.tree_root:
		primary_playback   = anim_tree.get("parameters/PrimaryFSM/playback")
		secondary_playback = anim_tree.get("parameters/SecondaryFSM/playback")


func _on_weapon_equipped(weapon_data: WeaponResource, is_primary_weapon: bool, is_dual_wielding: bool) -> void:
	_inject_weapon_data(weapon_data, is_primary_weapon, is_dual_wielding)




func _on_weapon_holstered(is_primary_weapon: bool) -> void:
	# Refreshing here is what automatically removes the "_r" from the primary 
	# weapon when the secondary is thrown away!
	_refresh_all_injections()



func _refresh_all_injections() -> void:
	# Evaluate the global dual-wield state
	var is_dual_wielding: bool = weapon_manager.active_primary_weapon != null and weapon_manager.active_secondary_weapon != null
	
	# Inject Primary Hand (if holding something)
	if weapon_manager.active_primary_weapon:
		_inject_weapon_data(weapon_manager.active_primary_weapon.data, true, is_dual_wielding)
		
	# Inject Secondary Hand (if holding something)
	if weapon_manager.active_secondary_weapon:
		_inject_weapon_data(weapon_manager.active_secondary_weapon.data, false, is_dual_wielding)
		
	# Update the bone mask filter
	_update_dual_wield_blend(is_dual_wielding)


func _inject_weapon_data(weapon_data: WeaponResource, is_primary_weapon: bool, is_dual_wielding: bool) -> void:
	var fsm_name: StringName = &"PrimaryFSM" if is_primary_weapon else &"SecondaryFSM"
	var fsm: AnimationNodeStateMachine = anim_tree.tree_root.get_node(fsm_name)
	
	var suffix: String = ""
	if weapon_data.is_dual_wieldable and is_dual_wielding:
		suffix = "_r" if is_primary_weapon else "_l"
		
	_inject(fsm, &"Equip", weapon_data.equip_animation, suffix)
	_inject(fsm, &"Unequip", weapon_data.unequip_animation, suffix)
	_inject(fsm, &"Idle", weapon_data.idle_animation, suffix)
	_inject(fsm, &"Inspect", weapon_data.inspect_animation, suffix)
	_inject(fsm, &"Reload", weapon_data.reload_animation, suffix)
	_inject(fsm, &"ReloadEmpty", weapon_data.reload_empty_animation, suffix)
	_inject(fsm, &"PrimaryPull", weapon_data.primary_trigger_pull_animation, suffix)
	_inject(fsm, &"SecondaryPull", weapon_data.secondary_trigger_pull_animation, suffix)
	_inject(fsm, &"PrimaryRelease", weapon_data.primary_trigger_release_animation, suffix)
	_inject(fsm, &"SecondaryRelease", weapon_data.secondary_trigger_release_animation, suffix)


func _update_dual_wield_blend(is_dual_wielding: bool) -> void:
	var target_blend : float = 1.0 if is_dual_wielding else 0.0
	anim_tree.set("parameters/DualWieldMixer/blend_amount", target_blend)


func _inject(fsm: AnimationNodeStateMachine, state_name: StringName, base_anim_name: StringName, suffix: String) -> void:
	if base_anim_name == &"" or not fsm: return
	
	if not fsm.has_node(state_name):
		push_warning("FSM does not contain the generic state: " + String(state_name))
		return
		
	var anim_node: AnimationNodeAnimation = fsm.get_node(state_name) as AnimationNodeAnimation
	if anim_node:
		anim_node.animation = StringName(anim_prefix + String(base_anim_name) + suffix)


func _on_animation_requested(state_name: StringName, force_restart: bool, duration: float, is_secondary: bool) -> void:
	var playback: AnimationNodeStateMachinePlayback = primary_playback if not is_secondary else secondary_playback
	if playback:
		if force_restart:
			playback.start(state_name)
		else:
			playback.travel(state_name)
