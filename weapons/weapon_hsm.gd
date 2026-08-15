class_name WeaponHSM extends LimboHSM

const EVENT_EQUIP_STARTED    : StringName= &"equip_started"
const EVENT_UNEQUIP_STARTED  : StringName= &"unequip_started"
const EVENT_ACTION_STARTED   : StringName= &"action_started"
const EVENT_RELOAD_STARTED   : StringName= &"reload_started"
const EVENT_SEQ_COMPLETED    : StringName= &"sequence_completed"

const ROUTE_PRIMARY          : StringName= &"route_primary"
const ROUTE_SECONDARY        : StringName= &"route_secondary"

const ROUTE_PRIMARY_RELOAD   : StringName= &"route_primary_reload"
const ROUTE_SECONDARY_RELOAD : StringName= &"route_secondary_reload"

@export var debug_print: bool = false

@onready var idle_state               : LimboState = %IdleState
@onready var equip_state              : LimboState = %EquipState
@onready var unequip_state            : LimboState = %UnequipState

@onready var action_hsm               : LimboHSM   = %ActionHSM
@onready var action_router_state      : LimboState = %ActionRouterState
@onready var primary_action_state     : LimboState = %PrimaryActionState
@onready var primary_recovery_state   : LimboState = %PrimaryRecoveryState
@onready var secondary_action_state   : LimboState = %SecondaryActionState
@onready var secondary_recovery_state : LimboState = %SecondaryRecoveryState

@onready var reload_hsm               : LimboHSM   = %ReloadHSM
@onready var reload_router_state      : LimboState = %ReloadRouterState
@onready var primary_reload_state     : LimboState = %PrimaryReloadState
@onready var secondary_reload_state   : LimboState = %SecondaryReloadState


# Call this from the WeaponInstance's _ready() function
func init_machine(weapon_agent: WeaponInstance) -> void:
	self.initial_state = equip_state
	
	# MACRO FLOW (ANYSTATE interrupts guarantee we can always swap weapons!)
	self.add_transition(self.ANYSTATE, unequip_state, EVENT_UNEQUIP_STARTED)
	self.add_transition(self.ANYSTATE, equip_state, EVENT_EQUIP_STARTED)
	self.add_transition(equip_state, idle_state, equip_state.EVENT_FINISHED)
	
	# TRANSITIONS OUT OF IDLE
	self.add_transition(idle_state, action_hsm, EVENT_ACTION_STARTED)
	self.add_transition(idle_state, reload_hsm, EVENT_RELOAD_STARTED)
	
	# TRANSITIONS BACK TO IDLE
	self.add_transition(action_hsm, idle_state, EVENT_SEQ_COMPLETED)
	self.add_transition(reload_hsm, idle_state, EVENT_SEQ_COMPLETED)
	
	# ACTION SUB-MACHINE WIRING
	action_hsm.initial_state = action_router_state
	action_hsm.add_transition(action_router_state, primary_action_state, ROUTE_PRIMARY)
	action_hsm.add_transition(action_router_state, secondary_action_state, ROUTE_SECONDARY)
	action_hsm.add_transition(primary_action_state, primary_recovery_state, primary_action_state.EVENT_FINISHED)
	action_hsm.add_transition(secondary_action_state, secondary_recovery_state, secondary_action_state.EVENT_FINISHED)
	# Note: RecoveryState will dispatch EVENT_SEQ_COMPLETED to exit the ActionHSM.
	
	# RELOAD SUB-MACHINE WIRING
	reload_hsm.initial_state = reload_router_state
	reload_hsm.add_transition(reload_router_state, primary_reload_state, ROUTE_PRIMARY_RELOAD)
	reload_hsm.add_transition(reload_router_state, secondary_reload_state, ROUTE_SECONDARY_RELOAD)
	
	
	# Boot up the nested machines
	self.initialize(weapon_agent)
	action_hsm.initialize(weapon_agent)
	reload_hsm.initialize(weapon_agent)

var old_name: StringName = &""
func _update(delta: float) -> void:
	if debug_print:
		if self.get_active_state().name != old_name:
			print("WeaponHSM -> " + self.get_active_state().name)
			old_name = self.get_active_state().name
		
