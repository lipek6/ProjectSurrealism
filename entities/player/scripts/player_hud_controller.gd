class_name PlayerHUDController extends CanvasLayer
## Passive UI component. Controlled entirely by the Player orchestrator.

@export_group("Gameplay UI Elements")
@export var gameplay_ui : Control             ## The main transparent HUD (Crosshair, Ammo, Health)
@export var weapon_name_label : Label
@export var ammo_label : Label
@export var health_label : Label

@export_group("Pause Menu Elements")
@export var pause_menu_ui : Control           ## The opaque/blurred pause screen overlay


func _ready() -> void:
	queue_free()
	# Ensure correct starting state
	if gameplay_ui: gameplay_ui.visible = true
	if pause_menu_ui: pause_menu_ui.visible = false


## Called every visual frame by the Player orchestrator
func update_hud(health: int, weapon_name: String, on_mag: int, on_reserve: int) -> void:
	if health_label:
		health_label.text = "SHIELDS: " + str(health)
		
	if weapon_name_label:
		weapon_name_label.text = weapon_name
		
	if ammo_label:
		# Format: 60 / 120
		ammo_label.text = str(on_mag) + " / " + str(on_reserve)


## Toggles the visibility of the UI layers based on game state
func set_pause_state(is_paused: bool) -> void:
	if pause_menu_ui: pause_menu_ui.visible = is_paused
	if gameplay_ui:   gameplay_ui.visible = not is_paused
