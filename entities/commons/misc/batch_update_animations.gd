@tool
extends EditorScript
# ==============================================================================
# TOOL: BATCH UPDATE ANIMATIONS
# A utility script to quickly override settings inside BlendSpace2D resources 
# without clicking through them manually.
# ==============================================================================

# 1. Define the resources you want to batch update
const BLEND_SPACES_TO_UPDATE: Array[String] = [
	#"res://entities/commons/human/arts/animations/states/stand_blend_space_2d.tres",
	"res://entities/commons/human/arts/animations/states/crouch_blend_space_2d.tres"
]


# Add exceptions
var ignore_array : Array[StringName] = []



const OVERRIDE_TIMELINE_LENGTH : float = 0.5


# 2. The _run() function is automatically called when you execute an EditorScript
func _run() -> void:
	print("--- Starting Batch Animation Update ---")
	
	for path in BLEND_SPACES_TO_UPDATE:
		_process_blend_space(path)
		
	print("--- Batch Update Complete ---")


func _process_blend_space(path: String) -> void:
	# Load the actual resource file from the disk
	var blend_space : AnimationNodeBlendSpace2D = load(path)
	
	if not blend_space:
		printerr("ERROR: Could not load BlendSpace at path: ", path)
		return
		
	var modified_count : int = 0
	
	# Loop through all points in the grid
	for i : int in blend_space.get_blend_point_count():
		var blend_point = blend_space.get_blend_point_node(i)
		
		# Ensure the node we grabbed is actually an Animation Node (and not a nested StateMachine)
		if blend_point is AnimationNodeAnimation:
			#if blend_point.animation in ignore_array:
			#	continue
			
			if blend_point.use_custom_timeline:
				blend_point.stretch_time_scale = true
				blend_point.loop_mode = Animation.LOOP_LINEAR
				blend_point.timeline_length = OVERRIDE_TIMELINE_LENGTH
				modified_count += 1
			
	# Save the modified resource back to the hard drive!
	var err = ResourceSaver.save(blend_space, path)
	
	if err == OK:
		print("SUCCESS: Updated ", modified_count, " animations in -> ", path.get_file())
	else:
		printerr("FAILED to save ", path.get_file(), " (Error Code: ", err, ")")
