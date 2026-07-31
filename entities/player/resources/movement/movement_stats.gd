class_name MovementStats extends Resource



#region Ground Movement
@export_group("Ground Movement")
@export var auto_bhop               : bool  = false                             ## [color=green]Hold jump to continuously bounce.[/color] [br]If true, holding the jump button automatically triggers a jump on the exact frame the player lands.
@export var auto_sprint             : bool  = true                              ## [color=cyan]Inverts sprint key logic.[/color] [br]If true, the player sprints by default and walks only when holding the sprint key.
@export var walk_speed              : float = 5.5                               ## [color=yellow]Base walking velocity (m/s).[/color] [br]Standard speed for normal ground traversal.
@export var sprint_speed            : float = 7.5                               ## [color=orange]Maximum running velocity (m/s).[/color] [br]Achieved when sprinting.
@export var ground_accel            : float = 14.0                              ## [color=cyan]Acceleration rate.[/color] [br]How quickly the player reaches max speed from a standstill. Higher values = snappier movement.
@export var ground_decel            : float = 10.0                              ## [color=cyan]Deceleration rate.[/color] [br]How quickly the player comes to a halt when releasing the movement keys.
@export var ground_friction         : float = 3.0                               ## [color=orange]Friction multiplier.[/color] [br]Applied against deceleration. Lower values make the floor feel like ice.
@export var max_step_height         : float = 0.5                               ## [color=pink]Stair snap height (m).[/color] [br]Maximum height of a ledge/stair the player will automatically step onto without jumping.
@export var crouch_translate        : float = 0.7                               ## [color=pink]Crouch depth (m).[/color] [br]How much the physical collision capsule shrinks and the camera lowers when crouching.
@export var crouch_jump_add         : float = 0.7 * 0.9                         ## [color=pink]Crouch-jump clearance (m).[/color] [br]Usually [code]crouch_translate * 0.9[/code]. Extra height gained by pulling legs up mid-air.
@export var crouch_speed_multiplier : float = 0.7                               ## [color=yellow]Crouch speed penalty.[/color] [br]Multiplies base speed. [code]0.8[/code] means moving at 80% speed while crouching.
#endregion


#region Air movement
@export_group("Air Movement")
@export var jump_velocity  : float = 6.0                                        ## [color=green]Initial jump burst (m/s).[/color] [br]Upward impulse instantly applied when jumping.
@export var air_cap        : float = 0.85                                       ## [color=yellow]Air strafe speed limit.[/color] [br]Caps how fast you can accelerate purely from air strafing vectors.
@export var air_accel      : float = 800.0                                      ## [color=orange]Air acceleration force.[/color] [br]Source-engine style high air accel for crisp mid-air directional changes and surfing.
@export var air_move_speed : float = 500.0                                      ## [color=orange]Base air move speed.[/color] [br]Used in conjunction with [code]air_accel[/code] to define the air-strafing handling curve.
#endregion


#region Debug
@export_group("Debug")
@export var can_noclip                       : bool  = false                    ## [color=red][DEBUG][/color] [color=cyan]Enables noclip toggle.[/color] [br]If true, allows the player to enter a flying ghost-cam mode.
@export var noclip                           : bool  = false                    ## [color=red][DEBUG][/color] [color=red]Current Noclip state.[/color] [br]If true, player flies and ignores all collisions.
@export var noclip_max_speed                 : float = 100.0                    ## [color=red][DEBUG][/color] [color=gray]Max fly speed.[/color] [br]Absolute limit for scroll-wheel speed increases in noclip.
@export var noclip_min_speed                 : float = 0.1                      ## [color=red][DEBUG][/color] [color=gray]Min fly speed.[/color] [br]Absolute limit for scroll-wheel speed decreases in noclip.
@export var noclip_speed_multiplier          : float = 3.0                      ## [color=red][DEBUG][/color] [color=yellow]Current fly speed multiplier.[/color] [br]Modifies base walk speed when flying.
@export var noclip_speed_increase_multiplier : float = 1.1                      ## [color=red][DEBUG][/color] [color=gray]Scroll-up scale.[/color] [br]How much speed increases per mouse scroll tick.
@export var noclip_speed_decrease_multiplier : float = 0.9                      ## [color=red][DEBUG][/color] [color=gray]Scroll-down scale.[/color] [br]How much speed decreases per mouse scroll tick.
#endregion
