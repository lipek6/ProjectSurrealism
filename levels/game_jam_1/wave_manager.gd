class_name WaveManager extends Node3D
## Handles clustered enemy spawning, wave progression, and reward dropping.

@export_group("Wave Settings")
@export var player : Node3D
@export var waves : Array[WaveConfig]                   ## Add 5 elements here in the Inspector!

@export_group("Spawn Radius")
@export var min_spawn_distance : float = 15.0           ## Minimum distance from player
@export var max_spawn_distance : float = 30.0           ## Maximum distance from player
@export var cluster_spread : float = 3.0                ## How far apart enemies in a cluster spawn

var _current_wave_index : int = 0
var _enemies_remaining_to_spawn : int = 0
var _active_enemies : int = 0
var _is_wave_active : bool = false

@onready var spawn_timer : Timer = Timer.new()

func _ready() -> void:
	# Setup internal timer for spacing out clusters
	add_child(spawn_timer)
	spawn_timer.wait_time = 3.0 # Spawns a cluster every 3 seconds
	spawn_timer.timeout.connect(_spawn_cluster)
	
	# Start the first wave after 5 seconds
	await get_tree().create_timer(5.0).timeout
	_start_wave(_current_wave_index)


func _start_wave(index: int) -> void:
	# ICTORY CONDITION & MENU RETURN ---
	if index >= waves.size():
		print("YOU BEAT THE GAME!")
		if player: 
			# Build a massive wall of text for the victory screen!
			var win_text : String = ""
			for i in range(15):
				win_text += "YOU WIN!!!\n"
			player.wave_message = win_text
			
		# Wait 5 seconds so they can bask in their glory
		await get_tree().create_timer(5.0).timeout
		
		# Unlock the mouse so they can click the menu buttons
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Send them back to the Main Menu!
		get_tree().change_scene_to_file("res://main_menu.tscn")
		return
		
	# --- NORMAL WAVE SPAWNING ---
	var wave : WaveConfig = waves[index]
	_enemies_remaining_to_spawn = wave.total_enemies
	_is_wave_active = true
	
	# Update the Player's Debug Label!
	if player: player.wave_message = "--- WAVE " + str(index + 1) + " STARTING! ---"
	
	print("--- WAVE ", index + 1, " STARTING! ---")
	spawn_timer.start()
	
func _spawn_cluster() -> void:
	if not _is_wave_active or not player: return
	
	var wave : WaveConfig = waves[_current_wave_index]
	
	# If no standard enemies left, check for boss
	if _enemies_remaining_to_spawn <= 0:
		spawn_timer.stop()
		if wave.boss_enemy:
			_spawn_enemy(wave.boss_enemy, _get_random_spawn_point_around(player.global_position, min_spawn_distance, max_spawn_distance))
		return
		
	# Determine how many to spawn in this cluster
	var amount_to_spawn = min(wave.cluster_size, _enemies_remaining_to_spawn)
	
	# Pick ONE central location for the cluster
	var cluster_center = _get_random_spawn_point_around(player.global_position, min_spawn_distance, max_spawn_distance)
	
	for i in range(amount_to_spawn):
		var enemy_scene = wave.enemy_types.pick_random()
		var final_pos = _get_random_spawn_point_around(cluster_center, 0.0, cluster_spread)
		_spawn_enemy(enemy_scene, final_pos)
		
	_enemies_remaining_to_spawn -= amount_to_spawn


func _spawn_enemy(enemy_scene: PackedScene, spawn_pos: Vector3) -> void:
	if not enemy_scene: return
	
	# Query the NavMesh to find the closest valid walkable position to our random point!
	var map = get_world_3d().navigation_map
	var safe_pos = NavigationServer3D.map_get_closest_point(map, spawn_pos)
	
	var enemy_instance = enemy_scene.instantiate()
	get_tree().root.add_child(enemy_instance)
	
	enemy_instance.global_position = safe_pos
	
	# Track the enemy
	_active_enemies += 1
	enemy_instance.tree_exiting.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	_active_enemies -= 1
	
	# Check if Wave is totally cleared
	if _active_enemies <= 0 and _enemies_remaining_to_spawn <= 0:
		_complete_current_wave()


func _complete_current_wave() -> void:
	_is_wave_active = false
	var wave : WaveConfig = waves[_current_wave_index]
	
	# Let the player know they have 10 seconds to grab the gun and reload
	if player: player.wave_message = "--- WAVE " + str(_current_wave_index + 1) + " CLEARED! NEXT WAVE IN 10s... ---"
	print("--- WAVE ", _current_wave_index + 1, " CLEARED! ---")
	
	# --- NEW: DIRECT INVENTORY INJECTION ---
	if wave.reward_weapon:
		# 1. Instantiate the physical drop scene in the void (not added to the tree)
		var temp_weapon_drop = wave.reward_weapon.instantiate()
		
		# 2. Check if this scene has the 'weapon_data' variable (from world_weapon.gd)
		if "weapon_data" in temp_weapon_drop and temp_weapon_drop.weapon_data != null:
			if player and player.weapon_manager:
				# 3. Force the resource directly into the player's brain!
				player.weapon_manager.add_weapon_to_inventory(temp_weapon_drop.weapon_data)
				print("Force-equipped weapon: ", temp_weapon_drop.weapon_data.weapon_name)
		
		# 4. Erase the physical drop from existence so it doesn't leak memory
		temp_weapon_drop.queue_free()
		
	_current_wave_index += 1
	
	# Start next wave after 10 seconds of breathing room
	await get_tree().create_timer(10.0).timeout
	_start_wave(_current_wave_index)


# ==========================================
# MATH HELPERS
# ==========================================
func _get_random_spawn_point_around(center: Vector3, min_radius: float, max_radius: float) -> Vector3:
	var angle = randf() * TAU # TAU is 2*PI (a full circle)
	var dist = randf_range(min_radius, max_radius)
	
	var offset = Vector3(
		cos(angle) * dist,
		0.0,
		sin(angle) * dist
	)
	
	return center + offset
