class_name WeaponManagerHSM extends LimboHSM

# ROOT STATES
@onready var swap_state         : LimboState = %SwapState
@onready var unarmed_state      : LimboState = %UnarmedState

# ARMED SUB-MACHINE
@onready var armed_hsm          : LimboHSM   = %ArmedHSM
@onready var armed_router_state : LimboState = %ArmedRouterState
@onready var single_wield_state : LimboState = %SingleWieldState
@onready var dual_wield_state   : LimboState = %DualWieldState

# HSM STATES EVENTS
const EVENT_SWAP_REQ    : StringName = &"swap_requested"
const EVENT_SINGLE_EQ   : StringName = &"single_wield_equipped"
const EVENT_DUAL_EQ     : StringName = &"dual_wield_equipped"
const EVENT_EQUIP_FIN   : StringName = &"equip_finished"
const EVENT_UNEQUIP_FIN : StringName = &"unequip_finished"

func init_machine(manager_agent: WeaponManager) -> void:
	# ROOT LEVEL TRANSITIONS (Macro Flow)
	self.add_transition(unarmed_state, swap_state, EVENT_SWAP_REQ)
	self.add_transition(armed_hsm, swap_state, EVENT_SWAP_REQ)
	
	self.add_transition(swap_state, armed_hsm, EVENT_EQUIP_FIN)
	self.add_transition(swap_state, unarmed_state, EVENT_UNEQUIP_FIN)

	# ARMED SUB-STATE TRANSITIONS (Micro Flow)
	armed_hsm.initial_state = armed_router_state
	
	# Routing from the ArmedRouter to the correct stance
	armed_hsm.add_transition(armed_router_state, single_wield_state, EVENT_SINGLE_EQ)
	armed_hsm.add_transition(armed_router_state, dual_wield_state, EVENT_DUAL_EQ)
	
	# Swapping hands while already armed
	armed_hsm.add_transition(single_wield_state, dual_wield_state, EVENT_DUAL_EQ)
	armed_hsm.add_transition(dual_wield_state, single_wield_state, EVENT_SINGLE_EQ)

	# Initial State Setup
	if not (manager_agent.active_primary_weapon or manager_agent.active_secondary_weapon):
		self.initial_state = unarmed_state
	else:
		self.initial_state = armed_hsm
	
	# Boot up the nested machines
	armed_hsm.initialize(manager_agent)
	self.initialize(manager_agent)
	self.set_active(true)

var old_name: StringName = &""
func _update(delta: float) -> void:
	if self.get_active_state().name != old_name:
		print("WeaponManagerHSM -> " + self.get_active_state().name)
		old_name = self.get_active_state().name
		
