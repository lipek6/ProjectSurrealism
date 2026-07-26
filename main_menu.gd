class_name MainMenu extends Node3D
## Handles 3D background rendering, UI input, and asynchronous background loading.

@export_file("*.tscn") var level_to_load : String

@onready var play_button    : Button    = %PlayButton
@onready var settings_button: Button    = %SettingsButton
@onready var exit_button    : Button    = %ExitButton
@onready var fade_rect      : ColorRect = %FadeRect

var _is_loading : bool = false
var _fade_complete : bool = false

func _ready() -> void:
	# Connect UI signals via code to avoid editor clutter
	play_button.pressed.connect(_on_play_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	
	# We will leave Settings empty for now until we build that UI panel!
	# settings_button.pressed.connect(_on_settings_pressed)

	# Ensure the fade rect starts fully transparent and doesn't block clicks
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ensure the mouse is visible and unlocked when entering the menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_play_pressed() -> void:
	# Prevent the player from mashing the play button 50 times
	if _is_loading: return
	_is_loading = true

	# Tell Godot to start loading the massive game level on a separate CPU thread
	ResourceLoader.load_threaded_request(level_to_load)

	# Create a smooth, 1.5-second fade to black
	var tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)
	tween.finished.connect(_on_fade_finished)
	

func _on_fade_finished() -> void:
	_fade_complete = true


func _process(_delta: float) -> void:
	# If we aren't loading anything, don't check the thread status
	if not _is_loading: return

	# Check how far along the background loading thread is
	var status = ResourceLoader.load_threaded_get_status(level_to_load)

	# Swap the scene ONLY if the level is 100% loaded AND the screen is fully black
	if status == ResourceLoader.THREAD_LOAD_LOADED and _fade_complete:
		var packed_scene = ResourceLoader.load_threaded_get(level_to_load)
		get_tree().change_scene_to_packed(packed_scene)
		
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("CRITICAL ERROR: Failed to load target level!")
		_is_loading = false


func _on_exit_pressed() -> void:
	get_tree().quit()
