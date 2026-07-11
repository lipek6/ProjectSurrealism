class_name PlayerInput extends Node
# =============================================================================
# COMPONENT: PLAYER INPUT
## Responsibilities: A pure data container. Polls the OS/Engine for hardware 
## state exactly once per frame. Does ZERO logic or mathematical mutation.
## Separation of Concerns: Keeps the physics math entirely blind to hardware events.
# =============================================================================



# ==============================================================================
# ATTRIBUTES
# ==============================================================================
#region Movement Data
var move_direction                  : Vector2 = Vector2.ZERO                    ## [color=cyan]Raw Input Vector.[/color] [br]The normalized 2D direction from WASD or left joystick.
var wished_direction                : Vector3 = Vector3.ZERO                    ## [color=orange]Player-Aligned Wished Velocity.[/color] [br]The movement intent rotated to match the player body's forward direction.
var camera_aligned_wished_direction : Vector3 = Vector3.ZERO                    ## [color=yellow]Camera-Aligned Wished Velocity.[/color] [br]The movement intent rotated to match where the camera is currently looking (useful for noclip).
var controller_look                 : Vector2 = Vector2.ZERO                    ## [color=pink]Analog Look Vector.[/color] [br]Smoothed raw input from the right stick for gamepad aiming.
#endregion


#region Button States
var next_camera_pressed             : bool    = false                           ## [color=green]Camera Swap.[/color] [br]True on the exact frame the swap camera button is pressed.
var jump_pressed                    : bool    = false                           ## [color=green]Jump Pressed.[/color] [br]True on the exact frame the jump button is hit.
var jump_held                       : bool    = false                           ## [color=green]Jump Held.[/color] [br]True while the jump button remains held down.
var sprint_held                     : bool    = false                           ## [color=green]Sprint Held.[/color] [br]True while the sprint button remains held down.
var crouch_held                     : bool    = false                           ## [color=green]Crouch Held.[/color] [br]True while the crouch button remains held down.
#endregion


#region Toggles & Debug
var toggle_sprint_pressed           : bool    = false                           ## [color=gray]Toggle Sprint.[/color] [br]True on the exact frame the sprint toggle button is hit.
var toggle_noclip_pressed           : bool    = false                           ## [color=red]Toggle Noclip.[/color] [br]True on the exact frame the noclip debug button is hit.
var noclip_increase_pressed         : bool    = false                           ## [color=red]Noclip Speed Up.[/color] [br]Scroll wheel up during noclip.
var noclip_decrease_pressed         : bool    = false                           ## [color=red]Noclip Speed Down.[/color] [br]Scroll wheel down during noclip.
#endregion



# ==============================================================================
# METHODS
# ==============================================================================
#region Core Execution
## Polls the hardware and populates the struct. Requires basis variables to translate raw input into 3D world space vectors.
func gather_inputs(player_basis: Basis, camera_basis: Basis) -> void:
	#region Hardware Polling
	move_direction          = Input.get_vector("move_left", "move_right", "move_forward", "move_backward").normalized()
	next_camera_pressed     = Input.is_action_just_pressed("next_camera")
	jump_pressed            = Input.is_action_just_pressed("jump")
	jump_held               = Input.is_action_pressed("jump")
	sprint_held             = Input.is_action_pressed("sprint")
	crouch_held             = Input.is_action_pressed("crouch")
	toggle_sprint_pressed   = Input.is_action_just_pressed("toggle_sprint")
	toggle_noclip_pressed   = Input.is_action_just_pressed("_noclip")
	noclip_increase_pressed = Input.is_action_just_pressed("_increase_noclip_speed")
	noclip_decrease_pressed = Input.is_action_just_pressed("_decrease_noclip_speed")
	#endregion
	
	#region Vector Translations
	wished_direction                   = player_basis * Vector3(move_direction.x, 0, move_direction.y)
	camera_aligned_wished_direction    = camera_basis * Vector3(move_direction.x, 0, move_direction.y)
	#endregion
#endregion
