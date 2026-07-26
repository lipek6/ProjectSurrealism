class_name WaveConfig extends Resource
## A data container for a single wave of enemies.

@export var enemy_types : Array[PackedScene]            ## The pool of standard enemies to spawn (e.g., Green Sphere, Red Sphere)
@export var total_enemies : int = 10                    ## Total number of standard enemies to spawn this wave
@export var cluster_size : int = 3                      ## How many enemies spawn together in a single group
@export var boss_enemy : PackedScene                    ## (Optional) Spawns at the very end of the wave
@export var reward_weapon : PackedScene                 ## The weapon dropped for the player when the wave is cleared
