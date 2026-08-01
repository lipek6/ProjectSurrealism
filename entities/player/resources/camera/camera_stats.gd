class_name CameraStats extends Resource

@export_group("Camera Settings")
@export var tp_look_sensitivity            : float = 0.006                      ## [color=yellow]Third-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in TP.
@export var fp_look_sensitivity            : float = 0.006                      ## [color=yellow]First-person mouse aim speed.[/color] [br]Multiplier for raw mouse input in FP. [br]Common range: [code]0.002[/code] to [code]0.01[/code].
@export var crouch_camera_offset           : float = 0.7                        
@export var controller_fp_look_sensitivity : float = 0.075                      ## [color=yellow]FP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var controller_tp_look_sensitivity : float = 0.075                      ## [color=yellow]TP Gamepad aim speed.[/color] [br]Multiplier for right-stick analog input.
@export var headbob                        : bool  = true                       ## [color=cyan]Enables fp_camera bobbing.[/color] [br]Simulates realistic footsteps visually when walking/sprinting on the ground.
@export var smooth_headbob                 : bool  = false
